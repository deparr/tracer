const std = @import("std");
const qoi = @import("qoi");
const Camera = @import("Camera.zig");
const rt = @import("rt.zig");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    var gpa = debug_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    const world_file = if (args.len > 1) args[1] else "world.zon";

    const world_zon = try std.fs.cwd().readFileAllocOptions(gpa, world_file, 1024 * 1024, 1 << 15, .@"1", 0);
    const world = try std.zon.parse.fromSlice(rt.World, gpa, @ptrCast(world_zon), null, .{});
    defer std.zon.parse.free(gpa, world);
    gpa.free(world_zon);

    var camera = Camera.initOptions(world.camera_options);
    camera.materials = world.materials;

    const pixels = try gpa.alloc(u8, camera.image_height * camera.image_width * 3);
    defer gpa.free(pixels);

    const root = std.Progress.start(.{ .estimated_total_items = 1 });
    const scanlines = root.start("scanlines", camera.image_height);

    camera.render(.{ .objects = world.objects }, pixels, scanlines);
    scanlines.end();
    root.end();

    // really need a streaming api on zig-qoi
    const qoi_img = try qoi.encode(gpa, pixels, .{
        .width = camera.image_width,
        .height = camera.image_height,
        .channels = .rgb,
        .colorspace = .srgb,
    });
    defer gpa.free(qoi_img);

    var io_buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout();
    var writer = stdout.writer(&io_buf);
    try writer.interface.writeAll(qoi_img);
    try writer.interface.flush();
}
