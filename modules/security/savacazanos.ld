/* SAVACAZANos Linker Script
 * Location: 0x388000–0x38BFFF (21KB)
 */
ENTRY(init_plugin)
MEMORY { sec : ORIGIN = 0x388000, LENGTH = 0x4000 }
SECTIONS {
    .text 0x388000 : { *(.text .text.*) *(.init) } > sec
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > sec
    .data : { *(.data .data.*) } > sec
    .bss : { *(.bss .bss.*) *(COMMON) } > sec
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
