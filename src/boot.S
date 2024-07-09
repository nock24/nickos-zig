#define PAGE_SHIFT 12
#define TABLE_SHIFT 9
#define SECTION_SHIFT (PAGE_SHIFT + TABLE_SHIFT)
#define PAGE_SIZE (1 << PAGE_SHIFT)
#define SECTION_SIZE (1 << SECTION_SHIFT)

#define LOW_MEMORY (2 * SECTION_SIZE)


.section ".text.boot"

.globl _start
_start: 
    mrs x0, mpidr_el1
    and x0, x0, #0xFF
    cbz x0, master
    b proc_hang

master:
    adr x0, bss_begin
    adr x1, bss_end
    sub x1, x1, x0
    bl memzero

    mov sp, #LOW_MEMORY
    bl kernel_main
    b proc_hang

memzero:
    str xzr, [x0], #8
    subs x1, x1, #8
    b.gt memzero
    ret

proc_hang:
    wfe
    b proc_hang
