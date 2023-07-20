#!/usr/bin/env bash 
# just a temporary fix until the x86_64 backend supports build.zig
~/dev/zig/build/debug/bin/zig build-exe "examples/$1.zig" --main-pkg-path . -target x86_64-plan9-none -freference-trace -fsingle-threaded --zig-lib-dir ~/dev/zig/lib
