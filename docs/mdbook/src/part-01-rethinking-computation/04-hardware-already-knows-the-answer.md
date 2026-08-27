# Hardware Already Knows the Answer

For decades, software has been built upon abstractions that deliberately erase the physical world.

Variables have no location.

Functions occupy no physical space.

Messages travel as though distance does not exist.

Memory appears equally close to every computation.

These assumptions have served us remarkably well. They allowed programmers to think in terms of algorithms rather than transistors, making software vastly more portable and productive.

But they have also created a disconnect.

None of these assumptions are actually true inside the machine.

A processor is not a list of instructions.

An FPGA is not a collection of algorithms.

A semiconductor is a physical object.

Every transistor occupies a precise location.

Every wire has measurable length.

Every signal requires finite time to propagate.

Every gate stores energy.

Every computation is constrained by geometry.

The remarkable thing is that hardware engineers have always known this.

They have never had the luxury of pretending that space and time don't matter.

---

Consider the simplest logic gate.

From the perspective of software, an AND gate computes a Boolean function.

```
A AND B → C
```

From the perspective of hardware, something quite different happens.

Electrical signals propagate along conductors.

Charge accumulates on transistors and interconnects.

Threshold voltages are crossed.

The circuit settles into a stable physical state.

That state remains available until new information arrives.

The gate is not continuously "executing" an AND operation.

It simply **exists** in a configuration that represents the correct answer.

This distinction may seem subtle, but it changes how we think about computation.

Software encourages us to imagine that computation is something a processor **does**.

Hardware reminds us that computation is often something a circuit **is**.

Once the inputs stabilize, the circuit itself embodies the solution. No instruction stream is required to preserve that result. The physical arrangement of transistors, wires, capacitances, and feedback paths already contains the computation.

---

This idea becomes even more striking when we consider asynchronous logic.

A conventional processor repeatedly asks every register in the machine whether it should update on the next clock edge.

An asynchronous circuit asks no such question.

Information simply propagates.

Each stage waits until enough information has arrived to determine its next stable state.

Nothing happens until it can happen.

Nothing happens sooner than physics allows.

The computation unfolds through causality rather than scheduling.

MatterScript embraces this same viewpoint.

A definition does not execute because a program counter reaches it.

It resolves because the required information exists.

Names become complete.

Relationships become satisfied.

Information propagates.

The computation emerges naturally from the network.

---

There is another lesson hardware has been teaching us for years.

**Placement is computation.**

Every FPGA engineer knows that moving two connected logic blocks farther apart increases propagation delay.

Every chip designer knows that wire length limits operating frequency.

Every physical implementation tool spends enormous effort deciding *where* computations should exist because geometry directly influences behavior.

Yet software has traditionally ignored all of this.

A compiler receives an abstract program.

Only after the program is complete does an entirely different class of software attempt to rediscover the geometry hidden within it. Place-and-route tools search for efficient layouts, balancing timing, congestion, power consumption, and routing resources.

The programmer rarely participates in that conversation.

The physical structure of the computation is treated as an optimization problem to be solved after the language has already discarded it.

---

MatterScript proposes that geometry should no longer be an afterthought.

If computation depends on placement, then placement belongs in the language.

If propagation delay affects behavior, then propagation belongs in the language.

If locality determines performance, then locality belongs in the language.

The physical organization of a system is not merely an implementation detail.

It is part of the computation itself.

This is why MatterScript is not simply another hardware description language.

Verilog and VHDL ultimately produce hardware that occupies physical space, but they still encourage programmers to think primarily in terms of signals, processes, and clock cycles. Geometry enters the picture only after synthesis begins.

MatterScript starts one level earlier.

It asks a different question:

> **What if the programmer could describe the geometry itself?**

Not just the logic.

Not just the timing.

The geometry.

---

Perhaps the most important lesson hardware has been teaching us is one that we have largely overlooked.

A modern FPGA contains millions of programmable elements. After configuration, those elements do not merely wait for instructions to execute. Their spatial arrangement, their interconnections, and their stable electrical states collectively embody the computation. As new information arrives, the device responds continuously because its physical structure already represents the solution.

In this sense, a configured FPGA is not simply a computer *running* a program.

It is a physical object whose structure *is* the program.

MatterScript extends this idea one step further.

If we arrange computational elements so that their geometry mirrors the geometry of the physical system being modeled—a heat exchanger, a river, a bridge, a biological tissue, or an entire city—then part of the computation no longer needs to be rediscovered at runtime.

It is already present in the structure of the machine.

The hardware is no longer merely executing a model of reality.

It becomes a computational analogue of that reality.

---

This leads to a perspective that is fundamentally different from conventional software.

When a MatterScript compiler places a computational mesh onto an FPGA, it is doing more than optimizing for timing. It is embedding knowledge about the physical world directly into the computational fabric.

Neighborhood relationships are established before the program begins.

Distances are already encoded.

Communication paths already exist.

Propagation delays already reflect the intended geometry.

The computation does not begin from an empty canvas.

**The placement itself is frozen knowledge.**

Before the first token propagates, before the first sensor reading arrives, before the first physical equation is evaluated, part of the solution already exists. It exists not as data in memory or instructions in a program, but as the physical organization of the machine itself.

Signals are no longer discovering the structure of the problem.

They are moving through a structure that already understands it.

That is the central idea behind MatterScript.

Software should no longer pretend that geometry is somebody else's problem.

For the first time, we have the hardware, the compiler technology, and the language abstractions to treat space and time as first-class programming constructs.

In doing so, we allow software to speak the same physical language that hardware has understood all along.

*Drafting in progress...*
