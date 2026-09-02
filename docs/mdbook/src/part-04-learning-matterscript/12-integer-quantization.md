# Integer Quantization

Most programming languages begin with numbers.

MatterScript begins with distinctions.

That difference may seem subtle at first, but it changes the way we model problems.

Traditional software assumes that every quantity is fundamentally a number.

MatterScript asks a different question:

> **What are the meaningful states of this system?**

The answer is often not a number at all.

It is a finite set of distinguishable possibilities.

Those possibilities become **single-digit numbers**.

---

## Single-Digit Numbers

When most programmers hear the word *digit*, they think of decimal notation.

MatterScript uses the term differently.

A single-digit number is a value represented by **one symbol**, regardless of how many possible values exist.

If a quantity can take on fifty distinct values, then its number system simply contains fifty digits.

There is no need to construct that value from multiple place-value digits.

Instead, each possible state is represented directly.

You can think of it as choosing a radix large enough that every value fits into a single position.

---

## From Mathematics to Tokens

This changes one of the programmer's primary responsibilities.

In conventional software, we begin by deciding how many bits are needed to store a number.

In MatterScript, we begin by deciding what distinctions actually exist.

Suppose we are modeling traffic lights.

A traditional program might write:

```text
0 = Red
1 = Yellow
2 = Green
```

Those integers have no intrinsic meaning.

They are merely encodings.

MatterScript would instead treat the three possible states as the vocabulary of the system.

```text
RED
YELLOW
GREEN
```

Each is a single token.

Each is equally fundamental.

None is "greater" than another.

---

## There Is No Number Line

This is perhaps the hardest idea for programmers to internalize.

Single-digit numbers do not necessarily possess numerical relationships.

There is no requirement that one value be larger than another.

There may be no meaningful notion of distance.

No ordering.

No arithmetic.

Only distinction.

For a traffic light, asking whether **GREEN** is larger than **RED** is meaningless.

For a protein, asking whether **Folded** is greater than **Unfolded** is equally meaningless.

The values simply represent different states.

---

## Quantizing a Weather System

Consider a simple weather simulation.

Instead of assigning floating-point temperatures everywhere, we might decide that, for our model, only a small number of atmospheric states matter.

```text
COLD
COOL
WARM
HOT
```

Humidity might become

```text
DRY
NORMAL
HUMID
SATURATED
```

Wind might become

```text
NORTH
SOUTH
EAST
WEST
CALM
```

These are no longer numbers in the mathematical sense.

They are tokens describing the current state of a region.

Transform rules define how neighboring regions influence one another.

Millions of cells evolve simultaneously through local interactions.

The programmer has quantized the continuous world into a vocabulary appropriate for the simulation.

---

## Quantizing Chemistry

Chemistry provides another example.

A conventional simulation often stores tables of atomic properties and repeatedly computes interactions numerically.

MatterScript encourages a different perspective.

The fundamental vocabulary might consist of tokens such as

```text
H
O
C
N
```

along with bonding states

```text
FREE
SINGLE_BOND
DOUBLE_BOND
```

Transform rules describe how neighboring atoms interact.

As relationships become satisfied, larger molecular structures emerge naturally from the network.

The simulation evolves because local distinctions change, not because a processor repeatedly scans an array looking for work.

---

## Quantizing Digital Logic

Digital electronics has already been using this idea for decades.

A logic signal is not an arbitrary integer.

It has a very small vocabulary.

```text
NULL
0
1
```

Each state has a specific meaning.

Transform rules describe how those states propagate through logic.

This is precisely why MatterScript maps so naturally onto asynchronous hardware.

The language speaks the same conceptual language as the underlying circuits.

---

## Choosing the Vocabulary

Viewed this way, quantization becomes one of the most important design decisions in a MatterScript program.

Before writing transform rules, the programmer asks:

> **What distinctions matter?**

Everything else is discarded.

A weather model does not need nanometer precision.

A biological model may not care about floating-point voltages.

A traffic simulation has no concept of molecular bonds.

Each domain chooses its own vocabulary.

The resulting tokens become the atoms from which the computation is built.

---

## Precision Through Representation

At first glance, reducing continuous mathematics to a finite vocabulary might appear to sacrifice precision.

In practice, the opposite is often true.

Every simulation already makes approximations.

Floating-point numbers are approximations.

Finite element meshes are approximations.

Time steps are approximations.

MatterScript simply makes that approximation explicit.

Instead of hiding quantization inside binary encodings, it asks the programmer to define the meaningful distinctions directly.

Once those distinctions have been chosen, the resulting computation becomes dramatically simpler.

Relationships become direct.

Transform rules become local.

Hardware can exploit massive concurrency because every token already represents exactly the information the system needs.

---

## Computation as Distinction

This chapter illustrates a recurring theme throughout MatterScript.

Traditional software tends to begin with mathematics and encode the world into numbers.

MatterScript begins with the world itself.

It asks what objects exist, what states they may occupy, and how those states transform through local interactions.

Numbers become just one possible vocabulary among many.

The real foundation of computation is not arithmetic.

It is distinction.

*Drafting in progress...*
