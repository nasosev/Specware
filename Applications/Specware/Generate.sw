let
  Specware = spec {
      import /Languages/MetaSlang/Specs/Printer
      import /Languages/MetaSlang/Specs/Elaborate/TypeChecker
      import /Library/Structures/Data/Categories/Diagrams/Polymorphic/AsRecord
    } 
  % S = printF Specware
in
  generate "lisp" Specware
