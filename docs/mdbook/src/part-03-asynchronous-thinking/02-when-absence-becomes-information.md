# When Absence Becomes Information

Every programmer has encountered some version of the same problem.

A value hasn't arrived yet.

A pointer hasn't been initialized.

A message is still in transit.

A thread must wait for another thread to finish.

A computation cannot continue because the required information does not yet exist.

Entire programming languages and software frameworks have been built around solving this problem.

Null pointer checks.

Optional types.

`Maybe<T>`.

`Option<T>`.

Promises.

Futures.

Queues.

Mutexes.

Semaphores.

Condition variables.

Reactive streams.

Although they appear very different, they all answer the same fundamental question:

**Is there valid information here yet?**

For decades, we have treated this as a software problem.

It isn't.

It is a hardware problem that software has spent half a century compensating for.

---

Traditional digital logic understands only two values.

Zero.

One.

A logic gate cannot distinguish between a valid piece of information and the absence of information.

It simply responds whenever its inputs change.

As a result, conventional digital systems require an external mechanism to decide when a computation has finished.

That mechanism is usually a clock.

The clock does not know whether every computation has completed.

It merely assumes that enough time has passed.

Every clock cycle is, in effect, an educated guess that the data has arrived.

---

Karl Fant's **NULL Convention Logic (NCL)** begins with a remarkably simple observation.

What if a logic gate could recognize not only the value being presented to it, but whether valid information had been presented at all?

Instead of two logical states, the computational fabric now recognizes three conditions.

True.

False.

And **NULL**.

NULL does not mean zero.

It does not mean false.

It does not represent an error.

It means something much more fundamental.

**There is presently no valid information here.**

That single distinction changes the behavior of the entire computational system.

---

Rather than relying on a clock, every gate now recognizes the boundaries between valid data and the absence of data.

Computation proceeds as alternating wavefronts.

A wave of valid information propagates through the network.

When every participating gate has completed its computation, a wave of NULL propagates behind it, returning the network to a neutral state and preparing it for the next computation.

The network breathes.

**NULL → DATA → NULL → DATA**

Each wavefront communicates not only values, but the state of the computation itself.

Synchronization is no longer imposed from outside the circuit.

It emerges naturally from the propagation of information.

---

This behavior is captured by what Fant called the **completeness criterion**.

A gate no longer reacts simply because one of its inputs changes.

Instead, it waits.

If all of its inputs contain valid data, the gate resolves its logical function and produces valid data at its output.

If all of its inputs have returned to NULL, the gate returns its output to NULL.

If neither condition has been satisfied, the gate does nothing.

Its current output is preserved through a small amount of hysteresis, or state-holding behavior, until the computation is genuinely complete.

The gate itself understands readiness.

It knows when to compute.

It knows when to wait.

No scheduler is required.

No polling loop is required.

No speculative execution is required.

The hardware already possesses the information needed to make the correct decision.

---

This is a profound departure from conventional Boolean logic.

Traditional logic gates are purely mathematical functions.

Given a set of inputs, they immediately produce an output.

NULL Convention Logic transforms them into participants in a larger computational conversation.

Every gate now understands not only **what** information it has received, but **whether** the information is complete.

Validity becomes part of the computation itself.

---

Viewed from this perspective, many familiar software abstractions begin to look surprisingly similar.

A mutex tells another thread that information is not yet available.

A queue tells a consumer that new information has arrived.

A future represents information that will exist later.

An `Option<T>` distinguishes between the existence and nonexistence of a value.

A `Maybe<T>` expresses the same idea.

Even the infamous null pointer exception exists because software attempted to use information that was never actually present.

These mechanisms are extraordinarily useful.

But they all compensate for the same missing capability.

The hardware itself cannot naturally express the difference between **valid information** and **no information**.

Software has spent decades rebuilding that distinction one abstraction at a time.

---

MatterScript fits naturally into this model.

Throughout this book we have described computation as the propagation of information.

We have replaced variables with tokens.

Instructions with events.

Connectivity with causality.

NULL Convention Logic contributes the final ingredient.

**Validity.**

A propagating token no longer carries only a value.

It also carries the knowledge that it exists.

Every computation knows when its inputs are complete.

Every downstream computation knows when it may begin.

Propagation becomes self-synchronizing.

The computational fabric no longer needs an external heartbeat to coordinate its behavior.

The information coordinates itself.

---

This idea also sheds new light on a concept we introduced earlier.

**Information at rest is still part of the computation.**

A gate holding valid data is not idle.

It is preserving the resolved state of a completed computation, ready to participate in whatever causal event comes next.

Likewise, a gate holding NULL is not empty.

It is communicating something equally important.

The previous computation has completed.

No valid information is presently available.

The network is ready for the next propagation.

Even absence has meaning.

---

This chapter began with a question that software has been asking for generations:

**Is there valid information here yet?**

NULL Convention Logic answers that question where it belongs.

In the computational fabric itself.

Once the hardware understands the difference between information and the absence of information, software no longer has to spend its life reconstructing that knowledge.

NULL is no longer merely the absence of a value.

It is information.

It tells the computational universe that one propagation has ended, another has not yet begun, and the fabric is prepared for whatever causal event arrives next.

In MatterScript, that idea completes a philosophy that has been building throughout this book.

Geometry carries information.

Placement carries information.

Causality carries information.

Tokens carry information.

And now we discover that **even the absence of a token carries information.**

Once every part of the computational fabric is allowed to express what it knows, computation begins to resemble something much closer to the physical universe itself—not a machine blindly executing instructions, but a connected world whose own structure tells it exactly when to act, and exactly when to wait.

*Drafting in progress...*
