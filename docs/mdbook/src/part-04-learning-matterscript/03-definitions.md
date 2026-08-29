# Definitions

If invocations are the doorways through which information enters and leaves a computation, **definitions** are the computations themselves.

Every definition describes a self-contained network of relationships. It receives information through its input boundary, transforms that information by connecting together other definitions, and presents the completed result through its output boundary.

A definition always begins with a name.

```matterscript
FULLADD[(X<> Y<> C<>)( $SUM $CARRY )

    ...

]
```

That name serves two purposes.

First, it gives the definition an identity that other parts of the program can invoke.

Second, it creates a completely independent naming domain. Every correspondence name declared inside the definition exists only within that definition. Internal names can be chosen for clarity without worrying about collisions elsewhere in the program.

Like a function in other languages, a definition may be reused many times. Unlike a conventional function, however, a definition is not a sequence of instructions. It is a description of a network.

---

## The Interface

Every definition begins with two lists enclosed in parentheses.

```matterscript
(X<> Y<> C<>)( $SUM $CARRY )
```

The first list declares the **source places** through which information enters the definition.

The second list declares the **destination places** through which completed results leave the definition.

These two lists form the public interface of the definition.

Everything inside the definition exists solely to transform the incoming relationships into the outgoing ones.

One subtle aspect of MatterScript is that these interface lists are mirror images of an invocation.

When an invocation supplies information through its destination places, those values appear at the corresponding source places of the definition.

Likewise, when the definition produces results through its destination places, those results emerge from the corresponding source places of the invocation.

This inversion often seems unusual at first, but it reflects the flow of information rather than the layout of the source code. Information enters one boundary, propagates through the internal network, and exits through the opposite boundary.

Once you begin thinking in terms of propagation instead of parameter passing, the symmetry becomes surprisingly natural.

---

## The Body of a Definition

After the interface comes the body of the definition.

This is where the computation is described.

```matterscript
NOT($X)(OP1<>)

AND($OP1 $Y)(OP4<>)

OR($OP4 $OP3)(FIRSTSUM<>)

...
```

Notice what is missing.

There are no assignments.

No variables.

No control flow.

No sequence of execution.

Each invocation simply introduces another relationship into the network.

Together, these invocations form a graph of causes and effects that the compiler later transforms into an executable implementation.

The source code is written linearly because humans read text one line at a time.

The computation itself is not linear.

---

## Definitions Build Definitions

One of the most elegant aspects of MatterScript is that every definition is built exactly the same way.

A full adder is constructed by invoking AND, OR, and NOT.

An arithmetic logic unit may be constructed by invoking full adders.

A processor may be constructed by invoking arithmetic logic units.

A computer may be constructed by invoking processors, memories, and communication fabrics.

At every level, the language remains unchanged.

There is no distinction between primitive expressions and large systems.

The same syntax that describes a Boolean gate can also describe a distributed simulation, a robotic control system, or a biological pathway.

Only the scale changes.

---

## Isolation Through Correspondence

Because every definition establishes its own correspondence domain, names are always interpreted locally.

The name `SUM` inside a full adder has no relationship to a `SUM` inside another definition unless one is explicitly connected through an invocation.

This isolation allows definitions to remain completely self-contained.

You never need to invent globally unique names.

You simply describe the relationships within the current definition, and the invocation boundary handles the correspondence with the outside world.

In many languages, managing scope is largely about preventing accidental collisions.

In MatterScript, the syntax naturally prevents them.

---

## A Definition Is a Small Universe

It is tempting to think of a definition as a function because the syntax appears familiar.

A better analogy is a **physical system**.

The interface defines the boundary of that system.

Inside the boundary is a network of interacting components.

Information enters, propagates according to local relationships, and eventually emerges in a transformed form.

Nothing outside the boundary needs to know how the internal network is organized.

Nothing inside the boundary needs to know where its inputs originated or where its outputs will ultimately go.

The definition is a complete computational universe in miniature.

It describes not a sequence of actions, but a set of relationships whose behavior emerges naturally from the propagation of information.


*Drafting in progress...*
