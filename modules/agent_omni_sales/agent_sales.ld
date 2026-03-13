/* Agent OMNI Sales Linker Script */

ENTRY(_start)

SECTIONS
{
    . = 0x5B0000;

    .text :
    {
        *(.text*)
        *(.rodata*)
    }

    .data :
    {
        *(.data*)
        *(.bss*)
    }

    . = 0x5BFFFF;
}
