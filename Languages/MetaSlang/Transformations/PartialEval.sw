spec
import Script

  op traceSpecializeSpec?: Bool = true
  op ignoreBaseSpec?: Bool = true

  op specializeSpec (specialFn: Spec -> MSTerm -> Option(MSTerm * QualifiedId * QualifiedIds * QualifiedIds)) (spc: Spec): Spec =
    let base_spec = getBaseSpec() in
    let (spc, rls, uf_qids, rw_qids) =
        foldOpInfos (fn (info, result as (spc, rls, uf_qids, rw_qids)) ->
                     let qid = primaryOpName info in
                     if ignoreBaseSpec? && some?(findTheOp(base_spec, qid)) then result
                     else
                     let (tvs, ty, init_dfn) = unpackFirstTerm info.dfn in
                     let tr_dfn = if rls = [] || anyTerm? init_dfn then init_dfn
                                  else
                                    let (tr_dfn, _) = interpretTerm0 (spc, mkSimplify rls, init_dfn, ty, qid, traceSpecializeSpec?) in
                                    if equalTerm?(tr_dfn, mkTypedTerm(init_dfn, ty))
                                      then init_dfn
                                    else
                                    let (tr_dfn0, _) = interpretTerm0 (spc, mkSimplify [], init_dfn, ty, qid, traceSpecializeSpec?) in
                                    if equalTerm?(tr_dfn, tr_dfn0)
                                      then init_dfn
                                      else tr_dfn
                     in
                     let (spc, rls, tr_dfn2, uf_qids, rw_qids) =
                         case findSubTerm (specialFn spc) tr_dfn of
                           | None -> (spc, rls, tr_dfn, uf_qids, rw_qids)
                           | Some(proto_tm, new_qid, new_uf_qids, new_rw_qids) ->
                         let fvs = freeVars proto_tm in
                         let proto_dfn = mkLambda(mkTuplePat(map mkVarPat fvs), proto_tm) in
                         let _ = writeLine(show new_qid^":\n"^printTerm proto_dfn) in
                         let spc = addOpDef(spc, new_qid, Nonfix, mkTypedTerm(proto_dfn, inferType(spc, proto_dfn))) in
                         let rls = Fold new_qid :: rls in
                         let (tr_dfn, _) = interpretTerm0 (spc, mkSimplify rls, tr_dfn, ty, qid, traceSpecializeSpec?) in
                         (spc, rls, tr_dfn,
                          (filter (fn qid -> qid nin? uf_qids) new_uf_qids) ++ uf_qids,
                          (filter (fn qid -> qid nin? rw_qids) new_rw_qids) ++ rw_qids)
                     in
                     if equalTerm?(tr_dfn2, init_dfn) || equalTerm?(tr_dfn2, mkTypedTerm(init_dfn, ty))
                       then result
                       else
                       let _ = writeLine("Refining "^show qid^"\n"^printTerm init_dfn^"\nto\n"^printTerm tr_dfn2) in
                       let spc = addRefinedDef(spc, info, maybePiTerm(tvs, tr_dfn2)) in
                       (spc, rls, uf_qids, rw_qids)
                     )
          (spc, [], [], [])
          spc.ops
    in
    let rw_rules = map Rewrite (uf_qids ++ rw_qids) in
    let script = mkSteps[mkSimplify1(map Unfold uf_qids),
                         mkSimplify(rls ++ rw_rules)] in
    let _ = writeLine("Partial Evaluation Script:\n"^scriptToString script) in
    let ops = foldl (fn (ops, qid as Qualified(q,id)) ->
                       case findTheOp(spc, qid) of
                         | None -> ops
                         | Some info ->
                       let (tvs, ty, init_dfn) = unpackFirstTerm info.dfn in
                       let (new_dfn, _) = interpretTerm0 (spc, script, init_dfn, ty, qid, traceSpecializeSpec?) in
                       let full_dfn = maybePiTerm(tvs, TypedTerm(new_dfn, ty, termAnn new_dfn)) in
                       insertAQualifierMap(ops, q, id, info << {dfn = full_dfn}))
                spc.ops (map (fn Fold qid -> qid) rls)
    in
    spc << {ops = ops}

  op [a] findSubTerm (f: MSTerm -> Option a) (tm: MSTerm): Option a =
    foldSubTerms (fn (stm, r) ->
                    case r of
                      | Some _ -> r
                      | None -> f stm)
      None tm

  op SpecTransform.specializeSpecCA (spc: Spec): Spec =
    specializeSpec constantConstructorArg spc

  op constructorTerm? (spc: Spec) (tm: MSTerm): Bool =
    some?(constructorTerm spc tm)

  op constructorTerm (spc: Spec) (tm: MSTerm): Option(String * QualifiedIds) =
    case tm of
      | Fun(Embed (id, _), _, _) -> Some(id, [])
      | Apply(Fun(Embed(id, _), _, _), _, _) -> Some(id, [])
      | Fun(Op(qid, _), _, _) ->
        (case findTheOp(spc, qid) of
         | None -> None
         | Some info ->
         let (_, _, dfn) = unpackFirstTerm info.dfn in
         case constructorTerm spc dfn of
         | None -> None
         | Some(id, qids) -> Some(id, qid :: qids))
      | _ -> None

  op mkUniqueName(Qualified(q,id), str: String, spc: Spec): QualifiedId =
    let base_id = id^"__"^str in
    let def findUnused i =
          let qid = Qualified(q, if i = 0 then base_id else base_id^show i) in
          case findTheOp(spc, qid) of
            | None -> qid
            | Some _ -> let _ = writeLine("Already have "^show qid) in
              findUnused(i+1)
    in
    findUnused 0

  op constantConstructorArg (spc: Spec) (tm: MSTerm): Option(MSTerm * QualifiedId * QualifiedIds * QualifiedIds) =
    case tm of
      | Apply(f as Fun(Op(qid, _), ty, _), arg, _ ) ->
        let args = termToList arg in
        (case findLeftmost (constructorTerm? spc) args of
         | Some stm ->
           let Some(constr_id, rw_qids) = constructorTerm spc stm in
           let proto_args = tabulate(length args,
                                     fn i -> let arg = args@i in
                                             if arg = stm then stm
                                               else mkVar("xx"^show i, inferType(spc, arg)))
           in
           let proto_tm = mkApply(f, mkTuple proto_args) in
           let _ = writeLine("Specializing "^printTerm proto_tm^"\n"^printTerm tm) in
           Some(proto_tm, mkUniqueName(qid, constr_id, spc), [qid], rw_qids)
         | None -> None)
      | _ -> None

end-spec
