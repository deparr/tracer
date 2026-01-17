const std = @import("std");
const qoi = @import("qoi");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Color = math.Color;
const Ray = math.Ray;
const Range = math.Range;
const rt = @import("rt.zig");
const Camera = @import("Camera.zig");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    var gpa = debug_allocator.allocator();

    var camera = Camera.initOptions(.{ .image_width = 1920, .samples_per_pixel = 100 });
    const pixels = try gpa.alloc(u8, camera.image_height * camera.image_width * 3);
    defer gpa.free(pixels);

    var world_buffer: [16]rt.Hittable = undefined;
    var world = std.ArrayList(rt.Hittable).initBuffer(&world_buffer);
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .z = -1.0 }, .radius = 0.5 } });
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .y = -100.5, .z = -1.0 }, .radius = 100.0 } });

    const progress = std.Progress.start(.{ .estimated_total_items = 1 });
    const scanlines = progress.start("scanlines", camera.image_height);

    camera.render(.{ .multi = world.items }, pixels, scanlines);
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
