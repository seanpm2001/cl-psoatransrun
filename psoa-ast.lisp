
(in-package #:psoa-ast)

#|

|#


(eval-when (:compile-toplevel :load-toplevel)
  (setf *arity-check-by-test-call* nil))

(named-readtables:in-readtable rutils-readtable)

(defstruct ruleml-ast-node
  "The supertype from which all PSOA RuleML AST nodes derive. The
position slot refers to the original lexical position within a RuleML
document, its character offset into the document string. The position
is typed as a non-negative integer and has a default of 0."
  (position 0 :type (integer 0 *)))

(defstruct (ruleml-document (:include ruleml-ast-node))
  "A complete PSOA RuleML document as specified in the PSOA RuleML
EBNF
(http://wiki.ruleml.org/index.php/PSOA_RuleML#Monolithic_EBNF_for_PSOA_RuleML_Presentation_Syntax)."
  (base nil :type list)
  (prefixes nil :type list)
  (prefix-ht (make-hash-table :test #'equalp) :type hash-table)
  (imports nil :type list)
  (performatives nil :type list))

(defstruct (ruleml-base (:include ruleml-ast-node))
  "A PSOA RuleML Base element."
  (iri-ref "" :type string))

(defstruct (ruleml-prefix (:include ruleml-ast-node))
  "A PSOA RuleML Prefix element."
  (name "" :type (or null string))
  (iri-ref (make-ruleml-iri) :type ruleml-iri))

(defstruct (ruleml-const (:include ruleml-ast-node))
  "A PSOA RuleML constant."
  (contents "" :type (or string number ruleml-pname-ln)))

(defstruct (ruleml-string (:include ruleml-ast-node))
  "A PSOA RuleML string, whose literal syntax is standard (written
between double quotation marks)."
  (contents "" :type string))

(defstruct (ruleml-import (:include ruleml-ast-node))
  "The contents of a PSOA RuleML Import(...) directive."
  (iri-ref (make-ruleml-iri) :type ruleml-iri)
  (profile "" :type (or null string)))

(defstruct (ruleml-assert (:include ruleml-ast-node))
  "An Assert(...) performative."
  (items nil :type list)
  (relationships (make-hash-table :test #'equalp) :type hash-table)
  (is-relational-p nil :type boolean))

(defstruct (ruleml-query (:include ruleml-ast-node))
  "A Query(...) performative."
  term)

(defstruct (ruleml-naf (:include ruleml-ast-node))
  "A Naf(...) formula."
  formula)

(defstruct (ruleml-var (:include ruleml-ast-node))
  "A variable."
  (name "" :type string))

(defstruct (ruleml-genvar (:include ruleml-var))
  "A variable generated by PSOATransRun.")

(defstruct (ruleml-slot (:include ruleml-ast-node))
  "A slot belonging to either an atom or expression."
  (dep t :type boolean)
  name
  filler)

(defstruct (ruleml-tuple (:include ruleml-ast-node))
  "A tuple belonging to an atom."
  (dep t :type boolean)
  (terms nil :type list))

(defstruct (ruleml-pname-ln (:include ruleml-ast-node))
  "A predicate name prefixed with a namespace, one form of a constant."
  (name "" :type (or null string))
  (url "" :type string))

(defstruct (ruleml-expr (:include ruleml-ast-node))
  "An expression."
  root
  (terms nil :type list))

(defstruct (ruleml-subclass-rel (:include ruleml-ast-node))
  "A subclass relation."
  sub
  super)

(defstruct (ruleml-equal (:include ruleml-ast-node))
  "An equality."
  left
  right)

(defstruct (ruleml-atom (:include ruleml-ast-node))
  "An oidless atom."
  root
  (descriptors nil :type list))

(defstruct (ruleml-oidful-atom (:include ruleml-ast-node))
  "An oidful atom."
  oid
  predicate)

(defstruct (ruleml-forall (:include ruleml-ast-node))
  "A Forall clause."
  (vars nil :type list)
  clause)

(defstruct (ruleml-implies (:include ruleml-ast-node))
  "A rule."
  conclusion
  condition)

(defstruct (ruleml-and (:include ruleml-ast-node))
  "An And formula."
  (terms nil :type list))

(defstruct (ruleml-or (:include ruleml-ast-node))
  "An Or formula."
  (terms nil :type list))

(defstruct (ruleml-exists (:include ruleml-ast-node))
  "An Exists formula."
  (vars nil :type list)
  formula)

(defstruct (ruleml-external (:include ruleml-ast-node))
  "An External formula."
  atom)

(defstruct (ruleml-membership (:include ruleml-ast-node))
  "A membership."
  oid
  predicate)

(defstruct (ruleml-number (:include ruleml-ast-node))
  "A number (float or integer)."
  (value 0 :type number))

(defstruct (ruleml-iri (:include ruleml-ast-node))
  "A constant representing an IRI."
  (contents "" :type string))


(defun match-builtin-function (local)
  "Names of builtin functions in PSOA RuleML are matched to their
ISO Prolog counterparts. Used for obtaining proper predicate names."
  (match local
    ("numeric-add" "'+'")
    ("numeric-subtract" "'-'")
    ("numeric-multiply" "'*'")
    ("numeric-divide" "'/'")
    ("numeric-integer-divide" "'//'")
    ("numeric-mod" "rem")))

(defun match-builtin-predicate (local)
    "Names of builtin predicates in PSOA RuleML are matched to their
ISO Prolog counterparts. Used for obtaining proper predicate names."
  (match local
    ("numeric-equal" "'=:='")
    ("numeric-less-than" "'<'")
    ("numeric-less-than-or-equal" "'=<'")
    ("numeric-greater-than" "'>'")
    ("numeric-greater-than-or-equal" "'>='")
    ("numeric-not-equal" "=\\=")
    ("is-literal-integer" "integer")))

(defun match-builtin-isopl (local)
   "Names of builtin predicates in PSOA RuleML are matched to their
ISO Prolog counterparts. Used for obtaining proper predicate names."
  (match local
    ("integer" "integer")
    ("float" "float")
    ("number" "number")
    ("eq" "'=:='")
    ("not_eq" "=\\=")
    ("greater_than" "'>'")
    ("greater_than_or_eq" "'>='")
    ("less_than" "'<'")
    ("less_than_or_eq" "'=<'")
    ("add" "'+'")
    ("sub" "'-'")
    ("mul" "'*'")
    ("int-div" "'//'")
    ("div" "'/'")
    ("abs" "abs")
    ("rem" "rem")
    ("mod" "mod")
    ("sign" "sign")
    ("float" "float")
    ("truncate" "truncate")
    ("round" "round")
    ("floor" "floor")
    ("ceiling" "ceiling")
    ("power" "'**'")
    ("sin" "sin")
    ("cos" "cos")
    ("atan" "atan")
    ("sqrt" "sqrt")
    ("exp" "exp")
    ("log" "log")))

(defun match-builtin-xsb (local)
  "Names of builtin predicates in the XSB Prolog standard library."
  (match local
    ("datime" "datime")
    ("local_datime" "local_datime")))

(defun write-url-const (ns local prefix-ht &optional stream)
  "Write the properly qualified name of prefixed predicate to the
output stream \"stream\" with the help of make-url-const."
  (let ((result (make-url-const ns local prefix-ht)))
    (typecase result
      (ruleml-const (format stream "~A" (ruleml-const-contents result)))
      (ruleml-iri (format stream "'<~A~A>'" (ruleml-iri-contents result) local))
      (t (format stream "~A:~A" ns local)))))

(defun make-url-const (ns local prefix-ht &optional (start 0))
  "Use the \"prefix-ht\" hash table to match the Prefix namespace to
its URL value. If the hash table doesn't contain the namespace as a
key, substitute the namespace for the URL."
  (multiple-value-bind (url foundp)
      (gethash ns prefix-ht)
    (when foundp
      (match (ruleml-iri-contents url)
        ("http://www.w3.org/2007/rif-builtin-function#"
         (when-it (match-builtin-function local)
           (make-ruleml-const :contents it :position start)))
        ("http://www.w3.org/2007/rif-builtin-predicate#"
         (when-it (match-builtin-predicate local)
           (make-ruleml-const :contents it :position start)))
        ("https://www.iso.org/standard/21413.html#"
         (when-it (match-builtin-isopl local)
           (make-ruleml-const :contents it :position start)))
        ("http://xsb.sourceforge.net/manual1/manual1.pdf#"
         (when-it (match-builtin-xsb local)
           (make-ruleml-const :contents it :position start)))
        (_
         url)))))

(defun prefix-type-cast (cast operand &optional (start 0))
  "Perform a compile-time type cast using a prefixed qualifier. Used
in conjunction with the \"^^\" operator."
  (cond
    ((or (string= cast "http://www.w3.org/2001/XMLSchema#integer")
         (string= cast "http://www.w3.org/2001/XMLSchema#long"))
     (make-ruleml-number :value (parse-integer operand)
                         :position start))
    ((string= cast "http://www.w3.org/2001/XMLSchema#double")
     (make-ruleml-number :value (read-from-string operand)
                         :position start))
    ((string= cast "http://www.w3.org/2001/XMLSchema#string")
     (make-ruleml-string :contents operand
                         :position start))))

(defun prefix-list->prefix-ht (prefixes)
  "Compile a hash table with namespace keys and IRI values."
  (alist->ht (loop for prefix in prefixes
                   collect (cons (ruleml-prefix-name prefix)
                                 (ruleml-prefix-iri-ref prefix)))
             :test #'equalp))

(defun transform-ast (term key &key positive negative external
                                 (propagator
                                  (lambda (term &key positive negative external)
                                    (transform-ast term key
                                     :positive positive
                                     :negative negative
                                     :external external))))
  "Performs a post-order traversal of an abstract syntax tree of PSOA
RuleML nodes, all of which have supertype ruleml-ast-node.

The first argument \"term\" can belong to any of the struct subtypes
of ruleml-ast-node enumerated as the cases of the form (match term
...). Each struct is rebuilt from the traversal of its subnodes as
determined by the \"propagator\" function argument before being passed
to the \"key\" function.

\"propagator\" is an optional argument whose default functorially maps
\"key\" to every ruleml-ast-node of the \"term\" tree by recursively
invoking transform-ast on each sub-\"term\". It re-uses the remaining
(lexically captured) \"key\" and keyword arguments of its originating
transform-ast caller.

The boolean keyword arguments :positive, :negative and :external are
used to inform the \"key\" function of its mapping context in the
\"term\" tree. The logic programming terms 'positive' and 'negative'
are modified slightly to derive traversal contexts in the following
combinations:

+---------------+---------------+---------------+
|:positive      |:negative      |context        |
+---------------+---------------+---------------+
|t              |t              |query          |
+---------------+---------------+---------------+
|t              |nil            |conclusion     |
+---------------+---------------+---------------+
|nil            |t              |condition      |
+---------------+---------------+---------------+
|nil            |nil            |fact           |
+---------------+---------------+---------------+

transform-ast sets but does not consume the values of :positive,
:negative and :external for consumption by \"key\".

Finally, the keyword :external indicates whether the formula being
traversed is inside an External(...)."
  (flet ((default-propagator (term)
           (funcall propagator term
                    :positive positive
                    :negative negative
                    :external external)))
    (match term
      ((ruleml-document :base base :prefixes prefixes
                        :imports imports :performatives performatives)
       (funcall key
                (make-ruleml-document
                 :base (default-propagator base)
                 :prefixes (mapcar #'default-propagator prefixes)
                 :imports (mapcar #'default-propagator imports)
                 :performatives (mapcar #'default-propagator performatives))))
      ((ruleml-assert :items terms)
       (funcall key (make-ruleml-assert :items (mapcar #'default-propagator terms))
                :positive positive
                :negative negative))
      ((ruleml-tuple :terms terms :dep dep)
       (funcall key (make-ruleml-tuple :terms (mapcar #'default-propagator terms) :dep dep)
                :positive positive
                :negative negative
                :external external))
      ((ruleml-and :terms terms)
       (funcall key (make-ruleml-and :terms (mapcar #'default-propagator terms))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-or :terms terms)
       (funcall key (make-ruleml-or :terms (mapcar #'default-propagator terms))
                :positive positive
                :negative negative
                :external external))
      ((or (ruleml-base)
           (ruleml-prefix)
           (ruleml-import)
           (ruleml-pname-ln)
           (ruleml-const)
           (ruleml-var)
           (ruleml-number)
           (ruleml-iri))
       (funcall key term
                :positive positive
                :negative negative
                :external external))
      ((ruleml-query :term query)
       (funcall key (make-ruleml-query :term (funcall propagator query
                                                      :positive t
                                                      :negative t
                                                      :external external))))
      ((ruleml-naf :formula naf)
       (funcall key (make-ruleml-naf :formula (default-propagator naf))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-slot  :name name :filler filler :dep dep)
       (funcall key (make-ruleml-slot :dep dep
                                      :name (default-propagator name)
                                      :filler (default-propagator filler))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-expr :root root :terms terms)
       (funcall key (make-ruleml-expr :root (default-propagator root)
                                      :terms (mapcar #'default-propagator terms))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-subclass-rel :sub sub :super super)
       (funcall key (make-ruleml-subclass-rel :sub (default-propagator sub)
                                              :super (default-propagator super))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-equal :left left :right right)
       (funcall key (make-ruleml-equal :left  (default-propagator left)
                                       :right (default-propagator right))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-implies :conclusion conclusion :condition condition)
       (funcall key (make-ruleml-implies
                     :conclusion (funcall propagator conclusion
                                          :positive t :negative nil)
                     :condition (funcall propagator condition
                                         :positive nil :negative t))
                :positive positive
                :negative negative))
      ((ruleml-exists :vars vars :formula formula)
       (funcall key (make-ruleml-exists :vars (mapcar #'default-propagator vars)
                                        :formula (default-propagator formula))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-atom :root root :descriptors descriptors)
       (funcall key (make-ruleml-atom :root (default-propagator root)
                                      :descriptors (mapcar #'default-propagator descriptors))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-oidful-atom :oid oid :predicate atom)
       (funcall key (make-ruleml-oidful-atom :oid (default-propagator oid)
                                             :predicate (default-propagator atom))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-forall :vars vars :clause clause)
       (funcall key (make-ruleml-forall :vars (mapcar #'default-propagator vars)
                                        :clause (default-propagator clause))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-external :atom atom)
       (funcall key (make-ruleml-external
                     :atom (funcall propagator atom
                                    :positive positive
                                    :negative negative
                                    :external t))
                :positive positive
                :negative negative
                :external external))
      ((ruleml-membership :oid oid :predicate predicate)
       (funcall key (make-ruleml-membership :oid (default-propagator oid)
                                            :predicate (default-propagator predicate))
                :positive positive
                :negative negative
                :external external))
      (_ (funcall key term
                  :positive positive
                  :negative negative
                  :external external)))))
