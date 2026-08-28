# Sequential Programs Are Special Cases

One of the oldest assumptions in computer science is so deeply embedded that most programmers never question it.

Programs execute one instruction after another.

If we wish to perform two things at once, we begin with sequential execution and then add mechanisms for concurrency.

Threads.

Processes.

Locks.

Queues.

Message passing.

Actors.

Coroutines.

Async runtimes.

From this perspective, concurrency appears to be an advanced feature layered on top of a fundamentally sequential world.

MatterScript begins from the opposite assumption.

**Concurrency is the natural state of computation.**

Sequential execution is simply one particular arrangement of causal relationships.

---

At first this sounds backwards.

Surely one thing at a time must be simpler than many things happening simultaneously.

After all, a sequential program has only one execution path.

A concurrent system may have thousands.

How could concurrency possibly be the simpler model?

The answer lies in a subtle confusion that has followed computer science since its mathematical beginnings.

---

When mathematicians describe an algorithm, they describe a sequence of symbolic transformations.

One step follows another.

The ordering itself is part of the definition.

That model is perfectly suited to proving theorems.

It is far less suited to describing physical systems.

The physical universe does not execute one event at a time.

Stars form while rivers flow.

Trees grow while clouds move.

Your heart beats while neurons fire.

Reality has never contained a program counter.

It contains countless independent processes interacting through local causal relationships.

Nature is concurrent by default.

---

The same is true inside every computer.

Billions of transistors switch simultaneously.

Signals propagate continuously through wires.

Memory arrays, caches, buses, and functional units all operate concurrently.

The familiar illusion of sequential execution exists because the hardware carefully coordinates these activities so they appear to produce one ordered stream of instructions.

Sequential software is therefore not the absence of concurrency.

It is a particular organization of concurrency.

---

This distinction becomes clearer when we consider a simple example.

Imagine two independent computations.

```text
Measure temperature.

Update the display.
```

Nothing about these activities requires one to happen before the other.

They may proceed simultaneously.

Now imagine introducing a new requirement.

```text
Measure temperature.

Only after the measurement completes,

update the display.
```

We have not changed the computations themselves.

We have merely introduced a causal relationship.

One event must now wait for another.

Sequentiality has emerged naturally from an additional constraint.

---

This observation generalizes remarkably well.

Every sequential program can be viewed as a network in which each computation depends upon the completion of the previous one.

```text
A → B → C → D → E
```

Nothing mysterious has happened.

We have simply constructed the narrowest possible causal graph.

Every node has exactly one predecessor and one successor.

It is still a propagation network.

It simply contains no independent branches.

Sequential execution is therefore a special case of concurrent computation whose dependency graph happens to collapse into a single chain.

---

Seen from this perspective, many of the traditional difficulties of concurrency begin to look different.

Programmers often speak of race conditions, deadlocks, livelocks, and nondeterminism as though they are unavoidable consequences of allowing multiple computations to occur simultaneously.

In reality, these problems arise because we have described **insufficient causal relationships**.

If two computations may produce different outcomes depending upon which one happens first, then the computation has failed to specify what must happen before what.

The ambiguity is not in the hardware.

It is in the description.

---

MatterScript eliminates much of this uncertainty by making causality explicit.

Names establish relationships.

Tokens propagate only when computations are complete.

Events occur because their causes have been satisfied.

The compiler constructs a network whose dependencies are already known before execution begins.

There is no need to recover ordering through locks, polling, or carefully timed delays.

The ordering already exists wherever it is logically necessary.

Everywhere else, the computation proceeds independently.

---

This dramatically changes the way we think about parallelism.

In conventional software, programmers often begin with a sequential algorithm and then search for opportunities to parallelize it.

MatterScript reverses the process.

The programmer describes the causal structure of the problem.

The compiler discovers which portions are inherently independent.

Parallelism is no longer something added to a sequential program.

It is simply the natural consequence of relationships that do not depend upon one another.

---

This is exactly how the physical world behaves.

A chemical reaction does not pause while another reaction occurs elsewhere in the solution.

A neuron does not wait for every neuron in the brain before producing a signal.

A weather system does not compute one cloud at a time.

Independent events proceed independently.

Only genuine causal relationships impose ordering.

MatterScript expresses computation in precisely the same way.

---

Perhaps the greatest misconception surrounding concurrency is the belief that it is inherently nondeterministic.

What is actually nondeterministic is **an incompletely specified system**.

When the necessary causal relationships are absent, multiple orderings become possible, and different orderings may produce different results.

The solution is not to force everything into a single sequential stream.

The solution is to describe the missing relationships.

Once those relationships exist, the computation becomes deterministic regardless of the relative speeds of its individual parts.

The hardware is free to propagate information as quickly or as slowly as physics allows.

The outcome remains the same because causality—not timing—determines the result.

---

This is one of the central ideas behind MatterScript.

Programs are not fundamentally sequences of instructions.

They are networks of causes and effects.

Some portions of those networks naturally execute one after another.

Others naturally proceed simultaneously.

Neither behavior is privileged.

Both emerge from exactly the same language.

Sequentiality is no longer the primitive from which concurrency must be constructed.

It is simply one possible shape that a causal network may take.

---

For decades we have taught programmers to begin with sequence and cautiously introduce parallelism where it appears safe.

MatterScript invites us to reverse that perspective.

Begin with the relationships.

Allow every independent computation to exist independently.

Introduce ordering only where the problem itself requires it.

Seen this way, sequential programs are not the foundation of computation.

They are its simplest special case.

*Drafting in progress...*
