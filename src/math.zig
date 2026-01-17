const stdmath = @import("std").math;

pub const inf = stdmath.inf(f32);
pub const pi: f32 = stdmath.pi;

pub fn deg_to_rad(deg: f32) f32 {
    return deg * pi / 180.0;
}

pub fn rad_to_deg(rad: f32) f32 {
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

    // generates f32 in range [0, 1)
    pub fn next_f32(self: *Random) f32 {
        const val: f32 = @floatFromInt(self.next_u32() >> 8);
        const inv_max: f32 = 1.0 / @as(f32, @floatFromInt(@as(u32, 1) << 24));
        return val * inv_max;
    }
};

pub const Vec3 = packed struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

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

    pub fn scale(self: Vec3, scalar: f32) Vec3 {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn scaleAssign(self: *Vec3, scalar: f32) void {
        self.x *= scalar;
        self.y *= scalar;
        self.z *= scalar;
    }

    pub fn divScalar(self: Vec3, scalar: f32) Vec3 {
        return self.scale(1.0 / scalar);
    }

    pub fn neg(self: Vec3) Vec3 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn len(self: Vec3) f32 {
        return @sqrt(self.len2());
    }

    pub fn len2(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn norm(self: Vec3) Vec3 {
        return self.scale(1.0 / self.len());
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
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

    pub fn at(self: *const Ray, t: f32) Point {
        return self.origin.add(self.dir.scale(t));
    }
};

pub const Range = packed struct {
    min: f32 = 0.0,
    max: f32 = 0.0,

    pub const empty = Range{ .min = inf, .max = -inf };
    pub const universe = Range{ .min = -inf, .max = inf };
    pub const forward = Range{ .min = 0.0, .max = inf };

    pub fn size(self: Range) f32 {
        return self.max - self.min;
    }

    pub fn contains(self: Range, x: f32) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Range, x: f32) bool {
        return self.min < x and x < self.max;
    }

    pub fn clamp(self: Range, x: f32) f32 {
        return @min(@max(self.min, x), self.max);
    }
};
