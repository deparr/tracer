const std = @import("std");
const math = @import("math.zig");
const Point = math.Point;
const Vec3 = math.Vec3;
const Ray = math.Ray;

pub const Hittable = union(enum) {
    sphere: struct { center: Point, radius: f32 },
    multi: []const Hittable,

    pub const HitRecord = struct {
        point: Point = Point.zero,
        normal: Vec3 = Vec3.zero,
        t: f32 = 0.0,
        front_face: bool = false,

        pub fn setFaceNormal(self: *HitRecord, ray: *const Ray, outward_normal: *const Vec3) void {
            self.front_face = ray.dir.dot(outward_normal.*) < 0.0;
            self.normal = if (self.front_face) outward_normal.* else outward_normal.neg();
        }
    };

    pub fn hit(self: Hittable, ray: *const Ray, ray_tmin: f32, ray_tmax: f32) ?HitRecord {
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
                    if (neg > ray_tmin and neg < ray_tmax) break :blk neg;
                    const pos = (h + sqrtd) / a;
                    if (pos > ray_tmin and pos < ray_tmax) break :blk pos;
                    return null;
                };

                const surface_point = ray.at(root);
                const outward_normal = surface_point.sub(s.center).divScalar(s.radius);
                var record = HitRecord{
                    .point = surface_point,
                    .t = root,
                };
                record.setFaceNormal(ray, &outward_normal);

                return record;
            },
            .multi => |list| {
                var record: ?HitRecord = null;
                var closest: f32 = ray_tmax;
                for (list) |obj| {
                    if (obj.hit(ray, ray_tmin, closest)) |obj_record| {
                        record = obj_record;
                        closest = obj_record.t;
                    }
                }
                return record;
            },
        }
    }
};
