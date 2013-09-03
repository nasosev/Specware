LM qualifying spec

import /Languages/SpecCalculus/AbstractSyntax/Types

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This spec describes a rather generic structure for mapping symbols from one
%% language into terms for another.  It coordinates with the parsing rules in 
%% lm-rules.lisp
%%
%% Terms created here could fail to be meaningful (e.g. '(0.A) (A.X.4 :: <=)'
%% so any code using them must verify appropriately in context.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op lowercase (s : String) : String = map toLowerCase s % why not in string library?

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LanguageMorphism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Parsed a = | Parsed a
                | Error  String

op parseLanguageMorphism (s : String) : Parsed LanguageMorphism % defined in lm-parser-interface.lisp

type LanguageMorphisms = List LanguageMorphism
type LanguageMorphism  = {source   : Language,
                          target   : Language,
                          sections : Sections}

op make_LanguageMorphism (source   : Language, 
                          target   : Language, 
                          sections : Sections)
 : LanguageMorphism =
 {source   = source,
  target   = target,
  sections = sections}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Language
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Language = 
  | MetaSlang 
  | Lisp
  | C
  | Java
  | Haskell
  | Isabelle
  | ACL2
  | XML
  | Unknown String
            
op make_Language (s : String) : Language =
 case lowercase s of
   | "metaslang" -> MetaSlang 
   | "lisp"      -> Lisp
   | "c"         -> C
   | "java"      -> Java
   | "haskell"   -> Haskell
   | "isabelle"  -> Isabelle
   | "acl2"      -> ACL2
   | "xml"       -> XML
   |  _ ->
      let _ = writeLine ("Unknown language in translation pragma: " ^ s) in
      Unknown s

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sections
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Output for sections (other than Native) preserves the order in which those
%% sections are declared.
%%
%% E.g., we could emit verbatim text followed by imports followed by generated 
%% code then emit more verbatim text after that.
%%
%% TODO:  If multiple LanguageMorphism's are imported, how do we order them?

type Sections = List Section
type Section = | Verbatim  String
               | Imports   Imports
               | Morphism  Translations
               | Natives   Natives
               | Generated

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Verbatim
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op make_Verbatim_Section  (pre : String, body : String, post : String) 
 : Section = 
 Verbatim  body

op extract_verbatims (lms : LanguageMorphisms) : List String =
 foldl (fn (all_strs, lm) ->
          foldl (fn (all_strs, section) ->
                   case section of
                     | Verbatim str -> all_strs ++ [str]
                     | _ -> all_strs)
                all_strs
                lm.sections)
       []
       lms

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Imports
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op make_Imports_Section (imports : Imports)
 : Section = 
 Imports imports

op extract_imports (lms : LanguageMorphisms) : Imports =
 foldl (fn (all_imports, lm) ->
          foldl (fn (all_imports, section) ->
                   case section of
                     | Imports imports -> all_imports ++ imports
                     | _ -> all_imports)
                all_imports
                lm.sections)
       []
       lms

type Imports   = List Import
type Import    = Pathname

op printImport (lm_import : Import) : String =
 printPathname lm_import

type Pathname  = {directory : Option Directory,
                  name      : FileName,
                  extension : FileExtension}

type Directory = {root_slash? : Bool,
                  path        : DirectoryPath}

type DirectoryPath = List DirectoryId
type DirectoryId   = String              %% in practice, no dots or slashes
type FileName      = String              %% in practice, no dots or slashes
type FileExtension = String              %% in practice, no dots or slashes

op make_Directory (root_slash? : Bool, 
                   path        : DirectoryPath)
 : Directory =
 {root_slash? = root_slash?,
  path        = path}
                   
op printDirectory (dir : Directory) : String =
 foldl (fn (s, file_id) -> s ^ file_id ^ "/")
       (if dir.root_slash? then "/" else "")
       dir.path

op make_Pathname (directory : Option Directory, 
                  name      : FileName,
                  extension : FileExtension)
 : Pathname =
 {directory = directory,
  name      = name,
  extension = extension}

op printPathname (pathname : Pathname) : String =
 let dir_str  = case pathname.directory of
                  | Some dir -> printDirectory dir
                  | _ -> ""
 in
 let name_str = pathname.name      in
 let ext_str  = pathname.extension in
 dir_str ^ name_str ^ "." ^ ext_str

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Morphism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op make_Morphism_Section (translations : Translations)
 : Section = 
 Morphism translations

op extract_translations (lms : LanguageMorphisms) : Translations =
 foldl (fn (all_translations, lm) ->
          foldl (fn (all_translations, section) ->
                   case section of
                     | Morphism translations -> all_translations ++ translations
                     | _ -> all_translations)
                all_translations
                lm.sections)
       []
       lms

type Translations = List Translation
type Translation  = | Type  TypeTranslation
                    | Field FieldTranslation
                    | Op    OpTranslation

op printTranslation (lm_translation : Translation) : String =
  case lm_translation of
    | Type  trans -> printTypeTranslation  trans
    | Field trans -> printFieldTranslation trans
    | Op    trans -> printOpTranslation    trans

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Names
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Symbol  = String               %% in practice, no dots

type Name    = List Symbol

op printName (name : Name) : String =
 let hd :: tail = name in
 foldl (fn (str, sym) -> str ^ "," ^ sym)
       hd
       tail

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Terms (for both ops and types)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Terms = List Term
type Term  = | Name  Name
             | List  SeqTerm
             | Apply ApplyTerm
             | Typed TypedTerm 

type SeqTerm   = {terms : Terms, separator : String}
type ApplyTerm = {x     : Term,  y         : Term}
type TypedTerm = {typ   : Term,  trm       : Term}

op make_Name_Term  (name  : Name)             : Term = Name name
op make_List_Term  (terms : Terms)            : Term = List  {terms = terms, separator = " "}
op make_Apply_Term (x     : Term, y   : Term) : Term = Apply {x     = x,     y         = y}
op make_Typed_Term (typ   : Term, trm : Term) : Term = Typed {typ   = typ,   trm       = trm}

op printTerm (term : Term) : String =
 case term of 
   | Name  name  -> printName      name
   | List  sterm -> printSeqTerm   sterm
   | Apply aterm -> printApplyTerm aterm
   | Typed tterm -> printTypedTerm tterm

op printSeqTerm (seq : SeqTerm) : String =
 case seq.terms of
   | [] -> "()"
   | hd :: tail ->
     "(" ^
     foldl (fn (str, tm) -> str ^ seq.separator ^ printTerm tm) 
           (printTerm hd)
           tail
     ^ ")"

op printApplyTerm (aterm : ApplyTerm) : String =
 printTerm aterm.x ^ "(" ^ printTerm aterm.y ^ ")"

op printTypedTerm (tterm : TypedTerm) : String =
 "((" ^ printTerm tterm.typ ^ ") " ^ printTerm tterm.trm ^ ")"

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Location
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Location = | Pathname Pathname
                | Primitive

op make_Pathname_Location (pathname : Pathname)
 : Location =
 Pathname pathname  

op make_Primitive_Location ()
 : Location =
 Primitive

op printLocation (location : Location) : String =
 case location of
   | Pathname pathname -> "in " ^ printPathname pathname
   | Primitive         -> "primitive"

op printOptionalLocation (x : Option Location) : String =
 case x of
   | Some location -> " \t " ^ printLocation location
   | _ -> ""

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% TypeTranslation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type TypeTranslation = {source   : Name, 
                        target   : Term,
                        location : Option Location}

op make_Type_Translation (source   : Name, 
                          target   : Term,
                          location : Option Location)
 : Translation =
 Type {source   = source, 
       target   = target, 
       location = location}

op printTypeTranslation (trans : TypeTranslation) : String =
 "Translate type:  "     ^ 
 printName trans.source  ^ 
 " \t=> "                ^ 
 printTerm trans.target  ^
 printOptionalLocation trans.location

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FieldTranslation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type FieldId  = Symbol
type FieldRef = {type_name : Name, field_id : FieldId}

type FieldTranslation = {source   : FieldRef, 
                         target   : FieldRef,
                         location : Option Location}

op make_Field_Translation (source   : FieldRef,
                           target   : FieldRef,
                           location : Option Location)
 : Translation =
 Field {source   = source,
        target   = target,
        location = location}

op make_FieldRef (type_name : Name, 
                  field_id  : FieldId)
 : FieldRef =
 {type_name = type_name,
  field_id  = field_id}

op printFieldRef (ref : FieldRef) : String =
 (printName ref.type_name) ^ "." ^ ref.field_id

op printFieldTranslation (trans : FieldTranslation) : String =
 "Translate field: "         ^ 
 printFieldRef trans.source  ^
 " \t=> "                    ^ 
 printFieldRef trans.target

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% OpTranslation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type OpTranslation = {source     : Name, 
                      target     : Term,
                      recurry    : Option ReCurry,
                      reversed?  : Bool,
                      fixity     : Option LM_Fixity,
                      precedence : Option Nat,
                      location   : Option Location}

type LM_Fixity = | Left | Right | Infix

op make_LM_Fixity (s : String) : LM_Fixity =
   case lowercase s of
     | "right" -> Right 
     | "left"  -> Left 
     | "infix" -> Infix

op make_Op_Translation (source     : Name, 
                        target     : Term,
                        recurry    : Option ReCurry,
                        fixity     : Option LM_Fixity,
                        precedence : Option Nat,
                        reversed?  : Bool,
                        location   : Option Location)
 : Translation =
 Op {source     = source,
     target     = target,
     recurry    = recurry,
     fixity     = fixity,
     precedence = precedence,
     reversed?  = reversed?,
     location   = location}

%%% --------

type ReCurry = | Curry | UnCurry

op make_ReCurry (s : String) 
 : ReCurry =
 case lowercase s of
   | "curry"   -> Curry
   | "uncurry" -> UnCurry

op printOpTranslation (trans : OpTranslation) : String =
 "Translate op:    "    ^ 
 printName trans.source ^ 
 " \t=> "               ^ 
 printTerm trans.target 
 ^
 (case trans.recurry of
    | Some recurry -> " recurry"
    | _ -> "")
 ^
 (case trans.fixity of
    | Some Left  -> " left"
    | Some Right -> " right"
    | Some Infix -> " infix"
    | _ -> "")
 ^
 (case trans.precedence of
    | Some n -> Nat.show n
    | _ -> "")
 ^
 (if trans.reversed? then " reversed" else "")
 ^
 printOptionalLocation trans.location

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Natives
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op make_Natives_Section (natives : Natives)
 : Section = 
 Natives natives

op extract_natives (lms : LanguageMorphisms) : Natives =
 foldl (fn (all_natives, lm) ->
          foldl (fn (all_natives, section) ->
                   case section of
                     | Natives natives -> all_natives ++ natives
                     | _ -> all_natives)
                all_natives
                lm.sections)
       []
       lms

type Natives = List Native  
type Native  = | Type {name : Name, location : Option Location}
               | Op   {name : Name, location : Option Location}

op make_Type_Native (name     : Name,
                     location : Option Location)
 : Native = 
 Type {name = name, location = location}

op make_Op_Native   (name     : Name, 
                     location : Option Location) 
 : Native = 
 Op {name = name, location = location}

op printNative (lm_native : Native) : String =
 case lm_native of
   | Type {name, location} -> 
     "Native type " ^ printName name ^ printOptionalLocation location

   | Op   {name, location} -> 
     "Native op " ^ printName name ^ printOptionalLocation location

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Generated
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op make_Generated_Section ()                                           : Section = Generated

end-spec

