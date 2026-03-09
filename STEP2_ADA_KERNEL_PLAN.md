# STEP 2: ADA MOTHER OS KERNEL IMPLEMENTATION

## Timeline & Scope
- **Duration**: Weeks 2-3 (14 days, ~150 hours)
- **Critical Blocker**: Blocks ALL other layers (L2-L24)
- **Success Criteria**:
  - Ada kernel boots to protected mode
  - Auth gate mechanism functional (0x100050 = 0x70)
  - PQC vault initialized (Kyber keys at 0x100800)
  - UART debug output working
  - QEMU boot test passes (Bootloader → Ada → Protected Mode)
  - All other layers can now initialize

---

## Architecture Overview

### Purpose
Ada Mother OS is the **security kernel and task orchestrator** for all 7 OS layers. Unlike traditional kernels, it:
1. **Validates all requests** from L2-L7 before execution
2. **Controls auth gate** (0x100050) — set to 0x70 to allow cycles
3. **Manages PQC vault** (0x100800) — Post-Quantum Cryptography keys for all layers
4. **Schedules execution** — rounds/cycles through L2-L4 trading layers
5. **Enforces memory isolation** — violations trigger SYS_PANIC
6. **No floating-point** — all math is fixed-point or integer

### Why Ada SPARK?
- **Formal verification** potential — SPARK subset allows mathematical proof
- **Type safety** — Ada's strong typing prevents bugs before runtime
- **Contract checking** — preconditions, postconditions, invariants
- **Built-in checks** — no buffer overflows, no undefined behavior
- **Suitable for security-critical code** — used in avionics, medical devices

---

## Memory Layout: Ada Kernel (0x100000–0x10FFFF = 64KB)

```
0x100000  KernelHeader (16B)
          [magic:u32="ADAK"][version:u16][flags:u16]

0x100010  StartupCode (1KB = 256 instructions)
          ├─ Enable paging
          ├─ Set up GDT (Global Descriptor Table)
          ├─ Load IDT (Interrupt Descriptor Table)
          ├─ Call Ada_Main()
          └─ Never returns (runs event loop)

0x100050  📌 AUTH GATE (1B) ⭐ CRITICAL
          ├─ Read: Check if == 0x70 (execute permission)
          ├─ Write: Ada kernel controls this byte
          └─ All L2-L7 read this at cycle start; if != 0x70, skip cycle

0x100800  🔐 PQC VAULT (2KB = Kyber-512 keys + metadata)
          ├─ Kyber public key A[u32; 512] — 2KB
          ├─ Kyber shared secret — 32B
          ├─ Hash of signing key — 32B
          └─ Encryption state — 32B

0x100400  TaskDescriptorTable (4KB)
          ├─ Task[0] = L2 Grid OS
          ├─ Task[1] = L3 Analytics OS
          ├─ Task[2] = L4 Execution OS
          ├─ Task[3..15] = Reserved (L5-L7 + future)
          └─ Each task: state, priority, memory bounds, entry point

0x101400  ExceptionHandlers (6KB)
          ├─ IRQ0: Timer (1KB) — not used yet
          ├─ IRQ1: Keyboard (1KB)
          ├─ IRQ8-14: Reserved (2KB)
          ├─ Exception #6 (Opcode) — illegal instruction → SYS_PANIC
          ├─ Exception #13 (GP Fault) — memory violation → SYS_PANIC
          └─ Soft IRQ 0x10: Syscall entry (2KB)

0x102C00  SchedulerState (2KB)
          ├─ current_task: u8 (0-2 = L2-L4)
          ├─ cycle_count: u64 (global counter)
          ├─ time_allocated_ms: u32 per task
          ├─ task_state: [3]TaskState
          │    ├─ state: enum {ready, running, blocked, idle}
          │    ├─ tsc_last_run: u64
          │    ├─ cycles: u64
          │    └─ errors: u32
          └─ irq_mask: u32 (which interrupts are active)

0x103200  MemoryManagement (3KB)
          ├─ PageDirectory @ 0x200000 (64KB, 16K page tables)
          ├─ L2 bounds: [0x110000, 0x12FFFF] — 128KB
          ├─ L3 bounds: [0x150000, 0x1FFFFF] — 512KB
          ├─ L4 bounds: [0x130000, 0x14FFFF] — 128KB
          ├─ L5-L7 bounds: Reserved
          └─ Violation handler: raises SYS_PANIC

0x100C00  GovernanceState (2KB)
          ├─ Authority hash (32B) — check signing key
          ├─ Governance flags (32B)
          │    ├─ Bit 0: Production mode (1) or debug (0)
          │    ├─ Bit 1: Enable trading (1) or simulate (0)
          │    ├─ Bits 2-7: Reserved
          ├─ Approval quorum (u8) — threshold for operations
          └─ PQC signature slots (4 × 64B = 256B) — multi-sig validation

0x104200  StackSpace (remaining ~48KB up to 0x10FFFF)
          ├─ Ada Stack: grows downward from 0x10FFFF
          ├─ Per-task context (128B each × 3 tasks)
          ├─ Working buffers (for crypto, etc.)
          └─ Guard page @ 0x10F000 (detect overflow)
```

---

## File Structure

```
modules/ada_mother_os/
├── ada_kernel.ads     # Ada package specification (interface contract)
├── ada_kernel.adb     # Ada implementation (body)
├── startup.asm        # x86-64 asm: paging setup, jump to Ada_Main
├── interrupts.ads     # Exception handler declarations
├── interrupts.adb     # Exception handler implementations
├── scheduler.ads      # Task scheduling interface
├── scheduler.adb      # Task scheduling logic
├── memory_mgmt.ads    # Memory isolation interface
├── memory_mgmt.adb    # Paging + bounds checking
├── pqc_vault.ads      # Kyber-512 interface
├── pqc_vault.adb      # Kyber-512 implementation (or FFI to Zig)
└── build.sh           # Ada SPARK compiler + verification script
```

**Estimated Lines of Code**:
- startup.asm: ~150 lines (pure asm, paging setup)
- ada_kernel.ads: ~200 lines (contracts + types)
- ada_kernel.adb: ~300 lines (main loop, task dispatch)
- interrupts.ads: ~100 lines (exception specs)
- interrupts.adb: ~250 lines (exception handlers)
- scheduler.ads: ~80 lines (task queue interface)
- scheduler.adb: ~200 lines (round-robin + fairness)
- memory_mgmt.ads: ~60 lines (memory bounds spec)
- memory_mgmt.adb: ~150 lines (page table setup + bounds checks)
- pqc_vault.ads: ~50 lines (Kyber-512 interface)
- pqc_vault.adb: ~100 lines (key initialization)

**Total**: ~1,640 lines (fits 150-hour estimate with verification overhead)

---

## Week-by-Week Breakdown

### Week 2 (Days 1-5)

#### Day 1-2: Startup & Memory Setup
1. **startup.asm** (~150 lines)
   - Load from Bootloader Stage 2 entry point (0x100010)
   - Initialize page tables (create @ 0x200000)
   - Enable 32-bit paging (CR3 → page dir, CR0.PG = 1)
   - Set up GDT for 64-bit (if needed) or extended 32-bit
   - Load IDT base register (0x100400 + handler offsets)
   - Call `Ada_Main()` at 0x100000 (linked address)

2. **ada_kernel.ads** (~200 lines)
   - Package declaration: `package Ada_Kernel`
   - Type definitions:
     ```ada
     type TaskId is (Grid_OS, Analytics_OS, Execution_OS);
     type TaskState is (Ready, Running, Blocked, Completed);
     type MemoryBounds is record
       Start : Address;
       Size  : Size_Type;
       Flags : Bounds_Flags;
     end record;
     ```
   - Subprogram specs with SPARK contracts:
     ```ada
     procedure Initialize_Kernel
       with Global => (In_Out => (Memory_State, Registers)),
            Pre => (Valid_Bootloader_Magic),
            Post => (Auth_Gate = Auth_Enabled);

     procedure Run_Cycle (Task : TaskId)
       with Global => (In_Out => Task_States),
            Pre => (Is_Authorized),
            Post => (Cycle_Count'Old < Cycle_Count);
     ```

3. **ada_kernel.adb** (first 100 lines)
   - `Ada_Main()` entry point
   - Init PQC vault (read Kyber keys from 0x100800)
   - Init task descriptor table (register L2-L4 entry points)
   - Clear exception handlers memory (0x101400)
   - Load IDT with exception handlers
   - Set CR0.PE (protected mode) — should already be set by Bootloader
   - Loop forever: `Run_Event_Loop()`

#### Day 3-4: Exception Handlers
1. **interrupts.ads** (~100 lines)
   - Exception spec: `procedure Exception_Handler (Vector : u8)`
   - Soft IRQ handler specs
   - Handler registration procedure

2. **interrupts.adb** (~250 lines)
   - #6 (Undefined Opcode): Detect illegal instruction → SYS_PANIC (or log + skip)
   - #13 (General Protection Fault): Detect memory violation → SYS_PANIC
   - #0 (Divide by Zero): Log error, panic
   - Soft IRQ 0x10 (syscall): L2-L4 request entry point
   - UART output for all exceptions (port 0x3F8)

#### Day 5: Integration Test
1. Link startup.asm + ada_kernel.adb
2. Test QEMU boot: `qemu-system-x86_64 -gdb tcp::1234 -S omnibus.iso`
3. GDB: Set breakpoint at `Ada_Main`, inspect 0x100000, verify Kyber keys at 0x100800
4. Goal: **Kernel reaches main loop without crashing**

---

### Week 3 (Days 6-10)

#### Day 6-7: Scheduler & Task Management
1. **scheduler.ads** (~80 lines)
   - Type: `type TaskQueue is record ... end`
   - Proc: `procedure Schedule_Next_Task (out : out TaskId)`
   - Proc: `procedure Mark_Task_Ready (T : TaskId)`
   - Proc: `procedure Yield_Task ()`

2. **scheduler.adb** (~200 lines)
   - Simple round-robin: L2 → L3 → L4 → L2 → ...
   - Time-based fairness: give each task 10ms (RDTSC-based)
   - Task completion tracking (track `cycle_count` per task)
   - UART log: `[SCHED] Task L2 → L3 (cycle 1234)`

#### Day 8: Memory Management
1. **memory_mgmt.ads** (~60 lines)
   - Type: `type MemoryBounds is record ...`
   - Proc: `function Is_Access_Valid (Addr : Address, Size : Size_Type; Task : TaskId) return Boolean`
   - Proc: `procedure Initialize_Page_Tables ()`

2. **memory_mgmt.adb** (~150 lines)
   - Setup page directory (4KB @ 0x200000)
   - Setup 16 page tables (16 × 4KB = 64KB @ 0x201000–0x20FFFF)
   - Map kernel: 0x100000 → 0x10FFFF (read-write-execute)
   - Map L2: 0x110000 → 0x12FFFF (read-write)
   - Map L3: 0x150000 → 0x1FFFFF (read-write)
   - Map L4: 0x130000 → 0x14FFFF (read-write)
   - Map I/O: 0x3F8 (UART)
   - Bounds check function: compare address against task segment

#### Day 9: PQC Vault & Cryptography
1. **pqc_vault.ads** (~50 lines)
   - Type: `type KyberPublicKey is array of u32`
   - Proc: `procedure Load_Kyber_Keys ()`
   - Proc: `function Validate_Key_Hash return Boolean`

2. **pqc_vault.adb** (~100 lines)
   - Read Kyber keys from hardcoded 0x100800
   - Initialize cryptographic state
   - (If Zig/Rust wrapper exists: call via FFI)
   - Simple hash validation (SHA256 of key == stored hash)

#### Day 10: Full Integration & QEMU Test
1. Compile all modules: `gnatmake ada_kernel.adb`
2. Link with startup.asm
3. Create bootable image
4. Boot in QEMU:
   ```
   qemu-system-x86_64 -gdb tcp::1234 -S omnibus.iso
   # In GDB:
   target remote localhost:1234
   break Ada_Main
   continue
   # Kernel should run, print UART output, dispatch to L2 Grid OS
   ```
5. **Success criterion**: Kernel loop runs, UART prints cycle messages, no crashes

---

## Build System

### Ada Compiler Setup
```bash
# Install Ada SPARK compiler (GNAT + SPARK tools)
sudo apt-get install gnat-11 spark2014

# Verification script
#!/bin/bash
set -e

echo "[BUILD] Ada Kernel..."
gprbuild -P ada_kernel.gpr -Xmode=verify

echo "[VERIFY] SPARK proofs..."
spark2014 -Pado_kernel.gpr --mode=prove

echo "[BUILD] Startup assembly..."
nasm -f elf64 startup.asm -o startup.o

echo "[LINK] Final kernel..."
ld -T linker.ld startup.o libada_kernel.a -o kernel.bin

echo "[TEST] QEMU..."
qemu-system-x86_64 -gdb tcp::1234 -S omnibus.iso &
sleep 2
# ... GDB test here ...

echo "✅ Build successful!"
```

### Critical Compiler Flags
```ada
-- ada_kernel.gpr (GNAT project file)
with "config";

project Ada_Kernel is
   for Source_Dirs use (".");
   for Object_Dir use "./build";
   for Exec_Dir use "./build";

   package Compiler is
      for Switches ("Ada") use ("-gnat2022", "-gnatwa", "-gnatwe", "-gnatyyM",
                                "-gnaty3abcdefhijklmnoprstux", "-gnatf",
                                "-O2", "-fPIC");
   end Compiler;

   package Binder is
      for Switches ("Ada") use ("-n");  -- No runtime library
   end Binder;
end Ada_Kernel;
```

---

## Dependency Chain (Strict Order)

1. **startup.asm** → compiles standalone
2. **ada_kernel.ads** → interface contract, no dependencies
3. **interrupts.ads** → spec only, depends on ada_kernel.ads
4. **memory_mgmt.ads** → spec only, depends on ada_kernel.ads
5. **scheduler.ads** → spec only, depends on ada_kernel.ads
6. **pqc_vault.ads** → spec only, depends on ada_kernel.ads
7. **pqc_vault.adb** → can compile (pure crypto)
8. **memory_mgmt.adb** → links after memory_mgmt.ads
9. **interrupts.adb** → links after interrupts.ads + ada_kernel.ads
10. **scheduler.adb** → links after scheduler.ads + ada_kernel.ads
11. **ada_kernel.adb** → links everything (main body)
12. **Final link**: startup.o + libada_kernel.a → kernel.bin

---

## Integration Points: Ada ↔ L2-L4

### How L2 Grid OS Boots
1. Ada kernel initializes (0x100010 startup)
2. Ada loads task table: Grid OS @ 0x110000, entry = `init_plugin`
3. Ada calls `run_cycle()` loop
4. **Cycle 0**: Dispatch Grid OS at 0x110000
   - Check auth gate (0x100050 == 0x70)
   - If YES: call `@ptrFromInt(0x110000).init_plugin()`
   - If NO: skip cycle, log warning
5. Grid OS initializes, returns to Ada kernel
6. **Cycle 1**: Dispatch Analytics OS at 0x150000
7. **Cycle 2**: Dispatch Execution OS at 0x130000
8. **Repeat** forever (or until SYS_PANIC)

### UART Debug Output Format
```
[KERN] Ada kernel booting @ 0x100000
[KERN] Auth gate: 0x100050 = 0x?? (not authorized yet)
[KERN] PQC vault loaded @ 0x100800
[KERN] Page tables initialized
[KERN] Task table ready: Grid @ 0x110000, Analytics @ 0x150000, Exec @ 0x130000
[SCHED] ===== CYCLE 0 =====
[SCHED] Dispatching: L2 Grid OS
[GRID] init_plugin() called
[GRID] ... (Grid OS startup messages)
[GRID] Grid OS ready, returning to kernel
[SCHED] L2 completed
[SCHED] ===== CYCLE 1 =====
[SCHED] Dispatching: L3 Analytics OS
[ANALYTICS] init_plugin() called
...
```

---

## Critical Success Factors

1. ✅ **Startup.asm must set CR3 correctly** — paging must work
2. ✅ **Ada must read 0x100050 at cycle start** — auth gate check
3. ✅ **Task entry points must match real addresses** — Grid @ 0x110000, etc.
4. ✅ **Exception handlers must not crash** — all exceptions must be caught
5. ✅ **UART output must work** — or no debug info available
6. ✅ **No floating-point** — Ada uses only fixed-point + integers
7. ✅ **Memory isolation must work** — bounds checks on all L2-L4 accesses

---

## Testing Checklist

### Unit Tests (Week 2-3)
- [ ] startup.asm: Paging works (GDB: inspect CR3 @ kernel entry)
- [ ] ada_kernel.adb: Boots to Ada_Main without crashing
- [ ] interrupts.adb: Exception #13 (GP fault) caught correctly
- [ ] scheduler.adb: Task sequence is L2→L3→L4→L2→... (UART log)
- [ ] memory_mgmt.adb: Bounds check rejects access outside task segment
- [ ] pqc_vault.adb: Kyber keys load from 0x100800

### Integration Tests (Day 10)
- [ ] QEMU boot: Bootloader → Ada kernel completes without hang
- [ ] Auth gate mechanism: Setting 0x100050 = 0x70 authorizes cycles
- [ ] Task dispatch: Each cycle calls correct layer's init_plugin()
- [ ] Cycle counter increments: `cycle_count` increases each round
- [ ] UART output appears in QEMU serial console

### Full System Test (Week 4)
- [ ] Ada + Grid OS + Analytics OS + Execution OS: Full 4-layer QEMU boot
- [ ] Order flow: Execution OS reads orders from Grid OS
- [ ] Fill writeback: Execution OS writes FillResults back to Grid OS

---

## Risks & Mitigation

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Ada compiler not installed | HIGH | Pre-install GNAT + SPARK in CI/CD |
| Paging setup incorrect | HIGH | Verify with GDB: `info registers` shows correct CR3 |
| Task entry points misaligned | MEDIUM | Link Grid OS at 0x110000 exactly (linker script) |
| Auth gate not read correctly | MEDIUM | Test: write 0x70 to 0x100050 in GDB, verify cycle runs |
| Kyber keys not present @ 0x100800 | MEDIUM | Pre-allocate + write test keys in bootstrap |
| Exception handlers cause infinite loop | MEDIUM | Each handler must set flag + return (not continue) |

---

## Success Metrics

- [ ] Kernel binary size: < 64KB (fits 0x100000–0x10FFFF)
- [ ] Build time: < 5 seconds (including SPARK verification)
- [ ] UART latency: < 100µs per message (no blocking)
- [ ] Task dispatch: 3 tasks per cycle, < 1ms total time
- [ ] Memory usage: < 48KB for Ada kernel + stacks + buffers
- [ ] SPARK verification: 100% of safety-critical code provable

---

## References

- **GNAT User's Guide**: https://gcc.gnu.org/onlinedocs/gnat_ugn/
- **SPARK 2014 User's Guide**: https://docs.adacore.com/spark2014-docs/
- **Intel x86-64 Manual**: Volume 3A/3B (paging, interrupts, segmentation)
- **Kyber-512**: NIST FIPS 203 (post-quantum standard)
- **OMNIBUS_MASTER_FINAL_COMPLETE.md**: Project specification
- **STEP1_MEMORY_LAYOUT_FINAL.md**: Detailed address map

---

## Deliverables (End of Week 3)

1. **ada_kernel.ads / ada_kernel.adb** — complete Ada kernel (1000+ lines)
2. **startup.asm** — x86-64 boot assembly (150 lines)
3. **interrupts.ads / interrupts.adb** — exception handlers
4. **scheduler.ads / scheduler.adb** — task scheduler
5. **memory_mgmt.ads / memory_mgmt.adb** — paging + bounds checking
6. **pqc_vault.ads / pqc_vault.adb** — Kyber-512 integration
7. **build.sh / ada_kernel.gpr** — build scripts
8. **kernel.bin** — compiled, linked, bootable Ada kernel
9. **QEMU test log** — verified boot sequence with UART output
10. **SPARK verification report** — formal proof of safety-critical sections

---

**Status**: READY TO IMPLEMENT (Week 2 starts immediately)
**Approval**: None required (Ada kernel is critical blocker, highest priority)
**Next Gate**: End of Day 5 (startup + Ada_Main must boot) | End of Week 3 (full kernel + QEMU test)

