# Tokens Instead of Variables

Every programming language has a fundamental unit of computation.

In C and C++, it is the variable.

In object-oriented languages, it is often the object.

In functional languages, it is the immutable value.

MatterScript begins with something even simpler.

**Information itself.**

This may seem like a matter of terminology, but it reflects a fundamentally different way of thinking about computation.

Variables carry a great deal of conceptual baggage.

They imply ownership.

They imply storage.

They imply memory locations.

They imply mutation.

They imply a history of old values and new values.

For decades, these ideas have shaped the way programmers think about software.

MatterScript deliberately sets them aside.

---

Consider this simple MatterScript invocation.

```matterscript
NOT($A)(Q<>)
```

A programmer encountering this for the first time might naturally imagine that `$A` is a variable.

It is not.

Instead, imagine a single piece of information arriving at the input of the NOT definition.

If that information is a `1`, it propagates into the network.

The definition responds by producing a new piece of information—a `0`—which continues propagating toward its destination.

Nothing has been overwritten.

Nothing has been updated.

Nothing has been assigned.

One token of information entered the network.

Another token emerged.

The computation is simply the transformation and propagation of information.

---

This is quite different from the way most programmers are taught to think.

Consider a familiar statement in C.

```c
x = x + 1;
```

Although it appears to describe a single operation, several things actually happen.

The current value of `x` is read from memory.

A new value is calculated.

The previous value stored in `x` is discarded.

The new value replaces it.

Mutation is central to the computation.

The variable exists before the operation.

It exists after the operation.

Only its contents have changed.

MatterScript does not encourage this way of thinking.

Instead, a computation receives information and produces new information.

The previous information is not overwritten.

It simply continues to exist as part of the causal history of the computation.

---

This perspective is much closer to the behavior of the physical world.

A photon does not become a different photon because it entered a lens.

A water molecule does not overwrite itself when it participates in a chemical reaction.

Instead, interactions produce new states that continue propagating through the system.

MatterScript adopts this same viewpoint.

Information flows.

Information transforms.

Information combines.

Information separates.

The network responds to arriving information rather than repeatedly modifying named storage locations.

---

This distinction becomes even more important when we consider time.

Variables naturally encourage us to ask questions like,

*"What is the current value?"*

or

*"What was the previous value?"*

These are perfectly reasonable questions for sequential software.

But MatterScript asks a different question.

**Where is the information now?**

Its history is not defined by successive assignments.

Its history is defined by the path it has taken through the network.

Information is understood through propagation rather than mutation.

---

This leads to another important observation.

Information does not cease to participate in a computation simply because it has stopped moving.

Consider a logic gate whose inputs have stabilized.

From the perspective of an imperative language, nothing is happening.

The computation appears to be finished.

From the perspective of MatterScript, the computation is still present.

The information remains embodied within the stable state of the network.

It is waiting.

A new input may arrive a nanosecond later.

Or a year later.

Until then, the information continues to exist as part of the computational fabric.

**Information at rest is still part of the computation.**

This idea reflects the physical reality of digital hardware.

Every gate behaves as a tiny sample-and-hold device.

Once it reaches a stable state, that state represents potential.

It is ready to participate in the next propagation event whenever new information arrives.

Computation therefore consists not only of moving information, but also of preserving it in stable physical configurations that remain available for future interactions.

---

This way of thinking also changes how the compiler views a program.

A conventional compiler asks questions such as:

Where is this variable stored?

When is it read?

When is it written?

MatterScript asks a different question.

**Which computations can this token of information cause?**

The compiler follows causal relationships rather than variable lifetimes.

Every token has a set of possible destinations.

Every destination may activate additional computations.

The program unfolds as information propagates through an already established network of relationships.

---

This perspective reaches far beyond digital logic.

A token may represent a Boolean value.

It may represent a packet moving across a network.

It may represent a molecule participating in a chemical reaction.

It may represent heat flowing through a solid, water moving through a watershed, or a financial transaction moving through an economy.

The underlying computational model does not change.

Only the meaning of the information changes.

MatterScript is therefore not built around variables.

**It is built around the movement of information itself.**

---

This is one of the most important conceptual shifts in the language.

A variable describes a place where information might exist.

A token **is** the information.

Once that distinction becomes natural, the rest of MatterScript begins to fall into place.

Programs are no longer collections of mutable variables manipulated by sequential instructions.

They become networks through which information propagates, transforms, combines, and occasionally comes to rest, waiting for the next cause to set the computation in motion once again.

*Drafting in progress...*
