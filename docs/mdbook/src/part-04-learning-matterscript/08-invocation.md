# Invocation

Every definition describes a local piece of computation.

An invocation is how those pieces are connected together.

If definitions are the building blocks of a MatterScript program, invocations are the joints that hold those blocks together.

They do not execute a function.

They establish a **relationship**.

---

## Invoking a Definition

An invocation consists of three parts:

```matterscript
AND($A $B)(RESULT<>)
```

The definition name:

```matterscript
AND
```

The destination list:

```matterscript
($A $B)
```

And the source list:

```matterscript
(RESULT<>)
```

Read aloud, this simply means:

> Resolve the definition named **AND** using the information arriving at `$A` and `$B`, then propagate the resulting token from `RESULT<>`.

Notice what is missing.

There is no assignment.

There is no return statement.

There is no instruction pointer moving into another function.

The invocation merely connects one region of the computational network to another.

---

## Interfaces, Not Calls

Programmers often think of function calls as transferring control.

MatterScript does not transfer control.

It transfers relationships.

When an invocation associates with a definition, the invocation's destination places become the definition's source places.

The definition's destination places become the invocation's source places.

The definition behaves as though it were physically inserted into the surrounding network.

Nothing is copied.

Nothing is executed "inside" another function.

The interface simply joins two parts of the larger computational fabric.

---

## Daisy-Chaining Computation

Karl Fant describes this relationship as **daisy-chaining**.

One boundary connects directly to the next.

Conceptually, the invocation and definition fit together like matching connectors.

```text
Invocation

($A $B) ---> Definition Inputs

Definition Outputs ---> (RESULT<>)
```

This interface is entirely syntactic.

Names inside the definition remain private.

Only the boundary is visible from the outside.

That makes definitions naturally composable.

A definition can be rewritten internally without affecting anything connected to it, provided its interface remains the same.

---

## Invocations Build Networks

An invocation does not perform work by itself.

Its purpose is to describe how work is connected.

Consider the beginning of the full adder.

```matterscript
NOT($X)(OP1<>)

AND($OP1 $Y)(OP4<>)

OR($OP4 $OP3)(FIRSTSUM<>)
```

Each invocation contributes another node to the growing network.

Notice how every result immediately becomes available to subsequent relationships through name correspondence.

The program grows outward like a circuit diagram rather than downward like a call stack.

By the time the compiler has processed the definition, these individual invocations have become a connected graph of causal relationships.

---

## Invocation Is Composition

This is perhaps the most important idea in the language.

An invocation is not asking another definition to perform work.

It is composing a larger computation from smaller ones.

That distinction may seem subtle at first, but it changes how we think about programs.

Instead of imagining a processor jumping from function to function, imagine an architect assembling a bridge from prefabricated components.

Each component contributes its own local behavior.

Together they form a larger structure.

MatterScript programs are assembled in exactly this way.

---

## Local Boundaries, Global Behavior

One remarkable consequence of invocations is that every definition remains completely local.

Each definition knows only its own interface.

It has no knowledge of the larger system in which it participates.

Yet when thousands—or millions—of definitions are connected together through invocations, coherent global behavior emerges.

This is the same principle we have encountered throughout the book.

Local relationships produce global computation.

No central controller is required.

---

## One Language at Every Scale

Because invocations simply connect definitions, there is no distinction between small and large systems.

A primitive logic gate is invoked exactly the same way as a processor.

A processor is invoked exactly the same way as a network protocol.

A biological model could be invoked exactly the same way as a weather simulation.

The syntax never changes.

Only the definitions become larger.

This consistency is one of MatterScript's greatest strengths.

The language scales by composition rather than by accumulating new abstractions.

---

## Building Computational Fabric

If definitions are the vocabulary of MatterScript, invocations are its grammar.

They tell the compiler how individual pieces relate to one another.

Not in time.

Not through memory.

But through causality.

Each invocation extends the computational fabric, joining one local network to another until the complete system emerges as a single connected web of relationships.

Nothing is "called."

Everything is connected.

*Drafting in progress...*
