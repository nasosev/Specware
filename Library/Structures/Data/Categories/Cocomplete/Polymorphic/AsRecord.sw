\section{Concrete Sort for Cocomplete Cats as Record}

\begin{spec}
spec {
  import ../Polymorphic

  sort Cocone (O,A) = {
      diagram : Diagram (O,A),
      apex : O,
      natTrans : NatTrans (O,A)
    }

  def diagram cocone = cocone.diagram
  def apex cocone = cocone.apex
  def natTrans cocone = cocone.natTrans

  sort InitialCocone (O,A) = {
      cocone : Cocone (O,A),
      universal : Cocone (O,A) -> A
    }

  def cocone initCocone = initCocone.cocone
  def universal initCocone = initCocone.universal

  sort Cat (O,A) = {
      ident : O -> A,
      dom : A -> O,
      cod : A -> O,
      % composable? : A -> A -> Boolean,
      compose : A -> A -> A,
      colimit : Diagram (O,A) -> InitialCocone (O,A),
      ppObj : O -> Pretty,
      ppArr : A -> Pretty
    }

%  op ident: fa(O,A) Cat(O,A) -> O -> A
%  op dom: fa(O,A) Cat(O,A) -> A -> O
%  op cod: fa(O,A) Cat(O,A) -> A -> O
%  % op composable?: fa(O,A) Cat(O,A)  -> A -> A -> Boolean
%  op compose: fa(O,A) Cat(O,A) -> A -> A -> A 
%  op colimit: fa(O,A) Cat(O,A) -> Diagram (O,A) -> InitialCocone (O,A)
%  op ppObj: fa(O,A) Cat(O,A) -> O -> Pretty
%  op ppArr: fa(O,A) Cat(O,A) -> A -> Pretty

  def ident (cat) = cat.ident
  def dom cat = cat.dom
  def cod cat = cat.cod
  % def composable? cat = cat.composable?
  def compose cat = cat.compose
  def colimit cat = cat.colimit
  def ppObj cat = cat.ppObj
  def ppArr cat = cat.ppArr
}
\end{spec}

Should we add ppObj and ppArrow to the record for pretty printing
objects and arrows respectively?
