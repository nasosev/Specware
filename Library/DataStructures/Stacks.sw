%Stacks qualifying   %%TODO Add this qualifier back?
spec

%% Old comment: currently we can't refine a sum type to a product
%% (TODO what about isomorphic type refinement?), so these
%% constructors must become ops, and we must use destructors instead
%% of inductive/cases defs.

%% TODO can we prove that all stacks can be made from a finite number of applications of push, starting with the empty stack?

%% TODO add a refinement of this spec in terms of the stack data type hinted at in this file (with empty and push constructors).  In progress in BasicStacks.sw

  type Stack a         % = | empty_stack | push (a*Stack a)

  %% We give semantics to stacks by making them isomorphic to lists.
  %% The declaration of stackToList gives rise to an implicit axiom
  %% that Stacks and Lists are isomorphic.  Then we define the Stack
  %% operations below in terms of their corresponding list operations.

  op [a] stackToList : Bijection(Stack a, List a)

  %% Unlike stackToList, we can give this one a definition:

  op [a] listToStack : Bijection(List a, Stack a) = inverse stackToList

  theorem listToStack_equal_listToStack is [a]
    fa(stk1 : List a, stk2 : List a) (listToStack stk1 = listToStack stk2) = (stk1 = stk2)

  %% The empty Stack corresponds to the empty list:

  op [a] empty_stack : Stack a = listToStack []

  op [a] empty_stack? (s:Stack a) : Bool = (s = empty_stack)

  %% TODO Add op to test for non-emptiness (and a type for non-empty
  %% stacks, which we could use below)?  Also add an op for the lenght
  %% of a stack?  I guess such new ops would have to be given
  %% refinements in the morphisms..

  %% The push operation on Stacks corresponds to Cons on lists:

  op [a] push (elt:a, stk:Stack a) : Stack a = listToStack (Cons(elt, stackToList stk))

  %% The pop operation on Stacks corresponds to tail on lists:

  op [a] pop (stk:Stack a | stk ~= empty_stack): Stack a = listToStack (tail (stackToList stk))
%     = case stk of | push (_,stk) -> stk

  %% The top operation on Stacks corresponds to head on lists:

  op [a] top (stk:Stack a | stk ~= empty_stack): a  = head (stackToList stk)
%      = case stk of | push (elt,_) -> elt

%% Push the elements of lst onto stk (earlier elements of lst go deeper in the stack).
%% Note that this function is tail-recursive.
%% TODO rename to pushl_aux?

  op [a] push_aux (lst:List a, stk:Stack a): Stack a =
    case lst of
      | [] -> stk
      | elt::y -> push_aux(y, push(elt, stk))

%% TODO add analogous theorem about pushl:

theorem push_aux_append is [a]
  fa(x:List a,y:List a,stk:Stack a) push_aux(x ++ y, stk) = push_aux(y, push_aux(x, stk))

%% Push the elements of lst onto stk (earlier elements of lst go shallower in the stack):

  op [a] pushl (lst:List a, stk:Stack a): Stack a = 
    push_aux(reverse(lst),stk)



%% TODO This is what I want to do for pushl but cannot, due to an Isabelle translator bug (JIRA issue SPEC-41):
%% %% Push the elements of lst onto stk (earlier elements of lst go shallower in the stack):
%% %% This op is not tail-recursive but is refined to a tail-recursive op below.

%%   op [a] pushl (lst:List a, stk:Stack a): Stack a = 
%%     case lst of
%%     | [] -> stk
%%     | elt::y -> push(elt, pushl(y,stk))
                  
%% %% Tail-recursive refinement of pushl:

%%   refine def [a] pushl (lst:List a, stk:Stack a): Stack a = 
%%     push_aux(reverse(lst),stk)



theorem push_not_empty is [a]
  fa(elt:a, stk: Stack a) (push(elt, stk) = empty_stack) = false

theorem top_push is [a]
  fa(elt:a, stk: Stack a) top(push(elt, stk)) = elt

theorem pop_push is [a]
  fa(elt:a, stk: Stack a) pop(push(elt, stk)) = stk

proof isa push_aux_append
  apply(induct "x" arbitrary: stk)
  apply(simp)
  apply(simp)
end-proof

proof isa pop_Obligation_subtype
  apply(auto simp add: List__nonEmpty_p_def empty_stack_def)
  by (metis Function__fxy_implies_inverse listToStack_def stackToList_subtype_constr) 
end-proof

proof isa top_Obligation_subtype
  by (rule pop_Obligation_subtype)
end-proof

proof isa listToStack_equal_listToStack
  by (metis Function__f_inverse_apply listToStack_def stackToList_subtype_constr)
end-proof

proof isa push_not_empty
  apply(simp add: push_def empty_stack_def listToStack_equal_listToStack)
end-proof

proof isa top_push_Obligation_subtype
  by (auto simp add: push_not_empty)
end-proof

proof isa top_push
  apply(simp add: top_def push_def listToStack_def)
  by (metis Function__f_inverse_apply hd.simps stackToList_subtype_constr)
end-proof

proof isa pop_push_Obligation_subtype
  by (rule top_push_Obligation_subtype)
end-proof

proof isa pop_push
  apply(simp add: push_def pop_def)
  by (metis Function__f_inverse_apply Function__inverse_f_apply listToStack_def stackToList_subtype_constr tl.simps(2))
end-proof

end-spec
