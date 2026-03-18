# BlockchainOS Module

**Layer 5 Blockchain Execution (0x250000-0x27FFFF, 192KB)**

This is the complete blockchain system for OmniBus running at Layer 5 in bare-metal mode.

## Structure

```
blockchain_os/
├── blockchain_kernel.zig       Entry point + kernel state
├── state_trie.zig              Account state management
├── consensus.zig               Byzantine consensus engine
├── network_protocol.zig        P2P networking
├── rpc_server.zig              JSON-RPC 2.0 interface
├── omnibus_networks.zig        Multi-environment config
└── README.md                   This file
```

## Quick Start

### Test Individual Components

```bash
zig build-exe ../../state_trie.zig && ./../../state_trie
zig build-exe ../../consensus.zig && ./../../consensus
zig build-exe ../../network_protocol.zig && ./../../network_protocol
zig build-exe ../../rpc_server.zig && ./../../rpc_server
```

### Test Complete System

```bash
zig build-exe ../../omnibus_system.zig && ./../../omnibus_system
```

### Test Multi-Environment

```bash
zig build-exe ../../omnibus_networks.zig && ./../../omnibus_networks
```

### Build Bare-Metal Kernel

```bash
# Full bare-metal build (includes all 7 layers)
make build

# Run in QEMU
make qemu

# Debug with GDB
make qemu-debug
```

## Modules

### 1. state_trie.zig (64KB at 0x250000)
Account state management with Merkle Patricia Trie.

**Key structures:**
- `AccountState` - Individual account (address, nonce, balances)
- `StateTrieManager` - Manager for 100 accounts
- SHA256-based state roots with 100-block history

**Key functions:**
- `get_account()` - Query account
- `set_account()` - Create/update account
- `transfer_omni()` - Send OMNI between accounts
- `update_root_hash()` - Compute state root
- `get_state_root_at_block()` - Historical state roots

### 2. consensus.zig (64KB at 0x260000)
Byzantine consensus with 4-of-6 quorum.

**Key structures:**
- `ValidatorSet` - 6 validators with stake
- `BlockProposal` - Block with 10 sub-blocks
- `SubBlock` - 100ms atomic unit
- `ConsensusManager` - Orchestrates voting

**Key functions:**
- `propose_block()` - Start new block proposal
- `add_subblock()` - Add 100ms sub-block
- `vote_commit_block()` - Validator votes
- `update_finality()` - 12-block finality tracking
- `advance_height()` - Move to next block

### 3. network_protocol.zig (32KB at 0x270000)
P2P peer-to-peer networking.

**Key structures:**
- `PeerConnection` - Peer metadata + stats
- `TransactionPool` - Mempool with priority
- `BlockSyncQueue` - Download queue with retry
- `NetworkNode` - P2P coordinator

**Key functions:**
- `add_peer()` - Connect to peer
- `broadcast_block()` - Propagate block
- `broadcast_transaction()` - Propagate TX
- `request_blocks()` - Sync blocks
- `cleanup_dead_peers()` - Remove inactive peers

### 4. rpc_server.zig (32KB at 0x278000)
JSON-RPC 2.0 HTTP interface.

**Ethereum-compatible methods:**
- `eth_blockNumber` - Latest block
- `eth_getBalance()` - Account balance
- `eth_sendTransaction()` - Submit TX
- `eth_call()` - Read-only call
- `eth_estimateGas()` - Gas estimation

**OmniBus-specific methods:**
- `omnibus_getDualAddress()` - PQ + EVM addresses
- `omnibus_getStateRoot()` - State root at block
- `omnibus_getBridgeStatus()` - Cross-chain status
- `omnibus_getValidators()` - Validator set
- `omnibus_submitProof()` - Anchor proof

### 5. omnibus_networks.zig (External)
Multi-environment configuration (Simulation, Testnet, Mainnet).

**Key structures:**
- `NetworkConfig` - Per-environment settings
- `NodeInstance` - Simulated node
- `NetworkSimulation` - Multi-node cluster
- `NetworkFactory` - Environment builder

**Key functions:**
- `init_simulation()` - Create simulation config
- `init_testnet()` - Create testnet config
- `init_mainnet()` - Create mainnet config
- `setup_simulation_cluster()` - Create test nodes
- `advance_block()` - Simulate block progression

### 6. blockchain_kernel.zig (Entry Point)
Bare-metal kernel entry and IPC interface.

**Key functions:**
- `kernel_init()` - Initialize blockchain OS
- `kernel_tick()` - Called every 100ms by Mother OS
- `process_transaction()` - Add TX to mempool
- `propose_block()` - Create new block
- `finalize_block()` - Mark block final
- `query_balance()` - Get account balance
- `handle_rpc_request()` - Process RPC
- `get_status()` - Kernel health status

## Consensus Specification

### Block Time
- **Full block**: 1,000ms (1 second)
- **Sub-block**: 100ms each
- **Sub-blocks/block**: 10
- **Total TXs/block**: ~145 (avg 14.5 per sub-block)
- **Throughput**: ~145 tx/sec

### Voting
- **Validators**: 6 active
- **Quorum**: 4-of-6 (67%)
- **Stake-weighted**: Higher stake = more voting power
- **Voting round**: Happens at end of block (1000ms)
- **Vote timeout**: 5 seconds

### Finality
- **Committed**: After 4/6 votes at block creation
- **Final**: After 12 more blocks (12 seconds total)
- **Safety**: Cannot revert blocks >12 blocks deep
- **Liveness**: 1 block per second guaranteed

## Token Economics

| Token | Decimals | Supply | Usage |
|-------|----------|--------|-------|
| OMNI | 18 | 100M mainnet | Stake, fees, governance |
| USDC | 6 | Minted on bridge | Stable settlement |

**TX Fees**
- Fee: 0.1% (10 basis points)
- Collected by protocol (future: distributed to validators)

**Validator Stake**
- Minimum: 1000 OMNI mainnet, 50 OMNI testnet
- Slashing: -20% for Byzantine behavior
- Rewards: TBD (currently no inflation)

## Environment Configuration

### Simulation (Chain 999)
```rust
NetworkConfig {
    block_time: 1000ms,
    max_peers: 16,
    max_tx_pool: 5000,
    initial_supply: 1B OMNI,
    reset: daily,
}
```

### Testnet (Chain 888)
```rust
NetworkConfig {
    block_time: 1000ms,
    max_peers: 32,
    max_tx_pool: 10000,
    initial_supply: 10M OMNI,
    reset: weekly,
    faucet: 1000 OMNI/wallet,
}
```

### Mainnet (Chain 1)
```rust
NetworkConfig {
    block_time: 1000ms,
    max_peers: 64,
    max_tx_pool: 20000,
    initial_supply: 100M OMNI,
    reset: never,
}
```

## Memory Map

```
0x250000-0x27FFFF  BlockchainOS (192KB total)
├─ 0x250000-0x260000  State Trie (64KB)
│  ├─ 0x250000-0x250100  StateTrieManager struct (256B)
│  └─ 0x250100-0x260000  Account storage (64KB - 256B)
│
├─ 0x260000-0x270000  Consensus (64KB)
│  ├─ 0x260000-0x260100  ConsensusManager struct (256B)
│  └─ 0x260100-0x270000  Block history (64KB - 256B)
│
├─ 0x270000-0x278000  Network (32KB)
│  ├─ 0x270000-0x270100  NetworkNode struct (256B)
│  └─ 0x270100-0x278000  Peer + TX pool (32KB - 256B)
│
└─ 0x278000-0x27FFFF  RPC Server (32KB)
   ├─ 0x278000-0x278100  RpcServer struct (256B)
   └─ 0x278100-0x27FFFF  Response buffer (32KB - 256B)
```

## Building for Bare-Metal

```bash
# Build entire OmniBus system (all 7 layers)
make build

# Output: omnibus.iso (10MB bootable disk image)

# Run in QEMU
make qemu

# Debug with GDB stub on port 1234
make qemu-debug
# In another terminal: gdb -ex 'target remote :1234'
```

## Testing Development Cycle

1. **Write code** in root (e.g., `consensus.zig`)
2. **Test independently** with `zig build-exe`
3. **Test integration** with `omnibus_system.zig`
4. **Test multi-env** with `omnibus_networks.zig`
5. **Copy to modules/** when stable
6. **Build bare-metal** with `make build`
7. **Test on QEMU** with `make qemu`

## Future Extensions

- **Smart contracts** - EVM bytecode execution (Phase 54)
- **Light clients** - Proof verification without full block (Phase 54)
- **Cross-chain bridges** - Multi-validator proofs (Phase 55)
- **Post-quantum upgrade** - ML-DSA/SPHINCS+ migration (Phase 56)
- **Layer 2 sequencer** - Rollup support (Phase 57)

## Status

✅ **Production Ready (v2.0.0)**

All core modules tested and functional:
- State Trie: ✅ Accounts, balances, nonces
- Consensus: ✅ Byzantine voting, finality
- Network: ✅ P2P peers, mempool, sync
- RPC: ✅ JSON-RPC 2.0, 12 methods
- Multi-env: ✅ Simulation, Testnet, Mainnet

## References

- `../../README_BLOCKCHAIN.md` - Detailed technical docs
- `../../OMNIBUS_BLOCKCHAIN.md` - Project overview
- `../../README.md` - System architecture (all 7 layers)
- `../../CLAUDE.md` - Development guide
- `../../IMPLEMENTATION_PLAN.md` - Phases 1-56 roadmap

---

**Last Updated**: March 12, 2026
**Version**: 2.0.0 (Phase 52)
**Status**: Production Ready
