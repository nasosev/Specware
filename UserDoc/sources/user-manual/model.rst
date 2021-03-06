

===========
Usage Model
===========



Units
#####

Simply put, the functionality provided by |Specware| consists in the
capability to construct specs, morphisms, diagrams, code, proofs, and
other entities. All these entities are collectively called
*units*.

Some of the operations made available by |Specware| to construct units
are fairly sophisticated. Examples are colimits, extraction of proof
obligations, discharging of proof obligations by means of external
theorem provers, and code generation.

The |Metaslang| language is the vehicle to construct units. The
language has syntax to express all the unit-constructing operations
that |Specware| provides. The user defines units in |Metaslang|,
writing the definitions in ``.sw`` files. (This file extension comes
from the first letters of the two syllables in "|Specware|".)

.. todo:: Are there plans for other ways? If not, drop this paragraph.

Currently, the only way to construct units in |Specware| is by writing
text in |Metaslang|. The ``.sw`` files that define units are edited
outside of |Specware|, using XEmacs, Notepad, Vim, or any other text
editor of choice. These files are processed by |Specware| by giving
suitable commands to the |SShell|. Future versions of |Specware| will
include the ability to construct units by other means. For instance,
instead of listing the nodes and edges of a diagram in text, it will
be possible to draw the diagram on the screen.

Interaction
###########

The interaction between the user and |Specware| takes place through
the |SShell|.

When ``.sw`` files are processed by |Specware|, progress and error
messages are displayed in the window containing the |SShell|. In
addition, the results of processing are saved into an internal cache
that |Specware| maintains. Lastly, processing of certain kinds of
units result in new files being created. For example, when Lisp code
is generated from a spec, the code is deposited into a ``.lisp`` file.

From the |SShell| it is possible to evaluate |Metaslang| expressions
in the context of a given spec, either directly or through generated
Lisp code.

|Specware| also features auxiliary commands to display information
about units, inspect and clear the internal cache, and inspect and
change the ``SWPATH`` environment variable, which determines how unit
identifiers are resolved to ``.sw`` files.

