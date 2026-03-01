const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("jackgraphd", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.addIncludePath(.{ .cwd_relative = "/usr/local/include/dbus-1.0" });
    mod.addIncludePath(.{ .cwd_relative = "/usr/local/lib/dbus-1.0/include" });

    const exe = b.addExecutable(.{
        .name = "jackgraphd",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "jackgraphd", .module = mod },
            },
        }),
    });
    exe.addCSourceFile(.{ .file = b.path("src/dbus_shim.c") });
    exe.linkSystemLibrary("dbus-1");
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/include/dbus-1.0" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/lib/dbus-1.0/include" });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
