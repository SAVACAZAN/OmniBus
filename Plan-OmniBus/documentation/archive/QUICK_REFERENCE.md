# OmniBus Quick Reference for AI Agents

**Purpose**: Fast reference for understanding OmniBus architecture, memory layout, hashes, and key patterns.
**Updated**: 2026-03-08
**For**: Next Claude Code sessions or other AI agents

---

## 🎯 System at a Glance

**What is OmniBus**: Bare-metal cryptocurrency arbitrage trading system (no OS kernel)
**Built with**: Assembly (bootloader) + Ada (kernel) + Zig (trading logic) + C/Rust (drivers)
**Key feature**: Sub-microsecond latency, fixed-point math (no floats), zero allocations
**Status**: Core layers complete (Bootloader ✅ + Analytics ✅ + Grid ✅ + Execution ✅)

---

## 📍 Critical Memory Addresses (Learn These!)

```
0x000000  Boot sector
0x007E00  Stage 2 bootloader (4KB)
0x100000  Ada Mother OS (128KB) — KERNEL
0x100050  🔑 AUTH GATE (must == 0x70 to execute)
0x110000  Grid OS (128KB) — Grid trading
0x110840  Order array (256 × 48B)
0x113840  Arb opportunities (32 × 96B)
0x130000  Execution OS (128KB) — Signing & TX
0x130040  Ring header (head/tail)
0x130050  Input ring (256 × 128B)
0x138050  TX queue (64 × 384B)
0x13E050  FillResult array (256 × 64B)
0x142050  API keys (3 × 512B)
0x150000  Analytics OS (512KB) — Price feed
```

**Magic**: Auth gate at **0x100050** must be set to **0x70** before any cycle runs!

---

## 🔗 Git Commits (Latest First)

### Execution OS Completion (Weeks 1-6)
```
06c182a - Week 6: execution_os.zig (root, orchestration)
5f5bfce - Week 5: fill_tracker.zig (FillResult writeback)
7c3dd29 - Week 4: coinbase_sign.zig (ECDSA P-256 JWT)
bdf8222 - Week 3: kraken_sign.zig (SHA256+HMAC-SHA512)
a2d9b5a - Week 2: order_format.zig + lcx_sign.zig
731d23e - Week 1 (part 2): crypto.zig + order_reader.zig
8f19daf - Week 1 (part 1): types.zig
```

### Earlier Work
```
b8d6f91 - Implement Grid OS (Track C, 8 modules)
b1eef43 - Implement Analytics OS (Track D, 9 modules)
678f875 - Update README
e1318b3 - Fix Stage 2 bootloader (far jump)
935018c - Initial commit: Stage 1+2 bootloader
```

### Remote
```
https://github.com/SAVACAZAN/OmniBus.git (main branch)
```

---

## 📊 Module Summary (What's Done)

| Module | Files | Lines | Status | Key Purpose |
|--------|-------|-------|--------|-------------|
| **Bootloader** | 2 | ~400 | ✅ Done | Real mode → Protected mode |
| **Analytics OS** | 9 | ~830 | ✅ Done | Price consensus (71% median) |
| **Grid OS** | 8 | ~1914 | ✅ Done | Buy/sell levels + arbitrage |
| **Execution OS** | 9 | ~1996 | ✅ Done | Sign orders per exchange |
| **Ada Kernel** | ? | ? | 🔄 Design | Auth, validation, PQC vault |
| **Blockchain OS** | ? | ? | ⏳ Todo | Solana flash loans (Track G) |
| **Bank OS** | ? | ? | ⏳ Todo | SWIFT settlement (Track F) |

**Total Implemented**: 26 modules, ~5,140 lines ✅

---

## 🔐 Fixed-Point Constants (Always Use!)

```zig
// Prices: u64 × 100
const PRICE_SCALE = 100;
// Example: 6_350_000 cents = $63,500.00

// Quantities: u64 × 1e8
const QTY_SCALE = 100_000_000;
// Example: 100_000_000 sats = 1.00000000 BTC

// Fees: u32 basis points
const FEE_SCALE = 10_000;  // 100 bps = 1%
// Example: 50 bps = 0.50% = value 50
```

---

## 🎯 Memory Layout Patterns

### Ring Buffer (Head/Tail Poll)
```zig
const header = @as(*volatile RingHeader, @ptrFromInt(0x130040));
if (header.head != header.tail) {
    const idx = header.head & 0xFF;  // 256-slot mask
    const data = array[idx];
    header.head = (header.head + 1) & 0xFFFFFFFF;  // Advance
}
```

### Volatile Memory Access
```zig
// Read from hardware
const value = @as(*volatile u8, @ptrFromInt(0x100050)).*;

// Write to hardware
const reg = @as(*volatile u32, @ptrFromInt(0x130040));
reg.* = new_value;
```

### Exchange Data Structures

**OrderPacket** (128B, from Grid → Execution)
```
opcode:u8=0x70
_pad0:u8
exchange_id:u16 (0=Kraken, 1=Coinbase, 2=LCX)
_pad1:u32
pair_id:u16 (0=BTC_USD, 1=ETH_USD, 2=XRP_USD)
side:u8 (0=buy, 1=sell)
_pad2:u8
quantity_sats:u64
price_cents:u64
signature_pqc:u8[64]
```

**SignedOrderSlot** (384B, from Execution → C NIC)
```
exchange_id:u8
pair_id:u8
flags:u8 (0x01=ready, 0x02=sent, 0x04=error)
_pad:u8
payload_len:u16
_pad2:u16
payload:u8[376] ← signed HTTP body
```

**FillResult** (64B, from exchange → Execution)
```
order_id:u32
pair_id:u16
exchange_id:u8
status:u8 (0=pending, 1=filled, 2=partial, 3=rejected)
filled_sats:u64
price_cents:u64
tsc:u64
_reserved:u8[36]
```

---

## 🔌 Exchange-Specific Signing

| Exchange | Algorithm | Input | Output |
|----------|-----------|-------|--------|
| **Kraken** | SHA256 → HMAC-SHA512 → Base64 | Nonce + URL-encoded body | API-Sign header |
| **Coinbase** | ECDSA P-256 JWT | JSON + timestamp | Bearer token |
| **LCX** | HMAC-SHA256 → Base64 | JSON body | x-access-sign header |

### Kraken Flow
```
nonce (TSC as decimal)
+ post_body (URL-encoded: "nonce=X&pair=XXBTZUSD&...")
→ SHA256 hash
+ path "/0/private/AddOrder"
→ HMAC-SHA512 with API secret
→ Base64 encode
→ API-Sign header
```

### Coinbase Flow
```
header JSON: {alg:ES256, typ:JWT, kid:key, nonce:hex}
+ payload JSON: {sub:key, iss:cdp, nbf:ts, exp:ts+120, uri:POST...}
→ base64url encode both
→ sign header.payload with ECDSA P-256
→ jwt = header.payload.signature
→ Authorization: Bearer jwt
```

### LCX Flow
```
body JSON: {symbol:BTC/EUR, type:limit, side:buy, ...}
→ request = "POST" + "/api/orders" + body
→ HMAC-SHA256(request, secret)
→ Base64 encode
→ x-access-sign header
```

---

## 🏗️ Data Flow (High-Level)

```
Exchange DMA Input
    ↓
Analytics OS (0x150000)
  - Parse price packets
  - 71% median consensus filter
  - Output: price feed @ 0x150000
    ↓
Grid OS (0x110000)
  - Read prices from 0x150000
  - Generate buy/sell levels
  - Detect arbitrage (buy exchange A, sell B)
  - Output: OrderPackets @ 0x130050
    ↓
Execution OS (0x130000)
  - Read orders from 0x130050 (ring buffer)
  - Sign per exchange (Kraken/Coinbase/LCX)
  - Write signed payload → 0x138050 (TX queue)
  - Read fills from 0x13E050
  - Writeback → 0x110840 (Grid order status)
    ↓
C NIC Driver
  - HTTP POST to exchange
  - Receive fill confirmation
  - Write FillResult @ 0x13E050
```

---

## 🔐 Cryptographic Primitives

All in `modules/execution_os/crypto.zig`:

```zig
pub fn sha256(out: *[32]u8, message: []const u8) void
pub fn hmacSha256(out: *[32]u8, message: []const u8, key: []const u8) void
pub fn hmacSha512(out: *[64]u8, message: []const u8, key: []const u8) void
pub fn getRandom64() u64  // RDRAND instruction
pub fn getTscEntropy() u64  // RDTSC instruction
```

**Note**: All crypto uses `std.crypto.*` which is freestanding-safe (no syscalls).

---

## 📁 File Structure (Know This!)

```
modules/
├── analytics_os/
│   ├── types.zig           ← Structures, memory layout
│   ├── dma_ring.zig        ← Ring buffer polling pattern
│   ├── consensus.zig       ← 71% median filter
│   ├── market_matrix.zig   ← 32×30 OHLCV grid
│   └── analytics_os.zig    ← Root: init_plugin(), run_cycle()
│
├── grid_os/
│   ├── types.zig           ← GridState, Order, Level structs
│   ├── math.zig            ← Fixed-point arithmetic
│   ├── grid.zig            ← Level generation
│   ├── order.zig           ← State machine
│   ├── scanner.zig         ← Arbitrage detection
│   └── grid_os.zig         ← Root: init_plugin(), run_cycle()
│
└── execution_os/
    ├── types.zig           ← OrderPacket, SignedOrderSlot, FillResult
    ├── crypto.zig          ← SHA256, HMAC, RDRAND
    ├── order_reader.zig    ← Ring polling
    ├── order_format.zig    ← Fixed-point → string
    ├── lcx_sign.zig        ← HMAC-SHA256 signing
    ├── kraken_sign.zig     ← SHA256+HMAC-SHA512 signing
    ├── coinbase_sign.zig   ← ECDSA P-256 JWT
    ├── fill_tracker.zig    ← FillResult processing
    └── execution_os.zig    ← Root: init_plugin(), run_cycle()
```

---

## 🚀 Build & Test Commands

```bash
# Build all modules
zig build-lib modules/analytics_os/analytics_os.zig -target x86_64-freestanding -O ReleaseFast
zig build-lib modules/grid_os/grid_os.zig -target x86_64-freestanding -O ReleaseFast
zig build-lib modules/execution_os/execution_os.zig -target x86_64-freestanding -O ReleaseFast

# Verify no syscalls
nm libanalytics_os.a | grep -E malloc|free|syscall
nm libgrid_os.a | grep -E malloc|free|syscall
nm libexecution_os.a | grep -E malloc|free|syscall

# QEMU test
qemu-system-x86_64 -gdb tcp::1234 -S omnibus.img
# Then in another terminal:
gdb
(gdb) target remote localhost:1234
(gdb) set {char}0x100050 = 0x70
(gdb) continue
```

---

## 🔑 Key Design Principles

1. **Determinism**: All nodes compute identical results. Fixed-point only.
2. **Latency**: No allocations, no syscalls, no blocking.
3. **Security**: Ada validates all requests before execution.
4. **Memory Isolation**: Each layer owns fixed segment; violations → SYS_PANIC.
5. **No Threads**: Sequential execution, manual context switching.

---

## 🧠 Pattern: Ring Buffer Protocol

Used everywhere (Analytics → Grid → Execution):

```zig
// Writer (Grid OS)
const tail = ring_header.tail;
data[tail & 0xFF] = new_data;
ring_header.tail = (tail + 1) & 0xFFFFFFFF;

// Reader (Execution OS)
while (ring_header.head != ring_header.tail) {
    const head = ring_header.head;
    const data = array[head & 0xFF];
    process(data);
    ring_header.head = (head + 1) & 0xFFFFFFFF;
}
```

**Why 0xFF mask?** 256-slot rings (2^8), so mask keeps index in 0–255 range.
**Why 32-bit counter?** Wraps after 4 billion increments (overflow-safe).

---

## 📝 Pair IDs & Exchange IDs

```zig
// Pairs (u16 enums in types.zig)
const PairId = enum(u16) {
    BTC_USD = 0,
    ETH_USD = 1,
    XRP_USD = 2,
};

// Exchanges (u8 constants)
const KRAKEN = 0;
const COINBASE = 1;
const LCX = 2;
```

### Pair Symbols per Exchange

| Pair | Kraken | Coinbase | LCX |
|------|--------|----------|-----|
| BTC_USD | XXBTZUSD | BTC-USD | BTC/EUR |
| ETH_USD | XETHZUSD | ETH-USD | ETH/EUR |
| XRP_USD | XXRPZUSD | XRP-USD | XRP/EUR |

---

## 🎓 How to Extend OmniBus

1. **New Exchange**: Create `new_exchange_sign.zig` in `modules/execution_os/`
   - Implement signing per exchange algorithm
   - Add dispatch in `execution_os.zig` switch statement
   - Recompile & test

2. **New Pair**: Update `PairId` enum in types.zig, update `pairSymbol()` function

3. **New Layer**: Create `modules/new_os/` with same pattern:
   - `types.zig` — structures & memory layout
   - `*.zig` — logic modules
   - `new_os.zig` — root with `init_plugin()`, `run_cycle()`

---

## ⚠️ Common Pitfalls

1. **Forgetting to set auth gate (0x100050 = 0x70)** → Cycles don't run
2. **Using floats instead of fixed-point** → Determinism lost, bugs in consensus
3. **Dynamic allocation (malloc)** → Violates bare-metal constraints
4. **Casting away volatile incorrectly** → Compiler optimizations may skip memory access
5. **Mixing up memory addresses** → Reads from wrong location
6. **Not masking ring indices** → Buffer overflow

---

## 📚 Documentation References

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Development guidelines, coding standards |
| `README.md` | Full system overview, build instructions |
| `opcodeOs/OMNIBUS_CODEX.md` | 100-page spec in Romanian |
| `QUICK_REFERENCE.md` | This file! |
| `MEMORY.md` | Auto-memory from previous Claude sessions |

---

## 🎯 Next Steps for Contributors

1. **Full QEMU Boot Test**: Integrate Ada kernel, test Bootloader → Ada → Analytics → Grid → Execution
2. **Track F (Bank OS)**: Implement SWIFT/ACH settlement (C module)
3. **Track G (Blockchain OS)**: Implement Solana flash loans (Rust module)
4. **CI/CD**: GitHub Actions to auto-build & test all modules
5. **Formal Test Suite**: Unit tests per module, integration tests

---

## 📞 Quick Contact

- **Repository**: https://github.com/SAVACAZAN/OmniBus
- **Primary Dev**: SAVACAZAN (owner)
- **Current Status**: 26 modules complete, 5K+ lines
- **Last Push**: 2026-03-08 (Execution OS Week 6)

---

**Remember**: Every module must compile to **freestanding x86_64** with **zero OS syscalls**!

---

*Generated for AI agents: If you can read this, you know OmniBus well enough to contribute.*

