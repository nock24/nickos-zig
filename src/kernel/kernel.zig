const std = @import("std");
const builtin = std.builtin;
const drivers = @import("drivers");
const serial = drivers.serial;
const shell = @import("shell.zig");
const kernel = @import("kernel");
const Buffer = kernel.Buffer;

export fn kernel_main() noreturn {
    serial.init();
    serial.writeStr("\n\nNickOS kernel initializing...\n");

    // YES: 1 to 6, 8 to 10, 12, 16 to 18, 20, 24 to 26, 28,
    // NO: 7, 11, 13, 14, 15, 19, 21, 22, 23, 27, 29, 30,
    
    comptime var len: usize = 30;
    inline while (len <= 30) : (len += 1) {
        serial.printf("{}: ", .{len});
        var buf: [len]u8 = undefined;
        @memset(&buf, 0);
        _ = serial.readLine(&buf);
    }

    shell.start();
}

pub fn panic(msg: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    serial.printf("\n[KERNEL PANIC]: {}", .{msg});
    while (true) {}
}
