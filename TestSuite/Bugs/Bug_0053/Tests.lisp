(test-directories ".")

(test 

 ("Bug 0053 : Strange result is shown for result of spec-substitution"
  :show   "Subst#BB" 
  :output '(";;; Elaborating spec-substitution at $TESTDIR/Subst#BB"
	    ";;; Elaborating spec at $TESTDIR/Subst#AA"
	    ";;; Elaborating spec at $TESTDIR/Subst#A"
	    ";;; Elaborating spec-morphism at $TESTDIR/Subst#M"
	    ";;; Elaborating spec at $TESTDIR/Subst#B"
            (:optional "")
	    "spec  "
            (:optional "")
	    " import B"
            (:optional "")
            (:alternatives
             "type Interval = {start: Nat, stop: Nat}"
             "type Interval = {start : Nat, stop : Nat}")
            (:optional "")
            (:alternatives
             "op  isEmptyInterval?: Interval -> Bool"
             "op  isEmptyInterval? : Interval -> Bool")
            (:alternatives
             "def isEmptyInterval?{start = x, stop = y} = x = y"
             "def isEmptyInterval? {start = x, stop = y} = x = y"
             "def isEmptyInterval?{start = x: Nat, stop = y: Nat}: Bool = x = y"
             "def isEmptyInterval? {start = x : Nat, stop = y : Nat} : Bool = x = y")
	    (:alternatives "endspec" "end-spec")
            (:optional "")
            (:optional "")))
 )
