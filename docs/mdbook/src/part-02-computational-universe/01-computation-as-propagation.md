# Computation as Propagation

Most programmers learn to think of computation as a sequence of instructions.

Read a value.

Execute an operation.

Store the result.

Repeat.

Whether the language is C, Python, Java, or Rust, this mental model rarely changes. Even when multiple processors are involved, we still imagine computation as many instruction streams executing simultaneously.

MatterScript begins from a different premise.

**Computation is not the execution of instructions.**

**Computation is the propagation of information through a network of relationships.**

This may sound like a subtle distinction, but it changes almost everything about how a program is written, understood, and ultimately executed.

---

Consider the simplest useful MatterScript definition.

```matterscript
NOT[(A<>)($Q)

    Q<$A()>

    :0[1]
     1[0]
]
```

If you've never seen MatterScript before, don't worry about every symbol just yet.

Instead, ask a single question.

**How does information move?**

The definition declares one input place, `A<>`, and one output place, `$Q`.

Between them is a single expression:

```matterscript
Q<$A()>
```

This statement does not perform a computation.

It creates a relationship.

It says that whatever value eventually arrives at `$A` will be used to form the name of another definition. That definition will return its contents, and the returned value will propagate to `Q`.

The two constant definitions at the end describe the behavior of the gate.

```matterscript
:0[1]
 1[0]
```

If the incoming value is `0`, return `1`.

If the incoming value is `1`, return `0`.

That is the complete definition of logical inversion.

---

Now imagine that the input contains the value `1`.

The flow of computation looks like this:

```text
1
│
▼
A<>
│
▼
$A()
│
▼
Q<1()>
│
▼
1[0]
│
▼
0
│
▼
Q<>
```

Nothing executes.

Nothing is assigned.

Nothing is overwritten.

The value simply propagates through an existing network until it reaches a stable destination.

The computation is the movement itself.

---

This may feel unfamiliar because conventional programming languages hide nearly every physical aspect of computation.

Consider the equivalent statement in C.

```c
q = !a;
```

The syntax is wonderfully concise.

But it leaves many important questions unanswered.

Where is `a` physically located?

Where is `q`?

How far apart are they?

How long does the operation take?

How does the result travel from one location to the other?

The language doesn't know.

Those questions belong to the compiler, the processor, the cache hierarchy, and ultimately the hardware itself.

MatterScript does not separate these concerns so completely.

Information always exists somewhere.

Propagation always requires time.

Every relationship has a physical interpretation.

---

Now consider a slightly larger example.

```matterscript
NOT($A)(OP<>)

NOT($OP)(Q<>)
```

A programmer raised on imperative languages naturally asks:

*"Which NOT executes first?"*

The answer is surprisingly simple.

Neither.

There is no first instruction.

The first NOT gate resolves only because information reaches `$A`.

The second NOT gate resolves only because information later reaches `$OP`.

The apparent ordering is not imposed by the programmer.

It is imposed by causality.

The second computation literally cannot occur until the first has produced information.

The order emerges naturally from the dependencies within the network.

MatterScript does not schedule computation.

It allows computation to unfold.

---

Once we begin thinking in terms of propagation rather than execution, time acquires a very different meaning.

Suppose each NOT gate requires two nanoseconds to settle.

The first inversion occurs.

Two nanoseconds later, its output becomes available.

Only then can the second gate begin resolving.

Two nanoseconds later, the final result appears.

The total propagation delay is four nanoseconds.

No clock was consulted.

No scheduler advanced to the next instruction.

Time emerges naturally from the physical behavior of the network.

---

Geometry becomes equally important.

Suppose the two NOT gates are adjacent on an FPGA.

The signal travels only a very short distance.

Now imagine placing them on opposite sides of the device.

The logical behavior is identical.

The Boolean function has not changed.

Yet the computation now requires additional propagation time because the signal must travel farther.

Nothing about the algorithm changed.

Only the geometry.

This is why MatterScript treats placement as part of the computation rather than an optimization to be discovered later.

The physical arrangement of the network directly influences its behavior.

---

There is another important idea hidden within this simple example.

Before the input ever arrives, the entire network already exists.

Every place has been created.

Every connection has been established.

Every propagation path has already been determined.

The program is complete before a single value enters the system.

The computation is **latent**.

The arrival of information does not create the computation.

It merely activates part of an existing computational structure.

**This is a profound departure from the conventional view of software.**

Imperative languages encourage us to think that a program comes to life one instruction at a time.

MatterScript encourages us to think of a program as a structured universe waiting for information to propagate through it.

Execution is not the creation of computation.

It is the unfolding of computation that already exists.

---

This idea should sound familiar.

In the previous chapter, we argued that a placed computational fabric already contains knowledge about the problem it is intended to solve.

Neighborhoods have already been established.

Distances have already been encoded.

Communication paths already exist.

**The placement itself is frozen knowledge.**

Propagation is the dynamic counterpart to that idea.

The structure represents potential.

Information reveals that potential.

One is static.

The other is dynamic.

Together they describe a completely different model of computation.

A MatterScript program is not a sequence of instructions waiting to be executed.

It is a latent computational structure waiting for information to propagate through it.

---

As programs grow larger, nothing fundamentally changes.

A full adder is built the same way.

A processor is built the same way.

A weather simulation is built the same way.

Each consists of places connected by relationships through which information naturally propagates according to local rules.

The scale changes.

The principle does not.

Once you begin thinking in terms of propagation rather than execution, MatterScript stops looking like an unusual programming language.

It begins to look remarkably similar to the way computation occurs in the physical world itself.

*Drafting in progress...*
