# Language Overview

## Understanding a MatterScript Definition

If you've written software before, the first thing you'll notice about MatterScript is what isn't there.

There are no variables.

There are no assignments.

There are no if statements.

There are no loops.

Instead, a MatterScript program describes a network of computations connected together by named places. Values don't move through a sequence of instructions—they propagate through a graph. Every definition is a small network, and larger systems are built by composing those networks together.

Let's look at a complete example.

```matterscript
// linear: TAG-129 Imperative form of expression

FULLADD(0, 1, 0)(< > CARRYOUT < >)  $CARRYOUT

FULLADD[(X< >Y< >C< >) ($SUM $CARRY)
NOT($X)(OP1< >)
AND($OP1 $Y)(OP4< >)
NOT($Y)(OP2< >)
AND($X $OP2)(OP3< >)
OR($OP4 $OP3)(FIRSTSUM< >)
NOT($FIRSTSUM)(OP6< >)
AND($C $OP6)(OP7< >)
NOT($C)(OP5< >)
AND($OP5 $FIRSTSUM)(OP8< >)
OR($OP7 $OP8)(SUM< >)
AND($X $Y)(OP10< >)
AND($C $FIRSTSUM)(OP9< >)
OR($OP10 $OP9)(CARRY< >)
: OR[(A< > B< >)($res) res<$A$B()> :0,0[0] 0,1[1] 1,0[1] 1,1[1] ]
  AND[(A< > B< >)($res) res<$A$B()> :0,0[0] 0,1[0] 1,0[0] 1,1[1] ]
  NOT[(A< >)($res) res<$A()> :1[0] 0[1] ] ]
```

At first glance this looks unusual, but there are really only three ideas at work.

## Definitions

Every MatterScript program is built from **definitions**. If you're coming from a conventional programming language, the closest analogy is a function or module, but a MatterScript definition describes a **network of relationships** rather than a sequence of instructions.

A definition begins with a name followed by two interface lists.

```matterscript
FULLADD[(X<> Y<> C<>) ($SUM $CARRY)
```

The first list declares the **source places** that provide information to the definition.

The second list declares the **destination places** that the definition will eventually produce.

You can think of these as the external interface of the network. Everything inside the definition exists to transform information arriving at the source places into information that eventually reaches the destination places.

Unlike an imperative function, a MatterScript definition doesn't "run" from top to bottom. It becomes active as values propagate through its internal network. Once every dependency needed by a particular invocation is complete, that portion of the network resolves naturally.

---

## Invocations

The body of a definition consists almost entirely of function invocations.

```matterscript
NOT($X)(OP1<>)

AND($OP1 $Y)(OP4<>)

OR($OP4 $OP3)(FIRSTSUM<>)
```

Each line says exactly one thing:

> Invoke this definition using these named inputs and place the result into this named output.

Nothing is assigned.

Nothing is overwritten.

Each invocation simply adds another node to the growing computation graph.

Notice that the order of the statements isn't particularly important. Unlike an imperative language, MatterScript doesn't execute one statement after another. An invocation becomes active as soon as every destination place it references contains a complete value. The apparent sequence of the source code exists primarily to make the network readable for humans.

---

## Names Create Connections

Perhaps the most unusual feature of MatterScript is that wires are never drawn explicitly.

Instead, names create the connections automatically.

When the output of one invocation is named `FIRSTSUM`...

```matterscript
OR($OP4 $OP3)(FIRSTSUM<>)
```

...another invocation can consume it simply by referring to `$FIRSTSUM`.

```matterscript
AND($C $FIRSTSUM)(OP9<>)
```

No explicit wiring statement is needed. The compiler recognizes that both names refer to the same place and connects them together automatically.

Throughout a MatterScript program, names define **connectivity**, not variable storage.

But connectivity is only part of the story.

By describing which computations produce information and which computations consume it, a MatterScript program also defines **causality**. Every connection identifies not only where information flows, but **what can cause something else to happen**. The compiler therefore constructs more than a network of wires—it constructs a network of cause-and-effect relationships.

This distinction becomes increasingly important as systems grow larger.

In conventional software, a simulation often advances by repeatedly scanning every element in the model to determine whether anything has changed. Whether simulating molecules, ecosystems, electrical grids, or weather systems, the processor continually revisits enormous amounts of state simply to discover where the next computation should occur.

MatterScript approaches the problem differently.

Because the causal relationships are known at compile time, the compiler already knows which computations are affected by each result. When information propagates, only those computations whose inputs have changed become active. The computation follows the structure of the problem itself rather than repeatedly searching for work to do.

This idea extends far beyond digital logic. In later chapters, we'll use the same language constructs to describe chemical reactions, physical simulations, biological systems, and large-scale computational models. Although these systems appear very different, they share the same underlying principle: **local causes produce local effects, and global behavior emerges from the propagation of those effects through a connected network.**

Rather than describing how values are copied from one location to another, MatterScript describes the relationships that govern both **connectivity** and **causality**, allowing the compiler to construct a computational fabric that mirrors the structure of the problem itself.


---

## Constant Definitions

Most definitions contain an internal network of invocations. Some definitions, however, are much simpler.

A **constant definition** contains no input interface, no internal definitions, and no resolution expression. It consists only of a name and a value.

```matterscript
ONE[1]

ZERO[0]
```

Because there are no inputs to resolve, the value is immediately returned whenever the definition is invoked.

Although these look trivial, constant definitions are one of the fundamental building blocks of MatterScript. They define the **value transformation rules** that describe how information moves through a network.

Consider the AND gate introduced earlier.

```matterscript
AND[(A<> B<>)($res)

res<$A$B()>

:0,0[0]
 0,1[0]
 1,0[0]
 1,1[1]
]
```

The lines following the colon are themselves constant definitions.

Each key on the left represents a possible invocation name formed by concatenating the values arriving on `$A` and `$B`.

When `$A` contains `1` and `$B` contains `0`, the composed name becomes `10`. The compiler locates the constant definition named `10` and returns its associated value—in this case `0`.

While the formed symbols are the concatenaed values like 00 and 01, for correct compiler interpretation of separate component symbols, you as the developer register your intent in the source code by separating the content values with the general separator comma ','.

Rather than executing conditional logic, MatterScript performs a lookup. The incoming token values determine which constant definition is selected, and that definition immediately returns its contents to the invocation.

Taken together, these constant definitions form the complete truth table of the AND gate.

This idea extends far beyond Boolean logic. A constant definition doesn't have to return a single integer. It can return an entire fragment of MatterScript that is inserted back into the network and resolved as if it had been written directly in place.

For example, a selector might choose between two different computation paths:

```matterscript
A[...]

B[...]

SELECT[(select<>)($out)

$out<$select()>

:A[A()]
 B[B()]
]
```

If `select` contains `A`, the constant definition `A[...]` is selected and its contents are returned to the place of invocation. If `select` contains `B`, the alternate definition is returned instead.

In this sense, constant definitions are much more than literals. They are the language's mechanism for expressing lookup tables, truth tables, compile-time dispatch, and even dynamic substitution of computation. Throughout MatterScript you'll encounter constant definitions everywhere—from primitive logic gates to large physics lookup tables generated automatically by the compiler.

---

## Primitive Definitions

At the end of the full-adder listing are three more definitions.

```matterscript
AND[...]

OR[...]

NOT[...]
```

These are not built-in language keywords. They are ordinary MatterScript definitions written in exactly the same language as every other component.

The only difference is that they terminate in collections of constant definitions rather than invoking additional networks.

```matterscript
:0,0[0]
 0,1[0]
 1,0[0]
 1,1[1]
```

This collection of constant definitions completely specifies the behavior of the AND gate.

Likewise, the OR and NOT definitions each contain their own independent lookup tables. Even though all three definitions use names such as `A`, `B`, and `res`, those names exist only within the definition in which they are declared. There is no possibility of collision because every definition has its own private scope.

This is an important design principle: there are no privileged language primitives. Even the simplest logical operators are expressed using the same mechanisms available to every MatterScript programmer.

---

## Reading MatterScript

A useful way to read MatterScript is to ignore the formatting at first and focus on the flow of information.

Every definition follows the same pattern:

1. Declare the external interface.
2. Invoke other definitions.
3. Connect them together through shared names.
4. Produce one or more outputs.

Once you begin thinking in terms of connected computations rather than sequential instructions, the language becomes surprisingly regular. Large systems are built from the same small vocabulary repeated over and over: definitions, places, invocations, and constant definitions.

The full adder shown here may appear very different from an equivalent implementation in C or Verilog, but conceptually it is doing something remarkably simple. It is describing a network of relationships. The compiler's job is to transform that description into executable hardware while preserving those relationships exactly.

