/* Vortex Bridge Linker Script
 * Location: 0x3A0000–0x3A7FFF (30KB)
 */
ENTRY(init_plugin)
MEMORY { vortex : ORIGIN = 0x3A0000, LENGTH = 0x8000 }
SECTIONS {
    .text 0x3A0000 : { *(.text .text.*) *(.init) } > vortex
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > vortex
    .data : { *(.data .data.*) } > vortex
    .bss : { *(.bss .bss.*) *(COMMON) } > vortex
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
