# Completeness and Tokens

Earlier we introduced the idea that MatterScript does not manipulate variables.

It propagates **tokens**.

At first glance, a token may appear to be nothing more than a value moving through a computational network.

In reality, it is much more than that.

A token represents a **complete assertion**.

This idea lies at the heart of MatterScript's computational model.

---

Most programming languages allow information to exist in partially completed states.

Consider a simple data structure.

```cpp
struct Person {
    string firstName;
    string lastName;
    int age;
};
```

At any moment during execution, one field may have been initialized while the others remain empty.

The object exists.

But is the information complete?

Can another computation safely depend upon it?

Software spends enormous amounts of effort answering these questions.

Constructors establish initialization.

Flags indicate readiness.

Validation routines verify consistency.

Optional fields express uncertainty.

Throughout the software stack we repeatedly ask the same question:

**Can this information be trusted yet?**

---

MatterScript approaches the problem differently.

Information does not propagate simply because part of it has arrived.

It propagates only when it is complete.

Consider a simple invocation.

```matterscript
ADD($A $B)(SUM<>)
```

Suppose the value for `$A` arrives first.

Nothing happens.

The computation waits.

When the value for `$B` arrives, the situation changes.

Now every required input has been presented.

The invocation resolves.

A new token emerges.

That token is itself complete.

Completeness propagates through the network just as naturally as the values themselves.

---

This is precisely the idea embodied by the **completeness criterion** introduced in the previous chapter.

A computation does not begin because one input changed.

It begins because every required cause has been satisfied.

Likewise, a downstream computation does not need to ask whether its inputs are ready.

The arrival of a token already answers that question.

Validity is no longer reconstructed in software.

It is carried by the computation itself.

---

This changes what we mean by the word *token*.

A token is not simply a bit.

It is not merely a collection of bits.

It is not even just a value.

A token is a **complete causal assertion**.

It represents information whose originating computation has fully resolved.

When a token propagates, it carries two inseparable pieces of knowledge.

The value itself.

And the fact that the value is complete.

---

Engineers already rely on this idea in many other domains.

A network packet is not useful because it contains bytes.

It is useful because the receiver knows where the packet begins, where it ends, and whether it arrived intact.

A partially received packet is not treated as valid information.

It waits until the transmission is complete.

Only then does it become meaningful.

MatterScript extends this same principle beyond communication.

Every computation operates on complete information rather than fragments of an unfinished process.

---

The physical world behaves in much the same way.

A neuron does not fire because a single sodium ion crossed its membrane.

It fires when the membrane reaches a threshold.

A chemical reaction does not occur because one reactant has appeared.

It occurs when the necessary reactants are simultaneously present.

A seed does not become a tree because one condition has changed.

Growth begins when countless local conditions together make development possible.

Nature waits for completeness.

MatterScript does as well.

---

This has profound implications for causality.

Incomplete information cannot trigger downstream computation.

It cannot become the cause of another event because the conditions that produced it have not yet been satisfied.

Only complete tokens propagate.

Only complete tokens participate in the next causal relationship.

The compiler therefore gains an extraordinarily powerful guarantee.

Every propagation event represents a completed computation.

Every downstream computation begins with information that is already known to be valid.

---

Viewed from this perspective, conventional software and MatterScript describe very different worlds.

Traditional software propagates values.

MatterScript propagates completed facts.

Not simply,

*"The temperature is 37 degrees."*

But,

*"The temperature has been measured."*

Not merely,

*"Collision equals true."*

But,

*"A collision has occurred."*

Not simply,

*"The account balance is 120 dollars."*

But,

*"The account has been reconciled."*

The distinction may seem subtle.

It is not.

The first describes data.

The second describes completed events.

MatterScript is fundamentally a language of completed events propagating through a causal network.

---

This perspective also explains why MatterScript scales so naturally.

Every token represents the completion of one causal chain and the beginning of another.

Large computations therefore become compositions of complete assertions rather than collections of partially updated state.

There is no need for downstream computations to guess whether upstream work has finished.

The token itself provides that guarantee.

Synchronization is not layered on top of the computation.

It is inherent in the computation.

---

Information is valuable only when it can be trusted.

A token therefore represents more than a value.

It represents the completion of whatever process produced that value.

Every token is both **data** and **evidence** that the computation which created it has finished.

That simple observation changes the role of programming itself.

Programs are no longer systems that continually verify whether information is ready.

They become networks through which completed knowledge naturally propagates from one resolved computation to the next.

In MatterScript, information does not become complete because the programmer declares it to be complete.

It becomes complete because the computational fabric itself recognizes that every cause required to produce it has been satisfied.

*Drafting in progress...*
