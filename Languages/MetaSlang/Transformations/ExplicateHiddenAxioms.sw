Prover qualifying spec
 import DefToAxiom
 import SortToAxiom
 import OpToAxiom

  op explicateHiddenAxioms: Spec -> Spec
  def explicateHiddenAxioms spc =
    let def axiomFromSortDef(qname,name,sortDecl,sortAxioms) = sortAxioms ++ axiomFromSortDefTop(spc,qname,name,sortDecl) in
    let def axiomFromOp(qname,name,decl,defAxioms) = defAxioms ++ axiomFromOpTop(spc,qname,name,decl) in
    %let def axiomFromProp(prop,props) = props ++ axiomFromPropTop(spc,prop) in
    let def mergeAxiomsByPos(oas, nas) =
      let def cmpGt(oax as (_, _, _, oat), nax as (_, _, _, nat)) =
        let old_pos:Position = termAnn(oat) in
	let new_pos = termAnn(nat) in
	case compare(old_pos, new_pos) of
	  | Greater -> false
	  | _ -> true in
      case (oas,nas) of
        | ([],nas) -> nas
        | (oas,[]) -> oas
        | (oa::oas,na::nas) ->
            if cmpGt(oa, na) then
              Cons(na, mergeAxiomsByPos(Cons(oa,oas),nas))
            else Cons(oa, mergeAxiomsByPos(oas,Cons(na,nas))) in
    let newSortAxioms = foldriAQualifierMap axiomFromSortDef [] spc.sorts in
    let newDefAxioms = foldriAQualifierMap axiomFromOp [] spc.ops in
    %let newPropAxioms = foldr axiomFromProp [] spc.properties in
    let newProperties = mergeAxiomsByPos(spc.properties, newSortAxioms) in
    let newProperties = mergeAxiomsByPos(newProperties, newDefAxioms) in
    %let newProperties = mergeAxiomsByPos(newProperties, newPropAxioms) in
    %%let _ = debug("explicateHidden") in 
    %simplifySpec((setProperties(spc, newProperties)))
    setProperties(spc, newProperties)

endspec
