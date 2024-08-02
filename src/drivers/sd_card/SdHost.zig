const SdHost = @This();
const kernel = @import("kernel");
const time = kernel.time;
const InterruptController = kernel.InterruptController;
const Mailbox = kernel.Mailbox;
const peripherals = kernel.peripherals;
const mmc = @import("mmc.zig");

const BASE = peripherals.BASE + 0x0020_2000;
const REGISTERS: *volatile Registers = @intFromEnum(BASE);

const Registers = extern struct {
    command: u32,
    arg: u32,
    timeout: u32,
    cdiv: u32,
    response: [4]u32,
    host_status: u32,
    vdd: u32,
    edm: u32,
    host_config: u32,
    host_byte_cnt: u32,
    data: u32,
    host_block_cnt: u32,
};

const SDEDM_WRITE_THRESHOLD_SHIFT: u32 = 9;
const SDEDM_READ_THRESHOLD_SHIFT: u32 = 14;
const SDEDM_THRESHOLD_MASK: u32 = 0x1f;

const FIFO_READ_THRESHOLD: u32 = 4;
const FIFO_WRITE_THRESHOLD: u32 = 4;

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

pub const BusMode = enum {
    mmc_legacy,
    sd_legacy,
    mmc_hs,
    sd_hs,
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

inline fn bit(nr: u32) u32 {
    return 1 << nr;
}

const HostConfig = enum(u32) {
    busy_irpt_en = bit(10),
    block_irpt_en = bit(8),
    sdio_irpt_en = bit(5),
    data_irpt_en = bit(4),
    slow_card = bit(3),
    wide_ext_bus = bit(2),
    wide_int_bus = bit(1),
    rel_cmd_line = bit(0),
};

const HostStatus = enum(u32) {
    busy_irpt = 0x400,
    block_irpt = 0x200,
    sdio_irpt = 0x100,
    rew_timeout = 0x80,
    cmd_timeout = 0x40,
    crc16_error = 0x20,
    crc7_error = 0x10,
    fifo_error = 0x08,
    data_flag = 0x01,
};

const SDHSTS_CLEAR_MASK: u32 = @intFromEnum(HostStatus.busy_irpt) |
    @intFromEnum(HostStatus.block_irpt) |
    @intFromEnum(HostStatus.sdio_irpt) |
    @intFromEnum(HostStatus.rew_timeout) |
    @intFromEnum(HostStatus.cmd_timeout) |
    @intFromEnum(HostStatus.crc16_error) |
    @intFromEnum(HostStatus.crc7_error) |
    @intFromEnum(HostStatus.fifo_error);

const CardType = enum {
    unknown,
    mmc,
    @"1",
    @"2_sc",
    @"2_hc",
};

const HC_CMD_ENABLE: u32 = 0x8000;
const Cmd = enum(u16) {
    fail_flag = 0x4000,
    busy_wait = 0x800,
    no_response = 0x400,
    long_response = 0x200,
    write = 0x80,
    read = 0x40,
    mask = 0x3f,
};

interrupt_controller: *InterruptController,
clock: u32 = 0,
host_config: u32,
cdiv: u32,
max_clock: u32,
ns_per_fifo_word: u32 = 0,
use_busy: u8 = 0,
config: mmc.Config,
command: ?mmc.Cmd,
data: ?mmc.Data,
mmc: mmc.Mmc,

fn interruptClearer() void {}

fn interruptHandler() void {}

fn updateReg(self: *SdHost, comptime register_name: []const u8) void {
    @field(REGISTERS, register_name) = @field(self, register_name);
}

fn readWaitSdCmd() ?u32 {
    var timeout: usize = 1000;
    while (REGISTERS.command & HC_CMD_ENABLE != 0) : (timeout -= 1) {
        if (timeout == 0) {
            return null;
        }
        time.sleepUs(1000);
    }

    return REGISTERS.command;
}

pub const CmdError = error{
    UnsupportedResponse,
    PreviousCmdUncompleted,
};

pub fn sendCommand(self: *SdHost, cmd: *mmc.Cmd, data: *mmc.Data) CmdError!void {
    if ((cmd.response_type & mmc.RSP_136) != 0 and
        (cmd.response_type & mmc.RSP_BUSY)) return error.UnsupportedResponse;

    _ = self.readWaitSdCmd() orelse
        return error.PreviousCmdUncompleted;

    self.command = cmd;

    REGISTERS.arg = 0;
    time.sleepUs(1000);
    self.prepareData(data);

    REGISTERS.arg = cmd.arg;

    var sd_cmd = cmd.idx & @intFromEnum(Cmd.mask);

    self.use_busy = 0;

    if (cmd.response_type & mmc.RSP_PRESENT == 0) {
        sd_cmd |= @intFromEnum(Cmd.no_response);
    } else {
        if (cmd.respose_type & mmc.RSP_136 != 0) {
            sd_cmd |= @intFromEnum(Cmd.long_response);
        }

        if (cmd.response_type & mmc.RSP_BUSY) {
            sd_cmd |= @intFromEnum(Cmd.busy_wait);
            self.use_busy = 1;
        }
    }

    if (data.flags & mmc.DATA_WRITE != 0) {
        sd_cmd |= @intFromEnum(Cmd.write);
    }
    if (data.flags & mmc.DATA_READ != 0) {
        sd_cmd |= @intFromEnum(Cmd.read);
    }

    REGISTERS.command = sd_cmd | HC_CMD_ENABLE;
}

fn setClock(self: *SdHost, clock: u32) void {
    if (clock < 100000) {
        self.cdiv = SDCDIV_MAX_CDIV;
        updateReg("cdiv");
        return {};
    }

    var div = self.max_clock / clock;
    if (div < 2) div = 2;
    if (self.max_clock / div > clock) div += 1;
    div -= 2;

    if (div > SDCDIV_MAX_CDIV) div = SDCDIV_MAX_CDIV;

    const clk = self.max_clock / (div + 2);
    self.mmc.clock = clk;

    self.ns_per_fifo_word = (1000000000 / clk) *
        if (self.mmc.card_caps & mmc.MODE_4BIT != 0) 8 else 32;

    self.cdiv = div;
    self.updateReg("cdiv");

    REGISTERS.timeout = self.mmc.clock / 2;
}

fn setIos(host_config: *u32) void {
    host_config.* &= ~@intFromEnum(HostConfig.wide_ext_bus);
    host_config.* |= @intFromEnum(HostConfig.wide_int_bus);
    host_config.* |= @intFromEnum(HostConfig.slow_card);

    REGISTERS.host_config = host_config;
}

const SDVDD_POWER_OFF: u32 = 0;
const SDVDD_POWER_ON: u32 = 1;

/// Returns clock
fn resetInternal(host_config: *u32) u32 {
    REGISTERS.vdd = SDVDD_POWER_ON;
    REGISTERS.command = 0;
    REGISTERS.arg = 0;

    REGISTERS.timeout = 0xf00000;
    REGISTERS.cdiv = 0;

    REGISTERS.host_status = SDHSTS_CLEAR_MASK;
    REGISTERS.host_config = 0;
    REGISTERS.host_byte_cnt = 0;
    REGISTERS.host_block_cnt = 0;

    var edm = REGISTERS.edm;
    edm &= ~((SDEDM_THRESHOLD_MASK << SDEDM_READ_THRESHOLD_SHIFT) |
        (SDEDM_THRESHOLD_MASK << SDEDM_WRITE_THRESHOLD_SHIFT));
    edm |= (FIFO_READ_THRESHOLD << SDEDM_READ_THRESHOLD_SHIFT) |
        (FIFO_WRITE_THRESHOLD << SDEDM_WRITE_THRESHOLD_SHIFT);
    REGISTERS.edm = edm;

    time.sleepMs(20);
    REGISTERS.vdd = SDVDD_POWER_ON;

    time.sleepMs(40);
    REGISTERS.host_config = host_config;
    return 250 * 1000 * 1000; // clock
}

const SDCDIV_MAX_CDIV: u32 = 0x7ff;

fn addHost(interrupt_controller: *InterruptController) SdHost {
    const max_clock: u32 = 250 * 1000 * 1000; // 250 MHz

    const cfg_f_max = max_clock;
    const cfg_f_min = max_clock / SDCDIV_MAX_CDIV;
    const cfg_b_max: u32 = 65535;

    // host controller capabilities
    const cfg_host_caps = mmc.MODE_4BIT |
        @intFromEnum(mmc.Mode.hs) |
        @intFromEnum(mmc.Mode.hs_52mhz);

    // report supported voltage ranges
    const cfg_voltages = @intFromEnum(mmc.VddVoltage.@"3.2-3.3") |
        @intFromEnum(mmc.VddVoltage.@"3.3-3.4");

    const host_config = @intFromEnum(HostConfig.busy_irpt_en);

    const clock = resetInternal(&host_config);
    setIos(&host_config);

    const sd_host = SdHost{
        .interrupt_controller = interrupt_controller,
        .clock = clock,
        .max_clock = max_clock,
        .config = .{
            .name = "",
            .f_min = cfg_f_min,
            .f_max = cfg_f_max,
            .b_max = cfg_b_max,
            .voltages = cfg_voltages,
            .host_caps = cfg_host_caps,
            .part_type = 0,
        },
    };

    sd_host.setClock(sd_host.clock);

    time.sleepUs(100);

    interrupt_controller.registerIrqHandler(
        InterruptController.Irq.sdhost,
        interruptHandler,
        interruptClearer,
    );

    return sd_host;
}

pub fn init(mailbox: *Mailbox, interrupt_controller: *InterruptController) SdHost {
    mailbox.addProperty(.set_power_state, &.{ 0x0, 0x3 });
    mailbox.processProperty();

    return addHost(interrupt_controller);
}
