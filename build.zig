const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ------------------------------------------------------------------------
    // 1. Build the Tangle Helper Executable
    // ------------------------------------------------------------------------
    const tangle_exe = b.addExecutable(.{
        .name = "tangle",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/tangle.zig"),
            .target = b.graph.host, // Compile for the host machine running the build
            .optimize = .Debug,
        }),
    });

    // Run the tangle executable as a build step
    const run_tangle = b.addRunArtifact(tangle_exe);
    run_tangle.addArgs(&[_][]const u8{ "--input", "docs/", "--output", "src/generated/" });

    // Explicit step for `zig build tangle`
    const tangle_step = b.step("tangle", "Extract code blocks from documentation");
    tangle_step.dependOn(&run_tangle.step);

    const mod = b.addModule("matterscript", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mkrand_mod = b.addModule("mkrand", .{
        .root_source_file = b.path("../mkrand/src/mkrand.zig"),
        .target = target,
    });

    mod.addImport("mkrand", mkrand_mod);

    const exe = b.addExecutable(.{
        .name = "matterscript",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "matterscript", .module = mod },
                .{ .name = "mkrand", .module = mkrand_mod },
            },
        }),
    });

    // CRITICAL: Ensure tangle runs BEFORE compiling the main program
    exe.step.dependOn(&run_tangle.step);

    b.installArtifact(exe);

    // ------------------------------------------------------------------------
    // 3. Build the Weave Helper Executable
    // ------------------------------------------------------------------------
    const weave_exe = b.addExecutable(.{
        .name = "weave",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/weave.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_weave = b.addRunArtifact(weave_exe);
    run_weave.addArgs(&[_][]const u8{ "--docs-dir", "docs/", "--output-dir", "dist/docs/" });

    const weave_step = b.step("weave", "Build documentation and visual assets");
    weave_step.dependOn(&run_weave.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // ------------------------------------------------------------
    // Verify pipeline
    // ------------------------------------------------------------
    // 1. Generate machine.vhd from coffee FSM example
    // 2. Generate add.vhd from add IL example
    // 3. GHDL syntax check both
    // ------------------------------------------------------------

    const verify_step = b.step("verify", "Generate VHDL and syntax check with GHDL");

    // --- FSM: coffee ---
    const gen_coffee = b.addRunArtifact(exe);
    gen_coffee.addArg("examples/coffee/coffee.ms.fsm");
    gen_coffee.step.dependOn(b.getInstallStep());
    verify_step.dependOn(&gen_coffee.step);

    const ghdl_coffee = b.addSystemCommand(&.{
        "ghdl", "-s", "--std=08", "../workspace/coffee/machine.vhd",
    });
    ghdl_coffee.step.dependOn(&gen_coffee.step);
    verify_step.dependOn(&ghdl_coffee.step);

    // --- IL: add ---
    const gen_add = b.addRunArtifact(exe);
    gen_add.addArg("examples/add/add.ms.ipl");
    gen_add.step.dependOn(b.getInstallStep());
    verify_step.dependOn(&gen_add.step);

    const ghdl_add = b.addSystemCommand(&.{
        "ghdl", "-s", "--std=08", "../workspace/add/add.vhd",
    });
    ghdl_add.step.dependOn(&gen_add.step);
    verify_step.dependOn(&ghdl_add.step);

    // ------------------------------------------------------------
    // Simulate pipeline (Linux only)
    // ------------------------------------------------------------
    // 1. ghdl -a  — analyze VHDL
    // 2. ghdl --synth — export to Verilog netlist
    // 3. verilator  — compile with C++ testbench to native binary
    // 4. run the simulation binary
    // ------------------------------------------------------------

    const simulate_step = b.step("simulate", "Full GHDL->Verilator simulation (Linux only)");

    const is_linux = b.graph.host.result.os.tag == .linux;
    if (is_linux) {
        const ghdl_analyze = b.addSystemCommand(&.{
            "ghdl-llvm",                     "-a",                              "--std=08",
            "--workdir=../workspace/coffee", "../workspace/coffee/machine.vhd",
        });
        ghdl_analyze.step.dependOn(&gen_coffee.step);

        const ghdl_synth = b.addSystemCommand(&.{
            "sh",                                                                                                                  "-c",
            "ghdl-llvm synth --std=08 --workdir=../workspace/coffee --out=verilog CoffeeShop > ../workspace/coffee/CoffeeShop.sv",
        });
        ghdl_synth.step.dependOn(&ghdl_analyze.step);

        const verilator_build = b.addSystemCommand(&.{
            "verilator",
            "--cc",
            "--exe",
            "--build",
            "--Mdir",
            "../workspace/coffee/obj_dir",
            "-CFLAGS",
            "-I.",
            "../workspace/coffee/CoffeeShop.sv",
            "../workspace/coffee/tb_machine.cpp",
        });
        verilator_build.step.dependOn(&ghdl_synth.step);

        const run_sim = b.addSystemCommand(&.{
            "../workspace/coffee/obj_dir/VCoffeeShop",
        });
        run_sim.step.dependOn(&verilator_build.step);

        simulate_step.dependOn(&run_sim.step);
    } else {
        const note = b.addSystemCommand(&.{
            "cmd", "/c", "echo", "Simulate step is Linux only",
        });
        simulate_step.dependOn(&note.step);
    }

    // ------------------------------------------------------------
    // Book example verification: parse + emit VHDL + GHDL syntax
    // check every examples/docs/<TAG>/*.ms.il against status.json.
    //
    // Discovered here at build-config time via std.Io.Dir, using the
    // Io instance the build graph itself exposes (b.graph.io) — plain
    // std.fs.cwd() no longer exists in this generation; all fs access
    // goes through Io uniformly, even in build.zig.
    // ------------------------------------------------------------
    const verify_examples_exe = b.addExecutable(.{
        .name = "verify_examples",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/verify_examples.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "matterscript", .module = mod },
            },
        }),
    });

    const run_verify_examples = b.addRunArtifact(verify_examples_exe);
    run_verify_examples.addArgs(&[_][]const u8{ "--status", "docs/generated/linear/status.json" });

    {
        const io = b.graph.io;
        var docs_dir = std.Io.Dir.cwd().openDir(io, "examples/docs", .{ .iterate = true }) catch null;
        if (docs_dir) |*dir| {
            defer dir.close(io);
            var it = dir.iterate();
            while (it.next(io) catch null) |tag_entry| {
                if (tag_entry.kind != .directory) continue;
                const tag_name = b.dupe(tag_entry.name);
                const sub_path = std.fs.path.join(b.allocator, &.{ "examples/docs", tag_entry.name }) catch continue;

                var sub_dir = std.Io.Dir.cwd().openDir(io, sub_path, .{ .iterate = true }) catch continue;
                defer sub_dir.close(io);
                var sub_it = sub_dir.iterate();
                while (sub_it.next(io) catch null) |file_entry| {
                    if (file_entry.kind != .file) continue;
                    if (!std.mem.endsWith(u8, file_entry.name, ".ms.ipl")) continue;
                    const full_path = std.fs.path.join(b.allocator, &.{ sub_path, file_entry.name }) catch continue;
                    run_verify_examples.addArgs(&[_][]const u8{ "--example", tag_name, b.dupe(full_path) });
                }
            }
        }
    }

    const verify_examples_step = b.step("verify-examples", "Parse+VHDL+GHDL check all examples/docs sources against status.json");
    verify_examples_step.dependOn(&run_verify_examples.step);
    verify_step.dependOn(&run_verify_examples.step);
}
