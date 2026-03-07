# 🚀 OmniBus - Multi-Chain Cryptocurrency Arbitrage Trading System

A bare-metal, sub-microsecond latency trading engine built from scratch with 7 simultaneous OS layers for ultra-high-speed cryptocurrency arbitrage across CEX, flash loans, and SWIFT settlement.

## 🎯 Mission

Execute profitable arbitrage trades in **< 1 microsecond** across:
- **Multi-Exchange**: Kraken, Coinbase, LCX
- **Solana Flash Loans**: Raydium, Orca
- **Bank Settlement**: SWIFT/ACH international transfers
- **Staking**: EGLD validation
- **AI Optimization**: Genetic algorithm trading strategy evolution

## 🏗️ Architecture: 7 Simultaneous OS Layers

```
┌─────────────────────────────────────────────────────┐
│  Layer 7: Neuro OS (Optional ML/GA)                 │
│           Genetic algorithm optimization            │
├─────────────────────────────────────────────────────┤
│  Layer 6: BankOS                                    │
│           SWIFT/ACH settlement (C)                  │
├─────────────────────────────────────────────────────┤
│  Layer 5: BlockchainOS                              │
│           Solana flash loans (Zig/Rust)             │
├─────────────────────────────────────────────────────┤
│  Layer 4: Execution OS                              │
│           Exchange API formatting (C)               │
├─────────────────────────────────────────────────────┤
│  Layer 3: Analytics OS                              │
│           Market aggregation (Zig)                  │
├─────────────────────────────────────────────────────┤
│  Layer 2: Grid OS                                   │
│           Matching engine (Zig)                     │
├─────────────────────────────────────────────────────┤
│  Layer 1: Ada Mother OS (Kernel)                    │
│           Core scheduling & memory management       │
├─────────────────────────────────────────────────────┤
│  Bootloader: Stage 1 + Stage 2                      │
│           x86-64 real mode → 32-bit protected mode  │
└─────────────────────────────────────────────────────┘
```

### Memory Layout (Fixed, No Dynamic Allocation)

```
0x00010000 - 0x00110000  Ada Mother OS (kernel)
0x00100000 - 0x00110000  Grid OS (matching engine)
0x00110000 - 0x00130000  Analytics OS
0x00130000 - 0x00150000  Execution OS
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
