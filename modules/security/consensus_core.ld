/* Consensus Core Linker Script
 * Location: 0x3AD000–0x3B2FFF (36KB)
 */
ENTRY(init_plugin)
MEMORY { consensus : ORIGIN = 0x3AD000, LENGTH = 0x6000 }
SECTIONS {
    .text 0x3AD000 : { *(.text .text.*) *(.init) } > consensus
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > consensus
    .data : { *(.data .data.*) } > consensus
    .bss : { *(.bss .bss.*) *(COMMON) } > consensus
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
