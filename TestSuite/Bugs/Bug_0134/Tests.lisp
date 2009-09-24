(test-directories ".")

(test 

 ("Bug 0134 : Unparseable proof obligation generated"
  :show "fold#O"
  :output '(";;; Elaborating obligator at $TESTDIR/fold#O"
	    ";;; Elaborating spec at $TESTDIR/fold#S"
	    (:optional ";;; Elaborating spec at $SPECWARE/Library/Base/WFO")
            ""
            "spec  "
	    (:optional " import /Library/Base/WFO")
            ""
	    " type Predicate(a) = a -> Boolean"
	    " "
	    " op uniquelySatisfies? : [a] a * Predicate(a) -> Boolean"
            ""
	    " axiom uniquelySatisfies?_def is [a] "
	    "    fa(x : a, p : Predicate(a)) "
	    "     uniquelySatisfies?(x, p) = (p x && (fa(y : a) (p y => y = x)))"
	    " "
	    " op uniquelySatisfied? : [a] Predicate(a) -> Boolean"
            ""
	    " axiom uniquelySatisfied?_def is [a] "
	    "    fa(p : Predicate(a)) "
	    "     uniquelySatisfied? p = (ex(x : a) uniquelySatisfies?(x, p))"
            ""
	    " type UniquelySatisfiedPredicate(a) = (Predicate(a) | uniquelySatisfied?)"
	    " "
	    " op The : [a] UniquelySatisfiedPredicate(a) -> a"
            ""
	    " axiom The_def is [a] "
	    "    fa(p : UniquelySatisfiedPredicate(a)) uniquelySatisfies?(The p, p)"
            ""
	    " type FSet(a)"
	    " "
	    " op in? infixl 20 : [a] a * FSet(a) -> Boolean"
            ""
	    " op empty : [a] FSet(a)"
            ""
	    " op with infixl 30 : [a] FSet(a) * a -> FSet(a)"
            ""
	    " op wout infixl 30 : [a] FSet(a) * a -> FSet(a)"
	    " "
	    " op foldable? : [a, b] FSet(a) * b * (b * a -> b) -> Boolean"
	    " def foldable? (s, c, f) = "
	    "   fa(x : a, y : a, z : b) "
	    "    x in? s && y in? s => f(f(z, x), y) = f(f(z, y), x)"
	    " "
	    " op fold : [a, b] ((FSet(a) * b * (b * a -> b)) | foldable?) -> b"
            ""
	    " conjecture fold_Obligation_subtype is [a, b] "
	    "    uniquelySatisfied?"
	    "      ((fn fold -> "
	    "           (fa(c : b, f : b * a -> b) fold(empty, c, f) = c) "
	    "           && (fa(s : FSet(a), x : a, c_1 : b, f_1 : b * a -> b) "
	    "                (foldable?(s with x, c_1, f_1) "
	    "                => fold(s with x, c_1, f_1) "
	    "                   = f_1(fold(s wout x, c_1, f_1), x)))))"
            ""
	    " conjecture fold_Obligation_subtype1 is [a, b] "
            "   fa(fold : ((FSet(a) * b * (b * a -> b)) | foldable?) -> b, s : FSet(a), "
            "      x : a, c_1 : b, f_1 : b * a -> b) "
            "    (fa(c : b, f : b * a -> b) fold(empty, c, f) = c) "
            "    && foldable?(s with x, c_1, f_1) => foldable?(s wout x, c_1, f_1)"
	    ""
	    " conjecture fold_Obligation_subtype0 is [a, b] "
	    "    fa(c : b, f : b * a -> b) foldable?(empty, c, f)"
            ""
	    " def fold = "
	    "   The"
            (:alternaticves
             "     ((fn fold -> "
             ("    ((fn fold : "
              "         ((FSet(a) * b * (b * a -> b)) | "
              "         foldable? : FSet(a) * b * (b * a -> b) -> Boolean) -> b -> "))
	    "          (fa(c : b, f : b * a -> b) fold(empty, c, f) = c) "
	    "          && (fa(s : FSet(a), x : a, c : b, f : b * a -> b) "
	    "               (foldable?(s with x, c, f) "
	    "               => fold(s with x, c, f) = f(fold(s wout x, c, f), x)))))"
            "endspec"
	    ""
	    ""))
 )

