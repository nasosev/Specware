/*
 * MetaSlangGrammar.g
 *
 * $Id$
 *
 *
 *
 * $Log$
 * Revision 1.13  2003/02/17 07:04:09  weilyn
 * Made scURI return an Item, and added more rules for scProve.
 *
 * Revision 1.12  2003/02/17 04:35:26  weilyn
 * Added support for expressions.
 *
 * Revision 1.11  2003/02/16 02:16:03  weilyn
 * Added support for defs.
 *
 * Revision 1.10  2003/02/14 17:00:38  weilyn
 * Added prove term to grammar.
 *
 * Revision 1.9  2003/02/13 19:44:09  weilyn
 * Added code to create claim objects.
 *
 * Revision 1.8  2003/02/10 15:38:36  gilham
 * Allow non-word symbols only as op names, not as sort names or unit ids.
 *
 * Revision 1.7  2003/02/08 01:26:59  weilyn
 * Added rules to recognize claims and sort definitions
 *
 * Revision 1.6  2003/02/07 20:06:19  gilham
 * Added opDefinition and scURI to MetaSlangGrammar.
 *
 * Revision 1.5  2003/01/31 17:38:33  gilham
 * Removed token recording code.
 *
 * Revision 1.4  2003/01/31 15:34:08  gilham
 * Defined nonWordSymbol[String expected] parser rule to handle ":", "=", "*", etc.
 * used in the language syntax.
 *
 * Revision 1.3  2003/01/31 00:47:15  gilham
 * Fixed a bug in the lexer rule for block comments.
 *
 * Revision 1.2  2003/01/30 22:02:38  gilham
 * Improved parse error messages for non-word symbols such as ":".
 *
 * Revision 1.1  2003/01/30 02:02:18  gilham
 * Initial version.
 *
 *
 */

header {
package edu.kestrel.netbeans.parser;
}

//---------------------------------------------------------------------------
//============================   MetaSlangParserFromAntlr   =============================
//---------------------------------------------------------------------------

{
import java.util.*;

import org.netbeans.modules.java.ErrConsumer;

import edu.kestrel.netbeans.model.*;
import edu.kestrel.netbeans.parser.ElementFactory;
import edu.kestrel.netbeans.parser.ParserUtil;
}

class MetaSlangParserFromAntlr extends Parser;
options {
    k=3;
    buildAST=false;
//    defaultErrorHandler=false;
}

//---------------------------------------------------------------------------
starts
{
    Token firstToken = LT(1);
}
    : (  (scDecl) => scToplevelDecls
       | scToplevelTerm
      )                     {Token lastToken = LT(0);
                             if (lastToken != null && lastToken.getText() != null) {
                                 ParserUtil.setBodyBounds(builder, (ElementFactory.Item)builder, firstToken, lastToken);
                             }}
    ;

private scToplevelTerm 
{
    ElementFactory.Item ignore;
}
    : ignore=scTerm[null]
    ;

private scToplevelDecls
    : scDecl (scDecl)*
    ;

private scDecl
{
    String ignore;
    ElementFactory.Item ignore2;
    Token unitIdToken = null;
}
    : ignore=name           {unitIdToken = LT(0);}
      equals
      ignore2=scTerm[unitIdToken]
    ;

private scTerm[Token unitIdToken] returns[ElementFactory.Item item]
{
    item = null;
}
    : ( item=specDefinition[unitIdToken]
      | item=scProve[unitIdToken]
      )                     {if (item != null) builder.setParent(item, null);}
    ;

//---------------------------------------------------------------------------
// TODO: scURI should really be an object that has parameters (bool relOrAbs, string path, scTermItem optionalRef)
private scURI returns[ElementFactory.Item uri]
{
    uri = null;
    String strURI = null;
}
    : strURI=fullURIPath
    ;

private fullURIPath returns[String path]
{
    path = null;
    String item = null;
}
    : (   (nonWordSymbol["/"]) => nonWordSymbol["/"] 
                                  item=partialURIPath        {path = "/" + item;}
        | item=partialURIPath                                {path = item;}
      )
      (ref:INNER_UNIT_REF)?
    ;

private partialURIPath returns[String path]
{
    path = "";
    String item = null;
}
    : id:IDENTIFIER                                     {path = path + id.getText();} 
      ( (nonWordSymbol["/"]) => nonWordSymbol["/"] 
                                item=partialURIPath     {path = path + "/" + item;}
      |
      )
    ;

//---------------------------------------------------------------------------
private specDefinition[Token unitIdToken] returns[ElementFactory.Item spec]
{
    spec = null;
    ElementFactory.Item childItem = null;
    Token headerEnd = null;
    List children = new LinkedList();
    String name = (unitIdToken == null) ? "" : unitIdToken.getText();
}
    : begin:"spec"          {headerEnd = begin;}
      (childItem=declaration
                            {if (childItem != null) children.add(childItem);}
      )*
      end:"endspec"
                            {spec = builder.createSpec(name);
                             if (unitIdToken != null) {
                                 begin = unitIdToken;
                             }
                             builder.setParent(children, spec);
                             ParserUtil.setAllBounds(builder, spec, begin, headerEnd, end);
                             }
    ;

private scProve[Token unitIdToken] returns[ElementFactory.Item prove]
{
    prove = null;
    ElementFactory.Item childItem = null;
    String ignore = null;
    Token headerEnd = null;
    List children = new LinkedList();
    String name = (unitIdToken == null) ? "" : unitIdToken.getText();
}
    : begin:"prove"                     {headerEnd = begin;}
      childItem=claimName               {if (childItem != null) children.add(childItem);}
      "in"
      //childItem=scURI                   {if (childItem != null) children.add(childItem);}
      ignore=fullURIPath
      (childItem=proverAssertions)?     {if (childItem != null) children.add(childItem);}
      (childItem=proverOptions)?        {if (childItem != null) children.add(childItem);}
                                        /*{prove = builder.createProve(name);
                                         if (unitIdToken != null) {
                                            begin = unitIdToken;
                                         }
                                         builder.setParent(children, prove);
                                         ParserUtil.setAllBounds(builder, prove, begin, headerEnd, LT(0));
                                         }*/
    ;

private claimName returns[ElementFactory.Item claimName]
{
    claimName = null;
    String ignore = null;
}
    : ignore=name
    ;

private proverAssertions returns[ElementFactory.Item assertionsItem]
{
    assertionsItem = null;
    String anAssertion = null;
}
    : "using" 
      (anAssertion=name
      )+
    ;

private proverOptions returns[ElementFactory.Item optionsItem]
{
    optionsItem = null;
    String anOption = null;
}
    : "options"
      (anOption=name
      )+
    ;

private qualifier returns[String qlf]
{
    qlf = null;
}
    : qlf=name
    ;

//!!! TO BE EXTENDED !!!
private name returns[String name]
{
    name = null;
}
    : name=idName
    ;

private declaration returns[ElementFactory.Item item]
{
    item = null;
}
    : item=importDeclaration
    | item=sortDeclarationOrDefinition
    | item=opDeclaration
    | item=definition
    ;

//---------------------------------------------------------------------------
private importDeclaration returns[ElementFactory.Item importItem]
{
    importItem = null;
    String strURI = null;
}
    : begin:"import"
      strURI=fullURIPath    {importItem = builder.createImport(strURI);
                             ParserUtil.setBounds(builder, importItem, begin, LT(0));
                            }
    ;

//---------------------------------------------------------------------------
private sortDeclarationOrDefinition returns[ElementFactory.Item sort]
{
    sort = null;
    String[] params = null;
    String sortName = null;
    String sortDef = null;
}
    : begin:"sort" 
      sortName=qualifiableSortNames
      ((formalSortParameters) => 
            (params=formalSortParameters) (equals sortDef=sort)?
          | (equals sortDef=sort)?
      )
                           {sort = builder.createSort(sortName, params);
                             ParserUtil.setBounds(builder, sort, begin, LT(0));
                           }
    ;

private qualifiableSortNames returns[String sortName]
{
    sortName = null;
    String member = null;
    String qlf = null;
}
    : sortName=qualifiableSortName
    | LBRACE 
      member=qualifiableSortName
                            {sortName = "{" + member;}
      (COMMA member=qualifiableSortName
                            {sortName = sortName + ", " + member;}
      )*
      RBRACE                {sortName = sortName + "}";}
      
                            
    ;

private qualifiableSortName returns[String sortName]
{
    sortName = null;
    String qlf = null;
}
    : (qlf=qualifier DOT)?
      sortName=idName
                            {if (qlf != null) sortName = qlf + "." + sortName;}
    ;

private idName returns[String name]
{
    name = null;
}
    : id:IDENTIFIER         {name = id.getText();}
    ;

private formalSortParameters returns[String[] params]
{
    params = null;
    String param = null;
    List paramList = null;
}
    : param=idName
                            {params = new String[]{param};}
    | LPAREN                {paramList = new LinkedList();}
      param=idName
                            {paramList.add(param);}
      (COMMA 
       param=idName
                            {paramList.add(param);}
      )* 
      RPAREN                {params = (String[]) paramList.toArray(new String[]{});}
    ;

//---------------------------------------------------------------------------
//!!! TODO: fixity !!!
private opDeclaration returns[ElementFactory.Item op]
{
    op = null;
    String name = null;
    String sort = null;
}
    : begin:"op" 
      name=qualifiableOpNames
      nonWordSymbol[":"] 
      sort=sort
                            {op = builder.createOp(name, sort);
                             ParserUtil.setBounds(builder, op, begin, LT(0));
                            }
    ;

private qualifiableOpNames returns[String opName]
{
    opName = null;
    String member = null;
    String qlf = null;
}
    : opName=qualifiableOpName
    | LBRACE 
      member=qualifiableOpName
                            {opName = "{" + member;}
      (COMMA member=qualifiableOpName
                            {opName = opName + ", " + member;}
      )*
      RBRACE                {opName = opName + "}";}
      
                            
    ;

private qualifiableOpName returns[String opName]
{
    opName = null;
    String qlf = null;
}
    : (qlf=qualifier DOT)?
      opName=opName
                            {if (qlf != null) opName = qlf + "." + opName;}
    ;

private opName returns[String opName]
{
    opName = null;
}
    : id:IDENTIFIER         {opName = id.getText();}
    | sym:NON_WORD_SYMBOL   {opName = sym.getText();}
    ;

private sort returns[String sort]
{
    String text = null;
    sort = "";
}
    : (text=qualifiableRef
                            {sort = sort + text;}
       | text=literal
                            {sort = sort + text;}
       | text=specialSymbol
                            {sort = sort + text;}
       | text=expressionKeyword
                            {sort = sort + text;}
      )+
    ;

//---------------------------------------------------------------------------
private definition returns[ElementFactory.Item item]
{
    item=null;
}
    : item=opDefinition
    | item=claimDefinition
    ;

private opDefinition returns[ElementFactory.Item def]
{
    def = null;
    String name = null;
    String[] params = null;
    String expr = null;
}
    : begin:"def"
      name=qualifiableOpNames
      ((formalOpParameters equals) => params=formalOpParameters equals
       | equals) 
      expr=expression            {def = builder.createDef(name, params, expr);
                                  ParserUtil.setBounds(builder, def, begin, LT(0));
                                 }
    ;

private claimDefinition returns[ElementFactory.Item claim]
{
    claim = null;
    String name = null;
    String kind = null;
    Token begin = null;
    String expr = null;
}
    : kind=claimKind       {begin = LT(0);}
      name=idName
      equals
      expr=expression
                           {claim = builder.createClaim(name, kind, expr);
                            ParserUtil.setBounds(builder, claim, begin, LT(0));
                           }

    ;

private claimKind returns[String kind]
{
    kind = null;
}
    : "theorem"            {kind = "theorem";}
    | "axiom"              {kind = "axiom";}
    | "conjecture"         {kind = "conjecture";}
    ;

private expression returns[String expr]
{
    expr = "";
    String item = null;
}
    : (  item=qualifiableRef    {expr = expr + item + " ";}
       | item=literal           {expr = expr + item + " ";}
       | item=specialSymbol     {expr = expr + item + " ";}
       | item=expressionKeyword {expr = expr + item + " ";}
      )+
    ;

private formalOpParameters returns[String[] params]
{
    params = null;
    String param = null;
    List paramList = null;
}
    : param=idName
                            {params = new String[]{param};}
    | LPAREN                {paramList = new LinkedList();}
      (param=idName
                            {paramList.add(param);}
       (COMMA 
        param=idName
                            {paramList.add(param);}
       )*)?
      RPAREN                {params = (String[]) paramList.toArray(new String[]{});}
    ;

//---------------------------------------------------------------------------
private specialSymbol returns[String text]
{
    text = null;
}
    : UBAR                  {text = "_";}
    | LPAREN                {text = "(";}
    | RPAREN                {text = "}";}
    | LBRACKET              {text = "[";}
    | RBRACKET              {text = "]";}
    | LBRACE                {text = "{";}
    | RBRACE                {text = "}";}
    | COMMA                 {text = ", ";}
//    | SEMICOLON             {text = ";";}
//    | DOT                   {text = ".";}
    ;

private literal returns[String text]
{
    text = null;
}
    : text=booleanLiteral
    | t1:NAT_LITERAL        {text = t1.getText();}
    | t2:CHAR_LITERAL       {text = t2.getText();}
    | t3:STRING_LITERAL     {text = t3.getText();}
    ;

private booleanLiteral returns[String text]
{
    text = null;
}
    : t1:"true"             {text = "true ";}
    | t2:"false"            {text = "false ";}
    ;

private expressionKeyword returns[String text]
{
    text = null;
}
    : "as"                  {text = "as ";}
    | "case"                {text = "case ";}
    | "choose"              {text = "choose ";}
    | "else"                {text = "else ";}
    | "embed"               {text = "embed ";}
    | "embed?"              {text = "embed? ";}
    | "ex"                  {text = "ex ";}
    | "fa"                  {text = "fa ";}
    | "fn"                  {text = "fn ";}
    | "if"                  {text = "if ";}
    | "in"                  {text = "in ";}
    | (  ("let" "def") => "let" "def"               
                            {text = "let def";}
       | "let"              {text = "let";}
      )
    | "of"                  {text = "of ";}
    | "project"             {text = "project ";}
    | "quotient"            {text = "quotient ";}
    | "relax"               {text = "relax ";}
    | "restrict"            {text = "restrict ";}
    | "then"                {text = "then ";}
    | "where"               {text = "where ";}
    ; 

private qualifiableRef returns[String name]
{
    name = null;
}
    // 
    : name=qualifiableOpName
    ;

//---------------------------------------------------------------------------
private equals
    : nonWordSymbol["="]
    | "is"
    ;

//---------------------------------------------------------------------------
// Used to refer to any specific NON_WORD_SYMBOL in the Specware language syntax,
// e.g. ":", "=", "*", "/", "|", "->".  (If these are defined as tokens, the 
// lexer will be nonderterministic.)
private nonWordSymbol[String expected]
    : t:NON_WORD_SYMBOL     {t.getText().equals(expected)}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"" + expected + "\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

//---------------------------------------------------------------------------
//=============================   MetaSlangLexerFromAntlr   =============================
//---------------------------------------------------------------------------

class MetaSlangLexerFromAntlr extends Lexer;

options {
    k=4;
    testLiterals=false;
}

// a dummy rule to force vocabulary to be all characters (except special
// ones that ANTLR uses internally (0 to 2) 

protected
VOCAB
    : '\3'..'\377'
    ;

//-----------------------------
//====== WHITESPACE ===========
//-----------------------------

// Whitespace -- ignored
WHITESPACE
    : ( ' '
      | '\t'
      | '\f'
      // handle newlines
      | ( "\r\n"  // DOS
        | '\r'    // Macintosh
        | '\n'    // Unix
        )                   {newline();}
      )                     {_ttype = Token.SKIP;}
    ;


// Single-line comments -- ignored
LINE_COMMENT
    : '%'
      (~('\n'|'\r'))* ('\n'|'\r'('\n')?)
                            {newline();
			    _ttype = Token.SKIP;}
    ;


// multiple-line comments -- ignored
BLOCK_COMMENT
    : "(*"
      (// '\r' '\n' can be matched in one alternative or by matching
       // '\r' in one iteration and '\n' in another.  The language
       // that allows both "\r\n" and "\r" and "\n" to be valid
       // newlines is ambiguous.  Consequently, the resulting grammar
       // must be ambiguous.  This warning is shut off.
       options {generateAmbigWarnings=false;}
       : { LA(2)!=')' }? '*'
	 | '\r' '\n'		{newline();}
	 | '\r'			{newline();}
	 | '\n'			{newline();}
	 | ~('*'|'\n'|'\r')
      )*
      "*)"                  {_ttype = Token.SKIP;}
    ;

//-----------------------------
//==== SPECIFIC CHARACTERS  ===
//-----------------------------


UBAR
options {
  paraphrase = "'_'";
}
    :  "_"
    ;

LPAREN
options {
  paraphrase = "'('";
}
    : '('
    ;
RPAREN
options {
  paraphrase = "')'";
}
    : ')'
    ;
LBRACKET
options {
  paraphrase = "'['";
}
    : '['
    ;
RBRACKET
options {
  paraphrase = "']'";
}
    : ']'
    ;
LBRACE
options {
  paraphrase = "'{'";
}
    : '{'
    ;
RBRACE
options {
  paraphrase = "'}'";
}
    : '}'
    ;
COMMA
options {
  paraphrase = "','";
}
    : ','
    ;
SEMICOLON
options {
  paraphrase = "';'";
}
    : ';'
    ;
DOT
options {
  paraphrase = "'.'";
}
    : '.'
    ;
DOTDOT
options {
  paraphrase = "'..'";
}
    :  ".."
    ;

//-----------------------------
//=== ALL LETTERS and DIGITS ==
//-----------------------------

protected
LETTER
    : ('A'..'Z')
    | ('a'..'z')
    ;

protected
DIGIT
    : ('0'..'9')
    ;

//-----------------------------
//=== INNER_UNIT_REF ================
//-----------------------------

INNER_UNIT_REF
options {
  paraphrase = "an inner-unit reference";
}
    : '#' WORD_START_MARK (WORD_CONTINUE_MARK)+
    ;

//-----------------------------
//=== Literals ================
//-----------------------------

NAT_LITERAL
options {
  paraphrase = "an integer";
}
    : '0'                   
    | ('1'..'9') ('0'..'9')*
    ;

// character literals
CHAR_LITERAL
options {
  paraphrase = "a character";
}
    : '#' CHAR_GLYPH
    ;

protected CHAR_GLYPH
    : LETTER
    | DIGIT
    | OTHER_CHAR_GLYPH
    ;

protected OTHER_CHAR_GLYPH
    : '!' | ':' | '@' | '#' | '$' | '%' | '^' | '&' | '*' | '(' | ')' | '_' | '-' | '+' | '='
    | '|' | '~' | '`' | '.' | ',' | '<' | '>' | '?' | '/' | ';' | '\'' | '[' | ']' | '{' | '}'
    | ESC
    | '\\' 'x' HEXADECIMAL_DIGIT HEXADECIMAL_DIGIT
    ;

protected ESC
    : '\\'
      ( 'a'
      | 'b'
      | 't'
      | 'n'
      | 'v'
      | 'f'
      | 'r'
      | 's'
      | '"'
      | '\\'
      )
    ;

protected HEXADECIMAL_DIGIT
    : DIGIT
    | ('a'..'f')
    | ('A'..'F')
    ;

// string literals
STRING_LITERAL
options {
  paraphrase = "a string";
}
    : '"' (STRING_LITERAL_GLYPH)* '"'
    ;

protected STRING_LITERAL_GLYPH
    : LETTER
    | DIGIT
    | OTHER_CHAR_GLYPH
    | ' '
    ;



//-----------------------------
//====== IDENTIFIERS ==========
//-----------------------------

IDENTIFIER  options
{
    paraphrase = "an identifier";
    testLiterals = true;
}
    : WORD_START_MARK (WORD_CONTINUE_MARK)*
    ;

protected WORD_START_MARK
    : LETTER
    ;

protected WORD_CONTINUE_MARK
    : LETTER | DIGIT | '_' | '?'
    ;

//-----------------------------
//====== NON-WORD SYMBOLS =====
//-----------------------------

NON_WORD_SYMBOL
    : (NON_WORD_MARK)+
    ;

protected NON_WORD_MARK
    : '`' | '~' | '!' | '@' 
    | '$' | '^' | '&' | '-'
    | '+' | '<' | '>' | '?' 
    | '*' | '=' | ':' | '|' 
    | '\\' | '/' 
    ;


// java antlr.Tool MetaSlangGrammar.g > MetaSlangGrammar.log
