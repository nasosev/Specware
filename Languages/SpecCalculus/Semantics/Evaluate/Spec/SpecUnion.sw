% derived from SW4/Languages/MetaSlang/ADT/Specs/SpecUnion.sl, v1.3

SpecUnion qualifying spec {
 import ../../Environment  % foldM    
 import /Languages/MetaSlang/Specs/StandardSpec
 import /Library/Legacy/DataStructures/ListUtilities
 import Utilities % mergeSortInfo, mergeOpInfo

 op specUnion       : List Spec -> Env Spec
 op sortsUnion      : List Spec -> Env SortMap
 op opsUnion        : List Spec -> Env OpMap
 op propertiesUnion : List Spec -> Env Properties

 def specUnion specs =
  let merged_imports     = importsUnion    specs in
  %% let merged_local_ops   = localOpsUnion   specs in
  %% let merged_local_sorts = localSortsUnion specs in
  {
   merged_sorts  <- sortsUnion      specs;
   merged_ops    <- opsUnion        specs;
   merged_props  <- propertiesUnion specs;
   merged_spec   <- return {importInfo = {imports       = merged_imports,
					  importedSpec  = None,               % TODO: is this correct?
					  localOps      = emptyOpNames,    % merged_local_ops
					  localSorts    = emptySortNames}, % merged_local_sorts
			    sorts      = merged_sorts,
			    ops        = merged_ops,
			    properties = merged_props};
   return (compressDefs merged_spec)
  }

 %% TODO: The terms for the imports might not remain in a meaningful URI context -- relativize to new context
 def importsUnion specs =
  foldl (fn (spc, imports) -> listUnion (spc.importInfo.imports, imports))
        []
        specs

%%% def localSortsUnion specs =
%%%  foldl (fn (spc, local_sorts) -> listUnion (spc.importInfo.localSorts, local_sorts))
%%%        []
%%%        specs
%%%
%%% def localOpsUnion specs =
%%%  foldl (fn (spc, local_ops) -> listUnion (spc.importInfo.localOps, local_ops))
%%%        []
%%%        specs

 def sortsUnion specs =
  foldM unionSortMaps 
        emptySortMap 
        (List.foldl (fn (spc, sorts_list) -> cons (spc.sorts, sorts_list))
	            []
		    specs)

 def opsUnion specs = 
  foldM unionOpMaps 
        emptyOpMap
        (List.foldl (fn (spc, ops_list) -> cons (spc.ops, ops_list))
	            []
		    specs)

 def unionSortMaps old_sort_map new_sort_map =
   %% Jan 8, 2003: Fix for bug 23
   %% Assertion: If new_sort_map at a given name refers to an info, then it will
   %%            refer to the same info at all the aliases within that info.
   let 
      def augmentSortMap (new_qualifier, new_id, new_info, merged_sort_map) =
        let Qualified (primary_qualifier, primary_id) = hd (new_info.1) in
        if new_qualifier = primary_qualifier & new_id = primary_id then
          %% Assertion: We take this branch exactly once per new info.
          let optional_old_info = findAQualifierMap (merged_sort_map, new_qualifier, new_id) in
	  %% It would be better if emptySpec were somehow replaced with
	  %% a more informative spec for resolving equivalent sorts,
	  %% but its not obvious what spec(s) to pass in here.
	  %% Perhaps the entire spec union algorithm needs revision...
	  {merged_info <- mergeSortInfo emptySpec new_info optional_old_info noPos;
	   all_names <- return (merged_info.1);    % new and old names
	   foldM (fn merged_sort_map -> fn  Qualified(qualifier, id) ->
		  return (insertAQualifierMap (merged_sort_map, qualifier, id, merged_info)))
     	         merged_sort_map 
                 all_names}
	else
	  return merged_sort_map
   in
    foldOverQualifierMap augmentSortMap old_sort_map new_sort_map 

 def unionOpMaps old_op_map new_op_map =
   %% Jan 8, 2003: Fix for bug 23
   %% Assertion: If new_op_map at a given name refers to an info, then it will
   %%            refer to the same info at all the aliases within that info.
   let 
      def augmentOpMap (new_qualifier, new_id, new_info, merged_op_map) =
        let Qualified (primary_qualifier, primary_id) = hd (new_info.1) in
        if new_qualifier = primary_qualifier & new_id = primary_id then
          %% Assertion: We take this branch exactly once per new info.
          let optional_old_info = findAQualifierMap (merged_op_map, new_qualifier, new_id) in
	  %% It would be better if emptySpec were somehow replaced with
	  %% a more informative spec for resolving equivalent ops,
	  %% but its not obvious what spec(s) to pass in here.
	  %% Perhaps the entire spec union algorithm needs revision...
	  {merged_info <- mergeOpInfo emptySpec new_info optional_old_info noPos;
	   all_names <- return (merged_info.1);    % new and old
	   foldM (fn merged_op_map -> fn Qualified(qualifier, id) ->
		  return (insertAQualifierMap (merged_op_map, qualifier, id, merged_info)))
     	         merged_op_map 
                 all_names}
	else
	  return merged_op_map
   in
    foldOverQualifierMap augmentOpMap old_op_map new_op_map 

 %% TODO:  These might refer incorrectly into old specs
 %% TODO:  listUnion assumes = test on elements, we might want something smarter such as equivTerm?
 def propertiesUnion specs =
  return (foldl (fn (spc, props) -> listUnion (props, spc.properties))
	        []
	        specs)

}
