/* bank_os.ld — Linker script for BankOS module
 * Phase 12: Bank settlement (SWIFT/ACH) integration
 * Memory: 0x280000–0x2AFFFF (192KB)
 * Compiles with: ld -T bank_os.ld
 */

MEMORY {
    BANK_OS (rwx) : ORIGIN = 0x280000, LENGTH = 192K
}

SECTIONS {
    .text ORIGIN(BANK_OS) : {
        init_plugin = .;        /* init_plugin at offset 0 */
        *(.text)
        *(.text.*)
    } > BANK_OS

    .data : {
        *(.data)
        *(.data.*)
    } > BANK_OS

    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > BANK_OS

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > BANK_OS

    .debug_info 0 : { *(.debug_info) }
    .debug_line 0 : { *(.debug_line) }
}
