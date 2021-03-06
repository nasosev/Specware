(in-package "ACL2")
(set-ignore-ok t)
(set-irrelevant-formals-ok t)
(set-bogus-defun-hints-ok t)
;(set-guard-checking nil)

(include-book "mydefsum")
;(include-book "~/Specware2/Languages/ACL2/mydefsum")
 
;;;;;;;;;;;;;;;;;;;
;; MISCELLANEOUS ;;
;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; implies-to-implies-macro ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Used to convert all instances of ``implies'' to macros, in order to make
;; guard verification of theorem bodies possible.

(defmacro implies-macro (x y)
  (declare (xargs :guard t))
  `(if ,x (if ,y t nil) t))
;  (list 'if x (list 'if y 't 'nil) 't))

(mutual-recursion

 (defun implies-to-implies-macro (term)
   (declare (xargs :guard t))
   (if (atom term) 
       term
       (let ((fn-name (if (equal (car term) 'implies) 
                          'implies-macro 
                          (car term))))
         (cons fn-name (map-implies-to-implies-macro (cdr term))))))

 (defun map-implies-to-implies-macro (terms)
   (declare (xargs :guard t))
   (if (atom terms)
       nil
       (cons (implies-to-implies-macro (car terms))
             (map-implies-to-implies-macro (cdr terms))))))

;;;;;;;;;;;;
;; lookup ;;
;;;;;;;;;;;;

;; Look up the value of a keyword in a list. 
;; Used for extracting the values of :hints, :otf-flg, etc.

(defun lookup-listp (x)
  (declare (xargs :guard t))
  (cond ((atom x) (eq x nil))
        (t (and (consp (cdr x))
                (lookup-listp (cddr x))))))

(defun lookup (x l)
  (declare (xargs :guard (lookup-listp l)))
  (if (mbt (lookup-listp l))
      (cond ((atom l) nil)
            ((equal (car l) x) (cadr l))
            (t (lookup x (cddr l))))
      nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove-kwds, get-kwds ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Pretty self-explanatory. remove-kwds removes the keywords and their values,
;; get-kwds only retains the list of keywords and values.

(defun remove-kwds (stuff)
  (declare (xargs :mode :program))
  (cond ((atom stuff) stuff)
        ((keywordp (car stuff))
         (remove-kwds (cddr stuff)))
        (t (cons (car stuff)
                 (remove-kwds (cdr stuff))))))

(defun get-kwds (stuff)
  (declare (xargs :mode :program))
  (cond ((atom stuff) stuff)
        ((keywordp (car stuff))
         (cons (car stuff)
               (cons (cadr stuff)
                     (get-kwds (cddr stuff)))))
        (t (get-kwds (cdr stuff)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; integer-to-string, integer-to-symbol ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun integer-to-string (n)
  (declare (xargs :mode :program
                  :guard (integerp n)))
  (subseq (fms-to-string "~s0" (list (cons #\0 n))
                         :fmt-control-alist nil)
          1 nil))

(defun integer-to-symbol (n)
  (declare (xargs :mode :program
                  :guard (integerp n)))
  (intern (integer-to-string n) "ACL2"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFCOPRODUCT-CONCRETE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;
;; transform-type-case ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; Just an auxiliary function, used to convert defcoproduct-style definitions
;; into a defsum-friendly format. Basically, we add -p to all the type names,
;; and give arbitrary names to all the fields (arg-1, arg-2, etc.)

(defun transform-type-case-1 (constructor-name rst-type-case n)
  (declare (xargs :mode :program))
  (cond ((atom rst-type-case) nil)
        ((atom (car rst-type-case))
         (cons
          (list (appsyms (list (car rst-type-case) 'p))
                (appsyms (list 'arg (integer-to-symbol n))))
          (transform-type-case-1 constructor-name (cdr rst-type-case) (1+ n))))
        (t (cons (car rst-type-case) (transform-type-case-1 constructor-name
                                                            (cdr rst-type-case)
                                                            (1+ n))))))

(defun transform-type-case (constructor-name rst-type-case)
  (declare (xargs :mode :program))
  (cons constructor-name 
        (transform-type-case-1 constructor-name 
                               rst-type-case
                               1)))

(defun map-transform-type-case (type-cases)
  (declare (xargs :mode :program))
  (cond ((atom type-cases) nil)
        (t (cons (transform-type-case (caar type-cases)
                                      (cdar type-cases))
                 (map-transform-type-case (cdr type-cases))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; defcoproduct-concrete ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun defcoproduct-concrete-fn (type rst)
  (declare (xargs :mode :program))
  (let* ((type-cases (remove-kwds rst))
         (kwds (get-kwds rst)))
    `(defsum ,type ,@(map-transform-type-case type-cases)
       ,@kwds)))


(defmacro defcoproduct-concrete (type &rest type-cases)
  (defcoproduct-concrete-fn type type-cases))

;; This function is needed, because defsum uses & as the wildcard pattern, but
;; defcoproduct uses _.
(defun replace-_-with-& (x)
  (cond ((atom x) (if (eq x '_) '& x))
        (t (cons (replace-_-with-& (car x))
                 (replace-_-with-& (cdr x))))))

;; case-of is a synonym for pattern-match from the defsum book, but we use _
;; instead of &.
(defmacro case-of (term &rest clauses)
  (append (list 'pattern-match term)
          (replace-_-with-& clauses)))

;; This allows the pattern (as x (...)), binding x to a value matching the
;; pattern (...). This is needed for the Specware translation.
(defmacro as-pattern-matcher
    (term args tests bindings lhses rhses pmstate)
  (cond ((not (true-listp args))
         (er hard 'pattern-match
             "badly formed expression: ~x0~%"
             (cons 'cons args)))
        (t ;; recursively pattern match all the args against copies of the term
         (let ((rhses (make-list-ac (len args) term rhses))
               (lhses (append args lhses)))
           (pattern-bindings-list lhses rhses tests bindings pmstate)))))

;;;;;;;;;;;;;;;;;;;;;;
;; DEFCOPRODUCT-POLY ;;
;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;
;; make-alist ;;
;;;;;;;;;;;;;;;;

;; Create an alist from a list of keys and values. We use this as input to
;; several functions that deal with polymorphic type instantiation; we often
;; need to be able to look up the actuals for type variables. 

(defun make-alist (vars vals)
  (declare (xargs :guard (and (true-listp vars)
                              (true-listp vals))))
  (cond ((endp vars) nil)
        ((endp vals) nil)
        (t (cons (cons (car vars) (car vals))
                 (make-alist (cdr vars) (cdr vals))))))

(defthm alistp-make-alist
    (alistp (make-alist a b)))

;;;;;;;;;;;;;;;;;;;;;
;; subst-type-name ;;
;;;;;;;;;;;;;;;;;;;;;

;; Given a type, potentially containing type variables, and an alist mapping
;; variables to actuals (these cannot themselves be variables), produce the
;; instantiated type.
;;
;; To best see how this works, I recommend just calling things like
;;
;;   (subst-type-name '(:inst Seq a) '((a . int)))
;;   (subst-type-name '(:inst Seq (:inst Maybe a) (:inst Either a b)) 
;;                    '((a . int) (b . bool)))

(mutual-recursion

 (defun subst-type-name (type var-alist)
   (declare (xargs :mode :program))
   (cond ((atom type)
          (let ((var-sub (assoc-equal type var-alist)))
            (if var-sub
                (cdr var-sub)
                type)))
         (t (appsyms (cons (cadr type)
                           (map-subst-type-name (cddr type) var-alist))))))

 (defun map-subst-type-name (types var-alist)
   (declare (xargs :mode :program))
   (cond ((atom types) nil)
         (t (cons (subst-type-name (car types) var-alist)
                  (map-subst-type-name (cdr types) var-alist))))))

;;;;;;;;;;;;;;;;;;;;;;;;
;; subst-type-case(s) ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Crawl through a type case or cases (i.e. ``ICons'' ``INil'') and replace
;; variable types with their instantiated versions. Essentially we are just
;; applying subst-type-name to everything in the type case.

(defun subst-type-case (type-case var-alist)
  (declare (xargs :mode :program))
  (cons (appsyms (cons (car type-case) (strip-cdrs var-alist)))
        (map-subst-type-name (cdr type-case) var-alist)))

(defun subst-type-cases (type-cases var-alist)
  (declare (xargs :mode :program))
  (cond ((endp type-cases) nil)
        (t (cons (subst-type-case (car type-cases) var-alist)
                 (subst-type-cases (cdr type-cases) var-alist)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; constrained-type-var-name(s) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Right now, this does nothing, but we may want to use more specific names for
;; type variables, indicating the data structure, function or theorem to which
;; they have been instantiated for.

(defun constrained-type-var-name (var fn)
  (declare (xargs :mode :program
                  :guard (and (symbolp var) (symbolp fn))))
  var)

(defun constrained-type-var-names (vars fn)
  (declare (xargs :mode :program
                  :guard (and (symbol-listp vars)
                              (symbolp fn))))
  (cond ((endp vars) nil)
        (t (cons (constrained-type-var-name (car vars) fn)
                 (constrained-type-var-names (cdr vars) fn)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; constrained-type-var(s) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Produces a constrained function representing an arbitrary type.

(defun constrained-type-var (var fn)
  (declare (xargs :mode :program
                  :guard (and (symbolp var) (symbolp fn))))
  `(encapsulate
    (((,(appsyms (list (constrained-type-var-name var fn) 'p)) *) => *))
    (local (defun ,(appsyms (list (constrained-type-var-name var fn) 'p))
               (x) (declare (ignore x)) t))
    (defthm ,(appsyms (list (constrained-type-var-name var fn)
                            'type))
        (booleanp (,(appsyms (list (constrained-type-var-name var fn) 'p)) x))
      :rule-classes :type-prescription)))

(defun constrained-type-vars (vars fn)
  (declare (xargs :mode :program
                  :guard (and (symbol-listp vars)
                              (symbolp fn))))
  (cond ((endp vars) nil)
        (t (cons (constrained-type-var (car vars) fn)
                 (constrained-type-vars (cdr vars) fn)))))

;;;;;;;;;;;;;;;;;;;;;;;
;; type-inst-prereqs ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; Given a type, produces the list of ``instantiate'' calls required in order
;; to work with this type.

(mutual-recursion

 (defun type-inst-prereqs (type var-alist skip-types)
   (declare (xargs :mode :program))
   (cond ((atom type) nil)
         ((member-equal (cadr type) skip-types)
          nil)
         (t `(,@(type-inst-list-prereqs (cdr type) var-alist skip-types)
                (,(appsyms `(,(cadr type) instantiate))
                  ,@(map-subst-type-name (cddr type) var-alist))))))

 (defun type-inst-list-prereqs (types var-alist skip-types)
   (cond ((atom types) nil)
         (t (append (type-inst-prereqs (car types) var-alist skip-types)
                    (type-inst-list-prereqs (cdr types) var-alist
   skip-types))))))

;;;;;;;;;;;;;;;;;;;;;;;
;; type-case-prereqs ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; Apply type-inst-prereqs to a type case

(defun type-case-prereqs (type-case var-alist skip-types)
  (declare (xargs :mode :program))
  (type-inst-list-prereqs (cdr type-case) var-alist skip-types))

(defun type-cases-prereqs (type-cases var-alist skip-types)
  (declare (xargs :mode :program))
  (cond ((atom type-cases) nil)
        (t (append (type-case-prereqs (car type-cases) var-alist skip-types)
                   (type-cases-prereqs (cdr type-cases) var-alist
  skip-types)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; type-case-instantiators ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Along with the coproduct instantiators, we also provide an instantiate
;; function for each constructor, which is basically a synonym for the
;; coproduct instantiator. The reason we do this is because sometimes, an :inst
;; will appear for a constructor, but we won't know what the type of that
;; constructor is out of context. So this macro allows us to just
;; ``instantiate'' the constructor without having to look up what its coproduct
;; instantiator is.

(defun type-case-instantiators (type-name type-case-names vars)
  (declare (xargs :mode :program))
  (cond ((atom type-case-names) nil)
        (t (cons `(defmacro ,(appsyms `(,(car type-case-names) instantiate)) ,vars
                    (list ',(appsyms `(,type-name instantiate)) ,@vars))
                 (type-case-instantiators type-name (cdr type-case-names)
                                          vars)))))

;;;;;;;;;;;;;;;;;;;;
;; make-tag-alist ;;
;;;;;;;;;;;;;;;;;;;;

;; This is used for the functional instantiation macros below. The idea is to
;; use the abstract constructor names as the tags instead of the specific
;; constructor names. If the tags are different then we can't use functional
;; instantation, so we make sure they are all the same. 

(defun make-tag-alist (case-names type-actuals)
  (declare (xargs :mode :program))
  (cond ((atom case-names) case-names)
        (t (cons (cons (appsyms (cons (car case-names)
                                      type-actuals))
                       (car case-names))
                 (make-tag-alist (cdr case-names)
                                 type-actuals)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Functional instance stuff ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; These functions help to produce the list of substitutions needed for
;; functional instantiation.

(defun functional-instance-coproduct-recognizer-sub (name
                                                     var-names
                                                     type-names)
  (declare (xargs :mode :program))
  (list (appsyms `(,name ,@var-names p))
        (appsyms `(,name ,@type-names p))))

(defun functional-instance-product-recognizer-subs (constructors var-names
                                                    type-names)
  (declare (xargs :mode :program))
  (cond ((atom constructors) nil)
        (t (cons (list (appsyms `(,(car constructors) ,@var-names p))
                       (appsyms `(,(car constructors) ,@type-names p)))
                 (functional-instance-product-recognizer-subs
                  (cdr constructors)
                  var-names
                  type-names)))))

(defun functional-instance-constructor-subs (constructors var-names type-names)
  (declare (xargs :mode :program))
  (cond ((atom constructors) nil)
        (t (cons (list (appsyms `(,(car constructors) ,@var-names))
                       (appsyms `(,(car constructors) ,@type-names)))
                 (functional-instance-constructor-subs (cdr constructors)
                                                       var-names
                                                       type-names)))))

(defun functional-instance-destructor-subs-1 (constructor
                                              num-fields
                                              var-names
                                              type-names)
  (declare (xargs :mode :program))
  (cond ((zp num-fields) nil)
        (t (cons `(,(appsyms `(,constructor ,@var-names 
                                            arg
                                            ,(integer-to-symbol
                                              num-fields)))
                    ,(appsyms `(,constructor ,@type-names
                                             arg
                                             ,(integer-to-symbol
                                               num-fields))))
                 (functional-instance-destructor-subs-1 constructor
                                                        (1- num-fields)
                                                        var-names
                                                        type-names)))))

(defun functional-instance-destructor-subs (constructors nums-fields var-names
                                            type-names)
  (declare (xargs :mode :program))
  (cond ((atom constructors) nil)
        (t (append (functional-instance-destructor-subs-1 
                    (car constructors)
                    (car nums-fields)
                    var-names
                    type-names)
                   (functional-instance-destructor-subs
                    (cdr constructors)
                    (cdr nums-fields)
                    var-names
                    type-names)))))

;; This is the daddy function - we call him to produce the list of substitutions.
(defun functional-instance-subs (name constructors nums-fields var-names
                                 type-names)
  (declare (xargs :mode :program))
  `(,(functional-instance-coproduct-recognizer-sub name var-names type-names)
     ,@(functional-instance-product-recognizer-subs constructors
                                                    var-names
                                                    type-names)
     ,@(functional-instance-constructor-subs constructors var-names type-names)
     ,@(functional-instance-destructor-subs constructors 
                                            nums-fields 
                                            var-names
                                            type-names)))

;;;;;;;;;;;;;;
;; num-args ;;
;;;;;;;;;;;;;;

;; Given a list of type cases, produces a list of the numbers of arguments for
;; each type case. 
(defun nums-args (type-cases)
  (cond ((atom type-cases) nil)
        (t (cons (1- (len (car type-cases)))
                 (nums-args (cdr type-cases))))))

;;;;;;;;;;;;;;;;;;;;;;;
;; defcoproduct-poly ;;
;;;;;;;;;;;;;;;;;;;;;;;

(defun defcoproduct-poly-fn (name vars cases)
  (declare (xargs :guard (and (symbolp name)
                              (symbol-listp vars)
                              (pseudo-term-listp cases))
                  :mode :program))
  (let ((type-case-instantiators (type-case-instantiators 
                                  name 
                                  (strip-cars cases)
                                  vars)))
    `(progn
       (defmacro ,(appsyms (list name 'instantiate)) ,vars
         `(progn
            ,@(type-cases-prereqs ',cases (make-alist ',vars (list ,@vars)) (list ',name))
            (defcoproduct-concrete ,(appsyms (cons ',name (list ,@vars)))
                ,@(subst-type-cases ',cases (make-alist ',vars (list ,@vars)))
              :tag-alist ,(make-tag-alist ',(strip-cars cases) (list ,@vars)))))
       ,@(type-case-instantiators name (strip-cars cases) vars)
       ,@(constrained-type-vars vars name)
       (,(appsyms (list name 'instantiate)) 
         ,@(constrained-type-var-names vars name))
       (defun ,(appsyms `(,name functional-instance-subs))
           (var-names type-names)
         (declare (xargs :mode :program))
         (functional-instance-subs ',name 
                                   ',(strip-cars cases)
                                   ',(nums-args cases)
                                   var-names
                                   type-names)))))

(defmacro defcoproduct-poly (name vars &rest cases)
  (defcoproduct-poly-fn name vars cases))

;;;;;;;;;;;;;;;;;;
;; DEFCOPRODUCT ;;
;;;;;;;;;;;;;;;;;;

(defun defcoproduct-fn (name rst)
  (if (and (consp rst)
           (consp (cdr rst))
           (eq (car rst) ':type-vars))
      `(defcoproduct-poly ,name ,(cadr rst) ,@(cddr rst))
      `(defcoproduct-concrete ,name ,@rst)))

(defmacro defcoproduct (name &rest rst)
  (defcoproduct-fn name rst))

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFUN-TYPED-CONCRETE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Use:
;;
;; (defun-typed-concrete example ((x type1-p)
;;                       (y type2-p)
;;                       (z type3-p)
;;                       (a type4-p)
;;                       (b type5-p)
;;                       (c type6-p)
;;                       (i type7-p)
;;                       (j type8-p))
;;              output-type-p
;;   (declare (ignore a b c)
;;            (type integer i j)
;;            (xargs :guard (symbolp x)
;;                   :measure (- i j)
;;                   :ruler-extenders :basic
;;                   :well-founded-relation my-wfr
;;                   :hints (("Goal"
;;                            :do-not-induct t
;;                            :do-not '(generalize fertilize)
;;                            :expand ((assoc x a) (member y z))
;;                            :restrict ((<-trans ((x x) (y (foo x)))))
;;                            :hands-off (length binary-append)
;;                            :in-theory (set-difference-theories
;;                                        (current-theory :here)
;;                                        '(assoc))
;;                            :induct (and (nth n a) (nth n b))
;;                            :use ((:instance assoc-of-append
;;                                             (x a) (y b) (z c))
;;                                  (:functional-instance
;;                                   (:instance p-f (x a) (y b))
;;                                   (p consp)
;;                                   (f assoc)))))
;;                   :guard-hints (("Subgoal *1/3'"
;;                                  :use ((:instance assoc-of-append
;;                                                   (x a) (y b) (z c)))))
;;                   :mode :logic
;;                   :normalize nil
;;                   :non-executable t
;;                   :otf-flg t
;;                   :type-lemmas 
;;                    ((defthm example-type-lemma1 ...)
;;                     (defthm example-type-lemma2 ...))
;;                   :type-args
;;                   (:rule-classes foo1
;;                    :instructions foo2
;;                    :hints foo3
;;                    :otf-flg foo4
;;                    :doc foo5))
;;   (example-body x y z i j))
;;
;;  =>
;;
;; (defun example (x y z a b c i j
;;   (declare (ignore a b c)
;;            (type integer i j)
;;            (xargs :guard (and (type1-p x)
;;                               (type2-p y)
;;                               (type3-p z)
;;                               (type4-p a)
;;                               (type5-p b)
;;                               (type6-p c)
;;                               (type7-p i)
;;                               (type8-p j))
;;                   :verify-guards nil
;;                   :guard (symbolp x)
;;                   :measure (- i j)
;;                   :ruler-extenders :basic
;;                   :well-founded-relation my-wfr
;;                   :hints (("Goal"
;;                            :do-not-induct t
;;                            :do-not '(generalize fertilize)
;;                            :expand ((assoc x a) (member y z))
;;                            :restrict ((<-trans ((x x) (y (foo x)))))
;;                            :hands-off (length binary-append)
;;                            :in-theory (set-difference-theories
;;                                        (current-theory :here)
;;                                        '(assoc))
;;                            :induct (and (nth n a) (nth n b))
;;                            :use ((:instance assoc-of-append
;;                                             (x a) (y b) (z c))
;;                                  (:functional-instance
;;                                   (:instance p-f (x a) (y b))
;;                                   (p consp)
;;                                   (f assoc)))))
;;                   :guard-hints (("Subgoal *1/3'"
;;                                  :use ((:instance assoc-of-append
;;                                                   (x a) (y b) (z c)))))
;;                   :mode :logic
;;                   :normalize nil
;;                   :non-executable t
;;                   :otf-flg t
;;   (if (mbt (and (type1-p x)
;;                 (type2-p y)
;;                 (type3-p z)
;;                 (type4-p a)
;;                 (type5-p b)
;;                 (type6-p c)
;;                 (type7-p i)
;;                 (type8-p j)))
;;       (example-body x y z i j)
;;       nil))
;;
;; (defthm example-type-lemma1 ...)
;; (defthm example-type-lemma2 ...)
;;
;; (defthm example-type
;;   (implies (and (type1-p x)
;;                 (type2-p y)
;;                 (type3-p z)
;;                 (type4-p a)
;;                 (type5-p b)
;;                 (type6-p c)
;;                 (type7-p i)
;;                 (type8-p j)))
;;   :rule-classes foo1
;;   :instructions foo2
;;   :hints foo3
;;   :otf-flg foo4
;;   :doc foo5)

;;;;;;;;;;;;;;;;;;;
;; add-p-to-name ;;
;;;;;;;;;;;;;;;;;;;

(defun add-p-to-name (name)
  (declare (xargs :guard (symbolp name)))
  (intern (string-append (string name) "-P") "ACL2"))

;;;;;;;;;;;;;;;;;;;;;;;
;; hyphenate-symbols ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; TODO: Replace this throughout with appsyms 

(defun hyphenate-symbols-string (syms)
  (declare (xargs :guard (symbol-listp syms)))
  (cond ((atom syms) "")
        ((atom (cdr syms)) (string (car syms)))
        (t (string-append (string-append (string (car syms))
                                         "-")
                          (hyphenate-symbols-string (cdr syms))))))

(defun hyphenate-symbols (syms)
  (declare (xargs :guard (symbol-listp syms)))
  (intern (hyphenate-symbols-string syms) "ACL2"))

;;;;;;;;;;;;;;;;;;;
;; is-function-p ;;
;;;;;;;;;;;;;;;;;;;

;; Check if the term is possibly a function. This is outdated, because now we
;; allow things like (:inst foo a)

(defun is-function-p (term)
  (declare (xargs :guard t))
  (or (atom term)
      (equal (car term) 'lambda)))

;;;;;;;;;;;;
;; type-p ;;
;;;;;;;;;;;;

;; Check if the term is possibly a type.
 
(mutual-recursion
 (defun type-p (x)
   (declare (xargs :guard t))
   (or (symbolp x)
       (and (consp x)
            (consp (cdr x))
            (consp (cddr x))
            (atom (cdddr x))
            (eq (car x) ':subtype)
            (symbolp (cadr x)))
       (and (consp x)
            (eq (car x) ':inst)
            (type-list-p (cdr x)))))

 (defun type-list-p (l)
   (declare (xargs :guard t))
   (cond ((atom l) t)
         (t (and (type-p (car l))
                 (type-list-p (cdr l)))))))

;;;;;;;;;;;;;;;;;;;;;
;; typed-arg-listp ;;
;;;;;;;;;;;;;;;;;;;;;

;; Check if a term is a typed list of arguments, i.e.: 
;; ((x int) y (z (:inst Seq a)))

(defun typed-arg-listp (x)
  (declare (xargs :guard t))
  (cond ((atom x) (eq x nil))
        ((atom (car x)) (typed-arg-listp (cdr x)))
        (t (and (consp (car x))
                (consp (cdar x))
                (atom (cddar x))
                (type-p (cadar x))
                (typed-arg-listp (cdr x))))))

;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-args, get-types ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; retrieve the list of args, list of types of a typed-arg-listp

(defun get-args (typed-args)
  (declare (xargs :guard (typed-arg-listp typed-args)))
  (cond ((endp typed-args) nil)
        ((atom (car typed-args))
         (cons (car typed-args)
               (get-args (cdr typed-args))))
        (t (cons (caar typed-args)
                 (get-args (cdr typed-args))))))

(defun get-types (typed-args)
  (declare (xargs :guard (typed-arg-listp typed-args)))
  (cond ((endp typed-args) nil)
        ((atom (car typed-args))
         (cons ':all (get-types (cdr typed-args))))
        (t (cons (cadar typed-args)
                 (get-types (cdr typed-args))))))

;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-type-constraint ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; Given a typed-arg-listp, construct the type constraint (left-hand side of
;; implication). Test this with a typed-arg-listp to see what it does exactly.

(defun get-type-constraint-1 (typed-args)
  (declare (xargs :guard (typed-arg-listp typed-args)
                  :verify-guards nil))
  (cond ((endp typed-args) nil)
        ((atom (car typed-args))
         (get-type-constraint-1 (cdr typed-args)))
        ((consp (second (first typed-args)))
         (let* ((arg-name (first (first typed-args)))
                (parent-type-p (add-p-to-name (second (second 
                                                       (first
                                                        typed-args)))))
                (restriction (third (second (first typed-args))))
                (restriction-term
                 (if (is-function-p restriction)
                     (list restriction arg-name)
                     restriction)))
           (cons (list parent-type-p arg-name)
                 (cons restriction-term
                       (get-type-constraint-1 (cdr typed-args))))))
        (t (cons (list (add-p-to-name (second (first typed-args)))
                       (first (first typed-args)))
                 (get-type-constraint-1 (cdr typed-args))))))

(defun get-type-constraint (typed-args)
  (declare (xargs :guard (typed-arg-listp typed-args)
                  :verify-guards nil))
  (let ((gtc-1 (get-type-constraint-1 typed-args)))
    (cond ((atom gtc-1) t)
          ((atom (cdr gtc-1)) (car gtc-1))
          (t (cons 'and gtc-1)))))

;;;;;;;;;;;;;;;;;;;;
;; lookup-declare ;;
;;;;;;;;;;;;;;;;;;;;

;; Looks up the (declare ..) form in a function body.

(defun lookup-declare (l)
  (declare (xargs :guard (true-listp l)))
  (cond ((endp l) nil)
        ((atom (car l)) (lookup-declare (cdr l)))
        ((equal (caar l) 'declare)
         (car l))
        (t (lookup-declare (cdr l)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove-new-xargs-1 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Given (xargs l), removes the additional args so that defun can process them
;; normally. 

(defun remove-new-xargs-1 (xargs)
  (declare (xargs :guard (true-listp xargs)))
  (cond ((atom xargs) nil)
        ((or (equal (car xargs) ':type-lemmas)
             (equal (car xargs) ':type-args)
             (equal (car xargs) ':verify-guards-args))
         (remove-new-xargs-1 (cddr xargs)))
        (t (cons (car xargs) 
                 (cons (cadr xargs) (remove-new-xargs-1
                                     (cddr xargs)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove-new-xargs-declare ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Applies remove-new-xargs-1 to a (declare ...) form

(defun remove-new-xargs-declare-1 (decl)
  (declare (xargs :guard (true-list-listp decl)))
  (cond ((atom decl) nil)
        ((equal (caar decl) 'xargs)
         (cons (cons 'xargs (remove-new-xargs-1 (cdar decl)))
               (remove-new-xargs-declare-1 (cdr decl))))
        (t (cons (car decl) (remove-new-xargs-declare-1 (cdr decl))))))

(defun remove-new-xargs-declare (decl)
  (declare (xargs :guard (or (null decl)
                             (and (consp decl)
                                  (equal (car decl) 'declare)
                                  (true-list-listp (cdr decl))))))
  (if decl
      (cons 'declare (remove-new-xargs-declare-1 (cdr decl)))
      nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-type-constraint-args-decl ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-type-constraint-args-1 (xargs)
  (declare (xargs :guard (true-listp xargs)))
  (cond ((atom xargs) nil)
        ((equal (car xargs) ':type-args)
         (cadr xargs))
        (t (get-type-constraint-args-1 (cddr xargs)))))

(defun get-type-constraint-args-decl-1 (decl)
  (declare (xargs :guard (true-list-listp decl)))
  (cond ((atom decl) nil)
        ((equal (caar decl) 'xargs)
         (get-type-constraint-args-1 (cdar decl)))
        (t (get-type-constraint-args-decl-1 (cdr decl)))))

(defun get-type-constraint-args-decl (decl)
  (declare (xargs :guard (or (null decl)
                             (and (consp decl)
                                  (equal (car decl) 'declare)
                                  (true-list-listp (cdr decl))))))
  (if decl
      (get-type-constraint-args-decl-1 (cdr decl))
      nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-type-constraint-lemmas-decl ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-type-constraint-lemmas-1 (xargs)
  (declare (xargs :guard (true-listp xargs)))
  (cond ((atom xargs) nil)
        ((equal (car xargs) ':type-lemmas)
         (cadr xargs))
        (t (get-type-constraint-lemmas-1 (cddr xargs)))))

(defun get-type-constraint-lemmas-decl-1 (decl)
  (declare (xargs :guard (true-list-listp decl)))
  (cond ((atom decl) nil)
        ((equal (caar decl) 'xargs)
         (get-type-constraint-lemmas-1 (cdar decl)))
        (t (get-type-constraint-lemmas-decl-1 (cdr decl)))))

(defun get-type-constraint-lemmas-decl (decl)
  (declare (xargs :guard (or (null decl)
                             (and (consp decl)
                                  (equal (car decl) 'declare)
                                  (true-list-listp (cdr decl))))))
  (if decl
      (get-type-constraint-lemmas-decl-1 (cdr decl))
      nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-verify-guards-args-decl ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-verify-guards-args-1 (xargs)
  (declare (xargs :guard (true-listp xargs)))
  (cond ((atom xargs) nil)
        ((equal (car xargs) ':verify-guards-args)
         (cadr xargs))
        (t (get-verify-guards-args-1 (cddr xargs)))))

(defun get-verify-guards-args-decl-1 (decl)
  (declare (xargs :guard (true-list-listp decl)))
  (cond ((atom decl) nil)
        ((equal (caar decl) 'xargs)
         (get-verify-guards-args-1 (cdar decl)))
        (t (get-verify-guards-args-decl-1 (cdr decl)))))

(defun get-verify-guards-args-decl (decl)
  (declare (xargs :guard (or (null decl)
                             (and (consp decl)
                                  (equal (car decl) 'declare)
                                  (true-list-listp (cdr decl))))))
  (if decl
      (get-verify-guards-args-decl-1 (cdr decl))
      nil))

;;;;;;;;;;;;;;;;;
;; lookup-body ;;
;;;;;;;;;;;;;;;;;

;; Looks up the body of a function, skipping the declare and any keywords 

(defun lookup-body (l)
  (declare (xargs :guard (true-listp l)))
  (cond ((atom l) nil)
        ((keywordp (car l))
         (if (consp (cdr l))
             (lookup-body (cddr l))
             nil))
        ((and (consp (car l)) (equal (caar l) 'declare))
         (lookup-body (cdr l)))
        (t (car l))))

;;;;;;;;;;;;;;;;;;
;; replace-inst ;;
;;;;;;;;;;;;;;;;;;

;; replace any (:inst .. ) 's with the instantiated types

(defun replace-inst (term var-alist end-syms)
  (declare (xargs :mode :program))
  (cond ((atom term) 
         (let ((pair (assoc-equal term var-alist)))
           (if pair (cdr pair) term)))
        ((eq (car term) ':inst)
         (appsyms (append (replace-inst (cdr term) var-alist end-syms) end-syms)))
        (t (cons (replace-inst (car term) var-alist end-syms)
                 (replace-inst (cdr term) var-alist end-syms)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; type-inst-prereqs-defun ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Given the body of the function, the type variable substitution, and a list
;; of functions to skip, produces a list of the prerequisite instantiations we
;; need to perform before we can define this function

(defun type-inst-prereqs-defun (term var-alist skip-insts)
  (declare (xargs :mode :program))
  (cond ((atom term)
         nil)
         ;; (let ((pair (assoc-equal term var-alist)))
         ;;   (if pair (cdr pair) term)))
        ((and (eq (car term) ':inst)
              (member-equal (cadr term) skip-insts))
         nil)
        ((eq (car term) ':inst)
         (append (type-inst-prereqs-defun (cddr term)
                                          var-alist
                                          skip-insts)
                 (list (cons (appsyms (list (cadr term)
                                            'instantiate))
                             (map-subst-type-name (cddr term)
                                                  var-alist)))))
        ((consp (car term)) 
         (append (type-inst-prereqs-defun (car term)
                                          var-alist
                                          skip-insts)
                 (type-inst-prereqs-defun (cdr term)
                                          var-alist
                                          skip-insts)))
        (t (type-inst-prereqs-defun (cdr term) var-alist skip-insts))))

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; defun-typed-concrete ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TODO: use backquotes!!! (moron)

(defmacro defun-typed-concrete (name typed-args type &rest rst)
  (declare (xargs :guard (and (symbolp name)
                              (typed-arg-listp typed-args)
                              (type-p type)
                              (true-listp rst))))
  (let* ((decl (lookup-declare rst))
         (decl-defun (remove-new-xargs-declare decl))
         (type-constraint-args (get-type-constraint-args-decl decl))
         (type-constraint-lemmas (get-type-constraint-lemmas-decl decl))
         (verify-guards-args (get-verify-guards-args-decl decl))
;         (type-hints (lookup ':type-hints rst))
         (body (lookup-body rst))
         (type-inst-prereqs (append
                             (type-inst-prereqs-defun typed-args nil (list
                                                                      name))
                             (type-inst-prereqs-defun body nil (list name))))
         (typed-args (replace-inst typed-args nil nil))
         (type (replace-inst type nil nil))
         (body (replace-inst body nil nil)))
    (append (list 'progn)
            type-inst-prereqs
            (list (append (list 'defun name (get-args typed-args) 
                                (list 'declare
                                      (list 'xargs 
                                            ':guard 
                                            (get-type-constraint typed-args)
                                            ':verify-guards nil)))
                          (if decl-defun (list decl-defun) nil)
                          (if (equal (get-type-constraint typed-args) t)
                              (list body)
                              (list 
                               (list 'if
                                     (list 'mbt 
                                           (get-type-constraint typed-args))
                                     body
                                     nil)))))
            type-constraint-lemmas
            (cond ((equal type ':all) nil)
                  ((consp type) ; subtype
                   (let* ((parent-type-p (add-p-to-name (cadr type)))
                          (restriction (caddr type))
                          (type-constraint (get-type-constraint typed-args))
                          (term 
                           (if (eq type-constraint t)
                               (list 'and
                                     (list parent-type-p (cons name (get-args
                                                                     typed-args)))
                                     (list restriction (cons name (get-args
                                                                   typed-args))))
                               (list 'implies
                                     (get-type-constraint typed-args)
                                     (list 
                                      'and
                                      (list parent-type-p (cons name (get-args
                                                                      typed-args)))
                                      (list restriction (cons name (get-args
                                                                    typed-args))))))))
                     (list
                      (append (list 'defthm 
                                    (hyphenate-symbols 
                                     (list name 'type))
                                    term
                                    ':rule-classes '(:type-prescription
                                                     :rewrite))
                              type-constraint-args))))
                  (t (let* ((type-constraint (get-type-constraint typed-args))
                            (term
                             (if (eq type-constraint t)
                                 (list (add-p-to-name type)
                                       (cons name (get-args typed-args)))
                                 (list 'implies
                                       (get-type-constraint typed-args)
                                       (list (add-p-to-name type) (cons name (get-args
                                                                              typed-args)))))))
                       (list 
                        (append (list 'defthm (hyphenate-symbols (list name 'type))
                                      term
                                      ':rule-classes '(:type-prescription 
                                                       :rewrite))
                                type-constraint-args)))))
;            (lookup ':guard-lemmas rst)
            (list (append (list 'verify-guards name) verify-guards-args)))))

;            (list (list 'verify-guards (hyphenate-symbols (list name 'type-constraint)))))))

;;;;;;;;;;;;;;;;;;;;;;
;; DEFUN-TYPED-POLY ;;
;;;;;;;;;;;;;;;;;;;;;;

(defun defun-typed-poly-fn (name type-vars typed-args type rst)
  (declare (xargs :mode :program))
  `(progn 
     (defmacro ,(appsyms `(,name instantiate)) ,type-vars
       (let ((var-alist (make-alist ',type-vars (list ,@type-vars))))
         `(progn
            ,@(remove-duplicates
               (append (type-inst-prereqs-defun ',typed-args var-alist (list ',name))
                       (type-inst-prereqs-defun ',type var-alist (list ',name))
                       (type-inst-prereqs-defun ',rst var-alist (list ',name)))
               :test 'equal)
            (defun-typed ,(appsyms (list ',name ,@type-vars))
                ,(replace-inst ',typed-args var-alist nil)
              ,(replace-inst ',type var-alist nil)
              ,@(replace-inst ',rst var-alist nil)))))
     (defun ,(appsyms `(,name functional-instance-subs))
         (var-names type-names)
       (declare (xargs :mode :program))
       (list (list (appsyms (append (list ',name)
                                    var-names 
                                    nil))
                   (appsyms (append (list ',name)
                                    type-names
                                    nil)))))))


(defmacro defun-typed-poly (name type-vars typed-args type &rest rst)
  (defun-typed-poly-fn name type-vars typed-args type rst))

;; (defmacro defun-typed-poly (name type-vars typed-args type &rest rst)
;;   (defun-typed-poly-fn name type-vars typed-args type rst))

;;;;;;;;;;;;;;;;;
;; DEFUN-TYPED ;;
;;;;;;;;;;;;;;;;;

(defun defun-typed-fn (name rst)
  (if (and (consp rst)
           (consp (cdr rst))
           (eq (car rst) ':type-vars))
      `(defun-typed-poly ,name ,(cadr rst) ,@(cddr rst))
      `(defun-typed-concrete ,name ,@rst)))

(defmacro defun-typed (name &rest rst)
  (defun-typed-fn name rst))

(defmacro defund-typed (name &rest rst)
  `(progn (defun-typed ,name ,@rst)
          (in-theory (disable ,name))))

;; (defmacro defund-typed (name typed-args type &rest rst)
;;   (declare (xargs :guard (and (symbolp name)
;;                               (typed-arg-listp typed-args)
;;                               (type-p type)
;;                               (true-listp rst))))
;;   `(progn ,(append `(defun-typed ,name ,typed-args ,type) rst)
;;           (in-theory (disable ,name))))

;;;;;;;;;;;;;;;;;;
;; DEFPREDICATE ;;
;;;;;;;;;;;;;;;;;;

(defmacro defpredicate (name args &rest rst)
  (declare (xargs :guard (and (symbolp name)
                              (symbol-listp args)
                              (true-listp rst))))
  (append (list 'defun-typed name (list (car args)) 'bool)
          rst))

(defmacro defpredicated (name args &rest rst)
  (declare (xargs :guard (and (symbolp name)
                              (symbol-listp args)
                              (true-listp rst))))
  (append (list 'defund-typed name (list (car args)) 'bool)
          rst))

;;;;;;;;;;;;;;;;
;; DEFSUBTYPE ;;
;;;;;;;;;;;;;;;;

;; (defsubtype subtype parenttype-p restriction)
;;
;; =>
;;
;; (defpredicate subtype-p ((parenttype-p x))
;;   (and (parenttype-p x)
;;        (restriction x)))

(defmacro defsubtype (subtype-p parenttype restriction)
  (declare (xargs :guard (and (symbolp subtype-p)
                              (symbolp parenttype))))
  `(progn
     (defpredicate ,subtype-p (x)
       (and (,(add-p-to-name parenttype) x)
            (,restriction x)))
     (defthm ,(hyphenate-symbols (list subtype-p 'is (add-p-to-name parenttype)))
         (implies (,subtype-p x)
                  (,(add-p-to-name parenttype) x))
       :rule-classes :forward-chaining)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFTHM-TYPED-CONCRETE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Use:
;;
;; (defthm-typed the-theorem
;;   ((type1-p x) (type2-p y) (type3-p z))
;;   (implies (hyps x y z) (concl x y z))
;;   :rule-classes (:REWRITE :GENERALIZE)
;;   :instructions (induct prove promote (dive 1) x
;;                         (dive 2) = top (drop 2) prove)
;;   :hints (("Goal"
;;            :do-not '(generalize fertilize)
;;            :in-theory (set-difference-theories
;;                        (current-theory :here)
;;                        '(assoc))
;;            :induct (and (nth n a) (nth n b))
;;            :use ((:instance assoc-of-append
;;                             (x a) (y b) (z c))
;;                  (:functional-instance
;;                   (:instance p-f (x a) (y b))
;;                   (p consp)
;;                   (f assoc)))))
;;   :otf-flg t
;;   :doc "#0[one-liner/example/details]")
;;
;; =>
;;
;; (progn
;; (defthm the-theorem
;;     (implies (and (type1-p x)
;;                   (type2-p y)
;;                   (type3-p z)
;;                   (hyps x y z))
;;              (concl x y z))
;;   :rule-classes (:REWRITE :GENERALIZE)
;;   :instructions (induct prove promote (dive 1) x
;;                         (dive 2) = top (drop 2) prove)
;;   :hints (("Goal"
;;            :do-not '(generalize fertilize)
;;            :in-theory (set-difference-theories
;;                        (current-theory :here)
;;                        '(assoc))
;;            :induct (and (nth n a) (nth n b))
;;            :use ((:instance assoc-of-append
;;                             (x a) (y b) (z c))
;;                  (:functional-instance
;;                   (:instance p-f (x a) (y b))
;;                   (p consp)
;;                   (f assoc)))))
;;   :otf-flg t
;;   :doc "#0[one-liner/example/details]")
;; 
;; (defun-typed main-body ((type1-p x)
;;                         (type2-p y)
;;                         (type3-p z))
;;              booleanp
;;   (implies (hyps  x y z)
;;            (concl x y z))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove-body-declare, get-body-declare ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; To guard-verify the body of a theorem, we may need to add a declare form to
;; it. To do this, just add a :body-declare to the body of the theorem, and it
;; will be inserted at the top of the body function definition.

(defun remove-body-declare (rst)
  (declare (xargs :guard (true-listp rst)))
  (cond ((endp rst) nil)
        ((equal (car rst) ':body-declare)
         (remove-body-declare (cddr rst)))
        (t (cons (car rst) 
                 (cons (cadr rst) (remove-body-declare
                                   (cddr rst)))))))

(defun get-body-declare (rst)
  (declare (xargs :guard (true-listp rst) :verify-guards nil))
  (cond ((endp rst) nil)
        ((equal (car rst) ':body-declare)
         (cadr rst))
        (t (get-body-declare (cddr rst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove-enable, get-enable ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A quick-and-dirty way to enable a function for proving a theorem. Doesn't
;; work in the presence of other hints; if you need to do any more complicated
;; hints, just put the :enable there.

(defun remove-enable (rst)
  (declare (xargs :guard (true-listp rst)))
  (cond ((endp rst) nil)
        ((equal (car rst) ':enable)
         (remove-enable (cddr rst)))
        (t (cons (car rst) 
                 (cons (cadr rst) (remove-enable
                                   (cddr rst)))))))

(defun get-enable (rst)
  (declare (xargs :guard (true-listp rst) :verify-guards nil))
  (cond ((endp rst) nil)
        ((equal (car rst) ':enable)
         (cadr rst))
        (t (get-enable (cddr rst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; defthm-typed-concrete ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro defthm-typed-concrete (name typed-vars term &rest rst)
  (declare (xargs :guard (and (symbolp name)
                              (typed-arg-listp typed-vars)
                              (true-listp rst))))
  (let ((enable (get-enable rst))
        (rst (remove-enable rst)))
    `(progn
       ,@(if enable (list `(in-theory (enable ,@enable))) nil)
       (defund-typed ,(appsyms `(,name body))
           ,typed-vars
         bool
         ,@(if (get-body-declare rst)
               (list (get-body-declare rst))
               nil)
         ,(implies-to-implies-macro term))
       (defthm ,name
           (implies ,(get-type-constraint typed-vars)
                    ,term)
         ,@(remove-body-declare rst))
       ,@(if enable (list `(in-theory (disable ,@enable))) nil))))

(defmacro defthmd-typed-concrete (name typed-vars term &rest rst)
  (declare (xargs :guard (and (symbolp name)
                              (typed-arg-listp typed-vars)
                              (true-listp rst))))
  `(progn ,(append `(defthm-typed-concrete ,name ,typed-vars ,term) rst)
          (in-theory (disable ,name))))

;;;;;;;;;;;;;;;;;;;;;;;
;; DEFTHM-TYPED-POLY ;;
;;;;;;;;;;;;;;;;;;;;;;;

;; (defun type-inst-prereqs-defun (term var-alist skip-insts)
;;   (declare (xargs :mode :program))
;;   (cond ((atom term)
;;          (let ((pair (assoc-equal term var-alist)))
;;            (if pair (cdr pair) term)))
;;         ((and (eq (car term) ':inst)
;;               (member-equal (cadr term) skip-insts))
;;          nil)
;;         ((eq (car term) ':inst)
;;          (append (type-inst-prereqs-defun (cddr term)
;;                                           var-alist
;;                                           skip-insts)
;;                  (list (cons (appsyms (list (cadr term)
;;                                             'instantiate))
;;                              (map-subst-type-name (cddr term)
;;                                                   var-alist)))))
;;         ((consp (car term)) 
;;          (append (type-inst-prereqs-defun (car term)
;;                                           var-alist
;;                                           skip-insts)
;;                  (type-inst-prereqs-defun (cdr term)
;;                                           var-alist
;;                                           skip-insts)))
;;         (t (type-inst-prereqs-defun (cdr term) var-alist skip-insts))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; function-theory-prereqs ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Compute the theory calls we need enabled for functional instantiation...

(defun function-theory-prereqs (term var-alist skip-insts)
  (declare (xargs :mode :program))
  (cond ((atom term)
         (let ((pair (assoc-equal term var-alist)))
           (if pair (cdr pair) term)))
        ((and (eq (car term) ':inst)
              (member-equal (cadr term) skip-insts))
         nil)
        ((eq (car term) ':inst)
         (append (function-theory-prereqs (cddr term)
                                          var-alist
                                          skip-insts)
                 (list (appsyms (append (list (cadr term))
                                        (map-subst-type-name (cddr term)
                                                             var-alist)
                                        (list 'functions))))))
        ((consp (car term))
         (append (function-theory-prereqs (car term)
                                          var-alist
                                          skip-insts)
                 (function-theory-prereqs (cdr term)
                                          var-alist
                                          skip-insts)))
        (t (function-theory-prereqs (cdr term) var-alist skip-insts))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; collect-functional-instance-subs ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Compute the full list of substitutions needed for functional instantiation
;; of this theorem

(defun collect-functional-instance-subs-1 (term var-names type-names skip-insts)
  (declare (xargs :mode :program))
  (cond ((atom term) nil)
        ((and (eq (car term) ':inst)
              (member-equal (cadr term) skip-insts))
         nil)
        ((eq (car term) ':inst)
         (append (collect-functional-instance-subs-1
                  (cddr term)
                  var-names
                  type-names
                  skip-insts)
                 (list (list (appsyms (list (cadr term)
                                            'functional-instance-subs))
                             (list 'quote var-names)
                             (list 'quote type-names)))))
        ((consp (car term))
         (append (collect-functional-instance-subs-1 (car term)
                                                     var-names
                                                     type-names
                                                     skip-insts)
                 (collect-functional-instance-subs-1 (cdr term)
                                                     var-names
                                                     type-names
                                                     skip-insts)))
        (t (collect-functional-instance-subs-1 (cdr term)
                                               var-names
                                               type-names
                                               skip-insts))))

(defun collect-functional-instance-subs (term var-names type-names skip-insts)
  (declare (xargs :mode :program))
  (remove-duplicates
   (collect-functional-instance-subs-1 term var-names type-names skip-insts)
   :test 'equal))

;;;;;;;;;;;;;;;
;; zip-lists ;;
;;;;;;;;;;;;;;;

;; takes a list of vars, list of actuals, and gives the combined list of
;; substituting the ones for the others.

(defun zip-lists (x y name)
  (declare (xargs :mode :program))
  (cond ((atom x) nil)
        (t (cons (list (appsyms (list (car x) 
                                      'p))
                       (appsyms (list (car y) 'p)))
                 (zip-lists (cdr x) (cdr y) name)))))
 
;;;;;;;;;;;;;;;;;;;;;
;; instance-defthm ;;
;;;;;;;;;;;;;;;;;;;;;

;; This is pretty horrific - we need two levels of backquotes to achieve the
;; needed effect. 

(defun instance-defthm
    (name; of original theorem
     type-vars
     type-actuals
     typed-variables;  ((x (:inst Seq a)) ...)
     body
     var-alist
     abstract-name)
  (declare (xargs :mode :program))
  ``(progn
      ,@(remove-duplicates
         (type-inst-prereqs-defun
          ',typed-variables
          ',var-alist
          (list ',name))
          :test 'equal)
      ,@(remove-duplicates
         (type-inst-prereqs-defun
          ',body
          ',var-alist
          (list ',name))
          :test 'equal)
      (defthm-typed ,',(appsyms `(,name ,@type-actuals))
          ,',(replace-inst typed-variables var-alist nil)
        ,',@(replace-inst body var-alist nil)
        :hints (("Goal"
                 :do-not-induct t
                 :in-theory (enable 
                             ,',@(remove-duplicates
                                  (function-theory-prereqs
                                   typed-variables
                                   var-alist
                                   nil)))
                 :use ((:functional-instance
                        ,',abstract-name
                        ,@(zip-lists ',type-vars ',type-actuals ',name)
                        ,@(append
                           ,@(collect-functional-instance-subs
                              (cons typed-variables body)
                              (constrained-type-var-names
                               type-vars
                               name)
                              type-actuals
                              nil)))))))))

;;;;;;;;;;;;;;;;;;;;;;;
;; defthm-typed-poly ;;
;;;;;;;;;;;;;;;;;;;;;;;

(defun defthm-typed-poly-fn (name type-vars typed-variables body)
  (declare (xargs :mode :program))
  (let ((var-alist (make-alist type-vars (constrained-type-var-names
                                          type-vars
                                          name)))
        (abstract-name (appsyms `(,name ,@(constrained-type-var-names
                                           type-vars
                                           name)))))
    `(progn
       ,@(constrained-type-vars type-vars name)
       ,@(remove-duplicates
          (append (type-inst-prereqs-defun typed-variables var-alist (list name))
                  (type-inst-prereqs-defun body  var-alist (list name)))
          :test 'equal)
       (defthm-typed ,(appsyms `(,name ,@(constrained-type-var-names 
                                          type-vars
                                          name)))
           ,(replace-inst typed-variables var-alist nil)
         ,@(replace-inst body var-alist nil))
       (defmacro ,(appsyms `(,name instantiate)) ,type-vars
         (let ((var-alist (make-alist ',type-vars (list ,@type-vars)))
               (functional-subs (collect-functional-instance-subs
                                 ',(cons typed-variables body)
                                 ',(constrained-type-var-names
                                    type-vars
                                    name)
                                 (list ,@type-vars)
                                 nil)))

           `(make-event
             ,(instance-defthm
               ',name; of original theorem
               ',type-vars
               (list ,@type-vars)
               ',typed-variables;  ((x (:inst Seq a)) ...)
               ',body
               var-alist
               ',abstract-name)))))))

             

(defmacro defthm-typed-poly (name type-vars typed-variables &rest body)
  (defthm-typed-poly-fn name type-vars typed-variables body))

;;;;;;;;;;;;;;;;;;
;; DEFTHM-TYPED ;;
;;;;;;;;;;;;;;;;;;

(defun defthm-typed-fn (name rst)
  (if (and (consp rst)
           (consp (cdr rst))
           (eq (car rst) ':type-vars))
      `(defthm-typed-poly ,name ,(cadr rst) ,@(cddr rst))
      `(defthm-typed-concrete ,name ,@rst)))

(defmacro defthm-typed (name &rest rst)
  (defthm-typed-fn name rst))

(defmacro defthmd-typed (name &rest rst)
  `(progn (defun-typed ,name ,@rst)
          (in-theory (disable ,name))))

;;;;;;;;;;;;;;
;; BUILTINS ;;
;;;;;;;;;;;;;;

(defpredicate Bool-p (x) (booleanp x))
(defpredicate Int-p (x) (integerp x))
(defpredicate Nat-p (x) (natp x))
(defpredicate String-p (x) (stringp x))

;;;;;;;;;
;; OLD ;;
;;;;;;;;;

;(defun type-constraint-name (name)
;  (intern (string-append (string name) "-TYPE-CONSTRAINT") "ACL2"))

;; (mutual-recursion
;;  (defun match-conditions (pattern var-name)
;;    (declare (xargs :mode :program))
;;    (cond ((atom pattern) nil)
;;          ((equal (cadr pattern) '@)
;;           (cons (list (add-p-to-name (caddr pattern)) var-name)
;;                 (subterm-match-conditions-1 (caddr pattern)
;;                                             (cdddr pattern)
;;                                             var-name
;;                                             1)))
;;          (t
;;           (cons (list (add-p-to-name (car pattern)) var-name)
;;                 (subterm-match-conditions-1 (car pattern) 
;;                                             (cdr pattern) 
;;                                             var-name 
;;                                             1)))))

;;  (defun subterm-match-conditions-1 (constructor-name arg-patterns var-name n)
;;    (declare (xargs :mode :program))
;;    (cond ((atom arg-patterns) nil)
;;          (t (append (match-conditions 
;;                      (car arg-patterns)
;;                      (list (hyphenate-symbols 
;;                             (list constructor-name
;;                                   (intern (string-append 
;;                                            "ARG"
;;                                            (integer-to-string n))
;;                                           "ACL2")))
;;                            var-name))
;;                     (subterm-match-conditions-1 constructor-name
;;                                                 (cdr arg-patterns)
;;                                                 var-name
;;                                                 (1+ n)))))))

;; (defun match-condition (pattern var-name)
;;   (declare (xargs :mode :program))
;;   (cons 'and (match-conditions pattern var-name)))

;; (mutual-recursion
;;  (defun bindings (pattern term)
;;    (cond ((equal pattern '_) nil)
;;          ((symbolp pattern) (list (list pattern term)))
;;          ((atom pattern) nil)
;;          ((equal (cadr pattern) '@)
;;           (cons (list (car pattern) term) 
;;                 (subterm-bindings-1 (caddr pattern) 
;;                                     (cdddr pattern) 
;;                                     term 
;;                                     1)))
;;          (t (subterm-bindings-1 (car pattern) (cdr pattern) term 1))))

;;  (defun subterm-bindings-1 (constructor-name arg-patterns var-name n)
;;    (declare (xargs :mode :program))
;;    (cond ((atom arg-patterns) nil)
;;          (t (append (bindings 
;;                      (car arg-patterns)
;;                      (list (hyphenate-symbols 
;;                             (list constructor-name
;;                                   (intern (string-append 
;;                                            "ARG"
;;                                            (integer-to-string n))
;;                                           "ACL2")))
;;                            var-name))
;;                     (subterm-bindings-1 constructor-name
;;                                         (cdr arg-patterns)
;;                                         var-name
;;                                         (1+ n)))))))

;; (defun case-to-cond-1 (var-name cases)
;;   (declare (xargs :mode :program))
;;   (cond ((atom cases) nil)
;;         (t 
;;          (let* ((pattern (caar cases))
;;                 (term (cadar cases)))
;;            (cons (list
;;                   (match-condition pattern var-name)
;;                   (let ((b (bindings pattern var-name)))
;;                     (if (atom b)
;;                         term
;;                         (list 'let (bindings pattern var-name) term))))
;;                  (case-to-cond-1 var-name (cdr cases)))))))

;; (defun case-to-cond (var-name cases)
;;   (declare (xargs :mode :program))
;;   (cons 'cond (case-to-cond-1 var-name cases)))

;; (defun case-to-cond-macro (term)
;;   (declare (xargs :mode :program))
;;   (cond ((atom term) term)
;;         ((equal (car term) 'case-of)
;;          (case-to-cond (cadr term) (cddr term)))
;;         (t term)))


;(defun add-type-union-to-name (name)
;  (intern (string-append (string name) "-TYPE-UNION") "ACL2"))

;; (mutual-recursion 

;;  (defun coproduct-measure (x)
;;    (cond ((atom x) 0)
;;          (t (+ 1 (sum-coproduct-measure (cdr x))))))

;;  (defun sum-coproduct-measure (xs)
;;    (cond ((atom xs) 0)
;;          (t (+ (coproduct-measure (car xs))
;;                (sum-coproduct-measure (cdr xs)))))))

;; (defun nthcdr-macro (n x)
;;   (if (zp n)
;;       x
;;       (list 'cdr (nthcdr-macro (1- n) x))))

;; (defmacro nthcdr-ex (n x)
;;   (nthcdr-macro n x))

;; (defun type-case-macro-1 (rst n)
;;   (if (atom rst)
;;       (list (list 'equal (list 'nthcdr-ex n 'data) 'nil))
;;       (cond ((equal (car rst) ':all)
;;              (cons (list 'consp (list 'nthcdr-ex n 'data))
;;                    (type-case-macro-1 (cdr rst) (1+ n))))
;;             ((atom (car rst))
;;              (append (list (list 'consp (list 'nthcdr-ex n 'data))
;;                            (list (car rst) 
;;                                  (list 'car (list 'nthcdr-ex n 'data))))
;;                      (type-case-macro-1 (cdr rst) (1+ n))))
;;             ((equal (caar rst) ':all)
;;              (cons (list 'consp (list 'nthcdr-ex n 'data))
;;                    (type-case-macro-1 (cdr rst) (1+ n))))
;;             (t
;;              (append (list (list 'consp (list 'nthcdr-ex n 'data))
;;                            (list (caar rst) 
;;                                  (list 'car (list 'nthcdr-ex n 'data))))
;;                      (type-case-macro-1 (cdr rst) (1+ n)))))))

;; ;; Produces a list of requirements for a type case.
;; ;; Omits the "consp" requirement, as that always has to be at the top level.
;; (defun type-case-macro (constructor-name rst-type-case)
;;   (append (list 'and 
;;                 (list 'equal 
;;                       (list 'car 'data)
;;                       (list 'quote constructor-name)))
;;           (type-case-macro-1 rst-type-case 1)))

;; ;; Given the list of type-cases, gives a list of the requirements for each type
;; ;; case. This is not a valid term by itself; it is to be or-ed for the type
;; ;; definition.
;; (defun map-type-case-macro (type-cases)
;;   (if (atom type-cases)
;;       nil
;;       (cons (type-case-macro (caar type-cases) (cdar type-cases))
;;             (map-type-case-macro (cdr type-cases)))))

;; ;; Given a type case name and the list of type requirements for its arguments,
;; ;; produces the type case recognizer for that particular case.
;; (defun type-case-def-macro (constructor-name rst-type-case)
;;   (list 'defpredicate
;;         (add-p-to-name constructor-name)
;;         (list 'data)
;;         (append (list 'and
;;                       (list 'consp 'data)
;;                       (list 'equal
;;                             (list 'car 'data)
;;                             (list 'quote constructor-name)))
;;                 (type-case-macro-1 rst-type-case 1))))

;; ;; Given the list of type-cases, gives a list of "defun-typed"s, a recognizer
;; ;; function for each individual case.
;; (defun map-type-case-def-macro (type-cases)
;;   (if (atom type-cases)
;;       nil
;;       (cons (type-case-def-macro (caar type-cases) (cdar type-cases))
;;             (map-type-case-def-macro (cdr type-cases)))))

;; ;; Given the overall type-name, the constructor-name, and the list of type
;; ;; requirements for this type case, produces a defun-typed for the constructor
;; ;; of this type case.
;; (defun construct-type-case-macro (type-name constructor-name rst-type-case)
;;   (list 'defun-typed
;;         (list (add-p-to-name type-name) constructor-name)
;;         rst-type-case
;;         (append (list 'list
;;                       `(quote ,constructor-name))
;;                 (get-args rst-type-case))))

;; ;; Maps construct-type-case-macro over the type-cases for this type.
;; (defun map-construct-type-case-macro (type-name type-cases)
;;   (if (atom type-cases)
;;       nil
;;       (cons (construct-type-case-macro type-name (caar type-cases) (cdar type-cases))
;;             (map-construct-type-case-macro type-name (cdr type-cases)))))

;; ;; Given a type case name, an argument name, an argument type, and the position
;; ;; of the argument in the type case, produces a destructor for that particular
;; ;; argument.
;; (defun type-destructor-macro (type-case-name arg-name arg-type n)
;;   (list 'defun-typed
;;         (list arg-type arg-name)
;;         (list (list (add-p-to-name type-case-name) 'data))
;;         (list 'car (list 'nthcdr-ex n 'data))))

;; (defun type-case-destructors-macro-1 (case-type rst n)
;;   (cond ((atom rst) nil)
;;         (t (cons (type-destructor-macro case-type
;;                                         (cadar rst)
;;                                         (caar rst)
;;                                         n)
;;                  (type-case-destructors-macro-1 case-type
;;                                                 (cdr rst)
;;                                                 (1+ n))))))

;; ;; Given the type case name and the list of args for the type case, produces a
;; ;; list of destructor definitions for each arg in the type case.
;; (defun type-case-destructors-macro (type-case-name rst-type-case)
;;   (type-case-destructors-macro-1 type-case-name rst-type-case 1))

;; ;; Given a list of type-cases, produces a list of destructor definitions for
;; ;; each argument, for each type case.
;; (defun destructors-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (append (type-case-destructors-macro (caar type-cases)
;;                                                 (cdar type-cases))
;;                    (destructors-macro (cdr type-cases))))))

;; (defun decons-cons-macro (deconstructor-name constructor-name rst-type-case)
;;   (list 'defthm-guarded
;;         (hyphenate-symbols (list deconstructor-name constructor-name))
;;         (list 'implies 
;;               (get-type-constraint rst-type-case)
;;               (list 'equal
;;                     (list deconstructor-name
;;                           (cons constructor-name
;;                                 (get-args rst-type-case)))
;;                     deconstructor-name))))

;; (defun type-case-decons-cons-macro-1 (constructor-name
;;                                       type-case-args rst-type-case-args)
;;   (cond ((atom rst-type-case-args) nil)
;;         (t (cons (decons-cons-macro (cadar rst-type-case-args)
;;                                     constructor-name
;;                                     type-case-args)
;;                  (type-case-decons-cons-macro-1 constructor-name type-case-args
;;                                                 (cdr rst-type-case-args))))))

;; (defun type-case-decons-cons-macro (type-case)
;;   (type-case-decons-cons-macro-1 (car type-case)
;;                                  (cdr type-case)
;;                                  (cdr type-case)))

;; (defun type-decons-cons-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (append (type-case-decons-cons-macro (car type-cases))
;;                    (type-decons-cons-macro (cdr type-cases))))))

;; (defun pair-list-with-atom (lst atm)
;;   (if (atom lst)
;;       nil
;;       (cons (list (car lst) atm) (pair-list-with-atom (cdr lst) atm))))

;; (defun cons-decons-macro (constructor-name rst-type-case)
;;   (list 'defthm-guarded
;;         (if (atom rst-type-case)
;;             (hyphenate-symbols (list constructor-name 'one))
;;             (hyphenate-symbols (cons constructor-name
;;                                      (get-args rst-type-case))))
;;         (list 'implies
;;               (list (add-p-to-name constructor-name) 'data)
;;               (list 'equal
;;                     (cons constructor-name
;;                           (pair-list-with-atom 
;;                            (get-args rst-type-case)
;;                            'data))
;;                     'data))))

;; (defun map-cons-decons-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (cons (cons-decons-macro (caar type-cases) (cdar type-cases))
;;                  (map-cons-decons-macro (cdr type-cases))))))

;; (defun constructor-is-type-macro (type-name constructor-name)
;;   (list 'defthm
;;         (hyphenate-symbols (list constructor-name
;;                                  'is
;;                                  type-name))
;;         (list 'implies 
;;               (list (add-p-to-name constructor-name) 'data)
;;               (list (add-p-to-name type-name) 'data))
;;         ':rule-classes ':tau-system))

;; (defun map-constructor-is-type-macro (type-name type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (cons (constructor-is-type-macro type-name (caar type-cases))
;;                  (map-constructor-is-type-macro type-name (cdr type-cases))))))

;; ;; Destructor-measure-theorems
;; (defun destruct-measure-macro (constructor-name destructor-name)
;;   (list 'defthm
;;         (hyphenate-symbols (list destructor-name 'acl2-count))
;;         (list 'implies
;;               (list (add-p-to-name constructor-name) 'data)
;;               (list '< 
;;                     (list 'acl2-count (list destructor-name 'data))
;;                     (list 'acl2-count 'data)))))

;; (defun type-case-destruct-measure-macro (constructor-name rst-type-case)
;;   (cond ((atom rst-type-case) nil)
;;         (t (cons (destruct-measure-macro constructor-name (cadar rst-type-case))
;;                  (type-case-destruct-measure-macro constructor-name 
;;                                                    (cdr rst-type-case))))))

;; (defun map-type-case-destruct-measure-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (append (type-case-destruct-measure-macro (caar type-cases)
;;                                                      (cdar type-cases))
;;                    (map-type-case-destruct-measure-macro (cdr type-cases))))))

;; ;; One-hot theorems
;; (defun not-all-elim-macro (x)
;;   (cond ((atom x) nil)
;;         (t (cons (list 'not (list (add-p-to-name (car x)) 'data)) 
;;                  (not-all-elim-macro (cdr x))))))

;; (defun type-case-elim-macro (type-name constructor-name
;;                              other-constructor-names)
;;   (list 'defthm-guarded
;;         (hyphenate-symbols (list type-name constructor-name 'elim))
;;         (list 'implies 
;;               (append (list 'and
;;                             (list (add-p-to-name type-name) 'data))
;;                       (not-all-elim-macro other-constructor-names))
;;               (list (add-p-to-name constructor-name) 'data))))

;; (defun map-type-case-elim-macro-1 (type-name rst-constructor-names
;;                                    constructor-names)
;;   (cond ((atom rst-constructor-names) nil)
;;         (t (cons (type-case-elim-macro type-name 
;;                                        (car rst-constructor-names)
;;                                        (remove (car rst-constructor-names)
;;                                                constructor-names))
;;                  (map-type-case-elim-macro-1 type-name
;;                                              (cdr rst-constructor-names)
;;                                              constructor-names)))))

;; (defun map-type-case-elim-macro (type-name constructor-names)
;;   (map-type-case-elim-macro-1 type-name constructor-names constructor-names))

;; (defun cars (l)
;;   (cond ((atom l) nil)
;;         (t (cons (caar l) (cars (cdr l))))))

;; ;; constructorp-constructor

;; (defun constructorp-constructor-macro (constructor-name rst-type-case)
;;   (list 'defthm-guarded 
;;         (hyphenate-symbols (list (add-p-to-name constructor-name) 
;;                                  constructor-name))
;;         (list 'implies
;;               (get-type-constraint rst-type-case)
;;               (list (add-p-to-name constructor-name)
;;                     (cons constructor-name (get-args rst-type-case))))))

;; (defun map-constructorp-constructor-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (cons (constructorp-constructor-macro (caar type-cases)
;;                                                  (cdar type-cases))
;;                  (map-constructorp-constructor-macro (cdr type-cases))))))

;; ;; type cases don't overlap
;; (defun not-constructorp-constructor-macro (not-constructor-name
;;                                            constructor-name rst-type-case)
;;   (list 'defthm-guarded
;;         (hyphenate-symbols (list constructor-name
;;                                  'not 
;;                                  (add-p-to-name not-constructor-name)))
;;         (list 'implies
;;               (get-type-constraint rst-type-case)
;;               (list 'not (list (add-p-to-name not-constructor-name)
;;                                (cons constructor-name (get-args
;;                                                        rst-type-case)))))))

;; (defun map-not-constructorp-constructor-macro (not-constructor-names
;;                                                constructor-name rst-type-case)
;;   (cond ((atom not-constructor-names) nil)
;;         (t (cons (not-constructorp-constructor-macro 
;;                   (car not-constructor-names)
;;                   constructor-name rst-type-case)
;;                  (map-not-constructorp-constructor-macro
;;                   (cdr not-constructor-names)
;;                   constructor-name rst-type-case)))))

;; (defun map-map-not-constructorp-constructor-macro-1 (constructor-names
;;                                                      type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (append (map-not-constructorp-constructor-macro
;;                     (remove (caar type-cases) constructor-names)
;;                     (caar type-cases)
;;                     (cdar type-cases))
;;                    (map-map-not-constructorp-constructor-macro-1
;;                     constructor-names (cdr type-cases))))))

;; (defun map-map-not-constructorp-constructor-macro (type-cases)
;;   (map-map-not-constructorp-constructor-macro-1 (cars type-cases) type-cases))

;; (defun arity-0-uniqueness-macro (constructor-name)
;;   (list 'defthm
;;         (hyphenate-symbols (list constructor-name 'unique))
;;         (list 'implies
;;               (list (add-p-to-name constructor-name) 'data1)
;;               (list 'equal 'data1 (list constructor-name)))
;;         ':rule-classes ':forward-chaining))

;; (defun map-arity-0-uniqueness-macro (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (if (consp (cdar type-cases))
;;                (map-arity-0-uniqueness-macro (cdr type-cases))
;;                (cons (arity-0-uniqueness-macro (caar type-cases))
;;                      (map-arity-0-uniqueness-macro (cdr type-cases)))))))

;; (defun typep-consp (type-name)
;;   (list 'defthm 
;;         (hyphenate-symbols (list (add-p-to-name type-name)
;;                                  'consp))
;;         (list 'implies
;;               (list (add-p-to-name type-name) 'data)
;;               (list 'consp 'data))))

;; (defun get-predicates-1 (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (cons (add-p-to-name (caar type-cases))
;;                  (get-predicates-1 (cdr type-cases))))))

;; (defun get-predicates (type-name type-cases)
;;   (cons (add-p-to-name type-name)
;;         (get-predicates-1 type-cases)))

;; (defun get-constructors (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (cons (caar type-cases) (get-constructors (cdr type-cases))))))

;; (defun get-destructors-type-case (rst-type-case)
;;   (cond ((atom rst-type-case) nil)
;;         (t (cons (cadar rst-type-case) 
;;                  (get-destructors-type-case (cdr rst-type-case))))))

;; (defun get-destructors (type-cases)
;;   (cond ((atom type-cases) nil)
;;         (t (append (get-destructors-type-case (cdar type-cases))
;;                    (get-destructors (cdr type-cases))))))

;; (defmacro defcoproduct-explicit-destructor-names (type &rest type-cases)
;;   (append 
;;    (list 'progn
;;          (list 'defpredicate
;;                (add-p-to-name type)
;;                (list 'data)
;;                (list 'and
;;                      (list 'consp 'data)
;;                      (cons 'or (map-type-case-macro type-cases)))))
;;    (list (typep-consp type))
;;    (map-type-case-def-macro type-cases)
;;    (map-constructor-is-type-macro type type-cases)
;;    (map-construct-type-case-macro type type-cases)
;;    (destructors-macro type-cases)
;;    (type-decons-cons-macro type-cases)
;;    (map-cons-decons-macro type-cases)
;;    (map-type-case-destruct-measure-macro type-cases)
;;    (map-type-case-elim-macro type (cars type-cases))
;;    (map-constructorp-constructor-macro type-cases)
;;    (map-map-not-constructorp-constructor-macro type-cases)
;;    (map-arity-0-uniqueness-macro type-cases) ;; TODO: generalize this
;;    (list (list 'deftheory
;;                (hyphenate-symbols (list type 'types))
;;                (list 'quote (get-predicates type type-cases))))
;;    (list (list 'deftheory
;;                (hyphenate-symbols (list type 'constructors))
;;                (list 'quote (get-constructors type-cases))))
;;    (list (list 'deftheory
;;                (hyphenate-symbols (list type 'destructors))
;;                (list 'quote (get-destructors type-cases))))
;;    (list (list 'in-theory 
;;                (list 'disable (hyphenate-symbols 
;;                                (list type 'types)))))
;;    (list (list 'in-theory 
;;                (list 'disable (hyphenate-symbols 
;;                                (list type 'constructors)))))
;;    (list (list 'in-theory 
;;                (list 'disable (hyphenate-symbols 
;;                                (list type 'destructors)))))))


;; Library lemmas:

(defthmd split-equal
    (implies (and (booleanp x)
                  (booleanp y))
             (equal (equal x y)
                    (and (implies x y)
                         (implies y x)))))

;;fixme make this into a specware lemma (generalize?!)
(defthm cancel_ones
    (implies (and (natp x) (natp y))
             (equal (< (+ 1 x)
                       (+ 1 y))
                    (< x y)))
  :hints (("Goal" :in-theory (enable split-equal))))

;; ;;This could be expensive.
;; ;;It was needed for a guard conjecture, presumably because we used <, which expects rationals.
;; ;;we almost want the obligation to be tighter (natp) rather than the weaker rationalp, because we have rules about thins returning rationals.
;;   (defthm rationalp-when-natp
;;     (implies (natp x)
;;              (rationalp x)))
