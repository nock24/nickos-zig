const std = @import("std");
const math = std.math;
const meta = std.meta;
const kernel = @import("kernel");
const aux = kernel.aux;
const gpio = @import("gpio.zig");

const TXD: u8 = 14;
const RXD: u8 = 15;

pub fn init() void {
    aux.REGISTERS.enables = 1;
    aux.REGISTERS.mu_ier = 0;
    aux.REGISTERS.mu_control = 0;
    aux.REGISTERS.mu_lcr = 3;
    aux.REGISTERS.mu_mcr = 0;
    aux.REGISTERS.mu_ier = 0;
    aux.REGISTERS.mu_iir = 0xc6;
    aux.REGISTERS.mu_baud_rate = 270;

    gpio.pinSetFunc(TXD, .alt5);
    gpio.pinSetFunc(RXD, .alt5);

    gpio.pinEnable(TXD);
    gpio.pinEnable(RXD);

    aux.REGISTERS.mu_control = 3;
}

pub fn writeByte(byte: u8) void {
    while (aux.REGISTERS.mu_lsr & 0x20 == 0) {}

    aux.REGISTERS.mu_io = byte;
}

pub fn readByte() u8 {
    while (aux.REGISTERS.mu_lsr & 0x01 == 0) {}

    return @truncate(aux.REGISTERS.mu_io);
}

pub fn writeStr(str: []const u8) void {
    for (str) |char| {
        if (char == '\n') writeByte('\r');
        writeByte(char);
    }
}

fn printInt(int: anytype) void {
    if (@typeInfo(@TypeOf(int)) != .Int)
        @compileError(@typeName(@TypeOf(int)) ++ " is not an integer");
    const max_digit_cnt: usize = @ceil(@log10(@as(f32, math.maxInt(@TypeOf(int)))));

    var buf: [max_digit_cnt]u8 = undefined;
    @memset(&buf, 0);

    const digit_cnt: usize = @intFromFloat(@ceil(@log10(@as(f32, @floatFromInt(int)))));
    var i = digit_cnt - 1;
    var tmp = int;
    while (true) : (i -= 1) {
        buf[i] = @as(u8, @intCast(tmp % 10)) + '0';
        tmp /= 10;
        if (i == 0) break;
    }

    writeStr(buf[0..digit_cnt]);
}

inline fn isString(T: type) bool {
    if (T == []const u8) return true;
    const type_info = @typeInfo(T);
    if (type_info != .Pointer) return false;
    const child_info = @typeInfo(type_info.Pointer.child);
    if (child_info != .Array or
        child_info.Array.child != u8) return false;
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const args_info = @typeInfo(@TypeOf(args));
    if (args_info != .Struct or
        !args_info.Struct.is_tuple) @compileError("expected args tuple");
    const args_slice = args_info.Struct.fields;

    comptime var arg_idx: usize = 0;
    comptime var fmt_idx: usize = 0;

    inline while (fmt_idx < fmt.len) {
        const fmt_char = comptime fmt[fmt_idx];

        if (fmt_char == '}') @compileError("no start to placeholder");
        if (fmt_char != '{') {
            if (fmt_char == '\n') writeByte('\r');
            writeByte(fmt_char);
            fmt_idx += 1;
            continue;
        }

        // skipping past "{}"
        fmt_idx += 2;

        if (arg_idx >= args_slice.len) @compileError("not enough args");
        const arg = @field(args, args_slice[arg_idx].name);
        if (meta.hasMethod(@TypeOf(arg), "print"))
            arg.print()
        else {
            if (isString(@TypeOf(arg)))
                writeStr(arg)
            else if (@TypeOf(arg) == u8)
                writeByte(arg)
            else
                printInt(arg);
        }
        arg_idx += 1;
    }
}

/// Reads characters and prints them until the enter key is
/// pressed or `buf` is full.
pub fn readLine(buf: []u8) []u8 {
    var input_end: usize = undefined;
    for (buf, 0..) |*byte, i| {
        const char = readByte();
        if (char == '\r') {
            writeStr("\n");
            input_end = i;
            break;
        }
        writeByte(char);
        byte.* = char;
    }

    return buf[0..input_end];
}

pub fn flush() void {
    while (aux.REGISTERS.mu_msr & 0x20 != 0) {}
}
