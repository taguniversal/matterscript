## Transform Rules

As we have seen throughout this book, MatterScript builds complex behavior by composing definitions into increasingly larger networks. A full adder is built from logic gates. A processor is built from arithmetic units. A simulation is built from thousands or millions of interacting definitions.

Eventually, however, every hierarchy reaches a point where there is nothing left to decompose.

That is where **transform rules** come in.

Transform rules describe behavior directly. Rather than expressing a computation by invoking other definitions, they specify the relationship between an input and its corresponding output.

```matterscript
AND[(A<> B<>)($res)

    res<$A$B()>

    :0,0[0]
     0,1[0]
     1,0[0]
     1,1[1]
]
```

Here, the place of resolution forms the correspondence name `00`, `01`, `10`, or `11` from the arriving input tokens. That name selects one of the contained constant definitions, whose value is immediately returned as the result.

Nothing is executed.

Nothing is searched.

The behavior is simply declared.

---

## Computation as Transformation

In most programming languages, we think of computation as a sequence of operations.

An input is loaded into memory.

Instructions execute.

Intermediate values are produced.

Eventually a result is returned.

MatterScript approaches the problem from a different direction.

Every definition answers a single question:

> *Given these input tokens, what should this relationship produce?*

Sometimes that answer requires an entire network of interacting definitions.

Sometimes the answer is already known.

Transform rules express those known relationships directly.

Rather than describing *how* to compute a result, they declare *what* the result is.

---

## The Leaves of the Network

A useful way to think about transform rules is as the leaves of the computational tree.

Higher-level definitions are composed from smaller definitions.

Those definitions are composed from still smaller ones.

Eventually the hierarchy terminates in a set of transform rules that require no further decomposition.

The language itself makes no distinction between these levels.

A full adder and an AND gate are both definitions.

One happens to be implemented by composing other definitions.

The other happens to terminate in transform rules.

Composition, not special language primitives, is what gives the language its expressive power.

---

## More Than Lookup Tables

It is tempting to think of transform rules as lookup tables.

While the compiler may ultimately implement them that way, the language is expressing something more fundamental.

Each rule defines a relationship between information entering the definition and information leaving it.

```matterscript
:0,0[0]
 0,1[0]
 1,0[0]
 1,1[1]
```

These are not rows in a database.

They are declarations of causality.

When the incoming tokens form the name `11`, the relationship produces the token `1`.

When they form `00`, the relationship produces `0`.

The emphasis is not on storage, but on transformation.

---

## Building Without Built-ins

One of MatterScript's design principles is that there are no privileged language primitives.

`AND`, `OR`, and `NOT` are not keywords.

They are ordinary definitions.

The only difference is that they happen to terminate in transform rules rather than invoking additional definitions.

This uniformity makes the language remarkably scalable.

Whether you are describing a two-input logic gate, a cryptographic accelerator, a biological pathway, or a distributed simulation, every component is expressed using the same vocabulary of places, definitions, invocations, and transformations.

The language never changes.

Only the size of the network does.

---

## A Foundation for Higher-Level Systems

As MatterScript evolves, most transform rules will never be written by hand.

Compilers will synthesize them from Boolean minimization.

Geometry engines will generate them from spatial relationships.

Domain-specific libraries may derive them from physical laws, chemical reactions, or mathematical models.

To the language, however, they are all the same.

Every transform rule is simply a definition whose behavior is expressed directly rather than composed from smaller parts.

That uniformity is one of MatterScript's greatest strengths.

At every level of abstraction, from a single logic gate to a planetary simulation, computation is described using the same fundamental idea:

**Information arrives. Relationships resolve. New information emerges.**

*Drafting in progress...*
