
;; per instructions in swank-loader.lisp
(cl:defpackage :swank-loader
	       (:use :cl)
	       (:export :load-swank 
			:*source-directory*
			:*fasl-directory*))

(defparameter swank-loader::*fasl-directory* 
  (format nil "~a/Library/IO/Emacs/slime/" 
	  (sys:getenv "SPECWARE4")))

(load (format nil "~a/Library/IO/Emacs/slime/swank-loader.lisp"
	      (sys:getenv "SPECWARE4")))

(swank::create-swank-server 4005 :spawn #'swank::simple-announce-function t)

;(sys:with-command-line-arguments (("p" :short port :required))
;  (restvar)
;  (swank::create-swank-server (parse-integer port :junk-allowed nil)
;                              :spawn #'swank::simple-announce-function t))
