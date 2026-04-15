const std = @import("std");
const qoi = @import("qoi");
const Camera = @import("Camera.zig");
const rt = @import("rt.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const world_file = if (args.len > 1) args[1] else "world.zon";

    const world_zon = try std.Io.Dir.cwd().readFileAllocOptions(io, world_file, gpa, .unlimited, .@"1", 0);
    const world = try std.zon.parse.fromSliceAlloc(rt.World, gpa, @ptrCast(world_zon), null, .{});
    defer std.zon.parse.free(gpa, world);
    gpa.free(world_zon);

    var camera = Camera.initOptions(world.camera_options);
    camera.materials = world.materials;

    const pixels = try gpa.alloc(u8, camera.image_height * camera.image_width * 3);
    defer gpa.free(pixels);

    const root = std.Progress.start(io, .{ .estimated_total_items = 1 });
    const scanlines = root.start("scanlines", camera.image_height);

    camera.render(.{ .objects = world.objects }, pixels, scanlines);
    scanlines.end();
    root.end();

    var io_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout();
    var writer = stdout.writer(io, &io_buf);

    try qoi.encode(&writer.interface, pixels, .{
        .width = camera.image_width,
        .height = camera.image_height,
        .channels = .rgb,
        .colorspace = .srgb,
    });
}
