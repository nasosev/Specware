(* Copyright 2015 Kestrel Institute. See file LICENSE for license details *)

\section{Monomorphic Sketches}

A sketch is a finitary presentation of a category. Put another way,
a sketch generates a category. A common ingredient in a sketch is
a graph. On top of that there are many varieties of sketches. An
``elementary sketch'' is a graph together with a collection of equations
on paths in the graph. This generates a free category modulo the
congruence closure of those equations.

There are also limit and colimit sketches. These are graphs together with
a collection of cones or cocones. These give rise to limits and colimits
in the generated category.

Thus, there will need to be a family of specs for sketches, each being
a refinement of graphs.

For now, we omit the equations, cones and cocones and allow only
graphs as sketches.

\begin{spec}
spec
  import translate ../Graphs/Finite by {Graph +-> Sketch} 
\end{spec}

We define a type for paths though they aren't used yet.

\begin{spec}
  type Path = {
    first : Vertex,
    path : List Edge,
    last : Vertex
  } 
endspec
\end{spec}
