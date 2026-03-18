/* SAVAos Linker Script (Phase 52A)
 * Location: 0x380000–0x383C00 (15KB)
 * Entry point: init_plugin (must be first)
 */

ENTRY(init_plugin)

MEMORY {
    savaos : ORIGIN = 0x380000, LENGTH = 0x3C00
}

SECTIONS {
    .text 0x380000 : {
        *(.text .text.*)
        *(.init)
    } > savaos

    .rodata : {
        *(.rodata .rodata.*)
        *(.data.rel.ro .data.rel.ro.*)
    } > savaos

    .data : {
        *(.data .data.*)
    } > savaos

    .bss : {
        *(.bss .bss.*)
        *(COMMON)
    } > savaos

    /DISCARD/ : {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
        *(.gnu_debugdata)
    }
}
