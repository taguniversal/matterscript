# The Runtime Boundary

One of the central ideas behind MatterScript is that a program should describe **what** a computation is, not **how** it executes.

Most programming languages blur these two concerns together. The language describes the computation, but it also implicitly assumes a particular execution environment: a processor with an instruction pointer, a stack, a heap, and a runtime responsible for coordinating them all.

MatterScript makes a different distinction.

The language ends where the relationships have been fully described.

Everything beyond that point belongs to the compiler.

---

## Programs Describe Relationships

When you write a MatterScript definition, you are not writing instructions for a processor.

You are describing a network of causal relationships.

```matterscript
FULLADD($A $B $C)(SUM<> CARRY<>)
```

The definition says nothing about clocks.

Nothing about memory.

Nothing about registers.

Nothing about threads.

Nothing about instruction order.

It simply declares that when the appropriate information arrives, these relationships exist.

That description is complete in itself.

---

## From Source to Association Graph

The compiler's first responsibility is not to generate machine code.

It is to recover the computational fabric described by the program.

Conceptually, every MatterScript program is transformed into an **association graph**.

```text
MatterScript Source
        │
        ▼
Association Graph
```

This graph contains every place, every invocation, every correspondence relationship, and every causal dependency expressed by the source.

At this point the computation has already been defined.

Nothing about processors or hardware has entered the picture.

The graph is simply a faithful representation of the relationships described by the programmer.

---

## The Runtime Boundary

The association graph forms the boundary between the language and its implementation.

Everything above this boundary belongs to MatterScript.

Everything below it belongs to the compiler.

```text
MatterScript Source
        │
        ▼
Association Graph
        │
────────┼────────  Runtime Boundary
        │
        ▼
Backend Mapping
        │
 ┌──────┼──────────────┐
 ▼      ▼              ▼
FPGA   POSIX         GPU
VHDL   C/Pthreads    CUDA
```

The language never specifies how those relationships should be realized.

That decision belongs entirely to the backend.

---

## One Program, Many Realizations

This separation allows the same MatterScript program to target radically different computational substrates.

One backend may generate VHDL, mapping every relationship onto lookup tables, routing resources, and asynchronous logic.

Another may generate a POSIX application, where independent regions of the graph execute as cooperating threads.

A GPU backend may map repeated structures onto thousands of parallel execution units.

Future backends might target custom ASICs, distributed systems, neuromorphic hardware, or architectures that have not yet been invented.

The program itself does not change.

Only its realization changes.

---

## The Runtime Is an Implementation Detail

Traditional software is usually thought of in three layers:

```text
Program
    │
    ▼
Runtime
    │
    ▼
Hardware
```

The runtime is responsible for scheduling execution, managing memory, coordinating threads, and providing operating-system services.

MatterScript shifts that boundary.

```text
Program
    │
    ▼
Association Graph
    │
    ▼
Physical Realization
```

There is no mandatory runtime.

There is no required virtual machine.

No required scheduler.

No required heap.

No required stack.

A particular backend may choose to implement some or all of these mechanisms, but they are no longer properties of the language itself.

They are engineering decisions made during realization.

---

## Computation Becomes Portable

This separation has another consequence that is unlike anything possible in traditional software.

Today's computers routinely transmit data across networks.

Sometimes they transmit executable programs.

But those programs are still written for a particular processor architecture and operating system. They assume the receiving machine will execute instructions using its own runtime.

MatterScript can transmit something much more fundamental.

**It can transmit the computation itself.**

Imagine a running MatterScript system that constructs a new computational network dynamically—a signal-processing pipeline, a robotic controller, a physics simulation, or a specialized accelerator. That generated network is simply another MatterScript description. It can be handed to the local backend for synthesis, becoming dedicated hardware inside an FPGA.

Or it can be sent across the network to an entirely different machine.

That receiving machine might have different processors.

Different memory.

Different accelerators.

Different hardware capabilities.

It compiles the received MatterScript into a realization appropriate for its own architecture while preserving exactly the same causal relationships.

In effect, the computation has moved without carrying any assumptions about the machine on which it will execute.

One computer has transmitted part of itself to another.

Not merely its data.

Not merely its executable binary.

Its computational structure.

It is, in a very real sense, **the teleportation of machinery**.

---

## Preserving the Relationships

The compiler's job is not simply to translate syntax.

Its responsibility is to preserve the causal structure expressed by the program.

Whether that structure becomes a network of FPGA logic cells, a collection of POSIX threads, or a GPU kernel, the observable behavior must remain identical.

Only the implementation strategy changes.

The relationships do not.

This is the same principle that has guided the language from the beginning.

MatterScript describes causality.

The compiler determines how that causality is embodied in a physical system.

---

## A Language Independent of Its Machine

Perhaps the most significant consequence of the runtime boundary is philosophical rather than technical.

For decades, programming languages have largely been descriptions of how to drive a processor.

MatterScript is instead a description of a computation itself.

The processor is no longer the center of the programming model.

It is merely one possible realization of a deeper computational structure.

That distinction opens possibilities that have scarcely existed before. Computational structures can be generated, evolved, synthesized into hardware, or transmitted to entirely different machines for realization. Computation becomes something that can inhabit whatever physical substrate is available without changing its identity.

The language ends when the relationships have been described.

Everything beyond that point is an implementation choice.
