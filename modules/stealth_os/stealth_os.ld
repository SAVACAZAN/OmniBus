/* stealth_os.ld — Linker script for Stealth OS module
 * Phase 13: MEV protection (order obfuscation + sandwich attack detection)
 * Memory: 0x2C0000–0x2DFFFF (128KB)
 */

MEMORY {
    STEALTH_OS (rwx) : ORIGIN = 0x2C0000, LENGTH = 128K
}

SECTIONS {
    .text ORIGIN(STEALTH_OS) : {
        init_plugin = .;        /* init_plugin at offset 0 */
        *(.text)
        *(.text.*)
    } > STEALTH_OS

    .data : {
        *(.data)
        *(.data.*)
    } > STEALTH_OS

    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > STEALTH_OS

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > STEALTH_OS

    .debug_info 0 : { *(.debug_info) }
    .debug_line 0 : { *(.debug_line) }
}
