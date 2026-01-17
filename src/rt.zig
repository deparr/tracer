const std = @import("std");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Ray = math.Ray;
const Color = math.Color;

pub const Hittable = union(enum) {
    sphere: struct { center: Point, radius: f64, mat: Material.Index = .none },
    multi: []const Hittable,

    pub const HitRecord = struct {
        point: Point = Point.zero,
        normal: Vec3 = Vec3.zero,
        t: f64 = 0.0,
        front_face: bool = false,
        mat: Material.Index,

        pub fn setFaceNormal(self: *HitRecord, ray: *const Ray, outward_normal: *const Vec3) void {
            self.front_face = ray.dir.dot(outward_normal.*) < 0.0;
            self.normal = if (self.front_face) outward_normal.* else outward_normal.neg();
        }
    };

    pub fn hit(self: Hittable, ray: *const Ray, range: math.Range) ?HitRecord {
        switch (self) {
            .sphere => |s| {
                const oc = s.center.sub(ray.origin);
                const a = ray.dir.len2();
                const h = ray.dir.dot(oc);
                const c = oc.len2() - s.radius * s.radius;
                const discriminant = h * h - a * c;
                if (discriminant < 0.0) return null;

                const sqrtd = @sqrt(discriminant);
                const root = blk: {
                    const neg = (h - sqrtd) / a;
                    if (range.surrounds(neg)) break :blk neg;
                    const pos = (h + sqrtd) / a;
                    if (range.surrounds(pos)) break :blk pos;
                    return null;
                };

                const surface_point = ray.at(root);
                const outward_normal = surface_point.sub(s.center).divScalar(s.radius);
                var record = HitRecord{
                    .point = surface_point,
                    .t = root,
                    .mat = s.mat,
                };
                record.setFaceNormal(ray, &outward_normal);

                return record;
            },
            .multi => |list| {
                var record: ?HitRecord = null;
                var closest_range = range;
                for (list) |obj| {
                    if (obj.hit(ray, closest_range)) |obj_record| {
                        record = obj_record;
                        closest_range.max = obj_record.t;
                    }
                }
                return record;
            },
        }
    }
};

pub const Material = struct {
    tag: Tag,
    albedo: Color = .{},

    pub const Tag = enum {
        none,
        lambertian,
        metal,
    };

    pub const Index = enum(u32) {
        none = 0,
        _,

        pub fn toInt(self: Index) u32 {
            return @intFromEnum(self);
        }

        pub fn fromInt(val: u32) Index {
            return @enumFromInt(val);
        }
    };

    pub const ScatterRecord = struct {
        dir: Ray,
        attenuation: Color,
    };

    pub fn scatter(self: *const Material, rng: *math.Random, incident: Ray, rec: *const Hittable.HitRecord) ?ScatterRecord {
        switch (self.tag) {
            .lambertian => {
                var scatter_dir = rec.normal.add(rng.next_norm_vec3());
                if (scatter_dir.nearZero())
                    scatter_dir = rec.normal;
                const scattered_ray = Ray{ .origin = rec.point, .dir = scatter_dir };
                return .{ .dir = scattered_ray, .attenuation = self.albedo };
            },
            .metal => {
                const reflected = incident.dir.reflect(rec.normal);
                const scattered_ray = Ray{ .origin = rec.point, .dir = reflected };
                return .{ .dir = scattered_ray, .attenuation = self.albedo };
            },
            else => return null,
        }
    }
};
