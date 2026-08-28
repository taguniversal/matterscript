# Events Instead of Execution

For more than seventy years, programming languages have encouraged us to think of computation as the execution of instructions.

Fetch the next instruction.

Decode it.

Execute it.

Advance the program counter.

Repeat.

Whether the processor executes one instruction at a time or billions of them in parallel, the underlying question remains the same:

**What instruction should execute next?**

MatterScript asks a fundamentally different question.

**What new information has arrived?**

That single change in perspective transforms the entire model of computation.

---

Consider a familiar fragment of conventional software.

```c
if(sensor > threshold)
    alarm = 1;
```

It appears straightforward.

Yet hidden beneath this simple statement is an assumption that has shaped almost every programming language ever created.

The processor must continually execute code to discover whether anything has changed.

Read the sensor.

Compare it with the threshold.

Nothing changed.

Read it again.

Compare it again.

Still nothing.

Repeat millions of times every second.

The machine spends much of its life asking the same question over and over:

*"Has anything happened yet?"*

---

Now consider the same relationship expressed in MatterScript.

```matterscript
GREATER($sensor $threshold)(TRIGGER<>)

ALARM($TRIGGER)(SIREN<>)
```

Notice what is missing.

There is no loop.

There is no scheduler.

There is no polling.

Nothing executes simply because time has passed.

The network remains completely still until new information arrives.

When the sensor changes, the comparison resolves.

A token propagates to `TRIGGER`.

That propagation immediately becomes the cause for the next computation.

`ALARM` resolves.

A new token propagates to `SIREN`.

The event itself initiates the computation.

There was never an instruction repeatedly checking whether it should begin.

---

This way of thinking is much closer to the behavior of the physical world.

Nature does not poll.

A neuron does not repeatedly ask whether one of its neighbors has fired.

The electrical impulse arrives.

The membrane responds.

A new impulse propagates.

A chemical reaction does not continually check whether another molecule has entered the solution.

The molecules collide.

The reaction occurs.

The products continue propagating through the system.

A tree does not wake up every millisecond to ask whether spring has arrived.

Temperature changes.

Hormones propagate.

Growth begins.

Across physics, chemistry, and biology, systems respond to events.

They do not spend their existence searching for them.

---

MatterScript adopts this same model.

Computation occurs because something happened.

Not because a processor reached the next instruction.

Every propagation event may enable additional computations.

Those computations produce additional events.

Those events continue propagating through the network.

The program unfolds naturally through chains of cause and effect.

Execution becomes the visible consequence of propagation.

---

This idea builds directly upon one of MatterScript's central principles.

Earlier we saw that names define more than connectivity.

They define causality.

Every connection identifies not only where information can flow, but **what can cause something else to happen**.

Once the compiler has constructed this causal network, it already knows every possible propagation path before the program ever begins.

When an event occurs, the compiler does not need to search for work.

It already knows which computations are affected.

The event simply activates a portion of the network that already exists.

---

The consequences become dramatic as systems grow larger.

Imagine simulating ten billion interacting particles.

A conventional simulation often proceeds by examining every particle during every timestep.

Has anything changed?

Should this particle move?

Has this molecule reacted?

Has this cell divided?

Most of the computational effort is spent discovering where the next interesting event might occur.

MatterScript approaches the problem differently.

If a collision occurs, only the particles involved become active.

If a chemical reaction occurs, only the neighboring molecules affected by that reaction continue propagating information.

If a neuron fires, only the neurons connected to it become candidates for further computation.

Everything else remains exactly as it was.

The computation follows the causal structure of the system rather than repeatedly searching for places where computation might be needed.

---

This idea extends far beyond scientific simulation.

A financial transaction affects only the accounts connected to it.

A traffic accident affects only the roads connected to it.

A power outage affects only the portions of the electrical grid connected to it.

A disease spreads only through existing patterns of contact.

The world itself is organized as networks of local events producing local consequences.

MatterScript simply gives us a language capable of expressing those same relationships directly.

---

There is another consequence of this model that is easy to overlook.

When nothing changes, nothing happens.

The computational fabric remains in equilibrium.

Information continues to exist.

Stable states continue to exist.

The causal relationships continue to exist.

But no unnecessary computation occurs simply to verify that the world is unchanged.

The possibility of computation is always present.

Actual computation occurs only because an event has made it necessary.

---

This represents one of the deepest differences between MatterScript and conventional programming.

Traditional software spends much of its time asking whether anything has changed.

MatterScript already knows what **can** change.

The causal relationships were established when the program was compiled.

The geometry was established when the computational fabric was constructed.

The placement already embodies knowledge about the problem.

Events simply reveal which portion of that latent structure should become active next.

---

The result is a model of computation that feels remarkably familiar once we recognize it.

It is the model used by electrical circuits.

By chemical reactions.

By ecosystems.

By weather systems.

By living cells.

By the physical universe itself.

Computation is no longer a sequence of instructions advancing through memory.

It is a sequence of events propagating through a connected world.

MatterScript does not invent this model.

It simply allows software to participate in it.


*Drafting in progress...*
