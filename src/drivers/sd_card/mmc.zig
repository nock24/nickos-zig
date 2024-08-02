const SdHost = @import("SdHost.zig");
const BusMode = SdHost.BusMode;

pub const DATA_READ: u32 = 1;
pub const DATA_WRITE: u32 = 2;

pub const STATUS_MASK: u32 = ~0x0206_bf7f;
pub const Status = enum(u32) {
    switch_error = 1 << 7,
    ready_for_data = 1 << 8,
    current_state = 0xf << 9,
    error_ = 1 << 19,
};

pub const Config align(4) = extern struct {
    name: [*]const u8,
    host_caps: u32,
    voltages: u32,
    f_min: u32,
    f_max: u32,
    b_max: u32,
    part_type: u8,
};

pub const Cmd align(4) = extern struct {
    idx: u16,
    response_type: u32,
    arg: u32,
    response: [4]u32,
};

pub const Data align(4) = extern struct {
    buffer: union {
        dest: [*]u8,
        src: [*]const u8,
    },
    flags: u32,
    blocks: u32,
    block_size: u32,
};

pub const Voltage = enum(u2) {
    @"0" = 0,
    @"120" = 1,
    @"180" = 2,
    @"330" = 4,
};

pub const VddVoltage = enum(u32) {
    @"1.65-1.95" = 0x0000_0080,
    @"2.0-2.1" = 0x0000_0100,
    @"2.1-2.2" = 0x0000_0200,
    @"2.2-2.3" = 0x0000_0400,
    @"2.3-2.4" = 0x0000_0800,
    @"2.4-2.5" = 0x0000_1000,
    @"2.5-2.6" = 0x0000_2000,
    @"2.6-2.7" = 0x0000_4000,
    @"2.7-2.8" = 0x0000_8000,
    @"2.8-2.9" = 0x0001_0000,
    @"2.9-3.0" = 0x0002_0000,
    @"3.0-3.1" = 0x0004_0000,
    @"3.1-3.2" = 0x0008_0000,
    @"3.2-3.3" = 0x0010_0000,
    @"3.3-3.4" = 0x0020_0000,
    @"3.4-3.5" = 0x0040_0000,
    @"3.5-3.6" = 0x0080_0000,
};

pub const RSP_PRESENT: u32 = 1 << 0;
pub const RSP_136: u32 = 1 << 1;
pub const RSP_CRC: u32 = 1 << 2;
pub const RSP_BUSY: u32 = 1 << 3;
pub const RSP_OPCODE: u32 = 1 << 4;
pub const Response = enum(u32) {
    none = 0,
    r1 = RSP_PRESENT | RSP_CRC | RSP_OPCODE,
    r1b = RSP_PRESENT | RSP_CRC | RSP_OPCODE | RSP_BUSY,
    r2 = RSP_PRESENT | RSP_136 | RSP_CRC,
    r3 = RSP_PRESENT,
    r4 = RSP_PRESENT,
    r5 = RSP_PRESENT | RSP_CRC | RSP_OPCODE,
    r6 = RSP_PRESENT | RSP_CRC | RSP_OPCODE,
    r7 = RSP_PRESENT | RSP_CRC | RSP_OPCODE,
};

inline fn cap(mode: BusMode) u32 {
    return 1 << @intFromEnum(mode);
}

pub const Mode = enum(u32) {
    hs = cap(.mmc_hs) | cap(.sd_hs),
    hs_52mhz = cap(.mmc_hs_52),
    ddr_52mhz = cap(.mmc_ddr_52),
    hs_200 = cap(.mmc_hs_200),
    hs_400 = cap(.mmc_hs_400),
    hs_400_es = cap(.mmc_hs_400_es),
};

inline fn bit(nr: u32) u32 {
    return 1 << nr;
}
pub const MODE_8BIT = bit(30);
pub const MODE_4BIT = bit(29);
pub const MODE_1BIT = bit(28);
pub const MODE_SPI = bit(27);

pub const Mmc align(4) = extern struct {
    config: Config,
    version: u32,
    has_init: u32,
    high_capacity: u32,
    clock_disable: bool,
    bus_width: u32,
    clock: u32,
    signal_voltage: Voltage,
    card_caps: u32,
    host_caps: u32,
    ocr: u32,
    dsr: u32,
    dsr_imp: u32,
    scr: [2]u32,
    csd: [4]u32,
    cid: [4]u32,
    rca: u16,
    part_support: u8,
    part_attr: u8,
    wr_rel_set: u8,
    part_config: u8,
    gen_cmd6_time: u8,
    part_switch_time: u8,
    tran_speed: u32,
    legacy_speed: u32,
    read_bl_len: u32,
    capacity: u64,
    capacity_user: u64,
    capacity_boot: u64,
    capacity_rpmb: u64,
    capacity_gp: [4]u64,
    op_cond_pending: u8,
    init_in_progress: u8,
    preinit: u8,
    ddr_mode: u32,
    ext_csd: [*]u8,
    card_type: u32,
    current_voltage: Voltage,
    selected_mode: SdHost.BusMode,
    best_mode: BusMode,
    quirks: u32,
};
