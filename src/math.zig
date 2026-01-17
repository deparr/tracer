const stdmath = @import("std").math;

pub const inf = stdmath.inf(f64);
pub const pi: f64 = stdmath.pi;

pub fn deg_to_rad(deg: f64) f64 {
    return deg * pi / 180.0;
}

pub fn rad_to_deg(rad: f64) f64 {
    return rad * 180 / pi;
}

pub const Random = struct {
    state: u32,

    pub fn init(seed: u32) Random {
        return .{ .state = seed };
    }

    pub fn next_u32(self: *Random) u32 {
        var x = self.state;
        // George Marsaglia's xorshift paper (2003)
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.state = x;
        return x;
    }

    /// generates f32 in range [0, 1)
    pub fn next_f32(self: *Random) f32 {
        const inv_max: f32 = 1.0 / @as(f32, @floatFromInt(@as(u32, 1) << 24));

        const val: f32 = @floatFromInt(self.next_u32() >> 8);
        return val * inv_max;
    }

    /// generates f64 in range [0, 1)
    pub fn next_f64(self: *Random) f64 {
        const inv_max: f64 = 1.0 / @as(f64, @floatFromInt(@as(u64, 1) << 53));

        const hi: u64 = @as(u64, self.next_u32() >> 5); // 27 bits
        const lo: u64 = @as(u64, self.next_u32() >> 6); // 26 bits
        const val: f64 = @floatFromInt((hi << 26) | lo); // full mantissa, 53 bits
        return val * inv_max;
    }

    pub fn next_f64_range(self: *Random, min: f64, max: f64) f64 {
        return min + (max - min) * self.next_f64();
    }

    pub fn next_vec3(self: *Random) Vec3 {
        return .{ .x = self.next_f64(), .y = self.next_f64(), .z = self.next_f64() };
    }

    pub fn next_vec3_range(self: *Random, min: f64, max: f64) Vec3 {
        return .{
            .x = self.next_f64_range(min, max),
            .y = self.next_f64_range(min, max),
            .z = self.next_f64_range(min, max),
        };
    }

    pub fn next_norm_vec3(self: *Random) Vec3 {
        const iter_max = 1000;
        var i: u32 = 0;
        while (true and i < iter_max) : (i += 1) {
            const p = self.next_vec3_range(-1, 1);
            const lenp = p.len2();
            if (1e-160 < lenp and lenp <= 1.0) {
                return p.divScalar(@sqrt(lenp));
            }
        }
        @panic("failed to create a valid norm vec in 1000 iters");
    }

    pub fn next_vec3_on_hemisphere(self: *Random, normal: Vec3) Vec3 {
        const on_sphere = self.next_norm_vec3();
        return if (on_sphere.dot(normal) > 0.0)
            on_sphere
        else
            on_sphere.neg();
    }
};

pub const Vec3 = packed struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    pub const zero: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    pub const one: Vec3 = .{ .x = 1.0, .y = 1.0, .z = 1.0 };
    pub const black = zero;
    pub const white = one;

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn addAssign(self: *Vec3, other: Vec3) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
        };
    }

    pub fn scale(self: Vec3, scalar: f64) Vec3 {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn scaleAssign(self: *Vec3, scalar: f64) void {
        self.x *= scalar;
        self.y *= scalar;
        self.z *= scalar;
    }

    pub fn divScalar(self: Vec3, scalar: f64) Vec3 {
        return self.scale(1.0 / scalar);
    }

    pub fn neg(self: Vec3) Vec3 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn len(self: Vec3) f64 {
        return @sqrt(self.len2());
    }

    pub fn len2(self: Vec3) f64 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn norm(self: Vec3) Vec3 {
        return self.scale(1.0 / self.len());
    }

    pub fn dot(self: Vec3, other: Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }
};
pub const Point = Vec3;
pub const Color = Vec3;

pub const Ray = struct {
    origin: Point,
    dir: Vec3,

    pub fn at(self: *const Ray, t: f64) Point {
        return self.origin.add(self.dir.scale(t));
    }
};

pub const Range = packed struct {
    min: f64 = 0.0,
    max: f64 = 0.0,

    pub const empty = Range{ .min = inf, .max = -inf };
    pub const universe = Range{ .min = -inf, .max = inf };
    pub const forward = Range{ .min = 0.0, .max = inf };

    pub fn size(self: Range) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: Range, x: f64) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Range, x: f64) bool {
        return self.min < x and x < self.max;
    }

    pub fn clamp(self: Range, x: f64) f64 {
        return @min(@max(self.min, x), self.max);
    }
};
