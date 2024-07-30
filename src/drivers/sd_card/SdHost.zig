const SdHost = @This();
const Mailbox = @import("Mailbox.zig");

pub const Error = error{
    Generic,
    Timeout,
    Busy,
    NoResponse,
    ResetFailed,
    ClockChangeFailed,
    InvalidVoltage,
    AppCmdFailed,
    Absent,
    ReadFailed,
    MountFailed,
};

const CardType = enum {
    unknown,
    mmc,
    _1,
    sc_2,
    hc_2,
};

const MmcConfig align(4) = extern struct {
    name: []const u8,
    host_caps: u32,
    voltages: u32,
    f_min: u32,
    f_max: u32,
    b_max: u32,
    part_type: u8,
};

const MmcCmd align(4) = extern struct {
    idx: u16,
    response_type: u32,
    arg: u32,
    response: [4]u32,
};

const MmcData align(4) = extern struct {
    buffer: union {
        dest: []u8,
        src: []const u8,
    },
    flags: u32,
    blocks: u32,
    block_size: u32,
};

const BusMode = enum {
    mmc_legacy,
    sd_legacy,
    mmc_hs,
    sd_hc,
    mmc_hs_52,
    mmc_ddr_52,
    uhs_sdr12,
    uhs_sdr25,
    uhs_sdr50,
    uhs_ddr50,
    uhs_sdr104,
    mmc_hs_200,
    mmc_hs_400,
    mmc_hs_400_es,
    mmc_modes_end,
};

const Mmc align(4) = extern struct {
    config: MmcConfig,
    version: u32,
    has_init: u32,
    high_capacity: u32,
    clock_disable: bool,
    bus_width: u32,
    clock: u32,
    signal_voltage: 
};

pub fn init(mailbox: *Mailbox) SdHost {
    mailbox.addProperty(.set_power_state, &.{ 0x0, 0x3 });
    mailbox.processProperty();
    return .{};
}
