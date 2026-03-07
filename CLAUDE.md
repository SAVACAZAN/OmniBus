# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OmniBus** is a bare-metal, cryptocurrency arbitrage trading system designed to operate with sub-microsecond latency and cryptographic security. Unlike traditional applications, it runs directly on hardware without a conventional operating system kernel, controlling CPU registers and memory directly.

The system is highly experimental and in active development. Current source code is minimal (~227 lines), with extensive architectural documentation in `opcodeOs/OMNIBUS_CODEX.md` (written in Romanian).

## Architecture & Memory Model

OmniBus uses a **4-layer polyglot architecture**:

| Layer | Language | Role | Memory Segment |
|-------|----------|------|-----------------|
| L0 | Assembly | CPU control, timing, interrupts | - |
| L1 | Ada SPARK | Kernel ("Mother OS"), security, validation | 0x100000 |
| L2 | Zig | Analytics, grid trading, consensus | 0x110000–0x200000 |
| L3 | C/Rust | Network drivers, hardware I/O | 0x130000+ |

**Critical Memory Addresses** (from OMNIBUS_CODEX.md):
- `0x100000` – Kernel control & PQC (Post-Quantum Cryptography) vault
- `0x110000` – Grid trading state (buy/sell levels, step sizes)
- `0x130000` – Spot execution queue (signed orders to exchanges)
- `0x150000` – Analytics feed (market prices, consensus)
- `0x200000` – Neuro/AI evolutionary logic
- `0x300000` – Plugin side-loading (arbitrage, stealth, custom modules)

## Project Structure

```
/home/kiss/OmniBus/
├── OmniBus/module/                           # Active modules
│   ├── Multi_Exchange_Arbitrage_Plugin/      # Zig: Detects price spreads
│   ├── solana module/                        # Rust: Solana flash trading
│   ├── egld module +/                        # EGLD blockchain integration
│   └── bank0s/                               # Bank simulation/testing
├── OmniBus v1.0/                             # Archive/legacy
└── opcodeOs/
    └── OMNIBUS_CODEX.md                      # 100-page system specification
```

## Module Development

Modules are self-contained units that run in the plugin segment (0x300000). Key pattern:

```zig
// Module must export these functions
export fn init_plugin() void { ... }           // Called when Ada maps the module
export fn run_cycle() void { ... }             // Main loop invoked by Mother OS
export fn register_* (...) void { ... }        // Dynamic configuration
```

**Module communication**:
- Read prices from `0x150000` (Analytics)
- Write orders to `0x130000` (Spot Queue)
- Request authorization from `0x100050` (Ada's auth gate)
- No malloc/free – use fixed arrays or stack

## Languages & Toolchains

- **Zig**: For modules requiring high performance, deterministic math, no GC
  - Use `comptime` to pre-compute constants
  - Use fixed-point math (scaled integers) for trading prices
  - Check memory bounds with `@ptrFromInt()` carefully
- **Rust**: For algorithms requiring strong safety guarantees (Solana integration)
- **Ada SPARK**: Reserved for kernel/Mother OS (minimal active code)
- **Assembly**: Reserved for CPU-level operations (boot, interrupts)

## Key Design Principles

1. **Determinism**: All nodes must compute identical results. Use fixed-point arithmetic, not floats.
2. **Latency < 1μs**: No allocations, no system calls, no blocking.
3. **Security by default**: Ada validates all requests before execution.
4. **Memory isolation**: Each layer owns a fixed segment; violations trigger `SYS_PANIC`.
5. **No async/threads**: Sequential execution, manual context switching only.

## Testing & Debugging

**Current state**: No formal test framework integrated. Testing is manual via:
- UART telemetry (serial output at 115200 baud to COM1)
- Inspection of memory segments after execution
- Integration with `opcodeOs` bridge (Windows/Linux wrapper application)

**When adding features**:
- Verify memory layout doesn't collide with other segments
- Check authorization bits before touching shared state
- Use UART output (`0x3F8`) to log debug info in early stages

## Documentation References

- **`opcodeOs/OMNIBUS_CODEX.md`**: Full system specification (100 pages, in Romanian)
  - Pages 1–5: Architecture & memory map
  - Pages 6–10: Zig engines & AVX-512 math
  - Pages 11–15: Network drivers & stealth modules
  - Pages 16+: Synchronization, consensus, quantum cryptography

- **Module READMEs**: Each module directory has `read*.md` with plugin-specific details

## Build & Deployment

**Status**: No unified build system yet. Each module is compiled independently:

```bash
# Zig modules (when build system exists)
zig build-lib module/Multi_Exchange_Arbitrage_Plugin/arbitrage_plugin.zig --emit=obj

# Rust modules (when Cargo is integrated)
cd "module/solana module" && cargo build --release
```

**Current workflow**: Source files are prepared; Ada kernel will dynamically load compiled binaries into 0x300000 at runtime.

## Common Commands (TBD)

Once build infrastructure is added:
- `make build` – Compile all modules
- `make test` – Run module unit tests
- `make run-simulator` – Boot OmniBus in QEMU/simulator
- `make clean` – Remove build artifacts

For now, individual Zig/Rust compilation is manual.

## Known Limitations & TODOs

1. **No build system**: Makefile/build.zig needed to orchestrate multi-language builds
2. **No CI/CD**: GitHub Actions or similar for automated testing
3. **Limited source code**: Kernel (Ada), drivers (C), and boot sequence (Assembly) not yet visible
4. **Documentation in Romanian**: OMNIBUS_CODEX.md should be translated or supplemented with English summaries
5. **No formal test suite**: Unit tests for trading logic, price consensus, cryptographic signatures needed
6. **Hardware target undefined**: QEMU? Real CPUs? Real hardware requirements not yet specified

## When You're Stuck

1. **Architecture questions**: Read OMNIBUS_CODEX.md (pages 1–5) for memory layout and layer responsibilities
2. **Module integration**: Look at `Multi_Exchange_Arbitrage_Plugin/arbitrage_plugin.zig` as reference implementation
3. **Memory safety**: Always verify addresses and bounds before dereferencing pointers
4. **Latency problems**: Check for allocations, system calls, or floating-point operations

---

**Last updated**: 2026-03-07
**Project status**: Early development (core architecture defined, minimal implementation)
