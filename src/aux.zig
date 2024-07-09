const BASE: u32 = 0xfe21_5000;

const byte: u32 = 0x4;

pub const Regs = struct {
    pub const irq_status: *volatile u32 = @ptrFromInt(BASE + byte * 0);
    pub const enables: *volatile u32 = @ptrFromInt(BASE + byte * 1);
    // 14 reserved registers
    pub const mu_io: *volatile u32 = @ptrFromInt(BASE + byte * 16);
    pub const mu_ier: *volatile u32 = @ptrFromInt(BASE + byte * 17);
    pub const mu_iir: *volatile u32 = @ptrFromInt(BASE + byte * 18);
    pub const mu_lcr: *volatile u32 = @ptrFromInt(BASE + byte * 19);
    pub const mu_mcr: *volatile u32 = @ptrFromInt(BASE + byte * 20);
    pub const mu_lsr: *volatile u32 = @ptrFromInt(BASE + byte * 21);
    pub const mu_msr: *volatile u32 = @ptrFromInt(BASE + byte * 22);
    pub const mu_scratch: *volatile u32 = @ptrFromInt(BASE + byte * 23);
    pub const mu_control: *volatile u32 = @ptrFromInt(BASE + byte * 24);
    pub const mu_status: *volatile u32 = @ptrFromInt(BASE + byte * 25);
    pub const mu_baud_rate: *volatile u32 = @ptrFromInt(BASE + byte * 26);
};
