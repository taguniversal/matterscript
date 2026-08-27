# Part II: The Computational Universe

MatterScript begins from a remarkably simple observation.

**Information always exists somewhere.**

Signals occupy space.

Energy requires time to move.

Every physical interaction is local.

Every computation is embedded in a physical substrate.

For most of the history of computing, these facts have been treated as implementation details. Software describes algorithms, while hardware is responsible for making those algorithms run efficiently. The physical organization of the machine is largely hidden from the programmer.

MatterScript begins from the opposite assumption.

The physical world is not merely where computation happens.

The physical world **is** the computation.

---

For centuries, science has sought to understand nature by describing it mathematically.

A falling apple is described by Newton's laws.

A flowing river is described by the Navier-Stokes equations.

Heat is described by Fourier's equation.

Light is described by Maxwell's equations.

These mathematical descriptions are among humanity's greatest intellectual achievements. They allow us to predict the behavior of extraordinarily complex systems with remarkable accuracy.

But they are not the systems themselves.

They are **abstractions**.

When we build software to model a physical process, we typically begin by extracting a handful of measurable properties, deriving equations that approximate their behavior, and then solving those equations numerically. Reality is first reduced to mathematics, and mathematics is then reduced to software.

For many problems, this approach has been enormously successful.

But it is not the only possible approach.

---

In 2002, Stephen Wolfram proposed a different way of thinking.

Rather than viewing complexity as something that requires increasingly sophisticated mathematics, *A New Kind of Science* suggested that extraordinary complexity can emerge from the repeated application of remarkably simple computational rules.

The implications were profound.

Perhaps nature is not solving equations at all.

Perhaps nature is **computing**.

A snowflake does not solve differential equations to determine how it should grow.

A forest does not optimize a mathematical function before producing another branch.

A hurricane does not integrate the Navier-Stokes equations before changing direction.

Every component simply interacts with its immediate neighbors according to local rules.

From those countless local interactions, global behavior emerges.

---

MatterScript takes this idea one step further.

If reality is fundamentally an unfolding computation, then perhaps our programming languages should describe computations directly rather than forcing every physical system through layers of mathematical abstraction.

Instead of asking,

*"What equations govern this system?"*

we begin by asking,

*"What local interactions produce this behavior?"*

This is more than a philosophical distinction.

It changes how we build software.

One approach attempts to **describe** reality.

The other attempts to **recreate** it.

---

Consider weather prediction.

A modern weather simulation divides the atmosphere into millions of cells. At every timestep, the simulation repeatedly reads enormous quantities of data from memory, computes pressure, temperature, humidity, momentum, turbulence, radiation, and dozens of other coupled physical effects, then writes the updated state back to memory before beginning the next iteration.

The mathematics is elegant.

The engineering is extraordinary.

But much of the machine's effort is not spent performing physics.

It is spent moving data.

The computational substrate bears almost no resemblance to the atmosphere it is attempting to simulate.

---

Now imagine a different computational fabric.

Suppose every programmable logic element in an FPGA represented one small parcel of atmosphere.

Each logic cell stores its own temperature.

Its own pressure.

Its own humidity.

Its own momentum.

Each cell communicates only with its neighboring cells because neighboring parcels of air communicate only with neighboring parcels of air.

When heat flows through the simulated atmosphere, information propagates through the computational fabric in exactly the same local manner.

There is no processor repeatedly fetching state from memory.

There is no cache hierarchy attempting to hide memory latency.

There is no massive movement of data between storage and computation.

The atmosphere simply evolves.

The hardware itself becomes a computational analogue of the physical system.

---

This is not an analog computer.

Every value remains digital.

Every interaction remains deterministic.

Every computation remains reproducible.

What changes is the **organization** of the machine.

Instead of forcing a spatial process onto a sequential architecture, we construct a computational substrate whose geometry mirrors the geometry of the physical system itself.

The computation unfolds for exactly the same reason the physical system unfolds:

because neighboring elements continually influence one another.

---

This idea extends far beyond weather.

A heat exchanger.

A bridge under load.

A section of living tissue.

An electrical power grid.

A watershed.

An ecosystem.

A city.

Each can be viewed not merely as an object to be described mathematically, but as a computational universe composed of countless local interactions whose collective behavior emerges over time.

The programmer is no longer writing an algorithm that computes the state of the system.

The programmer is defining the universe in which the system is allowed to evolve.

---

This is why MatterScript is fundamentally different from conventional programming languages.

Traditional languages describe **algorithms**.

MatterScript describes **computational universes**.

A MatterScript program does not simply specify what should happen.

It defines the space in which computation exists.

It defines the relationships between neighboring elements.

It defines the local rules by which those elements interact.

The global behavior is not explicitly programmed.

It emerges.

---

Once computation is viewed this way, many familiar distinctions begin to disappear.

Simulation and execution become the same activity.

Geometry and computation become inseparable.

Data and structure become part of the same computational fabric.

Hardware ceases to be merely a platform that executes software.

It becomes the universe in which that software unfolds.

This is the central shift in perspective that MatterScript asks the reader to make.

Instead of viewing computation as a sequence of instructions acting upon data, we begin to view computation as the natural evolution of a structured universe governed by local relationships.

Once that shift occurs, geometry is no longer an implementation detail.

It becomes one of the fundamental building blocks of computation itself.

*Drafting in progress...*
