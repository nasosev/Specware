/*
 * MetaSlangGrammar.g
 *
 * $Id$
 *
 *
 *
 * $Log$
 * Revision 1.23  2003/03/21 02:48:45  weilyn
 * Attempting to add entire SpecCalculus grammar.  Added patterns,
 * expressions, and sorts.  Updated existing rules to use new
 * SpecCalculus rules.  Still needs a lot of work...
 *
 * Revision 1.22  2003/03/19 21:33:13  gilham
 * Fixed LATEX_COMMENT to handle  comment blocks not ended with
 * "\begin{spec}".
 *
 * Revision 1.21  2003/03/19 19:25:43  weilyn
 * Added patterns.
 * Made "\end{spec}" a starting latex comment token in lexer.
 *
 * Revision 1.20  2003/03/19 18:36:46  gilham
 * Fixed a bug in the Lexer that caused the token for "\end{spec}" not being skipped.
 *
 * Revision 1.19  2003/03/14 04:15:31  weilyn
 * Added support for proof terms
 *
 * Revision 1.18  2003/03/13 01:23:55  gilham
 * Handle Latex comments.
 * Report Lexer errors.
 * Always display parser messages (not displayed before if the parsing succeeded
 * and the parser output window is not open).
 *
 * Revision 1.17  2003/03/12 03:01:56  weilyn
 * no message
 *
 * Revision 1.16  2003/03/07 23:44:24  weilyn
 * Added most top level terms
 *
 * Revision 1.15  2003/02/20 23:17:41  weilyn
 * Fixed parsing of assertions and options in prove term
 *
 * Revision 1.14  2003/02/18 18:10:14  weilyn
 * Added support for imports.
 *
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
    : (  scToplevelDecls
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
    : ( item=scBasicTerm[unitIdToken]
      | item=scSubstitute[unitIdToken]
      )                     {if (item != null) builder.setParent(item, null);}
    ;

// These are the non-left-recursive terms
private scBasicTerm[Token unitIdToken] returns[ElementFactory.Item item]
{
    item = null;
}
    : item=scPrint[unitIdToken]
    | item=scURI[unitIdToken]
    | item=specDefinition[unitIdToken]
    | item=scLet[unitIdToken]
    | item=scTranslate[unitIdToken]
    | item=scQualify[unitIdToken]
    | item=scDiag[unitIdToken]
    | item=scColimit[unitIdToken]
    | item=scSpecMorph[unitIdToken]
    | item=scGenerate[unitIdToken]
    | item=scObligations[unitIdToken]
    | item=scProve[unitIdToken]
    ;

//---------------------------------------------------------------------------

private scPrint[Token unitIdToken] returns[ElementFactory.Item print]
{
    print = null;
    ElementFactory.Item ignore = null;
}
    : "print"
      ignore=scTerm[null]
    ;

// TODO: scURI should really be an object that has parameters (bool relOrAbs, string path, scTermItem optionalRef)
private scURI[Token unitIdToken] returns[ElementFactory.Item uri]
{
    uri = null;
    String strURI = null;
}
    : strURI=fullURIPath
    ;

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

private scLet[Token unitIdToken] returns[ElementFactory.Item let]
{
    let = null;
    ElementFactory.Item ignore = null;
}
    : "let"
      (scDecl
      )*
      "in"
      ignore=scTerm[unitIdToken]
    ;

private scTranslate[Token unitIdToken] returns[ElementFactory.Item translate]
{
    translate = null;
    ElementFactory.Item ignore = null;
}
    : "translate"
      ignore=scTerm[null]
      "by"
      nameMap
    ;

private scQualify[Token unitIdToken] returns[ElementFactory.Item qualify]
{
    qualify = null;
    String strIgnore = null;
    ElementFactory.Item itemIgnore = null;
}
    : strIgnore=qualifier
      "qualifying"
      itemIgnore=scTerm[null]
    ;

private scDiag[Token unitIdToken] returns[ElementFactory.Item diag]
{
    diag = null;
    ElementFactory.Item ignore = null;
}
    : "diagram"
      LBRACE
      scDiagElem
      (COMMA scDiagElem
      )*
      RBRACE
    ;

private scColimit[Token unitIdToken] returns[ElementFactory.Item colimit]
{
    colimit = null;
    ElementFactory.Item ignore = null;
}
    : "colimit"
      ignore=scTerm[null]
    ;

private scSubstitute[Token unitIdToken] returns[ElementFactory.Item substitute]
{
    substitute = null;
    ElementFactory.Item ignore = null;
}
    : ignore=scBasicTerm[null]
      scSubstituteTermList
    ;

private scSpecMorph[Token unitIdToken] returns[ElementFactory.Item morph]
{
    morph = null;
    ElementFactory.Item childItem = null;
    ElementFactory.Item ignore = null;
    Token headerEnd = null;
}

    : begin:"morphism"        {headerEnd = begin;}
      ignore=scTerm[null]
      nonWordSymbol["->"]
      ignore=scTerm[null]
      nameMap
    ;

private scGenerate[Token unitIdToken] returns[ElementFactory.Item generate]
{
    generate = null;
    String genName = null;
    String fileName = null;
    ElementFactory.Item ignore = null;
    Token headerEnd = null;
}
    : begin:"generate"        {headerEnd = begin;}
      genName=name
      ignore=scTerm[null]
      ("in" STRING_LITERAL
      )?
    ;

private scObligations[Token unitIdToken] returns[ElementFactory.Item obligations]
{
    obligations=null;
    ElementFactory.Item ignore=null;
    Token headerEnd = null;
}
    : begin:"obligations"     {headerEnd = begin;}
      ignore=scTerm[null]
    ;

private scProve[Token unitIdToken] returns[ElementFactory.Item proof]
{
    proof = null;
    ElementFactory.Item childItem = null;
    String ignore = null;
    Token headerEnd = null;
    List children = new LinkedList();
    String name = (unitIdToken == null) ? "" : unitIdToken.getText();
}
    : begin:"prove"                     {headerEnd = begin;}
      childItem=claimName               {if (childItem != null) children.add(childItem);}
      "in"
      childItem=scTerm[null]            {if (childItem != null) children.add(childItem);}
      (childItem=proverAssertions)?     {if (childItem != null) children.add(childItem);}
      (childItem=proverOptions)?        {if (childItem != null) children.add(childItem);}
                                        {proof = builder.createProof(name);
                                         if (unitIdToken != null) {
                                            begin = unitIdToken;
                                         }
                                         builder.setParent(new LinkedList()/*children*/, proof);
                                         ParserUtil.setAllBounds(builder, proof, begin, headerEnd, LT(0));
                                         }
    ;

//---------------------------------------------------------------------------

private fullURIPath returns[String path]
{
    path = null;
    String item = null;
}
    : ( SLASH item=partialURIPath        {path = "/" + item;}
        | item=partialURIPath            {path = item;}
      )
      (ref:INNER_UNIT_REF                {path += ref.getText();}
      )?
    ;

private partialURIPath returns[String path]
{
    path = "";
    String item = null;
}
    : id:IDENTIFIER                       {path = path + id.getText();} 
      ( SLASH item=partialURIPath         {path = path + "/" + item;}
      |
      )
    ;

//------------------------------------------------------------------------------

private nameMap
    : LBRACE
      (nameMapItem
       ( COMMA nameMapItem)*
      )?
      RBRACE
    ;

private nameMapItem
    : sortNameMapItem
    | opNameMapItem
    ;

private sortNameMapItem
{
    String ignore = null;
}
    : ("sort"
      )?
      ignore=qualifiableSortNames
      nonWordSymbol["+->"]
      ignore=qualifiableSortNames
    ;

private opNameMapItem
    : ("op"
      )?
      annotableQualifiableName
      nonWordSymbol["+->"]
      annotableQualifiableName
    ;

private annotableQualifiableName
{
    String ignore = null;
}
    : ignore=qualifiableOpNames
      (nonWordSymbol[":"]
       ignore=sort
      )?
    ;

//------------------------------------------------------------------------------

private scDiagElem
    : scDiagNode
    | scDiagEdge
    ;

private scDiagNode
{
    String nodeName = null;
    ElementFactory.Item ignore = null;
}
    : nodeName=name
      nonWordSymbol["+->"]
      ignore=scTerm[null]
    ;

private scDiagEdge
{
    String name1 = null;
    String name2 = null;
    String name3 = null;
    ElementFactory.Item ignore = null;
}
    : name1=name
      nonWordSymbol[":"]
      name2=name
      nonWordSymbol["->"]
      name3=name
      nonWordSymbol["+->"]
      ignore=scTerm[null]
    ;

//------------------------------------------------------------------------------

private scSubstituteTermList
{
    ElementFactory.Item ignore = null;
}
    : LBRACKET
      ignore=scTerm[null]
      RBRACKET
      (scSubstituteTermList
      )*
    ;

//------------------------------------------------------------------------------

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
       | COMMA anAssertion=name
      )+
    ;

private proverOptions returns[ElementFactory.Item optionsItem]
{
    optionsItem = null;
    String anOption = null;
}
    : "options"
      (anOption=literal
      )+
    ;

//------------------------------------------------------------------------------

private qualifier returns[String qlf]
{
    qlf = null;
}
    : qlf=name
    ;

private name returns[String name]
{
    name = null;
}
    : star:STAR                     {name=star.getText();}
    | sym:NON_WORD_SYMBOL           {name=sym.getText();}
    | name=idName
    | translate:"translate"         {name="translate";}
    | colimit:"colimit"             {name="colimit";}
    | diagram:"diagram"             {name="diagram";}
    | print:"print"                 {name="print";}
    | snark:"Snark"                 {name="Snark";}
    ;

private nonKeywordName returns[String name]
{
    name = null;
}
    : name=idName
    ;

//------------------------------------------------------------------------------

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
    ElementFactory.Item term = null;
    //String strURI = null;
}
    : begin:"import"
      term=scTerm[null]     {if (term != null) {
                                importItem = builder.createImport(term.getClass().getName());
                                ParserUtil.setBounds(builder, importItem, begin, LT(0));
                             }
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
      (params=formalSortParameters (equals sortDef=sort)?
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
}   
    : unqualifiedSortName
    | qualifiedSortName
    ;

private unqualifiedSortName
    : nonKeywordName
    ;

private qualifiedSortName
    : qualifier DOT nonKeywordName
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

private opDeclaration returns[ElementFactory.Item op]
{
    op = null;
    String name = null;
    String sort = null;
}
    : begin:"op" 
      name=qualifiableOpNames
      (fixity
      )?
      COLON
      sort=sortScheme
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
    : opName=name
    ;

private fixity
    : ("infixl"
       | "infixr"
      )
      NAT_LITERAL
    ;

private sortScheme returns[String sortScheme]
{
    sortScheme = "";
}
    : (sortVariableBinder)? sort
    ;

private sortVariableBinder
    : "fa" localSortVariableList
    ;

private localSortVariableList
    : LPAREN localSortVariable (COMMA localSortVariable)* RPAREN
    ;

private localSortVariable
    : nonKeywordName
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

/* THIS SORT STUFF IS TOO AMBIGUOUS =(  Syntactic predicates are too costly for performance.

                    : sortSum
                   | (sortArrow) => sortArrow
                    | slackSort
                    ;

                private sortSum
                    : (VERTICALBAR name (slackSort)?
                      )+
                    ;

                private sortArrow
                    : arrowSource ARROW sort
                    ;

                private slackSort
                    : tightSort (STAR tightSort)*
                    ;

                private arrowSource
                    : sortSum
                    | slackSort
                    ;

                private tightSort
                    : sortInstantiation
                    | closedSort
                    ;

                private sortInstantiation
                    : qualifiableSortName actualSortParameters
                    ;

                private actualSortParameters
                    : closedSort
                    | properSortList
                    ;

                private closedSort
                    : basicClosedSort
                    | sortQuotient
                    ;

                private properSortList
                    : LPAREN sort
                      (COMMA sort
                      )+
                      RPAREN
                    ;

                private basicClosedSort
                    : sortRef
                    | parenthesizedSort
                    | sortRecord
                    | sortRestriction
                    | sortComprehension
                    ;

                private sortRef
                    : qualifiableSortName
                    ;

                private sortRecord
                    : unitProductSort
                    | LBRACE fieldSortList RBRACE
                    ;

                private unitProductSort
                    : LBRACE RBRACE
                    | LPAREN RPAREN
                    ;

                private fieldSortList
                    : fieldSort
                      (COMMA fieldSort
                      )*
                    ;

                private fieldSort
                    : name COLON sort
                    ;

                private sortRestriction
                    : LPAREN slackSort VERTICALBAR expression RPAREN
                    ;

                private sortComprehension
                    : LBRACE annotatedPattern VERTICALBAR expression RBRACE
                    ;

                private sortQuotient
                    : basicClosedSort (closedSort)* SLASH tightExpression
                    ;

                private parenthesizedSort
                    : LPAREN sort RPAREN
                    ;

END OF AMBIGUOUS SORT STUFF*/

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
      (equals
       | params=formalOpParameters equals) 
      expr=expression            {def = builder.createDef(name, params, expr);
                                  ParserUtil.setBounds(builder, def, begin, LT(0));
                                 }
    ;

private claimDefinition returns[ElementFactory.Item claimDef]
{
    claimDef = null;
    String name = null;
    String kind = null;
    Token begin = null;
    String expr = null;
}
    : kind=claimKind       {begin = LT(0);}
      name=idName
      equals
      (sortQuantification
      )?
      expr=expression
                           {claimDef = builder.createClaim(name, kind, expr);
                            ParserUtil.setBounds(builder, claimDef, begin, LT(0));
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

private sortQuantification
{
    String ignore = null;
}
    : "sort"
      "fa"
      LPAREN
      ignore=name
      (COMMA ignore=name
      )*
      RPAREN
    ;

private formalOpParameters returns[String[] params]
{
    params = null;
    List paramList = new LinkedList();
}
    : (closedPattern
      )*                    {params = (String[]) paramList.toArray(new String[]{});}
    ;

// patterns ---------------------------------------------------------------------------

private pattern
    : basicPattern
    | annotatedPattern
    ;

private annotatedPattern
    : basicPattern COLON sort
    ;

private basicPattern
    : tightPattern
    ;

private tightPattern
    : //for performance reasons, made this part of the closedPattern production... (embedPattern) => embedPattern
//this is the (COLONCOLON tightPattern)? part of the closedPattern production...   | consPattern
    | aliasedPattern
    | quotientPattern
//the rule for relaxPattern wasn't in the official grammar...    | relaxPattern
    | (name)? closedPattern (COLONCOLON tightPattern)?
    ;

private aliasedPattern
    : variablePattern "as" tightPattern
    ;

private embedPattern
    : name closedPattern
    ;

private variablePattern
{
    String ignore = null;
}
    : ignore=nonKeywordName
    ;

/* Made this part of tightPattern's closedPattern production
private consPattern
    : closedPattern COLONCOLON tightPattern
    ;*/

private closedPattern
    : parenthesizedPattern
    | variablePattern
    | literalPattern
    | listPattern
    | recordPattern
    | wildcardPattern
    ;

private wildcardPattern
    : UBAR
    ;

private literalPattern
{
    String ignore = null;
}
    : ignore=literal
    ;

private listPattern
    : LBRACKET
      (pattern
       (COMMA pattern
       )*
      )?
      RBRACKET
    ;

private parenthesizedPattern
    : LPAREN
      (pattern
       (COMMA pattern
       )*
      )?
      RPAREN
    ;

private recordPattern
    : LBRACE
      fieldPattern
      (COMMA fieldPattern
      )*
      RBRACE
    ;

private fieldPattern
    : name
      (EQUALS
       pattern
      )?
    ;

private quotientPattern
    : "quotient" expression tightPattern
    ;

// expressions ---------------------------------------------------------------------------
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

/* EXPRESSIONS ARE TOO AMBIGUOUS =(

                : lambdaForm
                    | caseExpression
                    | letExpression
                    | ifExpression
                    | quantification
                    | tightExpression
                    ;

                private lambdaForm
                    : "fn" match
                    ;

                private caseExpression
                    : "case" expression "of" match
                    ;

                private letExpression
                    : "let" reclessLetBinding "in" expression
                    | "let" recLetBindingSequence "in" expression
                    ;

                private ifExpression
                    : "if" expression "then" expression "else" expression
                    ;

                private quantification
                    : quantifier localVariableList expression
                    ;

                private tightExpression
                    : basicTightExpression
                    | annotatedExpression
                    ;

                private basicTightExpression
                    : application
                    | closedExpression
                    ;

                private match
                    : (VERTICALBAR)? auxMatch
                    ;

                private auxMatch
                    : (nonBranchBranch VERTICALBAR) => nonBranchBranch VERTICALBAR auxMatch
                    | branch
                    ;

                private nonBranchBranch
                    : pattern ARROW nonBranchExpression
                    ;

                private branch
                    : pattern ARROW expression
                    ;

                private nonBranchExpression
                    : tightExpression
                    ;

                private reclessLetBinding
                    : pattern EQUALS expression
                    ;

                private recLetBindingSequence
                    : (recLetBinding)*
                    ;

                private recLetBinding
                    : "def" name (formalParameterSequence)? (COLON sort)? EQUALS expression
                    ;

                private formalParameterSequence
                    : ((closedPattern)*)?
                    ;

                private quantifier
                    : "fa"
                    | "ex"
                    ;

                private localVariableList
                    : LPAREN
                      annotatedVariable
                      (COMMA annotatedVariable
                      )*
                      RPAREN
                    ;

                private annotatedVariable
                    : nonKeywordName
                      (COLON sort
                      )?
                    ;

                private closedExpression
                    : unqualifiedOpRef
                    | selectableExpression
                    ;

                private application
                    : closedExpression
                      (closedExpression  // syntactic predicate to take care of cases like "case l of Nil -> true | _ -> false"
                      )*
                    ;

                private annotatedExpression
                    : basicTightExpression (tightExpression)? COLON sort
                    ;

                private unqualifiedOpRef
                    : name
                    ;

                private selectableExpression
                    : basicSelectableExpression
                    | fieldSelection
                    ;

                // TODO: This could probably be optimized a lot by left-factoring
                private basicSelectableExpression
                    : twoNameExpression
                    | natFieldSelection
                    | literal
                    | (tupleDisplay) => tupleDisplay
                    | (sequentialExpression) => sequentialExpression
                    | parenthesizedExpression
                    | listDisplay
                    | structor
                    | recordDisplay
                    | monadExpression
                    ;

                private twoNameExpression
                    : name DOT name
                    ;

                private natFieldSelection
                    : unqualifiedOpRef DOT natSelector
                    ;

                private natSelector
                    : NAT_LITERAL
                    ;

                private fieldSelection
                    : basicSelectableExpression 
                      (selectableExpression
                      )*
                      DOT fieldSelector
                    ;

                private fieldSelector
                    : NAT_LITERAL
                    | name
                    ;

                private tupleDisplay
                    : LPAREN
                      (tupleDisplayBody
                      )?
                      RPAREN
                    ;

                private tupleDisplayBody
                    : expression COMMA expression
                      (COMMA
                       expression
                      )*
                    ;

                private recordDisplay
                    : LBRACE
                      (recordDisplayBody
                      )?
                      RBRACE
                    ;

                private recordDisplayBody
                    : fieldFiller
                      (COMMA
                       fieldFiller
                      )*
                    ;

                private fieldFiller
                    : name EQUALS expression
                    ;

                private sequentialExpression
                    : LPAREN
                      openSequentialExpression
                      RPAREN
                    ;

                private openSequentialExpression
                    : expression (SEMICOLON expression)+
                    ;

                private voidExpression
                    : expression
                    ;
                
                private listDisplay
                    : LBRACKET
                      (listDisplayBody
                      )?
                      RBRACKET
                    ;

                private listDisplayBody
                    : (expression
                       (COMMA expression
                       )*
                      )?
                    ;

                private structor
                    : projector
                    | relaxator
                    | restrictor
                    | quotienter
                    | chooser
                    | embedder
                    | embeddingTest
                    ;

                private projector
                    : "project" fieldSelector
                    ;

                private relaxator
                    : "relax" closedExpression
                    ;

                private restrictor
                    : "restrict" closedExpression
                    ;

                private quotienter
                    : "quotient" closedExpression
                    ;

                private chooser
                    : "choose" closedExpression
                    ;

                private embedder
                    : "embed" name
                    ;

                private embeddingTest
                    : "embed?" name
                    ;

                private parenthesizedExpression
                    : LPAREN
                      expression
                      RPAREN
                    ;

                private monadExpression
                    : monadTermExpression
                    | monadBindingExpression
                    ;

                private monadTermExpression
                    : LBRACE
                      expression SEMICOLON monadStmtList
                      RBRACE
                    ;

                private monadStmtList
                    : expression
                    | expression SEMICOLON monadStmtList
                    | pattern BACKWARDSARROW expression SEMICOLON monadStmtList
                    ;

                private monadBindingExpression
                    : LBRACE
                      pattern BACKWARDSARROW expression SEMICOLON monadStmtList
                      RBRACE
                    ;

                private relaxPattern
                    : "relax" closedExpression tightPattern
                    ;

END OF EXPRESSION STUFF*/

//---------------------------------------------------------------------------
private specialSymbol returns[String text]
{
    text = null;
}
    : UBAR                  {text = "_";}
    | LPAREN                {text = "(";}
    | RPAREN                {text = ")";}
    | LBRACKET              {text = "[";}
    | RBRACKET              {text = "]";}
    | LBRACE                {text = "{";}
    | RBRACE                {text = "}";}
    | COMMA                 {text = ", ";}

    | STAR                  {text = "*";}
    | ARROW                 {text = "->";}
    | COLON                 {text = ":";}
    | VERTICALBAR           {text = "|";}
    | COLONCOLON            {text = "::";}
    | SEMICOLON             {text = ";";}
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
      "*)"                      {_ttype = Token.SKIP;}
    ;

// Latex comments -- ignored
LATEX_COMMENT
    : ( "\\end{spec}"
      | "\\section{"
      | "\\subsection{"
      | "\\document{"
      )
      (// '\r' '\n' can be matched in one alternative or by matching
       // '\r' in one iteration and '\n' in another.  The language
       // that allows both "\r\n" and "\r" and "\n" to be valid
       // newlines is ambiguous.  Consequently, the resulting grammar
       // must be ambiguous.  This warning is shut off.
       options {generateAmbigWarnings=false;}
       : { LA(2)!='b' || LA(3)!='e' || LA(4) !='g' || LA(5) !='i' || LA(6) !='n' || LA(7) != '{' || LA(8) != 's' || LA(9) != 'p' || LA(10) != 'e' || LA(11) != 'c' || LA(12) != '}'}? '\\'
	 | '\r' '\n'		{newline();}
	 | '\r'			{newline();}
	 | '\n'			{newline();}
	 | ~('\\'|'\n'|'\r')    
         )*
       (("\\begin{spec}") => "\\begin{spec}"
       |)                       {_ttype = Token.SKIP;}
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
COLON
options {
  paraphrase = "':'";
}
    :  ":"
    ;
COLONCOLON
options {
  paraphrase = "'::'";
}
    :  "::"
    ;
VERTICALBAR
options {
  paraphrase = "'|'";
}
    :  "|"
    ;
STAR
options {
  paraphrase = "'*'";
}
    :  "*"
    ;
ARROW
options {
  paraphrase = "'->'";
}
    :  "->"
    ;
BACKWARDSARROW
options {
  paraphrase = "'<-'";
}
    :  "<-"
    ;
SLASH
options {
  paraphrase = "'/'";
}
    :  "/"
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
