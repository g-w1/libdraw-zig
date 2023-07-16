#!/usr/bin/env bash
 ~/dev/zig/build/debug/bin/zig build-exe test.zig -target x86_64-plan9-none -fsingle-threaded --zig-lib-dir ~/dev/zig/lib $@
