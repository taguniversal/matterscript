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
    // Note: Verilator requires GHDL->Verilog synthesis before it can process
    // VHDL — that is handled by the simulate step below.
    // ------------------------------------------------------------

    const verify_step = b.step("verify", "Generate VHDL and syntax check with GHDL");

    const gen_vhd = b.addRunArtifact(exe);
    gen_vhd.addArg("examples/coffee/coffee.ms.fsm");
    gen_vhd.step.dependOn(b.getInstallStep());
    verify_step.dependOn(&gen_vhd.step);

    const ghdl_check = b.addSystemCommand(&.{
        "ghdl", "-s", "--std=08", "../workspace/coffee/machine.vhd",
    });
    ghdl_check.step.dependOn(&gen_vhd.step);
    verify_step.dependOn(&ghdl_check.step);

    // ------------------------------------------------------------
    // Simulate pipeline (Linux only)
    // ------------------------------------------------------------
    // 1. ghdl -a  — analyze VHDL
    // 2. ghdl -e  — elaborate
    // 3. ghdl --synth — export to Verilog netlist
    // 4. verilator  — compile with C++ testbench to native binary
    // 5. run the simulation binary
    // ------------------------------------------------------------

    const simulate_step = b.step("simulate", "Full GHDL->Verilator simulation (Linux only)");

    const is_linux = b.graph.host.result.os.tag == .linux;
    if (is_linux) {
        // Step 1: analyze
        const ghdl_analyze = b.addSystemCommand(&.{
            "ghdl", "-a", "--std=08",
            "--work-dir=../workspace/coffee",
            "../workspace/coffee/machine.vhd",
        });
        ghdl_analyze.step.dependOn(&gen_vhd.step);

        // Step 2: elaborate
        const ghdl_elaborate = b.addSystemCommand(&.{
            "ghdl", "-e", "--std=08",
            "--work-dir=../workspace/coffee",
            "CoffeeShop",
        });
        ghdl_elaborate.step.dependOn(&ghdl_analyze.step);

        // Step 3: synthesize to Verilog
        const ghdl_synth = b.addSystemCommand(&.{
            "ghdl", "--synth", "--std=08",
            "--work-dir=../workspace/coffee",
            "--out=verilog",
            "CoffeeShop",
            "-o", "../workspace/coffee/machine.sv",
        });
        ghdl_synth.step.dependOn(&ghdl_elaborate.step);

        // Step 4: verilator compile with testbench
        const verilator_build = b.addSystemCommand(&.{
            "verilator",
            "--cc", "--exe", "--build",
            "--Mdir", "../workspace/coffee/obj_dir",
            "../workspace/coffee/machine.sv",
            "tb/tb_coffee.cpp",
        });
        verilator_build.step.dependOn(&ghdl_synth.step);

        // Step 5: run the simulation binary
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
}
