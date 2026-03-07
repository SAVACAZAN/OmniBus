# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OmniBus** is a bare-metal, sub-microsecond latency cryptocurrency arbitrage trading system with 7 simultaneous OS layers. Unlike traditional applications, it runs directly on hardware without a conventional OS kernel, controlling CPU registers and memory directly for high-frequency trading across CEX, Solana flash loans, and bank settlement.

**Current status**: Bootloader (Stage 1 + 2) is complete and tested. Protected mode transition verified. Active development on 7 OS layers following the detailed roadmap in `IMPLEMENTATION_PLAN.md` and parallel execution strategy in `PARALLEL_EXECUTION_ROADMAP.md`.

## Architecture: 7 OS Layers + Plugin System

```
Layer 7: Neuro OS (Zig, 0x2D0000)      – Genetic algorithm optimization
Layer 6: BankOS (C, 0x280000)          – SWIFT/ACH settlement
Layer 5: BlockchainOS (Rust/Zig, 0x250000) – Solana flash loans, EGLD staking
Layer 4: Execution OS (C/Asm, 0x130000) – Exchange API + HMAC-SHA256 signing
Layer 3: Analytics OS (Zig, 0x150000)  – Multi-exchange price aggregation
Layer 2: Grid OS (Zig, 0x110000)       – Trading engine + matching
Layer 1: Mother OS (Ada, 0x100000)     – Kernel validation + IPC
L0: Bootloader (Asm, 0x7C00)           – Stage 1 (512B) → Stage 2 (4KB)
```

**Memory Layout**:
```
0x000000–0x00FFFF  Real mode BIOS area
0x010000–0x0FFFFF  Kernel (32-bit protected mode, stack, IDT, GDT)
0x100000–0x10FFFF  Ada Mother OS (64KB) – validation + security
0x110000–0x12FFFF  Grid OS (128KB) – trading state
0x130000–0x14FFFF  Execution OS (128KB) – order queues
0x150000–0x1FFFFF  Analytics OS (256KB) – market data
0x200000–0x20FFFF  Paging tables (64KB)
0x250000–0x27FFFF  BlockchainOS (192KB) – Solana/EGLD integration
0x280000–0x2AFFFF  BankOS (192KB) – SWIFT/ACH messaging
0x2C0000–0x2DFFFF  Stealth OS (128KB) – MEV protection
0x2D0000–0x34FFFF  Neuro OS (512KB) – ML models, genetic algorithm
0x350000+          Plugin segment (1MB+) – DSL bytecode, custom modules
```

## Build System

**Working build targets** (use `make help` for full list):

```bash
make build           # Compile bootloader + kernel, create disk image
make qemu            # Boot in QEMU emulator (Ctrl+A then X to exit)
make qemu-debug      # Boot in QEMU with GDB stub on port 1234
make clean           # Remove build artifacts
make inspect         # Hexdump bootloader for verification
```

**Requirements**: `nasm` (Netwide Assembler), `qemu-system-x86_64`

**Output**: `./build/omnibus.iso` (10MB bootable disk image with all stages)

**Build process**:
1. Assembles `arch/x86_64/boot.asm` → boot sector @ offset 0x0 (512 bytes)
2. Assembles `arch/x86_64/stage2_fixed_final.asm` → Stage 2 @ offset 0x200 (4KB)
3. Assembles `arch/x86_64/kernel_stub.asm` → kernel stub @ offset 0x100000
4. Creates raw disk image with all stages using `dd`

## Project Structure

```
OmniBus/
├── arch/x86_64/                          # Bootloader + boot code
│   ├── boot.asm                          # Stage 1 (BIOS → Stage 2)
│   ├── stage2_fixed_final.asm            # Stage 2 (protected mode entry)
│   └── kernel_stub.asm                   # Kernel placeholder
├── OmniBus/module/                       # Trading modules (future)
│   ├── Multi_Exchange_Arbitrage_Plugin/  # (To be ported from Zig-toolz)
│   ├── solana module/                    # Solana flash trading (Rust)
│   ├── egld module +/                    # EGLD staking integration
│   └── bank0s/                           # Bank settlement reference
├── Makefile                              # Build system
├── README.md                             # High-level overview
├── IMPLEMENTATION_PLAN.md                # 12-step architecture roadmap
├── PARALLEL_EXECUTION_ROADMAP.md         # 8-track parallel dev strategy
├── CLAUDE.md                             # This file
└── opcodeOs/
    └── OMNIBUS_CODEX.md                  # Full spec (100 pages, Romanian)
```

## Development Workflow

### Bootloader (COMPLETE ✅)
- **Stage 1** (512B): Loaded at 0x7C00 by BIOS. Enables A20 line, loads Stage 2.
- **Stage 2** (4KB): Sets up GDT (3 descriptors, 8 bytes each), IDT stub (256 gates), enables CR0.PE, far jumps to protected mode.
- **Key fix**: Far jump address now calculated correctly: `jmp 0x08:(pmode_entry - $$)` creates EA 1C 00 08 00 bytecode.

### Next Work (Weeks 1-3 per PARALLEL_EXECUTION_ROADMAP.md)

1. **Kernel completion**: Protected mode entry point, exception handlers (IRQ 0-31), UART driver
2. **Grid OS**: Port matching engine from `/home/kiss/Zig-toolz-Assembly/backend/src/`
3. **Analytics OS**: Port price aggregator from `/home/kiss/TorNetworkExchange/ExoGridChart/src/`

Each track maintains an integration interface defined in PARALLEL_EXECUTION_ROADMAP.md.

## Testing & Debugging

**Test with QEMU**:
```bash
make qemu              # Watch serial output (println goes to console)
make qemu-debug        # In separate terminal: gdb -ex 'target remote :1234'
```

**Inspection**:
```bash
make inspect           # Hexdump first 20 lines of boot.bin + verify 0x55AA signature
hexdump -C build/boot.bin | head -20
```

**Debug workflow**:
- UART output (port 0x3F8) prints debug messages to QEMU serial console
- GDB breakpoints work at protected mode entry (set breakpoint at `pmode_entry` label)
- Memory inspection: GDB can read arbitrary memory via `x/20i 0x10000` (inspect kernel)

**When something fails**:
1. Check `make qemu` output for boot errors (Stage 1 should print boot message, Stage 2 should print protected mode entry)
2. Use `make inspect` to verify boot.bin ends with 55AA signature
3. Use `make qemu-debug` + GDB to step through protected mode transition
4. Check memory layout collision: grep memory addresses in stage2 against defined segments

## Module Development Pattern

Modules are standalone libraries loaded at runtime into plugin segment (0x300000+). Pattern from PARALLEL_EXECUTION_ROADMAP.md:

**Code structure**:
```zig
// modules/grid_os/grid.zig
const GRID_BASE: usize = 0x110000;
const MAX_ORDERS: usize = 256;

const GridBox = struct {
    lower: f64,
    upper: f64,
    step: f64,
    orders: [MAX_ORDERS]Order,
    count: u32,
};

pub fn calculate_grid(pair: []const u8, vol: f64) void {
    var grid = @as(*GridBox, @ptrFromInt(GRID_BASE));
    // Direct memory write – no allocator, deterministic
}
```

**Constraints**:
- No malloc/free – use fixed-size arrays or stack only
- No floating-point unless necessary (use fixed-point scaled integers for prices)
- No system calls, no context switches, no blocking I/O
- Read from assigned memory segment, write results to shared buffers
- Use `comptime` to pre-calculate constants

**Communication with Mother OS**:
1. Write request to shared buffer (e.g., 0x130000 for Execution OS)
2. Set request flag at 0x100050 (Ada's auth gate)
3. Ada Mother OS validates memory bounds + permissions
4. Ada sets response flag when ready
5. Module reads response

## Key Design Principles

1. **Determinism**: All nodes compute identical results. Fixed-point arithmetic only.
2. **Sub-microsecond latency**: No allocations after init, no system calls, no GC.
3. **Security by default**: Ada kernel validates every cross-segment request.
4. **Memory isolation**: Each layer owns fixed segment; violations trigger `SYS_PANIC`.
5. **Sequential execution**: No threads/async (manual context switching only).

## Languages & Toolchains

- **Assembly (x86-64)**: Bootloader, boot sequence, UART I/O, exception handlers
- **Zig**: Grid OS, Analytics OS, BlockchainOS – high performance, deterministic
  - Use `@ptrFromInt()` carefully; always verify memory bounds
  - Use fixed-size arrays with sentinel values
  - Avoid undefined behavior – use `@intCast()` explicitly
- **Ada SPARK**: Mother OS kernel only – formal verification potential
- **Rust**: Solana integration – memory safety for blockchain signing
- **C**: Execution OS (exchange APIs), BankOS (SWIFT formatting) – performance critical

## Architecture References

- **README.md**: Overview of 7 layers + current boot status
- **IMPLEMENTATION_PLAN.md**: 12-step detailed plan (steps 1-5 are CEX core, 6-9 add blockchain/bank/ML)
- **PARALLEL_EXECUTION_ROADMAP.md**: 8 parallel tracks (A-H) with week-by-week checkpoints + integration points
- **opcodeOs/OMNIBUS_CODEX.md**: Full 100-page specification (Romanian) – memory map, trading math, crypto details

## Known Limitations

1. **Kernel (Ada) not yet visible**: Currently using Assembly stubs; full Ada Mother OS to be implemented
2. **No test framework**: Tests run manually via QEMU serial inspection; formal test suite TBD
3. **Documentation mixed language**: OMNIBUS_CODEX.md is in Romanian; English summaries needed
4. **No CI/CD**: GitHub Actions not yet configured; manual `make` workflow
5. **Module integration**: IPC handshake protocol (PARALLEL_EXECUTION_ROADMAP.md Step 11) not yet implemented

## When You're Stuck

1. **"Boot doesn't work"**: Run `make inspect` to verify 0x55AA signature; check NASM output for assembly errors
2. **"Protected mode hangs"**: Use `make qemu-debug` + GDB; set breakpoint at `pmode_entry`, step through CR0.PE and far jump
3. **"Memory layout collision"**: Check all memory addresses in stage2.asm against defined segments in this file
4. **"Module integration": Read PARALLEL_EXECUTION_ROADMAP.md Step 11 (IPC protocol); verify request/response handshake
5. **"Determinism issues"**: Grep for `float`, `malloc`, system calls in new code; use fixed-point math instead

---

**Last updated**: 2026-03-08
**Project status**: Bootloader complete (Stage 1+2). OS layers in active development per PARALLEL_EXECUTION_ROADMAP.md (8 parallel tracks)
**Next milestone**: Week 3 – Kernel boots to protected mode, Grid OS + Analytics OS stubs running
