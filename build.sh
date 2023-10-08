#!/usr/bin/env bash 
# just a temporary fix until the x86_64 backend supports build.zig
zig build-exe "examples/$1.zig" --main-pkg-path . -target x86_64-plan9-none -freference-trace -fsingle-threaded
