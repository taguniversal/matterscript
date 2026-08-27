# Why Clocks Are Artificial

We tend to think of time as one of the most fundamental things in computing.

Every processor has a clock. Every operating system has a clock. Every programming language has some way to ask what time it is, wait for a period of time, schedule something for later, or measure how long an operation took.

It seems almost impossible to imagine computation without clocks.

But there is something strange about this picture.

A clock is not time.

A clock is a machine that imposes an ordering on physical events and gives us a convenient way to count them.

That distinction matters.

The conventional computer was built around the assumption that computation must happen in discrete steps, and that those steps must be coordinated by a common external metronome. The clock ticks. Logic changes state. The clock ticks again. Logic changes state again.

This arrangement is extraordinarily useful. It is also an abstraction.

The physical world does not actually operate this way.

There is no universal clock ticking inside the universe, telling every atom, transistor, electron, and photon when it is permitted to change state. Physical events occur because physical conditions change. A wave propagates. A molecule collides. A transistor switches. A signal arrives. A system becomes stable. Another system responds.

The clock is something we introduced to make the behavior of machines easier to organize.

MatterScript asks a different question:

**What if time did not have to be imposed on computation from the outside?**

## The clock as a computational crutch

The conventional processor is fundamentally clock-centric.

A typical program is conceived as a sequence:

```text
fetch
→ decode
→ execute
→ store
→ wait
→ repeat
```

The clock provides the cadence that keeps everything moving.

This gives us an extraordinarily simple mental model. At one instant, the machine has one state. At the next clock cycle, it has another.

But this simplicity comes at a price.

The clock must run fast enough for the slowest operation that needs to complete within a cycle. Logic that could have completed much earlier must wait. Logic that could operate independently is often forced into a common rhythm. Increasing performance frequently means increasing clock frequency, adding pipelines, adding synchronization machinery, adding prediction, or adding increasingly sophisticated mechanisms for working around the limitations of the global clock.

The clock solves the coordination problem by making everything agree to move together.

That is not the only possible solution.

**Null Convention Logic** begins from almost the opposite premise.

Instead of asking:

> What time is it?

it asks:

> Has the information required for this operation arrived?

That is a profound difference.

## Time can emerge from information

In Null Convention Logic, a computational element does not necessarily need a clock to tell it when its inputs are valid.

The system can distinguish between **DATA** and **NULL**.

A collection of signals reaches a valid DATA state. The logic responds. The resulting information propagates forward. Eventually the system returns to NULL, making the computational fabric ready for the next wave of information.

The computation therefore has a temporal character without requiring an external clock to impose that temporal sequence.

The information itself moves.

The state transition itself creates the ordering.

A new symbol arriving behind an existing symbol can displace it. DATA becomes NULL. NULL becomes DATA. The transitions propagate through the geometry of the circuit.

What emerges is a **wavefront**.

And a wavefront is a temporal phenomenon without requiring a clock in the conventional sense.

Consider the difference.

A conventional digital system might say:

```text
clock 1 → compute
clock 2 → compute
clock 3 → compute
clock 4 → compute
```

An NCL system can instead behave more like:

```text
symbol → symbol → symbol → symbol
       →        →        →
    propagation through space
```

The temporal ordering is carried by the movement of information through the fabric.

This is important because it reconnects computation with physical reality.

The circuit has geometry.

The signals have position.

Propagation has duration.

Causality has direction.

Time is no longer merely a number attached to an event. It is part of the behavior of the physical system.

## From clocks to wavefronts

This suggests that there are at least two fundamentally different ways to understand computational time.

The first is **imposed time**.

A clock says:

> You may change state now.

The second is **emergent time**.

The physical state of the system says:

> The conditions required for this transition now exist.

The distinction is easy to overlook because conventional digital computers have made clocked computation so familiar that we mistake the implementation technique for a fundamental law.

It isn't.

A clock is one way of coordinating events.

It is not the definition of computation.

MatterScript is therefore interested in a richer temporal vocabulary.

A programmer should eventually be able to describe relationships such as:

```text
when this arrives
when this becomes valid
after this transition
when this wave reaches here
at this digital time
at this physical time
```

These statements describe temporal relationships without necessarily prescribing the mechanism by which those relationships are achieved.

That mechanism might be an operating-system scheduler.

It might be a hardware timer.

It might be an interrupt.

It might be propagation through an NCL circuit.

Or it might be something that conventional software has never had a convenient way to express at all.

## Digital time

This is where MatterScript's digital blockchain technology introduces another possibility.

MKRAND produces a deterministic sequence of 128-bit digital blocks.

A block might look like:

```text
[<:d9ca177b669ab95b6fef270657dff32c:>]
```

The important property is not simply that the value is large or apparently random.

It is that the sequence is **ordered and reproducible**.

If we have:

```text
B₀
B₁
B₂
B₃
B₄
...
```

then `B₄` is not merely an arbitrary value that happens to occur after `B₃`.

It is a specific, addressable point in the sequence.

This gives us something unusual:

**time can have an address.**

A MatterScript program can conceptually refer to a future temporal state rather than merely waiting for an elapsed duration.

If the current block is `B`, the programmer can ask for:

```text
B + 5
```

The MKRAND subsystem can deterministically generate the intervening blocks and identify the fifth subsequent state.

Hardware can then be configured to respond when that state occurs.

No polling is required.

No process has to repeatedly ask whether the time has arrived.

The hardware can simply wait for the digital condition corresponding to that temporal coordinate.

This is a fundamentally different abstraction from:

```text
sleep(5)
```

A sleep operation says:

> Stop doing things for some approximate duration.

A digital temporal reference says:

> This event belongs to this specific position in an ordered sequence of time.

That distinction becomes particularly important when computation is distributed.

## Time without a central clock

Imagine two pieces of hardware separated by a large physical distance.

They each possess the same deterministic temporal sequence.

Neither needs to continuously ask the other:

> Where are you in time?

Both can independently derive the same future temporal state.

If both are programmed to respond to `B₁₀₀₀`, then both know what event they are waiting for.

They do not have to share the event itself.

They share its **coordinate in digital time**.

This does not make physical simultaneity magically perfect. Real oscillators drift. Propagation takes time. Components have tolerances. Temperature changes physical behavior.

But it does provide something extremely valuable:

**a common, deterministic ordering of events.**

The distinction is important.

Digital time can provide exact ordering even when physical time can only be synchronized within the accuracy of the underlying physical timebase.

That gives distributed hardware a new kind of temporal reference.

Instead of continually synchronizing clocks, systems can synchronize around a deterministic sequence of digital states.

The blockchain, in this sense, is not merely a ledger.

It becomes a **coordinate system for computation through time**.

## Connecting digital time to physical time

Of course, computers ultimately inhabit the physical universe.

A digital sequence has to correspond to something physical if we want to use it to trigger real events.

This is where the relationship between MKRAND and a crystal oscillator becomes important.

If the hardware can establish, with sufficient accuracy, how many clock cycles are required to generate or advance through a block, then the digital sequence can be associated with a physical timebase.

We can establish a relationship between:

```text
MKRAND block
      ↓
hardware cycles
      ↓
crystal oscillator
      ↓
physical time
      ↓
wall-clock time
```

Now the digital coordinate does not exist in isolation.

It is anchored to physics.

The result is a hierarchy of time rather than a single notion of time.

At the highest level, a MatterScript programmer might care about wall-clock time:

> Tuesday at 14:30.

At another level, the program may care about physical time:

> 17.25 microseconds from the reference event.

At another level, they may care about digital time:

> block B₁₂₃₄₅.

And at the lowest level, they may care about a physical propagation event:

> when the wavefront reaches this gate.

These are not competing definitions of time.

They are different representations of temporal relationships at different levels of the machine.

## Time becomes a first-class domain

This is where MatterScript begins to depart most clearly from conventional programming languages.

Traditional programming languages tend to expose time through functions.

You call a function to get the current time.

You call another function to sleep.

You register a callback.

You configure a timer.

You wait for an interrupt.

Time exists outside the language, and the language provides mechanisms for asking the operating system or hardware about it.

MatterScript can treat time differently.

Time can become a **domain of computation**.

The programmer describes a temporal relationship, and the system determines how that relationship can be realized by the underlying physical substrate.

At one level:

```text
at 14:30:
    activate pump
```

At another:

```text
after 500 microseconds:
    trigger sensor
```

At another:

```text
at B + 5:
    emit signal
```

And at another:

```text
when wavefront reaches node:
    transform symbol
```

These statements appear superficially similar.

But they represent very different temporal mechanisms.

The first may require an operating-system service.

The second may use a hardware timer or interrupt.

The third may use the MKRAND temporal sequence.

The fourth may require no clock at all.

The language should not force the programmer to pretend that these are all the same thing.

They aren't.

## Space and time return together

There is a deeper connection here to geometry.

When software forgot geometry, it also forgot something about time.

Conventional software treats computation as an abstract sequence of instructions. The instructions have an order, but they have little inherent spatial meaning. Memory is an address. A processor is a generic execution engine. A program is a sequence.

MatterScript begins with a different premise.

A computation can occupy space.

Signals can have position.

Logic can have topology.

Information can propagate.

And once computation has physical extent, time becomes inseparable from that geometry.

A signal arriving at one gate before another gate is not merely a difference between two timestamps.

It is a physical relationship.

The distance, topology, propagation characteristics, and state of the computational fabric all participate in determining what happens next.

This is why geometry and time belong together in MatterScript.

Space describes **where** computation exists.

Time describes **when relationships propagate through it**.

The conventional computer separated these concepts so thoroughly that we came to think of them as separate abstractions.

Physical computation never did.

## The machine that inhabits time

The ultimate goal is not to eliminate clocks.

Clocks remain useful. They provide a stable reference. They allow us to measure physical processes and coordinate systems when that is the appropriate mechanism.

The mistake is treating the clock as the only meaningful representation of computational time.

MatterScript can have clocks without being imprisoned by them.

It can use an operating-system clock when wall time matters.

It can use a crystal oscillator when physical precision matters.

It can use hardware interrupts when deterministic triggering matters.

It can use MKRAND when a reproducible digital temporal coordinate matters.

And it can use NCL propagation when the computation itself can provide its own temporal ordering.

These mechanisms do not have to compete.

They can form a hierarchy.

The programmer can describe relationships.

The compiler and hardware can choose the appropriate temporal substrate.

That is the larger idea.

A conventional program executes **according to a clock**.

A MatterScript system can execute **according to relationships in space and time**.

The difference may sound subtle.

It isn't.

Once time becomes something that computation can represent, address, propagate, synchronize, and inhabit—not merely something it can measure—the boundary between software and physical process begins to disappear.

And that is precisely where MatterScript wants to operate.

*Drafting in progress...*
