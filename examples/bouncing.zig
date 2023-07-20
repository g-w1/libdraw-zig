const std = @import("std");
const ld = @import("../src/libdraw.zig");
const Point = ld.Point;
const Rectangle = ld.Rectangle;
var colors: [15]*ld.Image = undefined;
const cs: [15]u32 = .{
    0xff0000ff,
    0xff3600ff,
    0xff6d00ff,
    0xffa400ff,
    0xffda00ff,
    0xdbff00ff,
    0x6dff00ff,
    0x00ff00ff,
    0x00926dff,
    0x0024dbff,
    0x1500dbff,
    0x3600a6ff,
    0x540094ff,
    0x7000c9ff,
    0x8b00ffff,
};
pub fn main() !void {
    const ally = std.heap.page_allocator;
    const d = ld.initDraw(ally, null, "balls") catch |e| {
        std.debug.print("errstr: {s}\n", .{std.os.plan9.errstr()});
        return e;
    };
    defer d.close() catch {};
    for (cs, &colors) |c, *color| {
        color.* = try d.allocImage(Rectangle.init(0, 0, 1, 1), .rgba32, true, c);
    }
    var frames: usize = 0;
    const screen = d.getScreen();
    var ball: ld.Point = .{ .x = @divFloor((screen.r.max.x + screen.r.min.x), 2), .y = screen.r.max.y };
    var vel: ld.Point = .{ .x = 2, .y = -1 };
    while (true) {
        frames += 1;
        try screen.draw(screen.r, d.white, null, ld.Point.Zero);
        try screen.ellipse(ball, 8, 8, 8, colors[@divFloor(frames, 30) % 15], ld.Point.Zero);
        ball.x += vel.x;
        ball.y += vel.y;
        vel.y += 2;
        if (ball.y > screen.r.max.y) {
            vel.y *= -1;
        }
        if (ball.x < screen.r.min.x or ball.x > screen.r.max.x) {
            vel.x *= -1;
        }
        try d.flushImage(true);
        _ = std.os.plan9.syscall_bits.syscall1(.SLEEP, 20);
    }
}
