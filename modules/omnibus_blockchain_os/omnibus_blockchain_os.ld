/* OmniBus Blockchain OS – Linker Script
   Memory: 0x5D0000–0x5DFFFF (64KB)
   Phase 50 – Token Distribution Complete
*/

MEMORY
{
    blockchain_code : ORIGIN = 0x5D0000, LENGTH = 0x8000     /* 32KB code */
    blockchain_data : ORIGIN = 0x5D8000, LENGTH = 0x8000     /* 32KB data + BSS */
}

SECTIONS
{
    .text :
    {
        *(.text)
        *(.text.*)
    } > blockchain_code

    .rodata :
    {
        *(.rodata)
        *(.rodata.*)
    } > blockchain_code

    .data :
    {
        *(.data)
        *(.data.*)
    } > blockchain_data

    .bss :
    {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > blockchain_data

    /DISCARD/ :
    {
        *(.note.GNU-stack)
        *(.note.gnu.build-id)
    }
}
