spec

 %% notFalse should evaluate to true (or perhaps to itself),
 %% but should not evaluate to false!

 op notFalse : Bool
 def notFalse = (id:Nat->Nat) = id o id

endspec 
