const peripherals = @import("peripherals.zig");

pub const BASE = peripherals.BASE + 0x0021_5000;
pub const REGISTERS: *volatile Registers = @ptrFromInt(BASE);

pub const Registers = extern struct {
    irq_status: u32,
    enables: u32,
    _: [14]u32,
    mu_io: u32,
    mu_ier: u32,
    mu_iir: u32,
    mu_lcr: u32,
    mu_mcr: u32,
    mu_lsr: u32,
    mu_msr: u32,
    mu_scratch: u32,
    mu_control: u32,
    mu_status: u32,
    mu_baud_rate: u32,
};
