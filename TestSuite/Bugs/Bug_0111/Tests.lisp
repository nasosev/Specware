(test-directories ".")

(test 

 ("Bug 0111 : Capture of translated ops by var bindings [Once]"
  :show   "Capture#T"
  :output '(";;; Elaborating spec-translation at $TESTDIR/Capture#T"
	    ";;; Elaborating spec at $TESTDIR/Capture#S"
	    (:optional "")
	    "spec"
	    (:optional "")
	    " op  xx : Nat"
	    (:optional "")
	    " op  ww : Nat -> Nat"
	    (:optional "")
	    " op  ff : Nat -> Integer"
	    " def ff xx0 = xx0 + xx"
	    " axiom foo is fa(xx0 : Nat) xx0 = xx0 + xx"
	    (:optional "")
	    " op  g : Nat -> Integer"
	    " def g n = let xx0 = n in "
	    "           xx0 + xx"
	    (:optional "")
	    " op  h : Integer -> Integer"
	    " def h n = let def ww0 n = n"
	    "           in "
	    "           ww0 n + ww n"
	    (:optional "")
	    "endspec"
	    (:optional "")
	    (:optional "")))


 ("Bug 0111 : Capture of translated ops by var bindings [Repeated]"
  :show   "Capture#W"
  :output '(";;; Elaborating spec-translation at $TESTDIR/Capture#W"
	    (:optional "")
	    "spec  "
	    (:optional "")
	    " op  aa : Nat"
	    (:optional "")
	    " op  bb : Nat -> Nat"
	    (:optional "")
	    " op  ff : Nat -> Integer"
	    " def ff xx0 = xx0 + aa"
	    (:optional "")
	    " axiom foo is fa(xx0 : Nat) xx0 = xx0 + aa"
	    (:optional "")
	    " op  g : Nat -> Integer"
	    " def g n = let xx0 = n in "
	    "           xx0 + aa"
	    (:optional "")
	    " op  h : Integer -> Integer"
	    " def h n = let def ww0 n = n"
	    "           in "
	    "           ww0 n + bb n"
	    (:optional "")
	    "endspec"
	    (:optional "")
	    (:optional "")))


 )