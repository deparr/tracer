const std = @import("std");
const png = @import("png.zig");
const Camera = @import("Camera.zig");
const rt = @import("rt.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const world_file = if (args.len > 1) args[1] else "world.zon";

    const world_zon = try std.Io.Dir.cwd().readFileAllocOptions(io, world_file, gpa, .unlimited, .@"1", 0);
    var zon_diag = std.zon.parse.Diagnostics{ .errors = &.{} };
    const world = try std.zon.parse.fromSlice(rt.World, .{
        .gpa = gpa,
        .arena = init.arena.allocator(),
        .source = @ptrCast(world_zon),
        .diagnostics = &zon_diag,
        .ignore_unknown_fields = true,
    });
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
    var outfile = blk: {
        var stdout = std.Io.File.stdout();
        if (!(stdout.isTty(io) catch true))
            break :blk stdout;

        try stdout.writeStreamingAll(io, "stdout is a tty, writing img data to './render.png' instead");
        break :blk try std.Io.Dir.cwd().openFile(io, "render.png", .{ .mode = .write_only });
    };
    
    var writer = outfile.writer(io, &io_buf);
    try png.encodeStream(&writer.interface, pixels, camera.image_width, camera.image_height);
}
