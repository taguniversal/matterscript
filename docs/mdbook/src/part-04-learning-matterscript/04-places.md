# Places

Every programming language has a fundamental unit of expression.

In C, it is the variable.

In Lisp, it is the list.

In SQL, it is the relation.

In MatterScript, it is the **place**.

A place is where information exists.

Not memory.

Not storage.

Not a variable.

**A place**.

This may seem like a small difference in terminology, but it reflects a fundamentally different way of thinking about computation.

Variables are containers whose contents change over time.

Places are locations through which information flows.

---

## Information Exists Somewhere

Earlier in this book we introduced one of MatterScript's guiding principles:

> Information always exists somewhere.

Places are how the language expresses that idea.

Every token occupies a place.

Every computation consumes information from places and produces information into other places.

Every causal relationship in a MatterScript program is ultimately expressed as a relationship between places.

If you understand places, you understand the foundation of the language.

---

## Two Kinds of Places

MatterScript distinguishes between two kinds of places.

A **source place** is where information emerges after a computation has completed.

```matterscript
SUM<>
```

A **destination place** is where information arrives to participate in another computation.

```matterscript
$SUM
```

Although the syntax differs by only two characters, the distinction is important.

A source place represents the origin of a completed result.

A destination place represents the destination of information that will be resolved.

Every propagation in MatterScript begins at a source place and ends at one or more destination places.

---

## Names Create Association

Unlike a schematic, MatterScript never draws wires.

Instead, places associate through **correspondence names**.

```matterscript
OR($A $B)(SUM<>)

NOT($SUM)(INVERTED<>)

AND($SUM $ENABLE)(RESULT<>)
```

Here, the source place `SUM<>` associates automatically with every destination place named `$SUM`.

The compiler constructs the connections.

Nothing else is required.

One source place may associate with many destination places.

This is the language's natural form of fan-out.

Information propagates simultaneously to every associated destination without requiring explicit duplication or copying.

---

## Places Are Not Variables

It is tempting to think of a place as another name for a variable.

It is not.

A variable represents mutable storage.

A place represents a point of association.

The distinction matters.

Variables are updated.

Places are connected.

Variables emphasize ownership.

Places emphasize relationships.

Variables encourage us to ask,

*"What value does this object contain?"*

Places encourage us to ask,

*"What computations are related?"*

This shift in perspective is one of the most important conceptual transitions in learning MatterScript.

---

## One Source, Many Destinations

Every correspondence name identifies exactly one source place.

There cannot be two source places with the same name within the same correspondence domain.

If there were, the compiler could not determine which source should provide the information.

Destination places, however, may appear as many times as needed.

```matterscript
FIRSTSUM<>

...

AND($FIRSTSUM $C)(...)

...

NOT($FIRSTSUM)(...)

...

OR($FIRSTSUM $ENABLE)(...)
```

Each destination named `$FIRSTSUM` receives the same propagated token.

No explicit fan-out operator is necessary.

The correspondence itself defines the connectivity.

---

## Places Define the Network

As a MatterScript program grows, it becomes tempting to think that invocations are the primary objects.

In reality, the opposite is true.

Invocations exist because they connect places.

Definitions exist because they organize places.

Propagation occurs because places are associated.

Completeness is evaluated at places.

Tokens reside in places.

Geometry, as we will see later, gives places physical location.

Everything else in the language is built around them.

---

## From Names to Geometry

In this chapter, a place is identified by its correspondence name.

That is enough to express logical connectivity.

Later in the book, we will extend this idea.

A place may have not only a name, but also a position in physical space.

When that happens, the language begins to describe not merely *what* is connected, but *where* those relationships exist.

Names establish logical structure.

Geometry will establish physical structure.

Together they allow MatterScript to describe computational systems with the same fidelity that semiconductor manufacturing describes physical ones.

---

## A Computational Location

Perhaps the simplest way to think about a place is this:

A place is not a piece of memory.

It is not a variable.

It is not an address.

A place is a location in the computational universe.

Information appears there.

Relationships connect there.

Causes arrive there.

Effects depart from there.

Everything else in MatterScript exists to describe how information moves from one place to another.


*Drafting in progress...*
