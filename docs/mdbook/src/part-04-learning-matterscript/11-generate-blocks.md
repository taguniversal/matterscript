# Generate Blocks

One of MatterScript's goals is to make large computational networks as easy to describe as small ones.

That creates an obvious challenge.

Many real systems consist of thousands—or millions—of nearly identical relationships.

A memory array contains thousands of repeated cells.

A systolic array repeats the same processing element over and over.

A cellular automaton may contain millions of identical neighborhoods.

Writing these structures by hand would add no information to the program. It would merely repeat the same pattern over and over.

The `generate` block exists to solve that problem.

Rather than describing computation, it describes **how to construct computation**.

---

## Generating Relationships

A generate block contains a generator expression followed by the ranges over which that expression should be expanded.

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

Instead of manually writing hundreds or thousands of nearly identical association expressions, the programmer describes the pattern once.

The compiler expands that pattern into the corresponding MatterScript network.

The generated result is exactly the same as if the programmer had written every relationship by hand.

---

## Source Generation, Not Runtime Execution

The most important thing to understand is that `generate` is **not** part of the running computation.

Nothing is generated while the program executes.

The generate block exists only during compilation.

Its purpose is to produce ordinary MatterScript definitions, places, invocations, and transform rules.

Once expansion is complete, the generated code behaves exactly like handwritten MatterScript.

This keeps the language remarkably simple.

The computational model never changes.

The compiler merely helps construct larger expressions.

---

## Declaring the Input Space

The `inputs` section specifies the variables that participate in generation.

```matterscript
inputs $x[0..255], $y[0..255]
```

Each variable defines a finite range over which the generator expression will be expanded.

Rather than describing individual values, these declarations describe an entire space of possible relationships.

The generator expression can then refer to those variables symbolically.

---

## Describing the Output Space

The `output` declaration specifies the range of values that the generated relationships may produce.

```matterscript
output [0..512]
```

This gives the compiler enough information to construct the resulting association network while preserving the same correspondence model used throughout the language.

---

## Compile-Time Constants

Large generated structures often depend on parameters.

The optional `const` declarations allow those parameters to be named.

```matterscript
const MAX_LIMIT = 512
const OFFSET = 4
```

These constants exist only while the generator is expanding the network.

They are not runtime variables.

Like the rest of the generate block, they disappear once generation is complete.

---

## Scaling Without Changing the Language

One of the remarkable aspects of MatterScript is that the generated result uses exactly the same language as everything else.

The compiler does not introduce a hidden runtime.

It does not create a new execution model.

It simply writes more MatterScript.

Whether a definition contains ten relationships or ten million, the underlying computational model remains identical.

Generation changes the size of the description.

It does not change the nature of the computation.

---

## From Patterns to Computational Fabric

Today, `generate` provides a concise way to construct large regular networks.

In the future, it may become the foundation for much richer forms of synthesis.

A geometry engine could generate millions of spatial relationships from a compact geometric description.

A compiler could synthesize entire arithmetic units from algebraic specifications.

A simulation framework could construct vast lattices of interacting cells from a single neighborhood rule.

In every case, the principle remains the same.

The programmer describes the pattern.

The compiler expands the pattern into explicit relationships.

Those relationships become part of the computational fabric, indistinguishable from code written by hand.

*Drafting in progress...*
