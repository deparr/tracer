const std = @import("std");
const rt = @import("rt.zig");
const math = @import("math.zig");
const CameraOptions = @import("Camera.zig").Options;

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    const args = try std.process.argsAlloc(gpa);
    var seed: u32 = 0xba11dead;
    if (args.len > 1)
        seed = std.fmt.parseInt(u32, args[0], 0) catch seed;

    const camera_options = CameraOptions{
        .image_width = 1920,
        .aspect_ratio = 16.0 / 9.0,
        .samples_per_pixel = 300,
        .max_depth = 50,
        .vfov = 40.0,
        .look_from = .{ .x = 13, .y = 2, .z = 3 },
        .look_at = .zero,
        .view_up = .{ .y = 1.0 },
        .defocus_angle = 0.2,
        .focus_dist = 10.0,
    };
    const num_objects = 22;
    const half_num_objects: isize = num_objects / 2 + @as(isize, @intFromBool(num_objects % 2 == 1));

    var materials = try std.ArrayList(rt.Material).initCapacity(gpa, num_objects * num_objects + 10);
    var objects = try std.ArrayList(rt.Hittable).initCapacity(gpa, num_objects * num_objects + 10);
    var rng: math.Random = .init(seed);
    // I think this is so they dont overlap with the 3 center spheres?
    const pos_threshold = math.Vec3{ .x = 4.0, .y = 0.2 };

    // the ground
    objects.appendAssumeCapacity(.{ .sphere = .{
        .center = math.Vec3{ .y = -1000 },
        .radius = 1000,
        .mat = 0,
    } });
    materials.appendAssumeCapacity(.{
        .tag = .lambertian,
        .albedo = .{ .x = 0.5, .y = 0.5, .z = 0.5 },
    });

    // random spheres
    for (0..num_objects) |au| {
        for (0..num_objects) |bu| {
            const a: f64 = @floatFromInt(@as(isize, @intCast(au)) - half_num_objects);
            const b: f64 = @floatFromInt(@as(isize, @intCast(bu)) - half_num_objects);

            const mat_choice = rng.next_f64();
            const pos = math.Vec3{
                .x = a + 0.9 * rng.next_f64(),
                .y = 0.2,
                .z = b + 0.9 * rng.next_f64(),
            };

            if (pos.sub(pos_threshold).len() > 0.9) {
                var mat = rt.Material{ .tag = .none };
                if (mat_choice < 0.8) {
                    mat.tag = .lambertian;
                    mat.albedo = rng.next_vec3().mul(rng.next_vec3());
                } else if (mat_choice < 0.95) {
                    mat.tag = .metal;
                    mat.albedo = rng.next_vec3_range(0.5, 1.0);
                    mat.fuzz = rng.next_f64_range(0, 0.5);
                } else {
                    mat.tag = .dielectric;
                    mat.refraction_index = 1.5;
                }

                const mat_index: u32 = @truncate(materials.items.len);
                materials.appendAssumeCapacity(mat);
                objects.appendAssumeCapacity(.{
                    .sphere = .{
                        .center = pos,
                        .radius = 0.2,
                        .mat = mat_index,
                    },
                });
            }
        }
    }

    // three center spheres
    const mat_index: u32 = @truncate(materials.items.len);
    objects.appendAssumeCapacity(.{ .sphere = .{
        .center = .{ .y = 1 },
        .radius = 1,
        .mat = mat_index,
    } });
    materials.appendAssumeCapacity(.{
        .tag = .dielectric,
        .refraction_index = 1.5,
    });
    objects.appendAssumeCapacity(.{ .sphere = .{
        .center = .{ .x = -4, .y = 1 },
        .radius = 1,
        .mat = mat_index + 1,
    } });
    materials.appendAssumeCapacity(.{
        .tag = .lambertian,
        .albedo = .{ .x = 0.4, .y = 0.2, .z = 0.1 },
    });
    objects.appendAssumeCapacity(.{ .sphere = .{
        .center = .{ .x = 4, .y = 1 },
        .radius = 1,
        .mat = mat_index + 2,
    } });
    materials.appendAssumeCapacity(.{
        .tag = .metal,
        .albedo = .{ .x = 0.7, .y = 0.6, .z = 0.5 },
        .fuzz = 0,
    });

    std.debug.print("mat cap: {d}, len: {d}\n", .{ materials.capacity, materials.items.len });
    std.debug.print("obj cap: {d}, len: {d}\n", .{ objects.capacity, objects.items.len });

    const world = rt.World{
        .camera_options = camera_options,
        .materials = materials.items,
        .objects = objects.items,
    };

    var io_buf: [2048]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&io_buf);
    try std.zon.stringify.serialize(
        world,
        .{ .emit_default_optional_fields = false },
        &stdout.interface,
    );
    try stdout.interface.flush();

    materials.deinit(gpa);
    objects.deinit(gpa);
}
