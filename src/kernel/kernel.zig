const std = @import("std");
const builtin = std.builtin;
const drivers = @import("drivers");
const serial = drivers.serial;
const shell = @import("shell.zig");

export fn kernel_main() noreturn {
    serial.init();
    serial.writeStr("\n\nNickOS kernel initializing...\n");

    shell.start();
}

pub fn panic(msg: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    serial.printf("\n[KERNEL PANIC]: {}", .{msg});
    while (true) {}
}
