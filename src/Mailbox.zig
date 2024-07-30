const Mailbox = @This();
const peripherals = @import("peripherals.zig");

pub const BASE = peripherals.BASE + 0xb880;
pub const REGISTERS: *volatile Registers = @ptrFromInt(BASE);

const Registers = extern struct {
    read: u32,
    reserved: [3]u32,
    poll: u32,
    sender: u32,
    status: u32,
    configuration: u32,
    write: u32,
};

const Channel = enum(u4) {
    power_management = 0,
    framebuffer,
    virtual_uart,
    vchiq,
    leds,
    buttons,
    touchscreen,
    unused,
    tags_arm_to_vc,
    tags_vc_to_arm,
};

const StatusRegBits = enum(u32) {
    full = 0x8000_0000,
    empty = 0x4000_0000,
    level = 0x4000_00ff,
};

fn write(channel: Channel, value: u32) void {
    var val = value;
    val &= ~0xf;
    value |= @intFromEnum(channel);

    while (REGISTERS.status & StatusRegBits.full != 0) {}

    REGISTERS.write = value;
}

fn read(channel: Channel) u32 {
    var value = undefined;

    while (value & 0xf != @intFromEnum(channel)) {
        while (REGISTERS.status & StatusRegBits.empty != 0) {}

        value = REGISTERS.read;
    }

    return value >> 4;
}

pub const Tag = enum(u32) {
    // Videocore:
    get_firmware_version = 0x1,

    // Hardware:
    get_board_model = 0x10001,
    get_board_revision,
    get_board_mac_address,
    get_board_serial,
    get_arm_memory,
    get_vc_memory,
    get_clocks,

    // Config:
    get_command_line = 0x50001,

    // Shared resource management:
    get_dma_channels = 0x60001,

    // Power:
    get_power_state = 0x20001,
    get_timing,
    set_power_state = 0x28001,

    // Clocks:
    get_clock_state = 0x30001,
    set_clock_state = 0x38001,
    get_clock_rate = 0x30002,
    set_clock_rate = 0x38002,
    get_max_clock_rate = 0x30004,
    get_min_clock_rate = 0x30007,
    get_turbo = 0x30009,
    set_turbo = 0x38009,

    execute_qpu = 0x0003_0011,
    enable_qpu = 0x0003_0012,

    // Memory commands
    allocate_memory = 0x0003_000c,
    lock_memory = 0x0003_000d,
    unlock_memory = 0x0003_000e,
    release_memory = 0x0003_000f,

    execute_code = 0x30010,
    get_dispmanx_mem_handle = 0x30014,
    get_edid_block = 0x30020,

    // Voltage:
    get_voltage = 0x30003,
    set_voltage = 0x38003,
    get_max_voltage = 0x30005,
    get_min_voltage = 0x30008,
    get_temperature = 0x30006,
    get_max_temperature = 0x3000a,

    // GPIO:
    get_domain_state = 0x30030,
    get_gpio_state = 0x30041,
    set_gpio_state = 0x38041,
    get_gpio_config = 0x30043,
    set_gpio_config = 0x38043,

    set_customer_otp = 0x38021,
    set_domain_state = 0x38030,
    set_sdhost_clock = 0x38042,

    // Framebuffer:
    allocate_buffer = 0x40001,
    release_buffer = 0x48001,
    blank_screen = 0x40002,
    get_physical_size = 0x40003,
    test_physical_size = 0x44003,
    set_physical_size = 0x48003,
    get_virtual_size = 0x40004,
    test_virtual_size = 0x44004,
    set_virtual_size = 0x48004,
    get_depth = 0x40005,
    test_depth = 0x44005,
    set_depth = 0x48005,
    get_pixel_order = 0x40006,
    test_pixel_order = 0x44006,
    set_pixel_order = 0x48006,
    get_alpha_mode = 0x40007,
    test_alpha_mode = 0x44007,
    set_alpha_mode = 0x48007,
    get_pitch = 0x40008,
    get_virtual_offset = 0x40009,
    test_virtual_offset = 0x44009,
    set_virtual_offset = 0x48009,
    get_overscan = 0x4000a,
    test_overscan = 0x4400a,
    set_overscan = 0x4800a,
    get_palette = 0x4000b,
    test_palette = 0x4400b,
    set_palette = 0x4800b,
    set_cursor_info = 0x8011,
    set_cursor_state = 0x8010,
};

const TagState = enum(u1) {
    request = 0,
    response = 1,
};

const BufferOffset = enum(u1) {
    osize = 1,
    orequest_or_response = 1,
};

const TagOffset = enum(u2) {
    oident = 0,
    ovalue_size = 1,
    oresponse = 2,
    ovalue = 3,
};

const TagClockId = enum(u4) {
    reserved = 0,
    emmc = 1,
    uart = 2,
    arm = 3,
    core = 4,
    v3d = 5,
    h264 = 6,
    isp = 7,
    sdram = 8,
    pixel = 9,
    pwm = 10,
};

pub const Property = struct {
    tag: u32,
    byte_length: u32,
    data: union {
        value_32: u32,
        buffer_8: [256]u8,
        buffer_32: [64]u32,
    },
};

property_tags: [8192]u32 align(16),
pt_index: usize = 0,

pub fn propertyInit() void {
    var property_tags = [_]u32{0} ** 8192;
    property_tags[BufferOffset.osize] = 12;
    property_tags[BufferOffset.orequest_or_response] = 0;

    const pt_index: usize = 2;
    property_tags[pt_index] = 0;
}

fn ptPush(self: *Mailbox, value: u32) void {
    self.property_tags[self.pt_index] = value;
    self.pt_index += 1;
}

pub fn propertyAddTag(self: *Mailbox, comptime tag: Tag, data: anytype) void {
    const data_type_info = @typeInfo(@TypeOf(data));
    if (data_type_info != .Array or
        data_type_info.Array.child != u32) @compileError("expected data u32 array");
    const data_len: usize = data_type_info.Array.len;

    const DataAssert = struct {
        pub inline fn len(expected_len: usize) void {
            if (data_len != expected_len) @compileError("incorrect data array length");
        }
    };

    self.ptPush(@intFromEnum(tag));

    switch (tag) {
        .get_firmware_version,
        .get_board_model,
        .get_board_revision,
        .get_board_mac_address,
        .get_board_serial,
        .get_arm_memory,
        .get_vc_memory,
        .get_dma_channels,
        => {
            // provide 8 byte buffer for response
            self.ptPush(8);
            self.ptPush(0);
            self.pt_index += 2;
        },
        .get_clocks, .get_command_line => {
            // provide 256 byte buffer
            self.ptPush(256);
            self.ptPush(0);
            self.pt_index += 256 >> 2;
        },
        .get_power_state,
        .allocate_buffer,
        .get_max_clock_rate,
        .get_min_clock_rate,
        .get_clock_rate,
        => {
            self.ptPush(8);
            self.ptPush(0);

            DataAssert.len(1);
            self.ptPush(data[0]);
            self.ptPush(0);
        },
        .set_clock_rate => {
            self.ptPush(12);
            self.ptPush(0);

            DataAssert.len(3);
            self.ptPush(data[0]);
            self.ptPush(data[1]);
            self.ptPush(data[2]);
        },
        .set_physical_size,
        .set_virtual_size,
        .set_virtual_offset,
        .test_physical_size,
        .test_virtual_size,
        => {
            self.ptPush(8);
            self.ptPush(0);

            DataAssert.len(2);
            self.ptPush(data[0]); // width
            self.ptPush(data[1]); // height
        },
        .get_physical_size,
        .get_virtual_size,
        .get_virtual_offset,
        => {
            self.ptPush(8);
            self.ptPush(0);
            self.pt_index += 2;
        },
        .set_depth,
        .set_pixel_order,
        .set_alpha_mode,
        => {
            self.ptPush(4);
            self.ptPush(0);

            DataAssert.len(1);
            self.ptPush(data[0]); // colour depth, bits per pixel, pixel order state
        },
        .get_depth,
        .get_pixel_order,
        .get_alpha_mode,
        .get_pitch,
        => {
            self.ptPush(4);
            self.ptPush(0);
            self.pt_index += 1;
        },
        .set_overscan => {
            self.ptPush(16);
            self.ptPush(0);

            DataAssert.len(4);
            self.ptPush(data[0]); // top pixels
            self.ptPush(data[1]); // bottom pixels
            self.ptPush(data[2]); // left pixels
            self.ptPush(data[3]); // right pixels
        },
        .get_overscan => {
            self.ptPush(16);
            self.ptPush(0);
            self.pt_index += 4;
        },
        .set_power_state => {
            self.ptPush(8);
            self.ptPush(0);

            DataAssert.len(2);
            self.ptPush(data[0]); // device id
            self.ptPush(data[1]); // state
        },
        .enable_qpu => {
            self.ptPush(4);
            self.ptPush(0);

            DataAssert.len(1);
            self.ptPush(data[0]); // if 0 turn off qpu else enable qpu
        },
        .execute_qpu => {
            self.ptPush(16);
            self.ptPush(0);

            DataAssert.len(4);
            self.ptPush(data[0]); // jobs
            self.ptPush(data[1]); // pointer to buffer, 24 words of 32 bits
            self.ptPush(data[2]); // no flush
            self.ptPush(data[3]); // timeout
        },
        .allocate_memory => {
            self.ptPush(12);
            self.ptPush(0);

            DataAssert.len(3);
            self.ptPush(data[0]); // size
            self.ptPush(data[1]); // alignment
            self.ptPush(data[2]); // flags
        },
        .lock_memory,
        .unlock_memory,
        .release_memory,
        => {
            self.ptPush(4);
            self.ptPush(0);

            DataAssert.len(1);
            self.ptPush(data[0]); // handle
        },
        .execute_code => {
            self.ptPush(28);
            self.ptPush(0);

            DataAssert.len(7);
            self.ptPush(data[0]); // function pointer
            self.ptPush(data[1]); // r0
            self.ptPush(data[2]); // r1
            self.ptPush(data[3]); // r2
            self.ptPush(data[4]); // r3
            self.ptPush(data[5]); // r4
            self.ptPush(data[6]); // r5
        },
        else => {
            // unsupported tag, just remove from the list
            self.pt_index -= 1;
        },
    }

    // ensure tags are 0 terminated
    self.property_tags[self.pt_index] = 0;
}

pub fn propertyProcess(self: *Mailbox) u32 {
    // fill inthe size of the buffer
    self.property_tags[BufferOffset.osize] = (self.pt_index + 1) << 2;
    self.property_tags[BufferOffset.orequest_or_response] = 0;

    self.write(.tags_arm_to_vc, self.property_tags[0]);
    return self.read(.tags_arm_to_vc);
}

pub fn getProperty(self: *Mailbox, tag: Tag) *Property {
    var tag_buffer: ?[*]u32 = null;

    var index: usize = 2;
    while (index < self.property_tags[BufferOffset.osize] >> 2) : (index += (self.property_tags[index + 1] >> 2) + 3) {
        if (self.property_tags[index] == @intFromEnum(tag)) {
            tag_buffer = &self.property_tags[index];
        }
    }

    //TODO
}
