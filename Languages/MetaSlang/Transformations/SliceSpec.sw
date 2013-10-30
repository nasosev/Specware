SliceSpec qualifying spec 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% New Slicing Code
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

import /Languages/MetaSlang/Specs/Environment
import /Languages/MetaSlang/CodeGen/LanguageMorphism
import /Library/Legacy/DataStructures/MergeSort   % to sort names when printing
import /Languages/MetaSlang/Transformations/Setf

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  Misc support
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op [a] union (xs : List a, ys : List a) : List a =
 foldl (fn (new, x) -> 
          if x in? ys then
            new
          else
            x |> new)
       ys
       xs

op executable? (info : OpInfo) : Bool =
 let (decls, defs)  = opInfoDeclsAndDefs info in
 case defs of
   | dfn :: _ -> ~ (nonExecutableTerm1? dfn)
   | _ -> false

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  ADT for op/type reachability
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Cohorts          = List Cohort
type Cohort           = | Interface      % the desired interface or API
                        | Implementation % used to implement the interface
                        | Assertion      % used in assertions, could define runtime asserts
                        | Context        % used in relevant context, could define monitors
                        | Ignored        

type Status           = | Primitive 
                        | API 
                        | Handwritten 
                        | Macro 
                        | Defined 
                        | Undefined 
                        | Missing 
                        | Misc String

type TheoremName      = PropertyName

type Locations        = List Location
type Location         = | Root 
                        | Op      {name : OpName,      pos: Position}
                        | Type    {name : TypeName,    pos: Position}
                        | Theorem {name : TheoremName, pos: Position}
                        | Unknown

op showLocation (location : Location) : String = 
 let
   def printLCB (line,column,byte) = show line ^ "." ^ show column 

   def showPos pos =
     case pos of 
       | Internal "no position"       -> ""
       | Internal x                   -> " " ^ x
       | String   (s,    left, right) -> " [in some string at : " ^ (printLCB left) ^ "-" ^ (printLCB right) ^ "]"
       | File     (file, left, right) -> " [see " ^ file ^ " : " ^ (printLCB left) ^ "-" ^ (printLCB right) ^ "]"

       | _ -> " at " ^ print pos
 in
 case location of
   | Root      -> "a root"
   | Op      x -> "in   op "    ^ pad (show x.name, 20) ^ (showPos x.pos)
   | Type    x -> "in type "    ^ pad (show x.name, 20) ^ (showPos x.pos)
   | Theorem x -> "in theorem " ^ pad (show x.name, 20) ^ (showPos x.pos)
   | Unknown   -> "at unknown location"

type ResolvedRefs     = List ResolvedRef
type ResolvedRef      = | Op      ResolvedOpRef
                        | Type    ResolvedTypeRef
                        | Theorem ResolvedTheorem

type ResolvedOpRef    = {name            : OpName,   
                         cohort          : Cohort,
                         contextual_type : MSType, % how it is used (as opposed to how it is defined)
                         locations       : Locations,
                         status          : Status}

type ResolvedTypeRef  = {name       : TypeName, 
                         cohort     : Cohort,
                         locations  : Locations,
                         status     : Status}

type ResolvedTheorem  = {name       : TheoremName, 
                         cohort     : Cohort,
                         element    : SpecElement,
                         status     : Status}

op empty_resolved_refs   : ResolvedRefs   = []

type PendingRefs      = List PendingRef
type PendingRef       = | Op      PendingOpRef
                        | Type    PendingTypeRef
                        | Theorem PendingTheorem

type PendingOpRef     = {name            : OpName,   
                         cohort          : Cohort,
                         contextual_type : MSType, % how it is used (as opposed to how it is defined)
                         location        : Location}

type PendingTypeRef   = {name     : TypeName, 
                         cohort   : Cohort,
                         location : Location}

type PendingTheorem  = {name    : TheoremName, 
                        cohort  : Cohort,
                        element : SpecElement,
                        status  : Status}

op pending.showName (pending : PendingRef) : String =
 case pending of
   | Op   oref -> show oref.name
   | Type tref -> show tref.name

type Slice = {ms_spec             : Spec, 
              lm_data             : LMData,
              oracular_ref_status : PendingRef * Slice -> Option Status,
              % code is simpler if pending and resolved refs are tracked separately
              % (as opposed to having a Pending/Resolved status)
              pending_refs        : PendingRefs,
              resolved_refs       : ResolvedRefs}

type Groups = List Group
type Group  = {cohort : Cohort,
               status : Status, 
               refs   : Ref ResolvedRefs}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op opsInSlice (slice : Slice) : OpNames =
 foldl (fn (names, ref) ->
          case ref of
            | Op oref -> oref.name |> names
            | _ -> names)
       []
       slice.resolved_refs

op typesInSlice (slice : Slice) : TypeNames =
 foldl (fn (names, ref) ->
          case ref of
            | Type tref -> tref.name |> names
            | _ -> names)
       []
       slice.resolved_refs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op pad (s : String, n : Nat)  : String =
  let len = length s in
  if len < n then
    let spaces = implode (repeat #\s n) in
    s ^ subFromTo (spaces, 0, n - len)
  else
    s

op showRef (ref : ResolvedRef) (warning? : Bool) : String =
 if warning? then
   case ref of
     | Op   oref -> " op "   ^ pad (show oref.name, 32) ^ "\t" ^ (showLocation (head oref.locations)) ^ " " ^ 
                    (foldl (fn (s, loc) -> s ^ "\n\t\t\t\t\t" ^ showLocation loc) "" (tail oref.locations))

     | Type tref -> " type " ^ pad (show tref.name, 32) ^ "\t" ^ (showLocation (head tref.locations)) ^ " " ^ 
                    (foldl (fn (s, loc) -> s ^ "\n\t\t\t\t\t" ^ showLocation loc) "" (tail tref.locations))
 else
   case ref of
     | Op   oref -> " op "   ^ show oref.name
     | Type tref -> " type " ^ show tref.name

op describeGroup (group : Group) : () =
 case (! group.refs) of
   | [] -> ()
   | refs ->
     let (needed?, cohort)  = case group.cohort of
                                | Interface      -> (true,  "These interface types and/or ops ")
                                | Implementation -> (true,  "These implementing types and/or ops ")
                                | Assertion      -> (false, "These types and/or ops in assertions ")
                                | Context        -> (false, "These types and/or ops in the relevant context ")
                                | Ignored        -> (false, "These ignored types and/or ops ")
     in
     let (warning?, status) = case group.status of
                                | Primitive   -> (false, "translate to primitive syntax: ")
                                | API         -> (false, "translate to an API: ")
                                | Handwritten -> (false, "translate to handwritten code: ")
                                | Macro       -> (false, "translate to macros: ")
                                | Defined     -> (false, "are defined: ")
                                | Undefined   -> (true,  "are undefined: ")
                                | Missing     -> (true,  "are missing: ")
                                | Misc msg    -> (false, msg)
     in
     let tref_lines = foldl (fn (lines, ref) ->
                               case ref of
                                 | Type tref -> (showRef ref warning?) |> lines
                                 | _ -> lines)
                            []
                            refs
     in
     let oref_lines = foldl (fn (lines, ref) ->
                               case ref of
                                 | Op oref -> (showRef ref warning?) |> lines
                                 | _ -> lines)
                            []
                            refs
     in
     let tref_lines = sortGT (String.>) tref_lines in
     let oref_lines = sortGT (String.>) oref_lines in
     let _ = writeLine ((if warning? then "WARNING: " else "") ^ cohort ^ status) in
     let _ = case tref_lines of 
               | [] -> ()
               | _ ->
                 let _ = writeLine "" in
                 app writeLine tref_lines
     in
     let _ = case oref_lines of 
               | [] -> ()
               | _ ->
                 let _ = writeLine "" in
                 app writeLine oref_lines
     in
     let _ = writeLine "" in

     ()

op describeSlice (msg : String, slice : Slice) : () =
 let
   def pad (str, n) =
     let m = length str in
     if m < n then
       str ^ implode (repeat #\s (n - m))
     else
       str

   def partition_refs (groups : Groups, ref : ResolvedRef) : Groups =
     case findLeftmost (fn (group : Group) ->
                          case ref of
                            | Op (oref : ResolvedOpRef) ->
                              group.cohort = oref.cohort && 
                              group.status = oref.status

                            | Type tref ->
                              group.cohort = tref.cohort && 
                              group.status = tref.status

                            | _ ->
                              false)
                       groups 
       of
       | Some group -> 
         let _  = (group.refs := (! group.refs) ++ [ref]) in
         groups
         
       | _ -> 
         %% Misc options will be added to end
         let (cohort, status) =
             case ref of 
               | Op      oref -> (oref.cohort, oref.status)
               | Type    tref -> (tref.cohort, tref.status)
               | Theorem aref -> (aref.cohort, aref.status)
         in
         let group : Group = {cohort = cohort,
                              status = status,
                              refs   = Ref [ref]}
         in
         groups ++ [group]

 in
 let cohorts     = [Interface, Implementation, Assertion, Context, Ignored]          in
 let status_list = [Defined, Handwritten, API, Macro, Primitive, Undefined, Missing] in
 let groups      = foldl (fn (groups, cohort) -> 
                            foldl (fn (groups, status) ->
                                     let group = {cohort = cohort,
                                                  status = status, 
                                                  refs   = Ref []}
                                     in
                                     groups <| group)
                                  groups
                                  status_list)
                         []
                         cohorts
 in
 let groups = foldl partition_refs groups slice.resolved_refs in

 let _ = writeLine ("") in
 let _ = writeLine ("Slice: " ^ msg) in
 let _ = writeLine ("") in

 let _ = case slice.pending_refs of
           | [] -> ()
           | pendings ->
             let _ = writeLine "--------------------" in
             let _ = app (fn pending -> writeLine ("pending type: " ^ showName pending)) pendings in
             let _ = writeLine "--------------------" in
             ()
 in

 let _ = app describeGroup groups in
 ()
 
op resolve_ref (slice   : Slice, 
                pending : PendingRef,
                status  : Status)
 : ResolvedRefs =
 let
   def names_match? (Qualified (xq, xid), Qualified (yq, yid)) =
     %% could have Nat32 and Nat.Nat32 -- sigh
     xid = yid &&
     (xq = yq || xq = UnQualified || yq = UnQualified)

   def cohort_number cohort =
     case cohort of
       | Interface      -> 1
       | Implementation -> 2
       | Assertion      -> 3
       | Context        -> 4

   def earlier_cohort? (c1, c2) =
     (cohort_number c1) < (cohort_number c2)
 in
 let resolved_refs = slice.resolved_refs in
 case pending of
   | Op oref ->
     (case splitAtLeftmost (fn resolved -> 
                              case resolved of 
                                | Op resolved -> 
                                  names_match? (resolved.name, oref.name) && 
                                  equalType? (resolved.contextual_type, oref.contextual_type) &&
                                  resolved.status = status
                                | _ -> false)
                           resolved_refs 
       of
        | Some (x, Op old, y) -> 
          let cohort = 
              if earlier_cohort? (oref.cohort, old.cohort) then
                oref.cohort
              else
                old.cohort
          in
          let resolved_ref =
              Op {name            = oref.name, 
                  cohort          = cohort,
                  contextual_type = oref.contextual_type,
                  locations       = old.locations <| oref.location,
                  status          = status} 
          in
          x ++ [resolved_ref] ++ y

        | _ -> 
          let resolved_ref =
              Op {name            = oref.name, 
                  cohort          = oref.cohort,
                  contextual_type = oref.contextual_type, 
                  locations       = [oref.location],
                  status          = status} 
          in
          resolved_ref |> resolved_refs)

   | Type tref ->
     (case splitAtLeftmost (fn resolved -> 
                              case resolved of 
                                | Type resolved -> 
                                  names_match? (resolved.name, tref.name) &&
                                  resolved.status = status
                                | _ -> false)
                           resolved_refs 
       of
        | Some (x, Type old, y) ->
          let cohort = 
              if earlier_cohort? (tref.cohort, old.cohort) then
                tref.cohort
              else
                old.cohort
          in
          let resolved_ref =
               Type {name      = tref.name, 
                     cohort    = cohort,
                     locations = old.locations <| tref.location,
                     status    = status} 
          in
          x ++ [resolved_ref] ++ y
        | _ -> 
          let resolved_ref =
              Type {name      = tref.name, 
                    cohort    = tref.cohort,
                    locations = [tref.location],
                    status    = status} 
          in
          resolved_ref |> resolved_refs)

   | Theorem (tref : PendingTheorem) ->
     let resolved_ref = Theorem {name    = tref.name,
                                 cohort  = tref.cohort,
                                 element = tref.element,
                                 status  = status} 
     in
     resolved_ref |> resolved_refs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  Chase referenced types and ops to fixpoint
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op extend_cohort_for_ref (cohort       : Cohort)
                         (pending_refs : PendingRefs)
                         (op_status    : OpInfo   -> Status)
                         (type_status  : TypeInfo -> Status)
                         (slice        : Slice, 
                          pending_ref  : PendingRef)
 : Slice =
 let
   def matches_op_ref pending_op_ref (resolved_ref : ResolvedRef) =
     case resolved_ref of
       | Op resolved_op_ref -> 
         resolved_op_ref.name = pending_op_ref.name
       | _ -> 
         false

   def matches_type_ref (pending_type_ref : PendingTypeRef) (resolved : ResolvedRef) =
     case resolved of
       | Type resolved_type_ref ->
         resolved_type_ref.name = pending_type_ref.name
       | _ -> 
         false

   def add_pending_ref resolved_refs (pendings, pending) =
     case pending of
       | Op (pending_op_ref : PendingOpRef) ->
         (case findLeftmost (matches_op_ref pending_op_ref) resolved_refs of
            | Some _ -> 
              pendings
            | _ -> 
              if pending in? pendings then
                % it's already in the queue to be processed
                pendings
              else
                pending |> pendings)
       | Type (pending_type_ref : PendingTypeRef) ->
         (case findLeftmost (matches_type_ref pending_type_ref) resolved_refs of
            | Some _ -> 
              pendings
            | _ -> 
              if pending in? pendings then
                % it's already in the queue to be processed
                pendings
              else
                pending |> pendings)

    %% 
    def subtype_cohort cohort =
      case cohort of
        | Context -> Context
        | _ -> Assertion

 in
 case slice.oracular_ref_status (pending_ref, slice) of
   | Some status ->
     let new_resolved_refs = resolve_ref (slice, pending_ref, status) in
     slice << {resolved_refs = new_resolved_refs}
   | _ ->
     case pending_ref of
       | Op oref ->
         (case findTheOp (slice.ms_spec, oref.name) of
            | Some info ->
              let status            = op_status info                               in
              let new_resolved_refs = resolve_ref (slice, pending_ref, status)     in
              let op_name           = primaryOpName info                           in
              let new_pending_refs  = foldl (add_pending_ref new_resolved_refs)
                                            [] 
                                            (pendingRefsInTerm (info.dfn, cohort, op_name))
              in
              let new_pending_refs  = union (new_pending_refs, slice.pending_refs) in
              slice << {resolved_refs = new_resolved_refs,
                        pending_refs  = new_pending_refs}
            | _ ->
              let new_resolved_refs = resolve_ref (slice, pending_ref, Missing) in
              slice << {resolved_refs = new_resolved_refs})

       | Type tref ->
         (case findTheType (slice.ms_spec, tref.name) of
            | Some info ->
              let (pending_ref, status) =
                  case info.dfn of
                    | Subtype (t1, pred, _) ->
                      let cohort      = subtype_cohort tref.cohort       in
                      let pending_ref = Type (tref << {cohort = cohort}) in
                      (pending_ref, Defined)
                    | _ ->
                      (pending_ref, type_status info)
              in
              let new_resolved_refs = resolve_ref (slice, pending_ref, status) in
              let type_name         = primaryTypeName info                     in
              let new_pending_refs  = foldl (add_pending_ref new_resolved_refs)
                                            [] 
                                            (pendingRefsInType (info.dfn, cohort, type_name))
              in
              let new_pending_refs   = union (new_pending_refs, slice.pending_refs) in
              slice << {resolved_refs = new_resolved_refs,
                        pending_refs  = new_pending_refs}
            | _ ->
              let new_resolved_refs = resolve_ref (slice, pending_ref, Missing) in
              slice << {resolved_refs = new_resolved_refs})
       | Theorem tref ->
         let (Property (_, theorem_name, _, formula, _)) = tref.element in
         % let _ = writeLine("Resolving theorem " ^ show theorem_name) in
         let new_resolved_refs = resolve_ref (slice, pending_ref, Defined) in
         let new_pending_refs  = foldl (add_pending_ref new_resolved_refs)
                                       [] 
                                       (pendingRefsInTerm (formula, cohort, theorem_name))
         in
         let new_pending_refs  = union (new_pending_refs, slice.pending_refs) in
         slice << {resolved_refs = new_resolved_refs,
                   pending_refs  = new_pending_refs}


op pendingRefsInTerm (term : MSTerm, cohort : Cohort, parent_op_name : OpName) : PendingRefs =
 foldTerm (fn refs -> fn tm ->
             case tm of
               | Fun (Op (qid,_),_,pos) ->
                 let ref = 
                     Op {name            = qid,
                         cohort          = cohort,
                         contextual_type = Any noPos, 
                         location        = Op {name = parent_op_name, pos = pos}}
                 in
                 ref |> refs
               | _ -> refs,
           fn refs -> fn typ ->
             case typ of
               | Base (qid, _, pos) ->
                 let ref = 
                     Type {name            = qid,
                           cohort          = cohort,
                           location        = Op {name = parent_op_name, pos = pos}}
                 in
                 ref |> refs
               | _ -> refs,
           fn refs -> fn _ -> refs)
         [] 
         term

op pendingRefsInType (typ : MSType, cohort : Cohort, parent_type_name : TypeName) : PendingRefs =
 foldType (fn refs -> fn tm ->
             case tm of
               | Fun (Op (qid,_),_,pos) ->
                 let ref = 
                     Op {name            = qid,
                         cohort          = cohort,
                         contextual_type = Any noPos, 
                         location        = Type {name = parent_type_name, pos = pos}}
                 in
                 ref |> refs
               | _ -> refs,
           fn refs -> fn typ ->
             case typ of
               | Base (qid, _, pos) ->
                 let ref = 
                     Type {name      = qid,
                           cohort    = cohort,
                           location  = Type {name = parent_type_name, pos = pos}}
                 in
                 ref |> refs
               | _ -> refs,
           fn refs -> fn _ -> refs)
         [] 
         typ

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op extend_cohort (cohort : Cohort) (s0 : Slice) : Slice =
 let pending_refs = s0.pending_refs           in
 let s1           = s0 << {pending_refs = []} in
 let 
   def op_status   info = if executable? info     then Defined   else Undefined
   def type_status info = if anyType?    info.dfn then Undefined else Defined
 in
 foldl (extend_cohort_for_ref cohort pending_refs op_status type_status)
       s1
       pending_refs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op cohort_closure (cohort : Cohort) (slice : Slice) : Slice =
 let
   def aux slice =
     case slice.pending_refs of
       | [] ->  
         slice
       | _ ->
         aux (extend_cohort cohort slice)
 in
 let slice = aux slice                         in
 let slice = add_linking_theorems cohort slice in
 case slice.pending_refs of
   | [] -> slice
   | _ -> cohort_closure cohort slice

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op term_mentions? (term : MSTerm) (names : OpNames) : Bool =
 foldTerm (fn mentions?-> fn tm ->
             case tm of
               | Fun (Op (name,_),_,pos) | name in? names -> true
               | _ -> mentions?,
           fn mentions? -> fn _ -> mentions?,
           fn mentions? -> fn _ -> mentions?)
         false
         term

op getLinkingTheorems (spc : Spec) : SpecElements =
 %% could be others, e.g. axioms for property maintenance
 let entries = findSetfEntries spc in
 map (fn entry -> entry.element) entries

op add_linking_theorems (cohort : Cohort) (slice : Slice) : Slice =
 let resolved_elements = foldl (fn (elements, resolved_ref) ->
                                  case resolved_ref of
                                    | Theorem tref -> elements <| tref.element
                                    | _ -> elements)
                               []
                               slice.resolved_refs
 in
 let ops_in_slice      = opsInSlice         slice         in
 let linking_theorems  = getLinkingTheorems slice.ms_spec in
 let pending_theorem_refs =
     foldl (fn (pending_refs, element) ->
              case element of
                | Property (_, name, _, formula, _) ->
                  if term_mentions? formula ops_in_slice then
                    if element in? resolved_elements then
                      pending_refs
                    else
                      % let _ = writeLine("Adding theorem " ^ show name) in
                      let pending_ref = Theorem {name    = name,
                                                 cohort  = cohort,
                                                 element = element,
                                                 status  = Defined}
                      in
                      pending_refs <| pending_ref
                  else
                    pending_refs
                | _ ->
                    pending_refs)
            []
            linking_theorems
 in
 slice << {pending_refs = slice.pending_refs ++ pending_theorem_refs}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op implementation_closure (slice : Slice) : Slice = cohort_closure Implementation slice
op assertion_closure      (slice : Slice) : Slice = cohort_closure Assertion      slice
op context_closure        (slice : Slice) : Slice = slice

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op executionSlice (ms_spec    : Spec,
                   get_lms    : Spec -> LanguageMorphisms,
                   oracle     : PendingRef * Slice -> Option Status,
                   root_ops   : OpNames, 
                   root_types : TypeNames) 
 : Slice =
 let lms          = get_lms     ms_spec in
 let lm_data      = make_LMData lms     in
 let pending_refs = (map (fn name ->
                            Op {name            = name, 
                                cohort          = Interface,
                                contextual_type = Any noPos, 
                                location        = Root})
                         root_ops)
                    ++
                    (map (fn name -> 
                            Type {name     = name, 
                                  cohort   = Interface,
                                  location = Root})
                         root_types)
 in
 let s0 = {ms_spec             = ms_spec,
           lm_data             = lm_data,
           oracular_ref_status = oracle,
           pending_refs        = pending_refs,
           resolved_refs       = empty_resolved_refs}
 in
 let s1 = implementation_closure s0 in
 let s2 = assertion_closure      s1 in
 let s3 = context_closure        s2 in
 s3

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end-spec
