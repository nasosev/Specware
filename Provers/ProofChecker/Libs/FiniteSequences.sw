FSeq qualifying spec

  import Logic

  (* A finite sequence can be viewed as a function f having an initial segment
  {i:Nat | i < n} of the naturals as domain; n is the length and f(i) is the
  i-th element of the sequence (counting starts from 0, i.e. the elements are
  f(0),...,f(n-1)).

  Since n depends on the sequence, the pseudo subtype {i:Nat | i < n} cannot
  be a Metaslang type. So, we could use a partial function exactly defined on
  an initial segment of the naturals; the restriction on the domain can be
  expressed as a subtype of the type PFunction from spec PartialFunctions.

  From a specification perspective, it would be fine to define the type of
  finite sequences to coincide with the subtype of PFunction. However, it
  would then be impossible to have a morphism from this spec of finite
  sequences to a spec that, for instance, defines finite sequences as lists
  (which provides an implementation). In other words, data refinement as
  morphism would not be possible. For this reason, we just constrain the type
  of finite sequences to be isomorphic to the subtype of PFunction, leaving
  the possibility open to refinements as morphisms.
  *)

  import PartialFunctions

  op definedAtFirstNNaturals? : [a] PFunction(Nat,a) * Nat -> Boolean
  axiom definedAtFirstNNaturals?_def is fa(f,n)
    definedAtFirstNNaturals?(f,n) =
    (fa (i:Nat) i <  n =>   definedAt?(f,i)) &&
    (fa (i:Nat) i >= n => undefinedAt?(f,i))

  type FSeqFunction a =   % functions isomorphic to finite sequences
    {f : PFunction(Nat,a) |
       ex (n:Nat) definedAtFirstNNaturals?(f,n)}

  type FSeq a   % declared, not defined (to allow refinement as morphism)

  op seqFunction : [a] Bijection (FSeq a, FSeqFunction a)   % isomorphism

  % construct sequence from function:
  op seqSuchThat : [a] Bijection (FSeqFunction a, FSeq a)
  def seqSuchThat =
    inverse seqFunction

  op empty : [a] FSeq a
  def empty = seqSuchThat (fn(i:Nat) -> None)

  op empty? : [a] FSeq a -> Boolean
  def empty? s =
    s = empty

  op singleton : [a] a -> FSeq a
  def singleton x =
    seqSuchThat (fn(i:Nat) -> if i = 0 then Some x else None)

  % concatenate:
  op ++ infixl 25 : [a] FSeq a * FSeq a -> FSeq a
  def ++ (s1,s2) =
    seqSuchThat (fn(i:Nat) ->
     % first (length s1) elements are from s1:
          if i < length s1             then Some (s1 elem i)
     % following (length s2) elements are from s2:
     else if i < length s1 + length s2 then Some (s2 elem (i - length s1))
     % there are no other elements:
     else None)

  % prepend element (|> points into sequence):
  op |> infixl 30 : [a] a * FSeq a -> FSeq a
  def |> (x,s) =
    singleton x ++ s

  % append element (<| points into sequence):
  op <| infixl 30 : [a] FSeq a * a -> FSeq a
  def <| (s,x) =
    s ++ singleton x

  % update i-th element:
  op update : [a] {(s,i,x) : FSeq a * Nat * a | i < length s} -> FSeq a
  def update(s,i,x) =
    seqSuchThat (fn(j:Nat) -> if j = i then Some x else seqFunction s j)

  op length : [a] FSeq a -> Nat
  def length s =
    the (fn len -> definedAtFirstNNaturals? (seqFunction s, len))

  % return i-th element:
  op elem infixl 30 : [a] {(s,i) : FSeq a * Nat | i < length s} -> a
  def elem (s,i) = the (fn x -> seqFunction s i = Some x)

  op in? infixl 20 : [a] a * FSeq a -> Boolean
  axiom in?_def is fa(x,s)
    x in? s = (ex (i:Nat) seqFunction s i = Some x)

  % every element satisfies predicate:
  op forall? : [a] FSeq a * Predicate a -> Boolean
  axiom forall?_def is fa(s,p)
    forall?(s,p) =
    (fa (i:Nat) i < length s => p (s elem i))

  % some element satisfies predicate:
  op exists? : fa(a) FSeq a * Predicate a -> Boolean
  axiom exists?_def is fa(s,p)
    exists?(s,p) =
    (ex (i:Nat) i < length s &&  p (s elem i))

  % extract subsequence from i to j (both inclusive):
  op subFromTo : [a] {(s,i,j) : FSeq a * Nat * Nat |
                      i < length s && j < length s && i <= j} -> FSeq a
  def subFromTo(s,i,j) =
    seqSuchThat (fn(k:Nat) -> if k < j - i + 1   % j-i+1 = subsequence length
                              then seqFunction s (i + k)
                              else None)

  % extract subsequence from i (inclusive) of length n:
  op subFromLong : [a] {(s,i,n) : FSeq a * Nat * Nat |
                        i < length s && i + n <= length s} -> FSeq a
  def subFromLong(s,i,n) =
    seqSuchThat (fn(k:Nat) -> if k < n
                              then seqFunction s (i + k)
                              else None)

  % fold starting from left end:
  op foldl : [a,b] FSeq a * b * (b * a -> b) -> b
  def [a,b] foldl =
    the (fn (foldl : FSeq a * b * (b * a -> b) -> b) ->
      (fa (c,f)     foldl (empty,  c, f) = c) &&
      (fa (c,f,x,s) foldl (s <| x, c, f) = f (foldl(s,c,f), x)))

  % fold starting from right end:
  op foldr : [a,b] FSeq a * b * (a * b -> b) -> b
  def [a,b] foldr =
    the (fn (foldr : FSeq a * b * (a * b -> b) -> b) ->
      (fa (c,f)     foldr (empty,  c, f) = c) &&
      (fa (c,f,x,s) foldr (x |> s, c, f) = f (x, foldr(s,c,f))))

  op map : [a,b] (a -> b) * FSeq a -> FSeq b
  def map(f,s) =
    seqSuchThat (fn(i:Nat) -> if i < length s
                              then Some (f (s elem i))
                              else None)

  op map2 : [a,b,c] {(f,s1,s2) : (a * b -> c) * FSeq a * FSeq b |
                     length s1 = length s2} -> FSeq c
  def map2(f,s1,s2) =
    seqSuchThat (fn(i:Nat) -> if i < length s1 % = length s2
                              then Some (f (s1 elem i, s2 elem i))
                              else None)

  op filter : [a] FSeq a * Predicate a -> FSeq a
  def [a] filter =
    the (fn (filter : FSeq a * Predicate a -> FSeq a) ->
      (fa(p)       filter (empty,  p) = empty) &&
      (fa(x,s,p)   filter (x |> s, p) =
                   (if p x then x |> filter(s,p) else filter(s,p))))

  op repeat : [a] a * Nat -> FSeq a
  def repeat(x,n) =
    seqSuchThat (fn(i:Nat) -> if i < n then Some x else None)

  op reverse : [a] FSeq a -> FSeq a
  def reverse s =
    seqSuchThat (fn(i:Nat) -> if i < length s
                              then seqFunction s (length s - i -1)
                              else None)

  op zip : [a,b] {(s1,s2) : FSeq a * FSeq b | length s1 = length s2}
                 -> FSeq (a * b)
  def zip(s1,s2) =
    seqSuchThat (fn(i:Nat) -> if i < length s1 % = length s2
                              then Some (s1 elem i, s2 elem i)
                              else None)

  op unzip : [a,b] FSeq (a * b) -> FSeq a * FSeq b
  def unzip s =
    (seqSuchThat (fn(i:Nat) -> if i < length s
                               then Some (s elem i).1
                               else None),
     seqSuchThat (fn(i:Nat) -> if i < length s
                               then Some (s elem i).2
                               else None))

  % non-empty sequences:
  type FSeqNE a = {s : FSeq a | ~(empty? s)}

  op first : [a] FSeqNE a -> a
  def first s =
    s elem 0

  op last : [a] FSeqNE a -> a
  def last s =
    s elem (length s - 1)

  % left tail (i.e. remove last element):
  op ltail : [a] FSeqNE a -> FSeq a
  def ltail s =
    subFromLong (s, 0, length s - 1)

  % right tail (i.e. remove first element):
  op rtail : fa(a) FSeqNE a -> FSeq a
  def rtail s =
    subFromLong (s, 1, length s - 1)

  op noRepetitions? : [a] FSeq a -> Boolean
  axiom noRepetitions?_def is fa(s)
    noRepetitions? s =
    (fa (i:Nat, j:Nat) i < length s && j < length s && (i ~= j) =>
                       s elem i ~= s elem j)

  % sequences without repetitions:
  type FSeqNR a = (FSeq a | noRepetitions?)

endspec
