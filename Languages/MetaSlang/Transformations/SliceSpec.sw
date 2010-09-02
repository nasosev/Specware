SliceSpec qualifying
spec
import ../Specs/AnalyzeRecursion

type QualifierSet = AQualifierMap Bool

op emptySet: QualifierSet = emptyAQualifierMap

op in? (Qualified(q,id): QualifiedId, s: QualifierSet) infixl 20 : Bool =
  some?(findAQualifierMap(s, q, id) )

op nin?  (Qualified(q,id): QualifiedId, s: QualifierSet) infixl 20 : Bool =
  none?(findAQualifierMap(s, q, id) )

op <| (s: QualifierSet, Qualified(x, y): QualifiedId) infixl 25 : QualifierSet =
  insertAQualifierMap(s, x, y, true)

op addList(s: QualifierSet, l: QualifiedIds): QualifierSet =
  foldl (<|) s l

op [a] sliceAQualifierMap(m: AQualifierMap a, s: QualifierSet, pred: QualifiedId -> Bool): AQualifierMap a =
  mapiPartialAQualifierMap (fn (q, id, v) ->
                              let qid = Qualified(q, id) in
                              if qid in? s || pred qid
                                then Some v
                              else None)
    m

op scrubSpec(spc: Spec, op_set: QualifierSet, type_set: QualifierSet, base_spec: Spec): Spec =
  let def element_filter el =
        case el of
          | Sort(qid, _)     -> qid in? type_set
          | SortDef(qid, _)  -> qid in? type_set
          | Op(qid, _, _)    -> qid in? op_set
          | OpDef(qid, _, _) -> qid in? op_set
          | Property(_, _, _, formula, _) ->
            forall? (fn qid -> qid in? op_set || some?(findTheOp(base_spec, qid)))
              (opsInTerm formula)
              && forall? (fn qid -> qid in? type_set || some?(findTheSort(base_spec, qid)))
                   (typesInTerm formula)
          | _ -> true
  in
  spc <<
    {sorts = sliceAQualifierMap(spc.sorts, type_set, fn qid -> some?(findTheSort(base_spec, qid))),
     ops =   sliceAQualifierMap(spc.ops,     op_set, fn qid -> some?(findTheOp(base_spec, qid))),
     elements = filterSpecElements element_filter spc.elements}

op sliceSpec(spc: Spec, root_ops: QualifiedIds, root_types: QualifiedIds, ignore_subtypes?: Bool): Spec =
  let base_spec = SpecCalc.getBaseSpec() in
  let def newOpsInTerm(tm: MS.Term, newopids: QualifiedIds, op_set: QualifierSet): QualifiedIds =
        foldTerm (fn opids -> fn t ->
                    case t of
                      | Fun(Op(qid,_),_,_)
                          | qid nin? opids && qid nin? op_set && none?(findTheOp(base_spec, qid)) ->
                        qid :: opids
                      | _ -> opids,
                  fn result -> fn _ -> result,
                  fn result -> fn _ -> result)
          newopids tm
      def newOpsInType(ty: Sort, newopids: QualifiedIds, op_set: QualifierSet): QualifiedIds =
        foldSort (fn result -> fn t ->
                    case t of
                      | Fun(Op(qid,_),_,_) | qid nin? result -> qid::result
                      | _ -> result,
                  fn result -> fn _ -> result,
                  fn result -> fn _ -> result)
          newopids ty
      def newTypesInTerm(tm: MS.Term, newtypeids: QualifiedIds, type_set: QualifierSet): QualifiedIds =
        foldTerm (fn result -> fn _ -> result,
                  fn result -> fn t ->
                    case t of
                      | Base(qid,_,_)
                          | qid nin? result && qid nin? type_set && none?(findTheSort(base_spec, qid)) ->
                        qid :: result
                      | _ -> result,
                  fn result -> fn _ -> result)

          newtypeids tm
      def newTypesInType(ty: Sort, newtypeids: QualifiedIds, type_set: QualifierSet): QualifiedIds =
        foldSort (fn result -> fn _ -> result,
                  fn result -> fn t ->
                    case t of
                      | Base(qid,_,_) 
                          | qid nin? result && qid nin? type_set && none?(findTheSort(base_spec, qid)) ->
                        qid :: result
                      | _ -> result,
                  fn result -> fn _ -> result)

          newtypeids ty

      def iterateDeps(new_ops, new_types, op_set, type_set) =
        %let _ = writeLine("nts: "^anyToString new_ops) in
        if new_ops = [] && new_types = [] then (op_set, type_set)
        else
        let op_set = addList(op_set, new_ops) in
        let type_set = addList(type_set, new_types) in
        let new_ops1 = foldl (fn (newopids, qid) ->
                              case findTheOp(spc, qid) of
                                | Some opinfo -> newOpsInTerm(opinfo.dfn, newopids, op_set)
                                | None -> newopids)
                         [] new_ops
        in
        let new_ops2 = if ignore_subtypes? then new_ops1
                       else
                         foldl (fn (newopids, qid) ->
                              case findTheSort(spc, qid) of
                                | Some typeinfo -> newOpsInType(typeinfo.dfn, newopids, op_set)
                                | None -> newopids)
                           new_ops1 new_types
        in
        let new_types1 = foldl (fn (newtypeids, qid) ->
                              case findTheOp(spc, qid) of
                                | Some opinfo -> newTypesInTerm(opinfo.dfn, newtypeids, type_set)
                                | None -> newtypeids)
                         [] new_ops
        in
        let new_types2 = foldl (fn (newtypeids, qid) ->
                              case findTheSort(spc, qid) of
                                | Some typeinfo -> newTypesInType(typeinfo.dfn, newtypeids, type_set)
                                | None -> newtypeids)
                           new_types1 new_types
        in
        iterateDeps(new_ops2, new_types2, op_set, type_set)
    in
    let (op_set, type_set) = iterateDeps(root_ops, root_types, emptySet, emptySet) in
    let spc = scrubSpec(spc, op_set, type_set, base_spec) in
    % let _ = printSpec spc in
    spc

endspec