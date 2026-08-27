# The Cost of Abstraction

Abstraction is one of the great achievements of computer science.

It is also one of the great hidden expenses of civilization.

The modern programmer can write a few lines of code and cause an astonishing amount of physical machinery to act on their behalf. A programmer does not need to know the instruction set of the processor, the topology of the memory bus, the electrical characteristics of the transistors, the details of the storage controller, or the protocols by which packets move across a network.

That is the point of abstraction.

We hide the machine so that humans can work with ideas.

And it works.

The software industry has spent more than half a century building increasingly sophisticated layers between human intention and physical computation. Each layer makes the next layer easier to use.

But there is a question we rarely ask:

**What does all that abstraction cost?**

Not merely in software complexity.

In transistors.

In memory.

In electricity.

In bandwidth.

In heat.

In silicon.

In data centers.

In factories.

In power plants.

And ultimately, in the physical resources of civilization.

### The machine beneath the machine

Consider the most trivial computation imaginable:

```python
2 + 2
```

At the level of human intention, almost nothing is happening.

Two numbers are presented to a machine.

They are added.

The answer is four.

The physical operation required to perform an addition can be extraordinarily small. Digital addition can be implemented with relatively simple logic. A handful of Boolean operations can produce the result.

But that is not what happens when a programmer writes `2 + 2` in a high-level language.

The expression first exists as text.

That text must be interpreted according to the grammar of the language. It must be tokenized. Parsed. Represented internally. Compiled or interpreted. Perhaps transformed into bytecode. Perhaps passed through a virtual machine. Perhaps dispatched through a runtime. Perhaps represented as dynamically typed objects. Perhaps allocated in memory. Eventually, some sequence of machine instructions must reach a processor.

The processor itself contains instruction decoders, registers, caches, branch predictors, memory-management machinery, execution units, interconnects, and enormous amounts of control logic.

And somewhere down toward the bottom of all of this machinery, a relatively tiny collection of digital gates performs the arithmetic.

The result is:

```text
2 + 2 = 4
```

The important point is not that the computer did something wrong.

It did exactly what we asked.

The question is how much machinery had to participate in order to make such a simple expression convenient for a human being.

### Abstraction does not eliminate complexity

It **moves** complexity.

That is the great trick of abstraction.

A Python programmer does not need to understand the processor.

The processor does not need to understand Python.

Something in between has to translate.

And then something has to translate the translation.

And then something has to execute the result.

We can visualize the descent:

```text
human intention
      ↓
source code
      ↓
language grammar
      ↓
parser
      ↓
intermediate representation
      ↓
compiler / interpreter
      ↓
runtime
      ↓
operating system
      ↓
process
      ↓
machine instructions
      ↓
processor
      ↓
instruction decoder
      ↓
registers / execution units
      ↓
digital logic
      ↓
transistors
      ↓
electrical state
```

Every layer is useful.

Every layer solves a real problem.

But every layer is also another transformation.

The information has to be represented.

The representation has to be interpreted.

The interpretation has to be transformed.

The transformation has to be executed.

Abstraction doesn't make this machinery disappear.

**It makes the machinery invisible to the person using it.**

That distinction matters.

### The abstraction tax

We can think of this as an **abstraction tax**.

The abstraction tax is the physical cost incurred by representing a simple intention through a more general computational system.

It is tempting to define this as a simple ratio:

> useful computation divided by total computation.

But the problem is that "useful" is not always easy to define.

A general-purpose processor does not exist merely to perform one addition. Its enormous complexity provides flexibility. The operating system provides isolation, security, multitasking, portability, device management, and thousands of other capabilities. A programming language provides expressiveness and productivity.

Those things have enormous value.

So the question is not:

> Why don't we eliminate all abstraction?

That would be absurd.

The better question is:

> **How much physical machinery are we willing to deploy to obtain a particular level of abstraction?**

And once we ask the question that way, the answer becomes measurable in principle.

### The blockchain as an abstraction tax

Consider distributed agreement.

Suppose we want a collection of machines that do not trust one another to agree on a common sequence of events.

This is not a trivial problem.

We need some mechanism for determining which event came first, which history is authoritative, and how participants can agree without a central authority.

Bitcoin's proof-of-work mechanism solves part of this problem by making computational work—and therefore physical energy—part of the cost of participating in the consensus process.

That cost is not theoretical.

The Cambridge Centre for Alternative Finance estimated Bitcoin's annualized electricity consumption at about **138 TWh in June 2024**, with its model extending to approximately **183 TWh annualized by December 2024** as network hashrate increased.

That is a civilization-scale expenditure of energy to maintain a particular computational mechanism for distributed consensus.

And it is important to be precise here.

Bitcoin's proof-of-work does not exist merely to put transactions in order. It also provides Sybil resistance and makes rewriting history economically expensive. The enormous energy expenditure is part of the security model.

That is precisely why the example is useful.

The physical cost is not an accidental implementation detail.

**The physical cost is part of the abstraction.**

Ethereum provides an extraordinary counterexample.

Ethereum once used proof-of-work as well. Shortly before its transition to proof-of-stake, Ethereum's annual electricity consumption was estimated at approximately 78 TWh. After the transition, Ethereum estimates its current annual electricity consumption at roughly **0.0026 TWh**, with the Merge reducing electricity expenditure by more than **99.98%**.

The underlying lesson is much larger than cryptocurrency.

**Change the computational mechanism, and the physical cost of the abstraction can change by orders of magnitude.**

The problem was never "blockchains are inherently expensive."

The problem was that one particular mechanism for establishing distributed agreement was extremely expensive.

And this is precisely the sort of question MatterScript asks.

What if a problem that currently requires enormous computational machinery could instead be represented directly in the physical structure of the computation?

What if ordering could be established without repeatedly performing enormous amounts of unrelated work?

What if time itself could become a deterministic digital coordinate?

What if the hardware could recognize that coordinate directly?

The question is not whether computation should be distributed.

The question is whether **we are paying an unnecessary physical price for the way we have chosen to represent distribution and agreement.**

### The abstraction tax is everywhere

Blockchain is an unusually visible example because its energy consumption is easy to isolate.

Most abstraction costs are not.

They are distributed throughout the computing ecosystem.

A database query passes through layers of software.

A filesystem request passes through layers of software.

A network packet passes through layers of software and hardware.

A graphical operation passes through layers of software and hardware.

A web page passes through an extraordinary chain of representations before a human sees a collection of pixels.

Each layer is reasonable.

The complete stack can be enormous.

This is why the question of efficiency cannot be reduced to:

> How many CPU instructions does this program execute?

The physical cost of computation includes everything required to make the computation possible.

Memory movement.

Cache activity.

Instruction fetching.

Branch prediction.

Operating-system scheduling.

Virtualization.

Network transport.

Storage.

Cooling.

Power conversion.

Redundant infrastructure.

All of these exist somewhere below the programmer's abstraction.

### Civilization's computer

This matters because computing is no longer a small industrial activity.

It is **infrastructure**.

The International Energy Agency estimated that data centers consumed approximately **415 TWh of electricity in 2024**, about 1.5% of global electricity consumption. Its base-case projection puts data-center electricity consumption at approximately **945 TWh by 2030**.

These numbers cannot simply be labeled "waste."

Data centers provide enormous value.

They run financial systems, scientific computing, communications, entertainment, logistics, medical systems, businesses, government services, and increasingly artificial intelligence.

But the scale changes the question.

When computing consumes hundreds of terawatt-hours of electricity, even a small improvement in the amount of physical computation required to produce a unit of useful work becomes economically and environmentally significant.

At civilization scale, **efficiency is architecture**.

### How much of the machine is doing useful work?

This leads to a question that is difficult to answer precisely but impossible to ignore:

> **How much of the world's computational machinery is performing useful transformations of information, and how much is translating information between abstractions?**

We should be careful here.

There is no defensible universal number that says "X percent of computing is abstraction overhead."

Different workloads have radically different requirements.

An operating system may appear to be overhead when viewed from the perspective of a single arithmetic operation, but it is providing security, isolation, scheduling, hardware management, and services that are themselves useful.

A runtime may perform work that seems unnecessary for a particular calculation but enormously increases programmer productivity.

A compiler may produce millions of intermediate operations so that a human does not have to think about the physical machine.

The abstraction is buying something.

The question is:

**How much?**

And perhaps more importantly:

**Could we buy the same capability with less physical machinery?**

### From instructions to useful work

Consider two machines that both produce:

```text
4
```

One machine might perform the operation through a tiny dedicated circuit.

Another might execute it through a general-purpose processor running an operating system and a high-level runtime.

Another might execute the operation as part of a much larger computation on a GPU.

All three produce the same answer.

Their physical costs can be radically different.

This suggests a more interesting metric than raw performance:

> **physical computation per unit of useful result.**

How many transistor transitions?

How much energy?

How much memory movement?

How much bandwidth?

How much silicon?

How much cooling?

How much infrastructure?

For a particular useful result?

The answer will vary enormously depending on the abstraction and the workload.

But that is precisely the point.

We have become accustomed to measuring computers primarily in terms of abstract performance:

```text
gigahertz
gigaflops
terabytes
transactions per second
tokens per second
```

Perhaps we should also ask:

> **How much physical reality does one unit of useful computation require?**

### The strange economics of generality

There is a reason general-purpose computers became dominant.

Generality is extraordinarily valuable.

A specialized circuit might perform one operation extremely efficiently.

A general-purpose processor can perform millions of different operations.

A programming language can express almost anything.

An operating system can run almost anything.

A cloud platform can host almost anything.

This is the economic bargain of abstraction:

> Give up physical efficiency in exchange for flexibility.

For much of computing history, that was an excellent bargain.

Transistors became cheap.

Memory became cheap.

Storage became cheap.

Processors became faster.

So we spent the surplus on abstraction.

Instead of optimizing every computation for the physical machine, we optimized the machine for the convenience of the programmer.

And that worked spectacularly well.

But the bargain is changing.

Energy is not free.

Data movement is not free.

Cooling is not free.

Semiconductors are not free.

Data centers require land, transformers, transmission capacity, generators, cooling systems, construction, maintenance, and enormous amounts of capital.

The abstraction stack may be invisible to the programmer, but its physical consequences are not invisible to civilization.

### The opportunity hiding underneath the abstraction

This is where MatterScript takes a different position.

The objective is not to eliminate abstraction.

It is to **move the abstraction boundary closer to the physical computation**.

Instead of describing everything as instructions for a generic processor, MatterScript can describe things in terms of the structures that actually perform them.

A geometric relationship can become geometry.

A temporal relationship can become a temporal primitive.

A digital state can become a physical configuration.

A dataflow relationship can become a spatial arrangement of logic.

A deterministic sequence can become a hardware-recognizable temporal coordinate.

The programmer does not necessarily need to descend into transistor-level design.

But the language can preserve more information about the programmer's intention as it descends toward the machine.

That is the critical distinction.

Conventional abstraction often looks like:

```text
intention
   ↓
general representation
   ↓
more general representation
   ↓
more general representation
   ↓
generic machine
```

MatterScript aims for something more like:

```text
intention
   ↓
physical relationship
   ↓
computational structure
   ↓
physical implementation
```

The difference is not that MatterScript has fewer abstractions.

It is that the abstractions are intended to **preserve physical meaning**.

### Semantic compression

There is a useful way to think about this.

Suppose a programmer says:

```text
2 + 2
```

The semantic content of the statement is tiny.

If the physical system requires a vast amount of machinery to interpret and execute that statement, then most of the machinery is not creating new semantic information.

It is translating.

MatterScript seeks a form of **semantic compression**:

> Preserve as much of the programmer's intention as possible as the computation moves toward physical realization.

The closer the representation remains to the thing being computed, the less translation may be required.

This does not mean that every computation should become a custom circuit.

It means that the language should make it possible to express when that distinction matters.

If the programmer wants a general-purpose computation, use a general-purpose processor.

If the programmer wants a geometric object, represent geometry.

If the programmer wants a deterministic hardware event, represent the temporal relationship directly.

If the programmer wants a massive numerical operation, use the appropriate accelerator.

The abstraction should match the thing.

### The cost of forgetting the machine

There is a paradox at the heart of modern computing.

We became extraordinarily successful at making programmers forget that computers are physical machines.

That success allowed software to become vastly more sophisticated.

But it also created a generation of software systems in which the physical consequences of an abstraction are often invisible until they become enormous.

A programmer can allocate another object without thinking about the memory hierarchy.

A developer can make another network request without thinking about the physical infrastructure.

A service can replicate another database without thinking about the energy and hardware involved.

A distributed protocol can perform another round of consensus without thinking about the computation occurring across thousands of machines.

The abstractions are doing their job.

That is exactly why the physical cost is so easy to forget.

### The question MatterScript asks

MatterScript does not claim that abstraction is bad.

Abstraction is one of the reasons civilization has computers at all.

The question is more uncomfortable:

> **What if some of our abstractions are costing us far more physical reality than the problems they solve require?**

What if billions of gates are being activated to accomplish work that a much smaller physical structure could perform?

What if enormous quantities of memory are being moved because the representation of a problem is disconnected from the structure of the computation?

What if terawatt-hours of electricity are being consumed because we chose a computational mechanism that was convenient to general-purpose software rather than appropriate to the underlying physical problem?

What if the distance between human intention and physical realization has become unnecessarily large?

These are not merely questions of optimization.

They are questions about the architecture of computation.

Civilization has spent decades making computers easier to program.

We succeeded.

We built abstractions upon abstractions until almost no programmer needs to think about the physical machine anymore.

That achievement was extraordinary.

But abstraction has a physical cost.

Every representation requires storage.

Every translation requires computation.

Every computation requires matter and energy.

Every layer between intention and physical action has to exist somewhere.

The machine has not disappeared.

**We have simply hidden it.**

MatterScript begins with the proposition that perhaps we should make the machine visible again—not so that every programmer has to learn how to design transistors, but so that the language itself can preserve the physical structure of what the programmer means.

The goal is not less abstraction.

It is **better abstraction**.

Abstraction that understands geometry.

Abstraction that understands time.

Abstraction that understands causality.

Abstraction that understands the physical structure of computation.

And ultimately, abstraction that does not require civilization to build an enormous machine merely to hide the much smaller machine underneath it.

The question is no longer simply:

> How fast can we make computers?

It is:

> **How much physical reality should a computation require to express an idea?**

That is a question software has rarely been forced to answer.

MatterScript intends to ask it.

*Drafting in progress...*
