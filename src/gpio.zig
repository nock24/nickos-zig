const time = @import("time.zig");

pub const BASE: u32 = 0x3f00_0000;

pub const REGISTERS: *volatile Registers = @ptrFromInt(BASE);

pub const PinData = extern struct {
    _: u32,
    data: [2]u32,
};

pub const Registers = extern struct {
    func_select: [6]u32,
    output_set: PinData,
    output_clear: PinData,
    level: PinData,
    ev_detect_status: PinData,
    re_detect_enable: PinData,
    fe_detect_enable: PinData,
    hi_detect_enable: PinData,
    lo_detect_enable: PinData,
    async_re_detect: PinData,
    async_fe_detect: PinData,
    _: u32,
    pupd_enable: u32,
    pupd_enable_clocks: [2]u32,
};

pub const PinFuncType = enum(u32) {
    input = 0,
    output = 1,
    alt0 = 4,
    alt1 = 5,
    alt2 = 6,
    alt3 = 7,
    alt4 = 3,
    alt5 = 2,
};

pub fn pinSetFunc(pin_number: u8, func_type: PinFuncType) void {
    const bit_start: u5 = @intCast((pin_number * 3) % 30);
    const reg: usize = pin_number / 10;

    REGISTERS.func_select[reg] &= ~(@as(u32, 7) << bit_start);
    REGISTERS.func_select[reg] |= (@intFromEnum(func_type) << bit_start);
}

pub fn pinEnable(pin_number: u8) void {
    const reg: usize = pin_number / 32;

    REGISTERS.pupd_enable = 0;
    time.delay(150);
    REGISTERS.pupd_enable_clocks[reg] = @as(u32, 1) << @intCast(pin_number % 32);
    time.delay(150);
    REGISTERS.pupd_enable = 0;
    REGISTERS.pupd_enable_clocks[reg] = 0;
}
