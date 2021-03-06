
(defpackage :SpecToLisp)
(defpackage :Integer-Spec)
(defpackage :Integer_)
(defpackage :IntegerAux)
(defpackage :Nat-Spec)
(defpackage :Specware)
(in-package :Integer-Spec)

(defvar SpecToLisp::SuppressGeneratedDefuns nil) ; note: defvar does not redefine if var already has a value

(setq SpecToLisp::SuppressGeneratedDefuns
 (append '("Integer-Spec::ipred"
           "Integer-Spec::one"
           "Integer-Spec::positive?"
           "IntegerAux::|!-|"
           "Integer-Spec::|!+|"
           "Integer-Spec::+-2"
           "Nat-Spec::|!+|"
           "Nat-Spec::+-2"
           "Integer-Spec::|!-|"
           "Integer-Spec::--2"
           "Integer-Spec::|!*|"
           "Integer-Spec::*-2"
           "Nat-Spec::|!*|"
           "Nat-Spec::*-2"
           "Integer-Spec::|!**|"
           "Integer-Spec::**-2"
           "Integer-Spec::|!<|"
           "Integer-Spec::<-2"
           "Integer-Spec::|!<=|"
           "Integer-Spec::<=-2"
           "Integer-Spec::|!>|"
           "Integer-Spec::>-2"
           "Integer-Spec::|!>=|"
           "Integer-Spec::>=-2"
           "Integer-Spec::isucc"
           "Integer-Spec::ipred"
           "Nat-Spec::succ"
           "Nat-Spec::pred"
           "Integer-Spec::divides"
           "Integer-Spec::divides-2"
           "Integer-Spec::|!gcd|"
           "Integer-Spec::gcd-2"
           "Integer-Spec::|!lcm|"
           "Integer-Spec::lcm-2"
           "Integer-Spec::|!/|"
           "Integer-Spec::/-2"
           "Integer-Spec::divT"
           "Integer-Spec::divT-2"
           "Integer-Spec::modT"
           "Integer-Spec::modT-2"
           "Integer-Spec::divF"
           "Integer-Spec::divF-2"
           "Integer-Spec::modF"
           "Integer-Spec::modF-2"
           "Integer-Spec::divC"
           "Integer-Spec::divC-2"
           "Integer-Spec::divR"
           "Integer-Spec::divR-2"
           "Integer-Spec::divE"
           "Integer-Spec::divE-2"
           "Integer-Spec::modE"
           "Integer-Spec::modE-2"
           "Integer-Spec::div"
           "Integer-Spec::div-2"
           "Integer-Spec::|!mod|"
           "Integer-Spec::mod-2"
)
          SpecToLisp::SuppressGeneratedDefuns))


;;; For each binary op, there are two Lisp functions. One takes two arguments,
;;; the other takes one argument that is a pair. In MetaSlang, there is no such
;;; distinction: all ops are really unary, from a domain type D to a codomain
;;; type C, where D can be a product, e.g. A * B, in which case the op can be
;;; "viewed" as being binary. These double variants match Specware's Lisp code
;;; generator, which generates two variants for ops whose domain is a product:
;;; one that takes one argument for each factor, and the other that takes just
;;; one argument that is a tuple. The naming convention is that the variant that
;;; takes just one argument has the name directly derived from the op name from
;;; which it is generated, while the variant that takes n arguments (n > 1) has
;;; that name with a "-n" suffix.

;;; The define-compiler-macro definitions are necessary to get efficient
;;; arithmetic.


;;; mechanism for allowing the user to declare global restrictions on integers:
(eval-when (compile load)
 (defvar Specware::*integer-impl* 'integer))

(defmacro the-int (x)
 `(the ,Specware::*integer-impl* ,x))

(defconstant zero 0)

(defun isucc (x) (+ x 1))

(define-compiler-macro isucc (x) `(the-int (+ (the-int ,x) 1)))

(defun ipred (x) (- x 1))

(define-compiler-macro ipred (x) `(the-int (- (the-int ,x) 1)))

(defparameter one 1)

(defun positive? (x) (> x 0))

(defun IntegerAux::|!-| (x)
 (declare (integer x))
 (the-int (- 0 x)))

(defun |!+| (xy)
 (declare (cons xy))
 (the-int (+ (the-int (car xy)) (the-int (cdr xy)))))

(defun +-2 (x y)
 (declare (integer x y))
 (the-int (+ x y)))

(define-compiler-macro +-2 (x y)
 `(the-int (+ (the-int ,x) (the-int ,y))))

(defun Nat-Spec::|!+| (xy)
 (declare (cons xy))
 (the-int (+ (the-int (car xy)) (the-int (cdr xy)))))

(defun Nat-Spec::+-2 (x y)
 (declare (integer x y))
 (the-int (+ x y)))

(define-compiler-macro Nat-Spec::+-2 (x y)
 `(the-int (+ (the-int ,x) (the-int ,y))))

(defun |!-| (xy)
 (declare (cons xy))
 (the-int (- (the-int (car xy)) (the-int (cdr xy)))))

(defun --2 (x y)
 (declare (integer x y))
 (the-int (- x y)))

(define-compiler-macro --2 (x y)
 `(the-int (- (the-int ,x) (the-int ,y))))

(defun |!*| (xy)
 (declare (cons xy))
 (the-int (* (the-int (car xy)) (the-int (cdr xy)))))

(defun *-2 (x y)
 (declare (integer x y))
 (the-int (* x y)))

(define-compiler-macro *-2 (x y)
 `(the-int (* (the-int ,x) (the-int ,y))))

(defun Nat-Spec::|!*| (xy)
 (declare (cons xy))
 (the-int (* (the-int (car xy)) (the-int (cdr xy)))))

(defun Nat-Spec::*-2 (x y)
 (declare (integer x y))
 (the-int (* x y)))

(define-compiler-macro Nat-Spec::*-2 (x y)
 `(the-int (* (the-int ,x) (the-int ,y))))

(defun |!**| (xy)
 (declare (cons xy))
 (the-int (expt (the-int (car xy)) (the-int (cdr xy)))))

(defun **-2 (x y)
 (declare (integer x y))
 (the-int (expt x y)))

(define-compiler-macro **-2 (x y)
 `(the-int (expt (the-int ,x) (the-int ,y))))

(defun |!<| (xy)
 (declare (cons xy))
 (< (the-int (car xy)) (the-int (cdr xy))))

(defun <-2 (x y)
 (declare (integer x y))
 (the boolean (< x y)))

(define-compiler-macro <-2 (x y)
 `(< (the-int ,x) (the-int ,y)))

(defun |!<=| (xy)
 (declare (cons xy))
 (<= (the-int (car xy)) (the-int (cdr xy))))

(defun <=-2 (x y)
 (declare (integer x y))
 (the boolean (<= x y)))

(define-compiler-macro <=-2 (x y)
 `(<= (the-int ,x) (the-int ,y)))

(defun |!>| (xy)
 (declare (cons xy))
 (> (the-int (car xy)) (the-int (cdr xy))))

(defun >-2 (x y)
 (declare (integer x y))
 (the boolean (> x y)))

(define-compiler-macro >-2 (x y)
 `(> (the-int ,x) (the-int ,y)))

(defun |!>=| (xy)
 (declare (cons xy))
 (>= (the-int (car xy)) (the-int (cdr xy))))

(defun >=-2 (x y)
 (declare (integer x y))
 (the boolean (>= x y)))

(define-compiler-macro >=-2 (x y)
 `(>= (the-int ,x) (the-int ,y)))

(defun Nat-Spec::succ (x) (+ x 1))

(define-compiler-macro Nat-Spec::succ (x) `(the-int (+ (the-int ,x) 1)))

(defun Nat-Spec::pred (x) (- x 1))

(define-compiler-macro Nat-Spec::pred (x) `(the-int (- (the-int ,x) 1)))

(defun divides (xy)
 (declare (cons xy))
 (divides-2 (car xy) (cdr xy)))

(defun divides-2 (x y)
 (declare (integer x y))
 (the boolean (or (and (eql x 0) (eql y 0))
                  (and (not (eql x 0)) (eql (rem y x) 0)))))

(defun |!gcd| (xy)
 (declare (cons xy))
 (the-int (gcd (the-int (car xy)) (the-int (cdr xy)))))

(defun gcd-2 (x y)
 (declare (integer x y))
 (the-int (gcd x y)))

(define-compiler-macro gcd-2 (x y)
 `(the-int (gcd (the-int ,x) (the-int ,y))))

(defun |!lcm| (xy)
 (declare (cons xy))
 (the-int (lcm (the-int (car xy)) (the-int (cdr xy)))))

(defun lcm-2 (x y)
 (declare (integer x y))
 (the-int (lcm x y)))

(define-compiler-macro lcm-2 (x y)
 `(the-int (lcm (the-int ,x) (the-int ,y))))

(defun |!/| (xy)
 (declare (cons xy))
 (the-int (/-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun /-2 (x y)
 (declare (integer x y))
 (the-int (truncate x y)))

(defun divT (xy)
 (declare (cons xy))
 (the-int (divT-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun divT-2 (x y)
 (declare (integer x y))
 (the-int (truncate x y)))

(defun modT (xy)
 (declare (cons xy))
 (the-int (modT-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun modT-2 (x y)
 (declare (integer x y))
 (the-int (rem x y)))

(defun divF (xy)
 (declare (cons xy))
 (the-int (divF-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun divF-2 (x y)
 (declare (integer x y))
 (the-int (floor x y)))

(defun modF (xy)
 (declare (cons xy))
 (the-int (modF-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun modF-2 (x y)
 (declare (integer x y))
 (the-int (mod x y)))

(defun divC (xy)
 (declare (cons xy))
 (the-int (divC-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun divC-2 (x y)
 (declare (integer x y))
 (the-int (ceiling x y)))

(defun divR (xy)
 (declare (cons xy))
 (the-int (divR-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun divR-2 (x y)
 (declare (integer x y))
 (the-int (round x y)))

(defun divE (xy)
 (declare (cons xy))
 (the-int (divE-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun divE-2 (x y)
 (declare (integer x y))
 (the-int (if (> y 0) (floor x y) (ceiling x y))))

(defun modE (xy)
 (declare (cons xy))
 (the-int (modE-2 (the-int (car xy)) (the-int (cdr xy)))))

(defun modE-2 (x y)
 (declare (integer x y))
 (the-int (- x (* y (divE-2 x y)))))

(defun div (xy)
 (declare (cons xy))
 (the-int (cl:truncate (the-int (car xy)) (the-int (cdr xy)))))

(defun div-2 (x y)
 (declare (integer x y))
 (the-int (cl::truncate x y)))

(define-compiler-macro div-2 (x y)
 `(the-int (cl:truncate (the-int ,x) (the-int ,y))))

(defun |!mod| (xy)
 (declare (cons xy))
 (the-int (cl::mod (the-int (car xy)) (the-int (cdr xy)))))

(defun mod-2 (x y)
 (declare (integer x y))
 (the-int (cl:mod x y)))

(define-compiler-macro mod-2 (x y)
 `(the-int (cl:mod (the-int ,x) (the-int ,y))))

(define-compiler-macro max-2 (x y)
 `(max (the-int ,x) (the-int ,y)))

(define-compiler-macro min-2 (x y)
 `(min (the-int ,x) (the-int ,y)))
