#!/bin/bash
# examples/docs/ discovery (further down) has shown stale results
# across invocations on this toolchain — new or deleted example
# files not reflected until .zig-cache is cleared. Wiping it
# unconditionally here trades some incremental-compile speed for
# never hitting that "phantom missing/present file" mystery again.
# Revisit if full-rebuild time becomes a real cost as the project
# grows.
rm -rf .zig-cache
rm -rf .verify_scratch
zig build verify-examples