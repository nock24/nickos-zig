const std = @import("std");
const builtin = std.builtin;
const serial = @import("serial.zig");

export fn kernel_main() noreturn {
    serial.init();
    serial.printf("NickOS kernel initializing...\n", .{});

    while (true) {
        const c = serial.readByte();
        serial.writeByte(c);
    }
}

pub fn panic(msg: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    serial.printf("\n[KERNEL PANIC]: {}", .{msg});
    while (true) {}
}
