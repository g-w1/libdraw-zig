const std = @import("std");
const ld = @import("../src/libdraw.zig");
pub fn main() !void {
    const ally = std.heap.page_allocator;
    const d = ld.initDraw(ally, null, "rainbow") catch |e| {
        std.debug.print("errstr: {s}\n", .{std.os.plan9.errstr()});
        return e;
    };
    const screen = d.getScreen();
    const colors = [_]u32{
        ld.Color.Black,
        ld.Color.White,
        ld.Color.Red,
        ld.Color.Green,
        ld.Color.Blue,
        ld.Color.Cyan,
        ld.Color.Magenta,
        ld.Color.Yellow,
        ld.Color.Paleyellow,
        ld.Color.Darkyellow,
        ld.Color.Darkgreen,
        ld.Color.Palegreen,
        ld.Color.Medgreen,
        ld.Color.Darkblue,
        ld.Color.Palebluegreen,
        ld.Color.Paleblue,
        ld.Color.Bluegreen,
        ld.Color.Greygreen,
        ld.Color.Palegreygreen,
        ld.Color.Yellowgreen,
        ld.Color.Medblue,
        ld.Color.Greyblue,
        ld.Color.Palegreyblue,
        ld.Color.Purpleblue,
    };
    var images: [colors.len]*ld.Image = undefined;
    for (colors, 0..) |color, i| {
        images[i] = try d.allocImage(ld.Rectangle.init(0, 0, 1, 1), ld.Chan.rgb24, true, color);
        try d.flushImage(true);
    }
    while (true) {
        for (images) |image| {
            try screen.draw(screen.r, image, null, ld.Point.Zero);
            try d.flushImage(true);
            _ = std.os.plan9.syscall_bits.syscall1(.SLEEP, 750);
        }
    }
}
