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

const Base = enum {
    dec,
    hex,

    pub inline fn log(self: Base, x: f32) f32 {
        return switch (self) {
            .dec => @log10(x),
            .hex => @log2(x) / @log2(16.0),
        };
    }
};

pub fn printInt(int: anytype, comptime base: Base) void {
    const IntType = if (@TypeOf(int) == comptime_int) i64 else @TypeOf(int);
    if (@typeInfo(IntType) != .Int)
        @compileError("cannot format " ++ @typeName(IntType) ++ " as integer");

    var is_negative: bool = undefined;
    const max_int = @as(f32, math.maxInt(IntType));
    const max_digit_cnt: usize = if (@typeInfo(IntType).Int.signedness == .signed) blk: {
        is_negative = int < 0;
        break :blk @ceil(base.log(max_int)) + switch (base) {
            .dec => 1, // possible '-'
            .hex => 3, // possible '-' and leading "0x"
        };
    } else blk: {
        is_negative = false;
        break :blk @ceil(base.log(max_int)) + switch (base) {
            .dec => 0,
            .hex => 2, // leading "0x"
        };
    };

    var buf: [max_digit_cnt]u8 = undefined;
    @memset(&buf, 0);

    var tmp = @abs(@as(IntType, int));
    var digit_cnt: usize = if (tmp == 0)
        1
    else
        @intFromFloat(@floor(base.log(@as(f32, @floatFromInt(tmp))) + 1));

    var start_idx: usize = 0;
    if (is_negative) {
        buf[start_idx] = '-';
        start_idx += 1;
    }
    switch (base) {
        .dec => {},
        .hex => {
            buf[start_idx] = '0';
            start_idx += 1;

            buf[start_idx] = 'x';
            start_idx += 1;
        },
    }
    digit_cnt += start_idx;

    var i = digit_cnt - 1;
    while (true) : (i -= 1) {
        switch (base) {
            .dec => {
                buf[i] = @as(u8, @intCast(tmp % 10)) + '0';
                tmp /= 10;
            },
            .hex => {
                const value = @as(u8, @intCast(tmp % 16));
                buf[i] = if (value <= 9)
                    value + '0'
                else
                    (value - 10) + 'a';
                tmp /= 16;
            },
        }

        if (i == start_idx) break;
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

const FmtSpecifier = enum {
    in_hex,
    as_char,
    none,
};

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const args_info = @typeInfo(@TypeOf(args));
    if (args_info != .Struct or
        !args_info.Struct.is_tuple) @compileError("expected args tuple");
    const args_slice = args_info.Struct.fields;

    comptime var arg_idx: usize = 0;
    comptime var fmt_idx: usize = 0;

    inline while (fmt_idx < fmt.len) {
        const fmt_char = fmt[fmt_idx];

        if (fmt_char == '}') @compileError("unclosed placeholder");
        if (fmt_char != '{') {
            if (fmt_char == '\n') writeByte('\r');
            writeByte(fmt_char);
            fmt_idx += 1;
            continue;
        }

        // skipping past '{'
        fmt_idx += 1;

        const fmt_specifier: FmtSpecifier = switch (fmt[fmt_idx]) {
            'x' => .in_hex,
            'c' => .as_char,
            else => .none,
        };
        if (fmt_specifier != .none) fmt_idx += 1;

        if (fmt[fmt_idx] != '}') @compileError("unclosed placeholder");
        // skipping past '}'
        fmt_idx += 1;

        if (arg_idx >= args_slice.len) @compileError("not enough args");
        const arg = @field(args, args_slice[arg_idx].name);
        const ArgType = @TypeOf(arg);
        if (meta.hasMethod(ArgType, "print"))
            arg.print()
        else switch (fmt_specifier) {
            .none => if (isString(ArgType)) writeStr(arg) else printInt(arg, .dec),
            .as_char => {
                if (ArgType != u8 and ArgType != comptime_int)
                    @compileError("cannot format " ++
                        @typeName(ArgType) ++ " as char");
                writeByte(arg);
            },
            .in_hex => printInt(arg, .hex),
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
