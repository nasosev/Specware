% derived from SW4/Languages/MetaSlang/ADT/Specs/PosSpec.sl, v1.5
% derived from SW4/Languages/MetaSlang/ADT/Specs/PosSpecSig.sl v1.1.1.1

spec {
 import AnnSpec
 import /Library/Legacy/DataStructures/NatMap  % for metaTyVars

 sort Position = (Nat * Nat) * (Nat * Nat)

 %% -- See ../AbstractSyntax/AnnTerm.sl
 sort PTerm            = ATerm           Position
 sort PVar             = AVar            Position
 sort PMatch           = AMatch          Position
 sort PSort            = ASort           Position
 sort PPattern         = APattern        Position
 sort PFun             = AFun            Position

 sort PMetaTyVar       = AMetaTyVar      Position
 sort PMetaTyVars      = AMetaTyVars     Position
 sort PMetaSortScheme  = AMetaSortScheme Position

 sort PFields          = AFields         Position
 sort PField           = AField          Position

 %% -- See AnnSpec

 sort PosSpec          = ASpec           Position 

 sort PSortMap         = ASortMap        Position
 sort POpMap           = AOpMap          Position

 sort PSortInfo        = ASortInfo       Position
 sort POpInfo          = AOpInfo         Position

 sort PProperties      = AProperties     Position
 sort PProperty        = AProperty       Position

 sort PosSpecs         = ASpecs          Position 

 sort POpSignature     = AOpSignature    Position
 sort PSortScheme      = ASortScheme     Position

 % sort PQualifierMap    = AQualifierMap   Position

 % ------------------------------------------------------------------------
 %  Built-in operator supported from the compiler side.
 %

 def zeroPosition () : Position = ((0,0),(0,0))

 def pos0 = zeroPosition()

 % ------------------------------------------------------------------------

 op printPosition : Position -> String
 def printPosition (p1,p2) = 
     let printPos = fn(l,r) -> (Nat.toString l)^"."^(Nat.toString r) in
     printPos p1^"-"^printPos p2

 % ------------------------------------------------------------------------
 %  Base PSort's
 % ------------------------------------------------------------------------

 op mkPBase : QualifiedId * List PSort -> PSort
 def mkPBase (qid, srts) = PBase (qid, srts, pos0)

 op boolPSort   : PSort
 op charPSort   : PSort
 op stringPSort : PSort
 op natPSort    : PSort
 % op intPSort  : PSort

 def boolPSort   = mkPBase (Qualified ("Boolean", "Boolean"), [])
 def charPSort   = mkPBase (Qualified ("Char",    "Char"),    [])
 def stringPSort = mkPBase (Qualified ("String",  "String"),  [])
 def natPSort    = mkPBase (Qualified ("Nat",     "Nat"),     [])
 % def intPSort  = mkPBase (Qualified ("Integer", "Integer"), [])

 % ------------------------------------------------------------------------
 %  Constructors of PSort's
 % ------------------------------------------------------------------------

 op mkProduct : List PSort     -> PSort
 op mkArrow   : PSort * PSort  -> PSort

 % ------------------------------------------------------------------------

 def mkProduct psorts : PSort =
  let def loop (n, psorts) = 
       case psorts of
        | [] -> []
        | (psrt::psorts) -> List.cons((Nat.toString n, psrt), loop(n + 1, psorts))
  in
    (Product(loop(1, psorts), pos0))

 def mkArrow (s1, s2) : PSort = Arrow (s1, s2, pos0)

 % ------------------------------------------------------------------------
 %   Primitive PTerm's
 % ------------------------------------------------------------------------

 op mkTrue      : ()                  -> PTerm
 op mkString    : String              -> PTerm
 op mkOp        : QualifiedId * PSort -> PTerm % ?

 % ------------------------------------------------------------------------

 def mkTrue ()  = Fun(Bool true,boolPSort,pos0)
 %def mkFalse() = Fun(Bool false,boolPSort,pos0)

 def mkString s = Fun(String s,stringPSort,pos0)
 def mkOp (qid, srt) = Fun (Op (qid, Nonfix), srt, pos0)

 % ------------------------------------------------------------------------
 %  Constructors of PTerm's
 % ------------------------------------------------------------------------

 op mkApplyN      : PTerm * PTerm                 -> PTerm
 op mkTuple       : List PTerm                    -> PTerm
 op mkList        : List PTerm * Position * PSort -> PTerm

 % ------------------------------------------------------------------------

 def mkApplyN (t1, t2) : PTerm = ApplyN ([t1, t2],       pos0)
 def mkTuple  terms    : PTerm = Record (tagTuple terms, pos0)

 op tagTuple  : fa(A) List(A) -> List(Id * A)
 def tagTuple terms = 
  let def loop (index, terms) = 
        case terms of
         | []        -> []
         | tm::terms -> cons((toString index, tm), loop(index + 1, terms))
  in loop (1, terms)

 % ------------------------------------------------------------------------

 def mkList (terms : List PTerm, pos, element_type) = 
  let list_type  = PBase (Qualified ("List", "List"),                                [element_type], pos) in
  let cons_type  = Arrow (Product   ([("1", element_type), ("2", list_type)], pos),  list_type,      pos) in
  let consFun    = Fun   (Embed     ("Cons", true),                                  cons_type,      pos) in
  let empty_list = Fun   (Embed     ("Nil",  false),                                 list_type,      pos) in
  let def mkCons (x, xs) = ApplyN ([consFun, Record( [("1",x), ("2",xs)], pos)], pos) in
  List.foldr mkCons empty_list terms

 def mkOneName  (x,    fixity, srt) = Fun (OneName  (x,    fixity), srt, pos0)
 def mkTwoNames (x, y, fixity, srt) = Fun (TwoNames (x, y, fixity), srt, pos0)

 % ------------------------------------------------------------------------
 %  Recursive constructors of PPattern's
 % ------------------------------------------------------------------------

 op mkListPattern : List PPattern       * Position * PSort -> PPattern
 op mkConsPattern : PPattern * PPattern * Position * PSort -> PPattern

 def mkListPattern (patterns : List PPattern, pos, element_type) : PPattern = 
  let list_type  = PBase (Qualified("List","List"),  [element_type], pos) in
  let empty_list = EmbedPat ("Nil",  None,  list_type, pos) in
  let def mkCons (x, xs) = 
       EmbedPat ("Cons", Some (RecordPat ([("1",x), ("2",xs)], pos)), list_type, pos) in
  List.foldr mkCons empty_list patterns

 def mkConsPattern (p1 : PPattern, p2 : PPattern, pos, element_type) : PPattern =
  let list_type  = PBase (Qualified("List","List"), [element_type], pos) in
  EmbedPat ("Cons", Some (RecordPat ([("1",p1), ("2",p2)], pos)), list_type, pos)

 % ------------------------------------------------------------------------
 %   ???
 % ------------------------------------------------------------------------

 op insertDefaultMatches : PosSpec -> PosSpec

 op abstractSort : (String -> TyVar) * List String * PSort -> TyVars * PSort
 op abstractTerm : (String -> TyVar) * List String * PTerm -> TyVars * PTerm

 op removeDefinitions : PosSpec -> PosSpec
 op exportSpec        : PosSpec -> PosSpec

 % ------------------------------------------------------------------------

  %% sjw: Adds wildcard rule at the end of all lambdas in spec so they are complete
 def insertDefaultMatches (old_spec : PosSpec) : PosSpec = 
  let def doTerm (term : PTerm) : PTerm =
       case term of
        | Lambda (match, pos) ->
          %% sjw: srt is not used. This can only be called to detect an error early.
          (* "_" was "srt" *)
          let _     = termSort (let (_, _, b) = hd match in b) in
          let match = extendMatch (match, pos) in
          Lambda (match, pos)
        | _ -> term
  in
  let mkT = mapTerm (doTerm, fn s -> s, fn p -> p) in
  %% let mkS = mapSort (doTerm, fn s -> s, fn p -> p) in % unused for now
  setOps (old_spec, 
          %% sjw: Might need to replace  srt  by  mkS srt  if we do coercion of quotients
          %% but now the terms in sorts of ops do not get executed
          StringMap.map (fn qmap -> StringMap.map (fn (op_names, fixity, srt, Some term) -> 
                                                      (op_names, fixity, srt, Some (mkT term))
                                                    | op_info -> op_info)
                                                  qmap)
                        old_spec.ops)


 % Extend a pattern match with a default case if the last case
 % is not a wild-card or variable. Could be made more sophisticated
 % by detecting more compilcated exhaustive matches.
 % A similar utilities is in the PatternMatch compiler.
 def extendMatch (match, pos) = 
  let def loop (rules : PMatch) : PMatch = 
       case rules of
        | [] -> []
        | [(WildPat _, Fun (Bool true, _, _), body)] -> match
        | [(VarPat  _, Fun (Bool true, _, _), body)] -> match
        | [rule as (pat, cond, body)] -> 
          match ++  [(WildPat (patternSort pat, pos),
                      mkTrue (),
                      mkFail (pos, termSort body))]
        | _::rules ->  loop rules
  in
    loop match

 % ------------------------------------------------------------------------
 %   Construct or extend a PosSpec
 % ------------------------------------------------------------------------

 sort PropertyName = String
 sort SpecName     = String

 op addPSort : (Qualifier * Id * TyVars * Option PSort) * PosSpec -> PosSpec
 op addPOp : (Qualifier * Id * Fixity * PSortScheme * Option PTerm) * PosSpec -> PosSpec

 %op addAxiom          : (PropertyName   * TyVars * PTerm)                      * PosSpec -> PosSpec
 %op addTheorem        : (PropertyName   * TyVars * PTerm)                      * PosSpec -> PosSpec
 %op addConjecture     : (PropertyName   * TyVars * PTerm)                      * PosSpec -> PosSpec
 %op addProperty       : PProperty                                              * PosSpec -> PosSpec
 %op addImport         : Import                                                 * PosSpec -> PosSpec

 op removeDefinitions :                                                          PosSpec -> PosSpec

 % ------------------------------------------------------------------------

 def addPSort ((qualifier, id, new_type_vars, new_opt_def), old_spec) : PosSpec =
  %% qualifier could be "<unqualified>" !
  let old_sorts = old_spec.sorts in
  let old_qmap = case StringMap.find (old_sorts, qualifier) of
                  | None          -> StringMap.empty
                  | Some old_qmap -> old_qmap
  in
  let new_qmap =  
      case StringMap.find (old_qmap, id) of
       | None -> StringMap.insert (old_qmap, id, ([Qualified(qualifier, id)], new_type_vars, new_opt_def))
       | Some (old_sort_names, old_type_vars, old_opt_def) -> 
      case (new_opt_def, old_opt_def) of
       | (None,   None)   -> System.fail ("Sort "^id^" has been redeclared")
       | (Some _, None)   -> if length new_type_vars = length old_type_vars
                             %%  Sort S (A,B)
                             %%  Sort S (X,Y) = T(X,Y)
                             then StringMap.insert(old_qmap, id, (old_sort_names, new_type_vars, new_opt_def))
                             else fail ("Sort "^id^" redefined using different type variable lists")
       | (None,   Some _) -> if length new_type_vars = length old_type_vars
                             %%  Sort S (X,Y) = T(X,Y)
                             %%  Sort S (A,B)
                             then old_qmap % StringMap.insert(old_qmap, id, (old_sort_names, old_type_vars, old_opt_def))
                             else fail ("Sort "^id^" redefined using different type variable lists")
       | (Some _, Some _) -> fail ("Sort "^id^" has been redefined")
  in
  let new_sorts = StringMap.insert (old_sorts, qualifier, new_qmap)
  in 
    setSorts (old_spec, new_sorts)

 def addPOp ((qualifier, id, new_fixity, new_sort_scheme, new_opt_def), old_spec) : PosSpec =
  %% qualifier could be "<unqualified>" !
  let old_ops = old_spec.ops in
  let old_qmap = case StringMap.find (old_ops, qualifier) of
                  | None          -> StringMap.empty
                  | Some old_qmap -> old_qmap
  in
  let new_qmap =
      case StringMap.find (old_qmap, id) of
       | None -> StringMap.insert(old_qmap, id, ([Qualified(qualifier,id)], new_fixity, new_sort_scheme, new_opt_def))
       | Some (old_op_names, old_fixity, old_sort_scheme, old_opt_def) -> 
      case (new_opt_def, old_opt_def) of
       | (None,   Some _) -> %%  def foo (x, y) = baz (x, y)
                             %%  op foo : A * B -> C
                             StringMap.insert(old_qmap, id, (old_op_names, new_fixity, new_sort_scheme, old_opt_def))
       | (Some _, None)   -> %%  op foo : A * B -> C
                             %%  def foo (x, y) = baz (x, y)
                             StringMap.insert(old_qmap, id, (old_op_names, old_fixity, old_sort_scheme, new_opt_def))
       | (None,   None)   -> %%  op foo : ...
                             %%  op foo : ...
                             fail ("Operator "^id^" has been redeclared")
       | (Some _, Some _) -> %%  def foo ...
                             %%  def foo ...
                             fail ("Operator "^id^" has been redefined")
  in
  let new_ops = StringMap.insert (old_ops, qualifier, new_qmap)
  in
    setOps (old_spec, new_ops)

 % ------------------------------------------------------------------------

 def removeDefinitions old_spec : PosSpec =
  let new_ops =
      StringMap.mapDouble (fn (op_names, fixity, (tyVars, srt), optTerm) -> 
                              (op_names, fixity, (tyVars, srt), None : Option PTerm))
                            old_spec.ops
  in
    {imports          = old_spec.imports,
     importedSpec     = old_spec.importedSpec,
     ops              = new_ops,
     sorts            = old_spec.sorts,
     properties       = emptyAProperties}

 % ------------------------------------------------------------------------

 sort MetaTyVarsContext = {map     : Ref (NatMap.Map String),
                           counter : Ref Nat}

 def initializeMetaTyVars() : MetaTyVarsContext = 
   { map = Ref NatMap.empty, counter = Ref 0}

 def findTyVar (context : MetaTyVarsContext, uniqueId) : TyVar = 
    let mp = ! context.map in
    case NatMap.find(mp,uniqueId)
      of Some name -> name
       | None -> 
         let number    = ! context.counter   in
         let increment = number Nat.div 5           in
         let parity    = number Nat.rem 5           in
         let prefix = 
             (case parity 
                of 0 -> "a" | 1 -> "b" | 2 -> "c" | 3 -> "d" | 4 -> "e")
         in
         let suffix = if increment = 0 then "" else Nat.toString increment in
         let name = prefix ^ suffix in name
         
 %%
 %% It is important that the order of the type variables is preserved
 %% as this function is used to abstract sort in recursive sort defintions.
 %% For example, if 
 %% sort ListPair(a,b) = | Nil | Cons a * b * ListPair(a,b)
 %% is defined, then abstractSort is used to return the pair:
 %% ( (a,b), | Nil | Cons a * b * ListPair(a,b) )
 %%

 def makeTyVarMap (fresh, tyVars) = 
  let def insert (tv, map) = StringMap.insert (map, tv, fresh tv) in
  let m = List.foldr insert StringMap.empty tyVars in
  let doSort = 
      fn (srt as PBase (Qualified (_, s), [], pos) : PSort) -> 
         (case StringMap.find (m, s) of
           | Some tyVar -> TyVar (tyVar, pos) : PSort
           | None -> srt) 
       | s -> s
  in
    (m, doSort)

 def mapImage (m, vars) = 
     List.map (fn d -> case StringMap.find (m, d) of Some v -> v) vars

 def abstractSort (fresh, tyVars, srt) = 
  if null tyVars then ([], srt) else
  let (m, doSort) = makeTyVarMap (fresh, tyVars) in
  let srt = mapSort (fn M -> M, doSort, fn p -> p) srt in
  (mapImage (m, tyVars), srt)

 def abstractTerm (fresh, tyVars, trm) = 
  let (m, doSort) = makeTyVarMap (fresh, tyVars) in
  let trm = mapTerm (fn M -> M, doSort, fn p -> p) trm in
  (mapImage (m, tyVars), trm)


  %% Replace locally defined declarations by imported ones, such that
  %% when looking up the name from a different spec these declarations
  %% appear as external.

 def exportSpec (spc : PosSpec) = spc
 (* TODO: Fix this?
      let def export_sort (srt : PSort) : PSort = 
              case srt
                of PBase (Qualified(_,    id), srts, pos) -> 
                   PBase (Qualified(name, id), srts, pos)
                 | _ -> srt
      in
      let def export_term (trm : PTerm) : PTerm = 
              case trm of
               % TODO: This might be nonsense...
               | Fun (OneName id, srt, pos) -> 
                 Fun (Op (Qualified (name, id),  Nonfix), srt, pos)
               | Fun (TwoNames (x, y), srt, pos) -> 
                 Fun (Op (Qualified (x, y),      Nonfix), srt, pos)
               | _ -> trm
      in
      mapSpec (export_sort, export_term, fn p -> p) spc                
 *)

 def mkFail (((l1,r1), (l2,r2)), srt) =
  let srt1 = Arrow (stringPSort, srt, pos0) in
  let msg  = if l1 = 0 & l2 = 0 & r1 = 0 & r2 = 0 
             % Location is non-informative.
             then "Non-exhaustive match failure"
             else "Non-exhaustive match failure around " ^
                  Nat.toString l1^"."^Nat.toString r1^" - "^
                  Nat.toString l2^"."^Nat.toString r2 in                 
  ApplyN ([mkOp (Qualified ("BuiltIn", "Fail"), srt1),
           mkString msg],
          pos0)
}
