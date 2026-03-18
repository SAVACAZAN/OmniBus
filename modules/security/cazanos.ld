/* CAZANos Linker Script (Phase 52B)
 * Location: 0x383C00–0x387FFF (18KB)
 */
ENTRY(init_plugin)
MEMORY {
    cazanos : ORIGIN = 0x383C00, LENGTH = 0x4400
}
SECTIONS {
    .text 0x383C00 : {
        *(.text .text.*)
        *(.init)
    } > cazanos
    .rodata : {
        *(.rodata .rodata.*)
        *(.data.rel.ro .data.rel.ro.*)
    } > cazanos
    .data : {
        *(.data .data.*)
    } > cazanos
    .bss : {
        *(.bss .bss.*)
        *(COMMON)
    } > cazanos
    /DISCARD/ : {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
        *(.gnu_debugdata)
    }
}
