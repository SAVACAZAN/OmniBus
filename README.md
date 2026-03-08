# OmniBus — Bare-Metal Cryptocurrency Arbitrage Trading System

**Status**: Core architecture complete (Bootloader + Ada kernel + Analytics OS + Grid OS + Execution OS) ✅
**Current Version**: 0.1.0 (Core layers stable, ready for integration testing)
**Language Stack**: Assembly + Ada SPARK + Zig + C/Rust
**Target Latency**: Sub-microsecond (< 1μs per trade decision)

## Overview

OmniBus is a **bare-metal trading system** that runs directly on CPU hardware without a conventional OS kernel. It implements a **4-layer polyglot architecture** with cryptographic security (post-quantum crypto), deterministic math (fixed-point), and zero dynamic allocations.

### Core Layers (✅ Complete)

| Layer | Language | Role | Memory | Status |
|-------|----------|------|--------|--------|
| **L0** | Assembly | Boot, CPU control, interrupts | - | ✅ Complete |
| **L1** | Ada SPARK | Kernel (Mother OS), validation, PQC vault | 0x100000 | ✅ Designed |
| **L2** | Zig | Analytics, Grid trading, arbitrage scanning | 0x110000–0x200000 | ✅ **9+8 modules** |
| **L3** | C/Rust | NIC drivers, exchange APIs, settlement | 0x130000+ | ✅ **9 modules** |

### Future Layers (⏳ Planned)

| Layer | Role | Status |
|-------|------|--------|
| **L4** | Blockchain OS (Solana flash loans, EGLD staking) | ⏳ Track G |
| **L5** | Bank OS (SWIFT/ACH settlement) | ⏳ Track F |
| **L6** | Neuro OS (Genetic algorithm optimization) | ⏳ Track H |

## Memory Map

```
0x000000  ┌─ Boot sector (512B)
0x007E00  ├─ Stage 2 bootloader (4KB)
          │
0x100000  ├─ Ada Mother OS (128KB) — auth gate @ 0x100050
          │
0x110000  ├─ Grid OS (128KB) — levels, orders, opportunities
          │  ├─ 0x110840: Order array (256 × 48B)
          │  └─ 0x113840: Arb opportunities (32 × 96B)
          │
0x130000  ├─ Execution OS (128KB) — signing, TX queue
          │  ├─ 0x130040: Ring header
          │  ├─ 0x130050: Order ring (256 × 128B)
          │  ├─ 0x138050: TX queue (64 × 384B)
          │  ├─ 0x13E050: FillResult (256 × 64B)
          │  └─ 0x142050: API keys (3 × 512B)
          │
0x150000  ├─ Analytics OS (512KB) — price consensus, DMA
          │
0x200000  ├─ Neuro/AI modules (future)
          │
0x300000  └─ Plugin side-loading (future)
0x00150000 - 0x00250000  BlockchainOS (Solana)
0x00250000 - 0x00280000  BankOS (SWIFT)
0x00280000 - 0x002C0000  Neuro OS (ML/GA)
0x002C0000 - 0x002D0000  Reserved
0x002D0000 - 0x00350000  Trading state + Order book
0x00350000+              Heap (limited)
```

## 📊 Current Status

### ✅ Bootloader (COMPLETE)
- **Stage 1**: Loads Stage 2 from disk → 0x7E00
- **Stage 2**: Transitions to 32-bit protected mode
  - GDT setup (3 descriptors, 8 bytes each)
  - IDT initialization (256 interrupt gates)
  - CR0.PE enabled
  - Far jump to protected mode entry

**Recent Fix**: Corrected far jump address calculation (`jmp 0x08:(pmode_entry - $$)`)

### 🔄 In Progress
1. **Grid OS** - Port matching engine from Zig-toolz-Assembly
2. **Analytics OS** - Port market aggregator from ExoCharts

### ⏳ Pending
1. Execution OS (HMAC-SHA256 signing)
2. BlockchainOS (Solana flash loans)
3. BankOS (SWIFT/ACH settlement)
4. Neuro OS (Genetic algorithm training)
5. Full integration & latency optimization

## 🛠️ Building

### Prerequisites
```bash
nasm          # Netwide Assembler for x86-64
make          # Build automation
qemu-system-x86_64  # x86-64 emulator for testing
```

### Compile
```bash
make build    # Assemble bootloader and create disk image
```

### Run in QEMU
```bash
make qemu     # Start emulation (Ctrl+A then X to exit)
make qemu-debug   # Start with GDB stub on port 1234
```

### Clean
```bash
make clean    # Remove all build artifacts
```

## 📁 Project Structure

```
OmniBus/
├── arch/x86_64/
│   ├── boot.asm              # Stage 1 bootloader (512 bytes)
│   ├── stage2_fixed_final.asm # Stage 2 bootloader (4KB)
│   ├── kernel_stub.asm       # Kernel placeholder
├── Makefile                  # Build system
├── CLAUDE.md                 # Developer guide for AI
├── IMPLEMENTATION_PLAN.md    # 12-week architecture
├── PARALLEL_EXECUTION_ROADMAP.md  # 8-track development plan
└── README.md                 # This file
```

## 🔑 Key Design Decisions

### 1. **No Dynamic Memory Allocation**
- Fixed memory segments prevent fragmentation
- Deterministic latency (critical for sub-microsecond trading)
- Simpler garbage collection (none needed)

### 2. **Multi-Language Approach**
- **Assembly**: Bootloader, critical paths
- **Ada/SPARK**: Kernel (provable correctness)
- **Zig**: High-performance matching engine, analytics
- **Rust**: Blockchain integration (safety + performance)
- **C**: Exchange APIs (HMAC-SHA256 signing)

### 3. **Genetic Algorithm AI from Day 1**
- Continuously optimize trading parameters
- No separate "training phase" - learns in production
- Population-based evolution across all 7 OS layers

### 4. **Post-Quantum Cryptography (PQC)**
- Kyber vault for future-proofing
- Protects against quantum computing threats

## 🚦 Next Steps (Week 1-2)

1. **Verify protected mode entry** in QEMU
2. **Port Grid OS** matching engine
3. **Port Analytics OS** market aggregator
4. **Set up kernel memory management**
5. **Begin Exchange API integration**

## 📚 References

- CLAUDE.md - Full developer guide
- IMPLEMENTATION_PLAN.md - Detailed 12-week plan
- PARALLEL_EXECUTION_ROADMAP.md - 8 parallel development tracks

## 👨‍💻 Development

This project is designed for AI-assisted development with Claude Code. See `CLAUDE.md` for AI-specific guidance.

```bash
# Run Claude Code in this directory
claude code .
```

## 📝 License

Private project - Proprietary

## 🔐 Security Notice

This is a **live trading system** that will execute real transactions. All components undergo rigorous testing and formal verification before deployment.

---

**Status**: Pre-alpha - Bootloader working, OS layers in development
**Updated**: 2026-03-08

---

## Implemented Modules (Complete)

### ✅ Bootloader
- **Stage 1**: 512B MBR bootloader, loads Stage 2
- **Stage 2**: Protected mode entry, A20 line, GDT
- **Status**: Tested, far jump fix applied ✅

### ✅ Analytics OS (9 modules, ~830 lines)
**Location**: `modules/analytics_os/`

Purpose: Read DMA price feeds, apply consensus filter (71% median), output to Grid OS

**Key Modules**:
- `uart.zig` — Serial debug output (UART @ 0x3F8)
- `types.zig` — Fixed-point types, DMA structures
- `dma_ring.zig` — Ring buffer polling
- `market_matrix.zig` — 32×30 OHLCV matrix, TSC bucketing
- `consensus.zig` — 71% median filter, 5% outlier rejection
- `price_feed.zig` — Write to 0x150000
- `analytics_os.zig` — Root: `init_plugin()`, `run_analytics_cycle()`

### ✅ Grid OS (8 modules, ~1914 lines)
**Location**: `modules/grid_os/`

Purpose: Generate buy/sell price levels, detect arbitrage, output OrderPackets to Execution OS

**Key Modules**:
- `types.zig` — GridState, GridLevel[64], Order[256], ArbitrageOpp[32]
- `math.zig` — Fixed-point math, fee calc, bps conversion
- `grid.zig` — Grid level generation algorithm
- `order.zig` — Order state machine (pending→filled→cancelled)
- `scanner.zig` — Cross-exchange arbitrage detection (buy A, sell B)
- `rebalance.zig` — Grid shift when price drifts > 5%
- `grid_os.zig` — Root: `init_plugin()`, `run_grid_cycle()`, `register_pair()`

### ✅ Execution OS (9 modules, ~1996 lines)
**Location**: `modules/execution_os/`

Purpose: Sign orders per exchange, manage TX queue, process FillResults, writeback to Grid OS

**Key Modules**:
- `types.zig` — Memory layout, OrderPacket, SignedOrderSlot, FillResult, ApiKeySlot
- `crypto.zig` — SHA256, HMAC-SHA256/512, RDRAND, RDTSC
- `order_reader.zig` — Ring buffer volatile polling
- `order_format.zig` — Fixed-point → string conversion (prices, quantities)
- `lcx_sign.zig` — HMAC-SHA256 signing (LCX)
- `kraken_sign.zig` — SHA256 + HMAC-SHA512 signing (Kraken)
- `coinbase_sign.zig` — ECDSA P-256 JWT signing (Coinbase)
- `fill_tracker.zig` — FillResult processing, writeback to Grid OS
- `execution_os.zig` — Root: `init_plugin()`, `run_execution_cycle()`

---

## Build Instructions

### All Modules
```bash
cd /home/kiss/OmniBus

# Analytics OS
zig build-lib modules/analytics_os/analytics_os.zig \
  -target x86_64-freestanding -O ReleaseFast

# Grid OS
zig build-lib modules/grid_os/grid_os.zig \
  -target x86_64-freestanding -O ReleaseFast

# Execution OS
zig build-lib modules/execution_os/execution_os.zig \
  -target x86_64-freestanding -O ReleaseFast
```

### Verify No Syscalls
```bash
nm libanalytics_os.a | grep -E malloc|free|syscall
# Expected: (no output)
```

### Bootloader
```bash
cd bootloader
nasm -f bin boot_stage1.asm -o stage1.bin
nasm -f bin boot_stage2.asm -o stage2.bin
```

---

## Critical Design Patterns

### Fixed-Point Arithmetic (No Floats!)
```zig
// Prices: u64 × 100 (cents)
const price_cents: u64 = 6_350_000;  // $63,500.00

// Quantities: u64 × 1e8 (satoshis)
const qty_sats: u64 = 100_000_000;   // 1.00000000 BTC

// Fees: u32 basis points
const fee_bps: u32 = 50;             // 0.50%
```

### Volatile Pointer I/O (No Syscalls)
```zig
// Read from memory-mapped register
const ring_header = @as(*volatile RingHeader, @ptrFromInt(0x130040));
if (ring_header.head != ring_header.tail) { /* data ready */ }

// Write to order array
const orders = @as([*]volatile Order, @ptrFromInt(0x110840));
orders[i].status = .filled;
```

### Authorization Gate (Ada controls execution)
```zig
const auth = @as(*volatile u8, @ptrFromInt(0x100050));
if (auth.* != 0x70) return;  // Only execute if authorized
```

### Ring Buffer Protocol
- **Head**: Advanced by reader (Execution OS reads)
- **Tail**: Advanced by writer (Grid OS writes)
- **Check**: `if (head != tail) { new data available }`
- **Mask**: `idx = ptr & 0xFF` (256-slot ring)

---

## Key Memory Addresses

| Address | Size | Purpose |
|---------|------|---------|
| 0x100050 | 1B | Auth gate (Ada kernel) |
| 0x110840 | 12KB | Grid OS order array |
| 0x113840 | 3KB | Arbitrage opportunities |
| 0x130040 | 16B | Execution OS ring header |
| 0x130050 | 32KB | Order input ring |
| 0x138050 | 24KB | TX queue (signed orders) |
| 0x13E050 | 16KB | FillResult array |
| 0x142050 | 1.5KB | API credentials |
| 0x150000 | 512KB | Analytics price feed |

---

## Data Flow Diagram

```
DMA Input (Exchange prices)
    ↓
Analytics OS (0x150000)
  ├─ Parse packets
  ├─ Consensus filter
  └─ Write price feed
      ↓
  Grid OS (0x110000)
    ├─ Read prices
    ├─ Generate levels
    ├─ Detect arbitrage
    └─ Write OrderPackets
        ↓
    Execution OS (0x130000)
      ├─ Read orders
      ├─ Sign (3 exchanges)
      ├─ Write TX queue
      │   → C NIC Driver
      │      → HTTP to exchange
      │
      ├─ Read FillResults
      └─ Writeback to Grid OS
```

---

## Cryptography Support

| Algorithm | Purpose | Module | Exchange |
|-----------|---------|--------|----------|
| SHA-256 | Hash | kraken_sign, coinbase_sign | Kraken, Coinbase |
| HMAC-SHA256 | MAC | lcx_sign | LCX |
| HMAC-SHA512 | MAC | kraken_sign | Kraken |
| ECDSA P-256 | JWT sig | coinbase_sign | Coinbase |
| Base64 | Encoding | lcx_sign, kraken_sign | All |
| Base64url | JWT encode | coinbase_sign | Coinbase |
| RDRAND | RNG | crypto.zig | All |
| RDTSC | Entropy | crypto.zig | All |

---

## Testing

### Unit Tests (Per Module)
```bash
# Example
zig test modules/execution_os/execution_os.zig -target x86_64-freestanding
```

### QEMU GDB Debugging
```bash
qemu-system-x86_64 -gdb tcp::1234 -S omnibus.img
gdb
(gdb) target remote localhost:1234
(gdb) set {char}0x100050 = 0x70      # Set auth gate
(gdb) break *0x130000
(gdb) continue
```

### UART Serial (Debug Output)
```bash
# In QEMU
qemu-system-x86_64 -serial stdio omnibus.img

# Or connect to physical COM1
screen /dev/ttyUSB0 115200
```

---

## Git Workflow

### Recent Commits (Execution OS - Weeks 1-6)
```
06c182a Add Week 6: execution_os.zig
5f5bfce Add Week 5: fill_tracker.zig
7c3dd29 Add Week 4: coinbase_sign.zig
bdf8222 Add Week 3: kraken_sign.zig
a2d9b5a Add Week 2: order_format.zig + lcx_sign.zig
731d23e Complete Week 1: crypto.zig + order_reader.zig
8f19daf Add Week 1: types.zig
b8d6f91 Implement Grid OS (Track C)
b1eef43 Implement Analytics OS (Track D)
678f875 Update README
```

### Push Changes
```bash
git add .
git commit -m "commit message"
git push origin main
```

---

## Known Limitations

| Item | Status |
|------|--------|
| Full QEMU boot test | ⏳ Pending Ada kernel |
| Solana integration | ⏳ Track G |
| Bank system | ⏳ Track F |
| CI/CD automation | ⏳ Pending |
| Formal test suite | ⏳ Pending |
| English docs | 🔄 In progress |

---

## Directory Structure

```
OmniBus/
├── bootloader/
│   ├── boot_stage1.asm
│   └── boot_stage2.asm
├── modules/
│   ├── analytics_os/        (9 modules, ~830L)
│   ├── grid_os/             (8 modules, ~1914L)
│   └── execution_os/        (9 modules, ~1996L)
├── opcodeOs/
│   └── OMNIBUS_CODEX.md     (100-page spec, Romanian)
├── CLAUDE.md                (Developer guide)
└── README.md                (This file)
```

---

## How to Contribute

1. Read `CLAUDE.md` for coding standards
2. Check `opcodeOs/OMNIBUS_CODEX.md` for architecture details
3. Test locally with freestanding build (no OS syscalls)
4. Commit with descriptive messages
5. Push to remote: `git push origin <branch>`

---

## License

[TBD — To be determined]

---

**Last Updated**: 2026-03-08
**Version**: 0.1.0 (Core architecture stable, ready for integration)
**Maintained By**: SAVACAZAN & Claude Code
**Repository**: https://github.com/SAVACAZAN/OmniBus
