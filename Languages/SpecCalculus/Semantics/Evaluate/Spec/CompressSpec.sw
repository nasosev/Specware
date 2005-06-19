SpecCalc qualifying spec 

 import EquivPreds

 %% compressDefs is called from many places

 op  compressDefs : Spec -> Spec
 def compressDefs spc =
   let new_sorts = foldriAQualifierMap 
                     (fn (q, id, old_info, revised_sorts) ->
		      case compressSortDefs spc old_info of
			| Some new_info -> insertAQualifierMap (revised_sorts, q, id, new_info)
			| _             -> revised_sorts)
		     spc.sorts
		     spc.sorts
   in
   let new_ops = foldriAQualifierMap 
                   (fn (q, id, old_info, revised_ops) ->
		    case compressOpDefs spc old_info of
		      | Some new_info -> insertAQualifierMap (revised_ops, q, id, new_info)
		      | _             -> revised_ops)
		   spc.ops
		   spc.ops
   in
   let new_spec =  spc << {sorts = new_sorts,
			   ops   = new_ops}
   in
   new_spec

 op  compressSortDefs : Spec -> SortInfo -> Option SortInfo 
 def compressSortDefs spc info =
   let (old_decls, old_defs) = sortInfoDeclsAndDefs info in
   case old_defs of
     | []  -> None
     | [_] -> None
     | _ ->
       let pos = sortAnn info.dfn in
       let (tvs, srt) = unpackFirstSortDef info in
       let tvs = map mkTyVar tvs in
       let xxx_defs = map (fn name -> mkBase (name, tvs)) info.names in 
       let new_defs = 
           foldl (fn (old_def, new_defs) ->
		  if (% given {A,B,C} = B
		      % drop that definition
		      % note: equalSort?, not equivSort?, because we don't want to drop true defs
		      (exists (fn new_def -> equalSort? (old_def, new_def)) xxx_defs) 
		      ||
		      % asuming Nats = List Nat,
		      % given {A,B,C} = List Nat
		      %   and {A,B,C} = Nats       
		      % keep just one version
		      (exists (fn new_def -> equivSort? spc false (old_def, new_def)) new_defs)) 
		    then
		      new_defs
		  else
		    cons (old_def, new_defs))
	         []
		 old_defs
       in
       let new_names = removeDuplicates info.names in
       let new_dfn   = maybeAndSort (old_decls ++ new_defs, pos) in
       Some (info << {names = new_names,
		      dfn   = new_dfn})
        
 op  compressOpDefs : Spec -> OpInfo -> Option OpInfo
 def compressOpDefs spc info =
   let (old_decls, old_defs) = opInfoDeclsAndDefs info in
   case (old_decls, old_defs) of
     | ([], [])  -> None
     | ([], [_]) -> None
     | ([_],[])  -> None
     | _ ->
       let pos = termAnn info.dfn in
       let new_decls =
           foldl (fn (old_decl, new_decls) ->
		  let old_sort = termSort old_decl in
		  if exists (fn new_decl -> 
			     let new_sort = termSort new_decl in
			     equivSort? spc false (old_sort, new_sort))
		            new_decls 
		    then
		      new_decls
		  else
		    cons (SortedTerm (Any noPos, old_sort, noPos),
			  new_decls))
	         []
		 (old_decls ++ old_defs)
       in
       let new_defs =
           foldl (fn (old_def, new_defs) ->
		  if exists (fn new_def -> equivTerm? spc (old_def, new_def)) new_defs then
		    new_defs
		  else
		    cons (old_def, new_defs))
	         []
		 old_defs
       in
       let new_names = removeDuplicates info.names in
       let new_dfn = maybeAndTerm (new_decls ++ new_defs, pos) in
       Some (info << {names = new_names,
		      dfn   = new_dfn})
	          

 op  complainIfAmbiguous : Spec -> Position -> Env Spec
 def complainIfAmbiguous spc pos =
   case auxComplainIfAmbiguous spc of
     | (Some spc, _) -> return spc
     | (_, Some msg) -> raise (SpecError (pos,msg))

 op  auxComplainIfAmbiguous : Spec -> (Option Spec) * (Option String)
 def auxComplainIfAmbiguous spc =
   let ambiguous_sorts = 
       foldriAQualifierMap (fn (_, _, info, ambiguous_sorts) ->
			    let (decls, defs) = sortInfoDeclsAndDefs info in
			    if length decls <= 1 && length defs <= 1 then
			      ambiguous_sorts
			    else
			      ListUtilities.insert (info, ambiguous_sorts))
                           []
			   spc.sorts
   in
   let bad_fixity_ops = 
       foldriAQualifierMap (fn (_, _, info, bad_ops) ->
			    case info.fixity of
			      | Error _ -> ListUtilities.insert (info, bad_ops)
			      | _ -> bad_ops)
                           []
			   spc.ops
   in
   let ambiguous_ops = 
       foldriAQualifierMap (fn (_, _, info, ambiguous_ops) ->
			    let (decls, defs) = opInfoDeclsAndDefs info in
			    case (decls, defs) of
			      | ([],  [])  -> ambiguous_ops
			      | ([],  [_]) -> ambiguous_ops
			      | ([_], [])  -> ambiguous_ops
			      | ([x], [y]) -> 
			        let xsort = termSort x in
				let ysort = termSort y in
			        if equivSort? spc false (xsort, ysort) then
				  ambiguous_ops
				else
				  ListUtilities.insert (info, ambiguous_ops)
			      | _ ->
			        ListUtilities.insert (info, ambiguous_ops))
                           []
			   spc.ops
   in
   if ambiguous_sorts = [] & bad_fixity_ops = [] & ambiguous_ops = [] then
     (Some spc, None)
   else
     let sort_msg = 
         case ambiguous_sorts of
	   | [] -> ""
	   | _ ->
	     (foldl (fn (sort_info, msg) ->
		     msg ^ (ppFormat (ppASortInfo sort_info)))
	            "\nAmbiguous types:\n"
		    ambiguous_sorts)
	     ^ "\n"
     in
     let fixity_msg = 
         case bad_fixity_ops of
	   | [] -> ""
	   | _ ->
	     (foldl (fn (opinfo, msg) ->
		     msg ^ (printAliases opinfo.names) ^ " : " ^ (ppFormat (ppFixity opinfo.fixity)))
	            "\nOps with multiple fixities:\n"
		    bad_fixity_ops)
     in
     let op_msg = 
         case ambiguous_ops of
	   | [] -> ""
	   | _ ->
	     (foldl (fn (opinfo, msg) ->
		     msg ^ (ppFormat (ppAOpInfo opinfo)))
	            "\nAmbiguous ops:\n"
		    ambiguous_ops)
     in
       (None, Some ("\n" ^ sort_msg ^ fixity_msg ^ op_msg ^ "\n"))

endspec
