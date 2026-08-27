# Time is Not a Clock

Ask a programmer what time is, and they will probably reach for a datatype.

Maybe it is a Unix timestamp. Maybe it is a `DateTime`. Maybe it is a floating-point number representing seconds since some epoch. Maybe it is a string containing a date, a time, and a time zone.

This seems perfectly reasonable.

Until you have to make the software work.

Then time begins to reveal itself as one of the strangest and most treacherous abstractions in all of computing.

We have built an enormous body of software whose job is, in one way or another, to answer questions about time. And the history of computing is littered with the wreckage.

The first great warning was Y2K.

For decades, computer systems commonly represented years using two digits:

```text
1967 → 67
1984 → 84
1999 → 99
```

It saved space. It was convenient. It was perfectly adequate for the immediate problem.

Until the century changed.

What was supposed to happen when:

```text
99 → 00
```

Was that 00 the year 2000?

Or 1900?

Or an invalid value?

The computer did not know.

The computer had never known.

We had simply chosen an encoding and quietly forgotten that we had done so.

The Y2K problem was therefore not really a problem with the year 2000. It was a problem with the assumption that **a particular representation of time could stand in for time itself**.

And Y2K was only the beginning.

### We ran out of bits

Unix gave programmers a wonderfully simple temporal abstraction: count the number of seconds since January 1, 1970.

It is hard to imagine anything more straightforward.

Time becomes a number:

```text
0
1
2
3
4
...
```

Every second, increment it.

But the original Unix convention commonly stored that number in a signed 32-bit integer.

There are only so many values that can fit in 32 bits.

Eventually, the counter reaches:

```text
2147483647
```

At that point, there is nowhere else to go.

On January 19, 2038, at 03:14:07 UTC, the classic 32-bit representation reaches its limit.

The next second produces an overflow.

A date in 2038 can suddenly become a date in 1901.

The problem has acquired a name: **the Year 2038 problem**.

Modern 64-bit systems have largely moved beyond this particular limitation, but the underlying lesson remains.

Y2K was:

> We ran out of digits.

Y2038 is:

> We ran out of bits.

Neither problem was caused by time itself.

We simply built a representation with a finite range and then discovered that the universe was not obligated to stop when the representation ran out.

### We run out of precision

Even when the range is large enough, numbers introduce another problem: precision.

Computers routinely represent time using floating-point numbers.

Suppose an application has a timestamp:

```text
1734567890.123456
```

It may look as though the number describes time with extraordinary precision.

But floating-point representations do not provide arbitrary precision merely because we write many digits.

As numbers become larger, the spacing between representable values changes. Eventually, sufficiently small differences can no longer be represented.

Now a programmer who wants to ask:

```text
if (time >= target)
```

may be relying simultaneously on:

* the precision of the numerical representation,
* the behavior of floating-point arithmetic,
* rounding,
* the resolution of the underlying clock,
* the accuracy of the oscillator,
* and the behavior of the operating system scheduler.

The programmer thinks they are comparing two times.

They are actually comparing two **approximations of measurements of physical processes**.

That distinction is easy to miss.

### We can't even agree what a time means

Then there are time zones.

Consider:

```text
2026-11-01 01:30
```

What instant is that?

In some places, there may be two different occurrences of 1:30 on that date because the local clock moves backward when daylight-saving time ends.

So the value isn't necessarily enough.

We may also need:

```text
date
time
time zone
calendar
daylight-saving rules
historical time-zone rules
```

And suddenly something that appeared to be a simple scalar value has become a complicated object whose meaning depends upon geography, legislation, historical convention, and the version of a database containing those rules.

The computer isn't confused.

**Our representation is confused.**

The machine has been given a collection of symbols and asked to infer a physical reality from them.

### Then we discover that clocks disagree

The problem becomes even more interesting when there is more than one computer.

Suppose two machines each have a perfectly functioning clock.

Machine A records:

```text
10:00:00.001
```

Machine B records:

```text
10:00:00.002
```

Did A's event happen first?

Probably.

But perhaps A's clock is slightly fast.

Perhaps B's is slightly slow.

Perhaps the network introduced a delay.

Perhaps the machines synchronized at different moments.

Perhaps the event happened on one machine before the other but the messages describing those events arrived in the opposite order.

Now we have entered the world of distributed systems.

Computer science has developed increasingly sophisticated mechanisms for reasoning about time and causality:

* synchronized clocks,
* monotonic clocks,
* NTP,
* logical clocks,
* Lamport timestamps,
* vector clocks,
* causal ordering.

All of these are useful.

But notice what has happened.

We began with a simple question:

> What time is it?

And eventually arrived at:

> Which event happened first, given that no machine can necessarily observe the same clock, no clock is perfectly accurate, and messages take time to travel?

Perhaps the problem isn't that programmers are bad at handling time.

Perhaps **time was never the thing we were actually representing.**

### A clock is not time

This distinction is easy to lose because clocks are so useful.

A clock is a physical mechanism.

A quartz crystal oscillates.

An electronic circuit counts those oscillations.

A processor can count its cycles.

An operating system can turn those counts into seconds.

A calendar can turn seconds into dates.

A time-zone database can turn dates into local civil time.

At every step, we are transforming physical processes into increasingly convenient abstractions.

But the abstraction is not the thing itself.

A clock does not contain time.

A clock contains a process whose behavior we use as a **reference for ordering and measuring events**.

A timestamp does not contain an instant.

It contains an **encoding that we have agreed to interpret as an instant**.

A Unix timestamp is not time.

It is a coordinate in a convention.

A calendar is not time.

It is a system for organizing human experience of recurring astronomical and social events.

A time zone is not time.

It is a rule for translating between a global reference and local civil convention.

These things are extraordinarily useful.

But they are not interchangeable with the physical phenomenon they describe.

### We have mistaken the ruler for the distance

There is a broader pattern here.

A programmer can measure memory in bytes, but a byte is not memory.

A programmer can measure a network in packets, but a packet is not communication.

A programmer can represent an object with a pointer, but the pointer is not the object.

And a programmer can represent time with a number, but the number is not time.

The abstraction works because it hides almost everything we don't need to know.

Until suddenly we do need to know.

Then all the hidden complexity comes rushing back.

This is why time has produced such a remarkable collection of software disasters.

We have built layers upon layers of abstractions around an assumption that seems innocuous:

> **Time is a number that advances.**

But physical systems don't necessarily behave like numbers.

Events happen.

Signals propagate.

Oscillators oscillate.

Matter changes state.

Information arrives.

Systems wait.

Systems respond.

Some events cause others.

Some events happen independently.

Some events cannot be ordered from the perspective of an observer.

Some events are separated by measurable physical duration.

Others are separated primarily by causality.

These are all temporal relationships, but they are not the same thing.

### What happened first?

This question exposes the limitation particularly well.

A timestamp attempts to answer:

> When did this happen?

But sometimes the more useful question is:

> What caused what?

And sometimes the answer is neither.

Two events may be independent.

Two machines may observe them in different orders.

A signal may physically propagate from one location to another.

A computation may proceed only because a previous computation has reached a stable state.

These are different kinds of temporal relationships.

Yet conventional programming languages tend to flatten them into a small collection of concepts:

```text
now
before
after
sleep
timeout
timestamp
```

Useful, certainly.

But impoverished.

The physical world contains a much richer temporal vocabulary.

### The possibility of another model

This raises an uncomfortable possibility.

What if we stopped treating the clock as the fundamental temporal primitive of computation?

What if a computational system could reason about **events, ordering, causality, propagation, and temporal coordinates directly**?

What if time could be represented not merely as a number, but as a relationship between physical states?

What if a system could know that one piece of information follows another because the information itself propagated through the computational fabric?

What if a distributed system could refer to a deterministic digital position in a sequence rather than continually asking whether its local clock agrees with another machine?

What if hardware could be programmed to respond to a specific temporal state rather than repeatedly polling a clock until a numerical threshold had been crossed?

These questions lead somewhere very different from the conventional timer API.

They lead toward a model in which **time is a property of computation rather than merely a service provided to computation**.

**MatterScript** begins there.

It does not discard clocks.

Clocks remain useful physical references.

It does not discard timestamps.

Timestamps remain useful representations.

It does not discard operating-system time services.

They remain indispensable when software needs to interact with the world of calendars, schedules, and human time.

The point is simply that none of these things needs to be the fundamental representation of time inside the computational model.

A clock is one way of measuring temporal change.

A timestamp is one way of naming a temporal position.

A timer is one way of requesting that something happen later.

None of them is time itself.

**Time is not a clock.**

And once that distinction is taken seriously, a rather strange possibility appears:

perhaps computation does not need to wait for the clock to tell it when to move.

Perhaps computation can move because **something happened**.

And that is where the physical machine begins to become interesting again.

*Drafting in progress...*
