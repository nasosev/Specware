;;;-*- Mode: fi:common-lisp ; Package: USER ; Base: 10; Syntax: common-lisp  -*-
;;;-------------------------------------------------------------------------
;;;               Copyright (C) 2003 by Kestrel Technology
;;;                          All Rights Reserved
;;;-------------------------------------------------------------------------
xd

(in-package :user)


(eval-when (compile load)
  (require :jlinker)
  (require :jlinkent)
  (use-package :javatools.jlinker))

(defun print-result (arg)
  (format t "~% Connection to Java ~A" arg)
  t)

(defun kill-some-processes ()
  (dolist (p sys:*all-processes*)
    (when (y-or-n-p "Kill ~a (y or n)" (mp:process-name p))
      (mp:process-kill p)))
  (values))

(defun java-listener-running-p ()
  (loop for process in sys::*all-processes* 
      for name = (mp::process-name process)
      if (search  "LinkerListener" name)
      do (return t)
      finally (return nil)))

(defun init-java-listener () 
  (when (and (not (javatools.jlinker::jlinker-query))
	     (not (java-listener-running-p)))
    ;(excl::current-directory "planware:java-ui;")
    ;(excl::set-current-working-directory  "planware:java-ui;")
    ;(setq *default-pathname-defaults* "planware:java-ui;")
    (load (concatenate 'string specware::Specware4 "/Gui/src/edu/kestrel/netbeans/lisp/jl-config.cl")) 
    (jlinker-listen :process-function #'print-result
		    :init-args '(:lisp-file nil
				 :lisp-host "localhost"
				 :lisp-port 4321
				 :verbose t))))

;(excl::chdir "planware:java-ui;")
(init-java-listener)
