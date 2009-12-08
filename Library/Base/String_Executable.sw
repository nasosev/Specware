spec
 import String

 refine def natConvertible (s:String) : Bool =
   let cs = explode s in
   (exists? isNum cs) && (forall? isNum cs)

 refine def intConvertible (s:String) : Bool =
   let cs = explode s in
   (exists? isNum cs) &&
   ((forall? isNum cs) || (head cs = #- && forall? isNum (tail cs)))

 refine def stringToInt (s:String | Integer.intConvertible s) : Integer =
   let firstchar::_ = explode s in
   if firstchar = #- then - (stringToNat (subFromTo (s,1,length s)))
                     else    stringToNat s

endspec
