Functions qualifying spec

  (* Functions are built-in in Metaslang (A -> B is the type of all functions
  from type A to type B). This spec introduces some operations on functions and
  some subtypes of functions. *)

  % identity and composition:

  op id : [a] a -> a = fn x -> x

  op [a,b,c] o (g: b -> c, f: a -> b) infixl 24 : a -> c = fn x:a -> g (f x)

  theorem identity is [a,b]
    fa (f: a -> b) id o f = f
                && f o id = f
  proof Isa Functions__identity__stp
    apply(auto)
    apply(rule ext, simp)+
  end-proof

  theorem associativity is [a,b,c,d]
    fa (f: a -> b, g: b -> c, h: c -> d) (h o g) o f = h o (g o f)
  proof Isa
    apply(simp add: o_assoc)
  end-proof
  proof Isa Functions__associativity__stp
    apply(rule ext, simp)
  end-proof

  % forward (a.k.a. diagrammatic) composition:

  op [a,b,c] :> (f: a -> b, g: b -> c) infixl 24 : a -> c = g o f

  % injectivity, surjectivity, bijectivity:

  op [a,b] injective? (f: a -> b) : Boolean =
    fa (x1:a,x2:a) f x1 = f x2 => x1 = x2
  proof Isa
    apply(simp add: inj_on_def)
  end-proof
  proof Isa injective_p__stp [simp] end-proof

  op [a,b] surjective? (f: a -> b) : Boolean =
    fa (y:b) (ex (x:a) f x = y)
  proof Isa
    apply(simp add: surj_def eq_commute)
  end-proof

  op [a,b] bijective? (f: a -> b) : Boolean =
    injective? f && surjective? f
  proof Isa
    apply(simp add: bij_def)
  end-proof

  type Injection (a,b) = ((a -> b) | injective?)

  type Surjection(a,b) = ((a -> b) | surjective?)

  type Bijection (a,b) = ((a -> b) | bijective?)

  % inversion:

  op [a,b] inverse (f: Bijection(a,b)) : Bijection(b,a) =
    fn y:b -> the(x:a) f x = y
  proof Isa
    apply(simp add: inv_def)
    sorry
  end-proof
  proof Isa inverse__stp [simp] end-proof

  proof Isa inverse__stp_Obligation_subsort
    apply(auto)
    (** first subgoal **)
    apply(subgoal_tac "\<forall>y. f (THE x. P__a x \<and> f x = y) = y", auto) 
    (** subgoal 1.1 **)
    apply(subgoal_tac "f (THE x. P__a x \<and> f x = x1) = f(THE x. P__a x \<and> f x = x2)")
    apply(rotate_tac 4, frule_tac x="x1" in spec, drule_tac x="x2" in spec)
    (** Isabelle has no good equality reasoning tactic, so we need to guide it **)
    apply(rule_tac s="f (THE x. P__a x \<and> f x = x2)" in trans)
    apply(rule_tac s="f (THE x. P__a x \<and> f x = x1)" in trans)
    apply(rule sym, assumption, assumption, assumption,auto)
    (** subgoal 1.2 **)
    apply(drule_tac x="y" in spec, erule exE)
    apply(rule_tac a="x" in theI2, auto)
    (** second subgoal **)
    apply(rule exI, auto)
  end-proof

  (* Since we map SpecWare's "inverse f = \<lambda>y. THE x. f x = y)"
     to Isabelle's           "inv f     = \>lambda>y. SOME x. f x = y)"
     we need to show that this is the same if f is a bijection
  *)

  proof Isa inverse_Obligation_subsort
    apply(subgoal_tac "( \<lambda>y. THE x. f x = y) = inv f")
    apply(auto simp add: bij_def)
    apply(erule surj_imp_inj_inv)
    apply(erule inj_imp_surj_inv)
    apply(rule ext, rule the_equality, auto simp add: surj_f_inv_f)
  end-proof

  proof Isa inverse_Obligation_the
    apply(auto simp add: bij_def surj_def inj_on_def)
    apply(drule spec, erule exE, drule sym, auto)
  end-proof

  proof Isa inverse_subtype_constr
    apply(auto simp add: bij_def)
    apply(erule surj_imp_inj_inv)
    apply(erule inj_imp_surj_inv)
  end-proof

  theorem inverse_comp is [a,b]
    fa(f:Bijection(a,b)) f o inverse f = id
                      && inverse f o f = id
  proof Isa
    apply(simp add: bij_def surj_iff inj_iff)
  end-proof
  proof Isa inverse_comp__stp
    apply(auto)
    apply(rule ext, auto, rule the1I2, auto)
    apply(rule ext, auto)
  end-proof

  theorem f_inverse_apply is [a,b]
    fa(f:Bijection(a,b), x: b) f(inverse f (x)) = x
  proof Isa
    apply(simp add: bij_def surj_f_inv_f)
  end-proof

  theorem inverse_f_apply is [a,b]
    fa(f:Bijection(a,b), x: a) inverse f(f (x)) = x
  proof Isa
    apply(simp add: bij_def inv_f_f)
  end-proof
  proof Isa f_inverse_apply__stp
    apply(simp add: bij_def surj_iff inj_iff)
    apply(rule the1I2, auto)
  end-proof

  % eta conversion:

  theorem eta is [a,b]
    fa(f: a -> b) (fn x -> f x) = f
  proof Isa eta__stp
    apply(rule ext, simp)
  end-proof

  % used by obligation generator:

  op  wfo: [a] (a * a -> Boolean) -> Boolean

  % mapping to Isabelle:

  proof Isa ThyMorphism
    Functions.id          -> id
    Functions.o           -> o Left 24
    Functions.:>          -> o Left 24 reversed
    Functions.injective?  -> inj
    Functions.surjective? -> surj
    Functions.bijective?  -> bij
    Functions.inverse     -> inv
  end-proof

endspec
