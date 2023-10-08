# libdraw-zig

A (wip) library to interface with Plan 9's libdraw graphics protocol from pure Zig.

It reimplements the protocol, using the [C implementation](http://git.9front.org/plan9front/plan9front/7213f4a34d6b3bda61e6764d46980ef059adccdb/sys/src/libdraw/f.html) as a reference.

I tried to make this idomatic Zig, and once the x86_64 Zig backend progresses enough, I'll continue working on this.

Here's a demo:
![demo](./demo.mp4)
