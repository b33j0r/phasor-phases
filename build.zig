const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // phasor-ecs dependency
    const phasor_ecs_dep = b.dependency("phasor_ecs", .{});
    const phasor_ecs_module = phasor_ecs_dep.module("phasor-ecs");

    // phasor-phases library module
    const phasor_phases = b.addModule("phasor-phases", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "phasor-ecs", .module = phasor_ecs_module },
        },
    });

    const phasor_phases_tests = b.addModule(
        "phasor_phases_tests",
        .{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "phasor-ecs", .module = phasor_ecs_module },
                .{ .name = "phasor-phases", .module = phasor_phases },
            },
        },
    );
    const phasor_phases_test_runner = b.addTest(.{
        .root_module = phasor_phases_tests,
    });

    const run_phasor_phases_tests = b.addRunArtifact(phasor_phases_test_runner);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_phasor_phases_tests.step);
}
