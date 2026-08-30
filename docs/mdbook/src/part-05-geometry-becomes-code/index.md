# Part VI: Geometry Becomes Code

Traditional languages separate computation from geometry.

MatterScript unifies them.

Meshes become executable.
CAD models become programs.
LIDAR scans become computational substrates.

This is where MatterScript begins to differ fundamentally from every previous programming language. The language's geometry-aware placement model projects physical domains onto FPGA fabrics while preserving neighborhood relationships and compensating projection distortion with synthesized delays.

To achieve this, the MatterScript geometry dialect avoids treating shapes as dead collections of triangles. Instead, space is defined through six foundational primitives that capture spatial and causal relationships directly inside the association graph:

* **Point (`point`):** Not merely a 3D coordinate vector, but a discrete physical location within space.
* **Edge (`edge`):** A directional, causal connection established between two points.
* **Loop (`loop`):** An ordered, closed sequence of connected edges defining a spatial boundary.
* **Face (`face`):** A surface domain created by enclosing one or more loops.
* **Volume (`volume`):** Enclosed, three-dimensional spatial regions bounded by defined faces.
* **Group (`group`):** A hierarchical composition that organizes geometric relationships into nested, modular definitions.

By expressing physical domains using these topological building blocks rather than static polygon meshes, spatial proximity directly dictates computational interaction. Spatial relationships compile into the exact same propagation graph as time, turning geometric boundary conditions directly into executable hardware and software realizations.

Consider how this relationship graph handles non-orientable 3D manifolds without requiring mathematical matrix transformations inside the AST. A Möbius ribbon can be expressed by defining four quad faces where the topological boundary of the final face twists its edge bindings:

```matterscript
group mobius_ring {
    p0 = point{ x: 1.0, y: 0.0, z: -0.2 }   p1 = point{ x: 1.0, y: 0.0, z: 0.2 }
    p2 = point{ x: 0.0, y: 1.0, z: -0.2 }   p3 = point{ x: 0.0, y: 0.2, z: 0.0 }
    p4 = point{ x: -1.0, y: 0.0, z: -0.2 }  p5 = point{ x: -1.0, y: 0.0, z: 0.2 }
    p6 = point{ x: 0.0, y: -1.0, z: 0.0 }   p7 = point{ x: 0.0, y: -0.2, z: -0.2 }

    f0 = face(loop(edge(p0,p1), edge(p1,p3), edge(p3,p2), edge(p2,p0)))
    f1 = face(loop(edge(p2,p3), edge(p3,p5), edge(p5,p4), edge(p4,p2)))
    f2 = face(loop(edge(p4,p5), edge(p5,p7), edge(p7,p6), edge(p6,p4)))
    // The twist: reconnecting back to (p1, p0) inverted instead of (p0, p1)
    f3 = face(loop(edge(p6,p7), edge(p7,p0), edge(p0,p1), edge(p1,p6)))
}

```

The twist does not emerge from a continuous rotation matrix or an imperative sweep command. It exists because the causal connectivity graph swaps its terminal bindings (`edge(p0,p1)` versus `edge(p1,p0)`). The geometric surface is a direct consequence of topological declaration.
*Drafting in progress...*
