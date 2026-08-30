// Linear: TAG-112 

const std = @import("std");

/// Opaque handles representing ID references within a Geometric Context
pub const PointId = usize;
pub const EdgeId = usize;
pub const LoopId = usize;
pub const FaceId = usize;
pub const VolumeId = usize;
pub const GroupId = usize;

/// 1. Point: A place in 3D space with optional spatial metadata
pub const Point = struct {
    x: f64,
    y: f64,
    z: f64,
};

/// 2. Edge: Causal directional relationship connecting two points
pub const Edge = struct {
    p1: PointId,
    p2: PointId,
};

/// 3. Loop: Closed ordered sequence of edges defining a boundary
pub const Loop = struct {
    edges: []const EdgeId,
};

/// 4. Face: Surface bounded by an outer loop and optional inner hole loops
pub const Face = struct {
    outer_loop: LoopId,
    holes: []const LoopId = &[_]LoopId{},
};

/// 5. Volume: Enclosed spatial region defined by bounding faces
pub const Volume = struct {
    top: FaceId,
    bottom: FaceId,
    sides: []const FaceId,
};

/// Tagged union representing any single topological node
pub const GeoNode = union(enum) {
    point: Point,
    edge: Edge,
    loop: Loop,
    face: Face,
    volume: Volume,
    group: Group,
};

/// 6. Group: Hierarchical composition of spatial primitives or nested groups
pub const Group = struct {
    name: []const u8 = "",
    children: []const GeoNodeHandle,
};

/// Flexible handle pointing to any element in the spatial graph
pub const GeoNodeHandle = struct {
    id: usize,
    kind: std.meta.Tag(GeoNode),
};

/// Arena-allocated container storing the complete spatial relationship graph
pub const GeoContext = struct {
    allocator: std.mem.Allocator,

    points: std.ArrayListUnmanaged(Point) = .{},
    edges: std.ArrayListUnmanaged(Edge) = .{},
    loops: std.ArrayListUnmanaged(Loop) = .{},
    faces: std.ArrayListUnmanaged(Face) = .{},
    volumes: std.ArrayListUnmanaged(Volume) = .{},
    groups: std.ArrayListUnmanaged(Group) = .{},

    pub fn init(allocator: std.mem.Allocator) GeoContext {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *GeoContext) void {
        self.points.deinit(self.allocator);
        self.edges.deinit(self.allocator);
        for (self.loops.items) |l| self.allocator.free(l.edges);
        self.loops.deinit(self.allocator);
        for (self.faces.items) |f| self.allocator.free(f.holes);
        self.faces.deinit(self.allocator);
        for (self.volumes.items) |v| self.allocator.free(v.sides);
        self.volumes.deinit(self.allocator);
        for (self.groups.items) |g| self.allocator.free(g.children);
        self.groups.deinit(self.allocator);
    }

    pub fn addPoint(self: *GeoContext, x: f64, y: f64, z: f64) !PointId {
        const id = self.points.items.len;
        try self.points.append(self.allocator, .{ .x = x, .y = y, .z = z });
        return id;
    }

    pub fn addEdge(self: *GeoContext, p1: PointId, p2: PointId) !EdgeId {
        const id = self.edges.items.len;
        try self.edges.append(self.allocator, .{ .p1 = p1, .p2 = p2 });
        return id;
    }

    pub fn addLoop(self: *GeoContext, edge_ids: []const EdgeId) !LoopId {
        const id = self.loops.items.len;
        const owned_edges = try self.allocator.dupe(EdgeId, edge_ids);
        try self.loops.append(self.allocator, .{ .edges = owned_edges });
        return id;
    }

    pub fn addFace(self: *GeoContext, outer: LoopId, holes: []const LoopId) !FaceId {
        const id = self.faces.items.len;
        const owned_holes = try self.allocator.dupe(LoopId, holes);
        try self.faces.append(self.allocator, .{ .outer_loop = outer, .holes = owned_holes });
        return id;
    }
};