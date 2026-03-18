/* reset_handler.c — OmniBus Kernel Boot Sequence
 * Runs in 64-bit long mode after Stage 2 bootloader
 *
 * Responsibilities:
 * 1. Copy .data from Flash to RAM
 * 2. Zero-fill .bss
 * 3. Initialize stack canary
 * 4. Configure hardware (MPU, caches)
 * 5. Jump to kernel main()
 */

#include <stdint.h>
#include <string.h>

/* =====================================================================
 * Linker-Generated Symbols
 * ===================================================================== */

extern uint8_t __flash_start[];
extern uint8_t __data_load_addr[];
extern uint8_t __data_vma_start[];
extern uint8_t __data_vma_end[];
extern uint8_t __bss_start[];
extern uint8_t __bss_end[];
extern uint8_t __stack_top[];
extern uint8_t __stack_bottom[];
extern uint8_t __safety_canary;

/* =====================================================================
 * Architecture-Specific Helpers
 * ===================================================================== */

/* Set Model-Specific Register (x86-64) */
static inline void wrmsr(uint32_t msr, uint64_t value) {
    uint32_t low = (uint32_t)(value & 0xFFFFFFFF);
    uint32_t high = (uint32_t)((value >> 32) & 0xFFFFFFFF);
    asm volatile("wrmsr" : : "c"(msr), "a"(low), "d"(high));
}

/* Read MSR */
static inline uint64_t rdmsr(uint32_t msr) {
    uint32_t low, high;
    asm volatile("rdmsr" : "=a"(low), "=d"(high) : "c"(msr));
    return ((uint64_t)high << 32) | low;
}

/* Invalidate TLB (flush translation lookaside buffer) */
static inline void invlpg(void *addr) {
    asm volatile("invlpg (%0)" : : "r"(addr) : "memory");
}

/* =====================================================================
 * Hardware Configuration
 * ===================================================================== */

void init_mpu(void) {
    /* On x86-64 without full MMU, we use segment limits + paging
     * For our fixed 6MB layout, this is compile-time enforced by linker
     */

    /* Future: Configure SMEP/SMAP if available (Skylake+) */
    uint64_t cr4 = rdmsr(0x3A0);  /* IA32_FEATURE_CONTROL */

    /* Enable supervisor mode execution prevention if available */
    if (cr4 & (1 << 20)) {  /* SMEP available */
        cr4 |= (1 << 20);
        wrmsr(0x3A0, cr4);
    }
}

void init_caches(void) {
    /* On x86-64, caches are typically enabled by default
     * Here we just verify they're on for performance
     */

    uint64_t cr0;
    asm volatile("mov %%cr0, %0" : "=r"(cr0));

    /* Ensure cache is not disabled (CD bit = 0) */
    cr0 &= ~(1ULL << 30);  /* Clear CD (cache disable) */
    cr0 |= (1ULL << 29);   /* Set NW (not-write through) for performance */

    asm volatile("mov %0, %%cr0" : : "r"(cr0));
}

/* =====================================================================
 * Memory Initialization
 * ===================================================================== */

void copy_data_section(void) {
    /* Copy .data from Flash (LMA) to RAM (VMA)
     *
     * This is typically done 8 bytes at a time (uint64_t)
     * for maximum performance
     */

    uint64_t *src = (uint64_t *)__data_load_addr;
    uint64_t *dst = (uint64_t *)__data_vma_start;
    uint64_t count = (uint64_t)(__data_vma_end - __data_vma_start) / sizeof(uint64_t);

    for (uint64_t i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

void zero_bss_section(void) {
    /* Zero-fill .bss section
     * This is where all 47 modules' static state lives
     */

    uint64_t *dst = (uint64_t *)__bss_start;
    uint64_t count = (uint64_t)(__bss_end - __bss_start) / sizeof(uint64_t);

    for (uint64_t i = 0; i < count; i++) {
        dst[i] = 0;
    }
}

void init_stack_canary(void) {
    /* Write canary value at base of stack
     * If stack grows below this, it gets corrupted -> we detect it
     */

    volatile uint32_t *canary = (uint32_t *)((uint64_t)__stack_bottom + 32);
    *canary = 0xDEADBEEF;
}

/* =====================================================================
 * Kernel Main (forward declaration)
 * ===================================================================== */

extern int kernel_main(void);

/* =====================================================================
 * Reset Handler — Entry Point
 * ===================================================================== */

void reset_handler(void) {
    /* Stage 1: Initialize memory
     * ===========================
     * Order is critical: 1) Copy data, 2) Clear BSS, 3) Set up stack
     */

    copy_data_section();
    zero_bss_section();
    init_stack_canary();

    /* Stage 2: Configure hardware
     * ===========================
     */

    init_mpu();
    init_caches();

    /* Stage 3: Set Stack Pointer (x86-64 calling convention)
     * =====================================================
     * RSP should be 16-byte aligned before first call instruction
     * _estack is at 0x20600000 (already aligned)
     */

    asm volatile("mov %0, %%rsp" : : "r"(__stack_top - 8));

    /* Stage 4: Disable interrupts (until we're ready)
     * ===============================================
     */
    asm volatile("cli");

    /* Stage 5: Jump to Kernel Main
     * =============================
     * kernel_main() initializes all 47 modules and starts scheduler
     */

    int result = kernel_main();

    /* If kernel_main returns (should never happen), halt */
    while (1) {
        asm volatile("hlt");
    }
}

/* =====================================================================
 * Diagnostic Functions (for debugging)
 * ===================================================================== */

struct memory_stats {
    uint64_t data_size;
    uint64_t bss_size;
    uint64_t stack_size;
    uint64_t total_ram_used;
    uint64_t safety_margin;
};

struct memory_stats get_memory_stats(void) {
    struct memory_stats stats;

    stats.data_size = (uint64_t)(__data_vma_end - __data_vma_start);
    stats.bss_size = (uint64_t)(__bss_end - __bss_start);
    stats.stack_size = (uint64_t)(__stack_top - __stack_bottom);
    stats.total_ram_used = stats.data_size + stats.bss_size + stats.stack_size;
    stats.safety_margin = (6 * 1024 * 1024) - stats.total_ram_used;

    return stats;
}

void check_stack_canary(void) {
    /* Runtime check for stack overflow
     * Should be called periodically from the scheduler
     */

    volatile uint32_t *canary = (uint32_t *)((uint64_t)__stack_bottom + 32);

    if (*canary != 0xDEADBEEF) {
        /* PANIC: Stack has corrupted canary */
        while (1) {
            asm volatile("hlt");
        }
    }
}

