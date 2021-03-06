A = spec
%op Nat.+  infixl 25: Nat * Nat -> Nat
op nonNeg?: Int -> Bool

op f: {p: Int * Int | p.1 > - p.2}  -> Nat
%def f(x,y) = x Nat.+ y


def f(x,y) = restrict nonNeg? (x Integer.+ y)
%def f(x,y) = (restrict nonNeg? x) Nat.+ (restrict nonNeg? y)
endspec

O = obligations A

P = prove f_Obligation in O

P0 = prove f_Obligation0 in O
