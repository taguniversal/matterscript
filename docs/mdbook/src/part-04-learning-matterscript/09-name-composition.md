# Name Composition

Names are one of MatterScript's most powerful concepts.

Throughout this book we've seen names connecting places, selecting transform rules, and establishing causality between independent parts of a computation.

But names are not limited to simple identifiers.

They can also be **constructed dynamically** from the information flowing through the network.

This process is called **name composition**.

---

## Building a Name

Consider the definition of an OR gate.

```matterscript
OR[(A<> B<>)($result)

    $A$B()

    :0,0[0]
     0,1[1]
     1,0[1]
     1,1[1]
]
```

As tokens arrive at `A<>` and `B<>`, they are combined to form a single correspondence name.

If the arriving tokens are `0` and `1`, the composed name becomes:

```text
01
```

That composed name is then used to select the matching transform rule.

The computation is not performing a comparison.

It is forming a name and allowing the language's correspondence mechanism to resolve it.

---

## Names Are Structures

It is tempting to think of a composed name as a string.

That would miss the larger idea.

MatterScript treats names as **structured relationships**.

Each component contributes part of the completed correspondence.

The resulting name represents the combined state of all participating inputs.

This is why transform rules feel so natural.

Rather than asking,

> "If A equals 0 and B equals 1..."

the language simply forms the name represented by those arriving tokens.

That name either corresponds to a rule or it does not.

---

## Helping the Parser

You may have noticed that the transform rules include commas.

```matterscript
:0,0[0]
 0,1[1]
 1,0[1]
 1,1[1]
```

Internally, the correspondence name is simply the combination of the arriving tokens.

The commas are **not part of the name itself**.

Instead, they exist for the benefit of the programmer and the parser.

Without separators, a rule such as

```text
011
```

could represent several different structures depending on how the incoming tokens are partitioned.

Did it come from:

```text
0 11
```

or

```text
01 1
```

or three independent tokens?

The commas remove that ambiguity.

They tell the parser exactly which portion of the composed name corresponds to each incoming place.

They do **not** change the meaning of the composed name.

They simply make the programmer's intent explicit.

---

## Syntax That Expresses Intent

This is a recurring design principle throughout MatterScript.

Whenever possible, the syntax is designed to communicate intent rather than introduce additional semantics.

The commas do not alter the computation.

They do not change the internal representation.

They do not create a different correspondence relationship.

They simply record how the programmer intended the name to be composed.

The language remains simple.

The source code becomes clearer.

The parser receives an unambiguous description of the intended structure.

---

## Beyond Boolean Logic

The examples in this chapter use Boolean values because they are easy to visualize.

The idea is far more general.

Names can be composed from arbitrary tokens.

A biochemical simulation might compose the names of interacting molecules.

A routing engine might compose geometric regions.

A protocol stack might compose message types and state identifiers.

Wherever information can be combined to express a relationship, MatterScript can compose a correspondence name.

The mechanism never changes.

Only the participating tokens do.

---

## Example: Forming Water

Imagine a tiny region of space filled with tokens.

Initially it contains nothing more than individual atoms.

```text
H   H   O
```

Each atom is simply a token occupying a place.

No central program scans the region asking,

> "Can I make water yet?"

Instead, local transform rules describe what happens when compatible neighbors exist.

A simplified rule might be written conceptually as:

```matterscript
H,O,H -> H₂O
```

or in MatterScript style,

```matterscript
:H,O,H[H2O]
```

The exact syntax isn't important here.

The important point is that the three neighboring tokens form a correspondence name.

When the relationship

```
H,O,H
```

exists locally, the transform rule matches.

The three individual tokens disappear.

A new token appears.

```
H₂O
```

No search occurred.

No iteration occurred.

No scheduler was involved.

The relationship itself caused the transformation.

---

## Building Larger Structures

Now imagine the region contains thousands of atoms.

```
H H H O C N O H H ...
```

Most neighboring groups never satisfy any transform rule.

They simply remain unchanged.

Whenever a valid neighborhood forms, however, it immediately transforms into a larger structure.

Those larger structures become tokens themselves.

Now new rules become possible.

```
H
O
H
↓

H₂O
```

Later,

```
Protein Fragment
+
H₂O
↓

Hydrated Protein
```

The process continues naturally.

Simple tokens become molecules.

Molecules become complexes.

Complexes become organelles.

Every level is expressed using exactly the same mechanism:

> local relationships produce new local relationships.

---

## Reaching Stability

Eventually the region reaches a point where no transform rules apply.

Nothing is waiting.

Nothing is looping.

Nothing is consuming CPU cycles.

The computation has simply reached equilibrium.

At that point, the completed structure may propagate naturally to another region of the system, much like a finished protein being transported to a cell membrane.

The computation has not terminated because an instruction pointer reached the end of a program.

It has terminated because there are no remaining causal relationships capable of producing change.

---

## Why This Matters

This example hints at something much larger than chemistry.

Weather systems.

Crystal growth.

Traffic flow.

Biological development.

Galactic formation.

All of these systems evolve because local interactions continually produce new local interactions.

Today's computers simulate them by repeatedly scanning enormous arrays to ask whether anything has changed.

MatterScript describes the relationships directly.

When a valid relationship exists, it transforms.

When none exist, nothing happens.

The computation is driven by causality rather than inspection.

## Relationships Become Names

Name composition illustrates one of the central ideas of MatterScript.

Relationships are not discovered by searching memory.

They are not computed through chains of conditional statements.

They are expressed directly as correspondence.

Individual tokens arrive.

Their relationship forms a name.

That name identifies the next transformation.

From the programmer's perspective, this is a remarkably natural way to describe computation.

Rather than writing logic that asks *what should happen?*, you simply describe the relationships that exist.

The language allows those relationships to resolve themselves.

*Drafting in progress...*
