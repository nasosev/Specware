;;; -*- Mode: LISP; Package: User; Base: 10; Syntax: Common-Lisp -*-

(in-package "CL-USER")

(defpackage "PARSER4" (:use "COMMON-LISP"))

(in-package "PARSER4") 

(common-lisp::export '(*VERBOSE?*
		       WHEN-DEBUGGING
		       DEFINE-SW-PARSER-RULE	
		       PARSE-SESSION-GAPS
		       PARSE-SESSION-ERROR-REPORTED?
		       PARSE-SESSION-RESULTS 
		       PARSE-FILE))
