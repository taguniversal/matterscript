# The Invocation Programming Language

Everything we have discussed so far—propagation, geometry, locality, completeness, causality, and tokens—needs a language capable of expressing those ideas.

MatterScript is that language.

Unlike most programming languages, MatterScript does not describe a sequence of instructions to execute. It describes a network of relationships through which information propagates.

Its syntax is intentionally small.

At its core, the language contains only four fundamental concepts:

* Source and Destination Places
* Invocations
* Definitions
* Name correspondence

Everything else emerges from these four ideas.

---

## Places

The smallest unit of a MatterScript program is not a variable.

It is a **place**.

A place represents a location where information may exist.

Places come in two forms.

**Destination places** receive incoming information that will participate in a computation.

```matterscript
$SUM
```

**Source places** produce completed information after a computation has resolved.

```matterscript
SUM<>
```

Unlike variables, places do not own state.

They define the points through which information flows.

A destination place answers the question,

*"Where is information flowing to?"*

A source place answers,

*"Where does resolved information flow from?"*

This distinction may seem subtle at first, but it eliminates one of the oldest ambiguities in programming languages. A variable simultaneously represents storage, identity, value, and destination. MatterScript separates these ideas into explicit relationships.

---

## Invocations

Places become useful only when they are connected.

An **invocation** establishes one of those connections.

```matterscript
ADD($A $B)(SUM<>)
```

Read this almost like a sentence.

> Invoke the definition named `ADD`, using the information arriving at destination places `$A` and `$B`, and allow the completed result to emerge from the source place `SUM<>`.

Nothing executes here.

Nothing is assigned.

No function is "called" in the conventional sense.

The invocation simply declares a boundary through which information may propagate.

One side receives information.

The other side produces completed information.

The computation itself exists inside the associated definition.

---

## Definitions

A definition describes how one set of relationships gives rise to another.

```matterscript
ADD[(A<> B<>)( $SUM )

    ...

]
```

Every invocation associates with a definition of the same name.

The correspondence is entirely symbolic.

An invocation named `ADD` resolves against the definition named `ADD`.

No addresses.

No pointers.

No jump tables.

Just names.

The interface between an invocation and its definition is beautifully symmetrical.

The **destination places** of the invocation associate, by position, with the **source places** of the definition.

The **source places** of the invocation associate, by position, with the **destination places** of the definition.

In other words, information enters through the invocation, flows into the definition, is resolved by the internal network, and then returns through the invocation back into the surrounding expression.

From there, the definition constructs an internal network of additional invocations, each connected through names.

Because every definition establishes its own naming domain, internal names never collide with names outside the definition.

A definition is therefore more than a reusable function.

It is an isolated and replicatable computational universe.

---

## Name Correspondence

The fourth concept is the one that surprises almost everyone.

MatterScript has no explicit wiring syntax.

Connections arise through **name correspondence**.

```matterscript
OR($LEFT $RIGHT)(SUM<>)

NOT($SUM)(INVERTED<>)

AND($SUM $ENABLE)(RESULT<>)
```

The compiler recognizes that the source place ```SUM<>``` and every destination place named ```$SUM``` refer to the same point in the computational network. The connection is created automatically. If multiple destination places share the same correspondence name, the information naturally propagates to each of them without requiring explicit wiring.

Nothing else is required.

Name correspondence is therefore doing much more than replacing variables.

It expresses connectivity.

It expresses causality.

And, as we saw in earlier chapters, it expresses locality.

The names do not identify storage.

They identify relationships.

---

## A Language of Relationships

Readers familiar with procedural languages often ask what MatterScript does *not* contain.

The answer is almost as revealing as what it does.

There are no primitive data types.

No predefined operators.

No built-in control structures.

No loops.

No `if` statements.

No memory addresses.

No variables.

No global state.

No sequence of execution.

No program counter.

No notion of "the next instruction."

Those concepts are absent because the language is not describing execution.

It is describing a network.

Everything that appears dynamic in a conventional language emerges naturally from propagation through that network.

---

## From One Dimension to Many

There is another remarkable property hidden beneath this deceptively simple syntax.

A MatterScript program is written as a one-dimensional stream of text.

Reality is not.

Electronic circuits occupy three-dimensional space.

Biological systems occupy three-dimensional space.

Chemical reactions unfold throughout physical space.

Weather develops across an entire atmosphere.

The purpose of the language is therefore not to imitate the geometry of the system directly.

Its purpose is to **refer** to that geometry.

Names identify relationships that cannot be expressed by adjacency in a line of text.

The compiler reconstructs those higher-dimensional relationships during compilation, assembling the computational fabric implied by the source code.

The program is not the computation.

It is a compact description of the computation.

---

## A Different Kind of Programming Language

Most programming languages answer a familiar question.

*"What should the processor do next?"*

MatterScript answers a different one.

*"How is information related?"*

From that single question emerge propagation.

Locality.

Geometry.

Completeness.

Events.

Concurrency.

And even hardware itself.

The syntax is intentionally small because its purpose is not to describe every possible operation.

Its purpose is to describe the relationships from which every operation emerges.

Once you begin reading MatterScript this way, the language becomes surprisingly regular.

Every program is built from the same small vocabulary repeated over and over again.

Places.

Invocations.

Definitions.

And the names that bind them together.

Those four ideas are enough to describe computations ranging from Boolean logic to biological metabolism, from digital circuits to planetary simulations, because they describe not *what* a machine should do, but *how* information exists and propagates through the computational universe.

## Numbers as Symbols

One aspect of MatterScript that often surprises programmers is its treatment of numbers.

Most programming languages inherit their notion of numbers directly from mathematics. An integer is understood to occupy a position on an infinite number line. Arithmetic operates by manipulating place-value representations—binary, decimal, hexadecimal, or some other radix.

MatterScript begins from a different premise.

A value is first and foremost a symbol.

Whether that symbol happens to represent the number 7, the amino acid lysine, the state of a traffic light, or the identifier of a chemical species is entirely determined by the relationships in which it participates.

There is nothing fundamentally special about numbers.

They are simply another kind of token.

## Values Are Not Encodings

In conventional computing, the number 42 is represented as a sequence of bits.

Those bits are decoded, manipulated by arithmetic hardware, and then encoded again into another sequence of bits.

MatterScript does not require every value to be expressed as a place-value number.

Instead, a value may be represented directly as one member of a finite set of possible symbols.

If a computation distinguishes between fifty possible values, then there are simply fifty possible symbolic states.

Each state participates directly in the relationships that define the computation.

There is no requirement that every value first be embedded within a universal numeric encoding.

## Direct Relationships

This seemingly small distinction has important consequences.

Traditional arithmetic gains tremendous flexibility by representing every number using a common structure.

The same adder can add one or one million because every value ultimately reduces to the same binary representation.

That generality comes at a cost.

Every computation must continually encode, decode, compare, and manipulate place-value numbers.

MatterScript allows a different approach.

When a computation naturally consists of a finite collection of states, those states can interact directly.

There is no number line.

There is no implicit ordering.

There is no requirement that neighboring symbols possess any mathematical relationship at all.

Only the relationships that matter to the computation need to exist.

## Computation Without Arithmetic

Many real-world systems are not fundamentally arithmetic.

A protein may exist in one of several conformational states.

A traffic controller may distinguish among signal phases.

A biological cell may transition among metabolic conditions.

A packet on a network may occupy one of several protocol states.

These systems are typically forced into numeric representations because conventional computers fundamentally manipulate numbers.

MatterScript removes that assumption.

If the computation is symbolic, the representation can remain symbolic.

The compiler constructs the relationships directly, without first translating them into arithmetic.

## Choosing the Right Representation

This does not mean that MatterScript abandons conventional numbers.

Arithmetic remains an important and efficient way to express many classes of computation.

Addition, multiplication, floating-point operations, and signal processing all continue to have natural representations.

The difference is that arithmetic is no longer the foundation upon which every other computation must be built.

It becomes one representation among many.

MatterScript allows the programmer to choose the representation that most naturally matches the problem being solved.

Sometimes that representation is a binary integer.

Sometimes it is a floating-point value.

And sometimes it is simply a collection of named symbols participating in a network of relationships.

In MatterScript, numbers are no longer privileged simply because conventional computers happen to perform arithmetic well.

They are treated as one kind of information among many, each represented in the form that most directly expresses the computation.

*Drafting in progress...*
