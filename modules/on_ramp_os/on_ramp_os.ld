/* On-Ramp OS Linker Script */

ENTRY(_start)

SECTIONS
{
    . = 0x570000;

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

    . = 0x57F000;
}
