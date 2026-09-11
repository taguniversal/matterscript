# Domains & Spatial Contexts

In MatterScript, computation is inherently spatial. Rather than treating physical coordinates or hardware topology as secondary metadata, MatterScript uses the `@domain` directive to declare the geometric context in which signals propagate.

Although the `@domain(...)` syntax remains consistent across definitions, its semantics bifurcate cleanly based on dimensionality. A domain can act either as a discrete grid for bounded state generation or as a continuous topological graph for physical hardware routing.

---

## 1. Discrete Stencil Domains (`spatial2d`)

A `spatial2d` domain establishes a discrete, bounded coordinate space. It is typically paired with cellular automata, stencil kernels, or finite-difference solvers where state updates execute across a grid of uniform spatial registers.

### Key Mechanics

* **Explicit Bounding:** Defines rigid bounding boxes via properties such as `size: [Width, Height]`.
* **State Generation:** Coordinates input state tuples across localized neighborhood windows or coordinate offsets.
* **Boundary Conditions:** Standardizes edge-wrapping rules (such as toroidal grids or clamped edges) at the domain boundaries.

### Compiler Role

When encountering a `spatial2d` domain, the compiler lowers the definitions into grid memory allocations, compute shaders (such as WGSL), or flattened two-dimensional arrays.

```matterscript
// Bind to a 2D spatial domain with explicit bounds
@domain(spatial2d, size: [300, 500])

@generate {
  // Format: [ Left , Center , Right ] -> New Center State
  [2, 1, 5] : 4
  [3, 2, 4] : 6
  [4, 4, 6] : 4
}

```

---

## 2. Topological Graph Domains (`spatial3d`)

In contrast to discrete grids, a `spatial3d` domain does not represent an array to iterate across. Instead, it serves as a compiler hint that geometric primitives (`point`, `edge`, `loop`, `face`) describe **static spatial adjacency and physical routing proximity**.

Rather than relying on static polygon meshes or imperative sweep pipelines, physical domains are expressed using topological building blocks. Because spatial proximity directly dictates computational interaction, these relationships compile into the exact same propagation graph as time—turning geometric boundary conditions directly into executable hardware and software realizations.

### Software Reference & Primitive Vocabulary

The `spatial3d` domain exposes a rich set of structural keywords, predicates, CSG operations, and spatial transforms:

**Structural Primitives**

* **Point (`point`)**: A discrete physical location within space defined via `point(x, y, z)`.
* **Edge (`edge`)**: A directional, causal connection established between two points using `edge(pointA, pointB)`.
* **Loop (`loop`)**: An ordered, closed sequence of connected edges defining a spatial boundary via `loop(edges)`.
* **Face (`face`)**: A surface domain created by enclosing one or more loops via `face([edge])`.
* **Volume (`volume`)**: Enclosed, three-dimensional spatial regions bounded by defined faces.
* **Group (`group`)**: A hierarchical composition that organizes geometric relationships into nested, modular definitions.

**Spatial Predicates & Proximity**

* `near(faceA, faceB)`: Evaluates spatial proximity between surface domains.
* `adjacent(edgeA, edgeB)`: Asserts boundary connectivity between neighboring edges.
* `contains(point)`: Determines enclosure of a point within a spatial volume or boundary.
* `intersects()`: Computes structural overlap between spatial elements.
* `touches()`: Checks boundary contact without volumetric overlap.
* `within(distance)`: Evaluates whether elements fall within a specified metric radius.

**Constructive & Swept Geometry**

* `extrude(face, height)`: Projects a planar face along a normal vector to form a 3D volume.
* `sweep(profile, path)`: Sweeps a closed profile along a continuous path.
* `loft(loop1, loop2)`: Interpolates a continuous topological surface between disparate boundary loops.
* `revolve(profile, axis)`: Rotates a 2D profile around an axis of rotation.

**CSG & Boolean Operations**

* `union()`: Combines multiple spatial regions into a unified domain.
* `difference()`: Subtracts one spatial boundary from another.
* `intersection()`: Resolves the common volumetric domain shared between shapes.

**Spatial Transformations & Meshing**

* `subdivide()`: Refines topological density across a domain.
* `mirror()`: Reflects geometry across a specified plane.
* `translate()` / `rotate()` / `scale()`: Shifts, rotates, or resizes spatial geometries across coordinate axes.

---

## Topological Declaration vs. Matrix Transformation

A major advantage of graph-based topological modeling is that non-orientable 3D manifolds do not require continuous mathematical matrix transformations inside the AST.

Consider a Möbius ribbon. In traditional graphics pipelines, this shape requires procedural surface integration or continuous rotation matrices. In MatterScript, it is expressed simply by defining four quad faces where the topological boundary of the final face twists its edge bindings:

```matterscript
mobius_strip[()($f0, $f1, $f2, $f3) 
    @domain(spatial3d)
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
    :
]

```

The twist does not emerge from an imperative sweep command or a runtime matrix evaluation. It exists because the causal connectivity graph swaps its terminal bindings—connecting `edge($p0, $p1)` back to `edge($p1, $p6)` at the boundary. The geometric surface is a direct consequence of topological declaration.

---

## Binding Execution to Spatial Domains

An invocation targeting a geometric definition operates by binding dynamic execution and dataflow to the spatial boundary. It provides a placement vector (translation, orientation, scaling) to ground that definition within a concrete coordinate system.

Because the geometric definition specifies local manifold adjacencies, the invocation supplies the transform that projects those local spatial registers directly into global compute space or physical hardware placement constraints.