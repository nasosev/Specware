\section{C Code Generator}

\begin{spec}
CGen qualifying spec {
  import /Languages/MetaSlang/Specs/AnnSpec
  import /Languages/MetaSlang/Specs/StandardSpec
  import /Languages/MetaSlang/Specs/Printer
  import /Languages/C/AbstractSyntax/Types
  import /Languages/C/AbstractSyntax/Printer

  op specToC : Spec -> CSpec
  def specToC spc =
    let cSpec = emptyCSpec "" in
    let cSpec = generateCTypes cSpec spc in
    let cSpec = generateCVars cSpec spc in
    let cSpec = generateCFunctions cSpec spc in
    let stmt = Block ([],map (fn (typ,name,tyVars,term) -> termToCStmt term) spc.properties) in
    let cSpec = addFuncDefn cSpec "main" [] Int stmt in
    let _ = writeLine (PrettyPrint.toString (format (80, ppCSpec cSpec))) in
    cSpec

  op termToCStmt : ATerm Position -> Stmt
  def termToCStmt trm =
    case trm of
      | Apply (Fun (Equals,srt,_), Record ([("1",lhs), ("2",rhs)],_), _) ->
          Exp (Apply (Binary Set, [termToCExp lhs, termToCExp rhs]))
      | _ -> fail ("termToCStmt: term '"
                  ^ (printTerm trm)
                  ^ "' is not an equality")

  op codSort : Spec -> ASort Position -> ASort Position
  def codSort spc srt =
    case (derefSort spc srt) of
      | Arrow (domSrt,codSrt,_) -> codSrt
      | _ -> fail ("codSort: '" ^ (printSort srt) ^ "' is not a function type")
  
  op generateCFunctions : CSpec -> Spec -> CSpec
  def generateCFunctions cSpec spc =
    let
      def toCFunc cSpec name trm srt =
        case trm of
          | Lambda ([match],_) ->
              (case match of
                 | (VarPat ((id,varSrt),_),_,trm) ->
                      addFuncDefn cSpec name [(id,sortToCType varSrt)] (sortToCType (codSort spc srt)) (Return (termToCExp trm))
                 | (RecordPat (fields,_),_,trm) ->
                     let def fieldToVarDecl (_,pat) = % was (id,pat) but this id seems to be unused...
                       case pat of
                         | VarPat ((id,varSrt),_) -> (id, sortToCType varSrt)
                         | _ -> fail "generateCFunctions: record field not a var pat"
                     in
                       addFuncDefn cSpec name (map fieldToVarDecl fields) (sortToCType (codSort spc srt)) (Return (termToCExp trm))
                 | _ -> fail ("generateCFunctions: operator "
                              ^ name
                              ^ " is not a function: '"
                              ^ (printTerm trm)
                              ^ "'"))
          | trm -> addFuncDefn cSpec name [] (sortToCType srt) (Return (termToCExp trm))

%           | _ -> fail ("generateCFunctions: operator "
%                       ^ name
%                       ^ " is not a lambda : '"
%                       ^ (printTerm trm)
%                       ^ "'")
      def doOp (q, id, info, cSpec) =
        case opInfoDefs info of
          | []     -> cSpec
          | trm::_ -> 
	    let (tvs, typ, tm) = unpackTerm trm in
	    toCFunc cSpec (showQualifiedId (Qualified (q, id))) trm typ
    in
      foldriAQualifierMap doOp cSpec spc.ops

  op derefSort : Spec -> ASort Position -> ASort Position
  def derefSort spc srt =
    case srt of
      | Base (qid, srts,_) ->
        (case findTheSort (spc, qid) of
	   | None -> srt % fail ("derefSort: failed to find sort: " ^ (showQualifiedId qid))
	   | Some info ->
	     case sortDefs info.dfn of
	       | [] -> srt
	       | srt::_ -> derefSort spc srt)
      | _ -> srt

  op generateCVars : CSpec -> Spec -> CSpec
  def generateCVars cSpec spc =
    let def doOp (q, id, info, cSpec) =
      case opInfoDefs info of
        | [] -> 
	  let typ = firstOpDefInnerSort info in
	  addVarDecl cSpec (showQualifiedId (Qualified (q, id))) (sortToCType typ)
%             (case (srt : ASort Position) of
%               | Base (qid,srts,_) ->
%                  (case (derefSort spc srt) of
%                    | Base (qid,srts,_) ->
%                        addVarDecl cSpec (showQualifiedId (Qualified (qual,id))) (baseSortToCType qid)
%                    | Product (fields,_) ->
%                        addVarDecl cSpec (showQualifiedId (Qualified (qual,id))) (baseSortToCType qid)
%                    | _ -> fail ("generateCVars: operator "
%                               ^ (showQualifiedId (Qualified (qual,id)))
%                               ^ " resolves to unsupported sort: "
%                               ^ (printSort srt)))
%               | Arrow (domSort,codSrt,_) -> cSpec % not a variable (leave it alone)
%                        addVarDecl cSpec (showQualifiedId (Qualified (qual,id))) (sortToCType srt)
% 
%               | _ -> fail ("generateCVars: operator "
%                           ^ (showQualifiedId (Qualified (qual,id)))
%                           ^ " has an unnamed sort: "
%                           ^ (printSort srt)))
        | _ -> cSpec
    in
      foldriAQualifierMap doOp cSpec spc.ops

  op generateCTypes : CSpec -> Spec -> CSpec
  def generateCTypes cSpec spc =
    let
      def makeCType cSpec name srt =
        case srt of
          | Arrow (domSort,codSort,_) -> addTypeDefn cSpec name (sortToCType srt)
          | Subsort (srt,term,_) -> makeCType cSpec name srt
          % | Product (("1",_)::_,_) -> fail "generateCTypes: found tuples without projections"
          | Product (fields,_) -> 
              addStruct cSpec name (map (fn (fieldName,srt) -> (fieldName, sortToCType srt)) fields)
          % | CoProduct (fields,_) -> fail "generateCTypes: found coproduct"
          % | Quotient (srt,term,_) -> fail "generateCTypes: found quotient"
          | Base (qid,[],_) -> addTypeDefn cSpec name (baseSortToCType qid)
          | Boolean _       -> addTypeDefn cSpec name Int
          | Base (Qualified ("Array","Array"),[srt],_) -> addTypeDefn cSpec name (Array (sortToCType srt))
          | Base (Qualified ("Store","Ptr"),[srt],_) -> addTypeDefn cSpec name (Ptr (sortToCType srt))
          % | Base (qid,srts,_) -> fail "generateCTypes: found instantiated base type"
          % | TyVar _ -> fail "generateCTypes: found type variable"
          % | MetaTyVar _ -> fail "generateCTypes: found meta-type variable"
          | _ ->
             let _ = writeLine ("generateCTypes: unsupported sort: " ^ (printSort srt) ^ "\n") in
             cSpec

      def doSort (q, id, info, cSpec) =
        case sortDefs info.dfn of
          | []     -> cSpec
          | srt::_ -> makeCType cSpec (showQualifiedId (Qualified (q, id))) srt
    in
      addTypeDefn (foldriAQualifierMap doSort cSpec spc.sorts) "bool" Int

  op removePrime : QualifiedId -> QualifiedId
  def removePrime (qid as Qualified (qual,id)) =
    case (rev (explode id)) of
      | #'::rest -> Qualified (qual, implode (rev rest))
      | _ -> qid % fail ("removePrime: left side identifier not primed: "
                 % ^ (showQualifiedId qid))

  op showQualifiedId : QualifiedId -> String
  def showQualifiedId (Qualified (qual,id)) =
    if qual = UnQualified then
      (fixName id)
    else
      qual ^ "_" ^ (fixName id)

  op fixName : String -> String
  def fixName oldName =
    let def validChar c = (isAlphaNum c) or (c = #_) in
    let newStr = implode (filter validChar (explode oldName)) in
    newStr
\end{spec}

It is reasonable that the next function should disappear. One could argue,
that we should never map the MetaSlang types to C types but rather define
the base types in C. For instance \verb+typedef int Integer+.

\begin{spec}
  op baseSortToCType : QualifiedId -> Type
  def baseSortToCType (Qualified (qual,id)) =
    if qual = UnQualified then
      Base id
    else
      case (qual,id) of
        | ("Integer","Integer") -> Int
        | ("Nat","Nat") -> Int
        | ("String","String") -> Ptr Char
        | ("Char","Char") -> Char
        | ("Double","Double") -> Double
        | _ -> Base (showQualifiedId (Qualified (qual,id)))

  op sortToCType : ASort Position -> Type
  def sortToCType srt =
    case srt of
      | Subsort (srt,term,_) -> sortToCType srt
      | Base (Qualified ("Array","Array"),[srt],_) -> Array (sortToCType srt)
      | Base (Qualified ("Store","Ptr"),[srt],_) -> Ptr (sortToCType srt)
      | Base (qid,[],_) -> baseSortToCType qid
      | Boolean _       -> Int
      | Base (qid,srts,_) -> 
          % let _ = writeLine ("sortToCType: found instantiated base type: " ^ (printSort srt)) in
          Void
      | Arrow (domSort,codSort,_) -> 
          let domTypes =
            case domSort of
              | Product (fields as (("1",_)::_),_) -> 
                   map (fn (fieldName,srt) -> sortToCType srt) fields
              | _ -> [sortToCType domSort]
          in
            Fn (domTypes, sortToCType codSort)
      | _ -> 
         let _ = writeLine ("sortToCType: unsupported type: " ^ (printSort srt)) in
         Void
   
  op addInclude : CSpec -> String -> CSpec
  def addInclude cSpec inc = {
      includes    = cons (inc, cSpec.includes),
      defines     = cSpec.defines,
      constDefns  = cSpec.constDefns,
      vars        = cSpec.vars,
      extVars     = cSpec.extVars,
      fns         = cSpec.fns,
      axioms      = cSpec.axioms,
      typeDefns   = cSpec.typeDefns,
      structDefns = cSpec.structDefns,
      unionDefns  = cSpec.unionDefns,
      varDefns    = cSpec.varDefns,
      fnDefns     = cSpec.fnDefns
    }

  op addVarDecl : CSpec -> String -> Type -> CSpec
  def addVarDecl cSpec name vtype = {
      includes    = cSpec.includes,
      defines     = cSpec.defines,
      constDefns  = cSpec.constDefns,
      vars        = Cons ((name,vtype), cSpec.vars),
      extVars     = cSpec.extVars,
      fns         = cSpec.fns,
      axioms      = cSpec.axioms,
      typeDefns   = cSpec.typeDefns,
      structDefns = cSpec.structDefns,
      unionDefns  = cSpec.unionDefns,
      varDefns    = cSpec.varDefns,
      fnDefns     = cSpec.fnDefns
    }

  op addFuncDefn : CSpec -> String -> VarDecls -> Type -> Stmt -> CSpec
  def addFuncDefn cSpec name params ftype stmt = {
      includes    = cSpec.includes,
      defines     = cSpec.defines,
      constDefns  = cSpec.constDefns,
      vars        = cSpec.vars,
      extVars     = cSpec.extVars,
      fns         = cSpec.fns,
      axioms      = cSpec.axioms,
      typeDefns   = cSpec.typeDefns,
      structDefns = cSpec.structDefns,
      unionDefns  = cSpec.unionDefns,
      varDefns    = cSpec.varDefns,
      fnDefns     = Cons ((name,params,ftype,stmt),cSpec.fnDefns)
    }

  op addStruct : CSpec -> String -> VarDecls -> CSpec
  def addStruct cSpec name fields = {
      includes    = cSpec.includes,
      defines     = cSpec.defines,
      constDefns  = cSpec.constDefns,
      vars        = cSpec.vars,
      extVars     = cSpec.extVars,
      fns         = cSpec.fns,
      axioms      = cSpec.axioms,
      typeDefns   = Cons ((name,Struct name), cSpec.typeDefns),
      structDefns = Cons ((name,fields), cSpec.structDefns),
      unionDefns  = cSpec.unionDefns,
      varDefns    = cSpec.varDefns,
      fnDefns     = cSpec.fnDefns
    }

  op addTypeDefn : CSpec -> String -> Type -> CSpec
  def addTypeDefn cSpec name typ = {
      includes    = cSpec.includes,
      defines     = cSpec.defines,
      constDefns  = cSpec.constDefns,
      vars        = cSpec.vars,
      extVars     = cSpec.extVars,
      fns         = cSpec.fns,
      axioms      = cSpec.axioms,
      typeDefns   = Cons ((name,typ), cSpec.typeDefns),
      structDefns = cSpec.structDefns,
      unionDefns  = cSpec.unionDefns,
      varDefns    = cSpec.varDefns,
      fnDefns     = cSpec.fnDefns
    }
\end{spec}

\subsubsection*{Code Generation}

The following operator "termToCExp" translates a MetaSlang term to a C
expression. The "Spec" parameter is not used for now, it may be used
later to unfold sort definitions.

\begin{spec}
  op termToCExp: ATerm Position -> CExp
  def termToCExp term =
    let
      def recordFieldsToCExps (fields : List(Id * ATerm Position)) : CExps =
        case fields of 
          | [] -> []
          | (id,term)::fields -> Cons (termToCExp term, recordFieldsToCExps fields)
      def applyArgsToCExps (args : ATerm Position) =
        case args of
          | Record (fields,_) -> recordFieldsToCExps fields
          | term -> [termToCExp term]
    in
    case term of
      | Fun (fun,srt,_) -> funToCExp fun srt
      | Var ((id,srt),_) -> Var (id,sortToCType srt)
      | IfThenElse (test,term1,term2,_) -> IfExp (termToCExp test, termToCExp term1, termToCExp term2)
      | Apply (Fun (Project id, srt,pos),term,_) ->
          let cStruct = termToCExp term in
          StructRef (cStruct,id)
          % StructRef (Apply (Unary Contents, [cStruct]),id)
      | Apply (Fun (Op (Qualified (_,"active"),fxty),srt,pos), idx,_) ->
          ArrayRef (Var ("active",sortToCType srt),termToCExp idx)
      | Apply (Fun (Op (Qualified ("CStore","eval"),_),srt,pos),
         Record ([("1",Fun (Op (Qualified (_,mapName),_),_,_)), ("2",Fun (String mapIdx,_,_))],_), _) ->
          Var (mapName++mapIdx,sortToCType srt)
      | Apply (Fun (Op (Qualified (_,"eval"),_),e_srt,e_pos),
	       Record ([("1",Fun (Op (Qualified (_,"env"),_),srt,pos)),("2",Fun (Nat n,_,_))],_),_) ->
          if n = 0 then
            Apply (Unary Contents, [Var ("sp",sortToCType srt)])
          else
            Apply (Unary Contents, [Apply (Binary Add, [Var ("sp",sortToCType srt), Const (Int n)])])
      | Apply (Apply (Fun (Op (Qualified ("Array","index"),fxty),srt,pos), arrayTerm,_), indexTerm,_) ->
          let cArray = termToCExp arrayTerm in
          let cIndex = termToCExp indexTerm in
          ArrayRef (cArray,cIndex)
      | Apply (Fun (Op (Qualified ("Store","deref"),fxty),srt,pos), arg,_) ->
          Apply (Unary Contents, [termToCExp arg])
      | Apply (Fun (Embed ("Number",_),srt,_),arg,_) -> termToCExp arg
      | Apply (Fun (Embed ("Int",_),srt,_),arg,_) -> termToCExp arg
      | Apply (Fun (Op (Qualified (_,"fixBool"),fxty),srt,pos), arg,_) -> termToCExp arg
      | Apply (Fun (Op (Qualified ("Double","fromNat"),fxty),srt,pos), arg,_) -> termToCExp arg
      | Apply (Fun (Op (Qualified ("Double","sqrt"),fxty),srt,pos), arg,_) ->
          Apply (Var ("sqrt",Fn ([Double],Double)), [termToCExp arg])
      | Apply (Fun (Op (Qualified ("Double","exp"),fxty),srt,pos), arg,_) ->
          Apply (Var ("exp",Fn ([Double],Double)), [termToCExp arg])
      | Apply (Fun (Op (Qualified ("Double","abs"),fxty),srt,pos), arg,_) ->
          Apply (Var ("fabs",Fn ([Double],Double)), [termToCExp arg])
      | Apply (Fun (Op (Qualified ("Functions","id"),fxty),srt,pos), arg,_) -> termToCExp arg 
      | Apply (Apply (Fun (Op (Qualified ("Struct","proj"),_),srt,pos), Fun (Op (qid,_),_,_),_), structTerm,_) ->
          let cStruct = termToCExp structTerm in
          StructRef (cStruct, showQualifiedId (removePrime qid))
      | Apply (Apply (Fun (Op (Qualified ("Struct","proj"),fxty),srt,pos), projTerm,_), structTerm,_) ->
          let cProjFunc = termToCExp projTerm in
          let cStruct = termToCExp structTerm in
            Apply (Apply (Unary Contents,[cProjFunc]), [cStruct])
      | Apply (Fun (fun,srt,_),args,_) ->
          let cFun = funToCExp fun srt in
          let cArgs = applyArgsToCExps args in
          (case cFun of
            | Binary _ ->
               if ~(length cArgs = 2) then 
                 fail ("trying to apply a binary operator to " ^ (natToString (length cArgs)) ^ " arguments.") 
               else
                 Apply (cFun,cArgs)
            | Unary _ ->
               if ~(length cArgs = 1) then 
                 fail ("trying to apply a unary operator to " ^ (natToString (length cArgs)) ^ " arguments.") 
               else
                 Apply (cFun,cArgs)
            | _ -> Apply (cFun,cArgs))
      | Apply (term1,term2,_) ->
          let cFun = termToCExp term1 in
          let cArgs = applyArgsToCExps term2 in
          Apply (cFun,cArgs)
       | Record ([],_) -> Nop
       | _ -> 
         let _ = writeLine ("termToCExp: term is neither a constant nor an application: " ^ (printTerm term)) in Nop
\end{spec}

In contrast, "funToCExp" converts a one- or more-ary function
identifier to the corresponding C function identifier. Again, only
operators defined for the primitive types are allowed that have their
pendant on the C side.

\begin{spec}
  op funToCExp: AFun Position -> ASort Position -> CExp
  def funToCExp fun srt = 
    case fun of
      | Equals -> Binary Eq
      | Nat val -> Const (Int val)
      | Char val -> Const (Char val)
      | Bool val -> Const (Int (if val then 1 else 0))
      | String val -> Const (String val)
      | Op (Qualified("Store","nilPtr"),_) -> Var ("NULL",Void)
      | Op (Qualified("Nat","+"),_) -> Binary Add
      | Op (Qualified("Nat","*"),_) -> Binary Mul
      | Op (Qualified("Nat","-"),_) -> Binary Sub
      | Op (Qualified("Nat","<"),_) -> Binary Lt
      | Op (Qualified("Nat","<="),_) -> Binary Le
      | Op (Qualified("Nat",">"),_) -> Binary Gt
      | Op (Qualified("Nat",">="),_) -> Binary Ge
      | Op (Qualified("Nat","div"),_) -> Binary Div
      | Op (Qualified("Nat","mod"),_) -> Binary Mod

      | Op (Qualified("Integer","+"),_) -> Binary Add
      | Op (Qualified("Integer","*"),_) -> Binary Mul
      | Op (Qualified("Integer","-"),_) -> Binary Sub
      | Op (Qualified("Integer","div"),_) -> Binary Div
      | Op (Qualified("Integer","mod"),_) -> Binary Mod
      | Op (Qualified("Integer","~"),_) -> Unary Negate
      | Op (Qualified("Integer","<"),_) -> Binary Lt
      | Op (Qualified("Integer","<="),_) -> Binary Le
      | Op (Qualified("Integer",">"),_) -> Binary Gt
      | Op (Qualified("Integer",">="),_) -> Binary Ge

      | Op (Qualified("Double","+"),_) -> Binary Add
      | Op (Qualified("Double","*"),_) -> Binary Mul
      | Op (Qualified("Double","-"),_) -> Binary Sub
      | Op (Qualified("Double","//"),_) -> Binary Div
      | Op (Qualified("Double","~"),_) -> Unary Negate
      | Op (Qualified("Double","<"),_) -> Binary Lt
      | Op (Qualified("Double","<="),_) -> Binary Le
      | Op (Qualified("Double",">"),_) -> Binary Gt
      | Op (Qualified("Double",">="),_) -> Binary Ge
      | Op (Qualified("Double","pi"),_) -> Var ("M_PI",Double)

      | Not       -> Unary LogNot
      | And       -> Binary LogAnd
      | Or        -> Binary LogOr
      | NotEquals -> Binary NotEq
 
      % | Op (qid,_) -> Fn (showQualifiedId (removePrime qid), [], sortToCType srt)
      | Op (qid,_) -> Var (showQualifiedId (removePrime qid),sortToCType srt)

      | Embed (id,_) -> 
          let _ = writeLine ("funToCExp: Ignoring constructor " ^ id) in
          Nop
}
\end{spec}
