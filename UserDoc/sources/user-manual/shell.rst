

============
The |SShell|
============


Overview
########

Unit definitions are processed by |Specware|. The user instructs
|Specware| to process units by supplying certain commands. |Specware|
has access, via the Lisp runtime environment, to the underlying file
system, so it can access the ``.sw`` files that define units. The
environment variable |swpath| determines which ``.sw`` files are
accessed by |Specware| to find unit definitions.

Processing a unit causes the recursive processing of the units
referenced in that unit's term. For instance, if a spec ``A`` extends
a spec ``B`` which in turns extends a spec ``C``, then when ``A`` is
processed, ``B`` and ``C`` are also processed. There must be no
circularities in the chain of unit dependencies.

Processing causes progress and/or error messages to be displayed in
the window containing the |SShell|. Progress messages inform the user
that units were processed without error. Error messages provide
information on the cause of errors, so that the user can fix them by
editing the unit definitions. If the |SShell| is running under XEmacs,
then, when an error occurs in the definition of some unit, |Specware|
displays the ``.sw`` file containing the unit term in a separate
XEmacs buffer, with the cursor positioned at the point of the
erroneous text.

The processing of certain kinds of units also results in the creation
of new files as an additional side effect. For instance, Lisp, C or
Java programs are constructed by units containing the ``generate``
operation of |Metaslang|. A side effect of processing such a unit is
that the resulting code is written into a file.

When |Specware| processes a unit, it saves the processing results into
an internal cache, associating the results with the unit's identifier.
By using this cache, |Specware| avoids unnecessary re-computations: it
only re-processes the units whose files have changed since the last
time they were processed. From the point of view of the final result,
this caching mechanism is transparent to the user. However, it
improves the performance and response time of the system.

However, under certain circumstances this may lead to the wrong
result. Files only need to be processed if they may have changed since
the last time they were processed. To determine whether this is the
case, the caching mechanism uses the "last modified" date and time of
the files. Say there are two files named ``mickey.sw`` and
``minnie.sw``. If the user first lets |Specware| process ``mickey.sw``,
and then deletes that file and renames ``minnie.sw`` to ``mickey.sw``,
the system will be fooled into assuming that ``mickey.sw`` does not
need to be re-processed. After all, its modification time is that of
the original ``minnie.sw`` file, and so it is older than the last time
``mickey.sw`` was processed. A likely scenario under which this may
happen is when a user copies a file to a back up, modifies the file,
has |Specware| process it, and then restores it by moving the back-up
version in its place. All other scenarios that may lead to the wrong
results are variations on this theme, replacing a file with one with
the same name but different content during a |Specware| session
without adjusting its modification time, or by antedating its
modification time.

Clearly, to retain cache integrity, the user is well-advised not to
rename, move or delete ``.sw`` files while a |Specware| session is in
progress. If there is any reason to suspect that the integrity of the
cache has become compromised, the |SShell| command :command:`cinit` will
clear the unit cache and thereby restore integrity.

  

.. COMMENT:  overview 

Typechecking Specs
##################

The user can construct specs by explicitly listing the types, ops, and
axioms comprising the spec, possibly after importing one or more other
specs. When a spec is processed, |Specware| typechecks all the
expressions that appear in the spec. Typechecking means checking that
the expressions are type-correct, according to the rules of the
|Metaslang| language.

In general, only some of the ops and variables that appear in an
expression have explicit type information. Typechecking also involves
reconstructing the types of those ops and variables that lack explicit
type information.

Typechecking is an integrated process that checks the type correctness
of expressions while reconstructing the missing type information. This
is done by deriving and solving type constraints from the expression.
For instance, if it is known that an op ``f`` has type ``A -> B`` then
the type of the variable ``x`` in the expression ``f(x)`` must be
``A``, and the type of the whole expression must be ``B``.

If the missing type information cannot be uniquely reconstructed
and/or if certain constraints are violated, |Specware| signals an
error, indicating the textual position of the problematic expression.

Since the |Metaslang| type system features subtypes defined by
arbitrary predicates, it is in general undecidable whether an
expression involving subtypes is type-correct or not. When |Specware|
processes a spec, it assumes that the type constraints arising from
subtypes are satisfied, thus making typechecking decidable.

.. index::
   pair: shell-command; obligations

The proof obligations associated with a spec, which are extracted via
the |Metaslang| :command:`obligations` operation, include conjectures derived
from the type constraints arising from subtypes. If all of these
conjectures can be proved (using a theorem prover) then all the
expressions in the spec are type-correct.

.. _resolveUID:

Resolution of Unit Identifiers
##############################

Unit terms may reference units in the form of unit identifiers. A unit
identifier is resolved to the unit's term, which is contained in a
``.sw`` file. Unit identifiers are either |swpath|-based or relative;
these two kinds are syntactically distinguished from each other and
are resolved in slightly different ways.

.. _swpathuid:

|swpath|-Based Unit Identifier
==============================

A |swpath|-based unit identifier starts with "/", followed by a
"/"-separated sequence of one or more path elements, where the last
separator may be ``#``. Examples are ``/a/b/c``, ``/d``, and
``/e#f``.

.. index::
   pair: unit identifier; resolution
   see: absolute unit identifier; resolution

|Specware| resolves a |swpath|-based unit identifier in the following
steps:

#. If the unit identifier contains ``#``, the ``#`` itself and the path
   element following it are removed, obtaining a "/"-separated sequence
   of one or more path elements, preceded by "/". Otherwise, no removal
   takes place. Either way, the result of this first step is a
   "/"-separated sequence of path elements preceded by "/".

#. The "/" signs of the "/"-separated sequence of path elements preceded
   by "/", resulting from the previous step, are turned into "\"; in
   addition, ``.sw`` is appended at the end. The result of this second
   step is a (partial) path in the file system.

#. The path resulting from the previous step is appended after the first
   directory of |swpath|. If the resulting absolute path denotes an
   existing file, that is the result of this third step. Otherwise, the
   same attempt is made with the second directory of |swpath| (if any).
   Attempts continue until a directory is found in |swpath| such that the
   absolute path obtained by concatenating the directory with the result
   of the previous step denotes an existing file; such a file is the
   result of this step. If no such directory is found, the unit
   identifier cannot be resolved and an error is signaled by |Specware|.

#. There are two alternative steps here, depending on whether or not the
   original unit identifier contains ``#``.

   #. This is the case that the original unit identifier does not contain
      ``#``. If the file resulting from the previous step is a single-unit
      file, i.e., it contains a unit term, that the final result of
      resolution. Otherwise, an error is signaled by |Specware|.

   #. This is the case that the original unit identifier contains ``#``. The
      file resulting from the previous step must be a multiple-unit file,
      i.e., it must contain a sequence of one or more unit definitions. If
      this is not the case, the unit identifier cannot be resolved and an
      error is signaled by |Specware|. If that is the case, a unit
      definition is searched in the file, whose path elements (to the left
      of "=") is the same as the path element that follows ``#`` in the
      original unit identifier. If no such unit definition is found, the
      unit identifier cannot be resolved and an error is signaled by
      |Specware|. If such a unit definition is found, its unit term (at the
      right of "=") is the final result of resolution.

For example, consider a unit identifier ``/a/b/c``. Since it does
not contain ``#``, the first step does not do anything. The result of
the second step is ``\a\b\c.sw``. Suppose that |swpath| is
``C:\users\me\specware;C:\tmp``, that ``C:\users\me\specware`` does
not contain any ``a`` subdirectory, and that ``C:\tmp\a\b\c.sw``
exists. The result of the third step is the file ``C:\tmp\a\b\c.sw``.
If such a file is a single-unit file, its content is the result of the
fourth step.

As another example, consider a unit identifier ``/e#f``. The result
of the first step is ``/e``. The result of the second step is
``\e.sw``. Assuming that |swpath| is as before and that
``C:\users\me\specware`` contains a file ``e.sw``, the file
``C:\users\me\specware\e.sw`` is the result of the third step. The
file must be a multiple-unit file. Assuming that this is the case and
that it contains a unit definition with path element ``f``, its unit
term is the result of the fourth step.

The directories in |swpath| are searched in order during the third
step of resolution. So, in the last example, if the directory
``C:\tmp`` also contains a file ``e.sw``, such a file is ignored. This
features can be used, for example, to shadow selected library units
that populate certain file system directories in |swpath|.

For example, suppose that the first directory in |swpath| is
``C:\specware\libs`` and that the directory ``C:\specware\libs\data-
structures`` contains files ``Sets.sw``, ``Bags.sw``, ``Lists.sw``,
etc. defining specs of sets, bags, lists, etc. The unit identifier
``/data-structures/Sets`` resolves to the content of the file
``C:\specware\libs\data-structures\Sets.sw``. If the user wanted to
experiment with a slightly different version of the spec for sets, it
is sufficient to prepend another directory to |swpath|, e.g. 
``C:\shadow-lib``, and to create that slightly different version of the
spec for sets in ``C:\shadow-lib\data-structures\Sets.sw``. The same
unit identifier ``/data-structures/Sets`` will now resolve to the new
version.

  

.. COMMENT:  swpath-based unit identifiers 

Relative Unit Identifiers
=========================

.. index::
   pair: unit identifier; resolution
   see: relative unit identifier; resolution

A relative unit identifier is a ``/``\ -separated sequence of one or more
path elements, where the last separator can be ``#``. Examples are
``a/b/c``, ``d``, and ``e#f``. So, |swpath|-based and relative
unit identifiers can be distinguished by the presence or absence of
``/`` at the beginning.

The resolution of relative unit identifiers does not depend on
|swpath|, but on the location of the file where the unit identifier
occurs. There are two cases to consider: the unit identifier occurring
in a single-unit file and the unit identifier occurring in a multiple-
unit file.

Suppose that the relative unit identifier occurs in a single-unit
file. Then |Specware| attempts to resolve the unit identifier in the
following steps:

#. If the unit identifier contains ``#``, the ``#`` itself and the path
   element following it are removed, obtaining a ``/``\-separated sequence
   of one or more path elements. Otherwise, no removal takes place.
   Either way, the result of this first step is a ``/``\-separated sequence
   of path elements.

#. The ``/`` signs of the ``/``\-separated sequence of path elements,
   resulting from the previous step, are turned into "\"; in addition,
   ``.sw`` is appended at the end. The result of this second step is a
   (partial) path in the file system.

#. %%Otherwise, the
   %%"/" signs are left unchanged and ``.sw`` is appended at the
   %%end. Either way, the

#. The path resulting from the previous step is appended after the
   absolute path of the directory of the file containing the relative
   unit identifier. If the resulting absolute path denotes an existing
   file, that is the result of this third step. Otherwise, the unit
   identifier cannot be resolved and an error is signaled by |Specware|.

#. There are two alternative steps here, depending on whether the
   original unit identifier contains ``#`` or not.

   #. This is the case where the original unit identifier does not contain
      ``#``. If the file resulting from the previous step is a single-unit
      file, i.e., it contains a unit term, that is the final result of
      resolution. Otherwise, an error is signaled by |Specware|.

   #. This is the case that the original unit identifier contains ``#``. The
      file resulting from the previous step must be a multiple-unit file,
      i.e., it must contain a sequence of one or more unit definitions. If
      this is not the case, the unit identifier cannot be resolved and an
      error is signaled by |Specware|. If that is the case, a unit
      definition is searched in the file, whose path element (at the left of
      "=") is the same as the path element that follows ``#`` in the original
      unit identifier. If no such unit definition is found, the unit
      identifier cannot be resolved and an error is signaled by |Specware|.
      If instead such a unit definition is found, its unit term (to the
      right of "=") is the final result of resolution.

So, resolution of a relative unit identifier occurring in a single-
unit file is like resolution of a |swpath|-based unit identifier,
except that the directory where the identifier occurs is used instead
of |swpath|.

Suppose, instead, that the relative unit identifier occurs in a
multiple-unit file. Then |Specware| attempts to resolve the unit
identifier in the following steps:

#. If the relative unit identifier is a single path element, |Specware|
   attempts to find a unit definition with that path element inside the
   file where the unit identifier occurs. If such a unit definition is
   found, its unit term is the final result of resolution. Otherwise, the
   following steps are carried out:

#. If the unit identifier contains ``#``, the ``#`` itself and the path
   element following it are removed, obtaining a "/"-separated sequence
   of one or more path elements. Otherwise, no removal takes place.
   Either way, the result of this first step is a ``\``\-separated sequence
   of path elements.

#. The "/" signs of the "/"-separated sequence of path elements,
   resulting from the previous step, are turned into ``\``; in addition,
   ``.sw`` is appended at the end. The result of this second step is a
   (partial) path in the file system.

.. COMMENT:
   #. %%Otherwise, the
   %%"/" signs are left unchanged and ``.sw`` is appended at the
   %%end. Either way, the

#. The path resulting from the previous step is appended after the
   absolute path of the directory of the file containing the relative
   unit identifier. If the resulting absolute path denotes an existing
   file, that is the result of this third step. Otherwise, the unit
   identifier cannot be resolved and an error is signaled by |Specware|.

#. There are two alternative steps here, depending on whether the
   original unit identifier contains ``#`` or not.

   #. This is the case that the original unit identifier does not contain
      ``#``. If the file resulting from the previous step is a single-unit
      file, i.e., it contains a unit term, that is the final result of
      resolution. Otherwise, an error is signaled by |Specware|.

   #. This is the case that the original unit identifier contains ``#``. The
      file resulting from the previous step must be a multiple-unit file,
      i.e., it must contain a sequence of one or more unit definitions. If
      this is not the case, the unit identifier cannot be resolved and an
      error is signaled by |Specware|. If that is the case, a unit
      definition is searched in the file, whose path element (at the left of
      "=") is the same as the path element that follows ``#`` in the original
      unit identifier. If no such unit definition is found, the unit
      identifier cannot be resolved and an error is signaled by |Specware|.
      If instead such a unit definition is found, its unit term (to the
      right of "=") is the final result of resolution.

So, resolution of a relative unit identifier occurring in a multiple-
unit file is like resolution of a relative unit identifier occurring
in a single-unit file, preceded by an attempt to locate the unit in
the file where the identifier occurs, only in case such a unit
identifier is a path element.

  

.. COMMENT:  relative unit identifiers 

  

.. COMMENT:  resolution of unit identifiers 

Command Format
##############

Each |SShell| command consists of a keyword, the command name,
followed by zero or more arguments. Several |SShell| commands have
"optional arguments": they allow a variable number of arguments; e.g.,
zero or one. For many such commands, the zero-argument version means:
use the last argument of the same kind last used for a |SShell|
command. In other cases, it means: use a default value for the omitted
argument. Which commands use which convention is detailed below.
Optional arguments are given between square brackets ``[`` and ``]``.

Unit identifiers occurring in a unit term used as a command argument
are resolved as described in
:ref:`resolveUID`, where relative
unit identifiers are resolved as they would be if the unit term was a
single-unit file in the current directory.

A command entered by the user should be typed all on one line. The
Return/Enter at the end of the line signals to the |SShell| that the
command must be executed. If the |SShell| is running under XEmacs, the
TAB key can be used for filename completion.

Miscellaneous Commands
######################

The commands described in this section do not process units, but some
may influence the way later processing commands work.

.. index::
   pair: shell-command; help

A terse description of all Shell commands is produced by the help
command:

.. code-block:: specware

   help
   
With an argument:

.. code-block:: specware

   help <command-name>
   
it shows a description of just that command.

.. index::
   pair: shell-command; cd
   single: shell-command; change directory

The pathname of the current directory is shown on the putput by the
following command:

.. code-block:: specware

   cd
   
The change-directory command:

.. code-block:: specware

   cd <directory>
   
sets the current directory (folder) to the argument, which must be a
valid pathname for a directory in the file system, either absolute or
relative to the present directory. To move one level up, to the parent
of the current directory, the special notation "\ ``..``\ " can be
used. The full pathname of the new current directory is then
displayed. This influences the subsequent resolution of unit
identifiers if "\ ``.``\ " is on the |swpath|. With no argument, the
command :command:`cd` just shows the current directory.

.. index::
   pair: shell-command; dir

Two commands allow listing |Specware| files:

.. code-block:: specware

   dir
   
list the ``.sw`` files in the current directory, while

.. index::
   pair: shell-command; dirr


.. code-block:: specware

   dirr
   
(for DIR Recursive) also lists those in sub-directories.

.. index::
   pair: shell-command; path


The value of the |swpath| environment variable is shown via the
following command:

.. code-block:: specware

   path
   
The value of the |swpath| environment variable is changed via the
following command:

.. code-block:: specware

   path <dir>;<dir>;...;<dir>
   
The argument must be a semicolon-separated list of absolute directory
paths of the underlying operating system. For example, in order to set
|swpath| to ``C:\users\me`` it is necessary to write :command:`path C:\\users\\me`.

Changes to |swpath| only apply to the currently running |Specware|
session. If |Specware| is quit and then restarted, |swpath| loses the
value assigned to it during the previous session, reverting to its
default value.

Processing a Unit
#################

.. index::
   pair: shell-command; proc
   pair: shell-command; p

The command to process a unit is:

.. code-block:: specware

   proc [ <unit-term> ]
   
The argument can be any unit term: a simple unit identifier, a diagram
colimit, a proof term, and so on.

If the argument is not a syntactically valid unit term, or some unit
identifier in the term fails to resolve as explained in
:ref:`swpathuid`, an error is signaled by |Specware|.

Otherwise |Specware| parses and elaborates the unit term that results
from resolution. Parsing and elaboration carry out the computations to
construct the unit; they are |Specware|'s "core" functionality.
Parsing and elaboration implement the semantics of the |Metaslang|
language.

In this process, |Specware| performs further checks on the
requirements as stated in the language manual, such as non-ambiguity
of names. If any errors are found, they are signaled

If the unit term references other units, |Specware| recursively
resolves the unit identifiers and parses and elaborates their unit
terms.

Finally, if all went well, |Specware| typechecks the unit resulting
from the elaboration process, if applicable, and signals any errors
detected.

The elaboration of some unit terms may have side effects: code
generation; prover invocation. This is only done if no error was
encountered. Code can also be generated directly from the |SShell|
using the :command:`gen-`\ *Language*\ commands. For proving properties in
specs, see `Proving Properties in Specs`_.

Without argument, the :command:`proc` command re-processes the last unit term
given. It is an error if no unit term was given before.

It is also possible to process a multiple-unit file all at once:

.. code-block:: specware

   proc <multi-unit-identifier>
   
The unit identifier must not contain "\ ``#``\ " and the file must not
contain a unit of the same name as the file (without the directory and
extension). |Specware| attempts to resolve the unit identifier. If it
is a relative unit identifier, it is resolved as if it occurred inside
a single-unit file in the current directory. However, the file
obtained at the third step must be a multi-unit file, and not a
single-unit file. If it is indeed a multi-unit file, |Specware| parses
and elaborates all the unit definitions inside the file.

.. index::
   pair: shell-command; p

The command :command:`proc` may be abbreviated to :command:`p`.

.. index::
   pair: shell-command; prove


If the ``<unit-term>`` is a proof term, i.e. it begins with :command:`prove`,
then the :command:`proc` or :command:`p` may be omitted, so::

   prove <claim-name> in <unit-term>
   
is the same as

.. code-block:: specware

   proc prove <claim-name> in <unit-term>
   
.. index::
   pair: shell-command; cinit

The values of processed units are kept in the unit cache. To clear the
unit cache, as mentioned before, use::

   cinit
   
(Cache INITialize).

Showing a Unit
##############

When a unit definition is elaborated, a unit value is produced. For
example, a spec is essentially a set of types, ops, and axioms. A spec
can be constructed by means of various operations in the |Metaslang|
language, but the final result is always a spec, i.e., a set of types,
ops, and axioms.

.. index::
   pair: shell-command; show


The command for showing unit values is::

   show [ <unit-term> ]
   
As for :command:`proc` the argument can be any unit term: a simple unit
identifier, a diagram colimit, a proof term, and so on, and a missing
argument means: use the last argument supplied in a unit-term
position. However, unlike for :command:`proc`, the argument can not be a
multi-unit identifier.

The unit term is processed as for the :command:`proc` command. If no error
occurred, the unit value resulting from elaborating the unit term is
shown on the output. However, an attempt is made to keep imported
specs as import declarations, instead of expanded in the output. If
the argument was already a spec form, the output may look different in
several ways: white space may be different, declarations may have been
added or re-ordered, and explicit qualifications may have been added.


.. index::
   pair: shell-command; obligations
   pair: shell-command; obligs


If the [*unit-term*] is an obligation term then the show may be
omitted. For example,

.. code-block:: specware

   obligations <unit-term>
   
or its abbreviation

.. code-block:: specware

   oblig <unit-term>
   
is the same as

.. code-block:: specware

   show obligations <unit-term>
   

.. index::
   pair: shell-command; showx

To show imported specs expanded in place, use:

.. code-block:: specware

   showx [ <unit-term> ]
   
(for SHOW eXpanded).

"Showing" a proof unit has the same effect as just processing it; the
elaboration of a proof unit is only in the side effects.

Generating Proof Units
######################


.. index::
   pair: shell-command; punits

Two |SShell| commands facilitate the creation of proof units. The
first is::

   punits [ <unit-identifier> [ <filename> ] ]
   
in which the unit identifier must be that of a single spec term.
Executing the command then generates proof units for all the
conjectures, theorems and proof obligations of the spec resulting from
elaborating that spec term.

These proof units are written to a file that can then be processed to
attempt proving all the conjectures in the spec. The proof file can
also be edited to add ``using``\ s and ``options`` to the proof units.
By default, the proof units are written in a file obtained from the
unit identifier given to the :command:`punits` command. For example, if the
unit identifier is ``/dir1/dir2/foo``, then the proof units are
written to ``/dir1/dir2/foo_Proofs.sw``. Optionally, the file for the
proof units to be written to can be given as the second argument to
the :command:`punits` command.

Using :command:`punits`, proof units are generated not just for the
conjectures explicitly present in the spec, but also for all non-local
conjectures for the spec. The user can use the command::

   lpunits [ <unit-identifier> [ <filename> ] ]
   
to generate a proof-unit file with only the "local" conjectures.

Evaluating Expressions
######################

"Constructive" expressions -- i.e., using only constructively defined
types and ops -- can be evaluated directly from the |SShell|.
Evaluating an expression requires a "context" to be set, which is a
spec containing the definitions of the relevant types and ops. For
example, in the context of::

   spec
     def f x = 2*x+1
     def u = 6172
   end-spec


.. index::
   pair: shell-command; ctext

The evaluation context can be set by the shell command::

   ctext [ <spec-term> ]
   
As usual, if the argument is absent, it indicates the last term
processed, which must elaborate to a spec.

.. index::
   pair: shell-command; eval

Once a context has been set, a |Metaslang| expression can be evaluated
by::

   eval [ <expression> ]
   
which results in the value of the expression being shown, insofar as
possible: some types of values, in particular functions, have no
"printable" representation. Apart from that, values are shown using
|Metaslang| syntax; for example, :command:`eval [100, 2*100]` shows 
``[100, 200]``. The evaluation is done by a built-in |Metaslang|
interpreter.

.. index::
   pair: shell-command; e


The command :command:`eval` may be abbreviated to :command:`e`.

.. index::
   pair: shell-command; eval-lisp

Instead of using the built-in |Metaslang| interpreter, it is also
possible to evaluate |Metaslang| expressions from the |SShell| command
line as translated into Lisp. Unless no user-defined types and ops are
used (as in the expression :command:`2+2`), this requires that Lisp code
has already been generated for the context spec (see
:ref:`genlisp`) and that the Lisp file has been loaded
(see :ref:`auxlisp`). The command is::

   eval-lisp [ <expression> ]
   
which also results in the value of the expression being shown, but now
using Lisp syntax; for example, :command:`eval-lisp [100, 2*100]` shows
``(100 200)``.
For expressions whose evaluation is very computation-intensive,
this method of evaluation
can be substantially faster than using the interpreter.

.. _genlisp:

Generating Lisp Code
####################

Lisp code can be generated by constructing a |Metaslang| unit
containing a target-code term (using :command:`generate lisp`) and by
processing such unit via the :command:`proc` command.

.. index::
   pair: shell-command; gen-lisp

The |SShell| provides a command to accomplish the same result without
actually creating a separate |Metaslang| unit. The command is:

   gen-lisp [<spec-term> [<filename>] ]
   
The spec term is processed by |Specware|. If this argument is missing,
the last spec term processed is used. If the spec is successfully
processed, |Specware| generates Lisp code from it (according to the
semantics of :command:`generate lisp`) and deposits the resulting code into
the file whose path is given by the filename. The ``.lisp`` file
extension can be omitted.

The filename to ``gen-lisp`` is also optional. If it is not given, a
file name is inferred. If the spec term given as argument is a unit
identifier, |Specware| deposits the generated code into the file
*U*\ ``.lisp``, where *U* is the rightmost path element comprising the
unit identifier. The *U*\ ``.lisp`` file is deposited in a ``lisp``
subdirectory immediately under the directory of the file containing
the unit term of the spec identified by the unit identifier given as
argument to ``gen-lisp``.

For example, suppose that the first directory in |swpath| is
``C:\users\me\specware`` and that a spec is defined in the single-unit
file ``C:\users\me\specware\two\A.sw``. If the user gives the command::

   gen-lisp /two/A
   
the Lisp code is deposited into the file ``C:\users\me\specware\two\lisp\A.lisp``.

As another example, suppose that |swpath| is as before and that a spec
is defined in the multiple-unit file
``C:\users\me\specware\two\F.sw``, and that ``B`` is the path element
associated with the spec. If the user then gives the command::

   gen-lisp /two/F#B
   
the Lisp code is deposited into the file ``C:\users\me\specware\two\lisp\B.lisp``.

If the spec term given as argument is not a unit identifier,
|Specware| deposits the generated code in a file under
``C:\tmp\sw\lisp``, if possible. In all cases the name of the Lisp
file is shown on the output.

.. index::
   pair: shell-command; lgen-lisp

The shell command::

   lgen-lisp [ <spec-term> [ <filename> ] ]
   
is like :command:`gen-lisp`, but generates code only for the local
definitions of the spec and not any of the imports. It is intended for
incremental development. Note that if you have not generated code for
the imported specs and loaded it, trying to run the code generated by
this command will give undefined function errors. Also, if the spec is
unqualified but it is imported into a spec that is qualified, the
package used will be ``:SW-USER`` instead of the package of the
qualifier. To avoid this problem, qualification can be added to the
spec.


.. toctree::
   javacodegen
   ccodegen
   haskellcodegen

.. _auxlisp:

Auxiliary Commands for Lisp
###########################

When developing a |Specware| application you may generate Lisp code
for your application, and then load and test it in the same image in
which the |Specware| system is running. Then if you make a
modification to a single spec you can use the :command:`lgen-lisp` command to
just generate the generated code for the modification. This command is
also useful when you just want to see the generated code for a
particular spec.

.. index::
   pair: shell-command; ld

To load Lisp files from the |SShell|, the following commands can be
used::

   ld [ <lisp-filename> ]
   

.. index::
   pair: shell-command; cf


The generated Lisp files can also be compiled from the |SShell|, but
of course only if the running Lisp system has compiling enabled::

   cf [ <lisp-filename> ]
   
(for Compile File) will compile a Lisp file, and

.. index::
   pair: shell-command; cl


.. code-block:: specware

   cl [ <lisp-filename> ]
   
compiles and loads it.

	

Finally
#######

.. index::
   pair: shell-command; exit


To terminate a |Specware| session::

   exit
   
or, equivalently,

::

   quit
   

