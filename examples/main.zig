const std = @import("std");
const ld = @import("../src/libdraw.zig");
const SQUARELEN = 40;
const SPACING = 10;
pub fn main() !void {
    const ally = std.heap.page_allocator;
    const d = ld.initDraw(ally, null, "balls") catch |e| {
        std.debug.print("errstr: {s}\n", .{std.os.plan9.errstr()});
        return e;
    };
    defer d.close() catch {};
    const screen = d.getScreen();
    const width = screen.r.width();
    const height = screen.r.height();
    const numsquares_horiz: u32 = @intCast(@divFloor(width, SQUARELEN));
    const numsquares_vert: u32 = @intCast(@divFloor(height, SQUARELEN) - 3);
    var squares = try ally.alloc(u32, numsquares_horiz * numsquares_vert);
    for (squares) |*square| {
        square.* = 10;
    }
    const screenr = screen.r;
    try d.flushImage(true);
    var ball: ld.Point = .{ .x = @divFloor(screenr.min.x + screenr.max.x, 2), .y = screenr.max.y };
    var ballv: ld.Point = .{ .x = 1, .y = -1 };
    while (true) {
        try screen.draw(screen.r, d.white, null, ld.Point.Zero);
        ball.x += ballv.x;
        ball.y += ballv.y;
        if (ball.x > screenr.max.x or ball.x < screenr.min.x) {
            ballv.x *= -1;
        }
        if (ball.y > screenr.max.y or ball.y < screenr.min.y) {
            ballv.y *= -1;
        }
        var i: u16 = 0;
        while (i < numsquares_vert) : (i += 1) {
            var j: u16 = 0;
            while (j < numsquares_horiz) : (j += 1) {
                const square = squares[i * numsquares_vert + j];
                _ = square;
                var rect = ld.Rectangle.init(screenr.min.x + SQUARELEN * j, screenr.min.y + SQUARELEN * i, screenr.min.x + SQUARELEN * (j + 1) - SPACING, screenr.min.y + SQUARELEN * (i + 1) - SPACING);
                try screen.draw(rect, d.black, null, ld.Point.Zero);
            }
        }
        try screen.ellipse(ball, 10, 10, 10, d.black, ld.Point.Zero);
        try d.flushImage(true);
        _ = std.os.plan9.syscall_bits.syscall1(.SLEEP, 10);
    }
}
