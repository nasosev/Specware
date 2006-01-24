(in-package "USER")

(setq *GC-VERBOSE* nil)

(defun load-builder (specware-buildscripts-dir distribution-scripts-dir)
  (let ((specware-buildscripts-pathname  (pathname specware-buildscripts-dir))
	(distribution-scripts-pathname   (pathname distribution-scripts-dir)))
    (flet ((my-load (dir-pathname file)
	     (let ((lisp-file (make-pathname :name file :type "lisp" :defaults dir-pathname))
		   (fasl-file (make-pathname :name file :type "x86f" :defaults dir-pathname)))
	       (if (< (file-write-date lisp-file) (or (file-write-date fasl-file) 0))
		   (load fasl-file)
		 (load (compile-file lisp-file))))))
      (my-load distribution-scripts-pathname  "dist-utils")
      (my-load distribution-scripts-pathname  "dir-utils")
      (my-load distribution-scripts-pathname  "MemoryManagement")
      (my-load distribution-scripts-pathname  "save-image")
      (my-load specware-buildscripts-pathname "GatherSpecwareComponents"))))

(defun build-specware-release (i j k specware-dir distribution-dir verbose?)
  (let ((specware-buildscripts-dir 
	 (make-pathname :directory (append (pathname-directory specware-dir) '("Release" "BuildScripts"))
			:defaults  specware-dir))
	(distribution-scripts-dir 
	 (make-pathname :directory (append (pathname-directory distribution-dir) '("Scripts"))
			:defaults  distribution-dir))
	(distribution-release-dir 
	 (make-pathname :directory (append (pathname-directory distribution-dir) '("Releases" "Specware-4-1-4"))
			:defaults  distribution-dir)))
    (load-builder specware-buildscripts-dir distribution-scripts-dir)
    (prepare_specware_release i j k specware-dir distribution-release-dir verbose?)))



