# OmniBus Static Memory Map (6MB)

**System**: Bare-metal x86-64, 6MB unified RAM, no heap, no MMU
**Boot**: BIOS → Stage 1 (512B) → Stage 2 (4KB) → Kernel (64-bit long mode)

---

## Memory Layout Overview

```
0x00000000 ┌─────────────────────────────────┐
           │  BIOS Real Mode Area            │ 64KB
           │  (Interrupt vectors, BIOS data) │
0x00010000 ├─────────────────────────────────┤
           │  Bootloader (Stage 1)           │ 512B @ 0x7C00
           └─────────────────────────────────┘

0x08000000 ┌─────────────────────────────────┐
           │  Flash ROM                      │
           ├─────────────────────────────────┤
           │  .text (Kernel Code)            │ 64KB
           │  .text (Module Stubs)           │
0x08010000 ├─────────────────────────────────┤
           │  .rodata (Constants, Strings)   │ 128KB
0x08020000 ├─────────────────────────────────┤
           │  Stage 2 Bootloader             │ 4KB
           │  (Protected mode entry)         │
0x08021000 └─────────────────────────────────┘

0x20000000 ┌─────────────────────────────────┐ ← RAM START
           │  .data (Initialized globals)    │ 128KB
           │  - GDT, IDT tables              │
           │  - Kernel state                 │
0x20020000 ├─────────────────────────────────┤
           │  .bss (Uninitialized statics)   │ 5.5MB
           │  ├─ Kernel data (64KB)          │
           │  ├─ Grid OS state (128KB)       │
           │  ├─ Analytics OS (512KB)        │
           │  ├─ Execution OS (128KB)        │
           │  ├─ BlockchainOS (192KB)        │
           │  ├─ NeuroOS (512KB)             │
           │  ├─ BankOS (192KB)              │
           │  ├─ StealthOS (128KB)           │
           │  ├─ Tier 2-5 modules (1.5MB)    │
           │  ├─ Formal verification (256KB) │
           │  ├─ Cloud adapters (320KB)      │
           │  └─ Event replay (64KB)         │
           │                                 │
0x205B0000 ├─────────────────────────────────┤
           │  "No-Man's Land" (Safety Gap)   │ 256KB
           │  (Emergency buffer / DMA)       │
0x205C0000 ├─────────────────────────────────┤
           │  Stack (Top-Down)               │ 256KB
           │  ← Stack grows downward         │
0x205FFFFF ├─────────────────────────────────┤
           │  (Stack bottom limit)           │
0x20600000 └─────────────────────────────────┘ ← RAM END (6MB)

0x40000000 ┌─────────────────────────────────┐
           │  MMIO (Peripherals)             │
           │  - UART (0x40001000)            │
           │  - Timer (0x40002000)           │
           │  - GPIO (0x40003000)            │
           │  - DMA (0x40004000)             │
           │  - etc.                         │
0xFFFFFFFF └─────────────────────────────────┘
```

---

## Detailed Segment Breakdown

### 1. Flash (.text + .rodata)

| Segment | Start | Size | Purpose |
|---------|-------|------|---------|
| **Bootloader Stage 1** | 0x7C00 | 512B | BIOS entry, A20 gate, load Stage 2 |
| **Bootloader Stage 2** | 0x08000000 | 4KB | Protected mode transition, jump to kernel |
| **Kernel Code** | 0x08001000 | 64KB | Ada Mother OS kernel, IDT, exception handlers |
| **Module Entry Stubs** | 0x08010000 | 128KB | Zig module entry points (Grid, Exec, Analytics, etc.) |
| **Read-Only Data** | 0x08020000 | 256KB | String literals, constants, lookup tables |

**Total Flash**: ~512KB (non-volatile)

### 2. RAM: .data (Initialized Globals)

| Section | Start | Size | Contents |
|---------|-------|------|----------|
| **GDT/IDT** | 0x20000000 | 8KB | Global Descriptor Table, Interrupt Descriptor Table |
| **Kernel State** | 0x20002000 | 64KB | Cycle counter, exception state, IPC buffers |
| **Init Magic** | 0x20012000 | 4KB | Boot flags, initialization markers |

**Total .data**: ~128KB (copied from Flash at startup)

### 3. RAM: .bss (Uninitialized Statics) — **THE LARGEST CONSUMER**

Per-module breakdown (all at fixed addresses, pre-allocated):

| Module | Address | Size | Description |
|--------|---------|------|-------------|
| **Tier 1: Trading** | | |
| GridOS | 0x110000 | 128KB | Order grid state, matching engine |
| ExecutionOS | 0x130000 | 128KB | Order queues, execution state |
| AnalyticsOS | 0x150000 | 512KB | Market data buffers, OHLCV |
| BlockchainOS | 0x250000 | 192KB | Solana state, flash loan queue |
| NeuroOS | 0x2D0000 | 512KB | ML model weights, GA state |
| **Tier 1 Auxiliary** | | |
| BankOS | 0x280000 | 192KB | SWIFT/ACH messages |
| StealthOS | 0x2C0000 | 128KB | MEV protection state |
| **Tier 2-5 System** | 0x300000 | 1.5MB | Report, Checksum, AutoRepair, Zorin, Audit, ParamTune, HistAnalytics, Alert, Consensus, Federation, MEV, CrossChain, DAO, Profiler, Recovery, Compliance, Staking, Slashing, Auction, Breaker, FlashLoan, L2Rollup, Quantum, PQC |
| **Tier 5: Verification** | | |
| seL4 Microkernel | 0x4A0000 | 64KB | Capability-based isolation |
| CrossValidator | 0x4B0000 | 64KB | Ada/seL4 divergence detection |
| ProofChecker | 0x4C0000 | 64KB | T1-T4 theorem verification |
| ConvergenceTest | 0x4D0000 | 64KB | 1000+ cycle tracking |
| DomainResolver | 0x4E0000 | 64KB | ENS/blockchain domain cache |
| **Tier 3: Observability** | | |
| LoggingOS | 0x5A0000 | 64KB | JSON event log buffer |
| DatabaseOS | 0x5B0000 | 64KB | Trade journal + idempotency |
| CassandraOS | 0x5C0000 | 64KB | Multi-DC replication state |
| MetricsOS | 0x5D0000 | 64KB | Prometheus metrics cache |
| **Tier 3: Replay** | | |
| ReplayOS | 0x5E0000 | 64KB | Event replay + compensation |
| **Tier 3: Cloud** | | |
| MicrosoftOS | 0x5F0000 | 64KB | Azure instance tracking |
| OracleOS | 0x600000 | 64KB | OCI instance tracking |
| AWSOS | 0x610000 | 64KB | AWS instance tracking |
| VmwareOS | 0x620000 | 64KB | vSphere instance tracking |
| GCPOS | 0x630000 | 64KB | GCP instance tracking |

**Total .bss**: ~5.5MB (zero-filled at startup)

### 4. RAM: "No-Man's Land" (Safety Gap)

- **Address**: 0x205B0000 – 0x205BFFFF
- **Size**: 256KB
- **Purpose**: Emergency buffer for:
  - DMA transfers (if needed)
  - Fast RAM cache (if available)
  - Stack overflow detection (Canary value)
  - Runtime diagnostics

### 5. RAM: Stack (Top-Down, 256KB)

- **Base**: 0x205C0000 (bottom limit)
- **Top**: 0x205FFFFF (grows downward)
- **Size**: 256KB (sufficient for 47 modules without malloc)
- **MSP Init**: Set to 0x205FFFFF at startup
- **Guard**: Check canary @ 0x205B0000 periodically

**Why 256KB (not smaller)?**
- Deep call stacks in event processing
- Local buffers in module functions
- No heap → stack can safely use freed heap space

---

## Linker Script Mapping (.ld)

```ld
MEMORY {
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 2M
    RAM (rwx)   : ORIGIN = 0x20000000, LENGTH = 6M
}

_estack = 0x20600000;  /* Top of stack */

SECTIONS {
    .text 0x08000000 : {
        KEEP(*(.isr_vector))
        *(.text*)
        *(.rodata*)
    } > FLASH

    _sidata = LOADADDR(.data);
    .data 0x20000000 : {
        _sdata = .;
        *(.data*)
        _edata = .;
    } > RAM AT > FLASH

    .bss 0x20020000 : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM

    /* Safety check */
    ._stack_check : {
        . = ALIGN(8);
        . = . + 256K;  /* Minimal stack size */
    } > RAM
}
```

---

## Boot Sequence

1. **BIOS** (Real mode, 16-bit)
   - Loads Stage 1 @ 0x7C00
   - Checks 0x55AA signature

2. **Stage 1** (512B, 16-bit)
   - Enable A20 gate
   - Load Stage 2 from disk
   - Jump to Stage 2 @ 0x08000000

3. **Stage 2** (4KB, 32-bit protected mode)
   - Load GDT, IDT
   - Set CR0.PE (protected mode bit)
   - Jump to 64-bit kernel

4. **Kernel Reset Handler** (Zig, 64-bit long mode)
   - Copy .data from Flash to RAM
   - Zero-fill .bss
   - Initialize MPU
   - Configure Stack Pointer (MSP = 0x205FFFFF)
   - Jump to Kernel Main

5. **Kernel Main** (Ada Mother OS)
   - Initialize 47 modules
   - Start scheduler loop

---

## Memory Protection (MPU Configuration)

For x86-64 without MMU, we emulate protection via:

1. **Segment Limits** (via GDT)
   - Code segment: 0x08000000 – 0x20600000 (Read-Execute only)
   - Data segment: 0x20000000 – 0x20600000 (Read-Write)

2. **Stack Canary** (Software Guard)
   - Write 0xDEADBEEF @ 0x205B0000
   - Check every 65536 cycles
   - If corrupted → HardFault

3. **Bounds Checking** (In kernel)
   - All module pointers must be within segment bounds
   - Violators: `SYS_PANIC` exception

---

## Performance Implications

| Operation | Latency | Notes |
|-----------|---------|-------|
| Flash read (code) | ~4-5 cycles | With prefetch buffer |
| RAM read (.bss) | ~1-2 cycles | Local module state |
| Stack push | ~1 cycle | Top-of-stack cached |
| Module dispatch | <100 ns | Fixed address jump |
| IPC (cross-module) | <500 ns | Shared buffer + flag |

---

## Allocation Checklist

✅ Bootloader (Stage 1 @ 0x7C00, Stage 2 @ 0x08000000)
✅ Kernel (64KB @ 0x100000)
✅ 47 Modules (4.7MB @ 0x110000–0x630000)
✅ Stack (256KB @ 0x205C0000)
✅ Safety Gap (256KB @ 0x205B0000)
✅ No Heap (eliminated entirely)
✅ No Malloc (all static allocation)

**Total Used**: ~5.8MB / 6MB
**Free Margin**: ~200KB (safety buffer)

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| HardFault at boot | Stack MSP not initialized | Check Reset_Handler, verify _estack address |
| Module not found | Linker script address mismatch | Verify module base address matches .ld |
| Crashes in interrupt | VTOR (Vector Table Offset) wrong | Ensure SCB->VTOR = kernel address |
| Slow code execution | Flash prefetch disabled | Set FLASH_ACR prefetch bit |
| Stack overflow | Local buffers too large | Reduce local arrays, use module-level state |

---

## Next Steps

1. Update linker scripts for all modules
2. Implement Reset_Handler with .data copy + .bss zero-fill
3. Add MPU/Stack Canary configuration
4. Test with QEMU memory instrumentation

