/* Wallet Manager Linker Script
 * Location: 0x530000–0x57FFFF (320KB protected stealth zone)
 */
ENTRY(main)
MEMORY { wallet : ORIGIN = 0x530000, LENGTH = 0x50000 }
SECTIONS {
    .text 0x530000 : { *(.text .text.*) *(.init) } > wallet
    .rodata : { *(.rodata .rodata.*) *(.data.rel.ro .data.rel.ro.*) } > wallet
    .data : { *(.data .data.*) } > wallet
    .bss : { *(.bss .bss.*) *(COMMON) } > wallet
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu_debugdata) }
}
