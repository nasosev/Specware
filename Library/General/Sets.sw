Set qualifying spec

  (* In higher-order logic, it is customary to define a set as a predicate:
  the predicate is true exactly for (i.e. for all and only) the elements of
  the set.

  In this spec we follow that customary approach, which is very clear and
  simple. All the types and ops in this spec are defined, i.e. this spec is a
  definitional extension; therefore, it is readily seen to be consistent.

  The fact that type `Set' is defined means that sets as specified here cannot
  be later refined into a representation different from predicates. This
  should not be a problem because sets may be infinite and therefore cannot be
  refined to be executable (because equality is undecidable). Sets as defined
  here are useful for specification purposes, not for execution. Finite sets
  as defined in spec `FiniteSets' can instead be refined to be executable. *)

  %%%%% NOTE %%%%%
  % this was probably motivated by the translator to Isabelle 2007, where sets
  % were isomorphic to predicates, but now it can be probably removed for
  % Isabelle 2008, where sets are equal to predicates:
  type Predicate a = a -> Boolean

  type Set a = Predicate a

  % membership:

  op [a] in? (x:a, s: Set a) infixl 20 : Boolean = s x

  op [a] nin? (x:a, s: Set a) infixl 20 : Boolean = ~(x in? s)

  %%%%% NOTE %%%%%
  % this was probably motivated by the translator to Isabelle 2007, where sets
  % were isomorphic to predicates, but now it can be probably removed for
  % Isabelle 2008, where sets are equal to predicates:
  %% Coercion function that maps a Set to a Predicate
  op [a] r_in (s: Set a) (x: a): Boolean = x in? s

  % (strict) sub/superset:

  op [a] <= (s1: Set a, s2: Set a) infixl 20 : Boolean =
    fa(x) x in? s1 => x in? s2

  op [a] < (s1: Set a, s2: Set a) infixl 20 : Boolean = (s1 <= s2 && s1 ~= s2)

  op [a] >= (s1: Set a, s2: Set a) infixl 20 : Boolean = (s2 <= s1)

  op [a] > (s1: Set a, s2: Set a) infixl 20 : Boolean = (s2 < s1)

  % complement, intersection, and union (lift `~', `&&', and `||' to sets):

  op [a] ~~ (s: Set a) : Set a = fn x:a -> x nin? s

  op [a] /\ (s1: Set a, s2: Set a) infixr 25 : Set a =
    fn x:a -> x in? s1 && x in? s2

  op [a] \/ (s1: Set a, s2: Set a) infixr 24 : Set a =
    fn x:a -> x in? s1 || x in? s2

  % intersection/union of all sets in a set:

  op [a] //\\ (ss: Set (Set a)) : Set a =
    fn x:a -> (fa(s) s in? ss => x in? s)

  op [a] \\// (ss: Set (Set a)) : Set a =
    fn x:a -> (ex(s) s in? ss && x in? s)

  % lift `=>' and `<=>' to sets:

  op [a] ==> (s1: Set a, s2: Set a) infixr 23 : Set a =
    fn x:a -> x in? s1 => x in? s2

  op [a] <==> (s1: Set a, s2: Set a) infixr 22 : Set a =
    fn x:a -> x in? s1 <=> x in? s2

  % difference:

  op [a] -- (s1: Set a, s2: Set a) infixl 25 : Set a =
    fn x:a -> x in? s1 && x nin? s2

  % cartesian product:

  op [a,b] * (s1: Set a, s2: Set b) infixl 27 : Set (a * b) =
    fn (x:a,y:b) -> x in? s1 && y in? s2

  % powerset:

  op [a] power (s: Set a) : Set (Set a) =
    fn sub: Set a -> sub <= s

  % set with no elements (lift `false' to sets):

  op empty : [a] Set a = fn _ -> false

  op [a] empty? (s: Set a) : Boolean = (s = empty)
  proof Isa [simp] end-proof

  % sets with at least 1 element:

  op [a] nonEmpty? (s: Set a) : Boolean = (s ~= empty)

  type NonEmptySet a = (Set a | nonEmpty?)

  % set with all elements (lift `true' to sets):

  op full : [a] Set a = fn _ -> true
  proof Isa [simp] end-proof

  op [a] full? (s: Set a) : Boolean = (s = full)
  proof Isa [simp] end-proof

  % sets with at least 1 missing element:

  op [a] nonFull? (s: Set a) : Boolean = (s ~= full)
  proof Isa [simp] end-proof

  type NonFullSet a = (Set a | nonFull?)

  % sets with exactly one element:

  op [a] single(*ton*) (x:a) : Set a = fn y:a -> y = x
  proof Isa [simp] end-proof

  op [a] single? (s:Set a) : Boolean = (ex(x:a) s = single x)
  proof Isa [simp] end-proof

  op [a] onlyMemberOf (x:a, s: Set a) infixl 20 : Boolean =
    single? s && x in? s
  proof Isa [simp] end-proof

  type SingletonSet a = (Set a | single?)

  op [a] theMember (s: SingletonSet a) : a = the(x:a) x in? s

  % add member to set (triangle points towards set):

  op [a] <| (s: Set a, x:a) infixl 25 : Set a = s \/ single x
  proof Isa -> with_el [simp] end-proof

  % remove member from set:

  op [a] - (s: Set a, x:a) infixl 25 : Set a = s -- single x
  proof Isa -> less [simp] end-proof

  % map (partial) function over set:

  op [a,b] map (f: a -> b) (s: Set a) : Set b =
    fn y:b -> (ex(x:a) x in? s && y = f x)

  op [a,b] mapPartial (f: a -> Option b) (s: Set a) : Set b =
    fn y:b -> (ex(x:a) x in? s && Some y = f x)

  % inversely map function over set:

  op [a,b] imap (f: a -> b) (s: Set b) : Set a = fn x:a -> f x in? s

  (* A function f from a to b generates a Set b, namely the set of all
  y:b such that y = f x for some x:a. *)

  op [a,b] setGeneratedBy (f: a -> b) : Set b = map f full

  % finite sets:

  op [a] finite? (s: Set a) : Boolean =
    % this disjunct ensures that the definition is correct in case a is empty;
    % if a is empty, Nat -> a is empty and the disjunct below (ex ...) is false,
    % but of course the empty set over empty a is finite (note that there is
    % only one set over empty a, namely the empty set; so, if s is not empty, a
    % is not empty and Nat -> a is not empty):
    empty? s ||
    % there is a surjective function from {i:Nat | i < n} to {x:a | x in? s}
    % (which are "pseudo-types" because of the free variables `n' and `s'):
    (ex (f: Nat -> a, n:Nat)
      (fa(x:a) x in? s => (ex(i:Nat) i < n && f i = x)))

  type FiniteSet a = (Set a | finite?)

  theorem induction is [a]
    fa (p: FiniteSet a -> Boolean)
      p empty &&
      (fa (s: FiniteSet a, x:a) p s => p (s <| x)) =>
      (fa (s: FiniteSet a) p s)

  op size : [a] FiniteSet a -> Nat = the(size)
    (size empty = 0) &&
    (fa (s: FiniteSet a, x:a) size (s <| x) = 1 + size (s - x))

  op [a] hasSize (s: Set a, n:Nat) infixl 20 : Boolean =
    finite? s && size s = n

  (* In order to fold over a finite set, we need the folding function to be
  insensitive to order (a kind of commutativity property). It is not necessary
  that it is also insensitive to repetitions (a kind of idempotence property),
  because we can remove elements from the set as we fold. It is also not
  necessary that the function is commutative on its whole domain: it is
  sufficient that it is commutative on the elements of the set that we are
  folding over. *)

  op [a,b] foldable? (c:b, f: b * a -> b, s: FiniteSet a) : Boolean =
    %% Definition of foldable? doesn't depend on initial value c, but it's
    %% convenient to have foldable? apply to entire sequence of args to fold.
    (fa (x:a, y:a, z:b) x in? s && y in? s => f(f(z,x),y) = f(f(z,y),x))
  proof Isa [simp] end-proof

  op fold : [a,b] ((b * (b * a -> b) * FiniteSet a) | foldable?) -> b =
    the(fold)
      (fa (c: b, f: b * a -> b) fold (c, f, empty) = c) &&
      (fa (c: b, f: b * a -> b, s: FiniteSet a, x: a)
         foldable? (c, f, s <| x) =>
           fold (c, f, s <| x) = f (fold (c, f, s - x), x))

  % finite powerset:

  op [a] powerf (s: Set a) : Set (FiniteSet a) = power s /\ finite?

  % infinite, countable, and uncountable cardinality:

  op infinite? : [a] Set a -> Boolean = ~~ finite?

  type InfiniteSet a = (Set a | infinite?)

  op [a] countable? (s: Set a) : Boolean =
    infinite? s &&
    % there is a surjective function from Nat to {x:a | x in? s}
    % (the latter is a "pseudo-type" because of the free variable `s'):
    (ex (f : Nat -> a)
       (fa(x:a) x in? s => (ex(i:Nat) f i = x)))

  type CountableSet a = (Set a | countable?)

  op uncountable? : [a] Set a -> Boolean = infinite? /\  ~~ countable?

  type UncountableSet a = (Set a | uncountable?)

  % minimum/maximum set:

  op [a] isMinIn (s: Set a, ss: Set (Set a)) infixl 20 : Boolean =
    s in? ss && (fa(s1) s1 in? ss => s <= s1)

  op [a] hasMin? (ss: Set (Set a)) : Boolean = (ex(s) s isMinIn ss)

  type SetOfSetsWithMin a = (Set (Set a) | hasMin?)

  op [a] min (ss: SetOfSetsWithMin a) : Set a = the(s) s isMinIn ss

  proof Isa  Set__min_Obligation_the
    apply(auto simp add: Set__hasMin_p_def Set__isMinIn_def)
  end-proof

  op [a] isMaxIn (s: Set a, ss: Set (Set a)) infixl 20 : Boolean =
    s in? ss && (fa(s1) s1 in? ss => s >= s1)

  op [a] hasMax? (ss: Set (Set a)) : Boolean = (ex(s) s isMaxIn ss)

  type SetOfSetsWithMax a = (Set (Set a) | hasMax?)

  op [a] max (ss: SetOfSetsWithMax a) : Set a = the(s) s isMaxIn ss

  proof Isa  Set__max_Obligation_the
    apply(auto simp add: Set__hasMax_p_def Set__isMaxIn_def)
  end-proof

  % mapping to Isabelle:

  proof Isa Thy_Morphism Set
    type Set.Set -> set (id,id)
    Set.collect -> Collect
    Set.in? -> \<in> Left 20
    Set.nin? -> \<notin> Left 20
    Set.<= -> \<subseteq> Left 20
    Set.< -> \<subset> Left 20
    Set.>= -> \<subseteq> Left 20 reversed
    Set.> -> \<subset> Left 20 reversed
    Set.~~ -> -
    Set./\ -> \<inter> Left 25
    Set.//\\ -> \<Inter>
    Set.\/ -> \<union> Left 24 
    Set.\\// -> \<Union>
    Set.-- -> - Left 25
    Set.* -> <*> Left 27
    Set.power -> Pow
    Set.empty -> {}
    Set.finite? -> finite
  end-proof

endspec
