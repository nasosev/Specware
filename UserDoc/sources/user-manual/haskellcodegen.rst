


Generating Haskell Code
#######################

As an experimental feature, Specware provides the capability of
generating Haskell code from constructive |Metaslang| specs. Currently
all of the basic language is supported except for unnamed records.

The Haskell code generator can either be called from the |SShell| or
using the emacs interface.

There are two shell commands for generating Haskell, one that creates
modules that export everything and one that creates modules that only
export what is needed by the given spec, with unneeded ops omitted.
The latter is useful when applied to the top-level spec of interest.
The former is useful when you want code for lower-level specs that may
be used in different contexts.

.. index::
   pair: shell-command; gen-haskell

The first shell command, that exports all imports, is::

   gen-haskell <spec-term>
   
where the result of elaborating the spec term gives the spec to be
translated into Haskell. The :command:`gen-haskell` command can be
abbreviated to :command:`gen-h`. Inside the emacs interface it is simpler
to use the :kbd:`C-c h` command (``sw:convert-spec-to-haskell``)
which has the same effect but also visits the generated Haskell file.
For a single file spec, the generated Haskell file has the same name
as the Specware file with extension "hs" instead of "sw" and is put in
the "Haskell" subdirectory of the diretory containing the spec. A spec
in a multi-spec file also has the local name of the spec appended to
the file name. Haskell code is generated for any imported specs if
necessary. The Haskell code for the Base library is pre-generated and
stored in the directory ``%SPECWARE4%\Library\Haskell``, so this
directory must be on your |Haskell| system's load path in order to
process the generated |Haskell| files. The Base library and its
translation into |Haskell| provides good examples of the |Haskell|
generator and how to control it using the pragmas documented below.

.. index::
   pair: shell-command; gen-haskell-top

The second shell command for use with top-level specs is::

   gen-haskell-top <spec-term>
   
where the result of elaborating the spec term gives the spec to be
translated into Haskell. The :command:`gen-haskell` command can be
abbreviated to :command:`gen-ht`. Inside the emacs interface it is simpler
to use the :kbd:`C-c H` command (``sw:convert-top-spec-to-haskell``)
which has the same effect but also visits the generated Haskell file.
This also generates modules for all imported spec.

The names of the generated Haskell modules are the same as that for
the :command:`gen-haskell` command, but the files generated for specs in
different directories are put in sub-directories of the top-level
Haskell directory. For specs in sub-directories of the top-level spec,
the generated module files are in the corresponding sub-directory of
the top-level Haskell directory. For example, given the command ``gen-
haskell-top /A/B/C/Main.sw``\ , the top-level module is stored in file
``/A/B/C/Haskell/Main.hs`` and if this spec imports (possibly
indirectly) the spec ``/A/B/C/D/E/F.sw`` the corresponding module is
generated as ``/A/B/C/Haskell/D/E/F.hs``\ .

For specs in parent or sibling directories of the top-level spec, a
sub-directory called "Par__i" is created in the top-level Haskell
directory representing the common parent directory where i is the
number of directory levels that the parent directory is above that
containing the top-level spec, and sub-directories created below that
corresponding to the path of the sibling spec. In the example for
:command:`gen\-haskell\-top /A/B/C/Main.sw`, if this spec imports spec
``/A/W/X/Y.sw`` the corresponding module is generated as
``/A/B/C/Haskell/Par__2/W/X/Y.hs``.

Translation of Specware Names
=============================

.. index::
   single: pragma; translate

|Specware| unqualified type and op names are translated as is,
excepted that the first letter is down- or upper-cased respectively as
necessary to comply with Haskell's lexical rules. Qualified names have
the qualifier appended at the beginning of the name, separated from
the primary name by two underbar characters, changing the first-letter
case if necessary. For example, the type ``A.B`` is translated to
``A__B`` and the op ``A.b`` is translated to ``a__b``\ . However, the
user may provide a pragma to override this default translation of an
op. The pragma must occur immediately after the op definition if it is
unnamed or anywhere if names. The unnamed version has the form::

   #translate Haskell -> desiredName #end
   
where ``desiredName`` is the name you want to appear in the Haskell
translation. A named pragma has the actual op (or type) name occur
after ``#translate Haskell``, so the pragma may occur anywhere in
the file. E.g.::

   #translate Haskell Qual.opName -> desiredName #end
   

Translation Tables
==================


.. index::
   single: pragma; morphism

You can connect a |Specware| spec with an existing |Haskell| module by
providing a ``-morphism`` translation table within the spec.

A translation table for |Specware| types and ops is introduced by a
line beginning ``#translate Haskell -morphism`` followed optionally by
one or more |Haskell| module names (which will be imported into the
translated spec), and terminated by the string ``#end``. Each line
gives the translation of a type or op. For example, for the |Specware|
List spec we have::

   #translate Haskell -morphism  List
     type List.List    -> []
     Nil               -> []
     Cons              -> :            Right 5
     List.List_P       -> list_all
     List.length       -> length
     List.@            -> !!           Left  9
     List.empty        -> []
     List.empty?       -> null
     List.in?          -> elem         Infix 4
     List.nin?         -> notElem      Infix 4
     List.prefix       -> take         curried  reversed
     List.removePrefix -> drop         curried  reversed
     List.head         -> head
     List.last         -> last
     List.tail         -> tail
     List.butLast      -> init
     List.++           -> ++           Left 5
     List.|>           -> :            Right 5
     List.update       -> list_update  curried
     List.forall?      -> all
     List.exists?      -> any
     List.filter       -> filter
     List.zip          -> zip          curried
     List.unzip        -> unzip
     List.zip3         -> zip3         curried
     List.unzip3       -> unzip3
     List.map          -> map
     List.isoList      -> map
     List.reverse      -> reverse
     List.repeat       -> replicate    curried  reversed
     List.flatten      -> concat
     List.findLeftMost -> find
     List.leftmostPositionSuchThat -> findIndex  curried  reversed
     List.positionsSuchThat -> findIndices  curried  reversed
     List.positionsOf  -> elemIndices  curried  reverse
   #end
   

A type translation begins with the word ``type`` followed by the
fully-qualified |Specware| name, ``->`` and the |Haskell| name. Note
that by default, sub-types are represented by their super-type.

An op translation begins with the fully-qualified |Specware| name,
followed by ``->`` and the |Haskell| constant name. If the |Haskell|
constant is an infix operator, then it should be followed by ``Left``
or ``Right`` depending on whether it is left or right associative and
a precedence number. Note that the precedence number is relative to
|Haskell|'s precedence ranking, not |Specware|'s. Also, an uncurried
|Specware| op can be mapped to a curried |Haskell| constant by putting
``curried`` after the |Haskell| name, and a binary op can be mapped
with the arguments reversed by appending ``reversed`` to the line.

Translation To Type Class Instances
===================================

.. index::
   single: pragma; instance

A Specware type can be translated to be an instance of a Haskell type
class by including within the spec an ``-instance`` pragma. The name
of the typeclass to instantiate comes immediately after the
``-instance`` specifier, followed by the name of the Specware type. On
subsequent lines are translations of Specware ops to the functions of
the type class in the same syntax as for translation tables above. For
example, a monad defined in Specware can be specified to be translated
to an instance of the Haskell monad typeclass using the pragma::

   #translate Haskell -instance Monad Env
     monadBind -> >>=  Left 1
     return -> return
   #end
   

Note that if there are any ops to be translated to Haskell functions
in a type class where you want to use the Haskell definition rather
than the Specware definition, then you should use a ``-morphism``
pragma instead of an ``-instance`` pragma. In particular, to translate
to an existing Haskell monad, you use a ``-morphism`` pragma.

Connecting to Haskell IO Monad
==============================

The spec ``/Library/Base/BasicIO`` defines basic IO and exception
operations on a monad and includes a morphism to Haskell's IO monad.
The monad type ``IO.IO`` corresponds to Haskell IO monad type.

Strictness Pragmas
==================

.. index::
   single: pragma; strict


Both coprpoduct types and ops may have ``-strict`` in their associated
pragmas to cause the translator to generate strictness annotations in
the resulting Haskell.

For example, the type specification::

   type Pair(a,b) = Pair(a * b)
   #translate Haskell -strict #end
   
produces::

   data Pair a b = Pair__Pair !a !b
   
I.e. the pragma causes the addition of ``!`` before all the
constructor fields.


.. todo:
   This could also be accomplished using bang patterns, and would only
   require annotations at the function declaration, not at the call
   site. Perhaps that would be a simplifying change?

In the case of an op definition, the ``-strict`` pragma causes the
addition of ``$!`` for all applications to force evaluation of
function arguments before calling the function. For example::

   op ff(i: Int): Int = f(f i)
   #translate Haskell -strict #end
   
produces::

   ff :: Int -> Int
   ff i = f $! f $! i
   
Like other pragmas associated with particular types and ops, the
pragma may be named rather than immediately following the type or op.

Header Pragmas
==============

.. index::
   single: pragma; header

A ``-header`` pragma specifies text to go at the beginning of the
generated Haskell module. For example, the pragma::

   #translate Haskell -header
   {-# OPTIONS -fno-warn-duplicate-exports #-}
   #end
   
will add the text ``{-# OPTIONS -fno-warn-duplicate-exports #-}`` at
the beginning of the generated Haskell file.

