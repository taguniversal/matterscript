# Field of Resolution

At the heart of every definition is a **field of resolution**.

This is where computation happens.

Not by executing instructions one after another, but by allowing tokens to propagate through a bounded network of relationships until every possible consequence has been expressed.

A field of resolution is the computational interior of a definition.

The interface describes what enters and what leaves.

The field of resolution describes what happens in between.

```matterscript
FULLADD[(X<> Y<> C<>)( $SUM $CARRY )

    NOT($X)(OP1<>)
    AND($OP1 $Y)(OP4<>)
    OR($OP4 $OP3)(FIRSTSUM<>)

    ...

]
```

Everything between the interface and the contained definitions belongs to the field of resolution.

---

## A Local Universe

One useful way to think about a field of resolution is as a small universe with its own internal laws.

Tokens enter through the definition's source places.

They propagate through local relationships.

New tokens are produced.

Eventually the completed results appear at the definition's destination places.

Nothing outside the definition needs to know how that process unfolds.

The internal network is completely encapsulated.

This is not merely an organizational convenience.

It is what allows MatterScript to compose arbitrarily large systems from small, understandable pieces.

---

## Resolution Is Local

One of the recurring themes of this book is **locality**.

Every interaction occurs because information has arrived at a particular place.

Fields of resolution apply the same principle to entire computations.

A definition never scans the rest of the program looking for work.

It never asks whether another computation has finished.

It never waits for a scheduler to grant permission to execute.

It simply responds to the arrival of complete information at its own boundary.

Everything it needs to know already exists within its local neighborhood.

This is one of the reasons MatterScript scales naturally from tiny logic gates to systems containing billions of interacting elements.

---

## Boundaries Matter

The boundary of a field of resolution is more than syntax.

It defines where causality begins and ends.

Outside the boundary, the definition is simply a named component.

Inside the boundary, the compiler can freely analyze propagation, construct dependency graphs, optimize placement, and ultimately generate hardware or software that preserves the expressed relationships.

Because the internal implementation is isolated, a definition can be rewritten, optimized, or even mapped onto an entirely different execution substrate without changing its external behavior.

Only the relationships at the boundary matter.

---

## A Reaction Chamber

The word *resolution* was chosen deliberately.

The goal is not to execute code.

The goal is to resolve relationships.

A useful analogy is a chemical reaction vessel.

Reactants enter.

Local interactions occur according to the laws governing that system.

Products leave.

The vessel itself does not orchestrate the reaction.

It simply provides the environment in which the reaction can occur.

A resolution area serves the same purpose.

It defines the space within which information is allowed to interact.

---

## Resolution Before Execution

Most programming languages ask a familiar question:

> *What instruction executes next?*

MatterScript asks a different one:

> *What relationships can now be resolved?*

That difference may seem subtle, but it changes the entire computational model.

The compiler is no longer concerned with constructing an execution order.

Instead, it constructs a network in which every local relationship resolves as soon as its required information is complete.

Execution becomes an implementation detail.

Resolution is the language itself.

---

## Computation Happens Inside Relationships

As we've progressed through this chapter, a pattern has begun to emerge.

Places define where information exists.

Tokens define the information itself.

Invocations connect one computation to another.

Definitions establish local boundaries.

Fields of resolution are where those relationships come alive.

The language is gradually revealing itself not as a sequence of operations, but as a landscape of interacting regions, each resolving its own local relationships while contributing to the behavior of the larger system.


*Drafting in progress...*
