const gpio = @import("gpio.zig");
const aux = @import("aux.zig");

const TXD: u8 = 14;
const RXD: u8 = 15;

pub fn init() void {
    gpio.pinSetFunc(TXD, .alt5);
    gpio.pinSetFunc(RXD, .alt5);

    gpio.pinEnable(TXD);
    gpio.pinEnable(RXD);

    aux.REGISTERS.enables = 1;
    aux.REGISTERS.mu_control = 0;
    aux.REGISTERS.mu_ier = 0;
    aux.REGISTERS.mu_lcr = 3;
    aux.REGISTERS.mu_mcr = 0;
    aux.REGISTERS.mu_baud_rate = 541;
    aux.REGISTERS.mu_control = 3;
}

pub fn send_char(c: u8) void {
    while (aux.REGISTERS.mu_lsr & 0x20 == 0) {}

    aux.REGISTERS.mu_io = c;
}

pub fn recv_char() u8 {
    while (aux.REGISTERS.mu_lsr & 1 == 0) {}

    return @intCast(aux.REGISTERS.mu_io & 0xFF);
}

pub fn send_str(str: []const u8) void {
    for (str) |c| {
        if (c == '\n') {
            send_char('\r');
        }
        send_char(c);
    }
}
