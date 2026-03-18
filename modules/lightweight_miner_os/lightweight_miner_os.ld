/* Lightweight Miner OS Linker Script (Phase 61A) */
/* Memory: 0x670000–0x67FFFF (64KB) */

MEMORY
{
    code (rx) : ORIGIN = 0x670000, LENGTH = 0x10000
}

SECTIONS
{
    .text : {
        *(.text)
        *(.text.*)
    } > code

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > code

    .data : {
        *(.data)
        *(.data.*)
    } > code

    .bss : {
        *(.bss)
        *(.bss.*)
    } > code
}
