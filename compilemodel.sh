#!/bin/sh
zig build run -- examples/TAG-204/model.ms
zig build verify
