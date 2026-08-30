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
const STATUS_PRIORITY = [_][]const u8{ "Implemented", "Partial", "Spec Only" };

const IMAGE_DIR = "docs/generated/linear/images";

const IssueSections = struct {
    software_notes: []const u8,
    reference: []const u8,
};

const LinearIssue = struct {
    identifier: []const u8,
    title: []const u8,
    description: []const u8,
    labels: []const []const u8,
    workflow_state: []const u8,
};

const SectionKey = struct {
    parts: []const usize,
    has_section: bool,
};

const SortEntry = struct { key: SectionKey, identifier: []const u8, title: []const u8, labels: []const []const u8 };

/// Scan markdown for ![label](https://uploads.linear.app/...) image
/// links, download each (authenticated) into a shared pool keyed by
/// the alt-text label, and rewrite the markdown to point at the local
/// relative path — so the same figure referenced from multiple issues
/// is only ever fetched/stored once, and generated docs render
/// standalone on GitHub without a Linear session.
///
/// Convention: when pasting an image into a Linear issue description,
/// set its alt text to the figure's stable label (e.g. "fig_12_1") —
/// that's what becomes the pool key and local filename.
fn localizeImages(
    allocator: std.mem.Allocator,
    io: std.Io,
    client: *std.http.Client,
    api_key: []const u8,
    markdown: []const u8,
) ![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var pos: usize = 0;

    while (std.mem.indexOfPos(u8, markdown, pos, "![")) |bang_idx| {
        // copy everything up to this point verbatim
        try out.appendSlice(allocator, markdown[pos..bang_idx]);

        const label_start = bang_idx + 2;
        const label_end = std.mem.indexOfPos(u8, markdown, label_start, "](") orelse {
            // malformed — bail, copy rest verbatim
            try out.appendSlice(allocator, markdown[bang_idx..]);
            pos = markdown.len;
            break;
        };
        const label = markdown[label_start..label_end];

        const url_start = label_end + 2;
        const url_end = std.mem.indexOfPos(u8, markdown, url_start, ")") orelse {
            try out.appendSlice(allocator, markdown[bang_idx..]);
            pos = markdown.len;
            break;
        };
        const url = markdown[url_start..url_end];

        if (std.mem.indexOf(u8, url, "uploads.linear.app") != null) {
            const ext = std.fs.path.extension(label); // e.g. ".jpg" from "fig_12_1.jpg"
            const stem = label[0 .. label.len - ext.len]; // "fig_12_1"
            const local_path = try std.fmt.allocPrint(allocator, "{s}/{s}{s}", .{ IMAGE_DIR, stem, ext });

            // fetch once per label — skip if already downloaded this run
            const already_exists = fileExists(io, local_path);
            if (!already_exists) {
                try downloadImage(allocator, io, client, api_key, url, local_path);
                std.debug.print("  fetched image: {s}\n", .{label});
            }

            const rel_path = try std.fmt.allocPrint(allocator, "./images/{s}{s}", .{ stem, ext });
            try out.appendSlice(allocator, "![");
            try out.appendSlice(allocator, label);
            try out.appendSlice(allocator, "](");
            try out.appendSlice(allocator, rel_path);
            try out.appendSlice(allocator, ")");
        } else {
            // not a Linear-hosted image — leave untouched
            try out.appendSlice(allocator, markdown[bang_idx .. url_end + 1]);
        }

        pos = url_end + 1;
    }

    try out.appendSlice(allocator, markdown[pos..]);
    return out.toOwnedSlice(allocator);
}

fn fileExists(io: std.Io, path: []const u8) bool {
    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}

fn downloadImage(
    allocator: std.mem.Allocator,
    io: std.Io,
    client: *std.http.Client,
    api_key: []const u8,
    url: []const u8,
    local_path: []const u8,
) !void {
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    var response_writer: std.Io.Writer.Allocating = .fromArrayList(allocator, &body);

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = api_key },
        },
        .response_writer = &response_writer.writer,
    }) catch |err| {
        std.debug.print("  image fetch failed for {s}: {s}\n", .{ url, @errorName(err) });
        return;
    };

    if (result.status != .ok) {
        std.debug.print("  image fetch returned status {d} for {s}\n", .{ @intFromEnum(result.status), url });
        return;
    }

    body = response_writer.toArrayList();

    var file = try std.Io.Dir.cwd().createFile(io, local_path, .{});
    defer file.close(io);
    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try writer.interface.writeAll(body.items);
    try writer.interface.flush();
}

/// Resolve an issue's implementation status from its labels, applying
/// the agreed priority order. Returns null if none of the three status
/// labels are present — "not started" is left implicit, not its own tag.
fn resolveStatus(labels: []const []const u8) ?[]const u8 {
    for (STATUS_PRIORITY) |status| {
        for (labels) |label| {
            if (std.mem.eql(u8, label, status)) return status;
        }
    }
    return null;
}

fn hasLabel(labels: []const []const u8, name: []const u8) bool {
    for (labels) |label| {
        if (std.mem.eql(u8, label, name)) return true;
    }
    return false;
}

fn statusBadge(status: ?[]const u8) []const u8 {
    const s = status orelse return "⬜ Not started";
    if (std.mem.eql(u8, s, "Implemented")) return "✅ Implemented";
    if (std.mem.eql(u8, s, "Partial")) return "🟡 Partial";
    if (std.mem.eql(u8, s, "Spec Only")) return "⬛ Spec only";
    return "⬜ Not started";
}

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

    // Single HTTP client shared across the GraphQL fetch and any
    // subsequent image downloads — avoids reconnecting per request.
    var client: std.http.Client = .{ .allocator = arena, .io = io };
    defer client.deinit();

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
    const issues = try fetchIssues(arena, &client, api_key, project_name);
    try cleanOrphanedIssuePages(io, arena, issues);

    std.debug.print("  fetched {d} issues for project '{s}'\n", .{ issues.len, project_name });

    // --- 4. Bake each issue's Reference section into committed markdown ---
    // Io.Dir doesn't expose a recursive "makePath" under that name in this
    // build, so create each path segment explicitly rather than guess at
    // a renamed helper.
    try makeDirRecursive(io, "docs");
    try makeDirRecursive(io, "docs/generated");
    try makeDirRecursive(io, "docs/generated/linear");
    try makeDirRecursive(io, "docs/generated/linear/images");

    for (issues) |issue| {
        var sections = splitSections(issue.description);
        sections.software_notes = try localizeImages(arena, io, &client, api_key, sections.software_notes);
        sections.reference = try localizeImages(arena, io, &client, api_key, sections.reference);

        const status = resolveStatus(issue.labels);
        const badge = statusBadge(status);
        const needs_content = hasLabel(issue.labels, "Needs Content");

        const out_path = try std.fmt.allocPrint(arena, "docs/generated/linear/{s}.md", .{issue.identifier});
        var file = try std.Io.Dir.cwd().createFile(io, out_path, .{});
        defer file.close(io);

        var buffer: [8192]u8 = undefined;
        var writer = file.writer(io, &buffer);
        try writer.interface.print(
            "<!-- generated by weave from Linear issue {s} — do not hand-edit -->\n\n" ++
                "### {s}: {s}\n\n" ++
                "**Status:** {s}{s}\n\n" ++
                "## Software Notes\n\n{s}\n\n" ++
                "## Reference\n\n{s}\n",
            .{
                issue.identifier,
                issue.identifier,
                issue.title,
                badge,
                if (needs_content) "  |  📝 Needs content" else "",
                sections.software_notes,
                sections.reference,
            },
        );
        try writer.interface.flush();
    }

    try writeStatusManifest(io, issues);
    std.debug.print("Wrote status.json ({d} issues)\n", .{issues.len});

    var entries: std.ArrayListUnmanaged(SortEntry) = .empty;
    for (issues) |issue| {
        const key = try parseSectionKey(arena, issue.title);
        try entries.append(arena, .{ .key = key, .identifier = issue.identifier, .title = issue.title, .labels = issue.labels });
    }
    std.mem.sort(SortEntry, entries.items, {}, sectionLessThan);

    // --- Progress rollup (computed alongside the sort entries) ---
    var implemented_count: usize = 0;
    var partial_count: usize = 0;
    var spec_only_count: usize = 0;
    var not_started_count: usize = 0;
    for (issues) |issue| {
        const status = resolveStatus(issue.labels);
        if (status == null) {
            not_started_count += 1;
        } else if (std.mem.eql(u8, status.?, "Implemented")) {
            implemented_count += 1;
        } else if (std.mem.eql(u8, status.?, "Partial")) {
            partial_count += 1;
        } else {
            spec_only_count += 1;
        }
    }

    var index_file = try std.Io.Dir.cwd().createFile(io, "docs/generated/linear/index.md", .{});
    defer index_file.close(io);
    var index_buffer: [8192]u8 = undefined;
    var index_writer = index_file.writer(io, &index_buffer);
    try index_writer.interface.print(
        "<!-- generated by weave — reading order derived from title section numbers -->\n\n" ++
            "# Invocation Language — Reading Order\n\n" ++
            "## Progress\n\n" ++
            "✅ Implemented: {d}  |  🟡 Partial: {d}  |  ⬛ Spec only: {d}  |  ⬜ Not started: {d}  |  Total: {d}\n\n",
        .{ implemented_count, partial_count, spec_only_count, not_started_count, issues.len },
    );

    for (entries.items) |e| {
        const badge = statusBadge(resolveStatus(e.labels));
        try index_writer.interface.print("- {s} [{s}]({s}.md)\n", .{ badge, e.title, e.identifier });
    }

    try index_writer.interface.flush();

    std.debug.print("Wove {d} Linear issue references into docs/generated/linear/\n", .{issues.len});

    // Existing directive-fence scanning for figures etc. goes here, unchanged.
}

/// Fetch all issues for the named project via Linear's GraphQL API.
fn fetchIssues(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    api_key: []const u8,
    project_name: []const u8,
) ![]const LinearIssue {
    const query = try std.fmt.allocPrint(
        allocator,
        \\{{"query": "query {{ issues(filter: {{ project: {{ name: {{ eq: \"{s}\" }} }} }}, first: 200) {{ nodes {{ identifier title description labels {{ nodes {{ name }} }} state {{ name }} }} }} }}"}}
    ,
        .{project_name},
    );

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
        const workflow_state = try allocator.dupe(u8, node.object.get("state").?.object.get("name").?.string);

        var labels: std.ArrayListUnmanaged([]const u8) = .empty;
        const label_nodes = node.object.get("labels").?.object.get("nodes").?.array;
        for (label_nodes.items) |ln| {
            const name = try allocator.dupe(u8, ln.object.get("name").?.string);
            try labels.append(allocator, name);
        }

        try issues.append(allocator, .{ .identifier = identifier, .title = title, .description = description, .labels = try labels.toOwnedSlice(allocator), .workflow_state = workflow_state });
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

/// Remove any docs/generated/linear/TAG-*.md file whose issue no longer
/// exists in the current fetch. status.json and index.md are already
/// fully rebuilt from scratch every run — this is the one artifact
/// weave only ever creates/overwrites, never deletes, so a Linear
/// issue deletion previously left its stale .md page behind forever.
fn cleanOrphanedIssuePages(io: std.Io, allocator: std.mem.Allocator, issues: []const LinearIssue) !void {
    var live = std.StringHashMap(void).init(allocator);
    for (issues) |issue| {
        const filename = try std.fmt.allocPrint(allocator, "{s}.md", .{issue.identifier});
        try live.put(filename, {});
    }

    var dir = std.Io.Dir.cwd().openDir(io, "docs/generated/linear", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return, // nothing to clean on a fresh checkout
        else => return err,
    };
    defer dir.close(io);

    var it = dir.iterate();
    var to_delete: std.ArrayListUnmanaged([]const u8) = .empty;
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;
        if (std.mem.eql(u8, entry.name, "index.md")) continue; // fully regenerated separately
        if (live.contains(entry.name)) continue;
        try to_delete.append(allocator, try allocator.dupe(u8, entry.name));
    }

    for (to_delete.items) |name| {
        dir.deleteFile(io, name) catch |err| {
            std.debug.print("  warning: could not remove orphaned {s}: {s}\n", .{ name, @errorName(err) });
            continue;
        };
        std.debug.print("  removed orphaned page: {s}\n", .{name});
    }
}

/// Write docs/generated/linear/status.json — a committed manifest mapping
/// each issue to its implementation status (from the Implemented/Partial/
/// Spec Only labels), simulation request state, and Linear's native workflow
/// state. The example runner reads this file rather than querying Linear
/// directly, keeping example verification offline and deterministic like the
/// rest of weave.
///
/// Hand-written JSON rather than std.json.Stringify — that API has moved
/// under us before on this toolchain, and this shape is simple enough
/// not to be worth the risk of guessing at it again.
fn writeStatusManifest(io: std.Io, issues: []const LinearIssue) !void {
    var file = try std.Io.Dir.cwd().createFile(io, "docs/generated/linear/status.json", .{});
    defer file.close(io);

    var buffer: [16384]u8 = undefined;
    var writer = file.writer(io, &buffer);
    const w = &writer.interface;

    try w.writeAll("{\n");
    for (issues, 0..) |issue, i| {
        const impl_status = resolveStatus(issue.labels);
        const simulation_requested = hasLabel(issue.labels, "Simulation Requested");

        try w.print("  \"{s}\": {{\n", .{issue.identifier});
        try w.writeAll("    \"implementation_status\": ");
        if (impl_status) |s| {
            try w.print("\"{s}\"", .{s});
        } else {
            try w.writeAll("null");
        }
        try w.print(",\n    \"simulation_requested\": {s}", .{if (simulation_requested) "true" else "false"});
        try w.print(",\n    \"workflow_state\": \"{s}\"\n", .{issue.workflow_state});
        try w.writeAll(if (i + 1 < issues.len) "  },\n" else "  }\n");
    }
    try w.writeAll("}\n");
    try w.flush();
}
