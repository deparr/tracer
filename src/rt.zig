const std = @import("std");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Ray = math.Ray;
const Color = math.Color;

pub const Hittable = union(enum) {
    // https://ziggit.dev/t/is-it-possible-to-use-non-exhaustive-enums-in-zon/13847/16
    sphere: struct { center: Point, radius: f64, mat: u32 = 0 },
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
                    .mat = @enumFromInt(s.mat),
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
    fuzz: f64 = 1.0,
    refraction_index: f64 = 1.0,

    pub const Tag = enum {
        none,
        lambertian,
        metal,
        dielectric,
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
                const fuzz = @min(self.fuzz, 1.0);
                var reflected = incident.dir.reflect(rec.normal);
                reflected = reflected.norm().add(rng.next_norm_vec3().scale(fuzz));
                const scattered_ray = Ray{ .origin = rec.point, .dir = reflected };
                return .{ .dir = scattered_ray, .attenuation = self.albedo };
            },
            .dielectric => {
                const ri = if (rec.front_face) 1.0 / self.refraction_index else self.refraction_index;
                var dir = incident.dir.norm();
                const cos_theta = @min(dir.neg().dot(rec.normal), 1.0);
                const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
                const cannot_refract = ri * sin_theta > 1.0 or reflectance(cos_theta, ri) > rng.next_f64();
                if (cannot_refract){
                    dir = dir.reflect(rec.normal);
                }
                else {
                    dir = dir.refract(rec.normal, ri);
                }
                const ray = Ray{ .origin = rec.point, .dir = dir };
                return .{ .dir = ray, .attenuation = Color.white };
            },
            else => return null,
        }
    }

    fn reflectance(cos: f64, refraction_index: f64) f64 {
        // schlick aproximation
        var r0 = (1 - refraction_index) / (1 + refraction_index);
        r0 *= r0;
        return r0 + (1 - r0) * std.math.pow(f64, 1 - cos, 5);
    }
};

pub const World = struct {
    camera_options: @import("Camera.zig").Options,
    materials: []Material,
    objects: []Hittable,
};
