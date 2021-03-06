S = spec

  type Predicate a = a -> Bool

  op uniquelySatisfies? : [a] a * Predicate a -> Bool
  axiom uniquelySatisfies?_def is [a] fa(x,p)
    uniquelySatisfies?(x,p) =
    (p x && (fa (y:a) p y => y = x))

  op uniquelySatisfied? : [a] Predicate a -> Bool
  axiom uniquelySatisfied?_def is [a] fa(p)
    uniquelySatisfied? p =
    (ex (x:a) uniquelySatisfies?(x,p))

  type UniquelySatisfiedPredicate a = (Predicate a | uniquelySatisfied?)

  op The : [a] UniquelySatisfiedPredicate a -> a
  axiom The_def is [a]
    fa (p:UniquelySatisfiedPredicate a)
       uniquelySatisfies? (The p, p)

  type FSet a

  op in? infixl 20 : [a] a * FSet a -> Bool

  op empty : [a] FSet a

  op with infixl 30 : [a] FSet a * a -> FSet a

  op wout infixl 30 : [a] FSet a * a -> FSet a

  op foldable? : [a,b] FSet a * b * (b * a -> b) -> Bool
  def [a,b] foldable?(s,c,f) =
    (fa (x:a, y:a, z:b) x in? s && y in? s => f(f(z,x),y) = f(f(z,y),x))

  op fold : [a,b] ((FSet a * b * (b * a -> b)) | foldable?) -> b
  def [a,b] fold =
    The (fn (fold : ((FSet a * b * (b * a -> b)) | foldable?) -> b) ->
      (fa(c,f) fold (empty, c, f) = c) &&
      (fa(s,x,c,f) foldable? (s with x, c, f) =>
                   fold (s with x, c, f) = f (fold (s wout x, c, f), x)))

endspec

O = obligations S
