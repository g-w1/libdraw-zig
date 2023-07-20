const std = @import("std");
const ld = @import("../src/libdraw.zig");
const SQUARELEN = 40;
const SPACING = 15;
const Point = ld.Point;
const Rectangle = ld.Rectangle;
const Ball = struct {
    const FPoint = struct {
        x: f32,
        y: f32,
        fn toPoint(self: @This()) Point {
            return .{ .x = @intFromFloat(self.x), .y = @intFromFloat(self.y) };
        }
    };
    pos: FPoint,
    vel: FPoint,
    fn collide(b: *Ball) void {
        var i: u16 = 0;
        while (i < numbricks_vert) : (i += 1) {
            var j: u16 = 0;
            while (j < numbricks_horiz) : (j += 1) {
                const val = bricks[i * numbricks_vert + j];
                if (val == 0) continue;
                switch (b.testCollide(i, j)) {
                    .horiz => {
                        bricks[i * numbricks_vert + j] -|= 1;
                        b.vel.y *= -1;
                        return;
                    },
                    .vert => {
                        bricks[i * numbricks_vert + j] -|= 1;
                        b.vel.x *= -1;
                        return;
                    },
                    .none => {},
                }
            }
        }
    }
    fn testCollide(self: Ball, i: u16, j: u16) enum { horiz, vert, none } {
        const brick = getBrickRect(i, j);
        const p = self.pos.toPoint();
        const brickcenter: Point = .{ .x = brick.min.x + @divFloor(brick.width(), 2), .y = @divFloor(brick.min.y + brick.height(), 2) };
        if (p.x >= brick.min.x and
            p.x <= brick.max.x and
            p.y >= brick.min.y and
            p.y <= brick.max.y)
        {
            // const a = std.math.radiansToDegrees(f32, std.math.atan2(f32, @as(f32, @floatFromInt(brickcenter.y - p.y)), @as(f32, @floatFromInt(brickcenter.x - p.x))));
            // if (@fabs(a) < 45 or @fabs(a) >= 135) return .horiz;
            // return .vert;
            if (std.math.absInt(p.x - brickcenter.x) catch unreachable < std.math.absInt(p.y - brickcenter.y) catch unreachable) return .vert;
            return .horiz;
        }
        return .none;
    }
};
var bricks: []u32 = undefined;
var screenr: ld.Rectangle = undefined;
var balls: std.ArrayList(Ball) = undefined;
var numbricks_vert: u32 = undefined;
var numbricks_horiz: u32 = undefined;
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
fn getBrickRect(i: u16, j: u16) Rectangle {
    return Rectangle.init(screenr.min.x + SQUARELEN * j, screenr.min.y + SQUARELEN * i, screenr.min.x + SQUARELEN * (j + 1) - SPACING, screenr.min.y + SQUARELEN * (i + 1) - SPACING);
}
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
    for (cs, &colors) |c, *color| {
        color.* = try d.allocImage(Rectangle.init(0, 0, 1, 1), .rgba32, true, c);
    }
    screenr = screen.r;
    numbricks_horiz = @intCast(@divFloor(width, SQUARELEN));
    numbricks_vert = @intCast(@divFloor(height, SQUARELEN) - 3);
    bricks = try ally.alloc(u32, numbricks_horiz * numbricks_vert);
    for (bricks) |*square| {
        square.* = 14;
    }
    balls = try std.ArrayList(Ball).initCapacity(ally, 40);
    // var angle: f32 = std.math.degreesToRadians(f32, 80);
    // try balls.append(.{ .pos = .{ .x = @divFloor(screenr.min.x + screenr.max.x, 2), .y = screenr.max.y }, .vel = .{ .x = @cos(angle), .y = @sin(angle) } });
    try balls.append(.{ .pos = .{ .x = @as(f32, @floatFromInt(screenr.min.x + screenr.max.x)) / 2.0, .y = @as(f32, @floatFromInt(screenr.max.y)) }, .vel = .{ .x = 3.4, .y = 2.8 } });
    try balls.append(.{ .pos = .{ .x = @as(f32, @floatFromInt(screenr.min.x + screenr.max.x)) / 2.0, .y = @as(f32, @floatFromInt(screenr.max.y)) }, .vel = .{ .x = 1.4, .y = 7.8 } });
    try balls.append(.{ .pos = .{ .x = @as(f32, @floatFromInt(screenr.min.x + screenr.max.x)) / 2.0, .y = @as(f32, @floatFromInt(screenr.max.y)) }, .vel = .{ .x = 0.4, .y = 8.8 } });
    try balls.append(.{ .pos = .{ .x = @as(f32, @floatFromInt(screenr.min.x + screenr.max.x)) / 2.0, .y = @as(f32, @floatFromInt(screenr.max.y)) }, .vel = .{ .x = -4.1, .y = 0.5 } });
    while (true) {
        // clear the screen
        try screen.draw(screen.r, d.white, null, Point.Zero);
        // collide the balls
        // update the balls
        for (balls.items) |*ball| {
            ball.collide();
            ball.pos.x += ball.vel.x;
            ball.pos.y += ball.vel.y;
            const p = ball.pos.toPoint();
            if (p.x > screenr.max.x or p.x < screenr.min.x) {
                ball.vel.x *= -1;
            }
            if (p.y > screenr.max.y or p.y < screenr.min.y) {
                ball.vel.y *= -1;
            }
        }
        var quit = true;
        // draw the squares
        var i: u16 = 0;
        while (i < numbricks_vert) : (i += 1) {
            var j: u16 = 0;
            while (j < numbricks_horiz) : (j += 1) {
                const square = bricks[i * numbricks_vert + j];
                if (square > 0) {
                    quit = false;
                    try screen.draw(getBrickRect(i, j), colors[square], null, Point.Zero);
                }
            }
        }
        if (quit) break;
        for (balls.items) |ball| {
            try screen.ellipse(ball.pos.toPoint(), 3, 3, 3, d.black, Point.Zero);
        }
        try d.flushImage(true);
        _ = std.os.plan9.syscall_bits.syscall1(.SLEEP, 10);
    }
}
