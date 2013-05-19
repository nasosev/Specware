%% This utility checks a spec for well-formedness.  It is available as
%% the Specware shell command 'checkspec'.
CheckSpec qualifying spec 

import ShowUtils
import /Languages/MetaSlang/Specs/AnnSpec
%% import /Languages/MetaSlang/Specs/Elaborate/TypeChecker

op specOkay? (success_msg : String) (failure_msg : String) (s : Spec) : Bool =
 %% case elaboratePosSpec(s, "") of  % TODO Stephen says this is not really the right thing to call.
 %%  | Errors errs -> let _ = writeLine( "Errors in spec:" ^ (anyToString errs)) in false
 %%  | Spec spc -> let _ = writeLine "No type checking error in spec." in
%should we use spc here?
  %% For every type info in the hash table, verify that there is a corresponding
  %% Type and/or TypeDef spec element.
  let bad_type_infos =
      foldTypeInfos (fn (info, failures) ->
                       let names = info.names in
                       if names = [] then
                         let _ = writeLine("ERROR: No names for type!") in %% TODO Print the position?  We can't print the name since there isn't one!
                         failures ++ [info]
                       else
                         let qid = primaryTypeName info in  %% TODO If there is more than one name, should we look up each one below?:
                         let _ = if (length names > 1) then writeLine("Warning: More than one name for type: " ^ show qid ^ ": " ^ showQIDs names) else () in
                         let typeElts = getTypeElements qid s.elements in
                         let typeDefElts = getTypeDefElements qid s.elements in
                         let typeCount    = length typeElts    in
                         let typeDefCount = length typeDefElts in
                         let _ = if typeCount    > 1 then writeLine("ERROR: " ^ show typeCount    ^ " declarations for type: " ^ show qid) else () in
                         let _ = if typeDefCount > 1 then writeLine("ERROR: " ^ show typeDefCount ^ " definitions for type: " ^ show qid) else () in
                         %% There must be at least one declaration or definition for the type:
                         let found? = (typeCount > 0 || typeDefCount > 0) in
                         %% There can't be more than one declaration or more than one definition for the type:
                         let okay? = (typeCount <= 1 && typeDefCount <= 1) in
                           if found? && okay? then
                             failures   %% TODO Make sure we return a failure for any of the errors above
                           else
                             failures ++ [info])
                    []
                    s.types
  in
  %% For every op info in the hash table, verify that there is a corresponding
  %% Op and/or OpDef spec element.
  let bad_op_infos =
      foldOpInfos (fn (info, failures) ->
                     let names = info.names in
                     if names = [] then
                       let _ = writeLine("ERROR: No names for op!") in %% TODO Print the position?  We can't print the name since there isn't one!
                       failures ++ [info]
                     else
                       let qid = primaryOpName info in  %% TODO If there is more than one name, should we look up each one below?:
                       let _ = if (length names = 0) then writeLine("ERROR: No names for op: " ^ show qid) else () in
                       let _ = if (length names > 1) then writeLine("Warning: More than one name for op: " ^ show qid ^ ": " ^ showQIDs names) else () in
                       let opElts = getOpElements qid s.elements in
                       let opDefElts = getOpDefElements qid s.elements in
                       let opCount    = length opElts    in
                       let opDefCount = length opDefElts in


                       %% What are the rules about ops?  %%TODO: Implement these checks.
                       %% You can have an OpDecl with not-defined-when-declared, followed by any number of OpDefs, numbered starting from 0
                         %% What does the body in the opInfo look like?
                         %%   If there are no defs, the body is Any (possibly wrapped in TypedTerm and/or Pi?).
                         %%   If there is exactly 1 def, the body is does not contain Any or And.
                         %%   If there is more than 1 def, the body is an And (possibly wrapped in Pi and maybe TypedTerm).
                       %% You can have an OpDecl with defined-when-declared, followed by any number of opDefs, numbered starting from 1
                         %% What does the body in the opInfo look like?  First, the body in the opInfo can never contains Any.
                         %%   If there is exactly 1 def, the body does not contain And.
                         %%   If there is more than 1 def, the body is an And (possibly wrapped in Pi and maybe TypedTerm).

                       let _ = if opCount = 0 then writeLine("ERROR: No declarations for op: " ^ show qid) else () in
                       let _ = if opCount > 1 then writeLine("ERROR: " ^ show opCount    ^ " declarations for op: " ^ show qid) else () in
                       %let _ = if opDefCount > 1 then writeLine("ERROR: " ^ show opDefCount ^ " definitions for op: " ^ show qid) else () in
                       let found? = (opElts ~= [] || opDefElts ~= []) in %% TODO Eventually, have this check for all the errors just above here.                       
                         if found? then
                           failures
                         else
                           failures ++ [info])
                  []
                  s.ops
  in
  %% For every op info in the hash table, verify that every op-reference 
  %% has a corresponding entry.
  %% TODO: types, op-refs withing types, etc.
  let
    def bad_ref? tm =
      case tm of
        | Fun (Op (qid, _), _, _) ->
          (case findTheOp (s, qid) of
             | Some _ -> false
             | _ -> true)
        | _ -> false
  in 
  let bad_op_infos2 =
      foldOpInfos (fn (info, failures) ->
                     if existsSubTerm bad_ref? info.dfn then
                       failures ++ [info]
                     else
                       failures)
                  []
                  s.ops
  in
  %% For every Type, TypeDef, Op, or OpDef in spec elements,
  %% verify that it refers to an entry in the appropriate hash table.
  let bad_elements =
      foldlSpecElements (fn (failures, elt) ->
                           case elt of
                             | Type    (qid, _) ->
                               (case findTheType (s, qid) of
                                  | Some _ -> failures
                                  | _ -> failures ++ [elt])
                             | TypeDef (qid, _) ->
                               (case findTheType (s, qid) of
                                  | Some _ -> failures
                                  | _ -> failures ++ [elt])
                             | Op      (qid, _, _) ->
                               (case findTheOp (s, qid) of
                                  | Some _ -> failures
                                  | _ -> failures ++ [elt])
                             | OpDef   (qid, _, _, _) ->
                               (case findTheOp (s, qid) of
                                  | Some _ -> failures
                                  | _ -> failures ++ [elt])
                             | _ -> failures)
                        []
                        s.elements
  in
  case (bad_type_infos, bad_op_infos, bad_elements) of
    | ([], [], []) -> 
      let _ = writeLine success_msg in
      false
    | _ ->
      let _ = writeLine (failure_msg) in
      let _ = app (fn info -> writeLine(" Type "       ^ printQualifiedId (primaryTypeName info))) bad_type_infos in
      let _ = app (fn info -> writeLine(" Op   "       ^ printQualifiedId (primaryOpName   info))) bad_op_infos   in
      let _ = app (fn info -> writeLine(" Op refs in " ^ printQualifiedId (primaryOpName   info))) bad_op_infos2  in
      let _ = app (fn elt  -> writeLine(" Elt  "      ^ anyToString elt))                         bad_elements    in
      true


%% Evaluate the given unit and print it to a file.
%% Returns a success flag.
op checkSpec (uid_str : String) : Boolean =
%let _ = writeLine "Checking spec." in
%let _ = writeLine ("uid_str:"^uid_str) in
case evaluateUnitId uid_str of
  | None -> let _ = writeLine("Error in checkspec: Unknown UID " ^ uid_str) in false
  | Some val ->
    case val of
    | Spec spc -> let _ = specOkay? "Spec is okay." "ERROR: Ill-formed spec." spc in true

% This is the top-level function for the checkspec command.
op evaluateCheckSpec (optional_argstring : Option String, lastUnitIdLoaded : Option String, homedir : String) : Option String = 
%  let _ = writeLine "Calling evaluateCheckSpec." in
%  let _ = writeLine ("The user's home directory: "^homedir) in
%  let _ = writeLine ("arg string: "^(case optional_argstring of Some str -> enquote str | None -> "No arg string supplied.")) in
%  let _ = writeLine ("Last unit ID: "^(case lastUnitIdLoaded of | Some str -> str | None ->  "No last uid processed.")) in
  case UIDStringFromArgString(optional_argstring, lastUnitIdLoaded, homedir) of
  | None -> None % fail and don't change *last-unit-Id-_loaded*
  | Some uid_str ->
    %% Check the spec and return a new value for *last-unit-Id-_loaded* if the spec was found:
    let success? = checkSpec uid_str in
    if success? then Some uid_str else None

end-spec