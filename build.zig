const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zig_qoi = b.dependency("zig_qoi", .{
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("qoi", zig_qoi.module("qoi"));

    const exe = b.addExecutable(.{
        .name = "zrt",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
