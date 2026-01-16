const std = @import("std");
const qoi = @import("qoi");

pub fn main() !void {
    var image: [1024]u8 = @splat(0);


    for (0..16) |j| {
        for (0..16) |i| {
            const r = @as(f32, @floatFromInt(i)) / 15.0;
            const g = @as(f32, @floatFromInt(j)) / 15.0;
            const b: f32 = 0.0;

            const off = j * 16 * 3 + i * 3;
            image[off] = @intFromFloat(255.99 * r);
            image[off + 1] = @intFromFloat(255.99 * g);
            image[off + 2] = @intFromFloat(255.99 * b);
        }
    }

    const qoi_img = try qoi.encode(std.heap.smp_allocator, &image, .{
        .width = 16,
        .height = 16,
        .channels = .rgb,
        .colorspace = .srgb,
    });

    var io_buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout();
    var writer = stdout.writer(&io_buf);
    try writer.interface.writeAll(qoi_img);
    try writer.interface.flush();
}
