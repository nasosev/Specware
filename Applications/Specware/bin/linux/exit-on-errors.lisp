(in-package "USER")

(defun bail-out (exception)
  (let ((return-code
	 ;; Unix return codes are encoded in a byte (i.e. mod 256),
	 ;; so for clarity avoid values outside [0 .. 255]
	 (typecase exception
	   (INTERRUPT-SIGNAL                    
	    (let ((signal-number (excl::operating-system-signal-number exception))
		  (signal-name   (excl::operating-system-signal-name   exception)))
	      (when (stringp signal-number) (rotatef signal-name signal-number)) ; workaround for Allegro bug 
	      signal-number))

	   (STORAGE-CONDITION                   
	    101)

	   (SYNCHRONOUS-OPERATING-SYSTEM-SIGNAL 
	    102)

	   (t
	    103))))

    (format t "~%Lisp session exiting with code ~D after : ~A~%" return-code exception)
    (exit return-code)))

    
(defmacro exiting-on-errors (&body body)
  `(handler-bind ((condition (function bail-out)))
     ,@body))
