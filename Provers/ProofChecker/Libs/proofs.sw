% OL = obligations Logic   % crash


OPF = obligations PartialFunctions

PPF = prove o_Obligation in OPF   % crash


OPSP = obligations ProtoSetsParameter   % none


OPS = obligations ProtoSets   % fails to generate obligation for "the"


OPSIF = obligations ProtoSetsInstantiationFinite   % none


OPSIA = obligations ProtoSetsInstantiationAll   % none


OFS = obligations FiniteSets

PFS1 = prove fold_Obligation  in OFS   % crash
PFS2 = prove fold_Obligation0 in OFS   % crash
PFS3 = prove fold_Obligation1 in OFS   % crash
PFS4 = prove size_Obligation  in OFS   % crash


OS = obligations Sets
