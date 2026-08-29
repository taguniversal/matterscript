# Tokens

In recent years, the word **token** has become part of every programmer's vocabulary.

Large language models consume streams of tokens representing words, punctuation, and fragments of language. Those tokens move through billions of parameters, gradually transforming into new tokens that become the model's response.

MatterScript uses the same word, but in a much broader sense.

A token is simply a unit of information.

It may represent a number.

A symbol.

A Boolean value.

A chemical species.

A network packet.

A state in a finite-state machine.

Or even another fragment of computation.

Language is only one possible kind of token.

---

## Information in Motion

Earlier we introduced the idea that computation is propagation.

Tokens are the things that propagate.

A place does not "contain a variable."

It temporarily presents a token.

That token moves through the network according to the causal relationships expressed by the program.

```matterscript
SUM<1>

...

AND($SUM $ENABLE)(RESULT<>)
```

Here the token `1` emerges from the source place `SUM<>`, propagates to every destination place named `$SUM`, and participates in the next computation.

Nothing has been assigned.

Nothing has been copied.

The information has simply propagated through the network.

---

## Tokens Have Meaning Because of Relationships

One of the most important differences between MatterScript and conventional programming is that a token has no intrinsic meaning.

The symbol

```text
ACTIVE
```

is not inherently more significant than

```text
7
```

or

```text
GLYCINE
```

Its meaning comes entirely from the relationships in which it participates.

If a definition recognizes `ACTIVE`, then it becomes part of that computation.

If another definition recognizes `GLYCINE`, then it becomes part of an entirely different one.

MatterScript does not privilege numbers over symbols.

Every token is simply information participating in a network of relationships.

---

## Tokens Are Not Objects

Object-oriented programmers may be tempted to think of tokens as tiny objects moving through the program.

That is not quite right.

Objects combine identity, storage, behavior, and often lifetime into a single construct.

Tokens do none of those things.

A token is simply information.

The network provides the behavior.

Places provide the locations.

Definitions provide the transformations.

The token merely carries information from one relationship to the next.

---

## Tokens Carry Potential

One of the recurring themes of this book is that computation exists not only in motion, but also in possibility.

A token resting at a place is not inactive.

It represents a computation waiting for its remaining causes.

Once every required token has arrived, the definition resolves, produces new tokens, and propagation continues.

This idea should feel familiar.

A transistor waiting for its inputs is still part of a computation.

A molecule waiting for another reactant is still part of a chemical reaction.

A neuron waiting for enough excitation is still participating in thought.

The token represents the information currently present.

The relationships determine what may happen next.

---

## Tokens Beyond Software

Because tokens are simply information, MatterScript naturally extends beyond conventional software.

In a biological simulation, a token might represent the concentration of a signaling molecule.

In a traffic simulation, it might represent the state of an intersection.

In a manufacturing model, it could represent the presence of a component on an assembly line.

In an AI system, it may literally represent a language token.

The language itself does not distinguish among these cases.

Each is simply information flowing through a network of places.

---

## The Atoms of Computation

If places define the geometry of the computational universe, then tokens are its atoms.

They occupy places.

They propagate through relationships.

They trigger events.

They participate in transformations.

Everything that changes within a MatterScript program ultimately changes because tokens move.

The language does not begin with variables or instructions.

It begins with information itself.

**Variables store information. Tokens *are* information.**

In imperative languages, information is trapped inside mutable containers. In MatterScript, information is the thing that moves, and the computation emerges from its movement through a network of relationships.

*Drafting in progress...*
