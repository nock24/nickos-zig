const StackTrace = @import("std").builtin.StackTrace;
const builtin = @import("builtin");
const mini_uart = @import("mini_uart.zig");
const printf = @import("printf.zig").printf;

export fn kernel_main() noreturn {
    mini_uart.init();
    mini_uart.send_str("NickOS kernel initializing...\n");
    mini_uart.send_str("\tBoard: PI 4");

    while (true) {
        const c = mini_uart.receive_char();
        mini_uart.send_char(c);
    }
}

pub fn panic(msg: []const u8, _: ?*StackTrace, _: ?usize) noreturn {
    mini_uart.send_str("panic: ");
    mini_uart.send_str(msg);
    while (true) {}
}
