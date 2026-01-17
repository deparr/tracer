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

const materials = [_]Material{
    .{ .tag = .none },
    .{ .tag = .lambertian, .albedo = Color{ .x = 0.8, .y = 0.8, .z = 0.0 } },
    .{ .tag = .lambertian, .albedo = Color{ .x = 0.1, .y = 0.2, .z = 0.5 } },
    .{ .tag = .metal, .albedo = Color{ .x = 0.8, .y = 0.8, .z = 0.8 } },
    .{ .tag = .metal, .albedo = Color{ .x = 0.8, .y = 0.6, .z = 0.2 } },
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    var gpa = debug_allocator.allocator();

    const options_zon = try std.fs.cwd().readFileAllocOptions(gpa, "opts.zon", 2048, 150, .@"1", 0);
    const camera_options = try std.zon.parse.fromSlice(Camera.Options, gpa, @ptrCast(options_zon), null, .{});
    gpa.free(options_zon);
    var camera = Camera.initOptions(camera_options);
    camera.materials = &materials;

    const pixels = try gpa.alloc(u8, camera.image_height * camera.image_width * 3);
    defer gpa.free(pixels);

    const mat_ground = Material.Index.fromInt(1);
    const mat_center = Material.Index.fromInt(2);
    const mat_left = Material.Index.fromInt(3);
    const mat_right = Material.Index.fromInt(4);

    var world_buffer: [16]rt.Hittable = undefined;
    var world = std.ArrayList(rt.Hittable).initBuffer(&world_buffer);
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .x = -1.0, .z = -1.0 }, .radius = 0.5, .mat = mat_left } });
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .z = -1.2 }, .radius = 0.5, .mat = mat_center } });
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .x = 1.0, .z = -1.0 }, .radius = 0.5, .mat = mat_right } });
    world.appendAssumeCapacity(.{ .sphere = .{ .center = .{ .y = -100.5, .z = -1.0 }, .radius = 100.0, .mat = mat_ground } });

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
