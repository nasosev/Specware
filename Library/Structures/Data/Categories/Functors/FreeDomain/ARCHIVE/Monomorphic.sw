\section{Functors with free domain and fixed (monomorphic) target category}

This file to be deprecated in favour of ../FreeDomain.sw

This is a spec for mono functors where the domain is the free
category generated from a category presentation (ie sketch). This spec is
meant mainly defining systems. A key distinction between
this spec and the more general polymorphic functor spec is that the effect
of the functor is determined by what the maps do on the vertices
and edges of the graph underlying the sketch.

Note the following. In
\specref{Library/Structures/Data/Categories/Functors/Polymorphic},
the type Functor is defined over 4 type variables. The first two are
the types of the objects and arrows in the domain category. The other
two for the codomain category. In contrast, here there are only type
variables characterizing the objects and arrows in the codomain.

An alternative to including the generator is simply to define the
functor from the free category. The problem is that by doing so, we
lose the ability to enumerate (fold) over the vertices and edges
in the generating graph, since as a rule, whereas the number of edges
in the generating graph may be finite, there may not be a finite number
of paths in the free category.

Note that import Maps are qualified with "PolyMap". This is to distinguish
it from the monomorphic maps used elsewhere. See the file NameSpaces
for more on this.

The names of some of these operators clash with Cats and Graphs.

We use polymorphic maps but probably should import two copies
of monomorphic maps.

\begin{spec}
spec {
  import Sketch qualifying /Library/Structures/Data/Categories/Sketches/Monomorphic
  import Cat qualifying /Library/Structures/Math/Cat
  import PolyMap qualifying /Library/Structures/Data/Maps/Polymorphic 

  type Functor

  op dom : Functor -> Sketch
  op vertexMap : Functor -> PolyMap.Map (Vertex.Elem,Object)
  op edgeMap : Functor -> PolyMap.Map (Edge.Elem,Arrow)

  op emptyFunctor : Functor
  op makeFunctor :
            Sketch
         -> PolyMap.Map (Vertex.Elem,Object)
         -> PolyMap.Map (Edge.Elem,Arrow)
         -> Functor
\end{spec}

When pretty printing a functor, we don't print the domain or codomain. 
Printing the domain (generator) is not unreasonable.

\begin{spec}
  op ppFunctor : Functor -> Pretty
  def ppFunctor functor = 
    ppConcat [
      ppString "Vertex Map =",
      ppNewline,
      ppString "  ",
      ppIndent (PolyMap.ppMap Vertex.ppElem ppObject (vertexMap functor)),
      ppNewline,
      ppString "Edge Map =",
      ppNewline,
      ppString "  ",
      ppIndent (PolyMap.ppMap Edge.ppElem ppArrow (edgeMap functor))
   ]
}
\end{spec}

Perhaps we should define the free category construction. Can we also
describe what happens on graph homomorphisms? Ie can we define a functor?
Perhaps not since this requires the category of categories. Needs thought.