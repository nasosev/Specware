(* This does not currently use Allen-Cocke interval analysis to
discover structure in a control-flow graph.  Refs acm computing
surveys Sept 1986 Ryder & Paull Cifuentes UQ website, IEEE "New
Algorithms for Control-Flow Graph Structuring" Moretti, Chanteperdix,
Osorio 

Top-level function is nodeListToStructuredGraph
*)
Struct qualifying 
spec 
  import /Languages/MetaSlang/Specs/StandardSpec
  import /Library/Legacy/DataStructures/ListUtilities % For replaceNth findOptionIndex delete
  import /Languages/MetaSlang/Specs/Printer

  sort Index = Integer			% Acually Nat + -1

  % term annotated with its environment spec
  sort EnvTerm = AnnSpec.Spec * MS.Term

  sort Stat =
    | Assign EnvTerm
    | Proc EnvTerm
    | Return EnvTerm

  sort NodeContent =
    %% First three for pure control flow graphs
    | Branch { condition   : EnvTerm,
	       trueBranch  : Index,
	       falseBranch : Index }
    | Block { statements : List Stat,
	      next       : Index }
    | Return EnvTerm
    %% Next three are for representing discovered structure in the graph
    | IfThen { condition  : EnvTerm,
	       trueBranch : Index,
	       cont       : Index }
    | IfThenElse { condition   : EnvTerm,
		   trueBranch  : Index,
		   falseBranch : Index,
		   cont        : Index }
    | Loop { condition : EnvTerm,
	     preTest?  : Boolean,
	     body      : Index,
%	     endLoop   : Index,
	     cont      : Index }

  op noContinue: Index			% To represent return destination
  def noContinue = ~ 1
    
  sort Node = Index * NodeContent * List Index % predecessors
  sort Graph = List Node		% In some topological order

  op nodeContent: Nat * Graph -> NodeContent
  def nodeContent(i,g) = (nth(g,i)).2

  op predecessors: Index * Graph -> List Index
  op successors: Index * Graph -> List Index

  def predecessors(i,g) =
    case nth(g,i) of
      | (_,_,preds) -> preds

  def successors(i,g) = if i = noContinue then []
                         else nodeSuccessors(nodeContent(i,g))

  op nodeSuccessors: NodeContent ->  List Index
  def nodeSuccessors nc =
    case nc of
      | Block {statements = _, next} -> [next]
      | Branch {condition = _, trueBranch, falseBranch} -> [trueBranch, falseBranch]
      | Return _ -> []
      | IfThen {condition, trueBranch, cont} -> [trueBranch,cont]
      | IfThenElse {condition, trueBranch, falseBranch, cont} ->
        [trueBranch, falseBranch]
      | Loop {condition, preTest?, body, cont} -> [body,cont]

  op setNodeContent: Index * NodeContent * Graph -> Graph
  def setNodeContent(i,newNodeContent,g) =
    case nth(g,i) of
      | (dfsi,_,preds) ->
	replaceNth(i,g,(dfsi,newNodeContent,preds))

  op  setPredecessors: Index * List Index * Graph -> Graph
  def setPredecessors(i,preds,g) =
    case nth(g,i) of
      | (dfsi,content,_) -> replaceNth(i,g,(dfsi,content,preds))

  op  removePredecessor: Index * Index  * Graph -> Graph
  def removePredecessor(i,oldPred,g) =
    setPredecessors(i,delete(oldPred,predecessors(i,g)),g)

  op  addPredecessor: Index * Index  * Graph -> Graph
  def addPredecessor(i,newPred,g) =
    let oldPreds = predecessors(i,g) in
    if member(newPred,oldPreds) then g
      else setPredecessors(i,Cons(newPred,oldPreds),g)

  op  replaceSuccessor: Index * Index * Index * Graph -> Graph
  def replaceSuccessor(i,oldSucc,newSucc,g) =
    case nth(g,i) of
      | (dfsi,nc,preds) ->
        let def repl x = if x = oldSucc then newSucc else x in
        let newContent =
	    (case nc of
	       | Block {statements = stats, next} ->
	         Block {statements = stats, next = repl next}
	       | Branch {condition = condn, trueBranch, falseBranch} ->
		 Branch {condition = condn, trueBranch = repl trueBranch,
			 falseBranch = repl falseBranch}
	       | IfThen {condition, trueBranch, cont} ->
		 IfThen {condition = condition, trueBranch = repl trueBranch, cont = repl cont}
	       | IfThenElse {condition, trueBranch, falseBranch, cont} ->
	         IfThenElse {condition = condition, trueBranch = repl trueBranch,
			     falseBranch = repl falseBranch, cont = repl cont}
	       | Loop {condition, preTest?, body, cont} ->
		 Loop {condition = condition, preTest? = preTest?, body = repl body, cont = repl cont}
	       | content -> content)
	in
	replaceNth(i,g,(dfsi,newContent,preds))

  op  changeSuccessor: Index * Index * Index * Graph -> Graph
  def changeSuccessor(i,oldSucc,newSucc,g) =
    let g = replaceSuccessor(i,oldSucc,newSucc,g) in
    let g = removePredecessor(oldSucc,i,g) in
    addPredecessor(newSucc,i,g)

	    
  op setDFSIndex: Index * Nat * Graph -> Graph
  def setDFSIndex(i,newDFSI,g) =
    case nth(g,i) of
      | (_,content,preds) ->
	replaceNth(i,g,(newDFSI,content,preds))

  op depthFirstIndex: Index * Graph -> Nat
  def depthFirstIndex(i,g) =
    if i = noContinue then 0
      else (nth(g,i)).1

  op insertDFSIndices: Graph * Index -> Graph
  def insertDFSIndices (g,topIndex) =
    let
      def DFS(i,st as (count,seen,g)) =
	if member(i,seen) or i = noContinue  % ~1 test by LE
	  then st
	  else
	    let (count,seen,g) = DFSlist(successors(i,g),count,Cons(i,seen),g) in
	    (count + 1, seen, setDFSIndex(i,count,g))
      def DFSlist(ilst,count,seen,g) =
	foldl DFS (count,seen,g) ilst
    in
      (DFS(topIndex,(1,[],g))).3

  op descendantIndex?: Index * Index * Graph -> Boolean
  def descendantIndex?(i,j,g) = depthFirstIndex(i,g) < depthFirstIndex(j,g)

  %% Returns node that is lowest in graph
  op  latestNode?: List Index * Graph -> Index
  def latestNode?(firstNd::restNds,g) =
    foldl (fn (i,least) ->
	    if descendantIndex?(least,i,g) then i else least)
      firstNd restNds

  op loopPredecessors: Index * Graph -> List Index
  def loopPredecessors(i,g) =
    filter (fn j -> descendantIndex?(j,i,g)) (predecessors(i,g))

  op commonSuccessor: Nat * Nat * Graph -> Nat
  def commonSuccessor(i,j,g) =
    let def breadthFirst(iS,jS,iSeen,jSeen,g) =
          case iS of
	    | x::riS ->
	      if member(x,jSeen) then x   % LE added ~1 test
		else
		let newIS = filter (fn x -> ~(member(x,iSeen) or member(x,riS)
					      or x = noContinue))
		              (successors(x,g))
		in
		%% Notice reversal of jS and riS
		breadthFirst(jS,riS ++ newIS,jSeen,Cons(x,iSeen),g)
	    | [] ->
	  case jS of
	    | x::rjS ->
	      if member(x,iSeen) then x   % LE added ~1 test
		else let newJS = filter (fn x -> ~(member(x,jSeen) or member(x,rjS)
					             or x = noContinue))
		                   (successors(x,g))
		     in
		     breadthFirst(rjS ++ newJS,iS,Cons(x,jSeen),iSeen,g)
	    | _ -> noContinue
    in
      breadthFirst([i],[j],[],[],g)

  op findTopIndex: Graph -> Index
  def findTopIndex(g) = 0
%     % Index of node with no predecessors
%     case findOptionIndex
%            (fn (nd,i) -> if nd.3 = [] then Some i else None)
% 	   g
%       of Some (topIndex,_) -> topIndex

  op exitNodes: List Index * Graph -> List Index
  def exitNodes(nds,g) =
    foldl (fn (nd,exits) ->
	   (filter (fn sn -> ~(member(sn,nds) or member(sn,exits)))
	      (successors(nd,g)))
	   ++ exits)
      [] nds

  op getAllPredecessorsBackTo: List Index * List Index * Graph -> List Index
  def getAllPredecessorsBackTo(nds,limitNds,g) =
    let def loop(nds,found,g) =
          case nds of
	    | [] -> found
	    | nd::rNds ->
	      if member(nd,found) %or member(nd,limitNds)
		then loop(rNds,found,g)
		else loop(rNds ++ (predecessors(nd,g)),Cons(nd,found),g)
    in
      loop(nds,limitNds,g)

  op nodeListToStructuredGraph: List NodeContent -> Graph
  def nodeListToStructuredGraph contentsList =
    graphToStructuredGraph(addPredecessors contentsList)
  
  op graphToStructuredGraph: Graph -> Graph
  def graphToStructuredGraph (baseG) =
    if baseG = [] then baseG else
    %% The new graph has the same number of nodes as the old one,
    %% with structured nodes replacing simple nodes.
    %% This makes it easier to use indices as references before the whole
    %% graph is computed.
    let topIndex = findTopIndex(baseG) in
    let baseG = insertDFSIndices (baseG,topIndex) in
    %% DFS indices tell which nodes are higher in the graph and are used to
    %% to determine which links are looping links
    %% let - = print(printGraph baseG) in
    let
      def buildStructuredGraph(nd,exits,g) =
	if member(nd,exits) or nd = noContinue then g
	else
	case loopPredecessors(nd,baseG) of
	  | []  -> buildStraightLine(nd,exits,g)
	  | preds ->
	    let loopExits = exitNodes(Cons(nd,getAllPredecessorsBackTo(preds,[nd],
								       baseG)),
				      baseG) in
	    (case loopExit?(nd,loopExits,g) of
	       | Some (cond,body,cont) -> buildLoop(nd,true,nd,cond,body,cont,exits,loopExits,g)
	       | None ->
	     let tail = latestNode?(preds,g) in    % final predecessor
	     case loopExit?(tail,loopExits,g) of
	       | Some (cond,body,cont) ->
	       %% Move tail to head of the loop
	         let g = foldl (fn (pred,g) ->
				if descendantIndex?(nd,pred,g)
				  then changeSuccessor(pred,nd,tail,g)
				 else g)
	                   g (predecessors(nd,g))
	         in buildLoop(nd,false,tail,cond,body,cont,exits,loopExits,g)
	       %% Give up structuring. Rely on gotos.
	       | None -> buildStraightLine(nd,exits,g))
	  %% So far only one loop for node
	  %| x::rs -> buildLoops(n,x,rs,g)

      def buildStructuredGraphRec(nd,oldNd,exits,g) =
	if descendantIndex?(nd,oldNd,g)     % Prevent reprocessing nodes
	  then buildStructuredGraph(nd,exits,g)
	  else g

      def buildLoop(oldNd,pre?,head,cond,body,cont,exits,loopExits,g) =
	let g = buildStructuredGraphRec(cont,oldNd,exits,g) in
	let g = buildStructuredGraphRec(body,oldNd,Cons(head,loopExits),g) in
	let g = setNodeContent(head,
			       Loop {condition = cond,
				     preTest?  = pre?,
				     body      = body,
				     cont      = cont},
			       g)
	in foldl (fn (x,g) ->
		  if x = cont then g
		  else buildStructuredGraphRec(x,oldNd,exits,g))
	     g loopExits

      def loopExit?(node,loopExits,g) =
	case nodeContent(node,g) of
	  | Branch {condition, trueBranch, falseBranch} ->
	    if member(falseBranch,loopExits) % outside loop
	      then Some(condition,trueBranch,falseBranch)
	      else % trueBranch should be outside loop
	    if member(trueBranch,loopExits)
	      then Some(negateEnvTerm condition,falseBranch,trueBranch)
	      else None
	  | _ -> None
	    
      def buildStraightLine(nd,exits,g) =
        if nd = noContinue then g else
	case nodeContent(nd,baseG) of
	  | Block {statements = _, next} ->
	    buildStructuredGraphRec(next,nd,exits,g)
	  | Branch {condition, trueBranch, falseBranch} ->
	    let cont = commonSuccessor(trueBranch,falseBranch,baseG) in
	    let g = buildStructuredGraphRec(trueBranch, nd,[cont],g) in
	    let g = buildStructuredGraphRec(falseBranch,nd,[cont],g) in
	    let g = if cont = trueBranch or cont = falseBranch or cont = noContinue
	                then g
			else buildStructuredGraphRec(cont,nd,exits,g) in
	    if falseBranch = cont
	      then setNodeContent(nd,IfThen {condition   = condition,
					     trueBranch  = trueBranch,
					     cont        = falseBranch},
				  g)
	    else if trueBranch = cont
	      then setNodeContent(nd,IfThen {condition   = negateEnvTerm condition,
					     trueBranch  = falseBranch,
					     cont        = trueBranch},
				  g)
	      else setNodeContent(nd,IfThenElse {condition   = condition,
						 trueBranch  = trueBranch,
						 falseBranch = falseBranch,
						 cont        = cont},
				  g)
	   | Return _ -> g
    in
    case baseG of
      | [] -> []
      %% Assumes first node of baseG is the head of the graph
      | _::_ ->
        let g = buildStructuredGraph (topIndex, [], baseG) in
	%let _ = print(printGraph g) in
	g

  op printGraph: Graph -> String
  op printNode : Node * Index -> String
  op printStat : Stat  -> String
  op printNodeContent : NodeContent -> String

  def printGraph(g) =
    let (str,_) = foldl (fn (nd,(str,i)) -> (str ^ "\n" ^ printNode (nd,i),i+1))
                    ("",0) g
    in str

  def printNode((DFSindex,content,preds),i) =
    "Node " ^ (Integer.toString i) ^ ": DFS index: " ^ (Integer.toString DFSindex)
      ^ " Preds: (" ^ (show " " (map Integer.toString preds))
      ^ ")\n  "
      ^ (printNodeContent content)

  def printNodeContent content =
    case content of
	  | Branch {condition, trueBranch, falseBranch} ->
	    "Branch Condn: " ^ (printEnvTerm condition) ^ "\n  "
	    ^ "True branch: " ^ (Integer.toString trueBranch) ^ "\n  "
	    ^ "False branch: " ^ (Integer.toString falseBranch)
	  | Block {statements, next} ->
	    "Block: " ^ show "; " (map printStat statements)
	    ^ "\n  "
	    ^ "Next: " ^ (Integer.toString next)
	  | Return t ->
	    "Return: " ^ (printEnvTerm t)
	  | IfThen {condition, trueBranch, cont} ->
	    "If: " ^ (printEnvTerm condition) ^ "\n  "
	    ^ "True branch: " ^ (Integer.toString trueBranch) ^ "\n  "
	    ^ "Continue: " ^ (Integer.toString cont)
	  | IfThenElse {condition, trueBranch, falseBranch, cont} ->
	    "If: " ^ (printEnvTerm condition) ^ "\n  "
	    ^ "True branch: " ^ (Integer.toString trueBranch) ^ "\n  "
	    ^ "False branch: " ^ (Integer.toString falseBranch) ^ "\n  "
	    ^ "Continue: " ^ (Integer.toString cont)
	  | Loop {condition, preTest?, body, cont} ->
	    (if preTest? then "While: " else "Until: ") ^ (printEnvTerm condition) ^ "\n  "
	    ^ "Body:: " ^ (Integer.toString body) ^ "\n  "
	    ^ "Continue: " ^ (Integer.toString cont)

  def printStat st =
    case st of
      | Assign t -> "Assign " ^ (printEnvTerm t)
      | Proc t -> "Proc " ^ (printEnvTerm t)
      | Return t -> "Return " ^ (printEnvTerm t)

  op addPredecessors: List NodeContent -> Graph
  def addPredecessors contentsList =
    mapi (fn (i,nc) -> (0,nc,findPredecessors(i,contentsList))) contentsList

  op findPredecessors: Index * List NodeContent -> List Index
  def findPredecessors(i,contentsList) =
    filter (fn j -> member(i,nodeSuccessors(nth(contentsList,j))))
      (enumerate(0,(length contentsList) - 1))

  % --------------------------------------------------------------------------------

  op negateEnvTerm: EnvTerm -> EnvTerm
  def negateEnvTerm(spc,term) = (spc,negateTerm term)

  op printEnvTerm: EnvTerm -> String
  def printEnvTerm(_,term) = printTerm(term)

end
