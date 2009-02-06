(* change this qualifier to "Map" -> *) MapAC qualifying spec

  import Relation

  % recall that spec `Relations' defines type `Map(a,b)'

  % map (not) defined at element:

  op [a,b] definedAt (m: Map(a,b), x:a) infixl 20 : Bool = x in? domain m

  op [a,b] undefinedAt (m: Map(a,b), x:a) infixl 20 : Bool = x nin? domain m

  % map application (op @@ is a totalization of @):

  op [a,b] @ (m: Map(a,b), x:a | m definedAt x) infixl 30 : b = the(y:b) m(x,y)

  op [a,b] @@ (m: Map(a,b), x:a) infixl 30 : Option b =
    if m definedAt x then Some (m @ x) else None

  % update map at point(s) (analogous to record update):

  op [a,b] <<< (m1: Map(a,b), m2: Map(a,b)) infixl 25 : Map(a,b) = the(m)
    domain m = domain m1 \/ domain m2 &&
    (fa(x) x in? domain m =>
           m @ x = (if m2 definedAt x then m2 @ x else m1 @ x))

  op [a,b] update (m: Map(a,b)) (x:a) (y:b) : Map(a,b) = m <<< single (x, y)

  % remove domain value(s) from map:

  op [a,b] -- (m: Map(a,b), xS: Set a) infixl 25 : Map(a,b) =
    m restrictDomain (~~ xS)

  op [a,b] - (m: Map(a,b), x:a) infixl 25 : Map(a,b) = m -- single x
  proof Isa -> mless [simp] end-proof

  % maps agree on intersection of domains:

  op [a,b] agree? (m1: Map(a,b), m2: Map(a,b)) : Bool =
    functional? (m1 \/ m2)

  type TotalMap(a,b) = (Map(a,b) | total?)

  % convert between (total) maps and functions:

  op [a,b] fromFunction (f: a -> b) : TotalMap(a,b) = fn (x,y) -> y = f x

  op toFunction : [a,b] TotalMap(a,b) -> (a -> b) = inverse fromFunction

  % convert between maps and (partial) functions (modeled via Option):

  op [a,b] fromPartialFun (f: a -> Option b) : Map(a,b) =
    fn (x,y) -> f x = Some y

  op toPartialFun : [a,b] Map(a,b) -> (a -> Option b) = inverse fromPartialFun

  % surjective, injective, and bijective:

  type SurjectiveMap(a,b) = (Map(a,b) | Relation.surjective?)

  type InjectiveMap(a,b) = (Map(a,b) | Relation.injective?)

  type BijectiveMap(a,b) = (Map(a,b) | Relation.bijective?)

  % cardinalities:

  type      FiniteMap(a,b) = (Map(a,b) | finite?)
  type    InfiniteMap(a,b) = (Map(a,b) | infinite?)
  type   CountableMap(a,b) = (Map(a,b) | countable?)
  type UncountableMap(a,b) = (Map(a,b) | uncountable?)

endspec
