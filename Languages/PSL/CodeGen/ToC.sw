SpecCalc qualifying spec {
  import Convert
  import ../../MetaSlang/CodeGen/C/ToC
  import /Languages/PSL/Semantics/Evaluate/Specs/Op/Legacy

  sort Spec.Spec = ASpec Position

  op oscarToC : Oscar.Spec -> Spec.Spec -> Env CSpec
  def oscarToC oscSpec base =
    let cSpec = emptyCSpec in
    let envSpec = subtractSpec (specOf oscSpec.modeSpec) base in
    let cSpec = generateCTypes cSpec envSpec in
    let cSpec = generateCVars cSpec envSpec in
    let cSpec = generateCFunctions cSpec envSpec in {
      cSpec <- ProcMapEnv.fold generateCProcedure cSpec oscSpec.procedures;
      print (PrettyPrint.toString (format (80, ppCSpec cSpec)));
      return cSpec
    }

  op generateCProcedure : CSpec -> Id.Id -> Procedure -> Env CSpec
  def generateCProcedure cSpec procId (proc as {parameters,varsInScope,returnInfo,modeSpec,bSpec}) =
    let initSpec = BSpec.modeSpec bSpec (initial bSpec) in
    let varDecls =
      List.map (fn argRef -> let (names,fxty,(tyVars,srt),_) = Op.deref (specOf initSpec, argRef) in
            (OpRef.show argRef, sortToCType srt)) parameters in
    let returnType =
      case returnInfo of
        | None -> Void 
        | Some retRef ->
            let (names,fixity,(tyVars,srt),_) = Op.deref (specOf initSpec, retRef) in
              sortToCType srt in
    let def handler id proc except =
      case except of
        | SpecError (pos, msg) -> {
             print ("convertOscarSpec exception:" ^ msg ^ "\n");
             print "shape=";
             print (ppFormat (pp (shape (system (Proc.bSpec proc)))));
             print "\n";
             procDoc <- ProcEnv.pp id proc;
             print (ppFormat procDoc);
             print "\n";
             raise (SpecError (pos, "except : " ^ msg))
           }
        | _ -> raise except
    in {
      print ("\n\nGenerating code for procedure: " ^ (Id.show procId) ^ "\n");
      graph <- catch (convertBSpec bSpec) (handler procId proc);
      graph <- catch (structGraph graph) (handler procId proc);
      procStmt <- return (graphToC graph);
      return (addFuncDefn cSpec (CGen.showQualifiedId procId) varDecls returnType procStmt)
    }

  op nodeContent : Node -> NodeContent
  def nodeContent (index,content,predecessors) = content
\end{spec}

The following is meant to take a structured graph, as generated by convertBSpec into
a C abstract syntax tree. As far as I know, this does not handle breaks and continues
with a loop or out of a conditional.

\begin{spec}
  op graphToC : Struct.Graph -> Stmt
  def graphToC graph =
    let def consume first last =
      if first = ~1 then
        VoidReturn
      else if first = last then
        Nop
      else
        let _ = writeLine ("first = " ^ (Nat.toString first) ^ " last = " ^ (Nat.toString last)) in
          case nodeContent (nth (graph, first)) of
            | Block {statements, next} -> 
                let stmts = map statementToC statements in
                reduceStmt stmts (consume next last) 

            | Return term -> termToCStmtNew term % Return (termToCExp term)

            | IfThen {condition, trueBranch, continue} ->
                let stmt = IfThen (termToCExp condition, consume trueBranch continue) in
                let rest = consume continue last in
                reduceStmt [stmt] rest

            | IfThenElse {condition, trueBranch, falseBranch, continue} ->
                let trueStmt = consume trueBranch continue in
                let falseStmt = consume falseBranch continue in
                let ifStmt = If (termToCExp condition, trueStmt, falseStmt) in
                let rest = consume continue last in
                reduceStmt [ifStmt] rest

            | Loop {condition, preTest?, body, endLoop, continue} ->
                let bodyStmt = consume body first in
                let whileStmt = While (termToCExp condition, bodyStmt) in
                let rest = consume continue last in
                reduceStmt [whileStmt] rest

            | Branch {condition, trueBranch, falseBranch} ->
                let _ = writeLine ("ignoring branch") in
                Nop

      def reduceStmt stmts s2 =
        case s2 of
          | Block ([],moreStmts) -> Block ([],stmts ++ moreStmts)
          | Nop -> Block ([],stmts)
          | _ -> Block ([],stmts ++ [s2])

      def statementToC stat =
        case stat of
          | Assign term -> termToCStmtNew term
          | Proc term -> termToCStmtNew term
          | Return term -> termToCStmtNew term
    in
      consume 0 (length graph)

  op termToCStmtNew : MSlang.Term -> CStmt
  def termToCStmtNew term =
    case term of
      | Apply (Fun (Equals,srt,_), Record ([("1",lhs), ("2",rhs)],_), _) ->
          (case lhs of
            | Fun (Op (Qualified ("#return#",var),fxty),srt,pos) -> (Return (termToCExp rhs))
            | _ -> (Exp (Apply (Binary Set, [termToCExp lhs, termToCExp rhs]))))
      | Apply (Fun (Op (procId,fxty),procSort,pos),(Record ([(_,argTerm),(_,returnTerm),(_,storeTerm)],_)),pos) ->
          % let (Record ([(_,argTerm),(_,returnTerm),(_,storeTerm)],_)) = callArg in
          (case returnTerm of
            | Record ([],_) ->
                (Exp (termToCExp (Apply (Fun (Op (procId,fxty),procSort,pos),argTerm,pos))))
            | Fun (Op (Qualified ("#return#",var),fxty),srt,pos) ->
                (Return (termToCExp (Apply (Fun (Op (procId,fxty),procSort,pos),argTerm,pos))))
            | _ -> (Exp (Apply (Binary Set, [termToCExp returnTerm, termToCExp (Apply (Fun (Op (procId,fxty),procSort,pos),argTerm,pos))]))))
      | _ -> let _ = writeLine ("termToCStmt: ignoring term: " ^ (printTerm term)) in Nop
}
\end{spec}

Note that the second argument to "consume" above is an index greater
beyond the end of the array. This is deliberate. We could used
infinity. We will not get there as we must encounter a Return first. The
point is that the "consume" function will continue up to but not including
the "last" node.
