(test-directories ".")

(test 

 ("Bug 0103 : WFO obligation not generated"
  :sw  "NeedWFO"
  :output ";;; Elaborating spec at $TESTDIR/NeedWFO#S
;;; Elaborating obligator at $TESTDIR/NeedWFO#O

spec  
 import S
 import /Library/Base/WFO
 conjecture f_Obligation is [a] 
    fa(x0 : List(a), i : Nat, tl : List(a), hd : a) 
     i < length x0 && x0 = Cons(hd, tl) && ~(i = 0) 
     => i < length(Cons(hd, tl))
 conjecture f_Obligation0 is [a] 
    ex(pred : (List(a) * Nat) * (List(a) * Nat) -> Boolean) 
     WFO.wfo pred 
     && fa(x0 : List(a), i : Nat, tl : List(a), hd : a) 
         (i < length x0 && x0 = Cons(hd, tl) && ~(i = 0) 
         => pred((Cons(hd, tl), i), (x0, i)))
 conjecture f_Obligation1 is [a] 
    fa(x : Nat, x0 : List(a), D : List(a) * Nat, pV2 : Nat) 
     x < length x0 && pV2 = D.2 => embed?(Cons)(D.1)
endspec

;;; Elaborating proof-term at $TESTDIR/NeedWFO#P
;; ensure-directories-exist: creating $TESTDIR/Both/NeedWFO/P.log
;; Directory $TESTDIR/Both/ does not exist, will create.
;; Directory $TESTDIR/Both/NeedWFO/ does not exist, will create.
P: Conjecture f_Obligation in O is Proved! using simple inequality reasoning.
    Snark Log file: $TESTDIR/Both/NeedWFO/P.log
;;; Elaborating proof-term at $TESTDIR/NeedWFO#P0
P0: Conjecture f_Obligation0 in O is NOT proved using Snark.
    Snark Log file: $TESTDIR/Both/NeedWFO/P0.log
;;; Elaborating proof-term at $TESTDIR/NeedWFO#P1
P1: Conjecture f_Obligation1 in O is NOT proved using Snark.
    Snark Log file: $TESTDIR/Both/NeedWFO/P1.log
")

 )
