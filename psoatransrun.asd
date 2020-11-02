(asdf:defsystem #:psoatransrun
  :description "A CL implementation of PSOATransRun, an implementation of the PSOA RuleML data and rule language."
  :author "Mark Thom"
  :license "BSD-3"
  :version "0.9"
  :serial t
  :depends-on (#:esrap #:external-program #:rutils #:trivia #:usocket)
  :components ((:file "package")
               (:file "psoa-ast")
               (:file "psoa-grammar")
               (:file "psoa-pprint")
               (:file "psoa-prolog-translator")
               (:file "psoa-transformers")
               (:file "psoatransrun")))
