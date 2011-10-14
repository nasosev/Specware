\section{Abstraction of MetaSlang Terms}

Not clear that this is useful at this stage. Would
prefer the qualifier to be MetaSlang but this is taken.

It is expected that \Type{Term} refines to \Type{ATerm Position}
Similary, we expect that \Type{Type} refines to \Type{ATypeScheme Position}

The name of the qualifier is unfortunate. Would prefer \Qualifier{MetaSlang}
or \Qualifier{MS} but both are taken.

\begin{spec}
MSlang qualifying spec
  import /Library/Structures/Data/Pretty
  import /Languages/MetaSlang/AbstractSyntax/AnnTerm
  import Position
  import Id
  import Env

  % type MetaSlang.ATerm b

  type Term = MetaSlang.ATerm Position
  type Type
  type Fun
  type TypeVars

  op Term.pp : Term -> Doc
  op Term.show : Term -> String

  op Type.pp : Type -> Doc
  op Type.show : Type -> String

  op noTypeVars : TypeVars

  op boolType : Position -> Type
  op natType : Position -> Type
  op stringType : Position -> Type

  op MSlangEnv.mkApply : Term * Term * Position -> Env Term
  op mkApply : Term * Term * Position -> Term

  op mkApplyN : Term * Term * Position -> Term

  op MSlangEnv.mkApplyN : Term * Term * Position -> Env Term
  def MSlangEnv.mkApplyN (t1,t2,position) = return (mkApplyN (t1,t2, position))

  op mkTuple : (List Term) * Position -> Term
  op MSlangEnv.mkTuple : (List Term) * Position -> Env Term
  def MSlangEnv.mkTuple args = return (mkTuple args)

  op mkRecord : List (Id.Id * Term) * Position -> Term

  op mkArrow : Type * Type * Position -> Type

  op mkProduct : List Type * Position -> Type

  op MSlangEnv.mkProduct : List Type * Position -> Env Type
  def MSlangEnv.mkProduct args = return (mkProduct args)

  op mkBase : Id.Id * List Type * Position -> Type
  op MSlangEnv.mkBase : Id.Id * List Type * Position -> Env Type
  def MSlangEnv.mkBase args = return (mkBase args)

  op mkEquals : Type * Position -> Term

  op mkEquality : Term * Term * Position -> Term
  op MSlangEnv.mkEquality : Term * Term * Position -> Env Term
  def MSlangEnv.mkEquality args = return (mkEquality args)

  op mkTrue : Position -> Term
  op MSPosEnv.mkTrue : Position -> Env Term

  op mkFalse : Position -> Term
  op MSPosEnv.mkFalse : Position -> Env Term
  
  op mkNot : Term * Position -> Term

  op mkFun : Fun * Type * Position -> Term
  op MSlangEnv.mkFun : Fun * Type * Position -> Env Term
  def MSlangEnv.mkFun args = return (mkFun args)

  op mkOp : Id.Id * Type * Position -> Term
  op mkOr : Term * Term * Position -> Term
  op disjList : List Term * Position -> Term

  op mkNat : Nat * Position -> Term
  op mkString : String * Position -> Term

  op MSNoPos.mkNat : Nat -> Term
  def MSNoPos.mkNat n = mkNat (n, internalPosition)

  op idToNameRef : Id.Id -> Fun

  op freshMetaTyVar : String * Position -> Type
endspec
\end{spec}
