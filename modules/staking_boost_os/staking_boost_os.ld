/* Staking Boost OS Linker Script */

ENTRY(_start)

SECTIONS
{
    . = 0x580000;

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

    . = 0x58F000;
}
