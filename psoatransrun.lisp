
(in-package #:psoatransrun)

(defparameter *prolog-engine-path* "/home/mark/Projects/Rust/scryer-prolog/target/release/scryer-prolog"
  "The path of the local Scryer Prolog executable. Change this to your local path!")


#|
Global variables for command-line options.
|#

(defparameter *all-solutions* nil)


#|
Functions for translating PSOA RuleML documents and queries
to equivalent Prolog, and for sending those translations to
the Prolog engine and receiving back solutions.
|#

(defun psoa-document->prolog (document)
  (let ((document (transform-document (parse 'psoa-grammar::ruleml document))))
    (multiple-value-bind (prolog-kb-string relationships is-relational-p)
        (translate-document document)
      (values prolog-kb-string
              relationships
              is-relational-p
              (ruleml-document-prefix-ht document)))))

(defun psoa-query->prolog (query prefix-ht relationships)
  (-> (parse 'psoa-grammar::query (format nil "Query(~A)" query))
      (transform-query relationships prefix-ht)
      (translate-query prefix-ht)))

(defun read-and-print-solutions (socket-stream)
  (loop for solution = (read-line socket-stream nil nil)
        do (cond ((string= solution "No")
                  (format t "~%no~%")
                  (return-from read-and-print-solutions))
                 ((string= solution "Yes")
                  (format t "~%yes~%")
                  (read-line socket-stream nil nil) ;; Ignore following 'No'.
                  (return-from read-and-print-solutions))
                 (t
                  ;; The use of subseq is a kludge to remove quotation
                  ;; marks printed by Scryer.
                  (write-string (subseq solution 1 (1- (length solution))))
                  (when *all-solutions*
                    (terpri))))
           (unless *all-solutions*
               (read-char))))

(defun psoa-repl (engine-socket prefix-ht &optional (relationships (make-hash-table :test #'equalp)))
  (loop (handler-case (-psoa-repl engine-socket prefix-ht relationships)
          (esrap:esrap-parse-error (condition)
            (format t "Parse error at ~A at position ~D~%"
                    (esrap:esrap-error-text condition)
                    (esrap:esrap-error-position condition))))))

(defun send-query-to-prolog-engine (socket-stream query-string prefix-ht relationships)
  (multiple-value-bind (query-string toplevel-var-string)
      (psoa-query->prolog query-string prefix-ht relationships)
    (format t "~A" query-string)
    (write-line query-string socket-stream)
    (write-line toplevel-var-string socket-stream)
    (force-output socket-stream)
    (read-and-print-solutions socket-stream)))

(defun -psoa-repl (engine-socket prefix-ht relationships)
  (let ((socket-stream (socket-stream engine-socket)))
    (loop for line = (progn (write-string "> ")
                            (read-line *standard-input* nil))
          if line do (send-query-to-prolog-engine
                      socket-stream line
                      prefix-ht relationships))))

(defun psoa-load-and-repl (document)
  (if (and *prolog-engine-path* (probe-file *prolog-engine-path*))
      (-psoa-load-and-repl document)
      (progn (format t "Enter the path of Scryer Prolog: ")
             (finish-output)
             (setf *prolog-engine-path* (probe-file (pathname (read-line))))
             (psoa-load-and-repl document))))

(defun quit-prolog-engine (process)
  (signal-process process :quit))

(defun init-prolog-process (prolog-kb-string process)
  (let ((process-input-stream (process-input-stream process)))
    ;; Compile the PSOA document in the engine.
    (write-line "[user]." process-input-stream)
    (write-line prolog-kb-string process-input-stream)
    (write-line "end_of_file." process-input-stream)
    (finish-output process-input-stream)

    ;; Loading the server engine, which is initialized automatically
    ;; within the module via a ":- initialization(...)." directive.
    (write-string "use_module('" process-input-stream)
    (write-string "/home/mark/Projects/CL/PSOATransRun" process-input-stream)
    (write-line "/scryer_server.pl')." process-input-stream)
    (finish-output process-input-stream)))

(defun connect-to-prolog-process (process)
  ;; It's possible for the runtime to print warning messages (ie.,
  ;; for singleton variables) in some cases. In those cases, ignore
  ;; the junk output and try to read the port again.
  (loop (handler-case
            (let* ((port (parse-integer (read-line (process-output-stream process)))))
              (return-from connect-to-prolog-process
                (socket-connect "127.0.0.1" port)))
          (parse-error ()))))

(defun -psoa-load-and-repl (document)
  (multiple-value-bind (prolog-kb-string relationships is-relational-p prefix-ht)
      (psoa-document->prolog document)
    (let* ((process (external-program:start *prolog-engine-path* nil
                                            :input :stream
                                            :output :stream)))

      (format t "The translated KB:~%~%~A" prolog-kb-string)
      (init-prolog-process prolog-kb-string process)

      (let ((engine-socket (connect-to-prolog-process process)))
        (unwind-protect
             (let ((*is-relational-p* is-relational-p))
               (psoa-repl engine-socket prefix-ht relationships))
          (socket-close engine-socket)
          (quit-prolog-engine process))))))
