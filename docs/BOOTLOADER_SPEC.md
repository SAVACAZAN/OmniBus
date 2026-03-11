# OmniBus Bootloader Specification

**Version**: v1.0
**Architecture**: x86-64 (BIOS boot)
**Memory Model**: 6MB static, no heap, 47 modules

---

## Boot Sequence Overview

```
0. BIOS Power-On
   ↓ (CS:IP = 0xFFFF:0000, Real mode)
   ↓
1. BIOS Loads Stage 1 @ 0x7C00 (512B)
   ↓ (Checks 0x55AA signature)
   ↓
2. Stage 1: Real Mode
   ├─ Enable A20 gate
   ├─ Load Stage 2 from disk into RAM
   └─ Jump to Stage 2
   ↓
3. Stage 2: Protected Mode (32-bit)
   ├─ Load GDT (3 descriptors: NULL, code, data)
   ├─ Load IDT stub
   ├─ Set CR0.PE (protected mode bit)
   ├─ Far jump to kernel @ 0x08000000
   └─ [Transition to 64-bit handled by kernel]
   ↓
4. Kernel: Long Mode (64-bit)
   ├─ reset_handler() (C code)
   ├─ Copy .data from Flash to RAM
   ├─ Zero-fill .bss (5.5MB static modules)
   ├─ Initialize stack canary
   ├─ Call kernel_main()
   └─ Start 47-module scheduler
```

---

## Stage 1: Real Mode Bootloader (512B)

**File**: `arch/x86_64/boot.asm`
**Memory**: 0x7C00 – 0x7DFE (510 bytes code + data)
**Signature**: 0x55AA @ 0x7DFE–0x7DFF

### Responsibilities

1. **A20 Line Enable**
   - Enable address line 20 (allows addressing > 1MB)
   - Method: KBC (8042) or FastGate

2. **Load Stage 2 from Disk**
   - Read from disk (sector offset = Stage 2 location)
   - Load into RAM at 0x08000000 (or temporary buffer)
   - Size: 4KB (8 sectors @ 512B each)

3. **Transition to Protected Mode**
   - Load GDT (from hardcoded location)
   - Set CR0.PE bit
   - Far jump to Stage 2

### Key Constraints

- **Must fit in 512 bytes** (including signature)
- Real mode only (no 32-bit instructions)
- Cannot use advanced disk I/O (INT 13h AH=02 only)
- Stack: 0x7C00 grows upward (tiny)

---

## Stage 2: Protected Mode Bootloader (4KB)

**File**: `arch/x86_64/stage2_fixed_final.asm`
**Memory**: 0x08000000 – 0x08001000 (4KB)

### Responsibilities

1. **GDT Setup**
   - 3 descriptors: NULL (0x00), CODE (0x08), DATA (0x10)
   - Base: 0x00000000 (flat model)
   - Limit: 0xFFFFFFFF (4GB, all usable)

2. **IDT Stub**
   - 256 gate descriptors (minimal)
   - Vectors 0–31: Reserved (exceptions)
   - Vectors 32–255: Maskable interrupts
   - Filled with panic handler stub

3. **Switch to Protected Mode**
   ```asm
   mov eax, cr0
   or eax, 0x01        ; Set PE bit (Protected Enable)
   mov cr0, eax
   jmp 0x08:pmode_entry  ; Far jump to flush prefetch
   ```

4. **Transition to Long Mode (64-bit)**
   - Set CR4.PAE (Physical Address Extension)
   - Load CR3 with paging table address
   - Set IA32_EFER.LME (Long Mode Enable)
   - Set CR0.PG (Paging Enable)
   - Far jump to 64-bit code

5. **Jump to Kernel**
   - Call reset_handler @ 0x20000000 (or relocated)

### Key Constraints

- **Must be < 4KB**
- 32-bit protected mode (uses 32-bit registers)
- Can access up to 4GB address space
- Must enable paging before 64-bit

---

## Kernel: Reset Handler (reset_handler.c)

**Entry Point**: `reset_handler()`
**Mode**: 64-bit long mode, paging enabled
**Stack**: Not yet initialized (use temporary)

### Sequence

1. **Copy .data from Flash → RAM**
   ```c
   memcpy(__data_vma_start, __data_load_addr, data_size);
   ```

2. **Zero-fill .bss**
   ```c
   memset(__bss_start, 0, bss_size);
   ```

3. **Initialize Stack Pointer**
   ```c
   asm("mov %0, %%rsp" : : "r"(__stack_top - 8));
   ```

4. **Initialize Stack Canary**
   ```c
   *(uint32_t *)(__stack_bottom + 32) = 0xDEADBEEF;
   ```

5. **Configure Hardware**
   - Enable MPU (segment limits)
   - Enable caches
   - Disable interrupts (CLI)

6. **Call kernel_main()**
   ```c
   int result = kernel_main();
   ```

7. **Infinite halt on return**
   ```asm
   hlt
   ```

---

## Memory Layout During Boot

### Stage 1 (Real Mode, 16-bit)

```
0x00000000 ┌─────────────────┐
           │ IVT + BIOS data │ 1MB
0x00100000 ├─────────────────┤
           │ Available       │
0x00400000 ├─────────────────┤
           │ EBDA            │
0x007C00 ┌─┤ Stage 1 Code    │ 512B
         │ │ (executing)     │
0x007E00 ├─┤ Stack (grows up)│
         │ │                 │
0x007FFF └─┴─────────────────┘
```

### Stage 2 (Protected Mode, 32-bit)

```
0x00000000 ┌─────────────────┐
           │ IVT (unused)    │
0x08000000 ├─────────────────┤
           │ Stage 2 Code    │ 4KB
           │ (executing)     │
0x08001000 ├─────────────────┤
           │ GDT             │
0x08002000 ├─────────────────┤
           │ IDT             │
0x08003000 ├─────────────────┤
           │ Paging Tables   │
0x08200000 ├─────────────────┤
           │ Available Flash │
```

### Kernel (Long Mode, 64-bit, Paging Enabled)

```
0x20000000 ┌─────────────────┐
           │ .data (128KB)   │ [copied from Flash]
0x20020000 ├─────────────────┤
           │ .bss (5.5MB)    │ [zeroed]
           │ - GridOS        │
           │ - AnalyticsOS   │
           │ - 45 other mods │
0x205B0000 ├─────────────────┤
           │ Safety Gap      │ [canary guard]
           │ (256KB)         │
0x205C0000 ├─────────────────┤
           │ Stack (grows ↓) │ [256KB reserved]
0x205FFFFF ├─────────────────┤
           │ [top of 6MB]    │
0x20600000 └─────────────────┘
```

---

## Linker Script Integration

The `kernel_linker.ld` defines:

1. **MEMORY regions**
   ```ld
   BOOT (rx)  : ORIGIN = 0x7C00,  LENGTH = 512
   FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 2M
   RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 6M
   ```

2. **Section mapping**
   - `.text`: 0x08000000 (code in Flash)
   - `.data`: 0x20000000 (from Flash LMA)
   - `.bss`: 0x20020000 (zero-filled)
   - `.stack`: 0x205C0000 (reserved)

3. **Generated symbols**
   - `__flash_start`, `__ram_start`, `__stack_top`
   - `_sidata`, `_sdata`, `_edata` (data section)
   - `_sbss`, `_ebss` (BSS section)

---

## Boot Checklist

### Stage 1
- [ ] Enable A20 gate (KBC or FastGate)
- [ ] Load Stage 2 from disk (INT 13h)
- [ ] Verify Stage 2 checksum (optional)
- [ ] Set up GDT (minimal)
- [ ] Enable protected mode (CR0.PE)
- [ ] Far jump to Stage 2

### Stage 2
- [ ] Load full GDT (3 descriptors)
- [ ] Load IDT (stub)
- [ ] Enable paging (set CR3, CR4.PAE, CR0.PG)
- [ ] Switch to long mode (IA32_EFER.LME)
- [ ] Far jump to 64-bit code @ 0x08000000

### Kernel (reset_handler)
- [ ] Copy .data from Flash to RAM
- [ ] Zero-fill .bss (5.5MB)
- [ ] Initialize MSP (stack pointer)
- [ ] Initialize stack canary
- [ ] Enable caches
- [ ] Call kernel_main()

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Triple fault immediately | A20 not enabled | Check KBC/FastGate logic |
| Hangs after Stage 1 | Stage 2 not loaded | Check disk I/O (INT 13h) |
| HardFault in Stage 2 | Paging table incorrect | Verify CR3 address |
| Crashes in reset_handler | MSP not initialized | Set MSP to `__stack_top - 8` |
| Modules not found | Linker script mismatch | Check module base addresses |
| Stack overflow detected | BSS too large | Increase safety gap |

---

## Performance Notes

- **Stage 1 → Stage 2**: ~10ms (disk I/O)
- **Stage 2 init**: ~1ms (GDT, IDT, paging)
- **Kernel reset_handler**: ~0.1ms (memcpy + memset)
- **Module initialization**: ~10ms (47 modules × 0.2ms each)
- **Total boot time**: ~20–30ms (dominated by disk I/O)

---

## Security Considerations

1. **No bootloader signing** (current)
   - Vulnerable to malicious stage2 on disk
   - Future: Use TPM or signed Stage 2

2. **No UEFI/Secure Boot** (current)
   - BIOS boot only (legacy)
   - Future: Add UEFI support

3. **Canary-based stack overflow detection**
   - Hardware breakpoint on access to canary
   - Kernel panics on corruption

4. **No ASLR** (current)
   - Fixed addresses (determinism for HFT)
   - Acceptable risk (bare-metal, no multi-process)

---

## References

- Intel x86-64 Architecture Manual: Volume 3 (System Programming)
- AMD64 Architecture Application Programmer's Manual: Volume 2 (System Programming)
- OSDev.org Baremetal x86-64 tutorial
- OSDEV Bootloader wiki

