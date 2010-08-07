(defpackage :Emacs)
(defpackage :AnnSpecPrinter)
(defpackage :String-Spec)
(defpackage :MetaSlang)
(defpackage :Script)
(defpackage :MetaSlangRewriter)
(defpackage :Specware)
(defpackage :SWShell)
(in-package :SWShell)

(defvar *transform-help-strings* '(("at" . "[op] Focuses on definition of op")
				   ("move" . "[f l n p w a s r] Focus on neighboring expressions (first last next previous widen all search reverse-search)")
				   ("m" . "Abbreviation for move")
				   ("simplify" . "[rules] Applies rewriting simplifier with supplied rules.")
				   ("fold" . "[op] folds first occurrence of definition of op")
				   ("unfold" . "[op] unfolds first occurrence of op")
                                   ("rewrite" . "[op] does single rewrite using definition of op as a rewrite rule")
				   ("lr" . "[thm] Applies theorem as a rewrite in left-to-right direction")
				   ("rl" . "[thm] Applies theorem as a rewrite in right-to-left direction")
				   ("simp-standard" . "Applies standard simplifier")
				   ("ss" . "Applies standard simplifier")
				   ("partial-eval" . "Evaluate closed sub-expressions")
				   ("pe" . "Evaluate closed sub-expressions")
				   ("abstract-cse" . "Abstract Common Sub-Expressions")
				   ("cse" . "Abstract Common Sub-Expressions")
				   ("pc"   . "Print current expression")
				   ("proc" . "[unit-term} Restart transformation on processed spec")
				   ("p" . "[unit-term} Restart transformation on processed spec")
				   ("trace-rewrites" . "Print trace for individual rewrites")
				   ("trr" . "Print trace for individual rewrites")
				   ("untrace-rewrites" . "Turn off printing trace for individual rewrites")
				   ("untrr" . "Turn off printing trace for individual rewrites")
				   ("undo" . "[n] Undo n levels (1 with no argument)")
				   ("done" . "Print script and return to normal shell")
				   ))


(defvar *transform-spec*)
(defvar *transform-specunit-Id*)
(defvar *transform-term*)		; Actually a pair of current term and its parent
(defvar *transform-commands*)
(defvar *undo-stack*)
(defvar *redos*)
(defvar *redoing?* nil)

(defun initialize-transform-session (spc)
  (setq *transform-spec* spc)
  (setq *transform-specunit-Id* cl-user::*last-unit-Id-_loaded*)
  (setq *transform-term* nil)
  (setq *transform-commands* nil)
  (setq *undo-stack* nil)
  (setq *prompt* "** ")
  (Emacs::eval-in-emacs "(setq *sw-slime-prompt* \"** \")"))

(defun push-state (command)
  (unless *redoing?*
    (setq *redos* nil))
  (push (list *transform-term* *transform-commands* *transform-spec* command) *undo-stack*))

(defvar *print-undone-commands* t)

(defun pop-state ()
  (let ((last-state (pop *undo-stack*)))
    (setq *transform-term* (first last-state))
    (setq *transform-commands* (second last-state))
    (setq *transform-spec* (third last-state))
    (push (fourth last-state) *redos*)))

(defun print-current-term (with-types?)
  (if (null *transform-term*)
      (princ "No term chosen")
      (princ (if with-types?
		 (AnnSpecPrinter::printTermWithSorts (car *transform-term*))
		 (AnnSpecPrinter::printTerm (car *transform-term*)))))
  (values))

(defun undo-command (argstr quiet?)
  (if (null *undo-stack*)
      (format t "Nothing to undo!")
      (if (or (null argstr) (equal argstr ""))
	  (pop-state)
	  (if (equal argstr "all")
	      (progn (finish-previous-multi-command)
		     (unless (or quiet? (null *transform-commands*))
		       (Script::printScript (Script::mkSteps (reverse *transform-commands*))))
		     (loop while (not (null *undo-stack*))
			do (pop-state)))
	      (let ((num (read-from-string argstr)))
		(if (and (integerp num) (> num 0))
		    (loop while (and (> num 0) (not (null *undo-stack*)))
		       do (pop-state)
		       (incf num -1))
		    (format t "Illegal undo argument"))))))
  (unless (null *transform-term*)
    (print-current-term nil))
  (values))

(defun command-string (command)
  (case (car command)
    (interpret-command (Script::printScript (second command)))
    (at-command (format t " at ~a~%" (MetaSlang::printQualifiedId (second command))))
    (otherwise "Unknown")))

(defun redo-one-command ()
  (let ((command (pop *redos*))
	(undo-state *undo-stack*))
    (format t "~&Redoing ")
    (command-string command)
    (apply (car command) (cdr command))
    (if (eq undo-state *undo-stack*)
	(progn (format t " failed.") nil)
	t)))

(defun redo-command (argstr)
  (if (null *redos*)
      (format t "Nothing to redo!")
      (let ((*redoing?* t))
	(if (or (null argstr) (equal argstr ""))
	    (redo-one-command)
	    (if (equal argstr "all")
		(loop while (and (not (null *redos*))
				 (redo-one-command)))
		(let ((num (read-from-string argstr)))
		  (if (and (integerp num) (> num 0))
		      (loop while (and (> num 0) (not (null *undo-stack*))
				       (redo-one-command))
			 do (incf num -1))
		      (format t "Illegal undo argument")))))))
  (values))

(defun add-command (command later-commands)
  (if (and (not (null later-commands))
	   (eq (caar later-commands) ':|Move|)
	   (eq (car command) ':|Move|))
      (cons (cons ':|Move| (append (cdr command) (cdar later-commands)))
	    (cdr later-commands))
      (cons command later-commands)))

(defun previous-multi-command (acts)
  (when (null *transform-commands*)
    (error "Multi-step processing command not found!"))
  (let ((prev (pop *transform-commands*)))
    (if (functionp prev)
	(funcall prev acts)
	(previous-multi-command (add-command prev acts)))))

(defun finish-previous-multi-command ()
  (when (and (not (null *transform-commands*))
	     (loop for x in *transform-commands* thereis (functionp x)))
    (let ((prev-result (previous-multi-command nil)))
      (when prev-result
	(setq *transform-spec* (cadar (funcall (Script::interpretSpec-3 *transform-spec*
                                                                        prev-result nil)
                                               nil)))
	(push prev-result *transform-commands*)))))

(defun parse-qid (qid-str op?)
  (let* ((syms (String-Spec::splitStringAt-2 (String-Spec::removeWhiteSpace qid-str) "."))
	 (len (length syms)))
    (if (= len 1)
	(let ((uq_qid (MetaSlang::mkUnQualifiedId (first syms))))
          (if (if op? (Script::findMatchingOps-2 *transform-spec* uq_qid)
                  (Script::matchingTheorems?-2 *transform-spec* uq_qid))
              uq_qid
              (MetaSlang::mkQualifiedId-2 Script::wildQualifier (first syms))))
	(if (= len 2)
	    (MetaSlang::mkQualifiedId-2 (first syms) (second syms))
	    nil))))

(defun interpret-command (command)
  (if (null *transform-term*)
      (princ "No term chosen! (Use \"at\" command)")
      (let* (;(dum (format t "~a\~%~a~%" (car *transform-term*) (cdr *transform-term*)))
             (result (Script::interpretTerm-5 *transform-spec* command
                                              (car *transform-term*)
                                              (cdr *transform-term*)
                                              nil))
             (result (funcall result nil))
             (new-term (cadar result)))
	(if (MetaSlang::equalTerm?-2 (car *transform-term*) (car new-term))
	    (format t "No effect!")
	    (progn 
	      (push-state `(interpret-command ,command))
	      (setq *transform-term* new-term)
	      (push command *transform-commands*)
	      (print-current-term nil)))
	))
  (values))

(defun find-op-def (qid)
  (let ((result (Script::getOpDef-2 *transform-spec* qid)))
    (cdr result)))

(defun at-command (qid)
  (finish-previous-multi-command)
  (let ((new-term (find-op-def qid)))
    (if (null new-term)
	()
	(progn
	  (push-state `(at-command ,qid))
	  (setq *transform-term* (cons new-term new-term))
	  (push #'(lambda (future-steps)
		    (if (null future-steps)
			nil
			(Script::mkAt-2 qid future-steps)))
		*transform-commands*)
	  (print-current-term nil)))
    (values)))

(defparameter *move-alist* '(("f" :|First|) ("l" :|Last|) ("n" :|Next|) ("p" :|Prev|)
			     ("w" :|Widen|) ("a" :|All|) ("t" :|All|)
			     ("s" . :|Search|) ("r" . :|ReverseSearch|)))

(defun move-command (moves)
  (let ((move-comms (loop for move on moves
			  for pr = (assoc (car move) *move-alist* :test 'equal)
			 if (null pr)
			 do (return (progn (warn "Illegal move command: ~a" (car move)) nil))
			 else collect (if (listp (cdr pr))
					  (cdr pr)
					  (if (null (cdr move))
					      (return (progn (warn "Missing search arg: ~a" (car move)) nil))
					      (cons (cdr pr) (progn (pop move) (car move))))))))
    (when move-comms
      (interpret-command (Script::mkMove move-comms)))
    (values)))

(defun apply-command (qid constr-fn op?)
  (interpret-command (Script::mkApply (list (funcall constr-fn (parse-qid qid op?))))))

(defvar *op-commands* '(fold f unfold uf rewrite rw))
(defun op-command? (com)
  (member com *op-commands*))

(defun simplify-command (argstr)
  (let* ((words (and argstr
		     (String-Spec::removeEmpty (String-Spec::splitStringAt-2 argstr " "))))
	 (rules (loop for tl on words by #'cddr
		      collect (funcall (Script::ruleConstructor (first tl))
				       (if (null (cdr tl))
					   nil
					   (parse-qid (second tl) (op-command? (first tl))))))))
    (interpret-command (Script::mkSimplify rules))))

(defun finish-transform-session ()
  (finish-previous-multi-command)
  (setq *redos* (reverse (loop for el in *undo-stack* collect (fourth el))))
  (if (null *transform-commands*)
      (format t "No transformations")
      (Script::printScript (Script::mkSteps (reverse *transform-commands*))))
  (setq *current-command-processor* 'process-sw-shell-command)
  (setq *prompt* "* ")
  (Emacs::eval-in-emacs "(setq *sw-slime-prompt* \"* \")")
  (values))

(defun process-transform-shell-command (command argstr)
  (cond ((and (consp command) (null argstr))
	 (lisp-value (multiple-value-list (eval command))))
	((symbolp command)
	 (case command
	   (help      (let ((cl-user::*sw-help-strings*
			     *transform-help-strings*))
			(cl-user::sw-help argstr) ; refers to *transform-help-strings*
			))
	   (at                 (at-command (parse-qid argstr t)))
	   ((move m)           (move-command (String-Spec::split argstr)))
	   ((f l n p w a s r)  (move-command (cons (string-downcase (string command))
						   (String-Spec::split argstr))))
	   ((simplify simp s)  (simplify-command argstr)    )
	   ;((apply a)       (cl-user::ls     (or argstr "")))
	   ((fold f)           (apply-command argstr 'Script::mkFold t))
	   ((unfold uf)        (apply-command argstr 'Script::mkUnfold t))
           ((rewrite rw)       (apply-command argstr 'Script::mkRewrite t))
	   ((left-to-right lr) (apply-command argstr 'Script::mkLeftToRight nil))
	   ((right-to-left rl) (apply-command argstr 'Script::mkRightToLeft nil))
	   ((simp-standard ss) (interpret-command (Script::mkSimpStandard-0)))
	   ((abstract-cse cse acse) (interpret-command (Script::mkAbstractCommonExpressions-0)))
	   ((partial-eval pe)  (interpret-command (Script::mkPartialEval-0)))

	   (pc                 (print-current-term nil))
	   (pcv                (print-current-term t))
	   ((undo back)        (undo-command (and argstr (String-Spec::removeWhiteSpace argstr)) nil))
	   (redo               (redo-command (and argstr (String-Spec::removeWhiteSpace argstr))))
	   ((trace-rewrites trr) (setq MetaSlangRewriter::traceRewriting 2)
	                         (format t "Rewrite tracing turned on.")
	                         (values))
	   ((untrace-rewrites untrr) (setq MetaSlangRewriter::traceRewriting 0)
	                             (format t "Rewrite tracing turned off.")
	                             (values))
	   ((done)             (finish-transform-session))

	   ((proc p) (when (and (cl-user::sw argstr)
				(equal *transform-specunit-Id* cl-user::*last-unit-Id-_loaded*))
		       (let ((val (cdr (Specware::evaluateUnitId cl-user::*last-unit-Id-_loaded*))))
			 (if (or (null val) (not (eq (car val) ':|Spec|)))
			     (format t "Not a spec!")
			     (let ((spc (cdr val)))
			       (setq *redos* nil) ; Don't want to redo commands backed out of
			       (undo-command "all" t)
			       (setq *transform-spec* spc)
			       (format t "Restarting Transformation Shell.")
			       (redo-command "all")))))
		      (values))
	   (t (process-sw-shell-command command argstr))))
	((and (constantp command) (null argstr))
	 (values command))
	(t
	 (format t "Unknown command `~S'. Type `help' to see available commands."
		 command))))
