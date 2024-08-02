const InterruptController = @This();
const kernel = @import("kernel");
const peripherals = kernel.peripherals;

const BASE = peripherals.BASE + 0xb200;
const REGISTERS: *volatile Registers = @ptrFromInt(BASE);

const Registers align(4) = extern struct {
    basic_pending: u32,
    pending1: u32,
    pending2: u32,
    fiq_control: u32,
    enable1: u32,
    enable2: u32,
    enable_basic: u32,
    disable1: u32,
    disable2: u32,
    disable_basic: u32,
};

const IRQ_BASIC: u32 = BASE;
const IRQ_PEND1: u32 = BASE + 0x4;
const IRQ_PEND2: u32 = BASE + 0x8;
const IRQ_FIQ_CONTROL: u32 = BASE + 0x10;
const IRQ_ENABLE_BASIC: u32 = BASE + 0x18;
const IRQ_DISABLE_BASIC: u32 = BASE + 0x24;

const IRQ1_BASE: u32 = 0;
const IRQ0_BASE: u32 = 64;

const DMA0 = IRQ1_BASE + 16;
const DMA1 = IRQ1_BASE + 17;
const DMA2 = IRQ0_BASE + 13;
const DMA3 = IRQ0_BASE + 14;
const DMA4 = IRQ1_BASE + 20;
const DMA5 = IRQ1_BASE + 21;
const DMA6 = IRQ1_BASE + 22;
const DMA7 = IRQ1_BASE + 23;
const DMA8 = IRQ1_BASE + 24;
const DMA9 = IRQ1_BASE + 25;
const DMA10 = IRQ1_BASE + 26;
const DMA11 = IRQ1_BASE + 27;
const DMA12 = IRQ1_BASE + 28;

pub inline fn isBasicIrq(irq_num: u32) bool {
    return irq_num >= 64;
}

pub inline fn isGpu2Irq(irq_num: u32) bool {
    return irq_num >= 32 and irq_num < 64;
}

pub inline fn isGpu1Irq(irq_num: u32) bool {
    return irq_num < 32;
}

pub inline fn isPendingIrq(irq_num: u32) bool {
    return (isBasicIrq(irq_num) and (1 << (irq_num - 64)) & REGISTERS.basic_pending != 0) or
        (isGpu2Irq(irq_num) and (1 << (irq_num - 32)) & REGISTERS.pending2) != 0 or
        (isGpu1Irq(irq_num) and (1 << irq_num) & REGISTERS.pending1) != 0;
}

pub inline fn isInvalidIrq(irq_num: u32) bool {
    return !isBasicIrq(irq_num) and
        !isGpu2Irq(irq_num) and
        !isGpu1Irq(irq_num);
}

pub const Irq = enum(u32) {
    basic_arm_timer = 1 << 0,
    basic_arm_mailbox = 1 << 1,
    basic_arm_doorbell_0 = 1 << 2,
    basic_arm_doorbell_1 = 1 << 3,
    basic_gpu_0_halted = 1 << 4,
    basic_gpu_1_halted = 1 << 5,
    basic_access_error_1 = 1 << 6,
    basic_access_error_0 = 1 << 7,
    sdhost = 56,
};

extern fn _enable_interrupts() void;

inline fn interruptsEnabled() u32 {
    var res: u32 = undefined;
    asm volatile ("mrs %[res], CPSR"
        : [res] "=r" (res),
    );

    return (res >> 7) & 1 == 0;
}

inline fn enableInterrupts() void {
    asm volatile ("cpsie i");
    if (!interruptsEnabled()) {
        asm volatile ("cpsie i");
    }
}

inline fn disableInterrupts() void {
    asm volatile ("cpsid i");
    if (interruptsEnabled()) {
        asm volatile ("cpsid i");
    }
}

const InterruptHandlerFn = *const fn () void;
const InterruptClearerFn = *const fn () void;

const IRQ_CNT: usize = 72;

handlers: [IRQ_CNT]?InterruptHandlerFn,
clearers: [IRQ_CNT]?InterruptHandlerFn,

pub fn init() InterruptController {
    _enable_interrupts();

    disableInterrupts();
    REGISTERS.disable_basic = 0xffff_ffff;
    REGISTERS.disable1 = 0xffff_ffff;
    REGISTERS.disable2 = 0xffff_ffff;
    enableInterrupts();

    return .{
        .handlers = [_]?InterruptHandlerFn{null} ** IRQ_CNT,
        .clearers = [_]?InterruptClearerFn{null} ** IRQ_CNT,
    };
}

pub fn registerIrqHandler(
    self: *InterruptController,
    irq: Irq,
    handler: InterruptHandlerFn,
    clearer: InterruptClearerFn,
) !void {
    const irq_num = @intFromEnum(irq);

    if (isInvalidIrq(irq_num)) return error.InvalidIrq;

    self.handlers[irq_num] = handler;
    self.clearers[irq_num] = clearer;

    if (isBasicIrq(irq_num)) {
        const irq_pos = irq_num - 64;
        REGISTERS.enable_basic |= 1 << irq_pos;
    } else if (isGpu2Irq(irq_num)) {
        REGISTERS.enable2 |= 1 << (irq_num & (32 - 1));
    } else if (isGpu1Irq(irq_num)) {
        const irq_pos = irq_num;
        REGISTERS.enable1 |= 1 << irq_pos;
    }
}

pub fn unregisterIrqHandler(
    self: *InterruptController,
    irq: Irq,
) !void {
    const irq_num = @intFromEnum(irq);

    if (isInvalidIrq(irq_num)) return error.InvalidIrq;

    self.handlers[irq_num] = null;
    self.clearers[irq_num] = null;

    if (isBasicIrq(irq_num)) {
        const irq_pos = irq_num - 64;
        REGISTERS.disable_basic |= 1 << irq_pos;
    } else if (isGpu2Irq(irq_num)) {
        const irq_pos = irq_num - 32;
        REGISTERS.disable2 |= 1 << irq_pos;
    } else if (isGpu1Irq(irq_num)) {
        const irq_pos = irq_num;
        REGISTERS.disable1 |= 1 << irq_pos;
    }
}

pub fn irqHandler(self: *InterruptController) void {
    for (0..IRQ_CNT) |irq_num| {
        if (isPendingIrq(irq_num)) if (self.clearers[irq_num]) |clearerFn| {
            clearerFn();
            enableInterrupts();

            const handlerFn = self.handlers[irq_num].?;
            handlerFn();
            disableInterrupts();
        };
    }
}
