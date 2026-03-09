/* Linker Script for Ada Mother OS Kernel
   =======================================

   Memory Layout:
   - 0x100000–0x10FFFF: Ada Kernel (64KB)
     - 0x100000: Kernel entry point
     - 0x100010: Startup code entry

   Output: kernel.bin (raw binary, no ELF header)
*/

ENTRY(startup_begin)

SECTIONS
{
    /* Kernel code section - starts at 0x100010 */
    . = 0x100010;

    .text : ALIGN(16)
    {
        *(.text)
        *(.text.*)
    }

    /* Kernel data section */
    . = ALIGN(16);
    .data : ALIGN(16)
    {
        *(.data)
        *(.data.*)
    }

    /* Read-only data */
    . = ALIGN(16);
    .rodata : ALIGN(16)
    {
        *(.rodata)
        *(.rodata.*)
    }

    /* Uninitialized data (BSS) */
    . = ALIGN(16);
    .bss : ALIGN(16)
    {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    }

    /* Discard unnecessary sections */
    /DISCARD/ :
    {
        *(.note.*)
        *(.comment)
        *(.eh_frame)
        *(.gnu_hash)
    }
}
