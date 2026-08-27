# Geometry as Information

When programmers hear the word *geometry*, they usually think about graphics.

Points.

Lines.

Triangles.

Meshes.

Three-dimensional models.

These are certainly geometric objects, but they are not what makes geometry fundamentally important.

Geometry is important because it encodes relationships.

Distance.

Adjacency.

Containment.

Orientation.

Neighborhood.

Accessibility.

Before a single computation begins, a geometric arrangement already answers countless questions.

Which objects are nearby?

Which objects can interact?

Which paths are shortest?

Which regions share a boundary?

Which elements can exchange energy?

The answers exist simply because of the arrangement itself.

No algorithm has yet executed.

No search has begun.

The information is already there.

---

Imagine standing in a city.

Without calculating anything, you already know certain facts.

The building across the street is closer than the mountain on the horizon.

The room next door is easier to reach than another building downtown.

The sidewalk connects naturally to the intersection.

The intersection connects to another street.

None of these relationships need to be computed.

The geometry itself contains the information.

It is knowledge embedded in space.

---

Engineers rely on this every day.

A bridge transfers forces because its beams are arranged in particular ways.

A river flows downhill because the landscape possesses a particular geometry.

A neuron communicates only with neighboring neurons because biology arranged them that way.

A crystal forms because atoms occupy energetically favorable positions.

Nothing repeatedly computes these relationships.

They simply exist.

The structure itself determines what interactions are possible.

---

Modern software often works very differently.

Instead of allowing geometry to express relationships naturally, we store those relationships explicitly.

Graphs.

Adjacency matrices.

Spatial indexes.

Hash maps.

Trees.

Databases.

These structures are enormously useful, but they all represent something curious.

They are attempts to reconstruct information that geometry already contains.

Consider a molecular simulation.

A conventional program stores the position of every molecule in memory. During every simulation step it asks the same questions:

Which molecules are near one another?

Which molecules can collide?

Which forces should be applied?

Entire fields of computer science have been devoted to accelerating these searches.

Spatial partitioning.

KD-trees.

Bounding volume hierarchies.

Uniform grids.

Octrees.

These are elegant and sophisticated techniques.

But they all solve the same underlying problem.

The computation has forgotten the geometry.

It must rediscover it over and over again.

---

MatterScript proposes a different approach.

Suppose neighboring molecules are already neighboring computations.

Suppose adjacency is encoded directly into the computational fabric.

Suppose communication paths mirror physical connectivity.

Suppose propagation delays reflect physical distance.

Now the machine no longer asks,

*"Who are my neighbors?"*

It already knows.

The geometry answers the question before execution begins.

---

This observation extends far beyond scientific simulation.

A road network already describes transportation.

A watershed already describes drainage.

An electrical circuit already describes current flow.

A biological tissue already describes cellular communication.

A city's layout already constrains traffic, commerce, and movement.

Every physical arrangement contains information.

The arrangement itself is part of the computation.

---

This leads to an important observation.

**Every search performed at runtime is evidence that some relationship was unknown at compile time.**

When software traverses a graph, it is discovering connectivity.

When software searches a spatial index, it is discovering neighborhood.

When software consults a lookup table, it is discovering association.

When software scans a simulation looking for the next element to update, it is discovering causality.

Many of these searches are unavoidable because the relationships genuinely change over time.

But many are not.

They exist because our programming languages have no way to express those relationships as part of the program itself.

MatterScript does.

---

This is why geometry occupies such a central place in the language.

It is not included to support graphics.

It is not included merely to improve hardware placement.

It is included because geometry is a remarkably efficient way to represent knowledge.

When the compiler constructs a MatterScript program, it is doing more than arranging computations.

It is embedding information.

Distances become fixed.

Neighborhoods become fixed.

Communication paths become fixed.

Possible interactions become fixed.

**The placement itself is frozen knowledge.**

Execution does not begin from an empty machine.

It begins from a computational fabric whose structure already answers many of the questions the program would otherwise spend its time asking.

---

This represents a fundamental shift in how we think about programming.

Traditionally, geometry has been viewed as the place where computation happens.

MatterScript treats geometry as part of the computation itself.

A MatterScript program therefore consists of three complementary forms of information.

The **structure** defines what can exist.

The **geometry** defines what can interact.

The **propagation** defines what actually happens.

Together they describe more than a program.

They describe a computational universe whose organization already contains part of its own solution.

The programmer is no longer writing instructions that operate on an abstract machine.

The programmer is designing a universe whose structure, geometry, and causal relationships allow computation to emerge naturally.

*Drafting in progress...*
