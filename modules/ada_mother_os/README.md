# Ada Mother OS Kernel (L1)

## Overview

The Ada Mother OS is the **security kernel and task orchestrator** for all 7 OS layers in OmniBus. It runs at privilege level 0 (ring 0) and controls:

1. **Task Scheduling**: Dispatches L2 (Grid OS), L3 (Analytics OS), L4 (Execution OS) in round-robin
2. **Memory Isolation**: Enforces memory bounds; violations trigger SYS_PANIC
3. **Authorization Gate**: Controls execution via byte at 0x100050 (must be 0x70)
4. **PQC Vault**: Manages Kyber-512 keys for all layers
5. **Exception Handling**: CPU exceptions (divide by zero, page fault, etc.)

## Architecture

### Memory Layout (64KB segment at 0x100000–0x10FFFF)

```
0x100000  Kernel header (16B)
0x100010  Startup code (1KB)
0x100050  ⭐ AUTH GATE (1B) - Control byte
0x100400  Task descriptor table (4KB)
0x101400  Exception handlers (6KB)
0x102C00  Scheduler state (2KB)
0x103200  Memory management (3KB)
0x100800  🔐 PQC vault - Kyber-512 (2KB)
0x100C00  Governance state (2KB)
Rest      Stack + scratch (48KB)
```

### Critical Constants

- **AUTH_GATE** (0x100050): Write 0x70 here to authorize execution
- **PQC_VAULT** (0x100800): Kyber-512 post-quantum crypto keys
- **TASK_TABLE** (0x100400): Task descriptors for L2–L4

## File Structure

```
ada_mother_os/
├── startup.asm           # x86-64 boot assembly (150 lines)
│                         # - Sets up paging
│                         # - Initializes GDT/IDT
│                         # - Jumps to Ada_Main
│
├── ada_kernel.ads        # Main Ada interface contract (200 lines)
├── ada_kernel.adb        # Main Ada implementation (300 lines)
│
├── scheduler.ads         # Task scheduling interface (80 lines)
├── scheduler.adb         # Scheduler implementation (200 lines)
│
├── memory_mgmt.ads       # Memory isolation interface (60 lines)
├── memory_mgmt.adb       # Memory management (150 lines)
│
├── interrupts.ads        # Exception handlers interface (100 lines)
├── interrupts.adb        # Exception handlers (250 lines)
│
├── pqc_vault.ads         # PQC key management interface (50 lines)
├── pqc_vault.adb         # Kyber-512 implementation (100 lines)
│
├── ada_kernel.gpr        # GNAT project file (build config)
├── build.sh              # Build script
└── README.md             # This file
```

**Total**: ~1,640 lines of code

## Building

### Prerequisites

```bash
sudo apt-get install gnat-11 nasm
```

### Build Commands

```bash
# Full build
cd modules/ada_mother_os
./build.sh

# Or manual compilation
gprbuild -P ada_kernel.gpr
nasm -f elf64 startup.asm -o build/startup.o
ld -T linker.ld build/startup.o build/libada_kernel.a -o build/kernel.bin
```

### Output

- `build/kernel.bin` — Compiled Ada kernel (< 64KB)
- `build/libada_kernel.a` — Ada static library
- `build/startup.o` — Assembled startup code

## Testing

### QEMU Boot Test

```bash
# Terminal 1: Boot kernel with GDB server
qemu-system-x86_64 -gdb tcp::1234 -S omnibus.iso

# Terminal 2: Connect with GDB
gdb
(gdb) target remote localhost:1234
(gdb) file build/kernel.bin
(gdb) break Ada_Main
(gdb) continue

# Set auth gate (enable execution)
(gdb) set {char}0x100050 = 0x70
(gdb) continue

# Inspect kernel state
(gdb) x/16x 0x100000       # Kernel header
(gdb) info registers       # CPU registers, especially CR0, CR3
(gdb) x/128i 0x100010      # Startup code disassembly
```

### Expected UART Output

```
[KERN] Ada kernel booting @ 0x100000
[KERN] PQC vault loaded @ 0x100800
[KERN] Task table initialized
[KERN] Exception handlers ready
[KERN] Scheduler ready
[KERN] Auth gate DISABLED - waiting for auth
[SCHED] ===== CYCLE 0 =====
[SCHED] Dispatching L2 Grid OS
[GRID] init_plugin() called
...
```

## Integration with Bootloader

The bootloader (Stages 1 & 2) must:

1. ✅ Load the kernel to 0x100000
2. ✅ Enable protected mode (CR0.PE = 1)
3. ✅ Jump to 0x100010 (startup.asm entry point)

The Ada kernel then:

1. Sets up paging (CR3, page tables at 0x200000)
2. Initializes GDT and IDT
3. Calls Ada_Main()
4. Enters event loop (dispatches L2–L4 tasks)

## Key Design Principles

### 1. **Zero System Calls**
No malloc(), free(), syscall(), or OS kernel dependency. Pure bare-metal.

### 2. **Fixed-Point Arithmetic**
All prices/quantities are integers (u64). No floating-point.

### 3. **Memory Isolation**
Each task (L2–L4) has a fixed memory segment. Crossing boundaries = SYS_PANIC.

### 4. **Determinism**
All nodes compute identical results. No random state unless seeded.

### 5. **Sub-Microsecond Latency**
No blocking, no context switches (sequential dispatch), no GC.

## Task Dispatch Flow

```
Ada Kernel Event Loop:
  ├─ Cycle 0: Dispatch L2 Grid OS (0x110000)
  ├─ Cycle 1: Dispatch L3 Analytics OS (0x150000)
  ├─ Cycle 2: Dispatch L4 Execution OS (0x130000)
  └─ Repeat forever...

Each Cycle:
  1. Check auth gate (0x100050 == 0x70?)
  2. If authorized:
     - Dispatch current task
     - Task runs until completion
     - Increment cycle counter
     - Move to next task
  3. If not authorized:
     - Log warning
     - Sleep (yield CPU)
```

## API for Task Layers (L2–L4)

Each task layer (Grid OS, Analytics OS, Execution OS) must implement:

```ada
-- In their respective modules

export procedure init_plugin() is
  -- Called once per kernel boot
  -- Initialize task-specific state
begin
  ...
end init_plugin;

export procedure run_cycle() is
  -- Called every kernel cycle
  -- Perform task work (e.g., read input ring, compute, write output)
begin
  ...
end run_cycle;
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Kernel hangs at boot** | Check UART output; set auth gate in GDB: `set {char}0x100050 = 0x70` |
| **Page fault immediately** | Verify startup.asm paging setup; check CR3 in GDB |
| **Linker errors** | Ensure GNAT + ld are in PATH; check ada_kernel.gpr |
| **Compilation fails** | Run `sudo apt-get install gnat-11 nasm` |
| **Can't connect GDB** | Ensure QEMU is listening: `qemu-system-x86_64 -gdb tcp::1234 -S ...` |

## Performance Targets

- **Boot time**: < 1 second (from Stage 1 to event loop)
- **Task dispatch latency**: < 1ms per cycle (3 tasks)
- **Memory usage**: < 48KB for kernel + stacks
- **UART output**: < 100µs per message (non-blocking)

## Future Work

1. **SPARK Formal Verification**: Prove memory safety and determinism
2. **Complete Kyber-512 Implementation**: Full key encapsulation
3. **Advanced Scheduling**: Priority levels, time-based fairness
4. **Performance Monitoring**: Track cycle times, error rates
5. **Hot-reload**: Update task code without reboot

## References

- **Intel x86-64 Manual**: https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-manual-325462.pdf
- **GNAT User's Guide**: https://gcc.gnu.org/onlinedocs/gnat_ugn/
- **SPARK 2014**: https://docs.adacore.com/spark2014-docs/
- **Kyber-512 Spec**: NIST FIPS 203 (Post-Quantum Cryptography)

## License

Part of OmniBus project. See main README.md.

---

**Status**: IMPLEMENTATION IN PROGRESS (Week 2 of 14-week project)
**Last Updated**: 2026-03-09
**Maintained By**: Claude Code + SAVACAZAN
