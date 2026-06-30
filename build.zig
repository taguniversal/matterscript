const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    const mod = b.addModule("matterscript", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mkrand_mod = b.addModule("mkrand", .{
        .root_source_file = b.path("../../mkrand/src/mkrand.zig"),
        .target = target,
    });

    mod.addImport("mkrand", mkrand_mod);

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function.
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

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build`.
    b.installArtifact(exe);

    // This creates a top level step that can be invoked with `zig build run`.
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    run_cmd.addPassthruArgs();

    // Creates executables that will run `test` blocks from the provided modules.
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // ------------------------------------------------------------
    // Verify pipeline
    // ------------------------------------------------------------
    // 1. Run matterscript to generate machine.vhd from the coffee example
    // 2. On Linux, if verilator is available, lint the generated VHDL
    // ------------------------------------------------------------

    const verify_step = b.step("verify", "Generate VHDL and lint with Verilator (Linux only)");

    // Step 1: generate machine.vhd by running matterscript on the example script
    const gen_vhd = b.addRunArtifact(exe);
    gen_vhd.addArg("examples/coffee.ms.fsm");
    gen_vhd.step.dependOn(b.getInstallStep());
    verify_step.dependOn(&gen_vhd.step);

    // Step 2: verilator lint — only wire up on Linux
    const is_linux = b.graph.host.result.os.tag == .linux;
    if (is_linux) {
        // If verilator is not installed this step will fail with a clear error.
        // Install with: sudo apt install verilator
        const verilator_check = b.addSystemCommand(&.{
            "verilator",
            "--lint-only",
            "--language",
            "VHDL",
            "../workspace/coffee/machine.vhd",
        });
        verilator_check.step.dependOn(&gen_vhd.step);
        verify_step.dependOn(&verilator_check.step);
    } else {
        // On Windows just print a note — don't fail the step
        const note = b.addSystemCommand(&.{
            "cmd", "/c", "echo", "Verilator lint skipped (Linux only)",
        });
        note.step.dependOn(&gen_vhd.step);
        verify_step.dependOn(&note.step);
    }
}
