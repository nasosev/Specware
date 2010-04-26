Haskell qualifying spec

 import /Languages/SpecCalculus/Semantics/Evaluate/Signature
 import /Languages/SpecCalculus/Semantics/Evaluate/Spec/AddSpecElements
 import /Provers/ToIsabelle/TheoryMorphism
 import /Languages/MetaSlang/Transformations/NormalizeTypes
 import /Library/PrettyPrinter/BjornerEspinosa
 import /Library/Legacy/DataStructures/ListUtilities
 import /Languages/SpecCalculus/AbstractSyntax/Types
 import /Languages/SpecCalculus/Semantics/Value
 import /Languages/SpecCalculus/Semantics/Evaluate/UnitId/Utilities
 import /Languages/MetaSlang/Specs/Environment
 import /Languages/MetaSlang/Transformations/Coercions
 import /Languages/MetaSlang/Transformations/Simplify
 import /Languages/MetaSlang/Transformations/CurryUtils

 op simplify?: Boolean       = true

 type Pretty = PrettyPrint.Pretty
 type Pragma = String * String * String * Position

 type Context = {recursive?: Boolean,
                 thy_name: String,
		 spec?: Option Spec,
                 currentUID: Option UnitId,
		 trans_table: TransInfo,
                 coercions: TypeCoercionTable,
                 overloadedConstructors: List String,
                 newVarCount: Ref Nat,
                 source_of_thy_morphism?: Boolean,
                 typeNameInfo: List(QualifiedId * TyVars * Sort)}

 op  specialOpInfo: Context \_rightarrow QualifiedId \_rightarrow Option OpTransInfo
 def specialOpInfo c qid = apply(c.trans_table.op_map, qid)

 op  specialTypeInfo: Context \_rightarrow QualifiedId \_rightarrow Option TypeTransInfo
 def specialTypeInfo c qid = apply(c.trans_table.type_map, qid)

 op  getSpec: Context \_rightarrow Spec
 def getSpec {recursive?=_, thy_name=_, spec? = Some spc,
              currentUID=_, trans_table=_, coercions=_, overloadedConstructors=_,
              newVarCount=_, source_of_thy_morphism?=_, typeNameInfo=_} = spc

 op  getCurrentUID: Context \_rightarrow UnitId
 def getCurrentUID {recursive?=_, thy_name=_, spec?=_, currentUID = Some uid,
                    trans_table=_, coercions=_, overloadedConstructors=_, newVarCount=_,
                    source_of_thy_morphism?=_, typeNameInfo=_} =
   uid


 type ParentTerm = | Top | Nonfix | Infix Associativity * Nat
 type ParentSort = | Top | ArrowLeft | ArrowRight | Product | CoProduct
                   | Quotient | Subsort | Apply

 type SpecTerm = SpecCalc.SpecTerm StandardAnnotation
 type Term = SpecCalc.Term StandardAnnotation
 type SpecElem = SpecCalc.SpecElem StandardAnnotation
 type Decl = SpecCalc.Decl StandardAnnotation

 op  prNum: Integer \_rightarrow Pretty
 def prNum n = prString(show n)

 def prString s = string s

 %def prBreak =
 %def prNewline =
 op  prConcat: List Pretty \_rightarrow Pretty
 def prConcat l = prettysNone l

 op  prEmpty: Pretty
 def prEmpty = prConcat []

 op  prBreak: Nat \_rightarrow List Pretty \_rightarrow Pretty
 def prBreak n l = blockFill(0, (List.map (\_lambda x \_rightarrow (n,x)) l))

 op  prLinear: Nat \_rightarrow List Pretty \_rightarrow Pretty
 def prLinear n l = blockLinear(0, (List.map (\_lambda x \_rightarrow (n,x)) l))

 op  prLines: Nat \_rightarrow List Pretty \_rightarrow Pretty
 def prLines n l = blockAll(0, (List.map (\_lambda x \_rightarrow (n,x)) l))

 op  prBreakCat: Nat \_rightarrow List (List Pretty) \_rightarrow Pretty
 def prBreakCat n l = blockFill(0, (map (\_lambda x \_rightarrow (n,prConcat x)) l))

 op  prLinearCat: Nat \_rightarrow List (List Pretty) \_rightarrow Pretty
 def prLinearCat n l = blockLinear(0, (map (\_lambda x \_rightarrow (n,prConcat x)) l))

 op  prLinesCat: Nat \_rightarrow List (List Pretty) \_rightarrow Pretty
 def prLinesCat n l = blockAll(0, (map (\_lambda x \_rightarrow (n,prConcat x)) l))

 op  prSep: Nat \_rightarrow (Nat * Lines \_rightarrow Pretty) \_rightarrow Pretty \_rightarrow List Pretty \_rightarrow Pretty
 def prSep n blockFn sep l =
   case l of
     | [] \_rightarrow prEmpty
     | [p] \_rightarrow p
     | p::r \_rightarrow
       blockFn(0, Cons((0,p), List.map (\_lambda x \_rightarrow (n, prConcat [sep, x])) r))

 op  prPostSep: Nat \_rightarrow (Nat * Lines \_rightarrow Pretty) \_rightarrow Pretty \_rightarrow List Pretty \_rightarrow Pretty
 def prPostSep n blockFn sep l =
   case l of
     | [] \_rightarrow prEmpty
     | [p] \_rightarrow p
     | _ \_rightarrow
       blockFn(0, (List.map (\_lambda x \_rightarrow (n, prConcat [x, sep])) (butLast l)) ++ [(0, last l)])

  %% --------------------------------------------------------------------------------
  %% Give the signature of utilities so we don't have to import them

  type GlobalContext
  %op  MonadicStateInternal.readGlobalVar : [a] String \_rightarrow Option a
  op  Specware.evaluateUnitId: String \_rightarrow Option Value
  %op  SpecCalc.findUnitIdForUnit: Value \_times GlobalContext \_rightarrow Option UnitId
  %op  SpecCalc.uidToFullPath : UnitId \_rightarrow String
  op  Specware.cleanEnv : SpecCalc.Env ()
  op  Specware.runSpecCommand : [a] SpecCalc.Env a \_rightarrow a


  op  uidToHaskellName : UnitId \_rightarrow String
  def uidToHaskellName {path, hashSuffix=_} =
   let device? = deviceString? (head path) in
   let main_name = last path in
   let path_dir = butLast path in 
   let mainPath = flatten (foldr (\_lambda (elem, result) \_rightarrow "/"::elem::result)
			        ["/Haskell/", thyName main_name]
				(if device? then tail path_dir else path_dir))
   in if device?
	then (head path) ^ mainPath
	else mainPath


  op  printUIDtoThyFile: String \_times Boolean \_rightarrow String
  def printUIDtoThyFile (uid_str, recursive?) =
    case Specware.evaluateUnitId uid_str of
      | Some val \_rightarrow
        (case uidNamesForValue val of
	   | None \_rightarrow "Error: Can't get UID string from value"
	   | Some (thy_nm, uidstr, uid) \_rightarrow
	     let fil_nm = uidstr ^ ".hs" in
	     let _ = ensureDirectoriesExist fil_nm in
	     let _ = toFile(fil_nm, showValue(val, recursive?, Some uid, Some thy_nm)) in
	     fil_nm)
      | _ \_rightarrow "Error: Unknown UID " ^ uid_str

  op  deleteThyFilesForUID: String \_rightarrow ()
  def deleteThyFilesForUID uidstr =
    case evaluateUnitId uidstr of
      | Some val \_rightarrow
        deleteThyFilesForVal val
      | _ \_rightarrow ()

  op  deleteThyFilesForVal: Value \_rightarrow ()
  def deleteThyFilesForVal val =
    case uidNamesForValue val of
      | None \_rightarrow ()
      | Some (_, uidstr, uid) \_rightarrow
        if val = Spec(getBaseSpec())
          then ()
        else
        let fil_nm = uidstr ^ ".hs" in
	let _ = ensureFileDeleted fil_nm in
	case val of
	  | Spec spc \_rightarrow
	    app (\_lambda elem \_rightarrow case elem of
		              | Import(sc_tm, im_sp, _, _) \_rightarrow
		                deleteThyFilesForVal (Spec im_sp)
			      | _ \_rightarrow ())
	      spc.elements
          | Morph morph \_rightarrow deleteThyFilesForVal (Spec morph.dom)

  op  ensureFileDeleted: String \_rightarrow ()
  def ensureFileDeleted fil_nm =
    if fileExists? fil_nm
      then deleteFile fil_nm
      else ()

  op  ensureValuePrinted: Context \_rightarrow Value \_rightarrow String
  def ensureValuePrinted c val =
    case uidStringPairForValue val of
      | None \_rightarrow "Unknown"
      | Some ((thy_nm, fil_nm, hash_ext),uid) \_rightarrow
        printValueIfNeeded(c, val, thy_nm, fil_nm, hash_ext, uid)

  op printValueIfNeeded
       (c: Context, val: Value, thy_nm: String, fil_nm: String, hash_ext: String, uid: UnitId): String =
    let thy_fil_nm = fil_nm ^ hash_ext ^ ".hs" in
    let sw_fil_nm = fil_nm ^ ".sw" in
    let _ = if fileOlder?(sw_fil_nm, thy_fil_nm)
              then ()
            else toFile(thy_fil_nm,
                        showValue(val, c.recursive?, Some uid, Some (thy_nm ^ hash_ext)))
    in thy_nm

  op  uidNamesForValue: Value \_rightarrow Option (String * String * UnitId)
  def uidNamesForValue val =
    case uidStringPairForValue val of
      | None \_rightarrow None
      | Some((thynm, filnm, hash), uid) \_rightarrow Some(thynm ^ hash, filnm ^ hash, uid)

  op  uidStringPairForValue: Value \_rightarrow Option ((String \_times String \_times String) \_times UnitId)
  def uidStringPairForValue val =
    case MonadicStateInternal.readGlobalVar "GlobalContext" of
      | None \_rightarrow None
      | Some global_context \_rightarrow
    case findUnitIdForUnit(val, global_context) of
      | None \_rightarrow None
      | Some uid \_rightarrow Some (unitIdToHaskellString uid, uid)

  op unitIdToHaskellString(uid: UnitId): (String \_times String \_times String) =
    case uid.hashSuffix of
      | Some loc_nm \_rightarrow (last uid.path, uidToHaskellName uid, "_" ^ loc_nm)
      | _ \_rightarrow           (last uid.path, uidToHaskellName uid, "")

  op haskellLibrarySpecNames: List String = ["list", "integer", "nat", "set", "map", "fun",
                                         "option", "string",
                                         "lattices", "orderings", "sat", "relation", "record",
                                         "gcd", "datatype", "recdef", "hilbert_choice"]
  op thyName(spname: String): String =
    if (map toLowerCase spname) in? haskellLibrarySpecNames
      then "SW_"^spname
      else spname

  op uidStringPairForValueOrTerm
       (c: Context, val: Value, sc_tm: Term)
       : Option((String \_times String \_times String) \_times Value \_times UnitId) =
    case uidStringPairForValue val of
      | None \_rightarrow
        (case uidStringPairForTerm(c, sc_tm) of
           | None \_rightarrow None
           | Some((thynm, sw_file, thy_file), uid) \_rightarrow
         case evaluateTermWrtUnitId(sc_tm, getCurrentUID c) of
           | None \_rightarrow None
           | Some real_val \_rightarrow
             Some((thyName thynm, sw_file, thyName thy_file ^ ".hs"),
                  val, uid))
      | Some((thynm, filnm, hash), uid) \_rightarrow
        Some((thyName(thynm ^ hash),
              uidToFullPath uid ^ ".sw",
              thyName(filnm ^ hash) ^ ".hs"),
             val, uid)

  op uidStringPairForTerm(c: Context, sc_tm: Term): Option((String \_times String \_times String) \_times UnitId) =
    case sc_tm of
      | (Subst(spc_tm, morph_tm), pos) \_rightarrow
        (case uidStringPairForTerm(c, spc_tm) of
           | None \_rightarrow None
           | Some((thynm, sw_file, thy_file), uid) \_rightarrow
             let sb_id = "_sb_" ^ scTermShortName morph_tm in
             Some((thynm^sb_id, sw_file, thy_file^sb_id),
                  uid))

      | (UnitId relId, pos) \_rightarrow
        (case evaluateRelUIDWrtUnitId(relId, pos, getCurrentUID c) of
          | None \_rightarrow None
          | Some(val, uid) \_rightarrow
            let (thynm, filnm, hash) = unitIdToHaskellString uid in
            Some((thynm ^ hash,
                  uidToFullPath uid ^ ".sw",
                  filnm ^ hash),
                 uid))
      | _ \_rightarrow None

  op scTermShortName(sc_tm: Term): String =
    case sc_tm of
      | (UnitId relId, _) \_rightarrow relativeIdShortName relId
      | _ \_rightarrow "tm"

  op relativeIdShortName(relId: RelativeUID): String =
    case relId of
      | UnitId_Relative uid \_rightarrow unitIdShortName uid
      | SpecPath_Relative uid \_rightarrow unitIdShortName uid
    
  op unitIdShortName(uid: UnitId): String =
    case uid of
      | {path, hashSuffix = Some nm} \_rightarrow nm
      | {path, hashSuffix} \_rightarrow last path

  op  evaluateRelUIDWrtUnitId(rel_uid: RelativeUID, pos: Position, currentUID: UnitId): Option (Value * UnitId) = 
    let
      %% Ignore exceptions
      def handler _ (* except *) =
        return None
    in
    let prog = {cleanEnv;
		setCurrentUID currentUID;
		((val, _, _), uid)  <- evaluateReturnUID pos rel_uid;
		return (Some(val, uid))} 
    in
      runSpecCommand (catch prog handler)


  op  evaluateTermWrtUnitId(sc_tm: Term, currentUID: UnitId): Option Value = 
    let
      %% Ignore exceptions
      def handler _ (* except *) =
        return None
    in
    let prog = {cleanEnv;
		setCurrentUID currentUID;
		val  <- evaluateTerm sc_tm;
		return (Some val)} 
    in
      runSpecCommand (catch prog handler)

  op  SpecCalc.findUnitIdForUnitInCache: Value \_rightarrow Option UnitId
  def findUnitIdForUnitInCache val =
    case readGlobalVar "GlobalContext" of
      | None \_rightarrow None
      | Some global_context \_rightarrow
        findUnitIdForUnit(val, global_context)
  
  op  printUID : String \_times Boolean \_rightarrow ()
  def printUID (uid, recursive?) =
    case evaluateUnitId uid of
      | Some val \_rightarrow toTerminal(showValue (val, recursive?, findUnitIdForUnitInCache val, None))
      | _ \_rightarrow toScreen "<Unknown UID>"

  op  showValue : Value \_times Boolean \_times Option UnitId \_times Option String \_rightarrow Text
  def showValue (value, recursive?, uid, opt_nm) =
    let (thy_nm, val_uid) = case uidStringPairForValue value of
                             | Some ((thy_nm, _, hash_nm), uid) \_rightarrow (thy_nm ^ hash_nm, Some uid)
                             | _ \_rightarrow ("", None)
    in
    let main_pp_val = ppValue {recursive? = recursive?,
			       thy_name = case opt_nm of
                                            | Some nm \_rightarrow nm
                                            | None \_rightarrow thy_nm,
			       spec? = None,
                               currentUID = case uid of
                                              | None \_rightarrow val_uid
                                              | _ \_rightarrow uid,
			       trans_table = emptyTranslationTable,
                               coercions = [],
                               overloadedConstructors = [],
                               newVarCount = Ref 0,
                               source_of_thy_morphism? = false,
                               typeNameInfo = []}
			value
    in
    format(80, main_pp_val)


  op SpecCalc.morphismObligations: Morphism * SpecCalc.GlobalContext * Position \_rightarrow Spec
  %% --------------------------------------------------------------------------------

  op  ppValue : Context \_rightarrow Value \_rightarrow Pretty
  def ppValue c value =
    case value of
      | Spec spc \_rightarrow ppSpec c spc
      | Morph morph \_rightarrow
        let Some glob_ctxt = MonadicStateInternal.readGlobalVar "GlobalContext" in
        let oblig_spec = morphismObligations(morph, glob_ctxt, noPos) in
        ppSpec c oblig_spec
      | _ \_rightarrow prString "<Not a spec>"
 
  %% --------------------------------------------------------------------------------
  %% Specs
  %% --------------------------------------------------------------------------------

  op makeSubstFromRecPats(pats: List(Id * Pattern), rec_tm: MS.Term, spc: Spec): List(Pattern * MS.Term) =
    mapPartial (fn (fld, pat) -> if embed? WildPat pat then None
                                  else Some(pat, mkProjectTerm(spc, fld, rec_tm)))
      pats

  op expandRecPatterns (spc: Spec) (pat: Pattern, condn: MS.Term, body: MS.Term): Pattern * MS.Term * MS.Term =
    case pat of
      | RecordPat(pats as (id1,_)::_,_) | id1 ~= "1" && varOrRecordPattern? pat ->
        let rec_v = ("record__v", patternSort pat) in
        let binds = makeSubstFromRecPats(pats, mkVar rec_v, spc) in
        let let_bod = foldr (fn (bnd, bod) -> maybeExpandRecordPattern spc (MS.mkLet([bnd], bod))) body binds in
        (mkVarPat rec_v, condn, let_bod)
      | RecordPat(pats, a) ->
        let (newpats, condn, new_body)
           = foldl (fn ((newpats, condn, body), (id, p)) ->
                    let (new_p, condn, new_body) = expandRecPatterns spc (p, condn, body) in
                    (newpats ++ [(id, new_p)], condn, new_body))
              ([], condn, body) pats
        in
        (RecordPat(newpats, a), condn, new_body)
      | AliasPat(p1, p2, a) ->
        let (new_p2, condn, new_body) = expandRecPatterns spc (p2, condn, body) in
        (AliasPat(p1, new_p2, a), condn, new_body)
      | EmbedPat(id, Some p2, ty, a) ->
        let (new_p2, condn, new_body) = expandRecPatterns spc (p2, condn, body) in
        (EmbedPat(id, Some new_p2, ty, a), condn, new_body)
      | _ -> (pat, condn, body)

  op maybeExpandRecordPattern(spc: Spec) (t: MS.Term): MS.Term =
    case t of
      | Let([(pat as RecordPat(pats as (id1,_)::_,_), rec_tm)], body, _)
          | id1 ~= "1" && varOrRecordPattern? pat ->
        let binds = makeSubstFromRecPats(pats, rec_tm, spc) in
        foldr (fn (bnd, bod) -> maybeExpandRecordPattern spc (MS.mkLet([bnd], bod))) body binds
      | Lambda (pats, a) ->
        Lambda(map (expandRecPatterns spc) pats, a)
      | _ -> t

  op expandRecordPatterns(spc: Spec): Spec =
    mapSpec (maybeExpandRecordPattern spc, id, id)
      spc

  op  ppSpec: Context \_rightarrow Spec \_rightarrow Pretty
  def ppSpec c spc =
    % let _ = writeLine("0:\n"^printSpec spc) in
    let spc = spc << {elements = normalizeSpecElements(spc.elements)} in
    let spc = adjustElementOrder spc in
    let source_of_thy_morphism? = exists? (fn el ->
                                            case el of
                                              | Pragma("proof", prag_str, "end-proof", _)
                                                  \_rightarrow true
                                              | _ \_rightarrow false)
                                     spc.elements
    in
    let trans_table = thyMorphismMaps spc in
    let c = c << {spec? = Some spc,
                  trans_table = trans_table,
                  source_of_thy_morphism? = source_of_thy_morphism?}
    in
    let spc = normalizeTopLevelLambdas spc in
    let spc = if simplify? && some?(AnnSpec.findTheSort(spc, Qualified("Nat", "Nat")))
                then simplifyTopSpec spc
                else spc
    in
    let spc = normalizeNewTypes spc in
    let coercions = makeCoercionTable(trans_table, spc) in   % before removeSubTypes!
    let c = c << {coercions = coercions,
                  overloadedConstructors = overloadedConstructors spc}
    in
    % let _ = printSpecWithSortsToTerminal spc in
% let _ = writeLine("1:\n"^printSpec spc) in
% ?    let spc = removeSubTypes spc coercions stp_tbl in
    %% Second round of simplification could be avoided with smarter construction
% ?    let spc = expandRecordPatterns spc in
% ?    let spc = normalizeNewTypes spc in
    let spc = addCoercions coercions spc in
    let spc = if simplify? && some?(AnnSpec.findTheSort(spc, Qualified("Nat", "Nat")))
                then simplifyTopSpec(simplifyTopSpec spc) % double simplify temporary?
                else spc
    in
    let c = c << {typeNameInfo = topLevelTypes spc, spec? = Some spc} in
    % let _ = writeLine("n:\n"^printSpec spc) in
    prLinesCat 0 [[prString "import ", ppImports c spc.elements],
		  [ppSpecElements c spc (filter elementFilter spc.elements)]]

  op  elementFilter: SpecElement \_rightarrow Boolean
  def elementFilter elt =
    case elt of
      | Import _ \_rightarrow false
      | Pragma("proof", prag_str, "end-proof", _) | haskellPragma? prag_str
                                                && haskellThyMorphismPragma prag_str = None \_rightarrow
        true
      | Pragma _ \_rightarrow false
      | _ \_rightarrow true

  %% Originally was just supertype but generalized to also be a named type
  %% For internal use. Choose unparseable name
  def toHaskellQual = "ToHaskell-Internal"

  op getSuperTypeOp(ty: Sort): QualifiedId =
    case ty of
      | Base(superty,_,_) \_rightarrow superty
      | Subsort(sup,_,_) \_rightarrow getSuperTypeOp sup
      | _ \_rightarrow fail("Not a Subtype and not a named type")

  op  makeCoercionTable: TransInfo * Spec \_rightarrow TypeCoercionTable
  def makeCoercionTable(trans_info, spc) =
    Map.foldi (\_lambda (subty, (super_id, opt_coerc, overloadedOps), val) \_rightarrow
               case opt_coerc of
                 | None \_rightarrow val
                 | Some(toSuper, toSub) \_rightarrow
	       let srtDef = sortDef(subty, spc) in
               let superty = getSuperTypeOp srtDef in
               Cons({subtype = subty,
                     supertype = superty,
                     coerceToSuper = mkOp(Qualified(toHaskellQual, toSuper),
                                          mkArrow(mkBase(subty, []),
                                                  mkBase(superty, []))),
                     coerceToSub   = mkOp(Qualified(toHaskellQual, toSub),
                                          mkArrow(mkBase(superty, []),
                                                  mkBase(subty, []))),
                     overloadedOps = overloadedOps},
                    val))
      [] trans_info.type_map

  def baseSpecName = "Empty"

  op  ppImports: Context \_rightarrow SpecElements \_rightarrow Pretty
  def ppImports c elems =
    let imports_from_thy_morphism = thyMorphismImports c in
    let explicit_imports =
        mapPartial (\_lambda el \_rightarrow
		     case el of
		       | Import(imp_sc_tm, im_sp, _, _) \_rightarrow Some (ppImport c imp_sc_tm im_sp)
		       | _ \_rightarrow None)
           elems
    in case explicit_imports ++ imports_from_thy_morphism of
      | [] \_rightarrow prString baseSpecName
      | imports \_rightarrow prPostSep 0 blockFill prSpace imports

  op thyMorphismImports (c:Context): List Pretty =
    map prString c.trans_table.thy_imports

  op firstTypeDef (elems:SpecElements): Option QualifiedId =
    case elems of
      | [] \_rightarrow None
      | (Sort (type_id, _)) :: _ \_rightarrow Some type_id
      | (SortDef (type_id, _)) :: _ \_rightarrow Some type_id
      | _ :: r \_rightarrow firstTypeDef r

  op  ppImport: Context \_rightarrow Term \_rightarrow Spec \_rightarrow Pretty
  def ppImport c sc_tm spc =
    case uidStringPairForValueOrTerm(c, Spec spc, sc_tm) of
      | None \_rightarrow prString "<UnknownSpec>"
      | Some ((thy_nm, sw_fil_nm, thy_fil_nm), val, uid) \_rightarrow
        let _ = if c.recursive?
	          then
		    if fileOlder?(sw_fil_nm, thy_fil_nm) || spc = getBaseSpec()
		      then ()
		    else toFile(thy_fil_nm,
                                showValue(val, c.recursive?, Some uid, Some thy_nm))
		  else ()
	in prString (case thy_nm of
		       | "Base" \_rightarrow "Base"
		       | _ \_rightarrow thy_nm)

  op  ppSpecElements: Context \_rightarrow Spec \_rightarrow SpecElements \_rightarrow Pretty
  def ppSpecElements c spc elems =
    let
      %op  ppSpecElementsAux: Context \_rightarrow Spec \_rightarrow SpecElements \_rightarrow List Pretty
      def aux c spc r_elems =
	case r_elems of
	  | [] \_rightarrow []
	  | el :: (rst as (Pragma prag) :: _) | unnamedPragma? prag \_rightarrow
	    let pretty1 = ppSpecElement c spc el (Some prag) elems in
	    let prettyr = aux c spc rst in
	    if pretty1 = prEmpty
	      then prettyr
	      else pretty1::prettyr
	  | el :: rst \_rightarrow
	    let pretty1 = ppSpecElement c spc el None elems in
	    let prettyr = aux c spc rst in
	    if pretty1 = prEmpty
	      then prettyr
	      else pretty1::prettyr
    in
    prLines 0 (aux c spc elems)

  op  normalizeSpecElements: SpecElements \_rightarrow SpecElements
  def normalizeSpecElements elts =
    case elts of
      | [] \_rightarrow []
      | (Op (qid1, false, a)) :: (OpDef (qid2, 0, _)) :: rst | qid1 = qid2 \_rightarrow
        Cons(Op(qid1, true, a), normalizeSpecElements rst)
      | x::rst \_rightarrow x :: normalizeSpecElements rst

  op  ppSpecElement: Context \_rightarrow Spec \_rightarrow SpecElement \_rightarrow Option Pragma
                    \_rightarrow SpecElements \_rightarrow Pretty
  def ppSpecElement c spc elem opt_prag elems =
    case elem of
      | Import (_, im_sp, im_elements, _) \_rightarrow prEmpty
      | Op (qid as Qualified(_, nm), def?, _) \_rightarrow
	(case AnnSpec.findTheOp(spc, qid) of
	   | Some {names, fixity, dfn, fullyQualified?=_} \_rightarrow
	     ppOpInfo c true def? elems opt_prag
               names fixity 0 dfn  % TODO: change  op_with_def?  to  def? -- no one looks at it??
	   | _ \_rightarrow 
	     let _  = toScreen("\nInternal error: Missing op: "
				 ^ printQualifiedId qid ^ "\n") in
	     prString "<Undefined Op>")
      | OpDef(qid as Qualified(_,nm), refine_num, _) \_rightarrow
	(case AnnSpec.findTheOp(spc, qid) of
	   | Some {names, fixity, dfn, fullyQualified?=_} \_rightarrow
             let names = map (refinedQID refine_num) names in
	     ppOpInfo c (refine_num > 0) true elems opt_prag names fixity refine_num dfn
	   | _ \_rightarrow 
	     let _  = toScreen("\nInternal error: Missing op: "
				 ^ printQualifiedId qid ^ "\n") in
	     prString "<Undefined Op>")
      | Sort (qid,_) \_rightarrow
	(case AnnSpec.findTheSort(spc, qid) of
	   | Some {names, dfn} \_rightarrow ppTypeInfo c false (names, dfn)
	   | _ \_rightarrow 
	     let _  = toScreen("\nInternal error: Missing type: "
				 ^ printQualifiedId qid ^ "\n") in
	     prString "<Undefined Type>")
      | SortDef (qid,_) \_rightarrow
	(case AnnSpec.findTheSort(spc, qid) of
	   | Some {names, dfn} \_rightarrow ppTypeInfo c true (names, dfn)
	   | _ \_rightarrow 
	     let _  = toScreen("\nInternal error: Missing type: "
				 ^ printQualifiedId qid ^ "\n") in
	     prString "<Undefined Type>")
      | Pragma("proof", mid_str, "end-proof", pos) | verbatimPragma? mid_str \_rightarrow
        let verbatim_str = case search("\n", mid_str) of
                             | None \_rightarrow ""
                             | Some n \_rightarrow specwareToHaskellString(subFromTo(mid_str, n, length mid_str))
        in
        prLines 0 [prString verbatim_str]
	   
      | Comment (str,_) \_rightarrow
	prConcat [prString "{-",
		  prString str,
		  prString "-}"]
      | _ \_rightarrow prEmpty

 op xSymbolWords: List String = ["and", "or", "And", "Or", "lbrakk", "rbrakk", "inter", "union",
                                 "in", "notin", "lambda", "bar", "Colon",
                                 "Rightarrow", "Longrightarrow", "noteq",
                                 "forall", "exists", "equiv", "ge", "le", "times", "plus", "minus",
                                 "Inter", "Sqinter", "Union", "Squnion", "Prod", "not", "Sum"]
 op findXSymbolWord(s: String, start: Nat): Option Nat =
   let def find1 words =
         case words of
           | [] \_rightarrow None
           | w::r \_rightarrow
             let end_pos = start + length w - 1 in
             if testSubseqEqual?(w, s, 0, start)
               then Some (end_pos)
               else find1 r
   in
   find1 xSymbolWords
            

 op specwareToHaskellString(s: String): String =
   case search("\\_", s) of
     | None \_rightarrow s
     | Some i \_rightarrow
   let len = length s in
   let def loop j =
         if j >= len then j-1
         else if isAlphaNum(s@j)
                 then loop(j+1)
                 else j-1
   in
   let j = case findXSymbolWord(s, i+2) of
             | Some j \_rightarrow j
             | None \_rightarrow loop(i+2)
   in
   subFromTo(s, 0, i+1) ^ "<" ^ subFromTo(s, i+2, j+1) ^ ">" ^ specwareToHaskellString(subFromTo(s, j+1, len))

  op  haskellPragma?(s: String): Boolean =
    let s = stripSpaces s in
    let len = length s in
    len > 2 \_and (let pr_type = subFromTo(s, 0, 3) in
	       pr_type = "Haskell" \_or pr_type = "haskell" \_or pr_type = "All")
    \_or (len > 13 \_and subFromTo(s, 0, 14) = "Simplification")

  op controlPragmaString(s: String): Option(List String) =
    let line1 = case search("\n", s) of
                  | None \_rightarrow s
                  | Some n \_rightarrow subFromTo(s, 0, n)
    in
    case removeEmpty(splitStringAt(line1, " ")) of
     | "Isa"::str::rst | length str > 1 && str@0 = #- && str@1 ~= #> ->
       Some(str::rst)
     | _ \_rightarrow None

 op controlPragma?(s: String): Boolean =
   embed? Some (controlPragmaString s)

 op  stripSpaces(s: String): String =
   let len = length s in
   case findLeftmost (\_lambda i \_rightarrow s@i \_noteq #  ) (tabulate(len,\_lambda i \_rightarrow i)) of
     | Some firstNonSpace \_rightarrow 
       (case findLeftmost (\_lambda i \_rightarrow s@i \_noteq #  ) (tabulate(len,\_lambda i \_rightarrow len-i-1)) of
         | Some lastNonSpace \_rightarrow
           subFromTo(s,firstNonSpace,lastNonSpace+1)
         | _ \_rightarrow s)
     | _ \_rightarrow s

  op namedPragma?(p: Pragma): Boolean =
    let (_,s,_,_) = p in
    let line1 = case search("\n", s) of
                  | None \_rightarrow s
                  | Some n \_rightarrow subFromTo(s, 0, n)
    in
    case removeEmpty(splitStringAt(line1, " ")) of
     | pragma_kind::name?::r | pragma_kind = "Haskell" \_or pragma_kind = "haskell" \_rightarrow
       ~(name? = "fa"
           \_or name?@0 in? [#(,#[,#\\,#",#-])  % #" #]
     | _ \_rightarrow false

  op unnamedPragma?(p: Pragma): Boolean =
    ~(namedPragma? p || controlPragma? p.2)

  op verbatimIdString: String = "-verbatim"

  op verbatimPragma?(s: String): Boolean =
    case controlPragmaString s of
      | Some(str::_) \_rightarrow str = verbatimIdString
      | _ \_rightarrow false

 op  haskellThyMorphismPragma: String \_rightarrow Option(String * List String)
 def haskellThyMorphismPragma prag =
   case search("\n",prag) of
     | None \_rightarrow None
     | Some n \_rightarrow
   let line1 = subFromTo(prag,0,n) in
   case removeEmpty(splitStringAt(line1," ")) of
     | "Haskell"::thyMorphStr::r | thyMorphStr in?
				      ["ThyMorphism","Thy_Morphism",
				       "TheoryMorphism","Theory_Morphism"] \_rightarrow
       Some(subFromTo(prag,n,length prag), r)
     | _ \_rightarrow None


 op findPragmaNamed(elts: SpecElements, qid as (Qualified(q, nm)): QualifiedId, opt_prag: Option Pragma)
     : Option Pragma =
   % let _ = writeLine("findPragmaNamed: "^printQualifiedId qid^" opt_prag: "^anyToString opt_prag) in
   case findPragmaNamed1(elts, q^"__"^nm) of
     | Some p \_rightarrow Some p
     | None \_rightarrow
   case findPragmaNamed1(elts, qidToHaskellString qid) of   % Allow Haskell name
     | Some p \_rightarrow Some p
     | None \_rightarrow
   %% Try without qualifier
   case findPragmaNamed1(elts, nm) of
     | Some p \_rightarrow Some p
     | None \_rightarrow                          % Allow Haskell name
   case findPragmaNamed1(elts, ppIdStr nm) of
     | Some p \_rightarrow Some p
     | None \_rightarrow opt_prag                  

 op  findPragmaNamed1: SpecElements * String \_rightarrow Option Pragma
 def findPragmaNamed1(elts, nm) =
   % let _ = writeLine("findPragmaNamed1: "^nm) in
   let result =
         case elts of
          | [] \_rightarrow None
          | el::rst \_rightarrow
            (case el of
               | Pragma(p_bod as ("proof", prag_str, "end-proof", _)) \_rightarrow
                 (let line1 = case search("\n", prag_str) of
                                | None \_rightarrow prag_str
                                | Some n \_rightarrow subFromTo(prag_str, 0, n)
                  in
                  case removeEmpty(splitStringAt(line1, " ")) of
                    | pragma_kind::thm_nm::r
                      | (pragma_kind = "Haskell" \_or pragma_kind = "haskell") && thm_nm = nm \_rightarrow
                      Some p_bod
                    | _ \_rightarrow findPragmaNamed1(rst, nm))
               | _ \_rightarrow findPragmaNamed1(rst, nm))
   in
   % let _ = writeLine("returned: "^anyToString result) in
   result

 op haskellReservedWords: List String = ["class", "data", "deriving", "do", "import", "instance", "module",
                                         "newtype", "type", "where"]
 op disallowedVarNames: List String = []        % \_dots Don't know how to get all of them

 op directConstructorTypes: List QualifiedId =
   [Qualified("Option", "Option"),
    Qualified("List", "List"),
    Qualified("Compare", "Comparison")]

 op ppConstructor(c_nm: String, qid: QualifiedId): Pretty =
   prString(if qid in? directConstructorTypes then ppIdStr c_nm
              else qidToHaskellString qid^"__"^ppIdStr c_nm)

 op ppConstructorTyped(c_nm: String, ty: Sort, spc: Spec): Pretty =
   case unfoldToBaseNamedType(spc, ty) of
     | Base(qid, _, _) -> ppConstructor(c_nm, qid)
     | _ -> fail("Couldn't find coproduct type of constructor "^c_nm)

 op  ppIdInfo : List QualifiedId \_rightarrow Pretty
 def ppIdInfo qids =
   let qid = head qids in
   ppQualifiedId qid

 op mkFieldName(nm: String): String = ppIdStr nm ^ "__fld"
 op mkNamedRecordFieldName(qid: QualifiedId, nm: String): String =
   qidToHaskellString qid^"__"^ppIdStr nm

 op ppToplevelName(nm: String): Pretty =
   prString nm

 op  ppTypeInfo : Context \_rightarrow Boolean \_rightarrow List QualifiedId \_times Sort \_rightarrow Pretty
 def ppTypeInfo c full? (aliases, dfn) =
   let mainId = head aliases in
   case specialTypeInfo c mainId of
     | Some _ \_rightarrow prEmpty
     | None \_rightarrow
   let (tvs, ty) = unpackSort dfn in
   if full? \_and (case ty of Any _ \_rightarrow false | _ \_rightarrow true)
     then case ty of
	   | CoProduct(taggedSorts,_) \_rightarrow
             (let def ppTaggedSort (id,optTy) =
                case optTy of
                  | None \_rightarrow ppConstructor(id, mainId)
                  | Some ty \_rightarrow
                    prConcat [ppConstructor(id, mainId), prSpace,
                              case ty of
                                | Product(fields as ("1",_)::_,_) \_rightarrow	% Treat as curried
                                  prConcat(addSeparator prSpace
                                             (map (\_lambda (_,c_ty) \_rightarrow ppType c CoProduct c_ty) fields))
                                | _ \_rightarrow ppType c CoProduct ty]
              in
              prBreakCat 2
                [[prString "data ",
                  ppTyVars tvs,
                  ppIdInfo aliases],
                 [prString " = ", prSep (-2) blockAll (prString "| ") (map ppTaggedSort taggedSorts)]])
	   | Product (fields,_) | length fields > 0 && (head fields).1 ~= "1" \_rightarrow
	     prLinesCat 2
	       ([[prString "record ",
		  ppTyVars tvs,
		  ppIdInfo aliases,
		  prString " = "]] ++
		(map (\_lambda (fldname, fldty) \_rightarrow
		      [ppToplevelName (mkNamedRecordFieldName(mainId, fldname)),
                       prString " :: ", ppType c Top fldty])
		 fields))
	   | _ \_rightarrow
	     prBreakCat 2
	       [[prString "types ",
		 ppTyVars tvs,
		 ppIdInfo aliases,
		 prString " = "],
		[ppType c Top ty]]
     else prBreakCat 2
	    [[prString "typedecl ",
	      ppTyVars tvs,
	      ppIdInfo aliases]]

 op  ppTyVars : TyVars \_rightarrow Pretty
 def ppTyVars tvs =
   case tvs of
     | [] \_rightarrow prEmpty
     | [tv] \_rightarrow prConcat [prString "'", prString tv, prSpace]
     | _ \_rightarrow prConcat [prString " (",
		      prPostSep 0 blockFill (prString ",")
		        (map (\_lambda tv \_rightarrow prConcat[prString "'", prString tv]) tvs),
		      prString ")"]

 op precNumFudge: Nat = 0

 op mkIncTerm(t: MS.Term): MS.Term =
   mkApply(mkOp(Qualified("Integer","+"),
                mkArrow(mkProduct [natSort, natSort], natSort)),
           mkTuple[t,mkNat 1])

 op  defToFunCases: Context \_rightarrow MS.Term \_rightarrow MS.Term \_rightarrow List(MS.Term \_times MS.Term)
 def defToFunCases c op_tm bod =
   let
     def aux(hd, bod) =
       % let _ = writeLine("dtfc: "^printTerm hd^" = "^printTerm bod) in
       case bod of
         | Lambda ([(VarPat (v as (nm,ty),_), _, term)], a) \_rightarrow
           aux(Apply(hd, mkVar v, a), term)
         | Lambda ([(pattern, _, term)], a) \_rightarrow
           (case patToTerm (pattern, "",  c) of
              | Some pat_tm \_rightarrow
                aux (Apply(hd, pat_tm, a), term)
              | _ \_rightarrow [(hd, bod)])
         | Apply (Lambda (pats,_), Var(v,_), _) \_rightarrow
           if exists? (\_lambda v1 \_rightarrow v = v1) (freeVars hd)
            then foldl (\_lambda (cases, (pati, _, bodi)) \_rightarrow
                        case patToTerm(pati, "",  c) of
                          | Some pati_tm \_rightarrow
                            let sbst = [(v, pati_tm)] in
                            let s_bodi = if hasVarNameConflict?(pati_tm, [v]) then bodi
                                          else substitute(bodi, sbst)
                            in
                            let new_cases = aux_case(substitute(hd, sbst), s_bodi) in
                            (cases ++ new_cases)
                          | _ \_rightarrow
                            let new_cases = aux_case(hd, bodi) in
                            (cases ++ new_cases))
                   [] pats
            else [(hd, bod)]
         | Apply (Lambda (pats,_), arg as Record(var_tms,_), _)
             | tupleFields? var_tms    % ??
               &&  forall? (fn (_,t) \_rightarrow embed? Var t) var_tms
%                && (case hd of
%                      | Apply(_,param,_) \_rightarrow equalTerm?(param,arg)
%                      | _ \_rightarrow false)
           \_rightarrow
           let def matchPat (p: Pattern, cnd, bod: MS.Term): Option(MS.Term * MS.Term) =
                 case p of
                   | RecordPat(rpats,_) \_rightarrow
                     let sbst = mapPartial (fn ((_, v_tm as Var(v, _)), (_, p1)) \_rightarrow
                                              case p1 of
                                                | WildPat _ \_rightarrow Some(v, v_tm)  % id
                                                | _ \_rightarrow
                                              case patToTerm (p1, "", c) of
                                                | Some p_tm \_rightarrow Some(v, p_tm)
                                                | None \_rightarrow None)
                                 (zip (var_tms, rpats))
                     in
                     if length sbst ~= length rpats then None
                     else
                     let bod_sbst = filter (fn (v,tm) -> ~(hasVarNameConflict?(tm, [v]))) sbst in
                     Some(substitute(hd, sbst), substitute(bod, bod_sbst))
                   | VarPat(v, _) \_rightarrow Some(hd, substitute(bod, [(v, arg)]))
                   | WildPat _ \_rightarrow Some(hd, bod)
                   | AliasPat(VarPat(v, _), p2, _) \_rightarrow matchPat(p2, cnd, substitute(bod, [(v, arg)]))
                   | RestrictedPat(rp,_,_) \_rightarrow matchPat(rp, cnd, bod)
                   | _ \_rightarrow None
           in
           let cases = mapPartial matchPat pats in
           if length cases = length pats
             then foldl (fn (cases, (lhs,rhs)) -> cases ++ aux(lhs,rhs)) [] cases
             else [(hd, bod)]
         | Let([(pat, Var(v,_))], bod, a) | v in? freeVars hd \_rightarrow
           (case patToTerm(pat, "",  c) of
              | Some pat_tm \_rightarrow
                let s_bod = if hasVarNameConflict?(pat_tm, [v]) then bod
                            else substitute(bod,[(v,pat_tm)])
                in
                aux(substitute(hd, [(v,pat_tm)]), s_bod)
              | None \_rightarrow [(hd, bod)])
         | IfThenElse(Apply(Fun(Equals, _,_),
                            Record([("1", vr as Var(v as (vn,s),_)),
                                    ("2",zro as Fun(Nat 0,_,_))],_),
                            _),
                      then_cl, else_cl, _)
             | natSort? s \_and inVars?(v, freeVars hd) \_rightarrow
           let cases1 = aux(substitute(hd, [(v,zro)]), substitute(then_cl, [(v,zro)])) in
           let cases2 = aux(substitute(hd, [(v, mkIncTerm vr)]),
                            simpSubstitute(getSpec c, else_cl, [(v, mkIncTerm vr)]))
           in
           cases1 ++ cases2
         | _ \_rightarrow [(hd,bod)]
     def aux_case(hd,bod: MS.Term) =
       aux(hd,bod) 
     def fix_vars(hd,bod) =
       case hd of
         | Fun(_, ty, _) ->
           (case arrowOpt(getSpec c, ty) of
              | Some(dom,_) ->
                let new_v = mkVar("x__a", dom) in
                (mkApply(hd, new_v), mkApply(bod, new_v))
              %% Shouldn't happen?
              | None -> (hd,bod))
         | _ ->
       let fvs = freeVars hd ++ freeVars bod in
       let rename_fvs = filter (\_lambda (nm,_) \_rightarrow nm in? disallowedVarNames) fvs in
       if rename_fvs = [] then (hd,bod)
         else let sb = map (\_lambda (v as (nm,ty)) \_rightarrow (v,mkVar(nm^"_v",ty))) rename_fvs in
              let bod_sb = filter (fn (v,tm) -> ~(hasVarNameConflict?(tm, [v]))) sb in
              (substitute(hd,sb), substitute(bod,bod_sb))
   in
   case bod of
     | Lambda ([(RestrictedPat(rpat,_,_),condn,tm)], a) \_rightarrow
       defToFunCases c op_tm (Lambda ([(rpat, condn, tm)], a))
     | _ \_rightarrow
   let cases =
         case bod of
           | Lambda ([(recd as (RecordPat (prs as (("1",_)::_),_)), _, tm)],a)
               | varOrTuplePattern? recd \_rightarrow
             let Some arg = patToTerm(recd,"", c) in
             let cases = aux(Apply(op_tm, arg, a), tm) in
             cases
           | _ \_rightarrow aux(op_tm, bod)
   in
   % let _ = app (fn (x,y) -> writeLine(printTerm x^" -> "^printTerm y)) cases in
   %let _ = writeLine(" = "^show (length cases)^", "^show tuple?) in
   (map fix_vars cases)

 op processOptPrag(opt_prag: Option Pragma): List (List Pretty) * Boolean =
   case opt_prag of
     | Some(beg_str,mid_str,end_str,pos) \_rightarrow
       let len = length mid_str in
       (case search("\n",mid_str) of
          | None \_rightarrow ([], false)
          | Some n \_rightarrow
            let prf_str = stripExcessWhiteSpace(subFromTo(mid_str,n+1,len)) in
            ([[prString(specwareToHaskellString prf_str)]],
             proofEndsWithTerminator? prf_str))
     | _ \_rightarrow ([], false)

op defaultFunctionProof: String =
   "by pat_completeness auto\ntermination by lexicographic_order"

op ppFunctionDef (c: Context) (aliases: Aliases) (dfn: MS.Term) (ty: Sort) (opt_prag: Option Pragma) (fixity: Fixity)
    : Pretty =
  let mainId = head aliases in
  let op_tm = mkFun (Op (mainId, fixity), ty) in
  let cases = defToFunCases c op_tm dfn in
  let pp_cases = map (fn (lhs, rhs) ->
                        prBreakCat 2 [[ppTerm c Top lhs, string " = "], [ppTerm c Top rhs]])
                   cases
  in
  prLines (0) pp_cases
 
op  ppOpInfo :  Context \_rightarrow Boolean \_rightarrow Boolean \_rightarrow SpecElements \_rightarrow Option Pragma
                  \_rightarrow Aliases \_rightarrow Fixity \_rightarrow Nat \_rightarrow MS.Term
                  \_rightarrow Pretty
def ppOpInfo c decl? def? elems opt_prag aliases fixity refine_num dfn =
  %% Doesn't handle multi aliases correctly
  let c = c << {newVarCount = Ref 0} in
  let mainId = head aliases in
  % let _ = writeLine("Processing "^printQualifiedId mainId) in
  let opt_prag = findPragmaNamed(elems, mainId, opt_prag) in
  let (no_def?, mainId, fixity) =
      case specialOpInfo c mainId of
        | Some (haskell_id, infix?, _, _, no_def?) \_rightarrow
          (no_def?, mkUnQualifiedId(haskell_id),
           case infix? of
             | Some pr -> Infix pr
             | None -> fixity)
        | _ \_rightarrow (false, mainId, fixity)
  in
  if no_def?
    then prEmpty
  else
  let (tvs, ty, term) = if def? then unpackNthTerm(dfn, refine_num)
                         else unpackTerm(dfn)
  in
  let aliases = [mainId] in
  let decl_list = 
        if decl?
          then [[ppIdInfo aliases,
                 prString " :: ",
                 (case fixity of
                    | Infix(assoc, prec) \_rightarrow ppInfixType c ty   % Infix operators are curried in Haskell
                    | _ \_rightarrow ppType c Top ty)]
             ++ (case fixity of
                   | Infix(assoc,prec) \_rightarrow
                     [case assoc of
                        | Left  \_rightarrow prString "infixl "
                        | Right \_rightarrow prString "infixr ",
                      ppInfixDefId (mainId),
                      prString " ",
                      prString (show (prec + precNumFudge))]
                   | _ \_rightarrow [])]
           else []
  in
  let infix? = case fixity of Infix _ \_rightarrow true | _ \_rightarrow false in
  let def_list = if def? then [[ppFunctionDef c aliases term ty opt_prag fixity]] else []
  in prLinesCat 0 ([[]] ++ decl_list ++ def_list)

 op ensureNotCurried(lhs: MS.Term, rhs: MS.Term): MS.Term * MS.Term =
   case lhs of
     | Apply(h as Apply _, Var(v, _), _) ->
       ensureNotCurried(h, mkLambda(mkVarPat v, rhs))
     | _ -> (lhs, rhs)

 %op  Utilities.patternToTerm : Pattern \_rightarrow Option MS.Term
 %op  Utilities.substitute    : MS.Term * List (Var * MS.Term) \_rightarrow MS.Term
 %op  Utilities.freeVars      : MS.Term \_rightarrow List Var

op patToTerm(pat: Pattern, ext: String, c: Context): Option MS.Term = 
    case pat
      of EmbedPat(con,None,ty,a) \_rightarrow 
         Some(Fun(Embed(con,false),ty,a))
       | EmbedPat(con,Some p,ty,a) \_rightarrow 
         (case p of
            | WildPat(pty,a) | multiArgConstructor?(con,ty,getSpec c) \_rightarrow
              let tys = productSorts(getSpec c, pty) in
              let args = (foldr (fn (ty,(result,i)) ->
                                   let cnt = c.newVarCount in
                                   let _ = (cnt := !cnt + 1) in
                                   let v = (if true then "zzz" else "zzz_"^ext)^show (!cnt) in
                                   (Cons(Var((v,ty), a),result),i-1))
                            ([], length tys) tys).1
              in
              Some (Apply(Fun(Embed(con,true),Arrow(pty,ty,a),a),mkTuple args,a))
            | _ ->
          case patToTerm(p, ext, c)
            of None \_rightarrow None
             | Some (trm) \_rightarrow 
               let ty1 = patternSort p in
               Some (Apply(Fun(Embed(con,true),Arrow(ty1,ty,a),a),trm,a)))
       | RecordPat(fields,a) \_rightarrow 
         let
            def loop(new,old,i) = 
                case new
                  of [] \_rightarrow Some(Record(reverse old,a))
                   | (l,p)::new \_rightarrow 
                case patToTerm(p, ext^(show i), c)
                  of None \_rightarrow None
                   | Some(trm) \_rightarrow 
                     loop(new, Cons((l,trm),old), i+1)
         in
         loop(fields,[], 0)
       | NatPat(i, _) \_rightarrow Some(mkNat i)
       | BoolPat(b, _) \_rightarrow Some(mkBool b)
       | StringPat(s, _) \_rightarrow Some(mkString s)
       | CharPat(c, _) \_rightarrow Some(mkChar c)
       | VarPat((v,ty), a) \_rightarrow Some(Var((v,ty), a))
       | WildPat(ty,a) \_rightarrow
         let cnt = c.newVarCount in
         let _ = (cnt := !cnt + 1) in
         let v = "zzz_"^show (!cnt) in
         Some(Var((v,ty), a))
       | QuotientPat(pat,cond,_)  \_rightarrow None %% Not implemented
       | RestrictedPat(pat,cond,_)  \_rightarrow
         patToTerm(pat,ext, c)		% cond ??
       | AliasPat(p1,p2,_) \_rightarrow 
         (case patToTerm(p2, ext, c) 
            of None \_rightarrow patToTerm(p1, ext, c)
             | Some(trm) \_rightarrow Some trm)

 op constructorTerm?(tm: MS.Term): Boolean =
   case tm of
     | Fun(Embed _, _, _) \_rightarrow true
     | _ \_rightarrow false

 op primitiveArg?(tm: MS.Term): Boolean =
   case tm of
     | Apply(Fun(Embed _, _, _), arg, _) \_rightarrow
       forall? (embed? Var) (MS.termToList arg)
     | Fun(Embed _, _, _) \_rightarrow true
     | Var _ \_rightarrow true
     | _ \_rightarrow false

 op sameHead?(tm1: MS.Term, tm2: MS.Term): Boolean =
   equalTerm?(tm1, tm2)
     || (case (tm1, tm2) of
           | (Apply(x1,_,_), Apply(x2,_,_)) \_rightarrow sameHead?(x1,x2)
           | _ \_rightarrow false)

 op nonPrimitiveArg?(tm1: MS.Term, tm2: MS.Term): Boolean =
   case tm1 of
     | Apply(Fun(Embed _, _, _), arg, _) \_rightarrow
       ~(termIn?(tm2, MS.termToList arg))
     | _ \_rightarrow false

 op hasNonPrimitiveArg?(tm1: MS.Term, tm2: MS.Term): Boolean =
   case (tm1, tm2) of
     | (Apply(x1,y1,_), Apply(x2,y2,_)) \_rightarrow
       nonPrimitiveArg?(y1,y2) || hasNonPrimitiveArg?(x1,x2)
     | _ \_rightarrow false

 op nonPrimitiveCall? (hd: MS.Term) (tm: MS.Term): Boolean =
   sameHead?(hd,tm) && hasNonPrimitiveArg?(hd,tm)

 %% Only concerned with curried calls
 op recursiveCallsNotPrimitive?(hd: MS.Term, bod: MS.Term): Boolean =
   existsSubTerm (nonPrimitiveCall? hd) bod

 op patternLambda?(v_pos: Position, lam_pos: Position): Boolean =
   %% an explicit lambda will have beginning of variable close to beginning of lambda expr
   false   %usePosInfoForDefAnalysis?
     => (case (v_pos, lam_pos) of
           | (File(_,(_,_,v_byte),_), File(_,(_,_,lam_byte),_)) ->
             v_byte - lam_byte > 4
           | _ -> true)

 %% Ops that are not polymorphic in Specware but are mapped to polymorphic ops in Haskell
 op haskellOverloadedOps: List String = ["**", "modF", "divF"]

 op filterConstrainedVars(c: Context, t: MS.Term, vs: Vars): Vars =
   let def removeArgs(vs: Vars, args: Terms, bound_vars: Vars): Vars =
         % let _ = writeLine("removeArgs: "^anyToString (map (fn (x,_) \_rightarrow x) bound_vars)) in
         % let _ = app (fn t -> writeLine (printTerm t)) args in
         let v_args = mapPartial (\_lambda t \_rightarrow
                                    case t of
                                      | Var (v,_) | inVars?(v, vs)
                                                   && ~(hasVarNameConflict?(t, bound_vars)) \_rightarrow
                                        Some v
                                      | _ \_rightarrow None)
                         args
         in deleteVars(v_args, vs)
       def filterKnown(vs: Vars, id: String, f: MS.Term, args: Terms, bound_vs: Vars): Vars =
         % let _ = writeLine("fk "^id^": "^ anyToString (map (fn (x,_) \_rightarrow x) vs)) in
         if id = "natural?" \_or id in? haskellOverloadedOps 
            \_or exists? (\_lambda ci \_rightarrow id in? ci.overloadedOps)
                c.coercions
          then vs
         else
         if (termFixity f = Nonfix \_and \_not (overloadedHaskellOp? c f))
            \_or (length(wildFindUnQualified((getSpec c).ops, id)) = 1
                  %% The following is only necessary for base specs
                  && length(wildFindUnQualified((getBaseSpec()).ops, id)) <= 1)
           then removeArgs(vs,args,bound_vs)
           else vs
%         case wildFindUnQualified((getSpec c).ops, id) of
%              | [opinfo] \_rightarrow
%                (case unpackFirstOpDef opinfo of
%                   | (tvs, _, _) \_rightarrow     % Could polymorphic operator sometimes be a problem??
%                     removeArgs(vs,args,bound_vs)
%                   | _ \_rightarrow vs)
%              | _ \_rightarrow vs
      def fCV(st, vs: Vars, bound_vs: Vars): Vars =
        % let _ = writeLine("fCV: "^printTerm st^"\n"^anyToString (map (fn (x,_) \_rightarrow x) vs)) in
        let vs = case st of
                   | Apply(f as Fun(Op(Qualified(q,id),_),_,_),arg,_) \_rightarrow
                     filterKnown(vs, id, f, termList arg, bound_vs)
                   | Apply(Fun(Embed(id,_),_,_),arg,_) \_rightarrow
                     if id in? c.overloadedConstructors
                       then vs
                       else removeArgs(vs, termList arg, bound_vs)
                   | Apply(Var(v,_), arg, _) | ~(inVars?(v, vs)) ->
                     removeArgs(vs, termList arg, bound_vs)
                   | _ \_rightarrow
                 case CurryUtils.getCurryArgs st of
                   | Some(f as Fun(Op(Qualified(q,id),_),_,_),args) \_rightarrow
                     filterKnown(vs, id, f, args, bound_vs)
                   | _ \_rightarrow vs
        in
        % let _ = writeLine("fCV 1: "^anyToString (map (fn (x,_) \_rightarrow x) vs)) in
        let def fCVBV(vs: Vars, st: MS.Term): Vars = fCV(st, vs, bound_vs)
            def fCVsBV(vs: Vars, tms: Terms): Vars = foldl fCVBV vs tms
        in
        case st of
          | Apply     (M, N, _)     -> fCVBV(fCVBV(vs, M), N)
          | Record    (fields, _)   -> foldl (fn (vs,(_,M)) -> fCVBV(vs, M)) vs fields
          | Bind      (_,vars,M, _) -> fCV(M, vs, insertVars(vars, bound_vs))
          | The       (var,M, _)    -> fCV(M, vs, insertVar(var, bound_vs))
          | Let       (decls, N, _) -> let vs = foldl (fn (vs,(_,M)) -> fCVBV(vs, M)) vs decls in
                                       let bound_vs = foldl (fn (bound_vs,(pat,_)) ->
                                                               insertVars(patVars pat, bound_vs))
                                                          bound_vs decls
                                       in
                                       fCV(N, vs, bound_vs)
          | LetRec    (decls, N, _) -> let vs = foldl (fn (vs,(_,M)) -> fCVBV(vs, M)) vs decls in
                                       let bound_vs = foldl (fn (bound_vs, (var,_)) ->
                                                               insertVar(var, bound_vs))
                                                          bound_vs decls
                                       in
                                       fCV(N, vs, bound_vs)
          | Lambda    (rules,    _) -> foldl (fn (vs,(p, _, M)) ->
                                              fCV(M, vs, insertVars(patVars p, bound_vs)))
                                         vs rules
          | IfThenElse(P, M, N,  _) -> fCVBV(fCVBV(fCVBV(vs, P), M), N)
          | Seq       (Ms,       _) -> fCVsBV(vs, Ms)
          | SortedTerm(M,   _,   _) -> fCVBV(vs, M)
          | Pi        (_,   M,   _) -> fCVBV(vs, M)
          | And       (tms, _)      -> fCVsBV(vs, tms)
          | _ -> vs
   in
   fCV(t, vs, [])

 %% Adds explicit typing for first reference of variable
 op addExplicitTypingForVars(t: MS.Term, vs: Vars): MS.Term * Vars =
   let def addExpl(t: MS.Term, vs: Vars, bound_vs: Vars): MS.Term * Vars =
         case t of
           | Var(v1 as (_,ty),pos) | inVars?(v1, vs) && ~(hasVarNameConflict?(t, bound_vs)) \_rightarrow
             (SortedTerm(t,ty,pos), filter (\_lambda v2 \_rightarrow \_not (equalVar?(v1, v2))) vs)
           | Apply(t1,t2,a) \_rightarrow
             let (t1,vs) = addExpl(t1,vs,bound_vs) in
             let (t2,vs) = addExpl(t2,vs,bound_vs) in
             (Apply(t1,t2,a),vs)
           | Record(prs,a) \_rightarrow
             let (prs,vs) = foldl (\_lambda ((prs,vs),(id,st)) \_rightarrow
                                  let (st,vs) = addExpl(st,vs,bound_vs) in
                                  (Cons((id,st),prs), vs))
                             ([],vs) prs
             in
             (Record(reverse prs,a),vs)
           | Bind(bdr,lvs,st,a) \_rightarrow
             let (st,vs) = addExpl(st,vs,insertVars(lvs, bound_vs)) in
             (Bind(bdr,lvs,st,a),vs)
           | The(v,st,a) \_rightarrow
             let (st,vs) = addExpl(st,vs,insertVar(v, bound_vs)) in
             (The(v,st,a),vs)
           | Let(bds,st,a) \_rightarrow                % Should really look in bds
             let bound_vs = foldl (fn (bound_vs,(pat,_)) ->
                                     insertVars(patVars pat, bound_vs))
                              bound_vs bds
             in
             let (st,vs) = addExpl(st,vs,bound_vs) in
             (Let(bds,st,a),vs)
           | LetRec(bds,st,a) \_rightarrow
             let bound_vs = foldl (fn (bound_vs, (var,_)) ->
                                     insertVar(var, bound_vs))
                              bound_vs bds
             in
             let (st,vs) = addExpl(st,vs,bound_vs) in
             (LetRec(bds,st,a),vs)
           | IfThenElse(t1,t2,t3,a) \_rightarrow
             let (t1,vs) = addExpl(t1,vs,bound_vs) in
             let (t2,vs) = addExpl(t2,vs,bound_vs) in
             let (t3,vs) = addExpl(t3,vs,bound_vs) in
             (IfThenElse(t1,t2,t3,a),vs)
           | Lambda(cases,a) ->
             let (cases,vs) = foldl (fn ((result,vs),(p,c,t)) ->
                                       let (t,vs) = addExpl(t,vs,insertVars(patVars p, bound_vs)) in
                                       (result ++ [(p,c,t)], vs))
                                ([],vs) cases
             in
             (Lambda(cases,a), vs)
            %% Probably should put other cases
           | _ \_rightarrow (t,vs)
    in
    addExpl(t, vs, [])

 %op addExplicitTypingForNumbers(tm: MS.Term): MS.Term =

 op backwardsSExpr(s: String, pos: Nat): Option Nat =
   if pos >= length s then None
   else
   let def skip_back(i, paren_depth, non_ws?) =
         if i < 0 then None
         else
         let chr = s@i in
         if chr = #) then skip_back(i-1, paren_depth+1, true)
          else if chr = #(
            then if paren_depth = 1 then Some i
                   else skip_back(i-1, paren_depth-1, true)
          else if paren_depth = 0 && whiteSpaceChar? chr
            then if non_ws? then Some(i+1)
                  else skip_back(i-1, paren_depth, false)
          else skip_back(i-1, paren_depth, true)
   in
   skip_back(pos, 0, false)

 op lastLineEnds(prf: String): Boolean =
   let len_prf = length prf in
   case backwardsSExpr(prf, len_prf-1) of
     | None -> false
     | Some end_char ->
   let beg_last_line = case findLastBefore("\n", prf, end_char) of
                         | Some i -> i+1
                         | None -> 0
   in
  % let real_beg_last_line = skipWhiteSpace(prf, beg_last_line) in
   %% Should be more sophisticated
   case searchBetween("by", prf, beg_last_line, end_char) of
     | None -> false
     | Some n -> (n = 0 || whiteSpaceChar?(prf@(n-1)))
                && length prf > n+3
                && (whiteSpaceChar?(prf@(n+2))
                      || prf@(n+2) = #()

 op proofEndsWithTerminator?(prf: String): Boolean =
   let len = length prf in
   testSubseqEqual?("done",prf,0,len-4)
  \_or testSubseqEqual?("sorry",prf,0,len-5)
  \_or testSubseqEqual?("qed",prf,0,len-3)
  \_or lastLineEnds prf

 op  stripExcessWhiteSpace: String \_rightarrow String
 def stripExcessWhiteSpace s =
   let len = length s in
   if len > 0 \_and s@(len-1) in? [#\s,#\n]
     then stripExcessWhiteSpace(subFromTo(s,0,len-1))
     else if len > 2 && s@0 = #\s && s@1 = #\s
           then subFromTo(s,2,len)
           else s

 op endOfFirstLine(s: String): Nat =
   case search("\n",s) of
     | Some n \_rightarrow n
     | None \_rightarrow length s


 %% --------------------------------------------------------------------------------
 %% Terms
 %% --------------------------------------------------------------------------------

 op infixFun? (c: Context) (f: Fun): Option String =
   % let _ = writeLine("infixFun? of "^anyToString f) in
   let result =
         case f of
           | Op(qid,fx?) ->
             (let spc = getSpec c in
               case specialOpInfo c qid of
                | Some(haskell_id, infix?, _, _, _) \_rightarrow
                  (case infix? of
                     | Some fx -> Some haskell_id
                     | None -> None)
                | _ ->
               if embed? Infix fx?
                 then Some(mainId qid)
               else
               case AnnSpec.findTheOp(spc,qid) of
                 | Some{names=_,fixity = Infix fx, dfn=_,fullyQualified?=_} ->
                   Some(mainId qid)
                 | _ -> None)
           | And       \_rightarrow Some "&&"
           | Or        \_rightarrow Some "||"
           | Implies   \_rightarrow Some "=>"
           | Iff       \_rightarrow Some "=="
           | Equals    \_rightarrow Some "=="
           | NotEquals \_rightarrow Some "=~="
           | _ -> None
   in
   % let _ = writeLine("is "^anyToString result) in
   result

 op infixOp? (c: Context) (t: MS.Term): Option String =
   case t of
     | Fun(f,_,_) -> infixFun? c f
     | _ -> None

 op nonCaseMatch?(match: Match): Boolean =
   case match of
     | (NatPat _,_,_)::_ -> true
     | (CharPat _,_,_)::_ -> true
     | _ -> false

 op charMatch?(match: Match): Boolean =
   case match of
     | (CharPat _,_,_)::_ -> true
     | _ -> false

 op mkCoproductPat(ty: Sort, id: String, spc: Spec): Pattern =
   let Some(_,opt_ty) = findLeftmost (fn (id1,_) -> id = id1) (coproduct(spc, ty)) in
   mkEmbedPat(id,mapOption mkWildPat opt_ty,ty)

 op  ppTerm : Context \_rightarrow ParentTerm \_rightarrow MS.Term \_rightarrow Pretty
 def ppTerm c parentTerm term =
   %let _ = writeLine(printTerm term^": "^anyToString parentTerm) in
   case (isFiniteList term) of
     | Some terms \_rightarrow
       prConcat [prString "[",
                 prPostSep 0 blockFill (prString ", ") (map (ppTerm c Top) terms),
                 prString "]"]
     | None \_rightarrow
   let def prApply(term1, term2) =
      case (term1, term2) of
        | (Apply(Fun(Op(qid, _), _, _), t1, _), _) | reversedNonfixOp? c qid ->
          %% Reversed curried op, not infix
          let Some(haskell_id,_,_,reversed,_) = specialOpInfo c qid in
          enclose?(parentTerm ~= Top,
                   prBreak 2 [prString haskell_id,
                              prSpace,
                              ppTermEncloseComplex? c Nonfix term2,
                              prSpace,
                              ppTermEncloseComplex? c Nonfix t1])
        | (Fun(Embed(constr_id,_), ty, _), Record (("1",_)::_,_)) \_rightarrow
          let spc = getSpec c in
          let constr_ty = range(spc,ty) in
          if multiArgConstructor?(constr_id,constr_ty,spc) then
          %% Treat as curried
             prBreak 2 [ppConstructorTyped(constr_id, constr_ty, spc),
                        prSpace,
                        prPostSep 2 blockFill prSpace
                          (map (ppTermEncloseComplex? c Nonfix)
                             (MS.termToList term2))]
          else prConcat [ppConstructorTyped(constr_id, constr_ty, spc),
                         prSpace,
                         ppTerm c Nonfix term2]
        | (Lambda (match, _),_) \_rightarrow
          enclose?(parentTerm \_noteq Top,
                   prBreakCat 0 [[prString "case ",
                                  ppTerm c Top term2],
                                 [prString " of ",
                                 ppMatch c match]])
        | (Fun (Project p, ty1, _), _) \_rightarrow
          let pid = projectorFun(p,ty1,getSpec c) in
          prConcat [prString pid,
                    prConcat [prSpace, ppTermEncloseComplex? c Nonfix term2]]
%         | (Fun (Op (Qualified("Nat","natural?"),_), _,a),_) \_rightarrow  % natural? e \_longrightarrow 0 <= e
%           let term2 = case term2 of
%                         | Apply(Fun(Op(Qualified(q,"int"),_),_,_),x,_) | q = toHaskellQual \_rightarrow
%                           %% In this case it is known true, but leave it in for now for transparency
%                           x
%                         | _ \_rightarrow term2
%           in
%           ppTerm c parentTerm (mkAppl(Fun(Op (Qualified("Integer","<="),Infix(Left,20)),Any a,a),
%                                       [mkNat 0, term2]))
        | (Fun(Op(qid,Infix _),_,a), term2) \_rightarrow
          let spc = getSpec c in
          ppTerm c parentTerm
            (case productSorts(spc, inferType (spc, term2)) of
               | [t1,t2] ->
                 MS.mkLet([(MS.mkTuplePat[MS.mkVarPat("x",t1), MS.mkVarPat("y",t2)], term2)],
                          mkAppl(term1, [mkVar("x",t1), mkVar("y",t2)]))
               | _ -> fail("Can't get argument types of infix operator: "^ printTerm term))
        %%  embed? foo x  -->  case x of foo _ -> true | _ -> false
        | (Fun(Embedded id,ty,a), term2) \_rightarrow
          let spc = getSpec c in
          let term2_ty = inferType(spc, term2) in
          let lam_tm = Lambda([(mkCoproductPat(term2_ty,id,spc),trueTerm,trueTerm),
                               (mkWildPat term2_ty,trueTerm,falseTerm)], a)
          in
          prApply(lam_tm, term2)
        | _ \_rightarrow
          (case infixOp? c term1 of    % Infix ops are translated uniformly to curried ops
             | Some infix_str \_rightarrow
               enclose?(parentTerm ~= Top,
                        prLinearCat 0 [[prString "let (x,y) = ",
                                        ppTerm c Top term2,
                                        prSpace],
                                       [prString "in x ",
                                        prString infix_str,
                                        prString " y"]])
%                let spc = getSpec c in
%                ppTerm c parentTerm
%                  (case productSorts(spc, inferType (spc, term2)) of
%                     | [t1,t2] ->
%                       MS.mkLet([(MS.mkTuplePat[MS.mkVarPat("x",t1), MS.mkVarPat("y",t2)], term2)],
%                                mkAppl(term1, [mkVar("x",t1), mkVar("y",t2)]))
%                     | _ -> fail("Can't get argument types of infix operator: "^ printTerm term))
             | _ ->
           (case termFixity c term1 of
              | (Some pp_id,_,true,reversed) ->  % op translated to curried
                let terms2 = MS.termToList term2 in
                let terms2 = if reversed then reverse terms2 else terms2 in
                if length terms2 = 1
                  then
                    (let spc = getSpec c in
                     case productOpt(spc, inferType(spc, term2)) of
                       | Some fields ->
                         let (rec_pat, rec_tm) = patTermVarsForProduct fields in
                         ppTerm c parentTerm (MS.mkLet([(rec_pat, term2)], mkApply(term1, rec_tm)))
                       | None ->
                     case arrowOpt(spc, inferType(spc, term)) of
                       | Some(dom, _) ->
                         let new_v = ("cv", dom) in
                         ppTerm c parentTerm (mkLambda (mkVarPat new_v, mkApply(term, mkVar new_v)))
                       | None -> fail("Can't reverse term: "^printTerm term))
                else
                prBreak 2 [pp_id,
                           prSpace,
                           prPostSep 2 blockFill prSpace
                             (map (ppTermEncloseComplex? c Nonfix) terms2)]
              | (Some pp_id,_,false,true) ->
                (let spc = getSpec c in
                 case arrowOpt(spc, inferType(spc, term)) of
                   | Some(dom, _) ->
                     let new_v = ("cv", dom) in
                     ppTerm c parentTerm (mkLambda (mkVarPat new_v, mkApply(term, mkVar new_v)))
                   | None -> fail("Can't reverse term: "^printTerm term))
          | _ ->                 
            prBreak 2 [ppTerm c (Infix(Left,1000)) term1,
                       case term2 of
                         | Record _ \_rightarrow ppTerm c Top term2
                         | _ \_rightarrow prConcat [prSpace, ppTermEncloseComplex? c Nonfix term2]]))

   in
   case term of
     | Apply (trm1, trm2 as (Record ([("1", t1), ("2", t2)], a)), _) \_rightarrow
       (case (trm1, t2) of
        | (Fun(RecordMerge, ty, _), Record (fields,_)) ->
          let spc = getSpec c in
          let recd_ty = range(spc, ty) in
          let recd_ty = normalizeType (spc, c.typeNameInfo, false) recd_ty in
          let recd_ty = unfoldToBaseNamedType(spc, recd_ty) in
          enclose?(parentTerm ~= Top,
                   prBreak 2 [ppTerm c (Infix(Left,1000)) t1,
                              let def ppField (x,y) =
                                     prConcat [prString (case recd_ty of
                                                           | Base(qid, _, _) -> mkNamedRecordFieldName(qid,x)
                                                           | _ -> mkFieldName x),
                                               prString " := ",
                                               ppTerm c Top y]
                              in
                              prConcat [prString "{",
                                        prPostSep 0 blockLinear (prString ", ") (map ppField fields),
                                        prString "}"]])
        | _ ->
        let def prInfix (f1, f2, encl?, same?, t1, oper, t2) =
              enclose?(encl?,
                       prLinearCat (if same? then -2 else 2)
                         [[ppTerm c f1 t1, prSpace],
                          [oper, prSpace, ppTerm c f2 t2]])
        in
        let fx = termFixity c trm1 in
        % let _ = writeLine("parentTerm: "^anyToString parentTerm) in
        % let _ = writeLine(printTerm trm1 ^ " " ^printTerm trm2 ^ "\n" ^ anyToString fx) in
        let (t1,t2) = if fx.4 then (t2,t1) else (t1,t2) in   % Reverse args
        (case (parentTerm, fx) of
           | (_, (None, Nonfix, false, _)) \_rightarrow
             prApply (trm1, mkTuple[t1,t2])
           | (_, (Some pr_op, Nonfix, curried?, _)) \_rightarrow
             if ~curried?
               then enclose?(parentTerm ~= Top,
                             prConcat[pr_op,
                                      enclose?(true, prLinearCat 0 [[ppTerm c Top t1, prString ", "],
                                                                    [ppTerm c Top t2]])])
             else
             enclose?(parentTerm ~= Top,
                      prLinearCat 2 [[pr_op,prSpace],
                                     [ppTermEncloseComplex? c Nonfix t1, prSpace,
                                      ppTermEncloseComplex? c Nonfix t2]])
           | (Nonfix, (Some pr_op, Infix (a, p), _, _)) \_rightarrow
             prInfix (Infix (Left, p), Infix (Right, p), true, false, t1, pr_op, t2)
           | (Top,    (Some pr_op, Infix (a, p), _, _)) \_rightarrow
             prInfix (Infix (Left, p), Infix (Right, p), false, false, t1, pr_op, t2) 
           | (Infix (a1, p1), (Some pr_op, Infix (a2, p2), _, _)) \_rightarrow
             if p1 = p2
               then prInfix (Infix (Left, p2), Infix (Right, p2), true,  % be conservative a1 \_noteq a2
                             a1=a2, t1, pr_op, t2)
               else prInfix (Infix (Left, p2), Infix (Right, p2), p1 > p2, false, t1, pr_op, t2)))
     | Apply(term1 as Fun (Not, _, _),term2,_) \_rightarrow
       enclose?(case parentTerm of
                  | Infix(_,prec) \_rightarrow prec > 18
                  | _ \_rightarrow false,
                prApply (term1,term2))
     | Apply (term1,term2,_) \_rightarrow prApply (term1,term2)
     | ApplyN ([t1, t2], _) \_rightarrow prApply (t1, t2)
     | ApplyN (t1 :: t2 :: ts, a) \_rightarrow prApply (ApplyN ([t1, t2], a), ApplyN (ts, a))
     | Record (fields,_) \_rightarrow
       (case fields of
          | [] \_rightarrow prString "()"
          | ("1",_) :: _ \_rightarrow
            let def ppField (_,y) = ppTerm c Top y in
            prConcat [prString "(",
                      prPostSep 0 blockFill (prString ", ") (map ppField fields),
                      prString ")"]
          | _ \_rightarrow
            let spc = getSpec c in
            let recd_ty = inferType(spc, term) in
            let recd_ty = normalizeType (spc, c.typeNameInfo, false) recd_ty in
            let recd_ty = unfoldToBaseNamedType(spc, recd_ty) in
            let def ppField (x,y) =
                  prConcat [prString (case recd_ty of
                                      | Base(qid, _, _) -> mkNamedRecordFieldName(qid,x)
                                      | _ -> mkFieldName x),
                            prString " = ",
                            ppTerm c Top y]
            in
              prConcat [prString "{",
                        prPostSep 0 blockLinear (prString ", ") (map ppField fields),
                        prString "}"])
     | The (var,term,_) \_rightarrow  %% Not exec!!
       prBreak 0 [prString "(THE ",
                  ppVar c var,
                  prString ". ",
                  ppTerm c Top term,
                  prString ")"]
     | Bind (binder,vars,term,_) \_rightarrow  %% Not exec!!
       enclose?(case parentTerm of
                  | Infix(_,prec) \_rightarrow true  % prec > 18
                  | _ \_rightarrow false,
                prBreakCat 2 [[ppBinder binder,
                               prConcat(addSeparator prSpace (map (ppVar c) vars)),
                               prString ". "],
                              [ppTerm c Top term]])
     | Let ([(p,t)], bod, a) | existsPattern? (embed? EmbedPat) p ->
       prApply(Lambda([(p, trueTerm ,bod)], a), t)
     | Let (decls,term,_) \_rightarrow
       let def ppDecl (pattern,term) =
             prBreakCat 2 [[ppPattern c pattern (Some ""),
                            prSpace],
                           [prString "= ",
                            ppTerm c Top term]]
       in
       enclose?(infix? parentTerm,
                prLinear 0 [prLinear 0
                              [prConcat[prString "let ",
                                        prLinear 0 (addSeparator (prString "; ")
                                                      (map ppDecl decls)),
                                        prSpace],
                               prString "in "],
                            ppTerm c parentTerm term])
     | LetRec (decls,term,_) \_rightarrow
       let def ppDecl (v,term) =
             prBreak 0 [%prString "def ",
                        ppVarWithoutSort v,
                        prString " = ",
                        ppTerm c Top term]
       in
       enclose?(infix? parentTerm,
                prLinear 0 [prLinear 0
                              [prString "let",
                               prConcat[prLinear 0 (map ppDecl decls), prSpace],
                               prString "in "],
                            ppTerm c (if infix? parentTerm then Top else parentTerm) term])
     | Var (v,_) \_rightarrow ppVarWithoutSort v
     | Fun (fun,ty,_) \_rightarrow ppFun c parentTerm fun ty
%      | Lambda ([(_, Fun (Bool true,  _, _), Fun (Bool true,  _, _))], _) ->
%        prString "TRUE"                 % \_lambdax. True
     | Lambda ([(pattern,_,term)],_) \_rightarrow
       enclose?(parentTerm \_noteq Top,
                prBreakCat 2 [[prString "\\",
                                 ppPattern c pattern (Some ""),
                               prString ". "],
                              [ppTerm c Top term]])
     | Lambda (match,_) \_rightarrow ppMatch c match
     | IfThenElse (pred,term1,term2,_) \_rightarrow 
       enclose?(infix? parentTerm,
                blockLinear (0,[(0,prConcat [prString "if ",
                                             ppTerm c Top pred,
                                             prString " then "]),
                                (2,ppTerm c Top term1),
                                (-1,prString " else "),
                                (2,ppTerm c Top term2)]))
     | Seq (terms,_) \_rightarrow
       %prPostSep 0 blockLinear (prString "; ") (map (ppTerm c Top) terms)
       ppTerm c parentTerm (last terms)
     | SortedTerm (tm, ty, _) \_rightarrow
       enclose?(true, prBreakCat 0 [[ppTerm c parentTerm tm, prString "::"], [ppType c Top ty]])
     | mystery \_rightarrow fail ("No match in ppTerm with: '" ^ (anyToString mystery) ^ "'")

 op unfoldToBaseNamedType(spc: Spec, ty: Sort): Sort =
   % let _ = writeLine("ufnp: "^printSort ty) in
   case ty of
     | Base _ ->
       (case tryUnfoldBase spc ty of
        | Some (uf_ty as Base _) -> unfoldToBaseNamedType(spc, uf_ty)
        | Some (Subsort(sup_ty, _, _)) -> unfoldToBaseNamedType(spc, sup_ty)
        | _ -> ty)
     | _ -> ty

 op  projectorFun: String * Sort * Spec \_rightarrow String
 def projectorFun (p, s, spc) =
   let (prod_ty, arity) = case sortArity(spc, s) of
                            | None \_rightarrow (s,1)
                            | Some pr \_rightarrow pr
   in
   case p of
     | "1" \_rightarrow "fst"
     | "2" \_rightarrow (if arity = 2 then "snd" else "second")
     | "3" \_rightarrow (if arity = 3 then "thirdl" else "third")
     | "4" \_rightarrow (if arity = 4 then "fourthl" else "fourth")
     | "5" \_rightarrow (if arity = 5 then "fifthl" else "fifth")
     | "6" \_rightarrow (if arity = 6 then "sixthl" else "sixth")
     | "7" \_rightarrow (if arity = 7 then "seventhl" else "seventh")
     | "8" \_rightarrow (if arity = 8 then "eighthl" else "eighth")
     | "9" \_rightarrow (if arity = 9 then "ninethl" else "nineth")
     | _ \_rightarrow
   case unfoldToBaseNamedType(spc, prod_ty) of
     | Base(qid, _, _) -> mkNamedRecordFieldName(qid,p)
     | _ -> mkFieldName p

 op  ppBinder : Binder \_rightarrow Pretty
 def ppBinder binder =
   case binder of
     | Forall \_rightarrow prString "fa"
     | Exists \_rightarrow prString "ex"
     | Exists1 \_rightarrow prString "ex1"

 op ppVarStr(nm: String): Pretty =
   if nm in? disallowedVarNames then prString(nm^"__v")
     else prString (ppIdStr nm)

 op  ppVarWithoutSort : Var \_rightarrow Pretty
 def ppVarWithoutSort (id, _(* ty *)) =
   ppVarStr id

 op  ppVar : Context \_rightarrow Var \_rightarrow Pretty
 def ppVar c (id, ty) =
   ppVarStr id
%   prConcat [ppVarStr id,
%             prString ":",
%             ppType c Top ty]

 op  ppMatch : Context \_rightarrow Match \_rightarrow Pretty
 def ppMatch c cases =
   let def ppCase (pattern, _, term) =
         prBreakCat 0 [[ppPattern c pattern None,
                        prString " -> "],
                       [ppTerm c Top term]]
   in
     (prSep (-3) blockAll (prString " | ") (map ppCase cases))

 op  ppPattern : Context \_rightarrow Pattern \_rightarrow Option String \_rightarrow Pretty
 def ppPattern c pattern wildstr = 
   case pattern of
     | AliasPat (pat1, pat2, _) \_rightarrow 
       prBreak 0 [ppPattern c pat1 wildstr,
                  prString "@",
                  enclose?(true, ppPattern c pat2 wildstr)]
     | VarPat (v, _) \_rightarrow ppVarWithoutSort v
     | EmbedPat (constr, pat, ty, _) \_rightarrow
       prBreak 0 [ppConstructorTyped (constr, ty, getSpec c),
                  case pat of
                    | None \_rightarrow prEmpty
                    | Some pat \_rightarrow
                  case pat of
                    %% Print constructors with tuple args curried, unless polymorphic
                    | RecordPat(("1",_)::_,_) | multiArgConstructor?(constr, ty, getSpec c) \_rightarrow
                      prBreak 2 [prSpace,
                                 prPostSep 2 blockFill prSpace
                                   (map (\_lambda p \_rightarrow enclose?(case p of
                                                        | EmbedPat(_, Some _, _, _)-> true
                                                        | AliasPat _ -> true
                                                        | _ -> false,
                                                        ppPattern c p wildstr))
                                    (patternToList pat))]
                    | WildPat (pty,_) | multiArgConstructor?(constr, ty, getSpec c) \_rightarrow
                      let tys = productSorts(getSpec c, pty) in
                      prConcat [prSpace,
                                prPostSep 0 blockFill prSpace
                                  (map (fn ty \_rightarrow ppPattern c (mkWildPat ty) wildstr) tys)]
                    | _ \_rightarrow prConcat [prSpace, enclose?(embed? EmbedPat pat,
                                                       ppPattern c pat wildstr)]]
     | RecordPat (fields,_) \_rightarrow
       (case fields of
         | [] \_rightarrow prString "()"
         | ("1",_)::_ \_rightarrow
           let def ppField (idstr,pat) = ppPattern c pat (extendWild wildstr idstr) in
           prConcat [prString "(",
                     prPostSep 0 blockFill (prString ", ") (map ppField fields),
                     prString ")"]
         | _ \_rightarrow
           let def ppField (x,pat) =
                 prConcat [prString (mkFieldName x),
                           prString "=",
                           ppPattern c pat (extendWild wildstr x)]
           in
           prConcat [prString "{",
                     prPostSep 0 blockLinear (prString ", ") (map ppField fields),
                     prString "}"])
     | WildPat (ty,_) \_rightarrow
       (case wildstr of
          | Some str \_rightarrow prString("ignore"^str)
          | None \_rightarrow prString "_")
     | StringPat (str,_) \_rightarrow prString ("''" ^ str ^ "''")
     | BoolPat (b,_) \_rightarrow ppBoolean b
     | CharPat (chr,_) \_rightarrow prString (Char.show chr)
     | NatPat (int,_) \_rightarrow prString (Nat.show int)      
     | QuotientPat (pat,qid,_) \_rightarrow 
       prBreak 0 [prString ("(quotient[" ^ show qid ^ "] "),
                  ppPattern c pat wildstr,
                  prString ")"]
     | RestrictedPat (pat,term,_) \_rightarrow 
%        (case pat of
%	   | RecordPat (fields,_) \_rightarrow
%	     (case fields of
%	       | [] \_rightarrow prBreak 0 [prString "() | ",ppTerm c term]
%	       | ("1",_)::_ \_rightarrow
%		   let def ppField (_,pat) = ppPattern c pat wildstr in
%		   prConcat [
%		     prString "(",
%		     prSep (prString ",") (map ppField fields),
%		     prString " | ",
%		     ppTerm c term,
%		     prString ")"
%		   ]
%	       | _ \_rightarrow
%		   let def ppField (x,pat) =
%		     prConcat [
%		       prString x,
%		       prString "=",
%		       ppPattern c pat
%		     ] in
%		   prConcat [
%		     prString "{",
%		     prSep (prString ",") (map ppField fields),
%		     prString " | ",
%		     ppTerm c term,
%		     prString "}"
%		   ])
%	       | _ \_rightarrow
           prBreak 0 [ppPattern c pat wildstr
%% Ignore restricted patterns for now (certainly for lambdas)
%                       prString " | ",
%                       ppTerm c Top term
                      ] %)
     | SortedPat (pat,ty,_) \_rightarrow ppPattern c pat wildstr
     | mystery \_rightarrow fail ("No match in ppPattern with: '" ^ (anyToString mystery) ^ "'")

 op  multiArgConstructor?: Id * Sort * Spec \_rightarrow Boolean
 def multiArgConstructor?(constrId,ty,spc) =
   case ty of
     | Base(qid,_,_) \_rightarrow
       (let base_ty = sortDef(qid,spc) in
        case coproductOpt(spc,base_ty) of
          | None \_rightarrow false
          | Some fields \_rightarrow
            exists? (\_lambda (id,opt_arg_ty) \_rightarrow
                       case opt_arg_ty of
                         | Some(Product(("1",_)::_, _)) \_rightarrow id = constrId
                         | _ \_rightarrow false)
              fields)
     | _ \_rightarrow false

 op  extendWild (wildstr: Option String) (str: String): Option String =
    case wildstr of
      | Some s \_rightarrow Some (s^str)
      | None \_rightarrow None

 op  sortDef: QualifiedId * Spec \_rightarrow Sort
 def sortDef(qid,spc) =
   let Some info = AnnSpec.findTheSort(spc,qid) in
   firstSortDefInnerSort info

 op  ppBoolean : Boolean \_rightarrow Pretty
 def ppBoolean b =
   case b of
     | true \_rightarrow prString "True"
     | false \_rightarrow prString "False"

 op etaRuleProduct(tm: MS.Term, fields: List(Id * Sort)): MS.Term =
   let (pat,arg) = patTermVarsForProduct fields in
   mkLambda(pat, mkApply(tm, arg))

 op  ppFun : Context \_rightarrow ParentTerm \_rightarrow Fun \_rightarrow Sort \_rightarrow Pretty
 def ppFun c parentTerm fun ty =
   case fun of
     | Not       \_rightarrow prString "~"
     | And       \_rightarrow prString "&&"
     | Or        \_rightarrow prString "||"
     | Implies   \_rightarrow prString "==>"
     | Iff       \_rightarrow prString "=="
     | Equals    \_rightarrow prString "=="
     | NotEquals \_rightarrow prString "=~="
     | Quotient  _ \_rightarrow prString "quotient"
     | PQuotient _ \_rightarrow prString "quotient"
     | Choose    _ \_rightarrow prString "choose"
     | PChoose   _ \_rightarrow prString "choose"
     | Restrict \_rightarrow prString "restrict"
     | Relax \_rightarrow prString "relax"
     %| Op (qid,Nonfix) \_rightarrow ppOpQualifiedId c qid
     %| Op (qid,Unspecified) \_rightarrow ppOpQualifiedId c qid
     | Op (qid as Qualified(_,opstr),_) \_rightarrow
       (case infixFun? c fun of
          | Some infix_str \_rightarrow
            enclose?(parentTerm ~= Top,
                     prConcat [lengthString(11, "\\(x,y). x "),
                               prString infix_str,
                               prString " y"])
          | None \_rightarrow
        if (qid = Qualified("IntegerAux","-") || qid = Qualified("Integer","~"))
          && parentTerm ~= Infix(Left,1000)   % Only true if an application
          then let vt = ("i",integerSort) in
               ppTerm c parentTerm (mkLambda(mkVarPat vt, mkApply(mkFun(fun,ty), mkVar vt)))
        else
        case specialOpInfo c qid of
          | Some(haskell_id, _, curry?, reversed?, _) \_rightarrow
            if curry? || reversed?
              then (let spc = getSpec c in
                    case productOpt(spc,domain(spc,ty)) of
                      | Some fields \_rightarrow ppTerm c parentTerm (etaRuleProduct(mkFun(fun,ty), fields))
                      | None ->
                    case arrowOpt(spc, ty) of
                      | Some(dom, _) ->
                        let new_v = ("cv0", dom) in
                        ppTerm c parentTerm (mkLambda (mkVarPat new_v, mkApply(mkFun(fun,ty), mkVar new_v)))
                      | _ -> prString haskell_id)
              else prString haskell_id
          | _ -> ppOpQualifiedId c qid)
     | Project id \_rightarrow
       let (dom, _) = arrow(getSpec c, ty) in
       ppTerm c parentTerm (mkLambda(mkVarPat("tp",dom), mkApply(mkFun(fun,ty), mkVar("tp",dom))))
     | RecordMerge \_rightarrow prString "<<"
     | Embed (id,b) \_rightarrow
       (let spc = getSpec c in
        case arrowOpt(spc,ty) of
          | Some(dom,rng) \_rightarrow
            (if multiArgConstructor?(id,rng,spc)
               then
                 case productOpt(spc,dom) of
                 | Some fields \_rightarrow ppTerm c parentTerm (etaRuleProduct(mkFun(fun,ty), fields))
                 | None -> ppConstructorTyped(id, rng, getSpec c)
               else ppConstructorTyped(id, rng, getSpec c))
          | None \_rightarrow ppConstructorTyped(id, ty, getSpec c))
     | Embedded id \_rightarrow
       let (dom, _) = arrow(getSpec c, ty) in
       ppTerm c parentTerm (mkLambda(mkVarPat("cp",dom), mkApply(mkFun(fun,ty), mkVar("cp",dom))))
     | Select id \_rightarrow prConcat [prString "select ", prString id] % obsolete?
     | Nat n \_rightarrow prString (Nat.show n)
     | Char chr \_rightarrow prConcat [prString "CHR ''",
                             prString (Char.show chr),
                             prString "''"]
     | String str \_rightarrow prString ("''" ^ str ^ "''")
     | Bool b \_rightarrow ppBoolean b
     | OneName (id,fxty) \_rightarrow prString id
     | TwoNames (id1,id2,fxty) \_rightarrow ppOpQualifiedId c (Qualified (id1,id2))
     | mystery \_rightarrow fail ("No match in ppFun with: '" ^ (anyToString mystery) ^ "'")

 def omittedQualifiers = [toHaskellQual]  % "IntegerAux" "Option" ...?

 op qidToHaskellString(Qualified (qualifier,id): QualifiedId): String =
   if qualifier = UnQualified \_or qualifier in? omittedQualifiers then
     if id in? disallowedVarNames then id ^ "__c"
       else ppIdStr id
   else
     ppIdStr qualifier ^ "__" ^ ppIdStr id

 op ppQualifiedId (qid: QualifiedId): Pretty =
   prString(qidToHaskellString qid)

 op  ppOpQualifiedId : Context \_rightarrow QualifiedId \_rightarrow Pretty
 def ppOpQualifiedId c qid =
   case specialOpInfo c qid of
     | Some(s,_,_,_,_) \_rightarrow prString s
     | None \_rightarrow ppQualifiedId qid

 %% May only need ops that can be unary
 op overloadedHaskellOps: List String = ["+","-","^","abs","min","max"]

 op overloadedHaskellOp? (c: Context) (f: MS.Term) : Boolean =
   case f of
     | Fun(Op(qid,_),_,_) \_rightarrow
       (case specialOpInfo c qid of
          | Some(s,_,_,_,_) \_rightarrow s in? overloadedHaskellOps
          | None \_rightarrow false)
     | _ \_rightarrow false

 op  ppTypeQualifiedId : Context \_rightarrow QualifiedId \_rightarrow Pretty
 def ppTypeQualifiedId c qid =
   case specialTypeInfo c qid of
     | Some(s,_,_) \_rightarrow prString s
     | None \_rightarrow
   case qid of
%% Table-driven now above
%      | Qualified("Nat","Nat") \_rightarrow prString "nat"
%      | Qualified("List","List") \_rightarrow prString "list"
%      | Qualified("String","String") \_rightarrow prString "string"
%      | Qualified("Char","Char") \_rightarrow prString "char"
%      | Qualified("Boolean","Boolean") \_rightarrow prString "bool"
%      | Qualified("Integer","Integer") \_rightarrow prString "int"
     | _ \_rightarrow ppQualifiedId qid


 op  ppFixity : Fixity \_rightarrow Pretty
 def ppFixity fix =
   case fix of
     | Infix (Left,  n) \_rightarrow prConcat [prString "infixl ",
                                     prString (show n)]
     | Infix (Right, n) \_rightarrow prConcat [prString "infixr ",
                                     prString (show n)]
     | Nonfix           \_rightarrow prEmpty % prString "Nonfix"
     | Unspecified      \_rightarrow prEmpty % prString "Unspecified"
     | Error fixities   \_rightarrow prConcat [prString "conflicting fixities: [",
                                     prPostSep 0 blockFill (prString ",")
                                       (map ppFixity fixities),
                                     prString "]"]
     | mystery \_rightarrow fail ("No match in ppFixity with: '" ^ (anyToString mystery) ^ "'")

 op  isSimpleSort? : Sort \_rightarrow Boolean
 def isSimpleSort? ty =
   case ty of
     | Base _ \_rightarrow true
     | Boolean _ \_rightarrow true
     | _ \_rightarrow false

 op  ppInfixType : Context \_rightarrow Sort \_rightarrow Pretty
 def ppInfixType c ty =
   case arrowOpt(getSpec c,ty) of
     | Some(dom, rng) \_rightarrow
       (case productSorts(getSpec c,dom) of
         | [arg1_ty,arg2_ty] \_rightarrow
           ppType c Top (mkArrow(arg1_ty, mkArrow(arg2_ty,rng)))
         | _ \_rightarrow ppType c Top ty)
     | _ \_rightarrow ppType c Top ty

 op  ppType : Context \_rightarrow ParentSort \_rightarrow Sort \_rightarrow Pretty
 def ppType c parent ty =
   case ty of
     | Base (qid,[],_) \_rightarrow ppTypeQualifiedId c qid
      %% CoProduct only at top level
%     | CoProduct (taggedSorts,_) \_rightarrow 
%       let def ppTaggedSort (id,optTy) =
%       case optTy of
%         | None \_rightarrow quoteIf(~in_quotes?, id, ppConstructor id)
%         | Some ty \_rightarrow
%           prConcat [quoteIf(~in_quotes?, id, ppConstructor id), prSpace,
%                     case ty of
%                       | Product(fields as ("1",_)::_,_) \_rightarrow	% Treat as curried
%                         prConcat(addSeparator prSpace
%                                    (map (\_lambda (_,c_ty) \_rightarrow ppType c CoProduct in_quotes? c_ty) fields))
%                       | _ \_rightarrow ppType c CoProduct in_quotes? ty]
%       in
%         enclose?(case parent of
%                    | Product \_rightarrow true
%                    | CoProduct \_rightarrow true
%                    | Subsort \_rightarrow true
%                    | _ \_rightarrow false,
%                  prSep (-2) blockAll (prString "| ") (map ppTaggedSort taggedSorts))
     | Boolean _ \_rightarrow prString "Bool"  
     | TyVar (tyVar,_) \_rightarrow prString tyVar
     | MetaTyVar (tyVar,_) \_rightarrow 
       let ({link, uniqueId, name}) = ! tyVar in
       prString (name ^ (Nat.show uniqueId))

     | Base (qid,[ty],_) \_rightarrow
       prBreak 0 [ppType c Apply ty,
                  prSpace,
                  ppTypeQualifiedId c qid]
     | Base (qid,tys,_) \_rightarrow
       prBreak 0 [prString " (",
                  prPostSep 0 blockFill (prString ", ") (map (ppType c Top) tys),
                  prString ")",
                  ppTypeQualifiedId c qid]      | Arrow (ty1,ty2,_) \_rightarrow
       enclose?(case parent of
                  | Product -> true
                  | ArrowLeft -> true
                  | Subsort -> true
                  | Apply \_rightarrow true
                  | _ -> false,
                prBreak 0[ppType c ArrowLeft ty1,
                          prString " -> ",
                          ppType c ArrowRight ty2])
     | Product (fields,_) \_rightarrow
       (case fields of
          | [] \_rightarrow prString "unit"
          | ("1",_)::_ \_rightarrow
            let def ppField (_,y) = ppType c Product y in
            enclose?(case parent of
                       | Product -> true
                       | Subsort -> true
                       | Apply \_rightarrow true
                       | _ -> false,
                     prSep 2 blockFill (prString ", ")
                       (map ppField fields))
          | _ \_rightarrow
            let def ppField (x,y) =
            prLinearCat 2 [[prString (mkFieldName x),
                            prString " :: "],
                           [ppType c Top  y]]
            in
              prBreak 2 [prString "{",
                         prPostSep 0 blockLinear(prString ", ") (map ppField fields),
                         prString "}"])
     | Quotient (ty,term,_) \_rightarrow
         prBreak 0 [prString "(",
                    ppType c Top ty,
                    prString " \\ ",
                    ppTerm c Top term,
                    prString ")"]
     | Subsort (ty,_,_) \_rightarrow ppType c parent ty

     | mystery \_rightarrow fail ("No match in ppType with: '" ^ (anyToString mystery) ^ "'")

op  ppLitString: String \_rightarrow Pretty
def ppLitString id = prString(IO.formatString1("~S",id))

op  infix?: ParentTerm \_rightarrow Boolean
def infix? parentTerm =
  case parentTerm of
    | Infix _ \_rightarrow true
    | _ \_rightarrow false

op  termFixity: Context \_rightarrow MS.Term \_rightarrow Option Pretty * Fixity * Boolean * Boolean
def termFixity c term = 
  case term of
    | Fun (termOp, _, _) -> 
      (case termOp of
         | Op (id, fixity) ->
           (case specialOpInfo c id of
              | Some(haskell_id,fix,curried,reversed,_) \_rightarrow
                (case fix of
                   | Some f \_rightarrow (Some(prString haskell_id), Infix f, curried, reversed)
                   | None \_rightarrow   (Some(prString haskell_id), Nonfix, curried, reversed))
              | None \_rightarrow
                case fixity of
                  | Unspecified \_rightarrow (None, Nonfix, false, false)
                  | Nonfix \_rightarrow (None, Nonfix, false, false)
                  | _ -> (Some(ppInfixId id), fixity, true, false))
         | And            -> (Some(prString "&&"),Infix (Right, 15),true, false)
         | Or             -> (Some(prString "||"), Infix (Right, 14),true, false)
         | Implies        -> (Some(prString "==>"), Infix (Right, 13), true, false) 
         | Iff            -> (Some(prString "=="), Infix (Left, 20), true, false)
         | Not            -> (Some(prString "~"), Infix (Left, 18), false, false) % ???
         | Equals         -> (Some(prString "=="), Infix (Left, 20), true, false) % was 10 ??
         | NotEquals      -> (Some(prString "=~="), Infix (Left, 20), true, false) % ???
         % | RecordMerge    -> (None, Infix (Left, 25), true, false)  % ???
         | _              -> (None, Nonfix, false, false))
    | _ -> (None, Nonfix, false, false)

op reversedNonfixOp? (c: Context) (qid: QualifiedId): Boolean =
  case specialOpInfo c qid of
    | Some(_ ,None,_,true,_) -> true
    | _ -> false

op  enclose?: Boolean \_times Pretty \_rightarrow Pretty
def enclose?(encl? ,pp) =
  if encl? then prConcat [prString "(", pp, prString ")"]
    else pp

op ppTermEncloseComplex? (c: Context) (parentTerm: ParentTerm) (term: MS.Term): Pretty =
  let encl? = \_not(isSimpleTerm? term) in
  enclose?(encl?, ppTerm c (if encl? then Top else parentTerm) term)

def prSpace = prString " "

op  ppInfixId: QualifiedId \_rightarrow Pretty
def ppInfixId(Qualified(_,main_id)) = prString (infixId main_id)

op infixId(id: String): String =
  let idarray = explode(id) in
  let id = foldr (\_lambda(#\\,id) -> "\\\\"^id   % backslashes must be escaped
                  | (c,id) -> show(c)^id) "" idarray
  in id

op  ppInfixDefId: QualifiedId \_rightarrow Pretty
def ppInfixDefId(Qualified(_,main_id)) = prString (infixDefId main_id)

op infixDefId(id: String): String =
  let idarray = explode(id) in
  let id = foldr (\_lambda(#\\,id) -> "\\\\"^id   % backslashes must be escaped
                  | (#/,id) -> "'/"^id
                  | (#(,id) -> "'("^id
                  | (#),id) -> "')"^id
                  | (#_,id) -> "'_"^id
                  | (c,id) -> show(c)^id) "" idarray
  in id

op  ppIdStr: String -> String
def ppIdStr id =
  let idarray = explode(id) in
  let def att(id, s) =
        (if id = "" then "e" else id) ^ s
  in
  let id = foldl (\_lambda(id,#?) -> att(id, "_p")
                  | (id,#=) -> att(id, "_eq")
                  | (id,#<) -> att(id, "_lt")
                  | (id,#>) -> att(id, "_gt")
                  | (id,#~) -> att(id, "_tld")
                  | (id,#/) -> att(id, "_fsl")
                  | (id,#\\) -> att(id, "_bsl")
                  | (id,#-) -> att(id, "_dsh")
                  | (id,#*) -> att(id, "_ast")
                  | (id,#+) -> att(id, "_pls")
                  | (id,#|) -> att(id, "_bar")
                  | (id,#!) -> att(id, "_excl")
                  | (id,#@) -> att(id, "_at")
                  | (id,##) -> att(id, "_hsh")
                  | (id,#$) -> att(id, "_dolr")
                  | (id,#^) -> att(id, "_crt")
                  | (id,#&) -> att(id, "_amp")
                  | (id,#') -> att(id, "_cqt")
                  | (id,#`) -> att(id, "_oqt")
                  | (id,#:) -> att(id, "_cl")
                  | (id,c) -> id ^ show c) "" idarray
  in id

op  isSimpleTerm? : MS.Term \_rightarrow Boolean
def isSimpleTerm? trm =
  case trm of
    | SortedTerm(t,_,_) \_rightarrow isSimpleTerm? t
    | Var _ \_rightarrow true
    | Fun _ \_rightarrow true
    | _ \_rightarrow false

op  isSimplePattern? : Pattern \_rightarrow Boolean
def isSimplePattern? trm =
  case trm of
    | VarPat _ \_rightarrow true
    | WildPat _ \_rightarrow true
    | EmbedPat(_,None,_,_) \_rightarrow true
    | StringPat _ \_rightarrow true
    | BoolPat _ \_rightarrow true
    | CharPat _ \_rightarrow true
    | NatPat _ \_rightarrow true
    | _ \_rightarrow false

 op  varOrTuplePattern?: Pattern \_rightarrow Boolean
 def varOrTuplePattern? p =
   case p of
     | VarPat _ \_rightarrow true
     | RecordPat(prs,_) | tupleFields? prs \_rightarrow
       forall? (\_lambda (_,p) \_rightarrow varOrTuplePattern? p) prs
     | RestrictedPat(pat,cond,_) \_rightarrow varOrTuplePattern? pat
     | WildPat _ \_rightarrow true
     | _ \_rightarrow false

 op  varOrRecordPattern?: Pattern \_rightarrow Boolean
 def varOrRecordPattern? p =
   case p of
     | VarPat _ \_rightarrow true
     | RecordPat(prs,_) \_rightarrow
       forall? (\_lambda (_,p) \_rightarrow varOrRecordPattern? p) prs
     | RestrictedPat(pat,cond,_) \_rightarrow varOrRecordPattern? pat
     | WildPat _ \_rightarrow true
     | _ \_rightarrow false

 op  simpleHead?: MS.Term \_rightarrow Boolean
 def simpleHead? t =
   case t of
     | Apply(_,arg,_) \_rightarrow varOrTupleTerm? arg
     | _ -> false

 op  varOrTupleTerm?: MS.Term \_rightarrow Boolean
 def varOrTupleTerm? p =
   case p of
     | Var _ \_rightarrow true
     | Record(prs as (("1",_)::_),_) \_rightarrow
       forall? (\_lambda (_,p) \_rightarrow varOrTupleTerm? p) prs
     | _ \_rightarrow false

 op overloadedConstructors(spc: Spec): List String =
   (foldSortInfos
      (\_lambda (info, result as (found,overloaded)) \_rightarrow
         case sortInnerSort(info.dfn) of
           | CoProduct(prs,_) \_rightarrow
             foldl (\_lambda ((found,overloaded),(id,_)) \_rightarrow
                      if id in? found
                        then (  found, id::overloaded)
                      else (id::found,     overloaded))
               result prs
           | _ \_rightarrow result)
     ([],[])
     spc.sorts).2

%% Duplicated!
 op refinedQID (refine_num: Nat) (qid as Qualified(q, nm): QualifiedId): QualifiedId =
   if refine_num = 0 then qid
     else Qualified(q,nm^"__"^show refine_num)


endspec
