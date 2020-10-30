
(in-package #:psoa-prolog-translator)

(named-readtables:in-readtable rutils-readtable)

(defun translate-query (query prefix-ht)
  (let* ((*print-pprint-dispatch* (copy-pprint-dispatch nil))
         (output-stream (make-string-output-stream)))
    (-translate (ruleml-query-term query)
                prefix-ht
                output-stream
                nil)
    (format nil "~A.~%" (get-output-stream-string output-stream))))

(defun translate-document (document prefix-ht &key (system :scryer))
  (multiple-value-bind (prolog-kb-string relationships is-relational-p predicate-indicators)
      (translate-document- document prefix-ht)
    (ecase system
      (:scryer (let* ((stream (make-string-input-stream prolog-kb-string))
                      (collated-stream (make-string-output-stream))
                      (lines (loop for line = (read-line stream nil)
                                   while line collect line))
                      (lines (sort lines #'string<=)))
                 (format collated-stream ":- use_module(library(tabling)).~%~%")
                 (loop for key being each hash-key of predicate-indicators
                       do (format collated-stream ":- table ~A/~A.~%"
                                  (lt key) (rt key)))
                 (format collated-stream "~%")
                 (dolist (line lines)
                   (format collated-stream "~A~%" line))
                   (values (get-output-stream-string collated-stream)
                           relationships
                           is-relational-p
                           prefix-ht))))))

(defun translate-document- (document prefix-ht)
  (let* ((*print-pprint-dispatch* (copy-pprint-dispatch nil))
         (prolog-kb-stream (make-string-output-stream))
         (performatives (ruleml-document-performatives document))
         (predicate-indicators (make-hash-table :test #'equalp))
         (relationships)
         (is-relational-p))
    (dolist (performative performatives)
      (match performative
        ((ruleml-assert :items items :relationships assert-relationships
                        :is-relational-p assert-is-relational-p)
         (unless (null relationships)
           (error "multiple Assert's in a single PSOA KB isn't yet supported"))
         (setf relationships assert-relationships
               is-relational-p assert-is-relational-p)
         (mapc #`(let ((item-predicate-indicators (-translate % prefix-ht prolog-kb-stream)))
                   (setf predicate-indicators
                         (merge-hts predicate-indicators item-predicate-indicators))
                   (format prolog-kb-stream ".~%"))
               items))
        ((ruleml-query :term query-term)
         (format prolog-kb-stream "?- ~A."
                 (-translate query-term prefix-ht prolog-kb-stream)))))
    (values (get-output-stream-string prolog-kb-stream)
            relationships
            is-relational-p
            predicate-indicators)))

(defun -translate (item prefix-ht stream &optional (assert-item-p t))
  (let ((predicate-indicators (make-hash-table :test #'equalp)))
    (macrolet ((record-predicate-indicator (name arity recordp)
                 `(when ,recordp
                    (sethash (pair ,name ,arity) predicate-indicators t))))
      (labels ((translate (item &optional stream recordp)
                 (match item
                   ((ruleml-oidful-atom
                     :oid oid
                     :predicate (ruleml-atom :root (ruleml-const :contents "Top")
                                             :descriptors (list (ruleml-tuple :dep nil
                                                                              :terms terms))))
                    (record-predicate-indicator "tupterm" (1+ (length terms)) recordp)
                    (format stream "tupterm(~A, ~{~A~^, ~})"
                            (translate oid)
                            (mapcar #'translate terms)))
                   ((ruleml-oidful-atom
                     :oid oid
                     :predicate (ruleml-atom :root root
                                             :descriptors (list (ruleml-tuple :dep t
                                                                              :terms terms))))
                    (record-predicate-indicator "prdtupterm" (+ 2 (length terms)) recordp)
                    (format stream "prdtupterm(~A, ~A, ~{~A~^, ~})"
                            (translate oid)
                            (translate root)
                            (mapcar #'translate terms)))
                   ((ruleml-oidful-atom
                     :oid oid
                     :predicate (ruleml-atom :root (ruleml-const :contents "Top")
                                             :descriptors (list (ruleml-slot :dep nil
                                                                             :name name
                                                                             :filler filler))))
                    (record-predicate-indicator "sloterm" 3 recordp)
                    (format stream "sloterm(~A, ~A, ~A)"
                            (translate oid)
                            (translate name)
                            (translate filler)))
                   ((ruleml-oidful-atom
                     :oid oid
                     :predicate (ruleml-atom :root root
                                             :descriptors (list (ruleml-slot :dep t
                                                                             :name name
                                                                             :filler filler))))
                    (record-predicate-indicator "prdsloterm" 4 recordp)
                    (format stream "prdsloterm(~A, ~A, ~A, ~A)"
                            (translate oid)
                            (translate root)
                            (translate name)
                            (translate filler)))
                   ((ruleml-oidful-atom
                     :oid oid
                     :predicate (ruleml-atom :root root :descriptors descriptors))
                    (record-predicate-indicator "prdtupterm" (+ 2 (length descriptors)) recordp)
                    (format stream "prdtupterm(~A, ~A, ~{~A~^, ~})"
                            (translate oid)
                            (translate root)
                            (mapcar #'translate descriptors)))
                   ((ruleml-membership :oid oid :predicate predicate)
		            (match predicate
		              ((ruleml-const :contents "Top")
		               (format stream "true"))
		              (_
		               (record-predicate-indicator "memterm" 2 recordp)
		               (format stream "memterm(~A, ~A)"
			                   (translate oid)
			                   (translate predicate)))))
                   ((or (ruleml-atom :root root :descriptors (list (ruleml-tuple :dep t :terms terms)))
                        (ruleml-expr :root root :terms (list (ruleml-tuple :dep t :terms terms))))
                    (let ((root-string (translate root)))
                      (record-predicate-indicator (format nil "~A" root-string) (length terms) recordp)
                      (if (null terms)
                          (format stream "~A"
                                  root-string)
                          (format stream "~A(~{~A~^, ~})"
                                  root-string
                                  (mapcar #'translate terms)))))
                   ((ruleml-expr :root root :terms terms)
                    (let ((root-string (translate root)))
                      (record-predicate-indicator root-string (length terms) recordp)
                      (format stream "~A(~{~A~^, ~})"
                              root-string
                              (mapcar #'translate terms))))
                   ((ruleml-equal :left left :right (ruleml-external :atom atom))
                    (format stream "is(~A, ~A)"
                            (translate left)
                            (translate atom)))
                   ((ruleml-equal :left left :right right)
                    (format stream "'='(~A, ~A)"
                            (translate left)
                            (translate right)))
                   ((ruleml-and :terms terms)
                    (format stream "(~{~A~^, ~})"
                            (mapcar #'translate terms)))
                   ((ruleml-or :terms terms)
                    (format stream "(~{~A~^; ~})"
                            (mapcar #'translate terms)))
                   ((or (ruleml-exists :formula formula)
                        (ruleml-forall :clause formula))
                    (translate formula stream))
                   ((ruleml-external :atom atom)
                    (translate atom stream))
                   ((ruleml-implies :conclusion conclusion :condition condition)
                    (format stream "~A :- ~A"
                            (translate conclusion nil t)
                            (translate condition)))
                   ((ruleml-var :name name)
                    (format stream "Q~A" name))
                   ((ruleml-naf :formula formula)
                    (format stream "\+ (~A)"
                            (translate formula)))
                   ((ruleml-const :contents const)
                    (match const
                      ((ruleml-pname-ln :name ns :url local)
                       (if ns
                           (make-url-const ns local prefix-ht stream)
                           (format stream "~A" local)))
                      ((type string)
                       (format stream "\"~A\"" const)
                       (if (eql (char const 0) #\_)
                           (format stream "'~A'" const)
                           (format stream "'_~A'" const)))
                      ((type number)
                       (format stream "~A" const))))
                   ((ruleml-string :contents const)
                    (format stream "\"~A\"" const)))))
        (translate item stream assert-item-p)
        predicate-indicators))))
