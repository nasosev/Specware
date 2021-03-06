

==============
Defining Units
==============

Conceptual Model
################

A unit definition consists of a unit identifier and a unit term. The
identifier identifies the unit and the term defines how the unit is
constructed.

A project developed with |Specware| consists of a set of unit
definitions, some of which may come from libraries. Units have unique
identifiers within the project.

Unit Identifiers
================

A unit identifier is a finite, non-empty sequence of word symbols
(word symbols are defined in the |Metaslang| grammar). The sequence of
word symbols is essentially a "path" in a tree: the units comprising a
project are organized in a tree.

This provides a convenient and simple way to organize the units
comprising a project. Libraries are subtrees of the whole tree.
Parallel development of different parts of a project can be carried
out in different subtrees that can be later put together without risk
of naming clashes.

Unit Terms
==========

A unit term is text written in the |Metaslang| language. |Metaslang|
features various ways to construct specs, morphisms, and all the other
kinds of units. For instance, it is possible to construct a spec by
explicitly listing its types, ops, and axioms. It is also possible to
construct a spec by applying the colimit operation to a diagram of
specs and morphisms.

A unit term may reference other units. For instance, a spec
constructed by extending another one references the spec being
extended.

References can be "|swpath|-based" or "relative". In either case they
are resolved to full unit identifiers of units in the tree, according
to simple rules explained later.

  

.. COMMENT:  conceptual model 

Realization via the File System
###############################

The conceptual model just described is realized by means of the file
system of the underlying operating system. The file system has
essentially a tree structure. The tree of units comprising a
|Specware| project is mapped to subtrees of the file system; the word
symbols comprising a path are mapped to file and directory names.

.. todo:: 

   Another reference to "future versions". Is this still
   planned?

Future versions of |Specware| will have a more sophisticated UI that
will realize the conceptual model directly. Users will graphically see
the units organized in a tree and they will be able to add, remove,
move, and edit them. The mapping to the file system may even be made
totally transparent to the user.

The |swpath| Environment Variable
=================================

.. todo::

   Don't know where the `swpath` reference below is supposed to point.

The mapping of the conceptual unit tree to the file system is defined
by the environment variable |swpath|. Similarly to the ``PATH``
environment variable in operating systems, |swpath| is a string
consisting of a semicolon-separated list of absolute directory paths
in the file system. 

Roughly speaking, the unit tree consists of all the units defined in
``.sw`` files under the directories listed in |swpath|. The identifier
of each unit is its path from the directory in |swpath| under which
the file defining the unit is: if the unit is under a directory named
``ub2``, its identifier is its absolute path in the file system
"minus" the ``ub2`` prefix. This approximate statement is made precise
and illustrated by examples below.

Single Unit in a File
=====================

The simplest way to define a unit is to write its term into a ``.sw``
file in the subtree of one of the directories in |swpath|. The
identifier of the unit is the name of the file, without ``.sw``,
prefixed by the path from the directory in |swpath| to the file.

For example, suppose that |swpath| includes the directory
``C:\users\me\specware``. The user creates a file named ``A.sw``
immediately under the directory ``C:\users\me\specware\one\two``,
containing the following text::

   spec
     type X
   end-spec
   

The absolute path of the file in the file system is
``C:\users\me\specware\one\two\A.sw``. The unit is a spec declaring
just a type ``X``. The identifier of the unit is ``/one/two/A``.
Note that the path components are separated by "/" (forward slash),
even though the underlying file system uses "\" (backward slash). Unit
identifier are sequences of word symbols separated by "/", regardless
of the underlying operating system.

Multiple Units in a File
========================

It is also possible to put multiple units inside a ``.sw`` file. The
file must be in the subtree of one of the directories in |swpath|.
Instead of just containing a unit term, the file contains one or more
unit definitions. A unit definition consists of a word symbol, ``=``
(equal), and a unit term.

This case works almost exactly as if the file were replaced by a
directory with the same name (without ``.sw``) containing one ``.sw``
file for every unit defined therein. Each such file has the word
symbol of the unit as name (plus ``.sw``) and the term of the unit as
content.

The only difference between the case of multiple units per file and
the almost equivalent case where the file is replaced by a directory
containing single-unit files, is that in the former case the last
separator is not "/" but "#" (sharp). (This is reminiscent of the URI
syntax, where subparts of a document are referred to using "#".)

Suppose, as in the previous example, that |swpath| includes the
directory ``C:\users\me\specware``. The user creates a file named
``three.sw`` immediately under the directory
``C:\users\me\specware\one\two``, containing the following text::

   B = spec
     type Y
   end-spec
   
   three = spec
     import B
     type Z
   end-spec
   

This file defines two specs, one declaring just a type ``Y``, the
other, next to importing the first spec, declaring just a type
``Z``. The identifier of the first spec is ``/one/two/three#B``, the
identifier of the second spec is ``/one/two/three#three``.

As a particular instance of the case of multiple units per file, it is
possible to have just one unit definition in the file. This is
different from just having a unit term in a file. If the file contains
a unit definition, then the word symbol at the left of "=" is part of
the unit's identifier, together with "#" and the file path (relative
to the directory in |swpath|). If instead the file contains a unit
term, then the identifier of the unit is the file path (relative to
the directory in |swpath|), without any "#" and additional word
symbol.

Despite the possibility of having one unit definition in a file, in
this manual we use the term "multiple-unit file" to denote a file that
contains one or more unit definitions. The term "single-unit file" is
instead used to denote a file that only contains a unit term.

As a convenience, a unit in a multiple-unit file with the same name as
the file (without the directory and extension) may be referred to with
a URI for the file as a whole. For example, in the current case, the
identifier ``/one/two/three`` refers to the same spec as
``/one/two/three#three``. This feature supports a style of having
one primary unit in a file with auxiliary units that are used to
define the primary unit.

  

.. COMMENT:  realization 

Unit Definitions Are Managed Outside of |Specware|
##################################################

The ``.sw`` files are created, deleted, moved, and renamed by directly
interacting with the file system of the underlying operating system.

The content of the ``.sw`` files can be edited with any desired text
editor. A possibility is to use the XEmacs in which the |SShell| is
running when |Specware| is fired up using ``Specware4 XEmacs``. The
XEmacs-|Specware| combo can be thought of as a limited Integrated
Development Environment (IDE).

Note that unit definitions can be managed without running |Specware|
at all. As described in the next chapter, |Specware| is used to
process unit definitions.

  

.. COMMENT:  units definitions are managed outside of specware 

