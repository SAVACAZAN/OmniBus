/* Zen.OS Linker Script
 * Location: 0x3B7800–0x3BAFFF (18KB)
 */
ENTRY(init_plugin)
MEMORY { zen : ORIGIN = 0x3B7800, LENGTH = 0x3800 }
SECTIONS {
    .text 0x3B7800 : { *(.text .text.*) *(.init) } > zen
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > zen
    .data : { *(.data .data.*) } > zen
    .bss : { *(.bss .bss.*) *(COMMON) } > zen
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
