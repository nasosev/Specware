\subsection{Evalution of a Spec term in the Spec Calculus}

\begin{spec}
SpecCalc qualifying spec {
  import Signature 
  import URI/Utilities
  % import ../../../MetaSlang/Specs/Elaborate/TypeChecker
  import /Languages/MetaSlang/Specs/Elaborate/TypeChecker
\end{spec}

To evaluate a spec we deposit the declarations in a new spec
(evaluating any import terms along the way), elaborate the spec
and then qualify the resulting spec if the spec was given a name.

\begin{spec}
 def SpecCalc.evaluateSpec spec_elements = 
  %% TODO:  Figure out rules for adding import of Base.
  %%        For example, it should not be imported by specs that it imports.
  %%        And the user might want to suppress auto-import of it.
  %% let spec_elements = 
  %%     if dont_import_base? then
  %%      spec_elements
  %%     else
  %%      let base_path = ["Library","Base","Base"]    in
  %%      let base_uri    : SpecCalc.Term     Position = (URI (SpecPath_Relative base_path), pos0) in
  %%      let base_import : SpecCalc.SpecElem Position = (Import base_uri,                   pos0) in
  %%      let _ = toScreen ("\nAdding import of Base\n") in
  %%      cons(base_import, spec_elements)
  %% in
  {
    (pos_spec,TS,depURIs) <- evaluateSpecElems emptySpec spec_elements;
    elaborated_spec <- elaborateSpecM pos_spec;
    return (Spec elaborated_spec,TS,depURIs)
  }
\end{spec}

\begin{spec}
  op evaluateSpecElems : ASpec Position -> List (SpecElem Position)
                           -> Env (ASpec Position * TimeStamp * URI_Dependency)
  def evaluateSpecElems initialSpec specElems =
     foldM evaluateSpecElem (initialSpec,0,[]) specElems

  op evaluateSpecElem : (ASpec Position * TimeStamp * URI_Dependency)
                          -> SpecElem Position
                          -> Env (ASpec Position * TimeStamp * URI_Dependency)
  def evaluateSpecElem (spc,cTS,cDepURIs) (elem, _(* position *)) =
    case elem of
      | Import term -> {
            (value,iTS,depURIs) <- evaluateTermInfo term;
            (case value of
              | Spec impSpec ->
                 return (mergeImport ((term, impSpec), spc),
                         max(cTS,iTS), cDepURIs ++ depURIs)
                  %% return (extendImports spc impSpec) 
              | _ -> raise(Fail("Import not a spec")))
          }
      | Sort (name,(tyVars,optSort)) ->
          (case name of
            | Qualified (qualifier, id) ->
              return (addPSort ((qualifier, id, tyVars, optSort), 
                                spc),
                      cTS,cDepURIs))
      | Op (name,(fxty,srtScheme,optTerm)) ->
          (case name of
            | Qualified (qualifier, id) ->
              return (addPOp ((qualifier, id, fxty, srtScheme, optTerm), 
                              spc),
                      cTS,cDepURIs))
      | Claim (Axiom, name, tyVars, term) ->
          return (addAxiom ((name,tyVars,term), spc),
                  cTS,cDepURIs)
      | Claim (Theorem, name, tyVars, term) ->
          return (addTheorem ((name,tyVars,term), spc),
		  cTS,cDepURIs)
      | Claim (Conjecture, name, tyVars, term) ->
          return (addConjecture ((name,tyVars,term), spc),
		  cTS,cDepURIs)
      | Claim _ -> error "evaluateSpecElem: unsupported claim type"

 def mergeImport ((spec_term, imported_spec), spec_a) =
   let spec_b = addImport ((showTerm spec_term, imported_spec), spec_a) in
   let spec_c = setSorts (spec_b,
     foldriAQualifierMap
       (fn (imported_qualifier, 
            imported_id, 
            imported_sort_info, 
            combined_psorts) ->
              insertAQualifierMap (combined_psorts,
                                   imported_qualifier,
                                   imported_id,
                                   convertSortInfoToPSortInfo imported_sort_info))
     spec_b.sorts
     imported_spec.sorts)
   in
   let spec_d = setOps (spec_c,
     foldriAQualifierMap
       (fn (imported_qualifier, 
            imported_id, 
            imported_op_info, 
            combined_pops) ->
              insertAQualifierMap (combined_pops,
                                   imported_qualifier,
                                   imported_id,
                                   convertOpInfoToPOpInfo imported_op_info))
       spec_c.ops
       imported_spec.ops)
   in
     spec_d
\end{spec}

The following wraps the existing \verb+elaborateSpec+ in a monad until
such time as the current one can made monadic.

\begin{spec}
 op elaborateSpecM : PosSpec -> Env Spec
 def elaborateSpecM spc =
   {
     uri <- getCurrentURI;
     case elaboratePosSpec (spc, (uriToPath uri) ^ ".sw", true) of
       | Ok pos_spec -> return (convertPosSpecToSpec pos_spec)
       | Error msg   -> raise  (OldTypeCheck msg)
   }
\end{spec}

\begin{spec}
}
\end{spec}
