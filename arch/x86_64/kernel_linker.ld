/* kernel_linker.ld — OmniBus 6MB Static Memory Map
 * Bare-metal x86-64, no heap, deterministic allocation
 *
 * Memory Layout:
 * - Flash: 0x08000000 – 0x08200000 (Code, constants)
 * - RAM:   0x20000000 – 0x20600000 (6MB total)
 *   - .data: 0x20000000 (128KB, initialized)
 *   - .bss:  0x20020000 (5.5MB, static modules)
 *   - Stack: 0x205C0000 – 0x205FFFFF (256KB, top-down)
 */

/* Define memory regions */
MEMORY {
    /* Flash ROM for bootloader + kernel code */
    BOOT (rx)  : ORIGIN = 0x00007C00, LENGTH = 512    /* Stage 1 @ 0x7C00 */
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 2M     /* Kernel + module stubs */

    /* 6MB unified RAM for all module state */
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 6M
}

/* Stack top (grows downward from here) */
_estack = ORIGIN(RAM) + LENGTH(RAM);  /* 0x20600000 */

ENTRY(reset_handler)

SECTIONS {
    /* =====================================================================
     * 1. FLASH: Code and Read-Only Data
     * ===================================================================== */

    .boot_sector 0x00007C00 : {
        KEEP(*(.boot.sector))
        BYTE(0x55)                  /* Boot signature low byte */
        BYTE(0xAA)                  /* Boot signature high byte */
    } > BOOT

    .text 0x08000000 : {
        . = ALIGN(4);

        /* Interrupt Vector Table (ISR) */
        KEEP(*(.isr_vector))
        KEEP(*(.vectors))

        /* Kernel code */
        *(.text.reset_handler)
        *(.text.init_plugin)
        *(.text.*)
        *(.text)

        /* Module entry points */
        *(.module.entry)

        . = ALIGN(4);
        _etext = .;
    } > FLASH

    .rodata : {
        . = ALIGN(4);
        _srodata = .;

        /* String literals */
        *(.rodata)
        *(.rodata.*)

        /* Switch jump tables */
        *(.rodata1)

        . = ALIGN(4);
        _erodata = .;
    } > FLASH

    /* =====================================================================
     * 2. RAM: Initialized Data (.data)
     * ===================================================================== */

    /* LMA: Load Memory Address (in Flash) */
    _sidata = LOADADDR(.data);

    .data 0x20000000 : {
        . = ALIGN(4);
        _sdata = .;

        /* GDT, IDT, kernel tables */
        *(.data.gdt)
        *(.data.idt)
        *(.data.kernel)

        /* Initialized globals */
        *(.data)
        *(.data.*)

        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH

    /* =====================================================================
     * 3. RAM: Uninitialized Data (.bss) — LARGEST SECTION
     * ===================================================================== */

    .bss 0x20020000 (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;

        /* Kernel state */
        *(.bss.kernel)

        /* Tier 1: Trading modules (GridOS, ExecOS, AnalyticsOS, etc.) */
        *(.bss.grid_os)
        *(.bss.execution_os)
        *(.bss.analytics_os)
        *(.bss.blockchain_os)
        *(.bss.neuro_os)

        /* Tier 1 Auxiliary */
        *(.bss.bank_os)
        *(.bss.stealth_os)

        /* Tier 2-5: System, Notification, Protection, Verification */
        *(.bss.system)
        *(.bss.notification)
        *(.bss.protection)
        *(.bss.verification)

        /* Phase 50+ modules: Formal verification, cloud */
        *(.bss.formal_proofs)
        *(.bss.cloud_adapters)
        *(.bss.observability)

        /* Generic BSS */
        *(.bss)
        *(.bss.*)
        *(COMMON)

        . = ALIGN(8);
        _ebss = .;
    } > RAM

    /* =====================================================================
     * 4. RAM: Safety Gap (256KB) — Early Overflow Detection
     * ===================================================================== */

    .safety_gap (NOLOAD) : {
        . = ALIGN(4);
        _ssafety = .;

        /* Canary value for stack overflow detection */
        LONG(0xDEADBEEF);

        /* DMA buffer or fast cache (if needed) */
        . = ALIGN(4096);
        . = . + 256K - 4;  /* Fill to 256KB */

        . = ALIGN(4);
        _esafety = .;
    } > RAM

    /* =====================================================================
     * 5. RAM: Stack (Top-Down) — 256KB
     * ===================================================================== */

    /* Stack grows downward from _estack (0x205FFFFF) toward .bss */
    /* MSP initialized to _estack at startup */
    .stack (NOLOAD) : {
        . = ALIGN(8);
        _sstack = .;
        . = . + 256K;  /* Reserve 256KB for stack */
        . = ALIGN(8);
        _estack_end = .;
    } > RAM

    /* =====================================================================
     * 6. Verification: Check constraints
     * ===================================================================== */

    /* Ensure stack has minimum clearance */
    ASSERT(_ebss < _ssafety, "BSS overflows into safety gap!")
    ASSERT(_esafety < 0x205B0000, "Safety gap boundary violated!")
    ASSERT(_estack == 0x20600000, "Stack top is not at 6MB boundary!")

    /* =====================================================================
     * 7. Discard unused sections
     * ===================================================================== */

    /DISCARD/ : {
        *(.note*)
        *(.gnu_debuglink)
        *(.gnu_debugdata)
        *(.gnu.hash)
        *(.gnu.lto_*)
        *(.heap)
        *(.ARM.attributes)
    }
}

/* =====================================================================
 * Linker-Generated Symbols (used by startup code)
 * ===================================================================== */

/* Flash boundaries */
__flash_start = ORIGIN(FLASH);
__flash_end = ORIGIN(FLASH) + LENGTH(FLASH);

/* RAM boundaries */
__ram_start = ORIGIN(RAM);
__ram_end = ORIGIN(RAM) + LENGTH(RAM);

/* Data section symbols */
__data_load_addr = _sidata;    /* Where .data is in Flash */
__data_vma_start = _sdata;     /* Where .data should run in RAM */
__data_vma_end = _edata;

/* BSS section symbols */
__bss_start = _sbss;
__bss_end = _ebss;

/* Stack symbols */
__stack_top = _estack;
__stack_bottom = 0x205C0000;

/* Safety/canary */
__safety_start = _ssafety;
__safety_end = _esafety;
__safety_canary = 0xDEADBEEF;

