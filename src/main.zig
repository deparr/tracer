const std = @import("std");
const qoi = @import("qoi");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Color = math.Color;
const Ray = math.Ray;

const aspect_ratio = 16.0 / 9.0;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    var gpa = debug_allocator.allocator();

    const image_width: u32 = 400;
    const image_widthf: f32 = @floatFromInt(image_width);
    // calc image height with width and aspect
    var image_heightf: f32 = image_widthf / aspect_ratio;
    image_heightf = if (image_heightf < 1.0) 1.0 else image_heightf;
    const image_height: u32 = @intFromFloat(image_heightf);

    const focal_length: f32 = 1.0;
    const viewport_height: f32 = 2.0;
    const viewport_width = viewport_height * (image_widthf / image_heightf);
    const camera_center = Point.zero;

    const viewport_u = Vec3{ .x = viewport_width };
    const viewport_v = Vec3{ .y = -viewport_height };

    const pixel_delta_u = viewport_u.scale(1.0 / image_widthf);
    const pixel_delta_v = viewport_v.scale(1.0 / image_heightf);

    const viewport_upper_left = camera_center
        .sub(Vec3{ .z = focal_length })
        .sub(viewport_u.scale(0.5))
        .sub(viewport_v.scale(0.5));
    const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

    // render an image

    std.debug.print(
        \\.{{
        \\  .image_width = {d},
        \\  .image_height = {d},
        \\  .image_widthf = {d},
        \\  .image_heightf = {d},
        \\}}
        \\
        , .{ image_width, image_height, image_widthf, image_heightf });

    const pixels = try gpa.alloc(u8, image_height * image_width * 3);
    defer gpa.free(pixels);

    for (0..image_height) |j| {
        const jf: f32 = @floatFromInt(j);
        for (0..image_width) |i| {
            const i_f: f32 = @floatFromInt(i);
            const pixel_center = pixel00_loc
                .add(pixel_delta_u.scale(i_f))
                .add(pixel_delta_v.scale(jf));
            const ray_dir = pixel_center.sub(camera_center);
            const pixel_color = rayColor(Ray{
                .origin = camera_center,
                .dir = ray_dir,
            });
            const off = j * image_width * 3 + i * 3;

            writeColor(pixel_color, pixels, off);
        }
    }

    const qoi_img = try qoi.encode(gpa, pixels, .{
        .width = image_width,
        .height = image_height,
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

fn rayColor(ray: Ray) Color {
    if (hitSphere(.{.z = -1.0 }, 0.5, &ray))
        return .{ .x = 1.0 };
    const dir = ray.dir.norm();
    const a = 0.5 * (dir.y + 1.0);
    const blue = Color{.x = 0.5, .y = 0.7, .z = 1.0};
    return Color.white.scale(1.0 - a).add(blue.scale(a));
}

fn hitSphere(center: Point, radius: f32, ray: *const Ray) bool {
    const oc = center.sub(ray.origin);
    const a = ray.dir.dot(ray.dir);
    const b = -2.0 * ray.dir.dot(oc);
    const c = oc.dot(oc) - radius * radius;
    const discriminant = b * b - 4.0 * a * c;
    return discriminant >= 0;
}

fn writeColor(c: Color, pixels: []u8, off: usize) void {
    pixels[off] = @intFromFloat(255.99 * c.x);
    pixels[off + 1] = @intFromFloat(255.99 * c.y);
    pixels[off + 2] = @intFromFloat(255.99 * c.z);
}
