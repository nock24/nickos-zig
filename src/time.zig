pub const BASE: u32 = 0xfe00_3000;

pub fn getSysTime() u32 {
    const sys_time: *volatile u32 = @ptrFromInt(BASE + 0x4);
    return sys_time.* / 1000;
}

pub fn sleep(ms: u32) void {
    const start_time = getSysTime();
    while (getSysTime() - start_time < ms) {}
}

pub extern fn delay(ticks: u64) void;
