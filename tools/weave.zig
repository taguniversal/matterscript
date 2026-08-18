// weave.zig
// Fetches issue content from Linear via GraphQL and bakes it into
// committed markdown as source material for the reference docs.
//
// Per the project's deterministic/reproducible philosophy: this is a
// weave-time fetch-and-bake step, not a live runtime dependency. Once
// woven, the output is committed markdown — docs don't require network
// access or a Linear API key to read or rebuild downstream.

const std = @import("std");

const LINEAR_ENDPOINT = "https://api.linear.app/graphql";
const SOFTWARE_NOTES_MARKER = "## Software Notes";
const REFERENCE_MARKER = "## Reference";
const NOT_YET_WRITTEN = "_(not yet written)_";

const IssueSections = struct {
    software_notes: []const u8,
    reference: []const u8,
};

const LinearIssue = struct {
    identifier: []const u8,
    title: []const u8,
    description: []const u8, // raw markdown, includes ## Reference section
};

const SectionKey = struct {
    parts: []const usize,
    has_section: bool,
};

const SortEntry = struct {
    key: SectionKey,
    identifier: []const u8,
    title: []const u8,
};

/// Parse a leading dotted numeric prefix off a title, e.g.
/// "12.5.3 Conditional Completeness" -> { parts = [12, 5, 3] }.
/// Titles without a recognizable prefix (implementation work items
/// like the NuttX/MeshLab issues) come back with has_section = false.
fn parseSectionKey(allocator: std.mem.Allocator, title: []const u8) !SectionKey {
    var end: usize = 0;
    while (end < title.len and (std.ascii.isDigit(title[end]) or title[end] == '.')) : (end += 1) {}
    if (end == 0) return .{ .parts = &.{}, .has_section = false };

    var parts: std.ArrayListUnmanaged(usize) = .empty;
    var it = std.mem.splitScalar(u8, title[0..end], '.');
    while (it.next()) |piece| {
        if (piece.len == 0) continue;
        const n = std.fmt.parseInt(usize, piece, 10) catch continue;
        try parts.append(allocator, n);
    }
    if (parts.items.len == 0) return .{ .parts = &.{}, .has_section = false };
    return .{ .parts = try parts.toOwnedSlice(allocator), .has_section = true };
}

/// Numeric, element-wise comparison — avoids the "12.10" < "12.2"
/// string-sort trap. Unsectioned issues sort after all sectioned ones.
fn sectionLessThan(_: void, a: SortEntry, b: SortEntry) bool {
    if (!a.key.has_section and !b.key.has_section) return std.mem.lessThan(u8, a.identifier, b.identifier);
    if (!a.key.has_section) return false;
    if (!b.key.has_section) return true;

    const len = @min(a.key.parts.len, b.key.parts.len);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        if (a.key.parts[i] != b.key.parts[i]) return a.key.parts[i] < b.key.parts[i];
    }
    return a.key.parts.len < b.key.parts.len;
}

/// Split an issue description into its Software Notes and Reference
/// sections. Software Notes runs from its heading to wherever Reference
/// starts (or end of string if Reference is absent). Reference runs from
/// its heading to end of string. If a heading is missing, or present but
/// empty, the corresponding field is the NOT_YET_WRITTEN placeholder —
/// distinguishing "not written yet" from a parsing failure.
fn splitSections(description: []const u8) IssueSections {
    const sw_idx = std.mem.indexOf(u8, description, SOFTWARE_NOTES_MARKER);
    const ref_idx = std.mem.indexOf(u8, description, REFERENCE_MARKER);

    var software_notes: []const u8 = NOT_YET_WRITTEN;
    if (sw_idx) |si| {
        const content_start = si + SOFTWARE_NOTES_MARKER.len;
        const content_end = ref_idx orelse description.len;
        if (content_end > content_start) {
            const trimmed = std.mem.trim(u8, description[content_start..content_end], " \t\r\n");
            if (trimmed.len > 0) software_notes = trimmed;
        }
    }

    var reference: []const u8 = NOT_YET_WRITTEN;
    if (ref_idx) |ri| {
        const content_start = ri + REFERENCE_MARKER.len;
        const trimmed = std.mem.trim(u8, description[content_start..], " \t\r\n");
        if (trimmed.len > 0) reference = trimmed;
    }

    return .{ .software_notes = software_notes, .reference = reference };
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    std.debug.print("Weaving documentation and visual assets...\n", .{});
    std.debug.print("  args: {d}\n", .{args.len});

    // --- 1. Read API key from environment ---
    const api_key = init.environ_map.get("LINEAR_API_KEY") orelse {
        std.debug.print("LINEAR_API_KEY not set — skipping Linear fetch, weaving local docs only.\n", .{});
        return;
    };

    // --- 2. Parse args for project name (default: MatterScript) ---
    var project_name: []const u8 = "MatterScript";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--project") and i + 1 < args.len) {
            project_name = args[i + 1];
        }
    }

    // --- 3. Fetch issues ---
    const issues = try fetchIssues(arena, io, api_key, project_name);
    std.debug.print("  fetched {d} issues for project '{s}'\n", .{ issues.len, project_name });

    // --- 4. Bake each issue's Reference section into committed markdown ---
    // Io.Dir doesn't expose a recursive "makePath" under that name in this
    // build, so create each path segment explicitly rather than guess at
    // a renamed helper.
    try makeDirRecursive(io, "docs");
    try makeDirRecursive(io, "docs/generated");
    try makeDirRecursive(io, "docs/generated/linear");

    for (issues) |issue| {
        const sections = splitSections(issue.description);
        const out_path = try std.fmt.allocPrint(
            arena,
            "docs/generated/linear/{s}.md",
            .{issue.identifier},
        );

        var file = try std.Io.Dir.cwd().createFile(io, out_path, .{});
        defer file.close(io);

        var buffer: [8192]u8 = undefined;
        var writer = file.writer(io, &buffer);
        try writer.interface.print(
            "<!-- generated by weave from Linear issue {s} — do not hand-edit -->\n\n" ++
                "### {s}: {s}\n\n" ++
                "## Software Notes\n\n{s}\n\n" ++
                "## Reference\n\n{s}\n",
            .{
                issue.identifier,
                issue.identifier,
                issue.title,
                sections.software_notes,
                sections.reference,
            },
        );
        try writer.interface.flush();
    }

    var entries: std.ArrayListUnmanaged(SortEntry) = .empty;
    for (issues) |issue| {
        const key = try parseSectionKey(arena, issue.title);
        try entries.append(arena, .{ .key = key, .identifier = issue.identifier, .title = issue.title });
    }
    std.mem.sort(SortEntry, entries.items, {}, sectionLessThan);

    var index_file = try std.Io.Dir.cwd().createFile(io, "docs/generated/linear/index.md", .{});
    defer index_file.close(io);
    var index_buffer: [8192]u8 = undefined;
    var index_writer = index_file.writer(io, &index_buffer);
    try index_writer.interface.print("<!-- generated by weave — reading order derived from title section numbers -->\n\n# Invocation Language — Reading Order\n\n", .{});
    for (entries.items) |e| {
        try index_writer.interface.print("- [{s}]({s}.md)\n", .{ e.title, e.identifier });
    }
    try index_writer.interface.flush();

    std.debug.print("Wove {d} Linear issue references into docs/generated/linear/\n", .{issues.len});

    // Existing directive-fence scanning for figures etc. goes here, unchanged.
}

/// Fetch all issues for the named project via Linear's GraphQL API.
fn fetchIssues(
    allocator: std.mem.Allocator,
    io: std.Io,
    api_key: []const u8,
    project_name: []const u8,
) ![]const LinearIssue {
    const query = try std.fmt.allocPrint(
        allocator,
        \\{{"query": "query {{ issues(filter: {{ project: {{ name: {{ eq: \"{s}\" }} }} }}, first: 100) {{ nodes {{ identifier title description }} }} }}"}}
    ,
        .{project_name},
    );

    // zig-dev-0.17: Client now requires an .io field (HTTP was reworked
    // to depend only on std.Io streams, not networking directly).
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();

    // response_storage is gone — responses now stream into a caller-
    // supplied writer. Wrap an ArrayList via Writer.Allocating so we
    // still end up with the full body as a slice afterward.
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    var response_writer: std.Io.Writer.Allocating = .fromArrayList(allocator, &body);

    const result = client.fetch(.{
        .location = .{ .url = LINEAR_ENDPOINT },
        .method = .POST,
        .headers = .{
            .content_type = .{ .override = "application/json" },
        },
        .extra_headers = &.{
            .{ .name = "Authorization", .value = api_key },
        },
        .payload = query,
        .response_writer = &response_writer.writer,
    }) catch |err| {
        std.debug.print("Linear fetch failed: {s}\n", .{@errorName(err)});
        return error.LinearFetchFailed;
    };

    if (result.status != .ok) {
        std.debug.print("Linear API returned status {d}\n", .{@intFromEnum(result.status)});
        return error.LinearFetchFailed;
    }

    body = response_writer.toArrayList();
    return try parseIssuesResponse(allocator, body.items);
}

/// Parse the GraphQL response body into a slice of LinearIssue.
fn parseIssuesResponse(allocator: std.mem.Allocator, body: []const u8) ![]const LinearIssue {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const nodes = parsed.value.object.get("data").?
        .object.get("issues").?
        .object.get("nodes").?
        .array;

    var issues: std.ArrayListUnmanaged(LinearIssue) = .empty;
    for (nodes.items) |node| {
        const identifier = try allocator.dupe(u8, node.object.get("identifier").?.string);
        const title = try allocator.dupe(u8, node.object.get("title").?.string);
        const description = try allocator.dupe(u8, node.object.get("description").?.string);
        try issues.append(allocator, .{
            .identifier = identifier,
            .title = title,
            .description = description,
        });
    }
    return issues.toOwnedSlice(allocator);
}

/// Create a directory, tolerating the case where it already exists.
/// Used in place of a recursive "make path" helper whose current name
/// under std.Io.Dir isn't confirmed for this toolchain build.
fn makeDirRecursive(io: std.Io, path: []const u8) !void {
    std.Io.Dir.cwd().createDir(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
