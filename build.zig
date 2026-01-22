const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gen_step = b.step("generator", "build the generator");
    const tracer_step = b.step("tracer", "build the ray tracer");
    b.default_step = tracer_step;

    const render_exe_mod = b.createModule(.{
        .root_source_file = b.path("src/render.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zig_qoi = b.dependency("zig_qoi", .{
        .target = target,
        .optimize = optimize,
    });
    render_exe_mod.addImport("qoi", zig_qoi.module("qoi"));

    const render_exe = b.addExecutable(.{
        .name = "zrt",
        .root_module = render_exe_mod,
    });

    const gen_exe = b.addExecutable(.{
        .name = "gen_world",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_world.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_gen = b.addInstallArtifact(gen_exe, .{});
    gen_step.dependOn(&install_gen.step);

    const install_tracer = b.addInstallArtifact(render_exe, .{});
    tracer_step.dependOn(&install_tracer.step);
}
