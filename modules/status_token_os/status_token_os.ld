/* Status Token OS Linker Script */

ENTRY(_start)

SECTIONS
{
    . = 0x560000;

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

    . = 0x56F000;
}
