\section{Construction / Destruction Operations}

\begin{spec}
spec {
  import Environment

  op evaluatePSpecElems :
           PSpec
        -> List (PSpecElem Position)
        -> Env (PSpec * TimeStamp * URI_Dependency)

  op staticSpec : PSpec -> SpecCalc.Env Spec
  def staticSpec pSpec = return pSpec.staticSpec

  op dynamicSpec : PSpec -> SpecCalc.Env Spec
  def dynamicSpec pSpec = return pSpec.dynamicSpec

  op procedures : PSpec -> SpecCalc.Env (PolyMap.Map (QualifiedId,Procedure))
  def procedures pSpec = return pSpec.procedures
  
  op setStaticSpec : PSpec -> Spec -> SpecCalc.Env PSpec
  def setStaticSpec pSpec spc = return {
      staticSpec = spc,
      dynamicSpec = pSpec.dynamicSpec,
      procedures = pSpec.procedures
    }

  op setDynamicSpec : PSpec -> Spec -> SpecCalc.Env PSpec
  def setDynamicSpec pSpec spc = return {
      staticSpec = pSpec.staticSpec,
      dynamicSpec = spc,
      procedures = pSpec.procedures
    }

  op setProcedures : PSpec -> PolyMap.Map (QualifiedId,Procedure) -> SpecCalc.Env PSpec
  def setProcedures pSpec procs = return {
      staticSpec = pSpec.staticSpec,
      dynamicSpec = pSpec.dynamicSpec,
      procedures = procs
    }

  op addProcedure : PSpec -> QualifiedId -> Procedure -> SpecCalc.Env PSpec
  def addProcedure pSpec id proc = return {
      staticSpec = pSpec.staticSpec,
      dynamicSpec = pSpec.dynamicSpec,
      procedures = PolyMap.update pSpec.procedures id proc
    }
}
\end{spec}
