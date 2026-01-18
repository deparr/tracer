pub const Camera = @This();

pub const Options = struct {
    image_width: u32,
    aspect_ratio: f64 = 16.0 / 9.0,
    max_depth: u32 = 10,
    samples_per_pixel: u16 = 10,
    vfov: f64 = 90.0,
    look_from: Vec3 = .{},
    look_at: Vec3 = .{ .z = -1.0 },
    view_up: Vec3 = .{ .y = 1.0 },
    defocus_angle: f64 = 0,
    focus_dist: f64 = 10,
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
vfov: f64,
max_depth: u32,
u: Vec3,
v: Vec3,
w: Vec3,
defocus_angle: f64,
defocus_disk_u: Vec3,
defocus_disk_v: Vec3,
materials: []const rt.Material,
rng: math.Random,

pub fn initOptions(opts: Options) Camera {
    const widthf: f64 = @floatFromInt(opts.image_width);
    const image_height: f64 = @max(1.0, widthf / opts.aspect_ratio);

    // viewport dimensions
    // const focal_length: f64 = opts.look_from.sub(opts.look_at).len();
    const theta = math.deg_to_rad(opts.vfov);
    const h = @tan(theta / 2);
    const viewport_height: f64 = 2.0 * h * opts.focus_dist;
    const viewport_width = viewport_height * widthf / image_height;

    // basis vectors
    const w = opts.look_from.sub(opts.look_at).norm();
    const u = opts.view_up.cross(w).norm();
    const v = w.cross(u);

    // vectors across the horizontal and vertical edges
    const viewport_u = u.scale(viewport_width);
    const viewport_v = v.neg().scale(viewport_height);

    // delta from pixel to pixel
    const pixel_delta_u = viewport_u.divScalar(@floatFromInt(opts.image_width));
    const pixel_delta_v = viewport_v.divScalar(image_height);

    var viewport_upper_left = opts.look_from
        .sub(w.scale(opts.focus_dist))
        .sub(viewport_u.scale(0.5))
        .sub(viewport_v.scale(0.5));

    const defocus_radius = opts.focus_dist * @tan(math.deg_to_rad(opts.defocus_angle / 2));

    return .{
        .aspect_ratio = opts.aspect_ratio,
        .image_width = opts.image_width,
        .image_height = @intFromFloat(image_height),
        .center = opts.look_from,
        .pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5)),
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .stride = opts.image_width * 3,
        .samples_per_pixel = opts.samples_per_pixel,
        .sample_scale = 1.0 / @as(f64, @floatFromInt(opts.samples_per_pixel)),
        .vfov = theta,
        .max_depth = @max(opts.max_depth, 1),
        .u = u,
        .v = v,
        .w = w,
        .defocus_angle = opts.defocus_angle,
        .defocus_disk_u = u.scale(defocus_radius),
        .defocus_disk_v = v.scale(defocus_radius),
        .materials = &.{},
        .rng = .init(0xdeadcafe),
    };
}

pub fn render(self: *Camera, world: rt.Hittable, pixels: []u8, progress: std.Progress.Node) void {
    for (0..self.image_height) |j| {
        const row_offset = j * self.stride;
        for (0..self.image_width) |i| {
            var pixel_color = Color.black;
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(i, j);
                pixel_color.addAssign(self.rayColor(ray, &world, self.max_depth));
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

    const origin = if (self.defocus_angle <= 0) self.center else self.sampleDefocusDisk();
    const direction = pixel_sample.sub(origin);

    return Ray{ .origin = origin, .dir = direction };
}

fn sampleDefocusDisk(self: *Camera) Point {
    const p = self.rng.next_vec3_in_unit_disk();
    return self.center
        .add(self.defocus_disk_u.scale(p.x))
        .add(self.defocus_disk_v.scale(p.y));
}

fn rayColor(self: *Camera, ray: Ray, world: *const rt.Hittable, depth: u32) Color {
    if (depth == 0) return Color.black;

    if (world.hit(&ray, .forward)) |rec| {
        if (self.materials[@intFromEnum(rec.mat)].scatter(&self.rng, ray, &rec)) |scatter_rec| {
            return scatter_rec.attenuation.mul(self.rayColor(scatter_rec.dir, world, depth - 1));
        }
        return Color.black;
    }
    // if we dont hit anything, return the blue gradient
    const dir = ray.dir.norm();
    const a = 0.5 * (dir.y + 1.0);
    const blue = Color{ .x = 0.5, .y = 0.7, .z = 1.0 };
    return Color.white.scale(1.0 - a).add(blue.scale(a));
}

fn writePixel(c: Color, pixels: []u8, off: usize) void {
    const intensity = Range{ .max = 0.9999 };
    var r = c.x;
    var g = c.y;
    var b = c.z;
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    pixels[off] = @intFromFloat(256 * intensity.clamp(r));
    pixels[off + 1] = @intFromFloat(256 * intensity.clamp(g));
    pixels[off + 2] = @intFromFloat(256 * intensity.clamp(b));
}

inline fn linearToGamma(v: f64) f64 {
    if (v > 0.0) return @sqrt(v);
    return 0.0;
}

const std = @import("std");
const math = @import("math.zig");
const Color = math.Color;
const Vec3 = math.Vec3;
const Point = math.Point;
const Range = math.Range;
const Ray = math.Ray;
const rt = @import("rt.zig");
