# Why Software Forgot Geometry


Programming languages are built on an assumption so fundamental that most programmers never think to question it.

**Computation is independent of space.**

Variables have no location.

Functions occupy no physical volume.

Messages travel instantly.

Memory appears to be equally distant from every instruction.

The compiler may decide where code ultimately executes, but the programmer rarely cares. Geometry is someone else's problem.

This wasn't always inevitable.

In fact, for most of human history, geometry was considered the most intuitive and trustworthy branch of mathematics.

Euclid described mathematics in terms of points, lines, surfaces, and their relationships. Newton presented his revolutionary work in *Principia* using geometric arguments because they reflected physical reality in a way that symbolic algebra did not. For centuries, geometry was regarded as the language through which the physical world could be understood.

Algebra occupied a different role.

It was useful, often extraordinarily powerful, but it dealt with symbols detached from any particular physical interpretation. Equations could represent almost anything—or nothing at all.

Over time, that distinction disappeared.

During the nineteenth century, mathematics gradually shifted away from geometric reasoning toward symbolic manipulation. Hilbert demonstrated that geometry itself could be expressed axiomatically as symbols obeying formal rules. What mattered was no longer the interpretation of the symbols but the consistency of the rules governing them.

At nearly the same time, mathematicians became fascinated by a different question.

Could reasoning itself be mechanized?

The Hindu-Arabic numeral system had already shown that complex arithmetic could be performed through simple mechanical procedures. Leibniz imagined a universal symbolic language in which every scientific question could be answered by calculation alone. Later, Hilbert sought a formal method that could determine the truth or falsehood of any mathematical statement.

The search ultimately failed. Gödel proved there were limits to formal systems, while Church and Turing showed that no universal mechanical procedure could decide every mathematical question.

Yet something profound emerged from that work.

To study the limits of mathematics, researchers had developed a precise notion of a **mechanical computation**.

That notion became the algorithm.

The electronic computer arrived at exactly the right moment.

Unlike earlier calculating machines, electronic computers were capable of carrying out enormous numbers of these mechanical procedures automatically. Many of the mathematicians investigating algorithms—including John von Neumann and Alan Turing—were directly involved in their development.

As a result, computer science inherited not only the hardware, but the mathematical framework that had been created to study effective procedures.

The algorithm became the organizing principle of programming.

That inheritance made perfect sense.

The earliest computers possessed almost no memory, extremely limited processing power, and primitive input and output devices. Programs were written to solve numerical problems one instruction at a time. Thinking of computation as a sequence of symbolic transformations was both natural and extraordinarily successful.

For seventy years, programming languages refined this idea.

Assembly organized instructions.

FORTRAN organized calculations.

C organized memory.

Object-oriented languages organized data.

Functional languages organized transformations.

Distributed systems organized communication.

But throughout every generation, one assumption remained remarkably constant:

**Programs describe sequences of operations on symbols.**

Geometry disappeared.

Not because it was unimportant, but because it seemed unnecessary.

---

Today that assumption deserves to be reconsidered.

Modern processors contain billions of transistors arranged with nanometer precision.

FPGAs expose millions of programmable logic elements whose physical placement directly influences performance.

Robots navigate three-dimensional environments.

Autonomous vehicles continuously model space.

Scientific simulations solve problems defined on meshes, lattices, and finite elements.

Machine learning increasingly depends on spatial data structures, graph relationships, and locality of computation.

In every one of these domains, geometry is not incidental.

It is the computation.

Yet our programming languages continue to describe these systems as though geometry were merely an implementation detail to be recovered later by compilers and place-and-route tools.

We routinely manufacture computational devices whose physical organization determines their behavior, while programming them in languages that pretend physical organization does not exist.

The gap between software and hardware has never been wider.

---

MatterScript begins with a different assumption.

Computation always happens somewhere.

Information always travels through space.

Propagation always takes time.

The geometry of a computation is not an optimization to be discovered after the program is written—it is part of the program itself.

This does not replace algorithms.

Algorithms remain an extraordinarily useful way to describe many classes of computation.

But they are not the only way.

Just as geometry and algebra eventually came to coexist within mathematics, sequential algorithms and spatial computation can coexist within programming.

MatterScript explores what programming looks like when we stop treating geometry as an implementation detail and instead make it one of the fundamental concepts of the language.

---

*Drafting in progress...*
