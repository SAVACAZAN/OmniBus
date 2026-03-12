/* Phase 66: OmniBus Network OS Linker Script */

ENTRY(_start)

MEMORY
{
    rom (rx)  : ORIGIN = 0x5E0000, LENGTH = 64K
}

SECTIONS
{
    .text :
    {
        *(.text*)
        *(.rodata*)
        *(.data*)
    } > rom

    .bss :
    {
        *(.bss*)
        *(COMMON)
    } > rom

    /DISCARD/ : { *(.note.GNU-stack) }
}
