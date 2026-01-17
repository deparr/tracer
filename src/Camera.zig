pub const Camera = @This();

pub const CameraOptions = struct {
    image_width: u32,
    aspect_ratio: f64 = 16.0 / 9.0,
    samples_per_pixel: u16 = 100,
};

aspect_ratio: f64,
image_width: u32,
image_height: u32,
center: Point,
pixel00_loc: Point,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
stride: u32,
sample_scale: f64,
samples_per_pixel: u16,
rng: math.Random,

// todo if this needs more opts, create an options struct
pub fn initOptions(opts: CameraOptions) Camera {
    const widthf: f64 = @floatFromInt(opts.image_width);
    const image_height: f64 = @max(1.0, widthf / opts.aspect_ratio);

    // viewport dimensions
    const focal_length: f64 = 1.0;
    const viewport_height: f64 = 2.0;
    const viewport_width = viewport_height * widthf / image_height;

    // vectors across the horizontal and vertical edges
    const viewport_u = Vec3{ .x = viewport_width };
    const viewport_v = Vec3{ .y = -viewport_height };

    // delta from pixel to pixel
    const pixel_delta_u = viewport_u.divScalar(@floatFromInt(opts.image_width));
    const pixel_delta_v = viewport_v.divScalar(image_height);

    var viewport_upper_left = Vec3{ .z = -focal_length };
    viewport_upper_left = viewport_upper_left
        .sub(viewport_u.scale(0.5))
        .sub(viewport_v.scale(0.5));

    return .{
        .aspect_ratio = opts.aspect_ratio,
        .image_width = opts.image_width,
        .image_height = @intFromFloat(image_height),
        .center = Vec3.zero,
        .pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5)),
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .stride = opts.image_width * 3,
        .samples_per_pixel = opts.samples_per_pixel,
        .sample_scale = 1.0 / @as(f64, @floatFromInt(opts.samples_per_pixel)),
        .rng = .init(0xdeadcafe),
    };
}

pub fn render(self: *Camera, world: Hittable, pixels: []u8, progress: std.Progress.Node) void {
    for (0..self.image_height) |j| {
        const row_offset = j * self.stride;
        for (0..self.image_width) |i| {
            var pixel_color = Color.black;
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(i, j);
                pixel_color.addAssign(rayColor(ray, &world));
            }
            pixel_color.scaleAssign(self.sample_scale);
            const offset = row_offset + i * 3;
            writePixel(pixel_color, pixels, offset);
        }
        progress.completeOne();
    }
}

fn getRay(self: *Camera, i_int: usize, j_int: usize) Ray {
    const i: f64 = @floatFromInt(i_int);
    const j: f64 = @floatFromInt(j_int);
    const offset = Vec3{
        .x = self.rng.next_f64() - 0.5,
        .y = self.rng.next_f64() - 0.5,
    };
    const pixel_sample = self.pixel00_loc
        .add(self.pixel_delta_u.scale(i + offset.x))
        .add(self.pixel_delta_v.scale(j + offset.y));

    return Ray{ .origin = self.center, .dir = pixel_sample.sub(self.center) };
}

fn rayColor(ray: Ray, world: *const Hittable) Color {
    if (world.hit(&ray, .forward)) |rec| {
        return rec.normal.add(Color.white).scale(0.5);
    }
    // if we dont hit anything, return the blue gradient
    const dir = ray.dir.norm();
    const a = 0.5 * (dir.y + 1.0);
    const blue = Color{ .x = 0.5, .y = 0.7, .z = 1.0 };
    return Color.white.scale(1.0 - a).add(blue.scale(a));
}

fn writePixel(c: Color, pixels: []u8, off: usize) void {
    const intensity = Range{ .max = 0.9999 };
    pixels[off] = @intFromFloat(256 * intensity.clamp(c.x));
    pixels[off + 1] = @intFromFloat(256 * intensity.clamp(c.y));
    pixels[off + 2] = @intFromFloat(256 * intensity.clamp(c.z));
}

const std = @import("std");
const math = @import("math.zig");
const Color = math.Color;
const Vec3 = math.Vec3;
const Point = math.Point;
const Range = math.Range;
const Ray = math.Ray;
const Hittable = @import("rt.zig").Hittable;
