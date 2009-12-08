%% what's the proper qualifier for this??
%% right now, just XML uses this
XML qualifying spec

  %% IMPORT AS LITTLE AS POSSIBLE 

  %% This file is imported by applications, so anything this imports
  %%  must be available to the application.
  %% In particular, avoid importing any internals of specware itself.

  type IdDescriptor   = String
  type QIdDescriptor  = String * String
  type TermDescriptor = String

  %% A term of type SortDescriptor will be accessible at runtime as the reflection of a sort
  %% that was otherwise only present at compile-time.
  type SortDescriptor = | Arrow        SortDescriptor * SortDescriptor
                        | Product      List (IdDescriptor * SortDescriptor)
                        | CoProduct    List (IdDescriptor * Option SortDescriptor)
                        | Quotient     SortDescriptor * TermDescriptor              
                        | Subsort      SortDescriptor * TermDescriptor              
                        | Base         QIdDescriptor * List SortDescriptor
                        | Boolean
                        | TyVar        
                        | MetaTyVar    
                        | Bottom

  def MakeArrowSortDescriptor     (x, y)      : SortDescriptor = Arrow      (x, y)
  def MakeProductSortDescriptor   fields      : SortDescriptor = Product    fields
  def MakeCoProductSortDescriptor fields      : SortDescriptor = CoProduct  fields
  def MakeQuotientSortDescriptor  (base, qq)  : SortDescriptor = Quotient   (base, qq)
  def MakeSubsortSortDescriptor   (base, pp)  : SortDescriptor = Subsort    (base, pp)
  def MakeBaseSortDescriptor      (q,id,args) : SortDescriptor = Base       ((q,id), args)
  def MakeBooleanSortDescriptor   ()          : SortDescriptor = Boolean    

  %% Does this belong here (for use by apps) or elsewhere (for use by just Specware itself) ?

  type SortDescriptorExpansionTable = List (SortDescriptor * SortDescriptor)

  def expand_SortDescriptor (sd : SortDescriptor, table : SortDescriptorExpansionTable) =
   let
      def aux sd =
	let possible_entry = findLeftmost (fn (x,_) -> x = sd) table in
	case possible_entry of
	  | None -> sd
	  | Some (_, expansion) ->
	    case expansion of
	      | Base     _      -> aux expansion
	      | Subsort  (x, _) -> aux x
	      | Quotient (x, _) -> aux x
	      | _               -> expansion
   in
     aux sd

  def print_SortDescriptor (sd : SortDescriptor) =
    case sd of
      | Arrow        (x,y) -> (print_SortDescriptor x) ^ " -> " ^ (print_SortDescriptor y)
      | Product      fields -> "{" ^ (foldl (fn (result,(id, sd)) -> 
					     let this = id ^ ": " ^ (print_SortDescriptor sd) in
					     case result of
					       | "" -> this
					       | _ -> result ^ ", " ^ this)
				            ""
					    fields) ^ "}"
      | CoProduct    fields -> (foldl (fn (result,(id, possible_sd)) -> 
				       "| " ^ id ^ 
				       (case possible_sd of
					 | None -> " "
					 | Some sd -> print_SortDescriptor sd))
				      ""
				      fields)
      | Quotient     (sd,tm) -> (print_SortDescriptor sd) ^ "\\" ^ "???"
      | Subsort      (sd,tm) -> (print_SortDescriptor sd) ^ "|" ^ "???"
      | Base         ((q,id), parms) -> ((if q = "<unqualified>" then "" else q ^ ".") ^
					 id ^
					 (case parms of
					   | [] -> ""
					   | _ -> "(" ^ (foldl (fn (result,sd) -> 
								let this = print_SortDescriptor sd in
								case result of
								  | "" -> this
								  | _ -> result ^ ", " ^ this)
							       ""
							       parms) ^ 
					    ")"))
      | Boolean       -> "Boolean"
      | TyVar         -> "type var"
      | MetaTyVar     -> "meta type var"
      | Bottom        -> "<bottom>"

endspec
