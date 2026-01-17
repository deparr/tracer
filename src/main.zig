const std = @import("std");
const qoi = @import("qoi");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Color = math.Color;
const Ray = math.Ray;
const Range = math.Range;
const Camera = @import("Camera.zig");
const rt = @import("rt.zig");
const Material = rt.Material;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    var gpa = debug_allocator.allocator();

    const world_zon = try std.fs.cwd().readFileAllocOptions(gpa, "world.zon", 4096, 2048, .@"1", 0);
    const world = try std.zon.parse.fromSlice(rt.World, gpa, @ptrCast(world_zon), null, .{});
    defer std.zon.parse.free(gpa, world);
    gpa.free(world_zon);

    var camera = Camera.initOptions(world.camera_options);
    camera.materials = world.materials;

    const pixels = try gpa.alloc(u8, camera.image_height * camera.image_width * 3);
    defer gpa.free(pixels);

    const progress = std.Progress.start(.{ .estimated_total_items = 1 });
    const scanlines = progress.start("scanlines", camera.image_height);

    camera.render(.{ .multi = world.objects }, pixels, scanlines);
    scanlines.end();
    progress.end();

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
