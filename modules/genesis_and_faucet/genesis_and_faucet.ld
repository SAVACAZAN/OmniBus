/* Genesis and Faucet Linker Script (Phase 61) */
/* Memory: 0x660000–0x730000 (Dynamic allocation for state structures) */

MEMORY
{
    code (rx) : ORIGIN = 0x660000, LENGTH = 0xD0000   /* 832KB for code and data */
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
