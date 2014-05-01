#Check the number of arguments supplied:
if [ $# -ne 2 ]
then
    echo "test.sh: Error: Arguments must be the Specware installation to test and ISABELLE_2013_2_ROOT."
    exit 1
fi

export SPECWARE4=$1
echo "Library/DataStructures/test.sh: SPECWARE4 is ${SPECWARE4}."
ISABELLE_2013_2_ROOT=$2

echo "  Testing Library/DataStructures:"

# TODO Is this now complete?
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Sets
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Maps
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Maps#Maps_extended
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Bags
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Stacks
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/STBase
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StructuredTypes
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsBags#SetsAsBags
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsBags#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsMaps#SetsAsMaps
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsMaps#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/BagsAsMaps#BagsAsMaps
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/BagsAsMaps#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSTHTables#MapsAsSTHTables
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/POSet
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Extensions
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/Collections
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/AllIsa
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsLists#SetsAsLists
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsLists#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsLists
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsLists#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/BagsAsLists#BagsAsLists
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/BagsAsLists#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsSTHTables0#SetsAsSTHTables0
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsSTHTables0#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsVectors#MapsAsVectors
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsVectors#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSTHTables#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsBTVectors#MapsAsBTVectors
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsBTVectors#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsVectors#StacksAsVectors
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsVectors#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/All
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsCoproducts # not included in All.sw
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsCoproducts#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsLists # not included in All.sw
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsLists#M
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSets#MapsAsSets # not included in All.sw
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSets#M # not included in All.sw
run-proc.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsBagMaps#SetsAsBagMaps # not included in All.sw

echo "  Removing existing Isabelle obligations:"
clear-isabelle-dir.sh ${SPECWARE4}/Library/DataStructures/Isa

echo "  Generating Isabelle obligations:"

run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSets#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsMaps#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsBagMaps#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/SetsAsBags#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/BagsAsMaps#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsCoproducts#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/StacksAsLists#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsSTHTables#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/MapsAsVectors#M
run-gen-obligs.sh ${SPECWARE4} ${SPECWARE4}/Library/DataStructures/AllIsa
#This replaces the separate calls to run-isabelle2013-2.sh below and is faster:
run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/IsabelleWrapper.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/MapsAsSets_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/SetsAsMaps_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/SetsAsBagMaps_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/SetsAsBags_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/BagsAsMaps_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/StacksAsCoproducts_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/StacksAsLists_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/MapsAsSTHTables_M.thy ${ISABELLE_2013_2_ROOT}
# run-isabelle2013-2.sh ${SPECWARE4}/Library/DataStructures/Isa/MapsAsVectors_M.thy ${ISABELLE_2013_2_ROOT}
