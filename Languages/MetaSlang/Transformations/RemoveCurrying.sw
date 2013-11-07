%% Replace all curried functions by functions that take products
%%  op f: A -> B -> C
%% -->
%%  op f_1_1: A * B -> C
%%
%% Calls f x y --> f_1_1(x,y), f x --> (fn y -> f_1_1(x,y))
%%
%%  op f: A * (B -> C -> D) -> E
%% -->
%%  op f_2: A * (B * C -> D) -> E
%%
%%  fn x -> (fn y -> e(x,y))
%% -->
%%  fn (x,y) -> e(x,y)
%%
%%  fn x -> (e: (A -> B))
%% -->
%%  fn (x,y) e y
%%
%% Assume that pattern matching has been transformed away


RemoveCurrying qualifying spec

import CurryUtils
import /Languages/SpecCalculus/AbstractSyntax/CheckSpec

op SpecTransform.removeCurrying (spc : Spec) : Spec =
 let spc = add_uncurried_ops   spc in
 let spc = remove_curried_refs spc in
 spc

op remove_curried_refs (spc : Spec) : Spec =
 let new_ops = 
     mapOpInfos (fn old_info ->
                   if definedOpInfo? old_info then
                     %% TODO: Handle multiple defs??
                     let (old_tvs, old_typ, old_tm) = unpackFirstOpDef old_info in
                     let new_tm       = uncurry_term (old_tm,  spc, false) in
                     let (_, new_typ) = uncurry_type (old_typ, spc, false) in
                     let new_dfn = maybePiTerm (old_tvs, TypedTerm (new_tm, new_typ, noPos)) in
                     old_info << {dfn = new_dfn}
                   else
                     old_info)
                spc.ops
 in
 let new_types = 
     mapTypeInfos (fn old_info ->
                     if definedTypeInfo? old_info then
                       %% TODO: Handle multiple defs??
                       let (old_tvs, old_typ) = unpackFirstTypeDef old_info in
                       let new_typ = (uncurry_type (old_typ, spc, false)).2 in
                       let new_dfn = maybePiType (old_tvs, new_typ) in
                       old_info << {dfn = new_dfn}
                     else
                       old_info)
                  spc.types
 in
 setOps (setTypes (spc, new_types), new_ops)

op mkTypedApply (f : MSTerm, arg : MSTerm, spc : Spec) : MSTerm =
 let typed_f = case f of
                 | Fun _ -> f
                 | Var _ -> f
                 | TypedTerm _ -> f
                 | _ -> 
                   let f_type  = termTypeEnv (spc, f) in
                   TypedTerm (f, f_type, noPos) 
 in
 mkApply (typed_f, arg)

op add_uncurried_ops (spc : Spec) : Spec =
 let
   def mkNewApply (f, args) = 
     case args of
       | [] -> f
       | arg :: args ->
         mkNewApply (mkTypedApply (f, arg, spc), args)

   def curried_name name =
     let Some info = findTheOp (spc, name) in
     let Qualified(q,id) = name in
     let (old_decls, old_defs) = opInfoDeclsAndDefs info in
     case (old_defs ++ old_decls) of
       | old_dfn :: _ ->
         (let (old_tvs, old_type, old_tm) = unpackFirstTerm old_dfn in
          case new_uncurried_op (spc, id, old_type) of
            | Some (new_id, curry_level, new_type) -> Some (mkQualifiedId (q, new_id))
            | _ -> None)
       | _ ->
         None

   def add_uncurry_elements elts =
     foldl (fn (old_elts, old_elt) ->
              case old_elt of

                | Import (s_tm, imported_spec, sub_elts, _) ->
                  let new_elts = add_uncurry_elements sub_elts in
                  let new_elt  = Import (s_tm, imported_spec, new_elts, noPos) in
                  let new_elts = old_elts <| new_elt in
                  new_elts

                | Op (name, def?, _) ->  % true means decl includes def
                  (case curried_name name of
                     | Some new_name ->
                       let new_elt = Op (new_name, def?, noPos) in
                       old_elts <| old_elt <| new_elt
                     | _ ->
                       old_elts <| old_elt)

                | OpDef (name, x, y, a) ->
                  (case curried_name name of
                     | Some new_name ->
                       let new_elt = OpDef (new_name, x, y, noPos) in
                       old_elts <| old_elt <| new_elt
                     | _ ->
                       old_elts <| old_elt)
                | _ -> 
                  old_elts <| old_elt)
           []
           elts
 in
 let new_ops = 
     foldOpInfos (fn (info, ops) ->
                    let Qualified(q,id) = primaryOpName info in
                    let (old_decls, old_defs) = opInfoDeclsAndDefs info in
                    case old_defs ++ old_decls of
                      | old_dfn :: _ ->
                        (let (old_tvs, old_type, old_tm) = unpackFirstTerm old_dfn in
                         case new_uncurried_op (spc, id, old_type) of
                           
                           | Some (new_id, curry_level, new_type) ->
                             let new_name = Qualified (q, new_id) in
                             let new_arg_types = 
                                 case new_type of
                                   | Arrow (Product (fields, _), _, _) -> 
                                     map (fn (_, typ) -> typ) fields
                                   | _ -> 
                                     [new_type]
                             in
                             let new_vars      = mk_new_vars (new_arg_types, [], spc) in
                             let new_pvars     = map mkVarPat new_vars                in
                             let new_tvars     = map mkVar    new_vars                in
                             let new_pat       = mkTuplePat   new_pvars               in
                             let old_tm        = TypedTerm (old_tm, old_type, noPos)  in
                             let new_body      = mkNewApply (old_tm, new_tvars)       in
                             let new_rule      = (new_pat, trueTerm, new_body)        in
                             let new_lambda    = Lambda ([new_rule], noPos)           in
                             let (_, new_type) = uncurry_type (old_type, spc, true)   in 
                             let new_dfn       = maybePiTerm (old_tvs, TypedTerm (new_lambda, new_type, noPos)) in
                             insertAQualifierMap (ops, q, new_id,
                                                  info << {names = [new_name],
                                                           dfn   = new_dfn})
                          | _ -> ops)
                      | _ -> ops)
                 spc.ops
                 spc.ops
 in
 let new_elts = add_uncurry_elements spc.elements in
 spc << {ops        = new_ops, 
         elements   = new_elts}

op new_uncurried_op (spc      : Spec, 
                     old_id   : Id, 
                     old_type : MSType) 
 : Option (Id * Nat * MSType) =
 let (curried?, new_type) = uncurry_type (old_type, spc, true) in
 if ~curried? then
   None
 else
   let curry_level = curryShapeNum (spc, old_type)     in
   let new_name    = unCurryName (old_id, curry_level) in
   Some (new_name, curry_level, new_type)

%op  unCurryDef: MSTerm * Nat -> MSTerm
%def unCurryDef (tm, curryshape) =

op curried_fun_and_args (term : MSTerm) : Option (MSTerm * MSTerms) =
 let
   def aux (tm, i,  args) = 
     case tm of
       | Fun   _           -> Some (tm, args)
       | Apply (t1, t2, _) -> aux (t1, i + 1, t2::args)
       | _ -> None
 in
 aux (term, 0, [])

op uncurry_pattern (pat : MSPattern, spc : Spec) : MSPattern =
  case pat of
    | RestrictedPat(pat, tm, ann) -> RestrictedPat(pat, uncurry_term(tm, spc, false), ann)
    | _ -> pat  %%FIXME: Add more cases!

op uncurry_term (term : MSTerm, spc : Spec, toplevel_dfn? : Bool) : MSTerm =
 %% if toplevel_dfn? is true we wish to flatten nested lambdas, otherwise not
 let
   def uncurry_term_rec tm = 
     uncurry_term (tm, spc, false)

   def uncurry_apply (f, args) =
     let f_type      = termTypeEnv   (spc, f)      in
     let curry_level = curryShapeNum (spc, f_type) in
     let new_f =
         if curry_level > 1 && curry_level = length args then
           convert_fun (f, curry_level, spc) 
         else
           f
     in
     let new_arg = mkTuple (map uncurry_term_rec args) in
     mkTypedApply (new_f, new_arg, spc)
         
 in
 case term of

   | Apply (t1, t2, a) ->
     (case curried_fun_and_args term  of
        | Some (f, args) -> 
          uncurry_apply (f, args)
        | _ ->
          let new_t1 = uncurry_term_rec t1 in
          let new_t2 = uncurry_term_rec t2 in
          let new_tm = Apply (new_t1, new_t2, noPos) in
          new_tm)

   | Record (old_row, a) ->
     let new_row = map (fn (id, tm) -> 
                          (id, uncurry_term_rec tm)) 
                       old_row 
     in
     if new_row = old_row then 
       term
     else 
       Record (new_row, a)

   | Var ((id, old_type), a) ->
     let (curried?, new_type) = uncurry_type (old_type, spc, false) in
     if ~ curried? then
       term
     else 
       Var ((id, new_type), a)

   | Fun (Op (Qualified (old_q, old_id), fixity), old_type, a) ->
     (case new_uncurried_op (spc, old_id, old_type) of

        | Some (new_id, curry_level, new_type) -> 
          let new_name = Qualified (old_q, new_id) in
          Fun (Op (new_name, fixity), new_type, a) 

        | _ -> term)

     %% Assume multiple rules have been transformed away and predicate is true
   | Lambda ([(pat, _, old_body)], _)  ->
     if toplevel_dfn? then
       let body_type = termTypeEnv (spc, old_body) in
       let pat = uncurry_pattern(pat, spc) in
       if arrow? (spc, body_type) then
         flatten_lambda ([pat], old_body, body_type, spc) 
       else
         let new_body = uncurry_term_rec old_body in
         if new_body = old_body then
           term
         else 
           mkLambda (pat, new_body)
     else
       let new_body = uncurry_term_rec old_body in
       if new_body = old_body then
         term
       else 
         mkLambda (pat, new_body)

   | Lambda (old_rules, a) ->
     let new_rules = map (fn (old_pat, old_cond, old_body) -> 
                            let new_cond = uncurry_term_rec old_cond in
                            let new_body = uncurry_term_rec old_body in
                            (old_pat, new_cond, new_body))
                         old_rules
     in 
     Lambda (new_rules, a)

   | Let (old_decls, old_body, a)  ->
     let new_decls = map (fn (pat, tm) -> 
                            (pat, uncurry_term_rec tm))
                         old_decls
     in
     let new_body = uncurry_term_rec old_body in
     if new_body = old_body && new_decls = old_decls then
       term
     else
       Let (new_decls, new_body, a)

   | LetRec (old_decls, old_body, a) ->
     let new_decls = map (fn (pat, tm) -> 
                            (pat, uncurry_term_rec tm))
                         old_decls
     in
     let new_body = uncurry_term_rec old_body in
     if new_body = old_body && new_decls = old_decls then
       term
     else 
       LetRec (new_decls, new_body, a)

   | The (var, old_tm, a) ->
     let new_tm = uncurry_term_rec old_tm in
     if new_tm = old_tm then
       term
     else
       The (var, new_tm, a)

   | IfThenElse (t1, t2, t3, a) ->
     let new_t1 = uncurry_term_rec t1 in
     let new_t2 = uncurry_term_rec t2 in
     let new_t3 = uncurry_term_rec t3 in
     if new_t1 = t1 && new_t2 = t2 && new_t3 = t3 then 
       term
     else 
       IfThenElse (new_t1, new_t2, new_t3, a)

   | Seq (                     terms, a) -> 
     Seq (map uncurry_term_rec terms, a)

   | Bind (binder, vars, term, a)  -> Bind(binder, vars, uncurry_term(term, spc, false), a)

   | TypedTerm(tm,ty,ann) -> 
     let (_,new_ty) = uncurry_type(ty,spc, false) in 
     TypedTerm(uncurry_term(tm,spc,false),new_ty,ann)

   | _ -> term

%% Todo: Better way to do this?
 % Open up the definition of a named type (wrapped in a call of Base),
 % unless it is a co-product (which can cause loops for users of this routine).  Does not recurse.
op unfoldBaseNoCoProduct (sp : Spec, ty : MSType) : MSType =
  case ty of
    | Base (qid, tys, a) ->
      (case findTheType (sp, qid) of
	 | None -> ty %TODO Should this be an error?
	 | Some info ->
	   if definedTypeInfo? info then
	     (let (tvs, ty_def) = unpackFirstTypeDef info in
               if length tvs ~= length tys
                 then (% writeLine("Type arg# mismatch: "^printType ty);
                       %% This can arise because of inadequacy of patternType on QuotientPat
                       ty_def)
               else if coproduct? ty_def then  %% Don't do it for coproducts
                 ty
               else 
                substType (zip (tvs, tys), ty_def))
	     else %Should this be an error?
	       ty)
    | _ -> ty  %TODO: signal an error

%% Returns transformed type and whether any change was made
%% Don't look inside type definitions except to follow arrows
%% (otherwise infinitely recursive)

op uncurry_type (typ : MSType, spc : Spec, toplevel_dfn? : Bool) : Bool * MSType =
 let
   def uncurry_rec s = 
     uncurry_type (s, spc, false)

   def uncurry_arrow (rng, accum_dom_types) =
     case stripSubtypes (spc, rng) of
       | Arrow (dom, rest_rng, _) ->
         let expanded_dom_types = accum_dom_types 
             % foldl (fn (dom_typ, dom_types) ->
             %         case productOpt (spc, dom_typ) of
             %           | Some fields -> dom_types ++ (map (fn (_, s) -> s) fields)
             %           | _ -> dom_types ++ [dom_typ])
             %       []
             %       accum_dom_types
         in
         let new_type = (uncurry_arrow (rest_rng, expanded_dom_types ++ [dom])).2 in
         (true, new_type)
       | _ ->
         let (changed?, new_rng)       = uncurry_rec rng                                in
         let (changed?, new_dom_types) = foldrPred uncurry_rec changed? accum_dom_types in
         let new_type                  = mkArrow (mkProduct new_dom_types, new_rng)     in
         (changed?, new_type)
 in
 case typ of

   | Subtype (old_parent, old_pred, a) ->
     let (changed?, new_parent) = uncurry_rec old_parent            in
     let new_pred               = uncurry_term (old_pred, spc, false)      in
     let new_type               = Subtype (new_parent, new_pred, a) in
     (changed?, new_type)

   | Arrow (dom, rng, _) ->
     if toplevel_dfn? then
       uncurry_arrow (rng, [dom])
     else
       (false, typ)

   | Product (old_fields, a) ->
     let (changed?, new_fields) = 
         foldrPred (fn (id, old_type) ->
                      let (changed?, new_type) = uncurry_rec old_type in
                      (changed?, (id, new_type))) 
                   false 
                   old_fields
     in 
     let new_type = Product (new_fields, a) in
     (changed?, new_type)

   | CoProduct (old_fields, a) ->
     let (changed?, new_fields) =
         foldrPred (fn (id, opt_type) ->
                      case opt_type of
                        | Some old_type ->
                          let (changed?, new_type) = uncurry_rec old_type in
                          (changed?, (id, Some new_type))
                        | _ -> 
                          (false, (id, None)))
                   false 
                   old_fields
     in 
     (changed?, CoProduct (new_fields, a))

   | Quotient (old_base, old_rel, a) ->
     let (changed?, new_base) = uncurry_rec old_base            in
     let new_rel              = uncurry_term (old_rel, spc, false)     in
     let new_type             = Quotient (new_base, new_rel, a) in
     (changed?, new_type)

   | Base(qid, args, ann) -> 
     let new_typ = unfoldBaseNoCoProduct(spc,typ) in 
     % This equalType? test prevents loops when unfolding did nothing 
     % (if that possible?  maybe for BaseType Bool?)
     if equalType?(typ,new_typ) then 
       (false, typ)
     else 
       uncurry_type(new_typ,spc,false)

   | _ -> 
     (false, typ)

op flatten_lambda (outer_pats : MSPatterns, 
                   body       : MSTerm, 
                   body_type  : MSType, 
                   spc        : Spec) 
 : MSTerm =
 case body of

   | Lambda ([(pat, _, body)], _) ->
     flatten_lambda (outer_pats ++ [pat], 
                     body, 
                     termTypeEnv (spc, body), 
                     spc)

   | _ ->
     case arrowOpt (spc, body_type) of

       | Some (dom, _) ->
         %% !!? If dom is a product should we flatten it? No, for the moment.
         let new_vars = mk_new_vars ([dom], 
                                     map (fn (id, _)-> id) (freeVars body), 
                                     spc)
         in
         let new_pvars = map mkVarPat new_vars                in
         let new_tvars = map mkVar    new_vars                in
         let new_pat   = mkTuplePat (outer_pats ++ new_pvars) in
         let new_body  = mkTypedApply (body, mkTuple new_tvars, spc) in
         let new_body  = uncurry_term (new_body, spc, true)         in
         mkLambda (new_pat, new_body) 

       | _ -> 
         let new_pat  = mkTuplePat outer_pats    in
         let new_body = uncurry_term (body, spc, false) in
         mkLambda (new_pat, new_body)

op var_name_pool : List String = ["x", "y", "z", "w", "l", "m", "n", "o", "p", "q", "r", "s"]

op mk_new_vars (types    : MSTypes, 
                used_ids : List Id, 
                spc      : Spec) 
 : MSVars =
 let
   def find_unused_name (types, used_ids, pool_id :: pool_ids) =
     case types of

       | [] -> []

       | old_type :: tail_types ->
         if pool_id in? used_ids then
           find_unused_name (types, used_ids, pool_ids)
         else 
           let new_type = (uncurry_type (old_type, spc, false)).2 in
           let new_var  = (pool_id, new_type) in
           let pool_ids = case pool_ids of
                            | [] -> [pool_id ^ "x"]
                            | _ -> pool_ids
           in
           new_var |> find_unused_name (tail_types, used_ids, pool_ids)
 in 
 find_unused_name (types, used_ids, var_name_pool)

op convert_fun (term        : MSTerm, 
                curry_level : Nat, 
                spc         : Spec) 
 : MSTerm =
 case term of

   | Fun (Op (Qualified (old_q, old_id), _), typ, _) ->
     let new_id   = unCurryName (old_id, curry_level) in
     let new_name = Qualified (old_q, new_id)         in
     let new_type = (uncurry_type (typ, spc, false)).2       in
     mkOp (new_name, new_type)

   | _ -> term

end-spec
