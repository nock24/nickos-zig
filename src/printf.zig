const std = @import("std");
const mini_uart = @import("mini_uart.zig");

fn writeFn(_: void, str: []const u8) error{}!usize {
    mini_uart.send_str(str);
    return str.len;
}

const writer = std.io.GenericWriter(void, error{}, writeFn){
    .context = {},
};

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    std.fmt.format(writer, fmt, args) catch @panic("format error");
}
