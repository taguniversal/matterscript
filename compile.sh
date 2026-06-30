#!/bin/sh
zig build run -- examples/model/model.ms
zig build run -- examples/coffee/coffee.ms.fsm
zig build verify
