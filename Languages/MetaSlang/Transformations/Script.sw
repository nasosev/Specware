Script qualifying
spec
  import Simplify, Rewriter, Interpreter, CommonSubExpressions
  import /Library/PrettyPrinter/WadlerLindig
  import /Languages/SpecCalculus/Semantics/Monad

  op [a] dummy: a

  type Context = RewriteRules.Context
  
  type Location =
    | Def QualifiedId

  type RuleSpec =
    | Unfold      QualifiedId
    | Fold        QualifiedId
    | Rewrite     QualifiedId
    | LeftToRight QualifiedId
    | RightToLeft QualifiedId
    | AllDefs

  type Movement =
    | First | Last | Next | Prev | Widen | All | Search String | ReverseSearch String

  type Script =
    | At (List Location \_times Script)
    | Move (List Movement)
    | Steps List Script
    | Simplify (List RuleSpec)
    | Apply (List RuleSpec)
    | SimpStandard
    | PartialEval
    | AbstractCommonExpressions
    | IsoMorphism(List(QualifiedId \_times QualifiedId) \_times List RuleSpec)
    | Trace Boolean
    | Print

 op Isomorphism.makeIsoMorphism: Spec * List(QualifiedId * QualifiedId) * Option String * List RuleSpec -> SpecCalc.Env Spec
 op Iso.applyIso:  Spec * List (QualifiedId * QualifiedId) * Qualifier * List RuleSpec -> SpecCalc.Env Spec

 op ppSpace: WadlerLindig.Pretty = ppString " "

 op wildQualifier: String = "*"

 op ppQid(Qualified(q,nm): QualifiedId): WadlerLindig.Pretty =
   if q = UnQualified then ppString nm
     else ppConcat[ppString q, ppString ".", ppString nm]

 op ppLoc(loc: Location): WadlerLindig.Pretty =
   case loc of
     | Def qid -> ppQid qid

 op ppRuleSpec(rl: RuleSpec): WadlerLindig.Pretty =
   case rl of
     | Unfold  qid -> ppConcat   [ppString "unfold ", ppQid qid]
     | Fold    qid -> ppConcat   [ppString "fold ", ppQid qid]
     | Rewrite qid -> ppConcat   [ppString "rewrite ", ppQid qid]
     | LeftToRight qid -> ppConcat[ppString "lr ", ppQid qid]
     | RightToLeft qid -> ppConcat[ppString "rl ", ppQid qid]
     | AllDefs -> ppString "alldefs"

 op moveString(m: Movement): String =
   case m of
     | First -> "f"
     | Last -> "l"
     | Next -> "n"
     | Prev -> "p"
     | Widen -> "w"
     | All -> "a"
     | Search s -> "s \"" ^ s ^ "\""
     | ReverseSearch s -> "r \"" ^ s ^ "\""

 op ppScript(scr: Script): WadlerLindig.Pretty =
    case scr of
      | Steps steps \_rightarrow
        ppSep (ppConcat[ppString ",", ppNewline]) (map ppScript steps)
      | At(locs, scr) \_rightarrow
        ppIndent(ppConcat [ppString "at ", ppSep (ppString ",") (map ppLoc locs), ppString ",",
                           ppNewline,
                           ppScript scr])
      | Move mvmts -> ppConcat [ppString "move (",
                                ppSep (ppString ", ") (map (fn m -> ppString(moveString m)) mvmts),
                                ppString ")"]
      | Simplify rules ->
        if rules = [] then ppString "simplify"
          else
            ppConcat [ppString "simplify ",
                      ppNest 1 (ppConcat [ppString "(",
                                          ppSep (ppConcat [ppString ", ", ppBreak])
                                            (map ppRuleSpec rules),
                                          ppString ")"])]
      | Apply [rl] -> ppRuleSpec rl
      | Apply rules ->
        ppConcat [ppString "apply (", ppSep (ppString ", ") (map ppRuleSpec rules), ppString ")"]
      | SimpStandard -> ppString "SimpStandard"
      | PartialEval -> ppString "eval"
      | AbstractCommonExpressions -> ppString "AbstractCommonExprs"
      | IsoMorphism(iso_qid_prs, rls) \_rightarrow
        ppConcat[ppString "isomorphism (",
                 ppSep(ppString ", ") (map (fn (iso,osi) ->
                                              ppConcat[ppString "(",
                                                       ppQid iso,
                                                       ppQid osi,
                                                       ppString ")"])
                                         iso_qid_prs),
                 ppString "), (",
                 ppSep(ppString ", ") (map ppRuleSpec rls),
                 ppString ")"]
      | Trace on_or_off ->
        ppConcat [ppString "trace ", ppString (if on_or_off then "on" else "off")]
      | Print -> ppString "print"

 op scriptToString(scr: Script): String =
   let pp = ppNest 3 (ppConcat [ppString "  {", ppScript scr, ppString "}"]) in
   ppFormat(pp)

 op printScript(scr: Script): () =
   writeLine(scriptToString scr)

 op mkAt(qid: QualifiedId, steps: List Script): Script = At([Def qid], mkSteps steps)
 op mkSteps(steps: List Script): Script = if length steps = 1 then head steps else Steps steps
 op mkSimplify(steps: List RuleSpec): Script = Simplify(steps)
 op mkApply(rules: List RuleSpec): Script = Apply rules
 op mkSimpStandard(): Script = SimpStandard
 op mkPartialEval (): Script = PartialEval
 op mkAbstractCommonExpressions (): Script = AbstractCommonExpressions
 op mkMove(l: List Movement): Script = Move l

 %% For convenience calling from lisp
 op mkFold(qid: QualifiedId): RuleSpec = Fold qid
 op mkUnfold(qid: QualifiedId): RuleSpec = Unfold qid
 op mkRewrite(qid: QualifiedId): RuleSpec = Rewrite qid
 op mkLeftToRight(qid: QualifiedId): RuleSpec = LeftToRight qid
 op mkRightToLeft(qid: QualifiedId): RuleSpec = RightToLeft qid
 op mkAllDefs(qid: QualifiedId): RuleSpec = AllDefs


 op ruleConstructor(id: String): QualifiedId -> RuleSpec =
   case id of
     | "fold" \_rightarrow mkFold
     | "f" \_rightarrow mkFold
     | "unfold" \_rightarrow mkUnfold
     | "uf" \_rightarrow mkUnfold
     | "rewrite" \_rightarrow mkRewrite
     | "rw" \_rightarrow mkRewrite
     | "lr" \_rightarrow mkLeftToRight
     | "lefttoright" \_rightarrow mkLeftToRight
     | "left-to-right" \_rightarrow mkLeftToRight
     | "rl" \_rightarrow mkRightToLeft
     | "righttoleft" \_rightarrow mkRightToLeft
     | "right-to-left" \_rightarrow mkRightToLeft
     | "alldefs" \_rightarrow mkAllDefs

 %% From /Languages/SpecCalculus/Semantics/Evaluate/Prove.sw
 op  claimNameMatch: QualifiedId \_times QualifiedId -> Boolean
 def claimNameMatch(cn, pn) =
   let Qualified(cq, cid) = cn in
   let Qualified(pq, pid) = pn in
   if cq = wildQualifier
     then pid = cid
   else cq = pq && cid = pid

  op warnIfNone(qid: QualifiedId, kind: String, rls: List RewriteRule): List RewriteRule =
    if rls = []
      then (warn(kind ^ printQualifiedId qid ^ " not found!");
            [])
      else rls

  op findMatchingOps (spc: Spec, Qualified (q, id): QualifiedId): List OpInfo =
   if q = wildQualifier
     then wildFindUnQualified (spc.ops, id)
     else case findAQualifierMap (spc.ops, q, id) of
            | Some info -> [info]
            | None      -> []

  op makeRule (context: Context, spc: Spec, rule: RuleSpec): List RewriteRule =
    case rule of
      | Unfold(qid as Qualified(q,nm)) \_rightarrow
        warnIfNone(qid, "Op ",
                   flatten (map (fn info ->
                                   flatten (map (fn (Qualified(q,nm)) \_rightarrow
                                                   defRule(context, q, nm, info, true))
                                              info.names))
                              (findMatchingOps(spc,qid))))
      | Rewrite(qid as Qualified(q,nm)) \_rightarrow   % Like Unfold but only most specific rules
        warnIfNone(qid, "Op ",
                   flatten (map (fn info ->
                                   flatten (map (fn (Qualified(q,nm)) \_rightarrow
                                                   defRule(context, q, nm, info, false))
                                              info.names))
                              (findMatchingOps(spc,qid))))
      | Fold(qid) \_rightarrow
        map (\_lambda rl \_rightarrow rl \_guillemotleft {lhs = rl.rhs, rhs = rl.lhs})
          (makeRule(context, spc, Unfold(qid)))
      | LeftToRight(qid) \_rightarrow
        warnIfNone(qid, "Rule-shaped theorem ",
                   foldr (\_lambda (p,r) \_rightarrow
                            if claimNameMatch(qid,p.2)
                              then (axiomRules context p) ++ r
                            else r)
                     [] (allProperties spc))
      | RightToLeft(qid) \_rightarrow
        map (\_lambda rl \_rightarrow rl \_guillemotleft {lhs = rl.rhs, rhs = rl.lhs})
          (makeRule(context, spc, LeftToRight(qid)))
      | AllDefs \_rightarrow
        foldriAQualifierMap
          (\_lambda (q,id,opinfo,val) ->
             (defRule (context,q,id,opinfo,false)) ++ val)
          [] spc.ops

  op addSubtypeRules?: Boolean = true
  op subtypeRules(term: MS.Term, context: Context): List RewriteRule =
    if ~addSubtypeRules? then []
    else
    let subtypes = foldSubTerms (fn (t,subtypes) ->
                                 let ty = inferType(context.spc, t) in
                                 if subtype? (context.spc, ty) && ~(typeIn?(ty,subtypes))
                                   then Cons(ty,subtypes)
                                   else subtypes)
                      [] term
    in
    flatten
      (map (fn ty -> let Some(sty,p) = subtypeComps (context.spc, ty) in
              let v = ("x",ty) in
              let fml = mkBind(Forall, [v], simplifiedApply(p, mkVar v, context.spc)) in
              assertRules(context, fml, "Subtype1", false))
        subtypes)

  op rewriteDebug?: Boolean = false

  op rewriteDepth: Nat = 6
  op rewrite(term: MS.Term, context: Context, rules: List RewriteRule, maxDepth: Nat): MS.Term =
     let _ = if rewriteDebug? then
               (writeLine("Rewriting:\n"^printTerm term);
                app printRule rules)
               else ()
     in
     %let rules = map (etaExpand context) rules in   % Not sure if necessary
     %let rules = prioritizeRules rules in
     let rules = rules ++ subtypeRules(term, context) in
     let rules = splitConditionalRules rules in
     let def doTerm (count, trm) =
           %let _ = writeLine("doTerm "^show count) in
           let lazy = rewriteRecursive (context,freeVars trm,rules,trm,maxDepth) in
           case lazy of
             | Nil -> trm
             | Cons([],tl) -> trm
             | Cons((rule,trm,subst)::_,tl) ->
               if count > 0 then 
                 doTerm (count - 1, trm)
               else
                 trm
     in
     let result = % if maxDepth = 1 then hd(rewriteOnce(context,[],rules,term))
                  % else
                  doTerm(rewriteDepth, term)
     in
     let _ = if rewriteDebug? then writeLine("Result:\n"^printTerm result) else () in
     result

  op makeRules (context: Context, spc: Spec, rules: List RuleSpec): List RewriteRule =
    foldr (\_lambda (rl,rules) \_rightarrow makeRule(context, spc, rl) ++ rules) [] rules

  op [a] replaceSubTerm(new: ATerm a, old: ATerm a, top: ATerm a): ATerm a * ATerm a =
    (new, mapTerm (fn s -> if s = old then new else s, id, id) top)

  op [a] infixString(f: AFun a): Option String =
    case f of
      | Op(Qualified(_,s),Infix _) -> Some s
      | And -> Some "&&"
      | Or -> Some "||"
      | Implies -> Some "=>"
      | Iff -> Some "<=>"
      | Equals -> Some "="
      | NotEquals -> Some "~="
      | _ -> None

  op [a] infixFn?(f: AFun a): Boolean =
    some?(infixString f)

  op [a] immediateSubTerms(term: ATerm a): List (ATerm a) =
    case term of
      | Apply(Fun(f,_,_), Record([("1",x), ("2",y)],_),_) | infixFn? f ->
        [x,y]
      | Apply(x,y,_) -> [x,y]
      | Record(l,_) -> map (fn (_,t) -> t) l
      | Bind(_,_,x,_) -> [x]
      | The(_,x,_)  -> [x]
      | Let (l,b,_) -> (map (fn (_,t) -> t) l) ++ [b]
      | LetRec (l,b,_) -> (map (fn (_,t) -> t) l) ++ [b]
      | Lambda (l,_) -> map (fn (_,_,t) -> t) l
      | IfThenElse(x,y,z,_) -> [x,y,z]
      | Seq(l,_) -> l
      | SortedTerm(x,_,_) -> [x]
      | And(l,_) -> l
      | _ -> []

  op [a] parentTerm(term: ATerm a, top: ATerm a): Option (ATerm a) =
    if term = top then None
      else
        let children = immediateSubTerms top in
        if term in? children then Some top
          else foldl (fn (result,c) ->
                        if some? result then result
                          else parentTerm(term,c))
                 None children

  op [a] nextTermInList(term: ATerm a, l: List(ATerm a)): Option (ATerm a) =
    case l of
      | [] -> None
      | x::rl ->
        if x = term
         then case rl of
                | [] -> None
                | y::_ -> Some y
         else nextTermInList(term,rl)

  op [a] prevTermInList(term: ATerm a, l: List(ATerm a)): Option (ATerm a) =
    case l of
      | [] -> None
      | [_] -> None
      | y::x::_ | x = term -> Some y
      | _::rl -> prevTermInList(term,rl)

  op [a] moveToNext(term: ATerm a, top_term: ATerm a): Option (ATerm a) =
    case parentTerm(term, top_term) of
      | None -> None
      | Some par ->
    case nextTermInList(term, immediateSubTerms par) of
      | Some x -> Some x
      | None -> moveToNext(par, top_term)

  op [a] moveToPrev(term: ATerm a, top_term: ATerm a):  Option(ATerm a) =
    case parentTerm(term, top_term) of
      | None -> None
      | Some par ->
    case prevTermInList(term, immediateSubTerms par) of
      | Some x -> Some x
      | None -> Some par

  op [a] searchNextSt(term: ATerm a, top_term: ATerm a, pred: ATerm a -> Boolean):  Option(ATerm a) =
    case immediateSubTerms term of
      | new_term :: _ ->
        if pred new_term
          then Some new_term
          else searchNextSt(new_term, top_term, pred)
      | [] -> 
    case moveToNext(term, top_term) of
      | None -> None
      | Some new_term ->
        if pred new_term
          then Some new_term
          else searchNextSt(new_term, top_term, pred)

 op [a] searchPrevSt(term: ATerm a, top_term: ATerm a, pred: ATerm a -> Boolean):  Option(ATerm a) =
    case moveToPrev(term, top_term) of
      | None -> None
      | Some new_term ->
        if pred new_term
          then Some new_term
          else searchPrevSt(new_term, top_term, pred)

  op [a] searchPred(s: String): ATerm a -> Boolean =
    case s of
      | "if" -> embed? IfThenElse
      | "let" -> (fn t -> embed? Let t || embed? LetRec t)
      | "case" -> (fn t -> case t of
                             | Apply(Lambda _,_,_) -> true
                             | _ -> false)
      | "fn" -> embed? Lambda
      | "the" -> embed? The
      | "fa" -> (fn t -> case t of
                           | Bind(Forall,_,_,_) -> true
                           | _ -> false)
      | "ex" -> (fn t -> case t of
                           | Bind(Exists,_,_,_) -> true
                           | _ -> false)
      | _ -> (fn t ->
                case t of
                  | Apply(Fun(f,_,_),_,_) ->
                    (case infixString f of
                       | Some fn_str -> fn_str = s
                       | None -> false)
                  | _ -> false)

  op [a] makeMove(term: ATerm a, mv: Movement, top_term: ATerm a):  Option(ATerm a) =
    case mv of
      | First ->
        (case immediateSubTerms term of
           | x::_ -> Some x
           | [] -> None)
      | Last ->
        (case immediateSubTerms term of
           | [] -> None
           | l -> Some(last l))
      | Next -> moveToNext(term, top_term)
      | Prev -> moveToPrev(term, top_term)
      | Widen -> parentTerm(term, top_term)
      | All -> Some top_term
      | Search s -> searchNextSt(term, top_term, searchPred s)
      | ReverseSearch s -> searchPrevSt(term, top_term,searchPred s)

  op makeMoves(term: MS.Term, mvs: List Movement, top_term: MS.Term):  Option MS.Term =
    case mvs of
      | [] -> Some term
      | mv :: rem_mvs ->
    case makeMove(term, mv,  top_term) of
      | Some new_term -> makeMoves(new_term, rem_mvs, top_term)
      | None -> (warn("Move failed at: "^ (foldr (fn (m,res) -> moveString m ^ " " ^ res) "" mvs));
                 None)

  op maxRewrites: Nat = 900

  %% term is the current focus and should  be a sub-term of the top-level term top_term
  op interpretTerm(spc: Spec, script: Script, term: MS.Term, top_term: MS.Term, tracing?: Boolean)
     : SpecCalc.Env ((MS.Term * MS.Term) * Boolean) =
    case script of
      | Steps steps \_rightarrow
          foldM (\_lambda ((term,top_term),tracing?) -> fn s \_rightarrow
               interpretTerm (spc,s,term,top_term,tracing?))
            ((term,top_term), tracing?) steps
      | Print -> {
          print (printTerm term ^ "\n");
          return ((term,top_term), tracing?)
        }
      | Trace on_or_off -> {
          when (on_or_off && ~tracing?)
            (print ("-- Tracing on\n" ^ printTerm term ^ "\n"));
          when (~on_or_off && tracing?)
            (print "-- Tracing off\n");
          return ((term,top_term), on_or_off)
        }
      | _ -> {
          when tracing?
            (print ("--" ^ scriptToString script ^ "\n"));
          (term,top_term) <- return
              (case script of
                | Move mvmts -> (case makeMoves(term, mvmts, top_term) of
                                   | Some new_term -> new_term
                                   | None -> term,
                                  top_term)
                | SimpStandard \_rightarrow replaceSubTerm(simplify spc term, term, top_term)
                | PartialEval \_rightarrow
                  replaceSubTerm(evalFullyReducibleSubTerms(term, spc), term, top_term)
                | AbstractCommonExpressions \_rightarrow
                  replaceSubTerm(abstractCommonSubExpressions(term, spc), term, top_term)
                | Simplify(rules) \_rightarrow
                  let context = makeContext spc in
                  let rules = makeRules (context, spc, rules) in
                  replaceSubTerm(rewrite(term,context,rules,maxRewrites), term, top_term)
                | Apply(rules) \_rightarrow
                  let context = makeContext spc in
                  let rules = makeRules (context, spc, rules) in
                  replaceSubTerm(rewrite(term,context,rules,1), term, top_term));
          when tracing? 
            (print (printTerm term ^ "\n"));
          return ((term,top_term), tracing?)
        }

  op setOpInfo(spc: Spec, qid: QualifiedId, opinfo: OpInfo): Spec =
    let Qualified(q,id) = qid in
    spc << {ops = insertAQualifierMap(spc.ops,q,id,opinfo)}

%%% Used by Applications/Specware/Handwritten/Lisp/transform-shell.lisp
  op getOpDef(spc: Spec, qid: QualifiedId): Option MS.Term =
    case findAllOps(spc,qid) of
      | [] \_rightarrow (warn("No defined op with that name."); None)
      | [opinfo] \_rightarrow
        let (tvs, srt, tm) = unpackFirstTerm opinfo.dfn in
        Some tm
      | _ -> (warn("Ambiguous op name."); None)

  op interpretSpec(spc: Spec, script: Script, tracing?: Boolean): SpecCalc.Env (Spec * Boolean) =
    case script of
      | Steps steps \_rightarrow
          foldM (\_lambda (spc,tracing?) -> fn stp \_rightarrow
               interpretSpec(spc,stp,tracing?))
            (spc,tracing?) steps
      | At (locs, scr) \_rightarrow {
          when tracing? 
            (print ("-- { at"^flatten(map (fn (Def qid) -> " "^printQualifiedId qid) locs) ^" }\n"));
          foldM (fn (spc,tracing?) -> fn Def qid \_rightarrow
                 case findAllOps(spc,qid) of
                   | [] \_rightarrow {
                       print ("Can't find op " ^ anyToString qid ^ "\n");
                       return (spc,tracing?)
                     }
                   | [opinfo] \_rightarrow {
                       (tvs, srt, tm) <- return (unpackFirstTerm opinfo.dfn); 
                       when tracing? 
                         (print ((printTerm tm) ^ "\n")); 
                       ((_,newtm),tracing?) <- interpretTerm (spc, scr, tm, tm, tracing?); 
                       newdfn <- return (maybePiTerm(tvs, SortedTerm (newtm, srt, termAnn opinfo.dfn)));
                       return (setOpInfo(spc,qid,opinfo << {dfn = newdfn}),tracing?)
                     }
                   | opinfos -> {
                       print ("Ambiguous op " ^ anyToString qid ^ "\n");
                       return (spc,tracing?)
                     })
            (spc,tracing?) locs
        }
      | IsoMorphism(iso_osi_prs, rls) \_rightarrow {
          result <- makeIsoMorphism(spc, iso_osi_prs, Some "XXX", rls);
          % return (AnnSpecPrinter.printFlatSpecToFile("DUMP.sw", result));
          return (result,tracing?)
        }
        % (time(makeIsoMorphism(spc, iso_osi_prs, rls)), tracing?)
      | Trace on_or_off -> return (spc,on_or_off)

  op Env.interpret (spc: Spec, script: Script) : SpecCalc.Env Spec = {
   (result,_) <- interpretSpec(spc, script, false); 
    % let _ = writeLine(printSpec result) in
    return result
  }
endspec
