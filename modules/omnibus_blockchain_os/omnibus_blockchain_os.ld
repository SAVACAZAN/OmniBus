/* OmniBus Blockchain OS – Linker Script
   Memory: 0x5D0000–0x5DFFFF (64KB)
   Phase 50 – Token Distribution Complete
*/

MEMORY
{
    blockchain_code : ORIGIN = 0x5D0000, LENGTH = 0xC000     /* 48KB code (extended for boot modules) */
    blockchain_data : ORIGIN = 0x5DC000, LENGTH = 0x10000    /* 64KB data + BSS (oracle/ws state) */
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
