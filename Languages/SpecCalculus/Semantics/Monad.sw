\section{The Specware Environment Monad}

The environment is the monadic context for the spec calculus interpreter.
The monad handles, state, and exceptions. It should handle IO but perhaps
later. In principle, the datatype should be defined compositionally but
this isn't supported as yet. 

\begin{spec}
let BaseMonad = spec
  import /Library/Structures/Data/Monad/State
  import Exception
endspec in
SpecCalc qualifying spec
  import translate (translate BaseMonad
    by {Monad.Monad +-> SpecCalc.Env})
    by {Monad._ +-> SpecCalc._}
  import /Library/IO/Primitive/IO
  import Value
  import Wizard  % op specwareWizard? : Boolean

  %% To avoid name clashes, define undefinedGlobalVariable after importing 
  %% translated Monad stuff, as opposed to defining it in Exception.
  def SpecCalc.undefinedGlobalVariable (name : String) : Exception =
    UndefinedGlobalVar name

\end{spec}

The Monad/State spec supplies declarations of ths type Monad and the
operators monadSeq, monadBind and return. It also defines monadic
functions for creating, reading and writing both global and local
variables.

The result of a statement is \Op{Ok} or an exception.

\begin{spec}
  type Result a =
    | Ok a
    | Exception Exception
\end{spec}

Now we define the type for an state / exception monad. 

\begin{spec}
  type SpecCalc.Env a = State -> (Result a) * State
  type SpecCalc.State = {exceptions : List Exception} % for deferred processing
    op initialState : State
   def initialState = {exceptions = []}
\end{spec}

This runs a monadic program and lifts the result out of the monad.

\begin{spec}
  op run : [a] Env a -> a
  def run f = 
    case f initialState of
      | (Ok x, state) ->
        (case state.exceptions of
	   | [] -> x
	   | exceptions ->
	     fail (foldl (fn (s, exception) -> s ^ "\n" ^ (printException exception))
		         "run: uncaught exceptions:\n  "
			 (reverse exceptions)))
      | (Exception exception, _) -> 
        fail ("run: uncaught exception:\n  " ^ (printException exception))
\end{spec}

Next we define the monad sequencing operators.  The names of the operators
are fixed. The names are generated by the MetaSlang parser.  The first
operator binds the output of the first operation.

\begin{spec}
  % op monadBind : [a,b] (Env a) * (a -> Env b) -> Env b
  def SpecCalc.monadBind (f,g) =
    fn state -> (case (f state) of
      | (Ok y, newState) -> (g y newState)
      | (Exception except, newState) -> (Exception except, newState))
      %% Can't do obvious optimization of | x -> x because lhs is Env a and rhs is Env b
\end{spec}

The second simply sequences two operations without any extra binding.

\begin{spec}
  % op monadSeq : [a,b] (Env a) * (Env b) -> Env b
  def SpecCalc.monadSeq (f,g) = monadBind (f, (fn _ -> g))
\end{spec}

The unit of the monad.

\begin{spec}
  % op return : [a] a -> Env a
  def SpecCalc.return x = fn state -> (Ok x, state)
\end{spec}

Raise an exception. Should this be called throw?

\begin{spec}

  % op raise : [a] Exception -> Env a
  def SpecCalc.raise except = fn state -> 
    let _ =
      if specwareWizard? then
        fail (anyToString except) % under specwareWizard?
      else
        ()
    in
      (Exception except, state)


  %% --------------------------------------------------------------------------------
  %%  Error reporting -- normal control flow, up to a point, but record message for
  %%  delayed processing

   op raise_later : Exception -> Env ()
  def raise_later exception =
    fn state ->
      let _ =
          if specwareWizard? then
	    fail (anyToString exception) % under specwareWizard?
	  else
	    ()
      in
       (Ok (),
	{exceptions = Cons (exception, state.exceptions)})

  op  warn_later : Position * String -> Env ()
  def warn_later (pos, msg) =
    fn state ->
    (Ok (),
     {exceptions = Cons (Warning (pos, msg), state.exceptions)})

  op  raise_any_pending_exceptions : Env ()
  def raise_any_pending_exceptions =
    fn state ->
      let exceptions = reverse (foldl (fn (exceptions, e) ->
                                         case e of
                                           | Warning (pos, msg) ->
                                             let _ = toScreen ("\n; WARNING at " ^ anyToString pos ^ " " ^ anyToString msg ^ "\n") in
                                             exceptions
                                           | _ ->
                                             [e] ++ exceptions)
                                  []
                                  state.exceptions)
      in
        case exceptions of
          | [] ->  (Ok (), state << {exceptions = []})
          | _ ->
            (Exception (CollectedExceptions exceptions),
             initialState)

\end{spec}

This is meant to be for unrecoverable errors. Perhaps it should just call
\verb+fail+. Heaven help someone trying to debug monadic code within
the lisp debugger.

\begin{spec}
  op error : [a] String -> Env a
  def error str = raise (Fail str)
\end{spec}

This is for going into the Lisp Debugger when called during nomal madic execution.

\begin{spec}
  op mFail : [a] String -> Env a
  def mFail str = fn state -> let _ = (fail str) in (Exception (Fail str), state)
\end{spec}

This is used for catching an exception. We execute the first operation
If that raise an exception, then control is transferred to the second
sequence with the value of the exception passed as an argument.
Should catch save the state and restore it in the handler? No and it
probably isn't tractable anyway.

\begin{spec}
  % op catch : [a] Env a -> (Exception -> Env a) -> Env a
  def SpecCalc.catch f handler =
    fn state ->
      (case (f state) of
        | (Ok x, newState) -> (Ok x, newState)
        | (Exception except, newState) -> handler except newState)
\end{spec}

Some basic operations for debugging. There should be a proper IO monad.

\begin{spec}
  op trace : String -> Env ()
  % def trace str = return ()  % change to print when needed.
  def trace = print

  op print : String -> Env ()
  def print str = return (toScreen str) 
\end{spec}

Some hacks for twiddling memory.  hackMemory essentially calls (room nil)
in an attempt to appease Allegro CL into not causing mysterious storage 
conditions during the bootstrap. (sigh)  

\begin{spec}
  op garbageCollect : Boolean -> Env ()
  def garbageCollect full? = return (System.garbageCollect full?) 

  op hackMemory : Env ()
  def hackMemory = return (System.hackMemory ()) 
\end{spec}

The following is used when one wants to guard a command with a predicate.
The predicate is not computed in the monad.

\begin{spec}
  op when : Boolean -> Env () -> Env ()
  def when p command = if p then (fn s -> (command s)) else return ()
\end{spec}

The following is essentially a \verb+foldl+ over a list but within a
monad. We may want to change the order this function takes its arguments
and the structure of the argument (ie. curried or not) to be consistent
with other fold operations. (But they are in the order that I like :-).

This needs to go into a Monad library. The spec
Library/Structures/Data/Monad now exists but not used.

\begin{spec}
  op foldM : [a,b] (a -> b -> Env a) -> a -> List b -> Env a
  def foldM f a l =
    case l of
      | [] -> return a
      | x::xs -> {
            y <- f a x;
            foldM f y xs
          }

  op foldrM : [a,b] (a -> b -> Env a) -> a -> List b -> Env a
  def foldrM f a l =
    case l of
      | [] -> return a
      | x::xs -> {
            r_a <- foldrM f a xs;
            f r_a x
          }

\end{spec}

Analogously, this is the monadic version of \verb+map+. Both of these
need to have better names. Can we drop the 'M' suffix and
rely on the overloading?

\begin{spec}
  op mapM : [a,b] (a -> Env b) -> (List a) -> Env (List b)
  def mapM f l =
    case l of
      | [] -> return []
      | x::xs -> {
            xNew <- f x;
            xsNew <- mapM f xs;
            return (Cons (xNew,xsNew))
          }
\end{spec}

\begin{spec}
%   op getCurrentDirectory : Env String
%   def getCurrentDirectory = return currentDirectory

  op fileExistsAndReadable? : String -> Env Boolean
  def fileExistsAndReadable? fileName = return (fileExistsAndReadable fileName)
\end{spec}

\begin{spec}
endspec
\end{spec}
