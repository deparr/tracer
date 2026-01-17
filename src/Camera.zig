pub const Camera = @This();

aspect_ratio: f32,
image_width: u32,
image_height: u32,
center: Point,
pixel00_loc: Point,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
stride: u32,

// todo if this needs more opts, create an options struct
pub fn initFromWidthAndAspect(image_width: u32, aspect_ratio: f32) Camera {
    const widthf: f32 = @floatFromInt(image_width);
    const image_height: f32 = @max(1.0, widthf / aspect_ratio);

    // viewport dimensions
    const focal_length: f32 = 1.0;
    const viewport_height: f32 = 2.0;
    const viewport_width = viewport_height * widthf / image_height;

    // vectors across the horizontal and vertical edges
    const viewport_u = Vec3{ .x = viewport_width };
    const viewport_v = Vec3{ .y = -viewport_height };

    // delta from pixel to pixel
    const pixel_delta_u = viewport_u.divScalar(@floatFromInt(image_width));
    const pixel_delta_v = viewport_v.divScalar(image_height);

    var viewport_upper_left = Vec3{ .z = -focal_length };
    viewport_upper_left = viewport_upper_left
        .sub(viewport_u.scale(0.5))
        .sub(viewport_v.scale(0.5));

    return .{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .image_height = @intFromFloat(image_height),
        .center = Vec3.zero,
        .pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5)),
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .stride = image_width * 3,
    };
}

pub fn render(self: *const Camera, world: Hittable, pixels: []u8) void {
    for (0..self.image_height) |j| {
        const jf: f32 = @floatFromInt(j);
        const row_offset = j * self.stride;
        for (0..self.image_width) |i| {
            const i_f: f32 = @floatFromInt(i);
            const pixel_center = self.pixel00_loc
                .add(self.pixel_delta_u.scale(i_f))
                .add(self.pixel_delta_v.scale(jf));

            const ray_dir = pixel_center.sub(self.center);
            const ray = Ray{.dir = ray_dir, .origin = self.center};

            const pixel_color = rayColor(ray, &world);
            const offset = row_offset + i * 3;
            writePixel(pixel_color, pixels, offset);
        }
    }

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
    pixels[off] = @intFromFloat(255.99 * c.x);
    pixels[off + 1] = @intFromFloat(255.99 * c.y);
    pixels[off + 2] = @intFromFloat(255.99 * c.z);
}

const math = @import("math.zig");
const Color = math.Color;
const Vec3 = math.Vec3;
const Point = math.Point;
const Range = math.Range;
const Ray = math.Ray;
const Hittable = @import("rt.zig").Hittable;
