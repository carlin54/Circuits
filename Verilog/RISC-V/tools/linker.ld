ENTRY(_start)
SECTIONS {
    . = 0x80000000;
    .text : { *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) }
    .bss : {
        __bss_start = .;
        *(.bss .bss.* COMMON)
        __bss_end = .;
    }
    .tohost : { *(.tohost) }
    _stack_top = 0x80000000 + 0x4000 - 8;
}
