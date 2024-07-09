const time = @import("time.zig");

const BASE: u32 = 0xfe20_0000;

const byte: u32 = 0x4;

fn get_pin_data_regs(offset_bytes: u32) [2]*volatile u32 {
    var pin_data: [2]*volatile u32 = undefined;
    //one reserved regsister first
    for (0..2) |i| {
        pin_data[i] = @ptrFromInt(BASE + byte * (i + offset_bytes + 1));
    }
    return pin_data;
}

fn get_func_select_regs() [6]*volatile u32 {
    var func_select: [6]*volatile u32 = undefined;
    for (0..6) |i| {
        func_select[i] = @ptrFromInt(BASE + byte * i);
    }
    return func_select;
}

fn get_pupd_enable_clocks_regs() [2]*volatile u32 {
    const offset_bytes: u32 = 38;
    var pupd_enable_clocks_regs: [2]*volatile u32 = undefined;
    for (0..2) |i| {
        pupd_enable_clocks_regs[i] = @ptrFromInt(BASE + byte * (i + offset_bytes));
    }
    return pupd_enable_clocks_regs;
}

pub const Regs = struct {
    const func_select: [6]*volatile u32 = get_func_select_regs();
    const output_set: [2]*volatile u32 = get_pin_data_regs(6);
    const output_clear: [2]*volatile u32 = get_pin_data_regs(9);
    const level: [2]*volatile u32 = get_pin_data_regs(12);
    const ev_detect_status: [2]*volatile u32 = get_pin_data_regs(15);
    const re_detect_enable: [2]*volatile u32 = get_pin_data_regs(18);
    const fe_detect_enable: [2]*volatile u32 = get_pin_data_regs(21);
    const hi_detect_enable: [2]*volatile u32 = get_pin_data_regs(24);
    const lo_detect_enable: [2]*volatile u32 = get_pin_data_regs(27);
    const async_re_detect: [2]*volatile u32 = get_pin_data_regs(30);
    const async_fe_detect: [2]*volatile u32 = get_pin_data_regs(33);
    const reserved: *volatile u32 = @ptrFromInt(BASE + byte * 36);
    const pupd_enable: *volatile u32 = @ptrFromInt(BASE + byte * 37);
    const pupd_enable_clocks: [2]*volatile u32 = get_pupd_enable_clocks_regs();
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

    Regs.func_select[reg].* &= ~(@as(u32, 7) << bit_start);
    Regs.func_select[reg].* |= (@intFromEnum(func_type) << bit_start);
}

pub fn pinEnable(pin_number: u8) void {
    const reg: usize = pin_number / 32;

    Regs.pupd_enable.* = 0;
    time.delay(150);
    Regs.pupd_enable_clocks[reg].* = @as(u32, 1) << @intCast(pin_number % 32);
    time.delay(150);
    Regs.pupd_enable.* = 0;
    Regs.pupd_enable_clocks[reg].* = 0;
}
