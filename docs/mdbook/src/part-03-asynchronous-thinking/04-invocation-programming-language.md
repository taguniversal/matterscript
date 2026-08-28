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

It is an isolated computational universe.

---

## Name Correspondence

The fourth concept is the one that surprises almost everyone.

MatterScript has no explicit wiring syntax.

Connections arise through **name correspondence**.

```matterscript
OR($LEFT $RIGHT)(SUM<>)

...

AND($SUM $ENABLE)(RESULT<>)
```

The compiler recognizes that both references describe the same place.

The connection is created automatically.

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

*Drafting in progress...*
