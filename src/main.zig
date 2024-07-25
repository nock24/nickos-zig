const mini_uart = @import("mini_uart.zig");

export fn kernel_main() noreturn {
    mini_uart.init();
    mini_uart.send_str("NickOS kernel initializing...\n");
    mini_uart.send_str("\tBoard: PI 4");

    while (true) {}
}
