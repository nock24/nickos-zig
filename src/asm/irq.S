.globl _enable_interrupts
_enable_interrupts:
    mrs r0, cpsr
    bic r0, r0, #0x80
    msr cpsr_c, r0
    mov pc, lr
