;;; -*- Mode: LISP; Package: Specware; Base: 10; Syntax: Common-Lisp -*-

(in-package :Parser4)

;;; ======================================================================
;;;  Parser interface
;;; ======================================================================

;; parseSpecwareFile                    => parse-file => <parser>
;; parseSpecwareFileMsg                 => parse-file => <parser>
;; parseSpecwareString  => parse-string => parse-file => <parser>
;;
;; parse-file is defined in /Library/Algorithms/Parsing/Chart/Handwritten/Lisp/parse-top.lisp

;;;; now in Library/Algorithms/Parsing/Chart/Handwritten/Lisp/parse-semantics.lisp
;;;; (defvar *parser-source* nil) ; used by make-pos in semantics.lisp

;; Called from $SPECWARE4/Languages/SpecCalculus/Parser/Parse.sw
(defun parseFile (fileName) (parseSpecwareFile fileName)) ; temporary backwards compatibility

(defun parseSpecwareFile (fileName)
  (let* ((*parser-source* (list :file fileName))
	 (session (parse-file fileName *specware4-parser* *specware4-tokenizer* :report-gaps? nil))
	 (raw-results (parse-session-results session))
	 (error? (or (parse-session-error-reported? session) 
		     (parse-session-gaps            session) 
		     (null raw-results))))
    (cond (error?  
	   (when (null raw-results)
	     (format t "~&Syntax error: No term or decls in file ~A~%"
		     fileName))
	   '(:|None|))
	  ;; revised to fix Bug 001: "No error msg when processing files with multiple and un-named specs"
	  ((null (rest raw-results))
	   (let* ((raw-result (first  raw-results))
		  ; (start    (first  raw-result))  
		  ; (end      (second raw-result))  
		  (raw-data   (third  raw-result))  
		  (raw-form   (first  raw-data)))   ; why is raw-data is a 1-element list ?
	     (when-debugging
	      (when (or *verbose?* *show-results?*)
		(format t "~%---parseSpecwareFile pre-evaluation result---~%")
		(pprint raw-form)
		(format t "~%---~%")))
	     (let ((result (eval raw-form)))
	       (cons :|Some| result))))
	  (t
	   (format t "~&Syntax error: ~D top-level forms (as opposed to one term or one sequence of decls) in ~A~%"
		   (length raw-results)
		   fileName)
	   '(:|None|)))))

;; parseString is not called by anything, but is handy for debugging...
(defun parseString (string) (parseSpecwareString string))

(defun parseSpecwareString (string &key start-rule-name) 
  (let* ((*parser-source* (list :string string))
	 (session     (parse-string string *specware4-parser* *specware4-tokenizer* :start-rule-name start-rule-name))
	 (raw-results (parse-session-results session))
	 (error?      (or (parse-session-error-reported? session) 
			  (parse-session-gaps            session) 
			  (null raw-results))))
    (cond (error?
	   (cons :|Error| 
		 (format nil "Syntax error [~{~A~^, ~}] in explicit string.~%" 
			 (append (if (parse-session-error-reported? session) (list "explicit error(s)") nil)
				 (if (parse-session-gaps session) 
				     (let ((n (length (parse-session-gaps session)))) 
				       (list (format nil "~D gap~P" n n)))
				   nil)
				 (if (null raw-results) (list "no result") nil)))))

	  ;; revised per parseSpecwareFile above
	  ((null (rest raw-results))
	   (let* ((raw-result (first  raw-results))
		  ; (start    (first  raw-result))  
		  ; (end      (second raw-result))  
		  (raw-data   (third  raw-result))  
		  (raw-form   raw-data))
	     (when-debugging
	      (when (or *verbose?* *show-results?*)
		(format t "~%---parseSpecwareFile pre-evaluation result---~%")
		(pprint raw-form)
		(format t "~%---~%")))
	     (let ((result (eval raw-form))) ; may refer to *parser-source*
	       (cons :|Some| result))))
	  (t
	   (cons :|Error|
		 (format nil "Syntax error: ~D top-level forms (as opposed to one term or one sequence of decls) in ~A~%"
			 (length raw-results)
			 string))))))

;; Mock string parser based on printing to /tmp, and then parsing.

(defun parse-string (string parser tokenizer &key start-rule-name) 
  (with-open-file (s "/tmp/string-spec" :direction :output :if-exists :supersede)
    (format s "~A" string))
  ;; parse-file is defined in /Library/Algorithms/Parsing/Chart/Handwritten/Lisp/parse-top.lisp
  (let ((*parser-source* (list :string string)))
    (parse-file "/tmp/string-spec" parser tokenizer :start-rule-name start-rule-name :report-gaps? nil)))

