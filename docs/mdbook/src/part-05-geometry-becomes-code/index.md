# Part VI: Geometry Becomes Code

Traditional languages separate computation from geometry.

MatterScript unifies them.

Meshes become executable.

CAD models become programs.

LIDAR scans become computational substrates.

This is where MatterScript begins to differ fundamentally from every previous programming language. The language's geometry-aware placement model projects physical domains onto FPGA fabrics while preserving neighborhood relationships and compensating projection distortion with synthesized delays.

To achieve this, MatterScript utilizes domain selectors to activate domain-specific extensions directly within the structural graph. Introducing the `spatial3d` domain selector exposes a specialized set of topological primitives, geometric constructors, spatial predicates, and transformation operators tailored for 3D computational domains.

Below is the list of structural keywords and functions available under the `spatial3d` domain:

* **Point (`point`)**: Not merely a 3D coordinate vector, but a discrete physical location within space defined via `point(x, y, z)`.
* **Edge (`edge`)**: A directional, causal connection established between two points using `edge(pointA, pointB)`.
* **Loop (`loop`)**: An ordered, closed sequence of connected edges defining a spatial boundary via `loop(edges)`.
* **Face (`face`)**: A surface domain created by enclosing one or more loops via `face([edge])`.
* **Volume (`volume`)**: Enclosed, three-dimensional spatial regions bounded by defined faces.
* **Group (`group`)**: A hierarchical composition that organizes geometric relationships into nested, modular definitions.

### Spatial Predicates & Proximity

* **`near(faceA, faceB)`**: Evaluates spatial proximity between surface domains.
* **`adjacent(edgeA, edgeB)`**: Asserts boundary connectivity between neighboring edges.
* **`contains(point)`**: Determines enclosure of a point within a spatial volume or boundary.
* **`intersects()`**: Computes structural overlap between spatial elements.
* **`touches()`**: Checks boundary contact without volumetric overlap.
* **`within(distance)`**: Evaluates whether elements fall within a specified metric radius.

### Constructive & Swept Geometry

* **`extrude(face, height)`**: Projects a planar face along a normal vector to form a 3D volume.
* **`sweep(profile, path)`**: Sweeps a closed profile along a continuous path.
* **`loft(loop1, loop2)`**: Interpolates a continuous topological surface between disparate boundary loops.
* **`revolve(profile, axis)`**: Rotates a 2D profile around an axis of rotation.

### CSG & Boolean Operations

* **`union()`**: Combines multiple spatial regions into a unified domain.
* **`difference()`**: Subtracts one spatial boundary from another.
* **`intersection()`**: Resolves the common volumetric domain shared between shapes.

### Spatial Transformations & Meshing

* **`subdivide()`**: Refines topological density across a domain.
* **`mirror()`**: Reflects geometry across a specified plane.
* **`translate()`**: Shifts spatial entities across coordinate axes.
* **`rotate()`**: Applies rotational transformations around a specified axis.
* **`scale()`**: Uniformly or non-uniformly resizes spatial geometries.

By expressing physical domains using these topological building blocks rather than static polygon meshes, spatial proximity directly dictates computational interaction. Spatial relationships compile into the exact same propagation graph as time, turning geometric boundary conditions directly into executable hardware and software realizations.

Consider how this relationship graph handles non-orientable 3D manifolds without requiring mathematical matrix transformations inside the AST. A Möbius ribbon can be expressed by defining four quad faces where the topological boundary of the final face twists its edge bindings:

```matterscript
mobius_strip[()($f0, $f1, $f2, $f3) 
    spatial3d :
    // 1. Instantiating internal point sources (p0..p7)
    p0< point(1.0, 0.0, -0.2) >
    p1< point(1.0, 0.0, 0.2) >
    p2< point(0.0, 1.0, -0.2) >
    p3< point(0.0, 0.2, 0.0) >
    p4< point(-1.0, 0.0, -0.2) >
    p5< point(-1.0, 0.0, 0.2) >
    p6< point(0.0, -1.0, 0.0) >
    p7< point(0.0, -0.2, -0.2) >

    // 2. Consuming point destinations ($pX) to drive exported face destinations (fX<>)
    f0<face(loop(edge($p0, $p1), edge($p1, $p3), edge($p3, $p2), edge($p2, $p0)))>
    f1<face(loop(edge($p2, $p3), edge($p3, $p5), edge($p5, $p4), edge($p4, $p2)))>
    f2<face(loop(edge($p4, $p5), edge($p5, $p7), edge($p7, $p6), edge($p6, $p4)))>
    f3<face(loop(edge($p6, $p7), edge($p7, $p0), edge($p0, $p1), edge($p1, $p6)))>
]

```

The twist does not emerge from a continuous rotation matrix or an imperative sweep command. It exists because the causal connectivity graph swaps its terminal bindings (`edge(p0,p1)` versus `edge(p1,p0)`). The geometric surface is a direct consequence of topological declaration.

In IPL, an invocation targeting a geometric definition operates by binding dynamic execution/dataflow to the spatial boundary and providing a **spatial placement vector** (translation, orientation, scaling) to ground that definition within a coordinate system.

Because the geometric definition specifies relative topological adjacencies (the local manifold), the invocation supplies the transform that projects those local spatial registers into global compute space or hardware coordinates.

---

### Invocation Syntax & Mechanics

Following the canonical IPL invocation model:

$$\text{invocationName}[(\text{destination\_bindings})(\text{source\_bindings}) \quad \text{spatial\_domain} @ \text{placement\_vector} : \text{execution\_rules}]$$

* **Domain Target (`spatial_domain`):** Specifies which spatial definition acts as the physical/topological substrate.
* **Placement Vector (`@ placement_vector`):** Supplies the origin offset, orientation frame, or scale parameters to position the domain in 3D coordinate space.
* **Stream/Data Bindings (`(destinations)(sources)`):** Feeds real-time computational inputs and extracts output streams across the placed geometry.

---

### Conceptual Syntax Example

```ipl
// Invocation instantiating computation inside the declared 3D domain at explicit coordinates
field_solver[(output_mesh)(sensor_stream) mobius_strip @ transform3d{ pos: [10.0, 0.0, 5.0], rot: [0.0, 45.0, 0.0], scale: 1.0 } :
    // Execution rules evaluated across the placed topological domain
    output_mesh = compute_wave_propagation(sensor_stream)
]

```

---

### How the Compiler Resolves the Invocation

1. **Coordinate Transformation at AST Lowering:** The compiler applies the invocation's `@ transform3d` vector to the definition's local point set (`p0`...`p7`), transforming local anchors into global physical/virtual 3D coordinates.
2. **Channel Delay Re-Synthesis:** If the placement transformation stretches, scales, or skews the domain, the compiler recalculates edge physical lengths and re-synthesizes latency-compensation delays along the graph channels.
3. **Execution Domain Allocation:**
* **For Hardware (FPGA/ASIC):** The global coordinates directly map the graph node placement onto corresponding physical tiles or logic sectors.
* **For Software (SPIR-V/CPU):** Global coordinates determine spatial partitioning, workgroup dispatch dimensions, and thread routing.

### Manufacturing Outputs and Hardware Realization

Because a Möbius strip is a valid 2D manifold embedded in 3D space without self-intersection, it serves as a powerful bridge between abstract topology, physical manufacturing, and silicon compilation.

**1. Physical Manufacturability**
Traditional 3D models often suffer from manifold errors, unclosed shells, or self-intersecting meshes when sent to CAD/CAM software or 3D printers. Because MatterScript defines geometry via explicit topological adjacencies (`point`, `edge`, `loop`, `face`), the output guarantees surface continuity. The resulting AST compiles cleanly into:
* **Toolpath Generation:** Continuous CNC milling paths and 3D printer G-code without surface singularities.
* **Unfolded Flat Patterns:** Direct projection into 2D sheet metal cutting profiles or flexible PCB layouts.

**2. Flattening 3D Topologies to 2D FPGA Fabrics**
Mapping non-orientable 3D compute domains onto a flat 2D FPGA logic grid traditionally causes severe routing congestion. The IPL compiler resolves this via graph channel routing rather than geometric projection:

* **Topological Decoupling:** The compiler treats the 3D twist purely as a boundary redirection in the connectivity graph (e.g., binding `edge(p6, p7)` to `edge(p0, p1)` in reverse order).
* **Planar Placement Algorithms:** Spectral and force-directed graph algorithms lay out the topological nodes across the 2D Configurable Logic Block (CLB) array.
* **Synthesized Delay Equalization:** When topological connections cross physical distances on the chip, the compiler automatically inserts target delay buffers along the graph channels to ensure synchronized signal propagation.

Through this unified model, physical geometry, manufacturable toolpaths, and silicon place-and-route are treated as equivalent graph reduction passes.

