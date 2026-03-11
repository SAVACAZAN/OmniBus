/* Triage System Linker Script
 * Location: 0x3A7800–0x3AAFFF (21KB)
 */
ENTRY(init_plugin)
MEMORY { triage : ORIGIN = 0x3A7800, LENGTH = 0x3800 }
SECTIONS {
    .text 0x3A7800 : { *(.text .text.*) *(.init) } > triage
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > triage
    .data : { *(.data .data.*) } > triage
    .bss : { *(.bss .bss.*) *(COMMON) } > triage
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
