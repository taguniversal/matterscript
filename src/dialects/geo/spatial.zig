//! ============================================================================
//! SPATIAL GRAPH & TOPOLOGICAL MESH LOWERING ENGINE (`spatial.zig`)
//! ============================================================================
//!
//! This module implements the internal spatial topology engine and compiler pass
//! primitives for MatterScript's `@spatial2d` and `@spatial3d` contexts.
//!
//! Rather than treating geometry as passive triangular mesh data or applying
//! runtime trigonometric matrix transforms, MatterScript models geometry as a
//! first-class, graph-based topological network. Spatial primitives map directly
//! into the compiler's association graph to express physical/virtual execution
//! domains, routing connectivity, and distance-bound latency constraints.
//!
//! ### Core Responsibilities & Architectural Boundaries
//!
//! 1. **Index-Based Arena Storage (`SpatialGraph`)**
//!    Provides arena-allocated, cache-friendly storage for fundamental topological
//!    primitives (`Point`, `Edge`, `Loop`, `Face`, `Volume`) using strong type handles
//!    (`PointId`, `EdgeId`, etc.) to ensure memory locality and deterministic ordering.
//!
//! 2. **Dimension & Topology Enforcement**
//!    Validates planar boundaries under `@spatial2d` contexts vs. 3D manifold/volume
//!    closure under `@spatial3d`. Enforces closed-loop invariants and topological
//!    continuity across declared spatial structures.
//!
//! 3. **Graph Channel Latency Synthesis**
//!    Calculates physical and virtual Euclidean distance deltas ($\Delta s = \|p_B - p_A\|$)
//!    across topological edges to synthesize deterministic propagation delays along
//!    communication channels without continuous matrix evaluations.
//!
//! 4. **Spatial Relationship Resolution**
//!    Provides static graph evaluation utilities for spatial neighborhood operators
//!    (`near`, `adjacent`, `within`, `intersects`) during compiler optimization pass
//!    and layout reduction steps.
//!
//! 5. **Triangulation Engine & MeshLab Interop Boundary**
//!    Acts as the strict lower boundary for visual interop and external CAD tools.
//!    Lowers topological faces and loops into discrete planar triangular meshes
//!    (`TriangulatedMesh`) and serializes them into standard Little-Endian Binary `.ply`
//!    format for downstream processing by MeshLab, Blender, or OpenSCAD.
//!
//! ============================================================================
//!
const std = @import("std");
const Allocator = std.mem.Allocator;

/// Handles referencing entities in the Spatial Graph Arena
pub const PointId = enum(u32) { _ };
pub const EdgeId = enum(u32) { _ };
pub const LoopId = enum(u32) { _ };
pub const FaceId = enum(u32) { _ };
pub const VolumeId = enum(u32) { _ };

pub const SpatialGraph = struct {
    allocator: Allocator,
    dim: SpatialDimension,

    points: std.ArrayListUnmanaged(Point),
    edges: std.ArrayListUnmanaged(Edge),
    loops: std.ArrayListUnmanaged(Loop),
    faces: std.ArrayListUnmanaged(Face),
    volumes: std.ArrayListUnmanaged(Volume),

    pub fn init(allocator: Allocator, dim: SpatialDimension) SpatialGraph {
        return .{
            .allocator = allocator,
            .dim = dim,
            .points = .empty,
            .edges = .empty,
            .loops = .empty,
            .faces = .empty,
            .volumes = .empty,
        };
    }

    pub fn deinit(self: *SpatialGraph) void {
        self.points.deinit(self.allocator);
        self.edges.deinit(self.allocator);
        for (self.loops.items) |*l| l.edges.deinit(self.allocator);
        self.loops.deinit(self.allocator);
        for (self.faces.items) |*f| f.inner_holes.deinit(self.allocator);
        self.faces.deinit(self.allocator);
        for (self.volumes.items) |*v| v.faces.deinit(self.allocator);
        self.volumes.deinit(self.allocator);
    }
};

pub const SpatialDimension = enum {
    spatial2d,
    spatial3d,
};

pub const Vector3 = struct {
    x: f64,
    y: f64,
    z: f64 = 0.0,

    pub fn distance(a: Vector3, b: Vector3) f64 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

/// 1. Point: Spatial coordinate anchor & channel endpoint
pub const Point = struct {
    id: PointId,
    coords: Vector3,
};

/// 2. Edge: Directed topological channel with inherent latency delta
pub const Edge = struct {
    id: EdgeId,
    start: PointId,
    end: PointId,

    /// Returns physical distance delta (ds) used for latency synthesis
    pub fn length(self: Edge, graph: *const SpatialGraph) f64 {
        const p1 = graph.points.items[@intFromEnum(self.start)].coords;
        const p2 = graph.points.items[@intFromEnum(self.end)].coords;
        return p1.distance(p2);
    }
};

/// 3. Loop: Ordered closed cycle of directed edges
pub const Loop = struct {
    id: LoopId,
    edges: std.ArrayListUnmanaged(EdgeId),
};

/// 4. Face: 2D Manifold defined by boundary loops
pub const Face = struct {
    id: FaceId,
    outer_loop: LoopId,
    inner_holes: std.ArrayListUnmanaged(LoopId),
};

/// 5. Volume: Enclosed 3D spatial execution domain
pub const Volume = struct {
    id: VolumeId,
    faces: std.ArrayListUnmanaged(FaceId),
};

/// Triangle output structure for visual lowering (PLY / OBJ / MeshLab)
pub const Triangle = struct {
    v0: PointId,
    v1: PointId,
    v2: PointId,
};

pub const TriangulatedMesh = struct {
    vertices: std.ArrayListUnmanaged(Vector3),
    indices: std.ArrayListUnmanaged([3]u32),

    pub fn deinit(self: *TriangulatedMesh, allocator: Allocator) void {
        self.vertices.deinit(allocator);
        self.indices.deinit(allocator);
    }
};

pub fn addPoint(graph: *SpatialGraph, coords: Vector3) !PointId {
    if (graph.dim == .spatial2d and coords.z != 0.0) {
        return error.InvalidDimensionFor2DContext;
    }
    const id: PointId = @enumFromInt(@as(u32, @intCast(graph.points.items.len)));
    try graph.points.append(graph.allocator, .{ .id = id, .coords = coords });
    return id;
}

pub fn addEdge(graph: *SpatialGraph, start: PointId, end: PointId) !EdgeId {
    const id: EdgeId = @enumFromInt(@as(u32, @intCast(graph.edges.items.len)));
    try graph.edges.append(graph.allocator, .{ .id = id, .start = start, .end = end });
    return id;
}

/// Validates if a list of edges forms a closed loop end-to-end
pub fn validateLoopClosure(graph: *const SpatialGraph, edge_ids: []const EdgeId) !void {
    if (edge_ids.len < 3) return error.DegenerateLoop;

    var current_end = graph.edges.items[@intFromEnum(edge_ids[0])].end;
    for (edge_ids[1..]) |e_id| {
        const edge = graph.edges.items[@intFromEnum(e_id)];
        if (@intFromEnum(edge.start) != @intFromEnum(current_end)) {
            return error.DiscontinuousLoop;
        }
        current_end = edge.end;
    }

    const first_start = graph.edges.items[@intFromEnum(edge_ids[0])].start;
    if (@intFromEnum(current_end) != @intFromEnum(first_start)) {
        return error.UnclosedLoop;
    }
}

/// Triangulates all faces in the SpatialGraph into a standard triangular mesh
pub fn triangulate(graph: *const SpatialGraph, allocator: Allocator) !TriangulatedMesh {
    var mesh = TriangulatedMesh{ .vertices = .empty, .indices = .empty };

    // Copy point positions
    for (graph.points.items) |pt| {
        try mesh.vertices.append(allocator, pt.coords);
    }

    // Ear-clipping / Fan triangulation pass over planar faces
    for (graph.faces.items) |face| {
        const loop = graph.loops.items[@intFromEnum(face.outer_loop)];
        if (loop.edges.items.len < 3) continue;

        const first_edge = graph.edges.items[@intFromEnum(loop.edges.items[0])];
        const root_pt = @intFromEnum(first_edge.start);

        var i: usize = 1;
        while (i < loop.edges.items.len - 1) : (i += 1) {
            const e1 = graph.edges.items[@intFromEnum(loop.edges.items[i])];
            const e2 = graph.edges.items[@intFromEnum(loop.edges.items[i + 1])];

            try mesh.indices.append(allocator, .{
                @intCast(root_pt),
                @intCast(@intFromEnum(e1.start)),
                @intCast(@intFromEnum(e2.start)),
            });
        }
    }

    return mesh;
}

/// Writes the lower triangulated mesh out to standard Binary PLY format for MeshLab
pub fn exportPly(mesh: *const TriangulatedMesh, writer: *std.Io.Writer) !void {
    try writer.print("ply\nformat binary_little_endian 1.0\n", .{});
    try writer.print("element vertex {}\n", .{mesh.vertices.items.len});
    try writer.print("property float x\nproperty float y\nproperty float z\n", .{});
    try writer.print("element face {}\n", .{mesh.indices.items.len});
    try writer.print("property list uchar int vertex_indices\nend_header\n", .{});

    // Write binary vertex data
    for (mesh.vertices.items) |v| {
        const x: f32 = @floatCast(v.x);
        const y: f32 = @floatCast(v.y);
        const z: f32 = @floatCast(v.z);
        try writer.writeAll(std.mem.asBytes(&x));
        try writer.writeAll(std.mem.asBytes(&y));
        try writer.writeAll(std.mem.asBytes(&z));
    }

    // Write binary face index data
    for (mesh.indices.items) |idx| {
        const count: u8 = 3;
        try writer.writeByte(count);
        const idx0: i32 = @intCast(idx[0]);
        const idx1: i32 = @intCast(idx[1]);
        const idx2: i32 = @intCast(idx[2]);
        try writer.writeAll(std.mem.asBytes(&idx0));
        try writer.writeAll(std.mem.asBytes(&idx1));
        try writer.writeAll(std.mem.asBytes(&idx2));
    }
}

// Inverse of exportPly, above. Deliberately narrow: this parses exactly
// the fixed header shape and binary layout exportPly itself produces
// (binary_little_endian, float xyz, uchar-prefixed int triangle lists)
// — it is not a general-purpose PLY reader. Its purpose is round-trip
// verification of our own serialization, not reading arbitrary PLY
// files from other tools.
pub fn importPly(allocator: Allocator, bytes: []const u8) !TriangulatedMesh {
    const header_marker = "end_header\n";
    const header_end = std.mem.indexOf(u8, bytes, header_marker) orelse
        return error.InvalidPlyHeader;
    const header_text = bytes[0..header_end];
    var payload = bytes[header_end + header_marker.len ..];

    var vertex_count: ?usize = null;
    var face_count: ?usize = null;

    var lines = std.mem.splitScalar(u8, header_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "element vertex ")) {
            vertex_count = try std.fmt.parseInt(usize, line["element vertex ".len..], 10);
        } else if (std.mem.startsWith(u8, line, "element face ")) {
            face_count = try std.fmt.parseInt(usize, line["element face ".len..], 10);
        }
    }

    const vcount = vertex_count orelse return error.MissingVertexElement;
    const fcount = face_count orelse return error.MissingFaceElement;

    var mesh = TriangulatedMesh{ .vertices = .empty, .indices = .empty };
    errdefer mesh.deinit(allocator);

    const vertex_bytes = vcount * 12; // 3 x f32
    if (payload.len < vertex_bytes) return error.UnexpectedEndOfData;

    var offset: usize = 0;
    for (0..vcount) |_| {
        const x: f32 = @bitCast(std.mem.readInt(u32, payload[offset..][0..4], .little));
        const y: f32 = @bitCast(std.mem.readInt(u32, payload[offset + 4 ..][0..4], .little));
        const z: f32 = @bitCast(std.mem.readInt(u32, payload[offset + 8 ..][0..4], .little));
        offset += 12;
        try mesh.vertices.append(allocator, .{ .x = x, .y = y, .z = z });
    }

    for (0..fcount) |_| {
        if (offset >= payload.len) return error.UnexpectedEndOfData;
        const count = payload[offset];
        offset += 1;
        if (count != 3) return error.UnsupportedFaceArity; // exportPly always writes triangles
        if (offset + 12 > payload.len) return error.UnexpectedEndOfData;

        const idx0: i32 = std.mem.readInt(i32, payload[offset..][0..4], .little);
        const idx1: i32 = std.mem.readInt(i32, payload[offset + 4 ..][0..4], .little);
        const idx2: i32 = std.mem.readInt(i32, payload[offset + 8 ..][0..4], .little);
        offset += 12;

        try mesh.indices.append(allocator, .{
            @intCast(idx0), @intCast(idx1), @intCast(idx2),
        });
    }
    payload = payload[offset..];

    return mesh;
}

/// Evaluates spatial relationship constraint: within(distance)
pub fn isWithinDistance(graph: *const SpatialGraph, p1: PointId, p2: PointId, max_dist: f64) bool {
    const pt1 = graph.points.items[@intFromEnum(p1)].coords;
    const pt2 = graph.points.items[@intFromEnum(p2)].coords;
    return Vector3.distance(pt1, pt2) <= max_dist;
}

/// Computes edge distance delta for deterministic signal propagation delay
pub fn calculateChannelLatency(graph: *const SpatialGraph, edge_id: EdgeId, velocity: f64) f64 {
    const edge = graph.edges.items[@intFromEnum(edge_id)];
    return edge.length(graph) / velocity;
}

pub fn addLoop(graph: *SpatialGraph, edge_ids: []const EdgeId) !LoopId {
    // Validates that edges form a continuous closed loop
    try validateLoopClosure(graph, edge_ids);

    const id: LoopId = @enumFromInt(@as(u32, @intCast(graph.loops.items.len)));
    var loop = Loop{ .id = id, .edges = .empty };
    try loop.edges.appendSlice(graph.allocator, edge_ids);
    try graph.loops.append(graph.allocator, loop);
    return id;
}

pub fn addFace(graph: *SpatialGraph, outer_loop: LoopId) !FaceId {
    const id: FaceId = @enumFromInt(@as(u32, @intCast(graph.faces.items.len)));
    try graph.faces.append(graph.allocator, .{
        .id = id,
        .outer_loop = outer_loop,
        .inner_holes = .empty,
    });
    return id;
}
