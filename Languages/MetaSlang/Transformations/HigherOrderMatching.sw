(* Higher-Order matching for MetaSlang

API

match(lhs,rhs,flexTerms,context)
 [lhs, rhs] 	are the two terms to be matched
 [flexTerms] 	are terms denoting flexible variables.
 [context]	contains rewrite laws, theorems, and tracing information.
 [matchPairs]
 The main recursive matching loop.
*)

HigherOrderMatching qualifying
spec
 import ../Specs/Environment
 import ../Specs/Utilities
 import Simplify, Interpreter

 type SubstC    = StringMap Sort * NatMap.Map MS.Term * List MS.Term

 op match : Context -> MS.Term * MS.Term -> List SubstC

 op matchPairs : Context * SubstC * Stack -> List SubstC

 type Context = 
      { 
        spc         : Spec,
        trace 	    : Boolean,
        traceDepth  : Ref Nat,
	traceIndent : Ref Nat,
	boundVars   : List Var,
        counter     : Ref Nat
      }

  op withSpec infixl 17 : Context * Spec -> Context
  def withSpec (ctxt,spc) = { 
        spc = spc,
        trace = ctxt.trace,
        traceDepth = ctxt.traceDepth,
        traceIndent = ctxt.traceIndent,
        boundVars = ctxt.boundVars,
        counter = ctxt.counter
      }

%% . spc        : Spec
%% . trace      : print trace?
%% . traceDepth : Counter keeping track of how deeply 
%%                the rewrites have been applied
%% . traceIndent: Counter keeping track of trace indentation.
%% . boundVars  : List of bound variables in scope of term
%% . counter    : Counter to generate fresh variables

% A substitution maps type variables to sorts and 
% flexible variables to terms.

 type Stack = {new : List (MS.Term * MS.Term), flex:  List (MS.Term * MS.Term)}

(*  Stack operations

The agenda is placed on a stack with {\em new}, unexamined entries,
and {\em flex}, entries whose heads are flexible and in general lead to
non-unitary matching.
The stack is accessed and modified using the operations
{\em next} and {\em insert}.

\item[emptyStack] The empty stack
\item[next]  Get next element in the stack to match
\item[insert]  Insert a new pair in the agenda
*)

 op emptyStack : Stack
 op next : Stack -> Option (Stack * MS.Term * MS.Term)
 op insert : MS.Term * MS.Term * Stack -> Stack

 def emptyStack = {new = [],flex = []}

 def next({new,flex}) = 
     case new
       of (M,N)::new ->
	  (case isFlexVar?(M)
	     of Some _ -> Some({new = new,flex = flex},M,N)
	      | None -> 
	   case hasFlexHead?(M)
	     of Some _ -> next {new = new,flex = Cons((M,N),flex)} 
	      | None -> Some({new = new,flex = flex},M,N))
	| [] -> 
     case flex
       of (M,N)::flex -> Some({new = new,flex = flex},M,N)
	| [] -> None

 def insert(M,N,{new,flex}) = {new = Cons((M,N),new),flex = flex}
 op stackFromList: List(MS.Term * MS.Term) -> Stack
 def stackFromList pairs = 
     foldr (fn ((M,N),stack) -> insert(M,N,stack)) emptyStack pairs


(* Utilities for fresh and bound variables *)

 op freshVar : Context * Sort -> MS.Term

% Meta variables (flexible variables) are represented in the form
% Apply(Fun(Op "%Flex",Arrow(Nat,s)),Fun(Int n,Nat))
 op flexQId: QualifiedId = mkUnQualifiedId "%Flex"

 op mkVar: Nat * Sort -> MS.Term
 def mkVar(num,srt) = 
     Apply(Fun(Op (flexQId,Nonfix),Arrow(natSort,srt,noPos),noPos),
	   Fun(Nat num,natSort,noPos),noPos)

 def freshVar (context,srt) = 
     let num = ! context.counter in
     (context.counter := num + 1;
      mkVar(num,srt)
     )

 def freshBoundVar (context:Context,srt) = 
     let num = ! context.counter in
     (context.counter := num + 1;
      ("x%"^show num,srt))

 op flexRef?(t: MS.Term): Boolean =
   case t of
     | Fun(Op(Qualified (UnQualified,"%Flex"),_),_,_) -> true
     | _ -> false

 op hasFlexRef?(t: MS.Term): Boolean =
   existsSubTerm flexRef? t

 op isFlexVar? : MS.Term -> Option Nat
 def isFlexVar?(term) = 
     case term
       of Apply (Fun(Op(Qualified (UnQualified,"%Flex"),_),_,_),Fun(Nat n,_,_),_) -> 
	  Some n
	| _ -> None
 op  hasFlexHead? : MS.Term -> Option Nat
 def hasFlexHead?(term) = isFlexVar?(head(headForm term))

(*
\subsection{Term normalization}
A main utility in normalizing terms and applying the current 
substitution is the {\tt dereference} utility, which
uses the current substitution and beta-reduction to 
normalize a term with respect to the current substitution.

This computes weak head normal form with respect
to current substitution. This entails unraveling all
applications and applying the head beta redexes 
that appear.

The weak head normal form of a term is of the form
      (c M_2 \_dots M_k)
where standardly c is a constant, a bound variable.
In our case we allow c to be anything but an abstraction of
irrefutable patterns, where it is obvious how to perform 
beta contraction.
*)

 op dereferenceR : SubstC -> MS.Term -> MS.Term
 op dereference : SubstC -> MS.Term -> MS.Term

 def dereferenceR (S as (sortSubst,termSubst,_)) term = 
     (case term
       of Apply (Fun(Op(Qualified (UnQualified,"%Flex"),_),_,_),Fun(Nat n,_,_),_) -> 
	  (case NatMap.find(termSubst,n)
	     of Some term -> dereferenceR S term
	      | None -> term)
	| Apply(M,N,a) -> 
	  (case dereferenceR S M
	     of Lambda(rules, _) -> 
		let N = dereferenceR S N in 
		(case patternMatchRules(rules,N)
		   of None -> Apply(M,N,a)
		    | Some (sub,M) -> dereferenceR S (substitute(M,sub)))
	      | M as Fun(Project l,_,_) -> 
	        (case dereferenceR S N
		   of Record(fields, _) -> 
		      (case findLeftmost (fn (l2,_) -> l = l2) fields
		         of Some(_,trm) -> trm
			  | None -> System.fail ("Label "^l^" not found"))
		    | N -> Apply(M,N,a))
	      | M -> Apply(M,N,a))
	| _ -> term)


 def dereference S term = 
     let term1 = dereferenceR S term in
     (%writeLine (printTerm term ^" |-> \n"^ printTerm term1);
      term1)

%%
%% Wasteful, but simple beta-normalizer.
%%

 op dereferenceAll (subst: SubstC) (term: MS.Term): MS.Term =
%   let freeNames = NatMap.foldri (fn (_,trm,vs) ->
%                                    StringSet.union (StringSet.fromList
%                                                       (map (fn (n,_) -> n) (freeVars trm)),
%                                                     vs))
%                     StringSet.empty subst.2
%   in
%   let term = substitute2(term,[],freeNames) in % Purely for renaming to avoid name clashes
   let (sortSubst,termSubst,_) = subst in
   let def deref (term) = 
           case isFlexVar?(term)
             of Some n -> 
                (case NatMap.find(termSubst,n)
                   of Some term -> 
                      derefAll term %Memoization by using refs?
                    | None -> term)
              | None -> 
                (case term
                   of Apply (M as Lambda(rules,_),N,_) -> 
                     (case patternMatchRules(rules,N)
                        of None -> Apply(M,N,noPos)
                         | Some (sub,M) -> derefAll (substitute(M,sub)))
                 | Apply(M as Fun(Project l,_,_),Record(fields, _),_) -> 
                   (case findLeftmost (fn (l2,_) -> l = l2) fields
                      of Some(_,trm) -> trm
                       | None -> System.fail ("Label "^l^" not found"))
                 | _ -> term)
       def derefAll term = dereferenceAll subst term
   in
   mapTerm(deref,fn s -> dereferenceSort(subst,s),fn p -> p) term
		 		  


 def bindPattern (pat,trm):MS.Term = Lambda([(pat,trueTerm,trm)],noPos)

% Get list of applications, assumes that the term is already dereferenced.
 op  headForm : MS.Term -> List MS.Term
 def headForm (term) = 
     case isFlexVar? term
       of Some n -> [term]
        | None -> 
     case term
       of Apply(M,N,_) -> headForm M ++ [N]
        | _ -> [term]
     
 op insertFields (stack: Stack) (fields1: List(Id * MS.Term), fields2: List(Id * MS.Term)): Stack = 
   %% Try to put the easy cases that don't generate multiple possibilities first
   let (pairs, hard_pairs) =
     ListPair.foldr
	(fn((_,x),(_,y), (pairs, hard_pairs)) ->
           if some?(hasFlexHead? x)
             then (pairs, Cons((x,y), hard_pairs))
             else (Cons((x,y), pairs), hard_pairs))
        ([],[]) (fields1, fields2)
   in
     foldl (fn (stack,(x,y)) -> insert(x,y,stack))	
        stack (pairs ++ hard_pairs)

\end{spec}

\subsection{The matcher}

\newcommand{\inferenceRule}[2]{
\begin{array}{c}
#1 
\\
\hline
#2
\end{array}
}

The main matching steps consist in decomposing pairs to be matched according
to the following rules:
\[
\begin{array}{|ll|}
\hline
& \\[2em]
\Pi-\Pi & 
\inferenceRule{
 \pi_i\theta = \pi'_i\theta, M_i\theta = N_i\theta}
{
\lambda\ \pi_i\rightarrow M_i = \lambda\ \pi'_i \rightarrow N_i } 
\\[2em]

\Sigma-\Sigma & 
\inferenceRule{M_1 = N_1,\ldots,M_n = N_n}
{
\langle M_1,\ldots,M_n\rangle = \langle N_1,\ldots,N_n\rangle
} 
\\[2em]

{\bf Flex}-{\bf App} & 
\inferenceRule{
X \mapsto \lambda x_1\ldots x_n \  . \ f (X_1\; M_1\ldots M_n)\ldots (X_k\; M_1\ldots M_n)\ \ 
X_1\; M_1\ldots M_n = N_1,\ldots
}
{X\; M_1\; \ldots M_n = f\;N_1\;\ldots\; N_k} 
\\[2em]

{\bf Flex}-\Sigma & 
\inferenceRule{X \mapsto \lambda x_1\ldots x_n \  . \ \langle (X_1\; M_1\ldots M_n),\ldots, (X_k\; M_1\ldots M_n)\rangle}
{
 X\; M_1\; \ldots M_n = \langle N_1\;\ldots\; N_k\rangle 
}
\\[2em]

{\bf Var} & 
\inferenceRule{X \mapsto N}
{X = N} \ \ \ \mbox{N is closed} \\[2em]

{\bf Imitate} & 
\inferenceRule{X \mapsto \lambda x_1 \ . \ldots .\lambda x_k \ . \ N}
{
 (X\;M_1\;\ldots\; M_k) = N
}  \\[2em]

{\bf Project} & 
\inferenceRule{X \mapsto \lambda x_1 \ldots x_{j} \ . \ {\tt project}(i),\ M_i  = N}
{
  (X\;M'_1\ldots M'_j\; \langle M_1,\ldots,M_k\rangle\ldots) = N 
}
\\[2em]

{\bf Project} & 
\inferenceRule{X \mapsto \lambda x_1\ldots,x_k \ . \ x_i,\ \ M_i = N}
{(X\;M_1\ldots M_i\;\ldots\;M_k) = N}  \\[2em]
\hline
\end{array}
\]
where all applicable rules are taken, and may contribute with
a list of substitutions (matches).

The conditions for the imitation steps are not complete. They should
apply to any head normal form, and also allow to match against a non-application
right-hand side.
The conditions for projection should also be completed.

Note: projections should in general be represented as 
\lambda (x_1,\ldots,x_i,\ldots,x_n) \ . \ x_i with a suitable match on a 
record type.

Handle also \eta rules for \Pi, \Sigma, and the other sort constructors.

\begin{spec}

 op emptySubstitution: SubstC = (StringMap.empty,NatMap.empty,[])
 op debugHOM: Ref Nat = Ref 0
 op evaluateConstantTerms?: Boolean = false     % For now until utility is proven
 op allowTrivialMatches?: Boolean = false       % Allow matches that don't use match terms
 op resultLimitHOM: Nat = 4

 def match context (M,N) = 
     matchPairs(context,emptySubstitution,insert(M,N,emptyStack))

 op onlyTrivialMatchesPossible?(topStack:  Option (Stack * MS.Term * MS.Term)): Boolean =
   case topStack of
     | None -> false
     | Some(_,M,N) ->
       (existsSubTerm
           (fn mi ->
              case mi of
                | Fun(Op(qid_m,_),_,_) | qid_m ~= flexQId ->
                  ~(existsSubTerm (fn ni ->
                                     case ni of
                                       | Fun(Op(qid_n,_),_,_) ->
                                         qid_m = qid_n
                                       | _ -> false)
                      N)
                %% Could also look for if-then-else, let or other Funs
                | _ -> false)
           M)

 op matchPairsTop (context: Context, subst: SubstC, stack0: Stack): List SubstC =
   if allowTrivialMatches? || ~(onlyTrivialMatchesPossible?(next stack0))
     then matchPairs(context, subst, stack0)
     else []

 def matchPairs (context,subst,stack0) = 
  %let _ = writeLine("Stack:\n"^ anyToString stack0) in
  let result =
   case next stack0
     of None -> [subst]
      | Some(stack,M,N) -> 
   let _ = (if !debugHOM > 0 then
              (debugHOM := !debugHOM - 1;
               writeLine (printTerm (dereference subst M) ^ " =?= "
                           ^ printTerm N);
               printSubst subst)
            else ())
   in
   case (dereference subst M,N)
     of 
%%
%% Pi-Pi
%%

	(Lambda(rules1, _),Lambda(rules2, _)) -> 
	if length rules1 = length rules2
	   then matchRules(context,subst,stack,rules1,rules2,[])
	else []
%%
%% Var 
%% Check that N does not contain bound variables.
%% sjw: 2/15/01 Moved before Eta
      | (Apply (Fun(Op(Qualified (UnQualified,"%Flex"),_),Arrow(_,s,_),_),
		Fun(Nat n,_,_),_),
	 N) ->
	if closedTermV(N,context.boundVars) && ~(occursProper n N)
	   then 
	   let srt2 = inferType(context.spc,subst,N) in
	   foldr (fn (subst,r) ->
                    matchPairs(context,updateSubst(subst,n,N),stack) ++ r)
             [] (unifySorts(context,subst,s,srt2,Some N))
	else []
      | (M, N as Apply (Fun(Op(Qualified (UnQualified,"%Flex"),_),_,_), _,_)) | ~(hasFlexRef? M) ->
        matchPairs(context,subst,insert(N,M,insert(N,M,stack)))
%%
%% Eta rules
%%
      | (M as Lambda([(VarPat((_,srt), _),Fun(Bool true,_,_),_)], _),N) -> 
	foldr (fn (subst,r) -> 
               let x = freshBoundVar(context,srt) in
               matchPairs (context,subst,
                           insert(Apply(M,Var(x,noPos),noPos),Apply(N,Var(x,noPos),noPos),stack))
                 ++ r)
          [] (unifySorts(context,subst,
			 inferType(context.spc,subst,M),
			 inferType(context.spc,subst,N),
                         Some N))
      | (M,Lambda([(VarPat((_,srt), _),Fun(Bool true,_,_),_)], _)) -> 
	foldr (fn (subst,r) ->
                 let x = freshBoundVar(context,srt) in
                 matchPairs(context,subst,
                            insert(bindPattern(VarPat(x,noPos),Apply(M,Var(x,noPos),noPos)),
                                   N,stack))
                   ++ r)
          [] (unifySorts(context,subst,
			 inferType(context.spc,subst,M),
			 inferType(context.spc,subst,N),
                         Some N))
%%
%% Sigma-Sigma
%%
      | (Record(fields1, _),Record(fields2, _)) -> 
	matchPairs (context,subst,insertFields stack (fields1,fields2))
%%
%% Constants
%%
      | (Fun(f1,srt1,_),Fun(f2,srt2,_)) ->
        if f1 = Equals && f2 = Equals || f1 = NotEquals && f2 = NotEquals
          then matchPairs(context, subst, stack)
        else matchBase(context,f1,srt1,f2,srt2,stack,subst,N)
      | (M, N as Fun(f2,srt2,_)) | evaluateConstantTerms?
                                && ~(hasFlexRef? M)
                                && ~(constantTerm? M)
                                && freeVarsRec M = [] ->
        let v = eval(M,context.spc) in
        if fullyReduced? v
          then
            let new_M = valueToTerm v in
            if equalTerm?(new_M, M)
              then []
            else if equalTerm?(new_M, N)
              then matchPairs(context,subst,stack)
            else []
        else []
      | (Var((n1,srt1), _),Var((n2,srt2), _)) ->  
	matchBase(context,n1,srt1,n2,srt2,stack,subst,N)
      %% Special case of Let for now
      | (Let([(VarPat((v1,srt1), _), e1)], b1, _), Let([(VarPat((v2,srt2), _), e2)], b2, _)) ->
        foldr (fn (subst, r) ->
                 let x = freshBoundVar(context,srt1) in
                 let S1 = [((v1,srt1), Var(x,noPos))] in
                 let S2 = [((v2,srt2), Var(x,noPos))] in
                 let b1 = substitute(b1,S1) in
                 let b2 = substitute(b2,S2) in
                 matchPairs (context,subst,insert(b1,b2,insert(e1,e2,stack)))
                   ++ r)
          [] (unifySorts(context,subst,srt1,srt2,None))
      | (Bind(qf1,vars1,M,_),Bind(qf2,vars2,N,_)) -> 
	if ~(qf1 = qf2) || ~(length vars1 = length vars2)
	   then []
	else
	let (S1,S2,subst,flag) = 
	    ListPair.foldr
	      (fn ((v1,s1),(v2,s2),(S1,S2,subst,flag)) -> 
	      if ~ flag
		 then (S1,S2,subst,flag)
	      else
	      case unifySorts(context,subst,s1,s2,None)   % None ??
		of subst :: _ ->                          % Need to generalize!!
		   let x = freshBoundVar(context,s1) in
		   let S1 = Cons(((v1,s1),mkVar(x)),S1) in
		   let S2 = Cons(((v2,s2),mkVar(x)),S2) in
		   (S1,S2,subst,true)
		 | [] -> (S1,S2,subst,false)) 
	      ([],[],subst,true) (vars1,vars2)
	in
	if ~flag
	   then []
	else
	let M = substitute(M,S1) in
	let N = substitute(N,S2) in
	matchPairs (context,subst,insert(M,N,stack))
      | (IfThenElse(M1,M2,M3,_),IfThenElse(N1,N2,N3,_)) -> 
	matchPairs(context,subst,insert(M1,N1,insert(M2,N2,insert(M3,N3,stack))))
      | (The ((id1,srt1),M,_),The ((id2,srt2),N,_)) -> 
        foldr (fn (subst,r) ->
                 let x = freshBoundVar(context,srt1) in
                 let S1 = [((id1,srt1),Var(x,noPos))] in
                 let S2 = [((id2,srt2),Var(x,noPos))] in
                 let M = substitute(M,S1) in
                 let N = substitute(N,S2) in
                 matchPairs (context,subst,insert(M,N,stack))
                  ++ r)
          [] (unifySorts(context,subst,srt1,srt2,Some(mkVar(id2,srt2))))
      | (M,_) -> 
% 	  let _ = writeLine "matchPair" in
% 	  let _ = writeLine(printTerm M) in
% 	  let _ = writeLine(printTerm N) in
% 	  let _ = printSubst subst in
	let srt1 = inferType(context.spc,subst,M) in
	let srt2 = inferType(context.spc,subst,N) in
	let substs = unifySorts(context,subst,srt1,srt2,Some N) in
        foldr (fn (subst, r) ->
               (case headForm(M) of
                 | [M] -> []
%
% Flexible head
%
                 | Ms as 
                   ((Apply (Fun(Op(Qualified (UnQualified,"%Flex"),_), Arrow(_,s,_),_),
                              Fun(Nat n,_,_),_))::terms) ->
                   if occursProper n N || (exists? (fn v -> ~(inVars?(v,context.boundVars))
                                                     && ~(exists? (fn t -> inVars?(v,freeVars t)) Ms))
                                             (freeVars N))
                     then [] 
                   else
                   let Ns = headForm N in
                   let substs = if length Ns = length Ms
                                  then
                                    let stack1 = foldr
                                                   (fn ((M,N),stack) -> insert(M,N,stack))
                                                   stack (zip(Ms, Ns)) in
                                    matchPairs(context,subst,stack1)
                                else []
                   in
                   if ~(substs = []) then substs
                   else
                   let termTypes = map (fn M -> inferType(context.spc,subst,M)) terms in
                   
                   %% Special case of imitation where other cases are equivalent
                   if closedTermV(N,context.boundVars)
                     && ~(exists? (existsSubTerm (fn t -> some?(isFlexVar? t))) terms)
                     && noReferencesTo?(N,terms)
                     then 
                     let pats   = map (fn srt -> WildPat(srt,noPos)) termTypes in 
                     let trm    = foldr bindPattern N pats 			  in
                     let subst  = updateSubst(subst,n,trm) in
                     matchPairs(context,subst,stack) 
                   else 
                   let vars  = map (fn srt -> freshBoundVar(context,srt)) termTypes in

% 1. Recursive matching

% This was incomplete as formulated in the LaTeX documentation.
% It is being replaced by code that maps
%  n to fn x1 -> ... fn xn -> N1 (X1 x1 ... xn) ... (Xk x1 .. xn)
% where n is |terms| and k+1 = |Ns|.

                   let pats = map (fn v -> VarPat(v,noPos)) vars in
                   let varTerms = map (fn v -> Var(v,noPos)) vars in	
                   let def makeMatchForSubTerm (trm, bound_vs) =
                         let srt = inferType(context.spc,subst,trm) in
                         let srt = foldr mkArrow srt (termTypes ++ map(fn(_,ty) -> ty) bound_vs) in
                         let v = freshVar(context,srt) in
                         (foldl (fn (t1,t2)-> Apply(t1,t2,noPos)) v (varTerms ++ map mkVar bound_vs),
                          (foldl (fn (t1,t2)-> Apply(t1,t2,noPos)) v (terms ++ map mkVar bound_vs), trm))

                   in
                   let (sound,N1,pairs) = 
                       case Ns
%
% When matching against a record X M1 ... Mn = (N1,...,Nk)
% create the instantiation X |-> fn x1 .. xn -> (X1 x1..xn,...,Xk x1..xn) 
% and also the matching pairs X1 M1 ... Mn = N1 ...  Xk M1 ... Mn = Nk
%
                         of [Record(fields, _)] -> 
                           let ls = map (fn (l,trm) -> 
                                           let (s_tm,pr) = makeMatchForSubTerm (trm,[]) in
                                           ((l, s_tm), pr))
                                      fields
                           in
                           let (fields,pairs) = unzip ls in
                           (true, Record(fields,noPos), pairs)

                         | [IfThenElse(p,q,r,a)] ->
                           let (p1,p_pr) = makeMatchForSubTerm (p,[]) in
                           let (q1,q_pr) = makeMatchForSubTerm (q,[]) in
                           let (r1,r_pr) = makeMatchForSubTerm (r,[]) in
                           (true, IfThenElse(p1,q1,r1,a), [p_pr,q_pr,r_pr])
                         | [Bind(qf,vs,bod,a)] ->
                           let (bod1,bod_pr) = makeMatchForSubTerm(bod,vs) in
                           (true, Bind(qf,vs,bod1,a), [bod_pr])
 %                   %% case expression
                         | [Lambda(matches,a), case_arg] ->
                           let (matches1, pairs) =
                               foldr (fn ((p,c,t), (matches1, pairs)) ->
                                        let pvs = patternVars p in
                                        let (c1,c_pr) = makeMatchForSubTerm (c,pvs) in
                                        let (t1,t_pr) = makeMatchForSubTerm (t,pvs) in
                                        (Cons((p,c1,t1), matches1),
                                         [c_pr,t_pr] ++ pairs))
                                 ([],[]) matches
                           in
                           let (case_arg1,case_arg_pr) = makeMatchForSubTerm (case_arg,[]) in
                           (true, mkApply(Lambda(matches1,a),case_arg1), Cons(case_arg_pr, pairs))

% When matching against an application X M1 .. Mn = N1 ... Nk
% create the instantiation  X |-> fn x1 .. xn -> N1 (X2 x1..xn) ... (Xk x1..xn) 
% and also the matching pairs X2 M1 ... Mn = N2 ...  Xk M1 ... Mn = Nk
%
%
% N should be a closed term for this step to be legal/sound.
%
                           | N::Ns ->
                             %% Added Ns ~= [] because otherwise redundant with Imitation
                             if Ns ~= [] && closedTermV(N,context.boundVars)
                               then 
                                 let ls = map (fn n -> makeMatchForSubTerm(n,[])) Ns in
                                 let (Ns,pairs) = unzip ls in
                                 (true,foldl (fn (t1,t2) -> Apply(t1,t2,noPos)) N Ns,pairs)
                             else
                               (false,N,[])
                   in
                   let rec_results =
                       (if sound 
                          then
                            let N2     = foldr bindPattern N1 pats in
                            let stack1 = foldr (fn ((M,N),stack) -> insert(M,N,stack)) stack pairs in
                            matchPairs(context,updateSubst(subst,n,N2),stack1)
                        else [])
                   in
                   if length rec_results  > resultLimitHOM
                     then rec_results
                   else
                   let proj_results =
                       rec_results
                      ++
% 2. Projection.
                       (let projs  = projections (context,subst,terms,vars,srt2) in
                          (flatten
                             (map 
                                (fn (subst,proj) -> 
                                   let subst = updateSubst(subst,n,proj) in
                                   %% Repeat with the updated substitution, gets rid
                                   %% of the flexible head.
                                   let result = matchPairs(context,subst,insert(M,N,stack)) in
                                   result)
                                projs)))
                    in
                    if length proj_results > resultLimitHOM
                      then proj_results
                    else
                      proj_results
                        ++ 
                        % 3. Imitation.
                        (if closedTermV(N,context.boundVars)
                           then 
                             let pats   = map (fn srt -> WildPat(srt,noPos)) termTypes in 
                             let trm    = foldr bindPattern N pats in
                             let subst  = updateSubst(subst,n,trm) in
                             matchPairs(context,subst,stack) 
                         else [])
                        
              | Ms -> 
%%
%% Rigid head
%%
	        case insertPairs(Ms,headForm N,stack)
                  of Some stack -> matchPairs(context,subst,stack)
                   | None -> []) ++ r)
          [] substs
     in
     let _ = if !debugHOM > 0
               then if result = []
                  then (writeLine("MatchPairs failed!");
                         case next stack0
                           of None -> ()
                            | Some(stack,M,N) ->
                              writeLine (printTerm (dereference subst M) ^ " =~= "^ printTerm N)
                             )
                  else (writeLine("MatchPairs: "^show(length result)^" results.");
                        if length result > 0 then
                          ((case next stack0 of
                              | Some(stack,M,N) -> 
                                writeLine (printTerm (dereference subst M) ^ " = = "^ printTerm N)
                              | None -> ()) ;
                           app printSubst result)
                        else ())
              else ()
     in
     result

  op  insertPairs : List MS.Term * List MS.Term * Stack -> Option Stack

  def insertPairs(Ms,Ns,stack): Option Stack = 
      case (Ms,Ns)
	of (M::Ms,N::Ns) -> insertPairs(Ms,Ns,insert(M,N,stack))
	 | ([],[]) -> Some stack
	 | _ -> None


  def updateSubst((sortSubst,termSubst,condns),n,M) = 
      case isFlexVar?(M)
	of Some m | n = m -> (sortSubst,termSubst,condns)
	 | _ -> (sortSubst,NatMap.insert(termSubst,n,M),condns)

%%
%% Infer type with sort dereferencing
%%
 op inferType: Spec * SubstC * MS.Term -> Sort
 def inferType(spc,subst,N) = 
     case N
       of Apply(t1,t2,_) -> 
	  let srt = dereferenceSort(subst,inferType(spc,subst,t1)) in
	  (case Utilities.rangeOpt(spc,srt)
	     of Some rng -> rng
	      | None -> 
		(% System.print N; printSpecWithSortsToTerminal spc;
                 System.fail 
                   ("Could not extract type for "^
                      printTermWithSorts N)))
        | Bind _ -> boolSort
        | Record(fields,a) -> 
	  Product(map (fn (id,t)-> (id,inferType(spc,subst,t))) fields,a)
        | Let(_,term,_) -> inferType(spc,subst,term)
        | LetRec(_,term,_) -> inferType(spc,subst,term)
        | Var((_,srt), _) -> srt
        | Fun(_,srt, _) -> srt
        | Lambda((Cons((pat,_,body),_)), _) -> 
	  mkArrow(patternSort pat,inferType(spc,subst,body))
        | Lambda([], _) -> System.fail "Ill formed lambda abstraction"
        | The ((_,srt),_,_) -> srt
        | IfThenElse(_,t2,t3,_) -> inferType(spc,subst,t2)
        | Seq([],a) -> Product([],a)
        | Seq([M],_) -> inferType(spc,subst,M)
        | Seq(M::Ms,a) -> inferType(spc,subst,Seq(Ms,a))
	| Any a -> Any a
        | _ -> System.fail "inferType: non-exhaustive match"


\end{spec}
{\tt matchPairs} should also handle "IfThenElse", "Let", "LetRec", "Seq", 
possibly by using pre-cooking.

\subsection{Projections}

Projections are correctly computed based on the sort structure of the flexible variable.
Thus, if 

   X : \sigma_1 --> \sigma_2 --> \cdots --> \sigma_k --> \tau

and we process the equality

   (X M_1 ... M_k)  =  N,

then we generate the terms

   \lambda x_1  .  \lambda x_2  .  ...  \lambda x_k  .  \pi(x_i)

where \pi(x_i) is a projection on x_i and has type \tau.
The projection is computed using the following recursive unification procedure:

\begin{array}{llll}
N : \sigma  \simeq  \tau &  \{ N \} & \mbox{if \sigma\sqcap\tau \neq \bot} \\
N : \sigma_1 \times \sigma_2  \simeq  \tau & N.1: \sigma_1 \simeq \tau   \cup   
					     N.2: \sigma_2 \simeq \tau \\
N : \sigma_1 --> \sigma_2 \simeq  \tau 
			& (N\;(F\; x_1\;...\; x_n)):\sigma_2 \simeq \tau 
\end{array}
\]

\begin{spec}

  op projections : Context * SubstC * List MS.Term * List Var * Sort 
				-> List (SubstC * MS.Term)

  def projectTerm (fields,label,srt,N):MS.Term = 
      mkApply(mkFun(Project label,mkArrow(Product(fields,noPos),srt)),N)

  def projections (context,subst,(* terms *)_,vars,srt) =
      let
	  def projectSort(srt1,N) = 
	      (case unifySorts(context,subst,srt1,srt,None)  % None ??
		 of [] -> []
		  | subst :: _ -> [(subst,N)])    % Need to generalize!
	      ++
	      (case dereferenceSort(subst,srt1)
		 of Product(fields, _) -> 
		    flatten 
			(map (fn (l,s) -> 
			      projectSort(s,projectTerm(fields,l,s,N))) fields)
		  | Arrow(srt1,srt2,_) -> 
		    let srt1 = foldr mkArrow srt1 (map (fn (_,s) -> s) vars) in
		    let X = freshVar(context,srt1) in
		    let trm = foldl (fn (t1,v) -> mkApply(t1,mkVar(v))) X vars in
		    projectSort(srt2,mkApply(N,trm)) 
		  | _ -> [])
      in
      let terms = map (fn (x,s) -> projectSort(s,mkVar(x,s))) vars in
      let terms = flatten terms in
      let terms = map (fn (subst,M) -> 
                         (subst,foldr (fn(v,M) -> bindPattern(mkVarPat(v),M)) M vars))
                    terms 
      in
        let _ = if !debugHOM > 0 then
           (writeLine("Projections");
              app (fn (_,tm)  -> writeLine(printTerm tm)) terms)
              else () in

      terms

\end{spec}
 \subsection{Recursive matching utilities}

  Constants and bound variables are matched using {\tt matchBase}.
\begin{spec}

  op matchBase : [a] Context * a * Sort * a * Sort * Stack * SubstC * MS.Term-> List SubstC
  def matchBase (context,x,srt1,y,srt2,stack,subst,N) =
    % let _ = writeLine("matchBase: "^anyToString x^" =?= "^ anyToString y^"\n"^printSort srt1^"\n"^printSort srt2) in
      if x = y
	 then 
	    foldr (fn (subst,r) -> matchPairs(context, subst,stack) ++ r)
              [] (unifySorts(context,subst,srt1,srt2,Some N))
      else []


(* lambda-binders are matched by matching every pair of pattern against eachother.
  The pair of patterns that are compared must match precisely the same instances, thus,
  for example embed patterns must be equal.
  The variables that are bound by the patterns are substituted into the conditions and
  respective bodies such that variables bound at the same positions are equal.
*)

  def matchRules(context,subst,stack,rules1,rules2,v_subst) = 
      case (rules1,rules2)
        of ((pat1,cond1,body1)::rules1,(pat2,cond2,body2)::rules2) -> 
	   (case matchPattern(context,pat1,pat2,[],[],[])
	      of Some (S1,S2) -> 
		 let stack = insert(substitute(body1,S1),substitute(body2,S2),stack) in
		 let stack = insert(substitute(cond1,S1),substitute(cond2,S2),stack) in
		 matchRules(context,subst,stack,rules1,rules2,S2++v_subst)
	       | None -> [])
	 | ([],[]) ->
           let results = matchPairs(context,subst,stack) in
           map (fn (m1,m2,condns) ->
                  (m1,m2,map (fn t -> invertSubst(t,v_subst)) condns))
             results
	 | _ -> []

(* matchPattern, matchPatterns, and matchIrefutablePattern recurse on
  aligning the same pattern matches. *)

   op matchPattern(context: Context, pat1: Pattern, pat2: Pattern, pairs: List(Pattern * Pattern),
                   S1: VarSubst, S2: VarSubst)
      : Option (VarSubst * VarSubst) = 
      case (pat1,pat2)
        of (VarPat((x,srt1), _),VarPat((y,srt2), _)) ->
           let z  = freshBoundVar(context,srt1) in
           let S1 = Cons(((x,srt1),mkVar(z)),S1) in
           let S2 = Cons(((y,srt2),mkVar(z)),S2) in
           matchPatterns(context,pairs,S1,S2)
         | (EmbedPat(c1,None,srt1,_),EmbedPat(c2,None,srt2,_)) -> 
           if c1 = c2
               then matchPatterns(context,pairs,S1,S2)
           else None
         | (EmbedPat(c1,Some pat1,srt1,_),EmbedPat(c2,Some pat2,srt2,_)) -> 
           if c1 = c2
               then matchPattern(context,pat1,pat2,pairs,S1,S2)
           else None
         | (RecordPat(fields1, _),RecordPat(fields2, _)) -> 
           let pairs1 = ListPair.map (fn ((_,p1),(_,p2))-> (p1,p2)) (fields1,fields2) in
           matchPatterns(context,pairs1 ++ pairs,S1,S2)
         | (WildPat(srt1, _),WildPat(srt2, _)) -> Some(S1,S2)
         | (StringPat(s1, _),StringPat(s2, _)) -> 
           if s1 = s2 then matchPatterns(context,pairs,S1,S2) else None
         | (BoolPat(b1, _),BoolPat(b2, _)) -> 
           if b1 = b2 then matchPatterns(context,pairs,S1,S2) else None
         | (CharPat(c1, _),CharPat(c2, _)) -> 
           if c1 = c2 then matchPatterns(context,pairs,S1,S2) else None
         | (NatPat(i1, _),NatPat(i2, _)) -> 
           if i1 = i2 then matchPatterns(context,pairs,S1,S2) else None
%
% Possibly generalize the matching to include matching on (t1,t2), assuming t1 can
% contain meta variables.
% 
         | (QuotientPat(p1,t1,_),QuotientPat(p2,t2,_)) -> 
           if t1 = t2 then matchPatterns(context,pairs,S1,S2) else None
         | (RestrictedPat(p1,t1,_),RestrictedPat(p2,t2,_)) -> 
           if equalTerm?(t1,t2) then matchPatterns(context,pairs,S1,S2) else None
         | _ -> 
            case matchIrefutablePattern(context,pat1,S1)
              of None -> None
               | Some S1 -> 
            case matchIrefutablePattern(context,pat2,S2)
              of Some S2 -> matchPatterns(context,pairs,S1,S2)
               | None -> None

  op matchPatterns(context: Context, pairs: List(Pattern * Pattern), S1: VarSubst, S2: VarSubst)
     : Option (VarSubst * VarSubst) = 
     case pairs
       of (p1,p2)::pairs -> matchPattern(context,p1,p2,pairs,S1,S2)
        | [] -> Some (S1,S2)	   
  op matchIrefutablePattern(context: Context, pat: Pattern, S: VarSubst)
     : Option VarSubst = 
     case pat
       of WildPat _ -> Some S
        | VarPat((x,s),a) -> 
          let z = freshBoundVar(context,s) in 
          Some(Cons(((x,s),Var(z,a)),S))
        | RecordPat(fields, _) -> 
          let
              def loop(fields,S): Option VarSubst = 
                  case fields
                    of (l,p)::fields -> 
                       (case matchIrefutablePattern(context,p,S)
                          of Some S -> loop(fields,S)
                           | None -> None)
                     | [] -> Some S
          in
               loop(fields,S)
        | _ -> None


\end{spec}

\subsection{Occurs check}
Our matching algorithm includes the occurs check, as there we do not require the 
input to be a matching problem. In fact, in the glue code generation, proper 
skolemization transforms a proper matching problem into an inproper one.

\begin{spec}
  op occursProper : Nat -> MS.Term -> Boolean
  def occursProper n M = 
      case isFlexVar?(M)
	of Some _ -> false
	 | None -> occurs n M

  op occurs : Nat -> MS.Term -> Boolean
  op occursP : [a] Nat -> a * MS.Term -> Boolean
  def occursP n (_,M) = occurs n M
  def occurs n term = 
      case term
        of Var _ -> false
	 | Fun _ -> false
	 | Apply(M,N,_) -> 
	   (case isFlexVar?(term)
	      of Some m -> n = m
	       | None -> occurs n M || occurs n N)
	 | Record(fields, _) -> 
	   exists? (occursP n) fields
	 | Lambda(rules, _) -> 
	   exists? (fn (_,cond,body) -> 
			occurs n cond || occurs n body) rules
	 | Seq(Ms, _) -> exists? (occurs n) Ms
	 | IfThenElse(M1,M2,M3,_) -> 
	   occurs n M1 || occurs n M2 || occurs n M3
	 | The (var,M,_) -> occurs n M
	 | Bind(_,vars,M,_) -> occurs n M
	 | Let(decls,M,_) -> 
	   occurs n M || exists? (occursP n) decls
	 | LetRec(decls,M,_) ->
	   occurs n M || exists? (occursP n) decls
\end{spec}

\subsection{Closed terms}

\begin{description}
\item[{\tt closedTerm}]
 determines whether a term contains any 
        free variables or not.
\item[{\tt closedTermV}] detects existence of 
       free variables not included in the
        argument 
\end{description}

\begin{spec}

  op closedTerm : MS.Term -> Boolean
  op closedTermV : MS.Term * List Var -> Boolean

  def closedTerm(term) = closedTermV(term,[])

%  def patternVars(pat:Pattern) = 
%      case pat
%        of VarPat(v, _) -> [v]
%	 | WildPat _ -> []
%	 | RecordPat(fields, _) -> 
%	   flatten (map (fn (_,p) -> patternVars p) fields)
%	 | EmbedPat(_,None,_,_) -> []
%	 | EmbedPat(_,Some p,_,_) -> patternVars p
%	 | QuotientPat(p,t,_) -> patternVars p
%	 | AliasPat(p1,p2,_) -> patternVars p1 ++ patternVars p2 
%	 | _ -> []

  def closedTermV(term,bound) = 
      case term
        of Var(v, _) -> exists? (fn w -> v = w) bound	        
	 | Fun _ -> true
	 | Apply(M,N,_) -> closedTermV(M,bound) && closedTermV(N,bound)
	 | Record(fields, _) -> 
	   forall? (fn (_,M) -> closedTermV(M,bound)) fields
	 | Lambda(rules, _) -> 
	   forall? (fn (pat,cond,body) -> 
			let bound = patternVars(pat) ++ bound in
			(closedTermV(cond,bound) && 
			 closedTermV(body,bound))) rules
	 | Seq(Ms, _) -> forall? (fn M -> closedTermV(M,bound)) Ms
	 | IfThenElse(M1,M2,M3,_) -> 
	   closedTermV(M1,bound) && 
	   closedTermV(M2,bound) && 
	   closedTermV(M3,bound)
	 | Bind(_,vars,M,_) -> closedTermV(M,vars ++ bound)
	 | The (var,M,_) -> closedTermV (M,Cons(var, bound))
	 | Let(decls,M,_) -> 
	   forall? (fn (_,M) -> closedTermV(M,bound)) decls 
	   && 
	   (let bound = foldr 
		(fn ((pat,_),bound) -> patternVars pat ++ bound) 
		bound decls 
	   in
	   closedTermV(M,bound) )
	 | LetRec(decls,M,_) ->
	   let bound = (map (fn (v,_) -> v) decls) ++ bound in
	   closedTermV(M,bound) && 
	   (forall? (fn (_,M) -> closedTermV(M,bound)) decls) 

 op noReferencesTo?(tm: MS.Term, tms: List MS.Term): Boolean =
   ~(existsSubTerm (fn t -> termIn?(t,tms)) tm)

(* Sort unification}
 Unification of sorts is similar to the one in AstTypes.
 It uses a list of already processed sort pairs to avoid cycling through
 recursive definitions.
*)

  type Unification = 
    | NotUnify  Sort * Sort 
    | Unify     SubstC 

  op  unifyL : [a] SubstC * Sort * Sort * List(a) * List(a) * List (Sort * Sort) * Option MS.Term *
                  (SubstC * a * a * a * List(Sort * Sort) * Option MS.Term -> List Unification)
                  ->  List Unification
  def unifyL(subst,srt1,srt2,l1,l2,equals,optTerm,unify): List Unification = 
      case (l1,l2)
        of ([],[]) -> [Unify subst]
         | (e1::l1,e2::l2) -> 
	   (foldr (fn (r1,r) ->
                     case r1 of
                       | Unify subst -> unifyL(subst,srt1,srt2,l1,l2,equals,None,unify) ++ r
                       | notUnify -> Cons(notUnify, r) )
              []  (unify(subst,e1,e2,e1,equals,optTerm)))
         | _ -> [NotUnify(srt1,srt2)]

  op  occursRec : SubstC * String * Sort -> Boolean
  def occursRec (subst,v,srt) = 
      case srt 
        of Base(_,srts,_) -> exists? (fn s -> occursRec(subst,v,s)) srts
 	 | Arrow(s1,s2,_) -> occursRec(subst,v,s1) || occursRec(subst,v,s2)
	 | Product(fields, _) -> exists? (fn (_,s) -> occursRec(subst,v,s)) fields
	 | CoProduct(fields, _) -> 
	   exists? (fn(_,None)-> false | (_,Some s)-> occursRec(subst,v,s)) fields
	 | TyVar(w, _) -> 
	   (case StringMap.find(subst.1,w)
	      of Some s -> occursRec (subst,v,s)
	       | None -> v = w) 
	 | Subsort(s,_,_) -> occursRec(subst,v,s)
	 | Quotient(s,_,_) -> occursRec(subst,v,s)
         | Boolean _ -> false
%         | _ -> let _ = writeLine("occursRec missing case: "^printSort srt) in
%                false

  def dereferenceSort(subst:SubstC,srt) = 
      case srt
        of TyVar(v, _) -> 
	   (case StringMap.find(subst.1,v)
              of Some srt -> dereferenceSort(subst,srt)	
	       | None -> srt)
	 | _ -> srt

  %% Not symmetric wrt subsorts
  op unifySorts(context: Context,subst: SubstC,srt1: Sort,srt2: Sort,optTerm: Option MS.Term): List SubstC = 
%      let _ = case optTerm of None -> () | Some t -> writeLine("Term: "^printTerm t) in
      let spc = context.spc in
      let
	def insert(v,srt,(sortSubst,termSubst,condns)): SubstC = 
	    (StringMap.insert(sortSubst,v,srt),termSubst,condns)
        def addCondition(condn: MS.Term, subst as (sortSubst,termSubst,condns): SubstC): SubstC =
          if trueTerm? condn || termIn?(condn,condns) then subst
            else (sortSubst,termSubst,Cons(condn,condns))
	def unifyCP(subst,srt1,srt2,r1,r2,equals):List Unification = 
	    unifyL(subst,srt1,srt2,r1,r2,equals,None,
		   fn(subst,(id1,s1),(id2,s2),_,equals,_) -> 
		      if id1 = id2 
			then 
			(case (s1,s2)
			   of (None,None) -> [Unify subst] 
			    | (Some s1,Some s2) -> unify(subst,s1,s2,s1,equals,None)
			    | _ -> [NotUnify(srt1,srt2)])
		      else [NotUnify(srt1,srt2)])
	def unifyP(subst,srt1,srt2,r1,r2,equals): List Unification = 
	    unifyL(subst,srt1,srt2,r1,r2,equals,None,
		   fn(subst,(id1,s1),(id2,s2),_,equals,_) -> 
		      if id1 = id2 
			then unify(subst,s1,s2,s1,equals,None)
		      else [NotUnify(srt1,srt2)])
	def unify(subst,srt1:Sort,srt2:Sort,srt1_orig:Sort,equals,optTerm: Option MS.Term): List Unification =
            % let _ = writeLine("Matching "^printSort srt1^" --> "^printSort(dereferenceSort(subst,srt1))^" with \n"
            %                   ^printSort srt2^" --> "^printSort(dereferenceSort(subst,srt2))) in
	    case (dereferenceSort(subst,srt1), dereferenceSort(subst,srt2))
	      of (Boolean _, Boolean_) -> [Unify subst]
               | (CoProduct(r1,_),CoProduct(r2,_)) -> 
		 unifyCP(subst,srt1,srt2,r1,r2,equals)
	       | (Product(r1,_),Product(r2,_)) -> 
		 unifyP(subst,srt1,srt2,r1,r2,equals)
	       | (Arrow(t1,t2,_),Arrow(s1,s2,_)) -> 
		 foldr (fn (r1,r) ->
                          case r1 of
                            | Unify (subst) -> unify(subst,t2,s2,t2,equals,None) ++ r
                            | notUnify -> Cons(notUnify, r))
                   [] (unify(subst,t1,s1,t1,equals,None))
	       | (Quotient(ty1,trm1,_),Quotient(ty2,trm2,_)) -> % Shouldn't happen anymore
		 if equalTerm?(trm1, trm2)
		    then unify(subst,ty1,ty2,ty1,equals,None)
		 else [NotUnify (srt1,srt2)]
	       | (Subsort(ty1,p1,_),Subsort(ty2,p2,_))
                   | equalTermStruct?(p1,p2) || equalTermStruct?(dereferenceAll subst p1, dereferenceAll subst p2) ->
                 unify(subst,ty1,ty2,srt1_orig,equals,optTerm)
	       | (bsrt1 as Base(id1,ts1,_), bsrt2 as Base(id2,ts2,_)) -> 
		 if exists? (fn p -> p = (bsrt1,bsrt2)) equals
		    then [Unify subst]
		 else 
		 if id1 = id2 
		    then unifyL(subst,bsrt1,bsrt2,ts1,ts2,equals,None,unify)
	         else
                 (case (tryUnfoldBase spc bsrt1, tryUnfoldBase spc bsrt2) of
                    | (None, None) -> [NotUnify (bsrt1,bsrt2)]
                    | (Some s1, Some s2) -> unify(subst,s1,s2,srt1_orig,
                                                  Cons((bsrt1,bsrt2),equals),optTerm)
                    | (Some s1, None)    -> unify(subst,s1,bsrt2,srt1_orig,
                                                  Cons((bsrt1,bsrt2),equals),optTerm)
                    | (None, Some s2)    -> unify(subst,bsrt1,s2,srt1_orig,
                                                  Cons((bsrt1,bsrt2),equals),optTerm))
	       | (TyVar(v, _),TyVar(w, _)) -> 
		 if v = w then [Unify subst] else [Unify (insert(v,srt2,subst))]
	       | (TyVar(v, _),_) -> 
		     if occursRec(subst,v,srt2) 
			 then [NotUnify (srt1,srt2)]
		     else [Unify(insert(v,srt2,subst))]
	       | (_,TyVar(v, _)) -> 
		     if occursRec(subst,v,srt1) 
			 then [NotUnify (srt1,srt2)]
		     else [Unify(insert(v,srt1,subst))]
	       | (bsrt1 as Base _, bsrt2)
                   | some?(tryUnfoldBase spc bsrt1) && ~(possiblySubtypeOf?(bsrt2, bsrt1, spc))-> 
                 let Some s1 = tryUnfoldBase spc bsrt1 in
                 unify(subst,s1,bsrt2,srt1_orig,Cons((bsrt1,bsrt2),equals),optTerm)
	       | (bsrt1, bsrt2 as Base _)
                   | some?(tryUnfoldBase spc bsrt2) && ~(possiblySubtypeOf?(bsrt1, bsrt2, spc))->
		 let Some s2 = tryUnfoldBase spc bsrt2 in
		 unify(subst,bsrt1,s2,srt1_orig,Cons((bsrt1,bsrt2),equals),optTerm)
               %% Analysis could be smarter here so that order of subtypes is not so important
               | (bsrt1 as Subsort(ty1 ,p1, _), ty2) | ~(possiblySubtypeOf?(ty2, bsrt1, spc)) ->
                 % let _ = writeLine(case optTerm of None -> "No term" | Some t -> "Term: "^printTerm t) in
                 (case optTerm of
                       | None -> [NotUnify(srt1,srt2)]
                       | Some tm ->
                         case unify(subst,ty1,ty2,srt1_orig,equals,optTerm) of
                           | (Unify subst) :: _ ->    % Should generalize
                             let p1 = dereferenceAll subst p1 in
                             % let _ = writeLine("Pred: "^printTermWithSorts p1) in
                             % let _ = printSubst subst in
                             let condn = simplifiedApply(p1,tm,context.spc) in
                             % let _ = writeLine("Condn: "^printTermWithSorts condn) in
                             if falseTerm? condn then [NotUnify(srt1,srt2)]
                             else [Unify(addCondition(condn, subst))]
                           | result -> result)
                 ++ (case srt1_orig of
                    | TyVar(v,_) | equalType?(stripSubsorts(spc,ty1), stripSubsorts(spc,ty2)) ->
                      %% If we are matching a type variable then loosen match of variable
                      %% Could using ty2 cause overshoot?
                      [Unify(insert(v,ty2,subst))]
                    | _ -> [])
	       | (ty,Subsort(ty2,_,_)) -> unify(subst,ty,ty2,srt1_orig,equals,optTerm)
	       | _ -> [NotUnify(srt1,srt2)]
      in
      let results = unifyL(subst,srt1,srt2,[srt1],[srt2],[],optTerm,unify) in
      let good_results = filter (embed? Unify) results in
      let results = if good_results = [] then results else good_results in
      foldr (fn (r1,r) ->
             case r1 of
               | NotUnify (s1,s2) -> 
                 (if !debugHOM > 0 then (writeLine (printSort s1^" ! = "^printSort s2);
                                         printSubst subst)
                  else ();
                  r)
               | Unify subst ->
                 (if !debugHOM > 0 then (writeLine (printSort srt1^" =t= "^printSort srt2);
                                         printSubst subst)
                    else (); 
                  Cons(subst,r)))
        [] results

(* Normalization
To make the matching steps easier we normalize specifications
before matching by deleting {\tt IfThenElse}, {\tt Let}, and 
{\tt LetRec}, replacing these by function symbols and applications.
*)

  op doNormalizeTerm : Spec -> MS.Term -> MS.Term
  def doNormalizeTerm spc term = 
    case term of
      | Let ([(pat,N)],M,a) -> Apply (Lambda([(pat,trueTerm,M)],a),N,a)
      | Let (decls,M,a) -> 
         let (pats,Ns) = unzip decls in
          Apply (Lambda([(mkTuplePat pats,trueTerm,M)], a),mkTuple Ns,a)
%       | IfThenElse (M,N,P) -> 
%          let srt = inferType(spc,N) in
%          Apply(Fun(Op(Qualified("TranslationBuiltIn","IfThenElse"),Nonfix),
%                Arrow(mkProduct [boolSort,srt,srt],srt)),
%                mkTuple [M,N,P])
%       | LetRec(decls,M,_) -> 
%          System.fail "Replacement of LetRec by fix has not been implemented"
      | Seq (Ms,a) -> 
         let
            def loop Ms = 
              case Ms of
                | [] -> mkTuple []
                | [M] -> M
                |  M::Ms -> 
                    let srt = Utilities.inferType(spc,M) in
                      Apply(bindPattern(WildPat(srt,a),loop Ms),M,a)
          in
            loop Ms
       | term -> term

  def normalizeTerm (spc:Spec) = 
      let doTerm = doNormalizeTerm spc in
      mapTerm(doTerm,fn s -> s,fn p -> p)

  def normalizeSpec (spc:Spec) =
      let doTerm = doNormalizeTerm spc in
      mapSpec(doTerm,fn s -> s,fn p -> p) spc

  def doDeNormalizeTerm(term:MS.Term):MS.Term = 
      case term
	of Apply(Lambda([(WildPat _,Fun(Bool true,_,_),M)], _),N,a) -> 
	   Seq([N,M],a)
	 | Apply(Lambda([(pat,Fun(Bool true,_,_),M)], _),N,a) -> 
	   Let([(pat,N)],M,a)
%	 | Apply(Fun(Op(Qualified("TranslationBuiltIn","IfThenElse"),
%		     Nonfix),_),Record [(_,M),(_,N),(_,P)]) -> 
%	   IfThenElse(M,N,P)
	 | term -> term 

  def deNormalizeSpec = 
      mapSpec(doDeNormalizeTerm,fn s -> s,fn p -> p) 

  def deNormalizeTerm  = 
      mapTerm(doDeNormalizeTerm,fn s -> s,fn p -> p)


 op makeContext : Spec -> Context

 def makeContext spc = 
     {
	spc        = spc,
	trace      = true,
	traceDepth = Ref 0,
	traceIndent = Ref 0,
        boundVars  = [],
	counter    = Ref 1
     }
 
 op setBound : Context * List Var -> Context
 def setBound({spc,trace,traceDepth,traceIndent,boundVars,counter},bv) = 
     {spc = spc,trace = trace,
      traceDepth = traceDepth,
      traceIndent = traceIndent,
      boundVars = bv,counter = counter}


  op [a] printSubst: StringMap(ASort a) * NatMap.Map(ATerm a) * List (ATerm a) -> ()
  def printSubst(sortSubst,termSubst,condns) = 
      (writeLine "---------- substitution ---------";
	StringMap.appi 
	(fn (s,srt) -> 
	     writeLine(s^" |-> "^printSort srt^" "))
	sortSubst;
       writeLine "";
       NatMap.appi
	(fn (i,trm) -> 
	     writeLine(Nat.show i^" |-> "^ printTerm trm^" "))
	termSubst;
       writeLine "";
       if condns = [] then ()
         else (writeLine "Conditions:";
               List.app (fn t -> writeLine(printTerm t)) condns);
               writeLine "")

(* Freeze and thaw type variables in term
In order to ensure that type variables in a term to be rewritten are not
participating in unification we introduce freeze and thaw operations.
*)

 def freezeTerm(spc,term:MS.Term) = 
     let term = normalizeTerm spc term in
     let
	doFreeze = fn (s as TyVar _) -> Base(mkUnQualifiedId("TypeVar!"),[s],noPos)
		  | s -> s
     in
     mapTerm(fn tm -> tm,doFreeze,fn p -> p) term

 def thawTerm(term:MS.Term) =
     let term = deNormalizeTerm term in
     let
	doThaw = fn(Base(Qualified (UnQualified,"TypeVar!"),[s],_)) -> s
		  | s -> s
     in
     mapTerm(fn tm -> tm,doThaw,fn p -> p) term

endspec

