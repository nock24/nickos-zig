const peripherals = @import("peripherals.zig");

const BASE = peripherals.BASE + 0x3000;

pub fn getSysTimeUs() u32 {
    const sys_time_us: *volatile u32 = @ptrFromInt(BASE + 0x4);
    return sys_time_us.* / 1000;
}

pub fn sleepUs(us: u32) void {
    const start_time = getSysTimeUs();
    while (getSysTimeUs() - start_time < us) {}
}

pub fn getSysTimeMs() u32 {
    return getSysTimeUs() / 1000;
}

pub fn sleepMs(ms: u32) void {
    const start_time = getSysTimeMs();
    while (getSysTimeMs() - start_time < ms) {}
}

pub extern fn delay(cycles: u64) void;
