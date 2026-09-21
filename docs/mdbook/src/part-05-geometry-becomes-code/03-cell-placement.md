# Cell Placement


A mesh gives MatterScript a representation of physical space.

Cell placement gives that space **computational meaning**.

A spatial domain can be divided into discrete locations, and each location can become a computational cell. The behavior of the entire system is then determined by local relationships between neighboring cells.

This is the point where MatterScript connects directly to one of the most important ideas in *A New Kind of Science*:

> **Complex global behavior can arise from simple local rules.**

The programmer does not necessarily need to describe the behavior of the entire system.

Instead, the programmer describes:

1. the space in which computation occurs,
2. the state of each cell,
3. the neighborhood visible to a cell,
4. and the rule that determines its next state.

The system then evolves.

```text
SPACE
  │
  ▼
CELLS
  │
  ▼
LOCAL NEIGHBORHOODS
  │
  ▼
LOCAL RULE
  │
  ▼
GLOBAL BEHAVIOR
```

This is the fundamental connection between MatterScript and the computational universe explored by Stephen Wolfram's *A New Kind of Science*.

---

## 1. From Geometry to Computation

The previous chapters constructed geometry:

```text
Point
  ↓
Edge
  ↓
Loop
  ↓
Face
  ↓
Mesh
```

Cell placement adds another dimension:

```text
Mesh
  ↓
Cells
  ↓
State
  ↓
Evolution
```

The distinction is important.

A mesh tells us **where things are**.

A cell tells us **where computation happens**.

For example:

```text
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
```

Each square can become a computational location.

The geometry establishes the spatial relationships.

The cell model establishes the computational relationships.

MatterScript therefore allows the same underlying idea of locality to be expressed spatially and computationally.

---

## 2. A Cellular Space

MatterScript can declare a spatial cellular domain:

```matterscript
@domain(spatial2d, size: [300, 500])
```

The `size` establishes the extent of the cellular space.

Conceptually:

```text
          500
    ┌───────────────┐
    │               │
    │               │
300 │   CELLULAR    │
    │     SPACE     │
    │               │
    │               │
    └───────────────┘
```

The important abstraction is not the rectangle itself.

It is the fact that the domain contains a collection of discrete computational locations.

```text
domain
   │
   ├── cell
   ├── cell
   ├── cell
   ├── cell
   └── ...
```

Each cell occupies a particular location within the domain.

That location gives the cell a neighborhood.

The neighborhood gives the cell access to local information.

And the local information determines its evolution.

---

## 3. The Cell Is a Local Computational Entity

Consider a one-dimensional neighborhood:

```text
[ Left ][ Center ][ Right ]
```

A cell observes its local neighborhood:

```text
      neighborhood
   ┌─────┬─────┬─────┐
   │  L  │  C  │  R  │
   └─────┴─────┴─────┘
```

The next state of the center cell is determined by those states.

Conceptually:

```text
       L   C   R
       │   │   │
       └───┼───┘
           ▼
       local rule
           │
           ▼
       new C state
```

This is a cellular automaton.

The important property is **locality**.

The cell does not need to know the state of the entire universe.

It needs only the portion of the universe included in its neighborhood.

---

## 4. The Generate Directive

MatterScript expresses this local evolution rule with the `@generate` directive.

A simple example is:

```matterscript
ca100[()()

@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State

  [*, 1, 5]: 4

  [3, 2, 4]: 6

  // Unmentioned permutations retain their center state.
}
  :
]
```

The structure is deliberately compact.

```text
@generate
    │
    ▼
neighborhood
    │
    ▼
next state
```

The rule:

```text
[3, 2, 4]: 6
```

means:

```text
left   = 3
center = 2
right  = 4

        ↓

new center = 6
```

The rule describes the transformation of one local configuration.

It does not describe the entire grid.

---

## 5. Wildcards

The generate language also permits wildcard matching.

For example:

```matterscript
[*, 1, 5]: 4
```

means that the left-hand state can be any value.

Conceptually:

```text
[0, 1, 5] → 4
[1, 1, 5] → 4
[2, 1, 5] → 4
[3, 1, 5] → 4
...
```

The center and right states remain constrained:

```text
Center = 1
Right  = 5
```

while:

```text
Left = anything
```

This provides a compact way to express families of local transitions without enumerating every permutation individually.

---

## 6. The Default Rule

Not every possible neighborhood needs to be explicitly written.

For example:

```matterscript
[3, 2, 4]: 6
```

does not say what should happen for:

```text
[0,0,0]
```

or:

```text
[1,4,2]
```

or any other unmentioned configuration.

The generate semantics provide a default:

> **Unmentioned permutations retain their center state.**

Thus:

```text
[0, 0, 0] → 0
```

and:

```text
[1, 4, 2] → 4
```

unless an explicit or wildcard rule matches those neighborhoods.

This makes the rule specification sparse.

The programmer specifies **what changes** rather than being forced to enumerate everything that remains unchanged.

---

## 7. Local Rules, Global Systems

The remarkable property of a cellular automaton is that a tiny rule can govern an enormous number of cells.

Suppose the domain contains thousands of cells.

The programmer still defines the rule once:

```text
[Left, Center, Right] → New Center
```

The rule is then applied throughout the cellular space.

Conceptually:

```text
        local rule
             │
      ┌──────┼──────┐
      ▼      ▼      ▼
    cell    cell   cell
      │      │      │
      ▼      ▼      ▼
    state   state  state
```

The same rule is reused at every applicable location.

This is one of the most important differences between describing a system globally and describing it locally.

Instead of:

> Here is the complete behavior of the 300 × 500 system.

we say:

> Here is what any cell does when it encounters this neighborhood.

The global behavior emerges from repeated local application.

---

# 8. The NKS Connection

This is where MatterScript enters the conceptual territory of *A New Kind of Science*.

NKS treats cellular automata as a particularly important class of computational systems because extremely simple rules can produce unexpectedly rich behavior.

The essential structure is:

```text
simple rule
     +
simple initial condition
     +
repeated local evolution
     ↓
complex global behavior
```

MatterScript provides a language-level mechanism for expressing exactly this relationship.

The programmer describes the local rule.

The cellular domain provides the space.

Repeated application provides the evolution.

The resulting behavior is discovered by running the system.

---

## 9. From Programming Behavior to Discovering Behavior

Traditional programming generally begins with a desired global behavior.

For example:

```text
"Sort these values."

"Render this image."

"Calculate this result."
```

The programmer decomposes the desired behavior into instructions.

Cellular computation allows a different approach.

We can specify:

```text
"What happens locally?"
```

and then observe:

```text
"What happens globally?"
```

The difference is profound.

```text
TRADITIONAL

desired behavior
       ↓
algorithm
       ↓
execution


CELLULAR

local rule
       ↓
repeated evolution
       ↓
emergent behavior
```

The second approach is much closer to the experimental methodology of NKS.

Instead of always designing the final behavior first, we can explore what simple computational rules produce.

---

## 10. Rule Space Becomes a Programming Space

Once the system is described by a local rule, the rule itself becomes an object of exploration.

Imagine varying:

```text
[*, 1, 5]: 4
```

into another rule:

```text
[*, 1, 5]: 3
```

or adding another transition:

```text
[2, 3, *]: 7
```

Each change creates a different dynamical system.

We can therefore think of the space of possible programs as:

```text
             RULE SPACE

       ┌──────┬──────┬──────┐
       │ R001 │ R002 │ R003 │
       ├──────┼──────┼──────┤
       │ R004 │ R005 │ R006 │
       ├──────┼──────┼──────┤
       │  ... │  ... │  ... │
       └──────┴──────┴──────┘
```

MatterScript does not have to prescribe which rule is interesting.

It provides a mechanism for generating and running the rules.

This turns the language into an experimental environment for exploring computational behavior.

---

## 11. Emergence

The central phenomenon is emergence.

A single cell follows a simple rule.

A large collection of cells can exhibit behavior that is not obvious from inspecting any individual transition.

```text
LOCAL

[1, 2, 1] → 3


GLOBAL

many cells
    ↓
repeated application
    ↓
patterns
    ↓
structures
    ↓
behavior
```

The global pattern is not necessarily written anywhere in the source.

It emerges from the repeated interaction of local computations.

This is one reason cellular automata are so important to MatterScript.

They provide a concrete computational model in which:

> **structure can emerge from locality.**

---

## 12. Space Is Part of the Program

This changes the meaning of a program.

In conventional code, the location of an instruction is usually an implementation detail.

In a cellular system, location is part of the computation.

Consider:

```text
cell A
cell B
cell C
```

The relationship:

```text
A is next to B
```

can determine whether information flows between them.

The program therefore contains not only a rule:

```text
if neighborhood = X
then state = Y
```

but also a spatial structure:

```text
this cell
is adjacent to
those cells
```

MatterScript can represent both.

That is the deeper connection between the geometry system and cellular computation.

---

## 13. Geometry Provides Locality

The geometry chapters established:

```text
points
edges
loops
faces
meshes
```

These structures establish spatial relationships.

Cell placement uses those relationships to define computational neighborhoods.

The conceptual transition is:

```text
GEOMETRY

where are things?

        ↓

TOPOLOGY

what is connected to what?

        ↓

CELLULAR COMPUTATION

what information can each location see?

        ↓

EVOLUTION

how does the system change?
```

This is why Cell Placement belongs immediately after Meshes.

It is the first chapter where the geometry becomes an active computational substrate.

---

## 14. Locality Is a Computational Primitive

In ordinary programming, locality is often treated as a property of implementation.

In MatterScript, locality can become part of the program itself.

A cell's neighborhood defines the information available to it.

For the rule:

```text
[Left, Center, Right] → New Center
```

the computational boundary is explicit:

```text
        visible
   ┌─────┬─────┬─────┐
   │  L  │  C  │  R  │
   └─────┴─────┴─────┘
```

The cell cannot arbitrarily inspect every other cell.

Its computation is constrained by locality.

That constraint is not merely an optimization.

It is part of the computational model.

---

## 15. The Universe as a Cellular System

NKS encourages a much larger question:

> Could simple local computational rules be sufficient to generate the behavior we observe in nature?

MatterScript does not need to answer that question in advance.

Instead, it provides a language in which such questions can become executable experiments.

A cellular model can represent:

```text
local state
     ↓
local interaction
     ↓
local evolution
     ↓
global pattern
```

This makes cellular automata a bridge between programming and modeling.

The programmer can construct a small local rule and then investigate what kind of world it produces.

---

## 16. Theory-Free Exploration

This also connects directly to model-free inference.

Instead of beginning with a predefined equation describing a phenomenon, we can observe transitions:

```text
before                  after

A B C                    A D C
B C A       ─────→       B B A
C A B                    E A B
```

and ask:

> What local rule could have generated this transition?

The inference problem becomes:

```text
observations
     ↓
local transitions
     ↓
candidate rules
     ↓
generated evolution
     ↓
comparison
```

MatterScript can then become both:

```text
a language for specifying rules
```

and:

```text
a substrate for testing inferred rules.
```

This opens a path toward systems that discover local computational laws from observed spatial behavior.

---

## 17. Rule Generation and Rule Discovery

The `@generate` directive is therefore more significant than a convenient cellular-automata syntax.

It defines a boundary between:

```text
RULE SPECIFICATION
```

and:

```text
RULE EXECUTION
```

The programmer can explicitly provide:

```matterscript
@generate {
  [*, 1, 5]: 4
  [3, 2, 4]: 6
}
```

But a future system could potentially produce the same structure from:

```text
observed transitions
```

The architecture becomes:

```text
                   ┌──────────────┐
                   │ Human author │
                   └──────┬───────┘
                          │
                          ▼
                     @generate
                          │
                          ▼
                   local rule
                          │
                          ▼
                  cellular system
                          ▲
                          │
                   inferred rule
                          │
                   ┌──────┴───────┐
                   │ observations │
                   └──────────────┘
```

The language can therefore support both **programmed computation** and eventually **discovered computation**.

---

## 18. Computational Irreducibility

Cellular systems also provide a concrete setting for another important NKS concept: computational irreducibility.

A system may have a very short description:

```text
one simple local rule
```

while the behavior generated after many iterations may not have an equally simple shortcut.

The only practical way to know what happens may be to let the system evolve.

Conceptually:

```text
small rule
    │
    ▼
iteration 1
    │
    ▼
iteration 2
    │
    ▼
iteration 3
    │
    ▼
...
    │
    ▼
complex state
```

This changes the role of the programmer.

The programmer is not always deriving the answer analytically.

Sometimes the programmer constructs the computational universe and **runs it to find out what happens**.

That is a very different programming paradigm.

---

## 19. Simple Rules, Large Spaces

The example domain:

```matterscript
@domain(spatial2d, size: [300, 500])
```

contains a large number of locations while the rule itself remains tiny.

This gives us a useful ratio:

```text
large computational space
          +
small rule description
          ↓
large computational behavior
```

The source code does not need to scale linearly with the number of cells.

One local rule can govern an entire population.

This is precisely what makes cellular computation attractive as a model of distributed physical systems.

---

## 20. Cell Placement as Physical Placement

There is another important interpretation.

A cell is not merely an abstract array element.

It occupies a location.

That means the same conceptual cell can eventually be mapped onto:

```text
software memory
FPGA logic
hardware cells
sensor locations
fabricated structures
physical regions
```

The abstraction is:

```text
CELL
 │
 ├── state
 ├── neighborhood
 ├── rule
 └── physical location
```

This is where MatterScript begins to bridge cellular computation and physical computing.

The question becomes not merely:

> What does this cell calculate?

but:

> **Where does this computation physically exist?**

---

## 21. Cell Placement and Hardware

Suppose a cellular rule is eventually lowered onto physical hardware.

The abstract model might be:

```text
Cell
 │
 ├── input from left
 ├── local state
 ├── input from right
 └── output
```

A physical implementation could become:

```text
┌───────┐    ┌───────┐    ┌───────┐
│ Cell  │───▶│ Cell  │───▶│ Cell  │
│   A   │    │   B   │    │   C   │
└───────┘    └───────┘    └───────┘
```

The spatial relationship becomes an actual interconnection.

This is exactly where the distinction between conventional software and MatterScript begins to disappear.

The program's topology can become the hardware's topology.

---

## 22. A Cellular Automaton Is a Distributed Program

A useful way to think about the `@generate` directive is:

> It defines a program that is replicated across space.

Instead of:

```text
one program
    ↓
one execution
```

we have:

```text
one local program
    ↓
many spatial instances
    ↓
distributed evolution
```

Each cell executes the same local relationship.

The global system is the composition of those local processes.

This makes cellular automata a natural intermediate model between software and physical systems.

---

## 23. From Cellular Automata to NKS

The NKS connection can now be stated directly.

MatterScript provides the machinery to explore several ideas central to computational experiments with cellular systems:

```text
local rules
    ↓
simple programs
    ↓
large state spaces
    ↓
repeated evolution
    ↓
emergence
    ↓
complexity
    ↓
computation
```

The important methodological shift is:

> **Do not always begin by asking how to program the desired answer. Begin by asking what behavior a simple rule generates.**

This turns programming into experimentation.

The programmer becomes, in part:

```text
designer
   +
observer
   +
experimentalist
```

---

## 24. A MatterScript Cellular Experiment

The complete example is deliberately small:

```matterscript
ca100[()()

@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State

  // Wildcard rule
  [*, 1, 5]: 4

  // Explicit rule
  [3, 2, 4]: 6

  // Unmentioned permutations retain their center state.
}
  :
]
```

Yet this tiny definition establishes an entire computational universe:

```text
300 × 500 spatial domain
        │
        ▼
discrete cells
        │
        ▼
local neighborhoods
        │
        ▼
local transition rules
        │
        ▼
repeated evolution
        │
        ▼
emergent global behavior
```

The source code describes the rule.

The system discovers the behavior.

---

## 25. From Cell Placement to Space-Time

Cell placement introduces a second dimension to the meaning of a program.

We now have:

```text
SPACE
  │
  ▼
cell location
```

and:

```text
TIME
  │
  ▼
cell evolution
```

Together:

```text
              TIME
                │
                ▼
        ┌───────────────┐
        │       •       │
        │     • • •     │
        │   • • • • •   │
        │ • • • • • • • │
        └───────────────┘
                ▲
                │
              SPACE
```

A cellular automaton is therefore naturally a **space-time computation**.

Each iteration creates another state of the spatial system.

The complete computation is the history of those states.

---

## 26. The Geometry-to-NKS Bridge

The Part V trajectory can now be seen as one continuous construction:

```text
Spatial Domain
      │
      ▼
   Vertices
      │
      ▼
    Edges
      │
      ▼
    Loops
      │
      ▼
    Faces
      │
      ▼
    Meshes
      │
      ▼
Cell Placement
      │
      ▼
 Local Rules
      │
      ▼
Cellular Evolution
      │
      ▼
Emergent Behavior
```

The first half establishes **where**.

The second half establishes **what happens there**.

That is the fundamental bridge between geometry and computation.

---

## 27. Why Cell Placement Matters to MatterScript

Cell placement is not simply another feature added to the language.

It establishes a computational model in which:

- space is explicit,
- locality is explicit,
- state is distributed,
- rules are local,
- evolution is repeated,
- and global behavior can emerge.

This provides MatterScript with a direct path into the enormous design space of cellular automata and the broader computational perspective of NKS.

The programmer can begin with something as small as:

```text
[Left, Center, Right] → New Center
```

and end with a system containing hundreds of thousands of interacting computational locations.

That is an extraordinary amount of behavior generated from an extraordinarily small description.

---

## 28. Looking Ahead: Computation Becomes Physical

Cell placement gives us a computational substrate.

The next question is:

> What happens when the abstract cellular space must conform to an actual physical structure?

That leads naturally to **Conformal Projection**.

The trajectory becomes:

```text
CELLULAR SPACE
      │
      ▼
PHYSICAL GEOMETRY
      │
      ▼
CONFORMAL PROJECTION
      │
      ▼
CELLS ON A SURFACE
      │
      ▼
PHYSICAL COMPUTATION
```

At that point, the NKS cellular universe is no longer confined to an abstract grid.

Its cells can become associated with actual geometry.

The program begins with a local rule.

The geometry determines where the rule lives.

Time determines how it evolves.

And the resulting structure can ultimately become physical machinery.

That is the deeper promise of MatterScript:

> **A program can describe not only what computation does, but where computation exists, how it evolves through time, and how its local interactions become a physical system.**

*Drafting in progress...*
