const std = @import("std");

pub fn parseIntSkipPreceedingSpaces(comptime T: type, buf: []const u8) !T {
    var i: u32 = 0;
    while (buf[i] == ' ') i += 1;
    const int = try std.fmt.parseInt(T, buf[i..], 10);
    return int;
}

pub const Image = struct {
    display: *Display, // display holding data
    id: u32, // id of system-held Image
    r: Rectangle, // rectangle in data area, local coords
    clipr: Rectangle, // clipping region
    depth: u32, // number of bits per pixel
    chan: Chan,
    repl: bool, // flag: data replicates to tile clipr
    screen: ?*Screen, // 0 if not a window
    next: ?*Image, // next in list of windows
    fn allocScreen(image: *Image, fill: *Image, public: bool) !*Screen {
        const d = image.display;
        if (d != fill.display)
            return error.ImageAndFillOnDifferentDisplays;
        var s = try d.ally.create(Screen);
        errdefer d.ally.destroy(s);
        if (screenid == 0) {
            screenid = std.os.plan9.getpid();
        }
        var id: u32 = 0;
        var trys: usize = 0;
        while (trys < 25) : (trys += 1) {
            var a = try d.allocBuf(1 + 4 + 4 + 4 + 1);
            screenid += 1;
            id = screenid & 0xffff; // old devdraw bug
            a.writeByte('A') catch unreachable;
            a.writeIntLittle(u32, id) catch unreachable;
            a.writeIntLittle(u32, image.id) catch unreachable;
            a.writeIntLittle(u32, fill.id) catch unreachable;
            a.writeByte(@intFromBool(public)) catch unreachable;
            try d.flushImage(false);
        }
        s.display = d;
        s.id = id;
        s.image = image;
        s.fill = fill;
        return s;
    }
    pub fn free(self: *Image) !void {
        try Display.freeImage1(self);
        self.display.ally.destroy(self);
    }
    pub fn line(dest: *Image, p0: Point, p1: Point, end0: u32, end1: u32, radius: u32, src: *Image, sp: Point) !void {
        return dest.lineop(p0, p1, end0, end1, radius, src, sp, DrawOp.SoverD);
    }
    pub fn lineop(dst: *Image, p0: Point, p1: Point, end0: u32, end1: u32, radius: u32, src: *Image, sp: Point, op: DrawOp) !void {
        const d = dst.display;
        try d.setDrawOp(op);
        var a = try d.allocBuf(1 + 4 + 2 * 4 + 2 * 4 + 4 + 4 + 4 + 4 + 2 * 4);
        a.writeByte('L') catch unreachable;
        a.writeIntLittle(u32, dst.id) catch unreachable;
        a.writeIntLittle(u32, p0.x) catch unreachable;
        a.writeIntLittle(u32, p0.y) catch unreachable;
        a.writeIntLittle(u32, p1.x) catch unreachable;
        a.writeIntLittle(u32, p1.y) catch unreachable;
        a.writeIntLittle(u32, end0) catch unreachable;
        a.writeIntLittle(u32, end1) catch unreachable;
        a.writeIntLittle(u32, radius) catch unreachable;
        a.writeIntLittle(u32, src.id) catch unreachable;
        a.writeIntLittle(u32, sp.x) catch unreachable;
        a.writeIntLittle(u32, sp.y) catch unreachable;
    }
    pub fn draw1(dst: *Image, r: Rectangle, src: ?*Image, p0: Point, mask: ?*Image, p1: Point, op: DrawOp) !void {
        const d = dst.display;
        try d.setDrawOp(op);

        var a = try d.allocBuf(1 + 4 + 4 + 4 + 4 * 4 + 2 * 4 + 2 * 4);
        const s = src orelse d.black;
        const m = mask orelse d.@"opaque";
        a.writeByte('d') catch unreachable;
        a.writeIntLittle(u32, dst.id) catch unreachable;
        a.writeIntLittle(u32, s.id) catch unreachable;
        a.writeIntLittle(u32, m.id) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(r.min.x))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(r.min.y))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(r.max.x))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(r.max.y))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(p0.x))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(p0.y))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(p1.x))) catch unreachable;
        a.writeIntLittle(u32, @as(u32, @bitCast(p1.y))) catch unreachable;
    }

    pub fn draw(dst: *Image, r: Rectangle, src: *Image, mask: ?*Image, p1: Point) !void {
        return draw1(dst, r, src, p1, mask, p1, .soverD);
    }

    pub fn drawop(dst: *Image, r: Rectangle, src: ?*Image, mask: ?*Image, p1: Point, op: DrawOp) !void {
        return draw1(dst, r, src, p1, mask, p1, op);
    }

    pub fn gendraw(dst: *Image, r: Rectangle, src: ?*Image, p0: Point, mask: ?*Image, p1: Point) !void {
        return draw1(dst, r, src, p0, mask, p1, .soverD);
    }

    pub fn gendrawop(dst: *Image, r: Rectangle, src: ?*Image, p0: Point, mask: ?*Image, p1: Point, op: DrawOp) !void {
        return draw1(dst, r, src, p0, mask, p1, op);
    }
};
/// Porter-Duff compositing operators
const DrawOp = enum(u8) {
    pub const Clear = 0;

    pub const SinD = 8;
    pub const DinS = 4;
    pub const SoutD = 2;
    pub const DoutS = 1;

    pub const S = SinD | SoutD;
    pub const SoverD = SinD | SoutD | DoutS;
    pub const SatopD = SinD | DoutS;
    pub const SxorD = SoutD | DoutS;

    pub const D = DinS | DoutS;
    pub const DoverS = DinS | DoutS | SoutD;
    pub const DatopS = DinS | SoutD;
    pub const DxorS = DoutS | SoutD; // == SxorD

    pub const Ncomp = 12;

    sinD = SinD,
    dinS = DinS,
    soutD = SoutD,
    doutS = DoutS,

    s = S,
    soverD = SoverD,
    satopD = SatopD,
    sxorD = SxorD,

    d = D,
    doverS = DoverS,
    datopS = DatopS,
    // dxorS = DxorS, // == SxorD TODO have multiple enum vals with the same name

};
var screenid: u32 = 0;
pub const Point = struct {
    x: i32,
    y: i32,
    pub const Zero: Point = .{ .x = 0, .y = 0 };
};
pub const Rectangle = struct {
    min: Point,
    max: Point,
    pub const Zero: Rectangle = .{ .min = Point.Zero, .max = Point.Zero };
    pub fn init(min_x: i32, min_y: i32, max_x: i32, max_y: i32) Rectangle {
        return .{
            .min = .{
                .x = min_x,
                .y = min_y,
            },
            .max = .{
                .x = max_x,
                .y = max_y,
            },
        };
    }
    pub fn isBad(self: Rectangle) bool {
        const x = self.dX();
        const y = self.dY();
        if (x > 0 and y > 0) {
            const z = x * y;
            if (@divFloor(z, x) == y and z < 0x10000000) return false;
        }
        return true;
    }
    pub fn dX(self: Rectangle) i64 {
        return self.max.x - self.min.x;
    }
    pub fn dY(self: Rectangle) i64 {
        return self.max.y - self.min.y;
    }
    pub fn inset(self: Rectangle, n: i32) Rectangle {
        var r = self;
        r.min.x += n;
        r.min.y += n;
        r.max.x -= n;
        r.max.y -= n;
        return r;
    }
};
pub const Screen = struct {
    display: *Display, // display holding data
    id: u32, // id of system-held Screen
    image: *Image, // unused; for reference only
    fill: *Image, // color to paint behind windows
    fn free(self: *Screen) !void {
        const d = self.display;
        try d.freeRemote(self.id, .screen);
        d.ally.destroy(self);
    }
};
pub const Display = struct {
    ally: std.mem.Allocator,
    qlock: void, // some sort of mutex???
    locking: bool, // program is using lockdisplay
    dirno: u32, // the window id
    fd: std.fs.File,
    reffd: std.fs.File,
    ctlfd: std.fs.File,
    imageid: u32 = 0,
    local: u32,
    @"error": void, //  void		(*error)(Display*, char*);
    devdir: []const u8 = "/dev",
    windir: []const u8 = "/dev",
    oldlabel: [64]u8,
    dataqid: u64,
    white: *Image,
    black: *Image,
    @"opaque": *Image,
    transparent: *Image,
    image: ?*Image,
    buf: []u8,
    bufsize: u32,
    bufp: [*]u8,
    defaultfont: void, // TODO deal with this
    subfont: void, // TODO deal with this
    windows: ?*Image,
    screenimage: ?*Image,
    _isnewdisplay: bool,
    screen: ?*Image = null,
    _screen: ?*Screen = null,
    abpos: usize = 0, // for use in the writer
    pub fn init(ally: std.mem.Allocator, options: struct { devdir: []const u8 = "/dev", windir: []const u8 = "/dev" }) !*Display {
        const NINFO = 12 * 12;
        var info: [NINFO + 1]u8 = undefined;
        var buf: [512]u8 = undefined;
        var image: ?*Image = null;
        const ctlfd = try std.fs.openFileAbsolute(try std.fmt.bufPrint(&buf, "{s}/draw/new", .{options.devdir}), .{ .mode = .read_write });
        errdefer ctlfd.close();
        var n = try ctlfd.read(&info);
        if (n < 12) {
            return error.InvalidReadFromDrawCtl;
        }
        if (n == NINFO + 1) n = NINFO;
        info[n] = 0;
        const infoslice = info[0..n];
        var isnew: bool = false;
        if (n < NINFO) isnew = true;
        const winnum = try parseIntSkipPreceedingSpaces(u32, infoslice[0 .. 1 * 12 - 1]);
        const datafd = try std.fs.openFileAbsolute(try std.fmt.bufPrint(&buf, "{s}/draw/{d}/data", .{ options.devdir, winnum }), .{ .mode = .read_write });
        errdefer datafd.close();
        const reffd = try std.fs.openFileAbsolute(try std.fmt.bufPrint(&buf, "{s}/draw/{d}/refresh", .{ options.devdir, winnum }), .{});
        errdefer reffd.close();
        const disp = try ally.create(Display);
        disp.ally = ally;
        if (n >= NINFO) {
            image = try ally.create(Image);
            errdefer ally.destroy(image.?);

            const chan = Chan.fromString(infoslice[2 * 12 .. 3 * 12 - 1]);
            image.?.* = .{
                .display = disp,
                .id = 0,
                .chan = chan,
                .depth = chan.depth(),
                .repl = try parseIntSkipPreceedingSpaces(u32, infoslice[3 * 12 .. 4 * 12 - 1]) != 0,
                .r = .{
                    .min = .{
                        .x = try parseIntSkipPreceedingSpaces(i32, infoslice[4 * 12 .. 5 * 12 - 1]),
                        .y = try parseIntSkipPreceedingSpaces(i32, infoslice[5 * 12 .. 6 * 12 - 1]),
                    },
                    .max = .{
                        .x = try parseIntSkipPreceedingSpaces(i32, infoslice[6 * 12 .. 7 * 12 - 1]),
                        .y = try parseIntSkipPreceedingSpaces(i32, infoslice[7 * 12 .. 8 * 12 - 1]),
                    },
                },
                .clipr = .{
                    .min = .{
                        .x = try parseIntSkipPreceedingSpaces(i32, infoslice[8 * 12 .. 9 * 12 - 1]),
                        .y = try parseIntSkipPreceedingSpaces(i32, infoslice[9 * 12 .. 10 * 12 - 1]),
                    },
                    .max = .{
                        .x = try parseIntSkipPreceedingSpaces(i32, infoslice[10 * 12 .. 11 * 12 - 1]),
                        .y = try parseIntSkipPreceedingSpaces(i32, infoslice[11 * 12 .. 12 * 12 - 1]),
                    },
                },
                .screen = null,
                .next = null,
            };
        }
        // TODO refactor this into a disp.* = .{ ... } expression
        const bufsize_iounit = iounit(datafd);
        const bufsz = if (bufsize_iounit == 0) 8000 else if (disp.bufsize < 512) return error.IounitTooSmall else bufsize_iounit;
        disp.* = .{
            .ally = ally,
            .dirno = winnum,
            .fd = datafd,
            .reffd = reffd,
            .ctlfd = ctlfd,
            .imageid = 0,
            .local = 0,
            .devdir = options.devdir,
            .windir = options.windir,
            .oldlabel = .{0} ** 64,
            .dataqid = 0,
            .white = undefined, // filled in later
            .black = undefined, // filled in later
            .@"opaque" = undefined, // filled in later
            .transparent = undefined, // filled in later
            .buf = undefined, // filled in later
            .bufsize = bufsz,
            .bufp = undefined, // filled in later
            .windows = null,
            .screenimage = null,
            ._isnewdisplay = isnew,
            .qlock = {}, // TODO make this an actual lock
            .locking = false,
            .@"error" = {}, // TODO audit if we need this
            .image = image,
            .defaultfont = {},
            .subfont = {},
        };
        disp.buf = try ally.alloc(u8, bufsz + 5); // +5 for flush message;
        errdefer ally.free(disp.buf);
        disp.bufp = disp.buf.ptr;
        disp.white = try disp.allocImage(Rectangle.init(0, 0, 1, 1), .grey1, true, Color.White);
        disp.black = try disp.allocImage(Rectangle.init(0, 0, 1, 1), .grey1, true, Color.Black);
        // disp.error = error;
        disp.windir = try ally.dupe(u8, options.windir);
        errdefer ally.free(disp.windir);
        disp.devdir = try ally.dupe(u8, options.devdir);
        errdefer ally.free(disp.devdir);
        // qlock(&disp.qlock)
        disp.@"opaque" = disp.white;
        disp.transparent = disp.black;
        return disp;
    }
    pub fn allocImage(self: *Display, r: Rectangle, chan: Chan, repl: bool, col: u32) !*Image {
        return self._allocImage(null, r, chan, repl, col, 0, .backup);
    }
    fn _allocImage(self: *Display, ai: ?*Image, r: Rectangle, chan: Chan, repl: bool, col: u32, _screenid: u32, refresh: Refresh) !*Image {
        if (r.isBad()) {
            return error.BadRect;
        }
        if (@intFromEnum(chan) == 0) {
            return error.BadChanDesc;
        }
        const depth = chan.depth();
        if (depth == 0) {
            return error.BadChanDesc;
        }
        var a = try self.allocBuf(1 + 4 + 4 + 1 + 4 + 1 + 4 * 4 + 4 * 4 + 4);
        self.imageid += 1;
        const id = self.imageid;
        // start writing the protocol
        // everything is little endian
        a.writeByte('b') catch unreachable;
        a.writeIntLittle(u32, id) catch unreachable;
        a.writeIntLittle(u32, _screenid) catch unreachable;
        a.writeByte(@intFromEnum(refresh)) catch unreachable;
        a.writeIntLittle(u32, @intFromEnum(chan)) catch unreachable;
        a.writeByte(@intFromBool(repl)) catch unreachable;
        a.writeIntLittle(i32, r.min.x) catch unreachable;
        a.writeIntLittle(i32, r.min.y) catch unreachable;
        a.writeIntLittle(i32, r.max.x) catch unreachable;
        a.writeIntLittle(i32, r.max.y) catch unreachable;
        const clipr = if (repl)
            Rectangle.init(-0x3FFFFFFF, -0x3FFFFFFF, 0x3FFFFFFF, 0x3FFFFFFF)
        else
            r;
        a.writeIntLittle(i32, clipr.min.x) catch unreachable;
        a.writeIntLittle(i32, clipr.min.y) catch unreachable;
        a.writeIntLittle(i32, clipr.max.x) catch unreachable;
        a.writeIntLittle(i32, clipr.max.y) catch unreachable;
        a.writeIntLittle(u32, col) catch unreachable;
        var i: *Image = undefined;
        if (ai) |image| {
            i = image;
        } else {
            i = self.ally.create(Image) catch {
                try self.freeRemote(id, .image);
                return error.OutOfMemory;
            };
            errdefer self.ally.destroy(i);
        }
        i.* = .{ .display = self, .id = id, .depth = depth, .chan = chan, .r = r, .clipr = clipr, .repl = repl, .screen = null, .next = null };
        return i;
    }
    pub fn namedImage(self: *Display, name: []const u8) !*Image {
        if (name.len > 256) {
            return error.ImageNameTooLong;
        }
        self.flushImage(false) catch {};
        var a = try self.allocBuf(1 + 4 + 1 + name.len);
        self.imageid += 1;
        const id = self.imageid;
        a.writeByte('n') catch unreachable;
        a.writeIntLittle(u32, id) catch unreachable;
        a.writeByte(@intCast(name.len)) catch unreachable;
        a.writeAll(name) catch unreachable;
        try self.flushImage(false);
        var buf: [12 * 12 + 1]u8 = undefined;
        if (try self.ctlfd.pread(&buf, 0) < 12 * 12) {
            return error.CtlReadTooShort;
        }
        buf[12 * 12] = 0;
        var i = self.ally.create(Image) catch {
            try self.freeRemote(id, .image);
            try self.flushImage(false);
            return error.OutOfMemory;
        };
        errdefer self.ally.destroy(i);
        const chan = Chan.fromString(buf[2 * 12 .. 3 * 12 - 1]);
        i.* = .{
            .display = self,
            .id = id,
            .chan = chan,
            .depth = chan.depth(),
            .repl = try parseIntSkipPreceedingSpaces(u32, buf[3 * 12 .. 4 * 12 - 1]) != 0,
            .r = .{
                .min = .{
                    .x = try parseIntSkipPreceedingSpaces(i32, buf[4 * 12 .. 5 * 12 - 1]),
                    .y = try parseIntSkipPreceedingSpaces(i32, buf[5 * 12 .. 6 * 12 - 1]),
                },
                .max = .{
                    .x = try parseIntSkipPreceedingSpaces(i32, buf[6 * 12 .. 7 * 12 - 1]),
                    .y = try parseIntSkipPreceedingSpaces(i32, buf[7 * 12 .. 8 * 12 - 1]),
                },
            },
            .clipr = .{
                .min = .{
                    .x = try parseIntSkipPreceedingSpaces(i32, buf[8 * 12 .. 9 * 12 - 1]),
                    .y = try parseIntSkipPreceedingSpaces(i32, buf[9 * 12 .. 10 * 12 - 1]),
                },
                .max = .{
                    .x = try parseIntSkipPreceedingSpaces(i32, buf[10 * 12 .. 11 * 12 - 1]),
                    .y = try parseIntSkipPreceedingSpaces(i32, buf[11 * 12 .. 12 * 12 - 1]),
                },
            },
            .screen = null,
            .next = null,
        };
        return i;
    }
    fn _allocWindow(self: *Display, i: ?*Image, s: *Screen, r: Rectangle, ref: Refresh, col: u32) !*Image {
        var im = try self._allocImage(i, r, self.screenimage.?.chan, false, col, s.id, ref);
        im.screen = s;
        im.next = self.windows;
        self.windows = im;
        return im;
    }
    fn freeRemote(self: *Display, id: u32, t: enum { image, screen }) !void {
        var a = try self.allocBuf(1 + 4);
        const c: u8 = if (t == .image) 'f' else 'F';
        a.writeByte(c) catch unreachable;
        a.writeIntLittle(u32, id) catch unreachable;
    }
    fn freeImage1(image: *Image) !void {
        const d = image.display;
        if (image.screen != null) {
            var w: ?*Image = d.windows;
            if (w.? == image) {
                d.windows = image.next;
            } else {
                while (w != null) {
                    if (w.?.next == image) {
                        w.?.next = image.next;
                        break;
                    }
                    w = w.?.next;
                }
            }
        }
        try d.freeRemote(image.id, .image);
    }
    const AllocedBuf = struct {
        buffer: []u8,
        pos: *usize,
        fn writer(self: AllocedBuf) std.io.Writer(AllocedBuf, error{}, write) {
            return .{ .context = self };
        }
        fn write(self: AllocedBuf, bytes: []const u8) error{}!usize {
            if (bytes.len == 0) return 0;
            if (self.pos.* >= self.buffer.len) unreachable; // we don't allocate more than we use

            const n = if (self.pos.* + bytes.len <= self.buffer.len)
                bytes.len
            else
                self.buffer.len - self.pos.*;

            @memcpy(self.buffer[self.pos.*..][0..n], bytes[0..n]);
            self.pos.* += n;

            if (n == 0) unreachable;

            return n;
        }
    };
    pub fn allocBuf(self: *Display, n: usize) !std.io.Writer(AllocedBuf, error{}, AllocedBuf.write) {
        if (n > self.bufsize) {
            return error.BadCountBufSize;
        }
        if (@intFromPtr(self.bufp + n) > @intFromPtr(self.buf.ptr + self.bufsize)) {
            try self.flush();
        }
        const p = self.bufp;
        self.bufp += n;
        self.abpos = 0;
        var ab = AllocedBuf{ .buffer = p[0..n], .pos = &self.abpos };
        return ab.writer();
    }
    pub fn flush(self: *Display) !void {
        const n: i64 = @intCast(@intFromPtr(self.bufp) - @intFromPtr(self.buf.ptr));
        if (n <= 0) return error.UnableToFlushInvalidN;
        // std.debug.print("about to flush: {}\n{s}\n", .{ std.fmt.fmtSliceHexLower(self.buf[0..@intCast(n)]), self.buf[0..@intCast(n)] });
        if ((self.fd.write(self.buf[0..@intCast(n)]) catch return error.UnableToFlushWrite) != n) {
            self.bufp = self.buf.ptr; // might as well; chance of continuing
            return error.UnableToFlushN;
        }
        self.bufp = self.buf.ptr;
    }
    pub fn flushImage(self: *Display, visible: bool) !void {
        if (visible) {
            self.bufp[0] = 'v';
            self.bufp += 1;
            if (self._isnewdisplay) {
                std.mem.writeIntLittle(u32, self.bufp[0..4], self.screenimage.?.id);
            }
        }
        return self.flush();
    }
    pub fn genGetWindow(self: *Display, winname: []const u8, winp: *?*Image, scrp: *?*Screen, ref: Refresh) !void {
        var buf: [64 + 1]u8 = undefined;
        var obuf: [64 + 1]u8 = undefined;
        var image: ?*Image = null;
        obuf[0] = 0;
        while (true) {
            const fd = std.fs.openFileAbsolute(winname, .{}) catch {
                std.mem.copyForwards(u8, &buf, "noborder");
                image = self.image;
                break;
            };
            var n: ?usize = fd.read(buf[0..64]) catch null;
            if (n == 0) n = null; // TODO do I need this?
            if (n == null) {
                fd.close();
                std.mem.copyForwards(u8, &buf, "noborder");
                image = self.image;
                break;
            }
            // we correctly read in to buf
            fd.close();
            image = self.namedImage(buf[0..n.?]) catch |err| {
                std.debug.print("namedImage: {}\n", .{err});
                if (!std.mem.eql(u8, buf[0..n.?], obuf[0..n.?])) {
                    std.debug.print("trying to fix the race\n", .{});
                    std.mem.copyForwards(u8, obuf[0..n.?], buf[0..n.?]);
                    continue;
                }
                break;
            };
            break;
        }
        if (winp.*) |i| {
            try freeImage1(i);
            if (scrp.*.?.image != self.image)
                try scrp.*.?.image.free();
            try scrp.*.?.free();
            scrp.* = null;
        }
        if (image == null) {
            winp.* = null;
            self.screenimage = null;
            return error.CouldNotGetImage; // TODO audit this error
        }
        self.screenimage = image.?;
        scrp.* = image.?.allocScreen(self.white, false) catch |err| {
            winp.* = null;
            self.screenimage = null;
            if (image != self.image) {
                if (image) |i| try i.free();
            }
            return err;
        };
        const i = image.?;
        var r = i.r;
        if (!std.mem.eql(u8, buf[0..8], "noborder")) {
            r = r.inset(Borderwidth);
        }
        winp.* = self._allocWindow(winp.*, scrp.*.?, r, ref, Color.White) catch |err| {
            std.debug.print("could not alloc window {}\n", .{err});
            try scrp.*.?.free();
            scrp.* = null;
            self.screenimage = null;
            if (image != self.image)
                if (image) |im|
                    try im.free();
            return err;
        };
        self.screenimage = winp.*;
    }
    pub fn setDrawOp(self: *Display, op: DrawOp) !void {
        if (op != .soverD) {
            var a = try self.allocBuf(1 + 1);
            a.writeByte('O') catch unreachable;
            a.writeByte(@intFromEnum(op)) catch unreachable;
        }
    }
    // asserts self.screen != null
    pub fn getScreen(self: Display) *Image {
        return self.screen.?;
    }
};
fn iounit(file: std.fs.File) u32 {
    var buf: [128]u8 = undefined;
    const f = std.fmt.bufPrint(&buf, "/fd/{d}ctl", .{file.handle}) catch unreachable;
    const cfd = std.fs.openFileAbsolute(f, .{}) catch return 0;
    defer cfd.close();
    const i = cfd.read(&buf) catch 0;
    if (i == 0)
        return 0;
    const str = buf[0..i];
    var toks = std.mem.tokenizeSequence(u8, str, " ");
    var j: usize = 0;
    // skip the first 7
    while (j < 7) : (j += 1) _ = toks.next() orelse return 0;
    const iounit_str = toks.next() orelse return 0;
    return std.fmt.parseInt(u32, iounit_str, 10) catch return 0;
}
pub const Chan = enum(u32) {
    const CColor = struct {
        const Red = 0;
        const Green = 1;
        const Blue = 2;
        const Grey = 3;
        const Alpha = 4;
        const Map = 5;
        const Ignore = 6;
    };
    pub const NChan = 7;
    grey1 = chan1(CColor.Grey, 1),
    grey2 = chan1(CColor.Grey, 2),
    grey4 = chan1(CColor.Grey, 4),
    grey8 = chan1(CColor.Grey, 8),
    cmap8 = chan1(CColor.Map, 8),
    rgb15 = chan4(CColor.Ignore, 1, CColor.Red, 5, CColor.Green, 5, CColor.Blue, 5),
    rgb16 = chan3(CColor.Red, 5, CColor.Green, 6, CColor.Blue, 5),
    rgb24 = chan3(CColor.Red, 8, CColor.Green, 8, CColor.Blue, 8),
    rgba32 = chan4(CColor.Red, 8, CColor.Green, 8, CColor.Blue, 8, CColor.Alpha, 8),
    argb32 = chan4(CColor.Alpha, 8, CColor.Red, 8, CColor.Green, 8, CColor.Blue, 8),
    xrgb32 = chan4(CColor.Ignore, 8, CColor.Red, 8, CColor.Green, 8, CColor.Blue, 8),
    bgr24 = chan3(CColor.Blue, 8, CColor.Green, 8, CColor.Red, 8),
    abgr32 = chan4(CColor.Alpha, 8, CColor.Blue, 8, CColor.Green, 8, CColor.Red, 8),
    xbgr32 = chan4(CColor.Ignore, 8, CColor.Blue, 8, CColor.Green, 8, CColor.Red, 8),
    _,
    const channames: []const u8 = "rgbkamx";
    fn TYPE(self: u32) u32 {
        return (self >> 4) & 15;
    }
    fn NBITS(self: u32) u32 {
        return self & 15;
    }
    pub fn fromString(str: []const u8) Chan {
        // strip str
        const spaces: []const u8 = &.{ ' ', '\t', '\r', '\n' };
        const pos = std.mem.indexOfNone(u8, str, spaces).?;
        const s = str[pos..];

        var d: u32 = 0;
        var chan: u32 = 0;
        var i: usize = 0;
        const chan_ = blk: {
            while (i < s.len) : (i += 2) {
                if (std.ascii.isWhitespace(s[i])) break;
                if (std.mem.indexOfScalar(u8, channames, s[i])) |ty| {
                    const n = std.fmt.parseInt(u8, s[i + 1 .. i + 2], 10) catch break :blk 0;
                    d += n;
                    chan <<= 8;
                    chan |= dc(@intCast(ty), @intCast(n));
                } else break :blk 0;
            }
            if (d == 0 or (d > 8 and d % 8 != 0) or (d < 8 and 8 % d != 0)) break :blk 0;
            break :blk chan;
        };

        return @enumFromInt(chan_);
    }
    pub fn toString(self: Chan, buf: []u8) ![]const u8 {
        if (self.depth() == 0) {
            return error.ChanDepthIsZero;
        }
        var rc: u32 = 0;
        var c = @intFromEnum(self);
        while (c != 0) : (c >>= 8) {
            rc <<= 8;
            rc |= c & 0xff;
        }
        var i: usize = 0;
        c = rc;
        while (c != 0) : (c >>= 8) {
            buf[i] = channames[TYPE(c)];
            i += 1;
            buf[i] = @intCast('0' + NBITS(c));
            i += 1;
        }
        return buf[0..i];
    }
    pub fn depth(self: Chan) u32 {
        var d: u32 = 0;
        var c: u32 = @intFromEnum(self);
        while (c != 0) : (c >>= 8) {
            d += cdepth(c);
        }
        if (d == 0 or (d > 8 and d % 8 != 0) or (d < 8 and 8 % d != 0)) return 0;
        return d;
    }
    fn dc(ty: u32, nbit: u32) u32 {
        return ((ty & 15) << 4) | (nbit & 15);
    }
    fn cdepth(c: u32) u32 {
        return c & 0xf;
    }
    pub fn chan1(a: u32, b: u32) u32 {
        return dc(a, b);
    }
    pub fn chan2(a: u32, b: u32, c: u32, d: u32) u32 {
        return chan1(a, b) << 8 | dc(c, d);
    }
    pub fn chan3(a: u32, b: u32, c: u32, d: u32, e: u32, f: u32) u32 {
        return chan2(a, b, c, d) << 8 | dc(e, f);
    }
    pub fn chan4(a: u32, b: u32, c: u32, d: u32, e: u32, f: u32, g: u32, h: u32) u32 {
        return chan3(a, b, c, d, e, f) << 8 | dc(g, h);
    }
};
pub const Color = struct {
    pub const Opaque = 0xFFFFFFFF;
    pub const Transparent = 0x00000000; // only useful for allocimage, memfillcolor
    pub const Black = 0x000000FF;
    pub const White = 0xFFFFFFFF;
    pub const Red = 0xFF0000FF;
    pub const Green = 0x00FF00FF;
    pub const Blue = 0x0000FFFF;
    pub const Cyan = 0x00FFFFFF;
    pub const Magenta = 0xFF00FFFF;
    pub const Yellow = 0xFFFF00FF;
    pub const Paleyellow = 0xFFFFAAFF;
    pub const Darkyellow = 0xEEEE9EFF;
    pub const Darkgreen = 0x448844FF;
    pub const Palegreen = 0xAAFFAAFF;
    pub const Medgreen = 0x88CC88FF;
    pub const Darkblue = 0x000055FF;
    pub const Palebluegreen = 0xAAFFFFFF;
    pub const Paleblue = 0x0000BBFF;
    pub const Bluegreen = 0x008888FF;
    pub const Greygreen = 0x55AAAAFF;
    pub const Palegreygreen = 0x9EEEEEFF;
    pub const Yellowgreen = 0x99994CFF;
    pub const Medblue = 0x000099FF;
    pub const Greyblue = 0x005DBBFF;
    pub const Palegreyblue = 0x4993DDFF;
    pub const Purpleblue = 0x8888CCFF;

    pub const Notacolor = 0xFFFFFF00;
    pub const Nofill = Notacolor;
};
pub const Borderwidth = 4;
/// Refresh methods
pub const Refresh = enum(u8) {
    backup = 0,
    none = 1,
    mesg = 2,
};
pub fn initDraw(ally: std.mem.Allocator, fontname: ?[]const u8, label: ?[]const u8) !*Display {
    return genInitDraw(
        ally,
        "/dev",
        fontname,
        label,
        "/dev",
        .none,
    );
}
pub fn genInitDraw(ally: std.mem.Allocator, devdir: []const u8, fontname: ?[]const u8, label: ?[]const u8, windir: []const u8, ref: Refresh) !*Display {
    var buf: [128]u8 = undefined;
    var display = try Display.init(ally, .{ .devdir = devdir, .windir = windir });
    // TODO deal with fonts
    _ = fontname;
    if (label) |l| blk: {
        const labelfds = std.fmt.bufPrint(&buf, "{s}/label", .{display.windir}) catch break :blk;
        const labelfd = std.fs.openFileAbsolute(labelfds, .{ .mode = .read_write }) catch break :blk;
        defer labelfd.close();
        _ = try labelfd.write(l);
    }
    const winnamefds = std.fmt.bufPrint(&buf, "{s}/winname", .{display.windir}) catch unreachable;
    try display.genGetWindow(winnamefds, &display.screen, &display._screen, ref);
    return display;
}
