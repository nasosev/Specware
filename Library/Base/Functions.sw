Functions qualifying spec

  op id : [a] a -> a
  def id x = x

  op o infixl 24 : [a,b,c] (b -> c) * (a -> b) -> (a -> c)
  def o (f,g) x = f (g x)

  op injective?  : [a,b] (a -> b) -> Boolean
  def injective?  f = (fa(x1,x2) f x1 = f x2 => x1 = x2)

  op surjective? : [a,b] (a -> b) -> Boolean
  def surjective? f = (fa(y) (ex(x) f x = y))

  op bijective?  : [a,b] (a -> b) -> Boolean
  def bijective?  f = injective? f && surjective? f

  type Injection (a,b) = ((a -> b) | injective?)

  type Surjection(a,b) = ((a -> b) | surjective?)

  type Bijection (a,b) = ((a -> b) | bijective?)

  op inverse : [a,b] Bijection(a,b) -> Bijection(b,a)
  axiom inverse_def is [a,b]
    fa (f:Bijection(a,b))  (inverse f) o f = id  &&  f o (inverse f) = id

endspec
