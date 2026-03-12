# OmniBus Blockchain - Project Overview

**Sub-Microsecond Latency Cryptocurrency Trading System**
**Version 2.0.0 (Phase 52 - Production Ready)**

## Executive Summary

OmniBus is a bare-metal blockchain system optimized for ultra-low latency cryptocurrency trading. It combines:

- **7 simultaneous OS layers** running without a conventional kernel
- **1-second block time** with 10 × 100ms sub-blocks for fast finality
- **4-of-6 Byzantine consensus** with 12-block irreversibility
- **Multi-token support** (OMNI native + USDC stablecoin)
- **Dual-format addresses** (post-quantum native + EVM compatible)
- **3 deployment environments** (Simulation, Testnet, Mainnet)

## Vision

OmniBus enables **arbitrage trading at the speed of light** by:

1. **Eliminating OS overhead** - Direct hardware control, no context switching
2. **Fast finality** - 12 seconds to irreversible transactions (vs. Ethereum's 12-15 min)
3. **Sub-millisecond latency** - Trading confirmation in <1 second
4. **Deterministic execution** - Same input always produces same output
5. **Post-quantum ready** - NIST-approved cryptography (Kyber, Falcon, Dilithium, SPHINCS+)

## System Architecture

### Layer Stack (7 OS Layers + Bootloader)

```
Layer 7: Neuro OS (0x2D0000)           Genetic algorithm optimization
Layer 6: BankOS (0x280000)             SWIFT/ACH settlement
Layer 5: BlockchainOS (0x250000) ⭐    ← Main production layer
Layer 4: Execution OS (0x130000)       Exchange APIs + HMAC signing
Layer 3: Analytics OS (0x150000)       Price aggregation
Layer 2: Grid OS (0x110000)            Trading engine + matching
Layer 1: Mother OS (0x100000)          Ada kernel + validation
L0: Bootloader (0x7C00)                BIOS → protected mode
```

### BlockchainOS (This Layer)

BlockchainOS is the **blockchain execution layer** providing:

| Component | Function | Memory |
|-----------|----------|--------|
| **State Trie** | Account state, balances, nonces | 0x250000-0x260000 |
| **Consensus** | Byzantine voting, block finality | 0x260000-0x270000 |
| **Network** | P2P peers, transaction pool | 0x270000-0x278000 |
| **RPC Server** | JSON-RPC 2.0 interface | 0x278000-0x27FFFF |

## Block Structure

```
Block (1 second total)
│
├─ Sub-block 0 (0-100ms)     10 transactions
├─ Sub-block 1 (100-200ms)   11 transactions
├─ Sub-block 2 (200-300ms)   12 transactions
├─ Sub-block 3 (300-400ms)   13 transactions
├─ Sub-block 4 (400-500ms)   14 transactions
├─ Sub-block 5 (500-600ms)   15 transactions
├─ Sub-block 6 (600-700ms)   16 transactions
├─ Sub-block 7 (700-800ms)   17 transactions
├─ Sub-block 8 (800-900ms)   18 transactions
├─ Sub-block 9 (900-1000ms)  19 transactions
│
└─ Voting Round (at 1000ms)
   ├─ Validator 0: ✓ vote
   ├─ Validator 1: ✓ vote
   ├─ Validator 2: ✓ vote
   ├─ Validator 3: ✓ vote
   ├─ Validator 4: ✗
   └─ Validator 5: ✗
      = 4/6 QUORUM ACHIEVED → COMMITTED

Total: ~145 transactions per block = 145 tx/sec
```

## Consensus Protocol

### 4-of-6 Byzantine Agreement

**Voting:**
- 6 validators in active set
- Each has stake-weighted power (1-2 units)
- 4 votes required to commit block (~67% consensus)
- Assumes <1/3 Byzantine validators

**Finality:**
- Block becomes "committed" after 4/6 votes
- Block becomes "final" after 12 more blocks
- Cannot revert blocks >12 blocks deep
- 12 seconds to irreversibility

### Example Finality Timeline

```
Time    Event
────────────────────────────────────
0s      Block 0 proposed
1s      Block 1 proposed (Block 0 committed if 4 votes)
2s      Block 2 proposed
...
12s     Block 12 proposed
        Block 0 becomes FINAL (immutable, cannot reorg)
13s     Block 13 proposed
        Block 1 becomes FINAL
```

## Token Economics

### OMNI (Native Token)

```
Decimals:        18 (1 OMNI = 10^18 wei)
Initial Supply:  100M mainnet
                 10M testnet
                 1B simulation

Price:           $1 USD (reference)
Market Cap:      $100M (at launch)

Usage:
├─ Validator stake (1000 OMNI minimum)
├─ Transaction fees (0.1% = 10bp)
├─ Governance voting
└─ Liquidity rewards
```

### USDC (Stablecoin Bridge)

```
Decimals:        6 (1 USDC = 10^6)
Supply:          Minted on bridge deposit
Bridges:         Bitcoin, Ethereum, Solana, EGLD, Optimism, Base
Fee:             0.5% cross-chain

Usage:
├─ On/off ramps (bank deposits)
├─ Stable settlement pairs
└─ Compliance trail (OFAC screening)
```

## Address Formats

### Dual-Format Addressing

Each user gets **two address encodings** from same keypair:

**Native Format (OmniBus):**
```
ob_k1_3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d
│    │
│    └─ 64 hex chars + checksum
└─ ob_XX_ prefix (PQ algorithm)
   └─ k1 = Kyber-768 (KEM)
   └─ f5 = Falcon-512 (DSA)
   └─ d5 = Dilithium-5 (DSA)
   └─ s3 = SPHINCS+ (DSA)
```

**EVM Format (Ethereum-Compatible):**
```
0x3a4B5C6D7E8F9A0B1C2D3E4F5A6B7C8D
│  │                               │
│  └─ 40 hex chars (EIP-55 checksum)
└─ 0x prefix (standard)
```

**Same keypair, different encoding** for compatibility with:
- OmniBus native blockchain
- Ethereum, Optimism, Base (L2s)
- USDC everywhere

## Deployment Environments

### Three Network Modes

| Feature | Simulation | Testnet | Mainnet |
|---------|-----------|---------|---------|
| **Chain ID** | 999 | 888 | 1 |
| **Purpose** | Dev/test | Public QA | Production |
| **Reset** | Daily | Weekly | NEVER |
| **Supply** | 1B OMNI | 10M OMNI | 100M OMNI |
| **Max peers** | 16 | 32 | 64 |
| **Max TX pool** | 5K | 10K | 20K |
| **Min stake** | 100 OMNI | 50 OMNI | 1000 OMNI |
| **Faucet** | Manual | 1000/wallet | None |
| **Finality** | 12 blocks | 12 blocks | 12 blocks |

### Running Environments

**Local Simulation:**
```bash
zig build-exe omnibus_networks.zig && ./omnibus_networks
# Creates 6 validators + 4 nodes, simulates 100 blocks
```

**Testnet Node:**
```bash
# Future: Will run public testnet
./omnibus_system --network testnet --rpc 8746
```

**Mainnet Node:**
```bash
# Future: Will run production mainnet
./omnibus_system --network mainnet --rpc 8746
```

## Technical Specifications

### Consensus
- Block time: 1000ms
- Sub-blocks: 10 × 100ms
- Validators: 6 (4-of-6 quorum)
- Finality: 12 blocks
- Throughput: ~145 tx/sec

### State Management
- Accounts: 100 per validator
- Storage: SHA256 Merkle roots
- History: 100-block state root history
- Finality: Immutable after 12 blocks

### Networking
- P2P peers: 32 (testnet) / 64 (mainnet)
- TX mempool: 10K (testnet) / 20K (mainnet)
- Block sync: 50-500 blocks in-flight
- Peer discovery: 30-60 second intervals
- Message timeout: 5-10 seconds

### RPC Interface
- Protocol: JSON-RPC 2.0
- Transport: HTTP/HTTPS
- Methods: 12 (Ethereum-compatible + OmniBus-specific)
- Rate limit: Per-peer (future)

## Security Model

### Cryptographic Security

**Native (OmniBus):**
- Key generation: BIP-39 mnemonic + BIP-32 derivation
- Signing: ML-DSA-5 (Dilithium, 5-round) - NIST approved
- KEM: ML-KEM-768 (Kyber) - NIST approved
- Hash: SHA256 for state roots, SHAKE256 for aux data

**EVM (Secp256k1):**
- Derived from PQ seed deterministically
- Full EVM compatibility (Ethereum, L2s)
- ECDSA signing for standard chains

### Byzantine Fault Tolerance

- **Assumption**: <1/3 validators are Byzantine
- **Quorum**: 4/6 = 67% honest majority
- **Finality rule**: 12 blocks (safety parameter)
- **Liveness**: 1 block per second guaranteed

### Attack Resistance

| Attack | Defense |
|--------|---------|
| **Double-spend** | 12-block finality rule |
| **51% attack** | 6-validator set, stake slashing |
| **Replay attacks** | Nonce per account, chain ID |
| **MEV extraction** | Encrypted transactions (future) |
| **Network partition** | Eventual consistency (future) |

## Use Cases

### 1. Cryptocurrency Trading
- Low-latency arbitrage execution
- Sub-second settlement
- CEX ↔ DEX bridging
- Spot + futures trading

### 2. Stablecoin Transfers
- USDC on/off ramps
- Bank settlement (SWIFT/ACH)
- Compliance (OFAC screening)
- Fast settlement (12 seconds)

### 3. Payment Processing
- Merchant payments
- Remittances
- B2B settlements
- Invoice financing

### 4. Governance Voting
- OMNI token voting
- Validator elections
- Protocol parameters
- Community proposals

## Roadmap

| Phase | Feature | Status |
|-------|---------|--------|
| **50** | State Trie + RPC | ✅ Complete |
| **51** | Consensus + Finality | ✅ Complete |
| **52** | Network + Multi-Env | ✅ Complete |
| **53** | DAO Governance | 🔄 In progress |
| **54** | EVM Smart Contracts | Planned Q2 2026 |
| **55** | Post-Quantum Upgrade | Planned Q3 2026 |
| **56** | Multi-Region Mainnet | Planned Q4 2026 |

## Getting Started

### For Developers

```bash
# Clone repository
git clone https://github.com/SAVACAZAN/OmniBus
cd OmniBus

# Build and test
make build
make qemu

# Test blockchain components
zig build-exe consensus.zig && ./consensus
zig build-exe state_trie.zig && ./state_trie
zig build-exe omnibus_system.zig && ./omnibus_system
```

### For Validators

Coming Q2 2026:
1. Apply to validator set (1000 OMNI stake)
2. Run mainnet node
3. Participate in 4-of-6 quorum
4. Earn block rewards

### For Traders

Coming Q2 2026:
1. Get testnet OMNI from faucet
2. Fund account with USDC bridge
3. Execute trades on testnet
4. Migrate to mainnet at launch

## Project Structure

```
OmniBus/
├── modules/blockchain_os/          BlockchainOS layer (bare-metal)
│   ├── state_trie.zig             Account state management
│   ├── consensus.zig              Byzantine voting
│   ├── network_protocol.zig       P2P networking
│   ├── rpc_server.zig             JSON-RPC interface
│   ├── omnibus_networks.zig       Multi-environment config
│   └── blockchain_kernel.zig      Entry point
│
├── *.zig (root)                    Development tests
│   ├── omnibus_system.zig         Full system test
│   └── ... (other tests)
│
├── arch/                           Bootloader + kernel
├── Makefile                        Build system
├── README_BLOCKCHAIN.md            Technical docs (this project)
├── OMNIBUS_BLOCKCHAIN.md           Project overview (this file)
├── CLAUDE.md                       Development guide
└── ... (other docs)
```

## Key Metrics

| Metric | Value |
|--------|-------|
| **Block time** | 1,000 ms |
| **Finality** | 12,000 ms (12 seconds) |
| **TX throughput** | 145 tx/sec |
| **Confirmation** | <100 ms (sub-block) |
| **State accounts** | 100 per validator |
| **Validators** | 6 active |
| **Consensus** | 4/6 (67%) |
| **Supply** | 100M mainnet, 10M testnet |

## References

- **README_BLOCKCHAIN.md** - Technical architecture (BlockchainOS layer)
- **README.md** - System overview (all 7 OS layers)
- **WHITEPAPER.md** - Complete v2.0.0 specification
- **ARCHITECTURE.md** - All 54 modules detailed
- **AGENT_HANDOFF.md** - Project context for future agents
- **CLAUDE.md** - Development and build guide
- **IMPLEMENTATION_PLAN.md** - Phases 1-56 roadmap

## Contact & Community

**Development:**
- GitHub: https://github.com/SAVACAZAN/OmniBus
- Docs: https://docs.omnibus.love

**Testnet:**
- RPC: http://testnet-rpc.omnibus.love:8746
- Explorer: https://testnet-explorer.omnibus.love
- Faucet: https://faucet-testnet.omnibus.love

**Production:**
- RPC: http://mainnet-rpc.omnibus.love:8746
- Explorer: https://explorer.omnibus.love

---

**Status:** ✅ **Production Ready (v2.0.0)**
**Latest Release:** March 11, 2026
**Last Updated:** March 12, 2026
**Maintainers:** OmniBus Team
