# Neighborhood Rules

Earlier in the book we introduced **Transform Rules** as one of the fundamental building blocks of MatterScript. A Transform Rule describes how one arrangement of tokens transforms into another. Small examples, such as Boolean logic gates, can be written by hand.

```matterscript
0,0[0]
0,1[1]
1,0[1]
1,1[1]
```

For simple definitions, this is entirely practical.

Real systems, however, rarely consist of four rules.

A cellular simulation containing millions of cells—or a three-dimensional material spanning billions of interacting regions—would require an enormous number of nearly identical transformation rules. Writing those rules by hand would be impossible.

MatterScript therefore provides the `@generate` directive, allowing large collections of neighborhood rules to be created automatically during compilation.

---

## Programs That Generate Behavior

The `@generate` directive allows the programmer to describe an entire family of transformation rules using a compact specification.

```matterscript
@generate {
    ...
}
```

Rather than writing thousands or millions of individual rules by hand, the programmer describes the pattern from which those rules are constructed. During compilation, the generator expands into a complete transformation table before the association graph is built.

This idea is similar in spirit to the `generate` construct in VHDL, where a small fragment of source expands into large amounts of hardware. The difference is that MatterScript is not merely replicating circuitry—it is generating **local computational behavior**.

---

## Neighborhood Rules

A Neighborhood Rule describes how a local region of a computational fabric evolves.
For example, let's define three rules:

```matterscript
// Bind to a 2D spatial domain with bounds
@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State
  [2, 1, 5]:4
  [3, 2, 4]:6
  [4, 4, 6]:4
}
```

The first rule ```[2, 1, 5]:4``` can be interpreted as:

The cell under evaluation is currently in state `1`.

Its local neighborhood matches the pattern ```[2, 1, 5]``` (left neighbor is `2`, right neighbor is `5`).

The rule transforms the center cell into state `4`, leaving the local neighborhood in state ```[2, 4, 5]```.

Similarly, for the second rule ```[3, 2, 4]:6```, if the cell under evaluation is in state `2`, its left neighbor is in state `3`, and its right neighbor is in state `4`, the rule triggers and updates the center cell to state `6` (resulting in neighborhood state ```[3, 6, 4]```).

The third rule ```[4, 4, 6]:4``` introduces a pattern for state `4`: if the center cell is `4`, its left neighbor is `4`, and its right neighbor is `6`, the cell remains in state `4`,resulting in neighborhood state ```[4, 4, 6]```.

With explicit domain declarations like `@domain(spatial2d,  size: [300, 500])`, you decouple topology from extents. This allows the same neighborhood rules to compile across different grid sizes or dimensions without modifying the rule block syntax.

Any number of transformations can be defined, and they are not restricted to numeric states. Numbers hold no arithmetic meaning in MatterScript; here is an example defining transformations using domain-specific tokens:

```matterscript
@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State
  [DE, AK, JD]:JC
}
```

In MatterScript, Neighborhood Rules use **sparse notation**: you only declare explicit state transitions, and any unlisted neighborhood pattern automatically defaults to **Identity** (the center cell keeps its current state). You can also use the wildcard `*` to match any token or state in a given position.

```matterscript
@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State
  
  // Wildcard: Any left state, center state 1, right state 5 -> transition to 4
  [*, 1, 5]: 4
  
  // Explicit rule
  [3, 2, 4]: 6
  
  // Unmentioned permutations (e.g., [0, 0, 0]) automatically retain their center state.
}

```

Nothing in this description refers to equations, variables, or arithmetic.

Instead, the rule simply asks:

> **Does this neighborhood exist?**

If the answer is yes, the transformation occurs.

Each rule is therefore nothing more than a description of one possible local interaction. Collectively, the rules define how an entire computational fabric evolves over time.

All of the rules are then composed into a digital circuit that embodies all those transformations, in such a way that every cell in the generated field will exhibit identical behavior in accordance with that rule set. The field is now ready for state to start flowing into it, and all the cells, being independent digital circuits, react as soon as they receive their state and their neighbors are presenting their own state. The wiring between the cells extends as far as neccesary to allow a cell to read the state of all its neighbors, in this case the cell to the left and the cell to the right, in a 2D cellular automaton.

---

## Computation as Local Transformation

Readers familiar with *A New Kind of Science* will recognize this immediately.

Instead of modeling reality by solving increasingly complex mathematical equations, we describe reality through collections of local transformation rules. Every cell interacts only with its immediate neighborhood, and the repeated application of these simple rules gives rise to remarkably rich global behavior.

MatterScript adopts this philosophy directly.

Neighborhood Rules are not lookup tables in the traditional programming sense. They are **behavioral descriptions**. Each entry specifies one possible local interaction, and together they describe the evolution of an entire computational system.

The compiler does not interpret these rules mathematically.

It compiles them into the association graph that realizes the specified behavior.

---

## From One Rule to Billions

The real power of `@generate` becomes apparent when these local rules are replicated across space.

A two-dimensional cellular automaton containing one hundred million cells does not require one hundred million hand-written definitions.

The programmer defines a single local neighborhood and specifies how that neighborhood should be replicated.

The compiler manufactures the remaining computational fabric automatically.

Each generated cell possesses the same local behavior while remaining connected to its own unique neighbors.

The same principle naturally extends into three dimensions. Voxel simulations, reaction-diffusion systems, biological tissues, crystal growth, fluid dynamics, and many other spatial systems can all be expressed as collections of Neighborhood Rules distributed throughout a geometric structure.

The programmer describes the **behavior**.

The compiler constructs the **fabric**.

---

## Scaling Without Complexity

One of the central ideas of MatterScript is that source code should describe *patterns*, not instances.

The amount of source code should not grow simply because the problem becomes larger.

Instead, the programmer captures the behavior once, and the compiler expands that behavior into whatever scale is required.

```text
Neighborhood Rule
        │
        ▼
@generate
        │
        ▼
Millions or Billions
of Generated Rules
        │
        ▼
Association Graph
        │
        ▼
Target Backend
```

This separation of concerns keeps programs remarkably compact. The programmer reasons about local interactions, while the compiler is responsible for constructing the enormous computational structures needed to realize them.

---

## Toward Computational Matter

Neighborhood Rules are where MatterScript begins to move beyond conventional software.

Traditional programs execute instructions over collections of data.

MatterScript constructs collections of interacting regions, each governed by the same simple local behavior.

As we introduce domains such as `@domain(spatial3d)`, these neighborhoods no longer need to represent cells in a one-dimensional automaton. They can represent adjacent voxels, neighboring finite elements, atoms within a crystal lattice, interacting molecules, or regions within a simulated biological tissue.

The same mechanism applies regardless of scale.

A local interaction remains local.

The compiler simply extends that interaction across whatever geometry the programmer has described.

In this way, MatterScript unifies Karl Fant's model of causal association with the rule-based evolution of *A New Kind of Science*. The programmer defines **what interactions are possible**. The compiler constructs the computational fabric in which those interactions unfold. From a handful of simple Neighborhood Rules, systems containing millions or even billions of autonomous interacting regions can be synthesized automatically, all while preserving the same elegant, local description from which they began.

*Drafting in progress...*
