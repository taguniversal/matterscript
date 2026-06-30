const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("matterscript", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mkrand_mod = b.addModule("mkrand", .{
        .root_source_file = b.path("../../mkrand/src/mkrand.zig"),
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

    b.installArtifact(exe);

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
    // 1. Run matterscript to generate machine.vhd from the coffee example
    // 2. Run ghdl syntax check (cross-platform)
    // 3. Run verilator lint (Linux only)
    // ------------------------------------------------------------

    const verify_step = b.step("verify", "Generate VHDL, syntax check with GHDL, lint with Verilator");

    // Step 1: generate machine.vhd
    const gen_vhd = b.addRunArtifact(exe);
    gen_vhd.addArg("examples/coffee/coffee.ms.fsm");
    gen_vhd.step.dependOn(b.getInstallStep());
    verify_step.dependOn(&gen_vhd.step);

    // Step 2: ghdl syntax check — runs on both Windows and Linux
    const ghdl_check = b.addSystemCommand(&.{
        "ghdl", "-s", "--std=08", "../workspace/coffee/machine.vhd",
    });
    ghdl_check.step.dependOn(&gen_vhd.step);
    verify_step.dependOn(&ghdl_check.step);

    // Step 3: verilator lint — Linux only (not available on Windows)
    const is_linux = b.graph.host.result.os.tag == .linux;
    if (is_linux) {
        const verilator_check = b.addSystemCommand(&.{
            "verilator", "--lint-only", "../workspace/coffee/machine.vhd",
        });
        verilator_check.step.dependOn(&gen_vhd.step);
        verify_step.dependOn(&verilator_check.step);
    }
}
