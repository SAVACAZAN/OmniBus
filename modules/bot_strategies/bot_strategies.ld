/* Bot Strategies Module Linker Script
   Memory: 0x540000–0x55FFFF (128KB)
   Layout: Code + Data + BSS
*/

MEMORY
{
    bot_mem : ORIGIN = 0x540000, LENGTH = 128K
}

SECTIONS
{
    .text 0x540000 : {
        *(.text)
        *(.text.*)
    } > bot_mem

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > bot_mem

    .data : {
        *(.data)
        *(.data.*)
    } > bot_mem

    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > bot_mem

    /DISCARD/ : {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
    }
}
