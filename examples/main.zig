const std = @import("std");
const ld = @import("../src/libdraw.zig");
pub fn main() !void {
    const ally = std.heap.page_allocator;
    const d = ld.initDraw(ally, null, "bruh") catch |e| {
        std.debug.print("errstr: {s}\n", .{std.os.plan9.errstr()});
        return e;
    };
    const screen = d.getScreen();
    var buf: [128]u8 = undefined;
    _ = buf;
    try screen.draw(screen.r, d.white, null, ld.Point.Zero);
    try d.flushImage(true);
}
