... this is not loaded into Specware builds ...
... instead, see ./Library/Legacy/Utilities/Handwritten/Lisp/System.lisp ...

(defpackage :System-Spec)
(in-package :System-Spec)

(defvar System-Spec::specwareDebug? nil)

(defvar System-Spec::proverUseBase? t)

 ;;; op fail     : fa(a) String -> a
(defun fail (s) (break "~a" s))

;;; op debug     : fa(a) String -> a
(defun |!debug| (s) (when specwareDebug? (break "~a" s)))

;;; The following are hacks to print specs more tersely inside anyToString,
;;; which normally should be used only for debugging.

(defun System-Spec::probablyASpec? (x)
  (and ;; (progn (format t "~%Looking for spec....~%") t)
       (typep  x '(simple-vector 4))  
       ;; elements: SpecElements 
       (typep (svref x 0) 'cons)
       ;; ops: OpMap
       (typep (svref x 1) '(SIMPLE-VECTOR 3))
       (typep (svref (svref x 1) 0) 'HASH-TABLE)
       (typep (svref (svref x 1) 1) 'BOOLEAN)
       (typep (svref (svref x 1) 2) 'CONS)
       ;; qualifier: Option Qualifier
       (typep (svref x 2) 'cons)
       ;; types: TypeMap
       (typep (svref x 3) '(SIMPLE-VECTOR 3))
       (typep (svref (svref x 3) 0) 'HASH-TABLE)
       (typep (svref (svref x 3) 1) 'BOOLEAN)
       (typep (svref (svref x 3) 2) 'CONS)))

(defvar *spec-print-terse*  t)
(defvar *spec-print-level*  4)
(defvar *spec-print-length* 40)

(defun anySpecToString (s) 
  (if *spec-print-terse*
      (format nil "<Spec with ~D elements, ~D types, ~D ops, ~A>"
              (length (svref s 0))
              (hash-table-count (svref (svref s 3) 0))
              (hash-table-count (svref (svref s 1) 0))
              (if (eq (car (svref s 2)) :|Some|)
                  (format nil "qualified by " (cddr (svref s 2)))
                  "unqualified"))
      (let* ((common-lisp::*print-level*  *spec-print-level*)
             (common-lisp::*print-length* *spec-print-length*))
        (format nil "~S" s))))

;;; op anyToString : fa(a) a -> String
(defun anyToString (x) 
  (let ((common-lisp::*print-pretty* nil)) 
    (if (probablyASpec? x)
        (anySpecToString x)
        (format nil "~S" x))))

;;; op print    : fa(a) a -> a
(defun |!print| (x) (print x) (force-output))

;;; op warn     : fa(a) String -> a
(defun |!warn| (s) (warn "~a" s))

;;; op time     : fa(a) a -> a
(defmacro |!time| (x) (time x))

;;; op internalRunTime () : Nat
(defun internalRunTime-0 () (GET-INTERNAL-RUN-TIME))

;;; #-Lispworks
;;; (defun getenv (x) (Specware::getenv x))

;; The Lisp getenv returns nil if the name is not in the environment. 
;; Otherwise it returns a string. We want to be able to distinguish
;; the outcomes in MetaSlang

;;; op getEnv : String -> Option String
(defun getEnv (name)
  (let ((val (Specware::getenv name)))
    (if (or (eq val nil) (equal val ""))    ; I think it returns "" if not set
	(cons :|None| nil)
      (cons :|Some| val))))

(defvar msWindowsSystem? #+(or mswindows win32) t #-(or mswindows win32) nil)

;; The same function with the same name, but in a different package is
;; defined in Specware4/Applications/Handwritten/Lisp/load-utilities.lisp
(defun temporaryDirectory-0 ()
  (ensure-final-slash
   (cl:substitute #\/ #\\
		  #+(or win32 winnt mswindows)
		  (or (Specware::getenv "TEMP") (Specware::getenv "TMP")
		      #+allegro
		      (namestring (SYSTEM:temporary-directory)))
		  #+(and (not unix) Lispworks) (namestring SYSTEM::*TEMP-DIRECTORY*)
		  #+(and (not win32) unix) "/tmp/"
		  )))

;; The same function with the same name, but in a different package is
;; defined in Specware4/Applications/Handwritten/Lisp/load-utilities.lisp
(defun ensure-final-slash (dirname)
  (if (member (elt dirname (- (length dirname) 1))
	      '(#\/ #\\))
      dirname
    (concatenate 'string dirname "/")))

;;;  op temporaryDirectory : String
(defparameter temporaryDirectory
    (substitute #\/ #\\ (temporaryDirectory-0)))

;;; op withRestartHandler : fa (a) String * (() -> ()) * (() -> a) -> a
(defun withRestartHandler-3 (restart-msg restart-action body-action)
  (loop
    (let ((results (multiple-value-list 
		    (with-simple-restart (abort restart-msg) 
		      (funcall body-action (vector))))))
      (if (equal results '(nil t))
	  (funcall restart-action (vector))
	(return (values-list results))))))

;;; op garbageCollect : Boolean -> ()
(defun garbageCollect (full?)
  #+allegro (sys::gc full?)
  #+sbcl (sb-ext:gc :full full?)
  #+(and cmu (not darwin)) (ext:gc :full full?)
  #+(and cmu darwin) (when full? (ext:gc)))

;; hackMemory essentially calls (room nil) in an attempt to appease 
;; Allegro CL into not causing mysterious storage conditions during 
;; the bootstrap. (sigh)  
;; Calling (gc nil) and (gc t) both failed to have the desired effect.

;;; op hackMemory     : ()      -> ()
(defun hackMemory-0 ()
  ;; (sys::room nil)
  )

;;; op trueFilename : String -> String 
(defun trueFilename (filename)
  (let* ((given-pathname (pathname filename))
	 (resolved-pathname
	  #+Allegro
	  (excl::pathname-resolve-symbolic-links given-pathname)
	  #-Allegro
	  (truename given-pathname)
	  ))
    (namestring resolved-pathname)))

;;; op trueFilePath : List String * Boolean -> List String
(defun trueFilePath-2 (path relative?)
  (let* ((rpath (reverse path))
	 (name (first rpath))
	 (dir  (cons (if relative? :relative :absolute)
		     (reverse (rest rpath))))
	 (given-pathname (make-pathname :directory dir :name name))
	 (resolved-pathname
	  #+Allegro
	  (excl::pathname-resolve-symbolic-links given-pathname)
	  #-Allegro
	  (truename given-pathname)
	  ))
    (append (rest (pathname-directory resolved-pathname))
	    (list (pathname-name resolved-pathname)))))

