

===========================
Proving Properties in Specs
===========================

.. todo::
   Should SNARK stuff be removed?

|Specware| provides a mechanism for verifying the correctness of
properties either specified in |Metaslang| specs or automatically
generated as proof obligations arising from refinements or
typechecking. Currently |Specware| comes packaged with the Snark
first-order theorem prover. Interaction with Snark is through the
proof unit described below.

The Proof Unit
##############

The user invokes the Snark theorem prover by constructing and
processing a proof term. A typical proof term is of the form:

.. code-block:: specware

   prove f_stable in Stability
         with Snark
         using stable_charn, f_defn
         options "(use-paramodulation t)
                  (use-resolution nil)
                  (use-hyperresolution t)"
   

In this proof term, ``Stability`` must be a spec-valued unit term, and
``f_stable``\ , ``stable_charn``\ , and ``f_defn`` must all be names
of claims (i.e. axioms, conjectures, or theorems) that appear in the
spec resulting from elaborating that unit term. If this proof term is
in the single-unit file ``pruf.sw``, then issuing the command ``proc
pruf`` will result in first translating ``stable_charn``\ , ``f_defn``
and ``f_stable`` to Snark formulas, and then invoking the Snark prover
to try to prove ``f_stable`` from the hypotheses ``stable_charn`` and
``f_defn``\ , using the options in the ``options`` list. As of this
release claim names are qualified. If the user does not explicitly use
a qualifier then all properties that have that name will be used,
regardless of their qualification. Note also that |Specware| does not
require property names to be unique. If there are more than one
property that has the same name as a claim in the ``using`` clause
then they will all be sent to Snark.

To avoid circular proofs, the claims used as hypotheses --
``stable_charn`` and ``f_defn`` in the example -- are required to
appear earlier in that spec than the claim to be proved --
``f_stable`` in the example. Most users will omit the ``options``
part. Additionally, the ``using`` part can be omitted as well. In that
case all the claims that appear in the spec term before the claim to
be proved will be used as hypotheses in the proof.

The ``with`` clause is used to specify which prover to be used. If the
``with`` clause is omitted which is typically the case, then before
invoking Snark, the claim will be sent to a simple integer linear
inequality decision procedure based on the Fourier Motzkin method. If
this fails then Snark will be invoked. Optionally the user can specify
either, ``Snark`` or ``FourierM`` to explicitly state which prover he
wants used. Note that the inequality decision procedure does not make
use the properties specified in the ``using`` clause.

After Snark completes, |Specware| will report on the success or
failure of the Snark proof.

Implicit Axioms
###############

|Metaslang| ``type`` and ``op`` declarations as well as ``op``
definitions give rise to implicit axioms that need to be sent to
Snark. In the case of ``type`` and ``op`` declarations, these axioms
correspond to the semantics of the |Metaslang| type system as
described in the language manual. In the case of an ``op`` definition,
these axioms correspond to lifting embedded conditionals from the body
of the definition as well as translating |Metaslang|'s pattern
matching to first-order logic. Note that a single definition can give
rise to multiple axioms. If the ``using`` clause of the proof unit is
omitted then these axioms will automatically be sent to Snark.
However, if an explicit ``using`` clause is used then only those
axioms that are explicitly mentioned are sent to Snark. In this case
to send the axioms corresponding to ``op`` \ ``op_name`` to Snark the
user would include the axiom ``op_name_def`` in the ``using`` clause.
Similarily to include the axioms for ``type`` \ ``type_name`` the user
should include the axioms ``type_name_def``\ .

Proof Errors
############

|Specware| will report an error if the claim to be proved does not
occur in the spec, or if not all claims following ``using`` occur in
the spec before the claim to be proved.

Snark will likely break into Lisp if the user inputs an incorrect
option.

Proof Log Files
###############

In the course of its execution Snark typically outputs a lot of
information as well as a proof when it finds one. All this output can
be overwhelming to the user, yet invaluable in understanding why the
proofs succeeded or failed. To deal with all this output |Specware|
redirects all the Snark output to log files. In our example above,
which executed a proof in the file ``pruf.sw``, |Specware| will create
a subdirectory called ``Snark`` at the same level as ``pruf.sw``. In
that directory a log file called ``pruf.log`` will be created that
contains all the Snark output. In this same directory a specware file
called ``pruf.sw`` will also be generated that includes an expanded
version of the original spec containing the theorem to be proved. The
original spec needs to be expanded before being passed to Snark
because the Snark's logic is different from Specware's, lacking
polymorphism and higher-order functions.

Multiple Proofs
###############

As there can be multiple units per file, there can be multiple proof
units in single file. For example, in file ``pruuf.sw`` we could
include more than one proof unit, as follows:

.. code-block:: specware

   p1  = prove prop1 using ax1, ax2
   p1a = prove prop1 using ax3
   p2  = prove prop2
   

In this case ``proc pruuf`` will invoke Snark three separate times,
writing three different log files. In this case an additional
subdirectory will be created under ``Snark``, called ``pruuf``. The
three log files will then be: ``Snark/pruuf/p1.log``,
``Snark/pruuf/p1a.log``, and ``Snark/pruuf/p2.log``.

Interrupting Snark
##################

As any first-order prover is wont to do, Snark is likely to either
loop forever or run for a longer time than the user can wait. The user
can provide a time limit for Snark by using an appropriate option.
However, there are likely to be times when the user wants to stop
Snark in the middle of execution. The user can do this by typing
Cntrl-\ ``C`` Cntrl-\ ``C`` in the *common-lisp* buffer. This will
then interrupt Snark and place the user in the Lisp debugger. The user
can exit the debugger by issuing the ``:pop`` command. A log file will
still be written that can be perused if so desired.

The Prover Base Library
#######################

|Specware| has a base library that is implicitly imported by every
spec. Unfortunately, the axioms in this library are not necessarily
written to be useful by Snark. Instead of having Snark use these
libraries we have created a separate base library for Snark. This
library is located at ``/Library/ProverBase/``. For each spec in
``/Library/Base/`` there is a corresponding prover spec that shadows
it. This prover base spec imports the 'op and 'type declarations from
the corresponding base spec, and substitututes for the original
definitions and axioms, axioms that are more appropriate for sending
to Snark. The axioms in these specs are automatically sent to Snark as
part of any proof.

The Experimental Nature of the Prover
#####################################

Our experience with the current prover interface is very new and as
such we are still very much experimenting with it and don't expect it
to be perfect at this point in time. Many simple theorems will be
provable. Some that the user thinks should be might not, and the user
will be required to add further hypothesis and lemmas that may seem
unnecessary. We are currently working on making this interface as
robust and predictable as possible, and welcome any feedback the user
can offer.

One area where the user can directly experiment is with the axioms
that make up the ``ProverBase``\ . The axioms that make up an
effective prover library are best determined by an experimental
evolutionary process. The user is welcome to play with the axioms in
the ``ProverBase``\ , by adding new ones or changing or deleting old
ones. Keep in mind the goal is to have a single library that is useful
for a wide range of proofs. Axioms that are specific to different
proofs should be created in separate specs and imported where needed.

