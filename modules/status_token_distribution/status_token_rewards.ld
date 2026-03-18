/* Status Token Rewards Linker Script */

ENTRY(_start)

SECTIONS
{
    . = 0x5A0000;

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

    . = 0x5AFFFF;
}
