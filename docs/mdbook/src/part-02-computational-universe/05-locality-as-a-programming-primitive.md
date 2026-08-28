# Locality as a Programming Primitive

One of the deepest assumptions in modern software is that everything is, in principle, equally accessible.

A variable stored in memory can be read from anywhere.

An object may invoke methods on another object across the program.

A database query may retrieve information from anywhere in the world.

The programmer is free to describe relationships without regard for physical distance.

The machine worries about locality later.

Caches are introduced.

Memory hierarchies are optimized.

Distributed systems attempt to recover proximity after the fact.

In other words, locality is usually treated as an optimization.

MatterScript begins from the opposite assumption.

**Locality is not an optimization. It is a programming primitive.**

---

This idea has its roots in Karl Fant's *Computer Science Reconsidered*, where he introduced the concept of the **theng**.

A theng is not simply a variable, nor is it an object in the object-oriented sense.

A variable has identity, but no place.

An object has identity and behavior, but still no inherent physical location.

A **theng** possesses identity, persistence, locality, and relationships.

It exists somewhere.

Its location matters.

Its neighbors matter.

Its interactions arise because of that neighborhood.

Fant described a theng as a persistence whose value may change over time.

Persistence belongs to the theng itself.

Values belong to the moment.

Different thengs become associated because they are sufficiently close for their values to interact.

The asserted values of neighboring thengs form names, and those names invoke value transformation rules.

In this way, behavior emerges naturally from local relationships rather than from globally executed procedures.

---

This distinction is fundamental.

MatterScript does not ask, *"What should this computation do?"*

It first asks,

**"What can this computation interact with?"**

Once locality is established, the possible interactions become known.

Those interactions define causality.

Causality determines propagation.

Propagation produces computation.

The geometry of the system is therefore not merely a representation of the computation.

It is one of its defining components.

---

This perspective appears repeatedly throughout the natural world.

A molecule does not interact with every other molecule in the universe.

It interacts with neighboring molecules.

A neuron communicates only with neurons connected to it.

A tree exchanges water and nutrients with the soil surrounding its roots.

A parcel of air exchanges heat, pressure, moisture, and momentum with the parcels immediately around it.

None of these systems continually search the world for possible interactions.

Their neighborhoods already define what interactions are possible.

The geometry itself constrains the computation.

---

This observation also lies at the heart of *A New Kind of Science*.

One of Stephen Wolfram's central insights is that remarkably complex behavior can emerge from extraordinarily simple local rules.

A cellular automaton does not require a global controller.

Each cell examines only its immediate neighbors.

From those local interactions emerge structures that move, reproduce, stabilize, collide, and evolve.

Complexity arises not because individual rules are complicated, but because simple interactions are repeated across enormous collections of locally connected elements.

MatterScript provides a language capable of expressing this same principle directly.

Local interaction is not simulated on top of an imperative machine.

It is the native computational model.

---

Consider a weather simulation.

Traditional software often stores millions of atmospheric cells in memory.

During every timestep, the program repeatedly determines which neighboring cells exchange heat, pressure, moisture, and momentum.

Even highly optimized implementations spend considerable effort rediscovering relationships that are already implied by the geometry of the atmosphere.

MatterScript approaches the problem differently.

Each atmospheric cell already knows its neighborhood.

Propagation naturally occurs only between adjacent cells.

The simulation no longer spends its time searching for interactions.

It spends its time resolving them.

The same idea applies equally well to fluid dynamics, biological growth, electrical networks, ecosystems, and chemical reactions.

---

Chemistry provides perhaps the clearest example.

Atoms do not continually ask whether another compatible atom exists somewhere in the universe.

They interact with the atoms nearby.

Those local interactions produce molecules.

Those molecules interact with neighboring molecules.

Larger structures emerge from countless local events.

The universe never pauses to solve the global problem.

Global behavior emerges from local interactions.

MatterScript embraces this same philosophy.

Rather than describing an all-knowing program directing every step of the computation, it describes neighborhoods whose local interactions allow larger behavior to emerge naturally.

---

This changes the role of the compiler in a profound way.

The compiler is no longer arranging computations simply to improve performance.

It is constructing **neighborhoods**.

Those neighborhoods define which computations may interact.

Those interactions define causality.

Those causal relationships define propagation.

And propagation gives rise to the computation itself.

The resulting computational fabric mirrors the structure of the system it represents.

Whether that system is a digital circuit, a chemical reactor, a biological organism, or an evolving planetary climate, the underlying principle remains unchanged.

---

This represents another departure from conventional software.

Programming has traditionally been the art of describing behavior.

MatterScript is the art of describing neighborhoods.

Once those neighborhoods exist, behavior is no longer written one instruction at a time.

It emerges through local interactions unfolding across the computational fabric.

In MatterScript, locality is not an implementation detail.

It is the language in which reality writes its algorithms.

*Drafting in progress...*
