
S = spec

  type A
  axiom foo1 is fa (x : A) x = x

  type Q.B
  axiom foo2 is fa (x : B) x = x
  axiom foo3 is fa (x : Q.B) x = x

  type C
  type Q.C
  axiom foo4 is fa (x : C) x = x
  axiom foo5 is fa (x : Q.C) x = x

  type Q1.D
  type Q2.D
  axiom foo6 is fa (x : Q1.D) x = x
  axiom foo7 is fa (x : Q2.D) x = x

endspec


Winner = translate S by {A +-> AA, B +-> BB, C +-> CC, Q1.D +-> DD}

Loser = translate S by {D +-> DD}
