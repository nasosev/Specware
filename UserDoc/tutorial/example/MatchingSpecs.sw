Symbols = spec
  sort Symbol
endspec


Words = spec
  import Symbols
  sort Word = List Symbol
endspec


Messages = spec
  import Symbols
  sort Message = List (Option Symbol)
endspec


SymbolMatching = spec
  import Symbols

  op symb_matches? : Symbol * Option Symbol -> Boolean
  def symb_matches?(s,os) = case os of Some s1 -> s = s1
                                     | None    -> true
endspec


WordMatching = spec

  import Words
  import Messages
  import SymbolMatching

  op word_matches_at? : Word * Message * Nat -> Boolean
  axiom word_matching is
        fa(wrd,msg,pos)
          word_matches_at?(wrd,msg,pos) <=>
          pos + length wrd <= length msg &
          (fa(i:Nat) i < length wrd =>
                 symb_matches?(nth(wrd, i),
                               nth(msg, pos + i)))

endspec


Matches = spec
  import Words
  sort Match = {word : Word, position : Nat}
endspec


FindMatches = spec

  import WordMatching
  import Matches

  op find_matches : Message * List Word -> List Match
  axiom match_finding is
        fa(msg,wrds,mtch)
          member(mtch,find_matches(msg,wrds)) <=>
          member(mtch.word,wrds) &
          word_matches_at?(mtch.word,msg,mtch.position) &
          (fa(pos) word_matches_at?(mtch.word,msg,pos) =>
                   pos >= mtch.position)

endspec
