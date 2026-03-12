# OmniBus Blockchain – Complete Specification v2.1.0

**Status**: Phase 50 (Active Development)
**Last Updated**: 2026-03-12
**Layer**: L0 (Anchored to BTC/ETH/EGLD/SOL/OPT/BASE)

---

## 1. CORE ARCHITECTURE

### 1.1 Token System

#### Primary Token: OMNI
- **Symbol**: OMNI
- **Total Supply**: 21,000,000 OMNI (fixed, like Bitcoin)
- **Smallest Unit**: SAT (1 OMNI = 100,000,000 SAT)
- **Decimals**: 8
- **Purpose**: Governance, staking, long-term value storage

#### 4 Domain-Derived Tokens (Elastic Supply)
Each pegged to OMNI but with independent demand curves:

| Domain | Token | Symbol | Purpose | Initial Supply |
|--------|-------|--------|---------|-----------------|
| Love | OMNI-LOVE | ΩLOVE | Romance/social dApps | 2.1M |
| Food | OMNI-FOOD | ΩFOOD | Agricultural/supply chain | 2.1M |
| Rent | OMNI-RENT | ΩRENT | Real estate/housing | 2.1M |
| Vacation | OMNI-VACA | ΩVACA | Travel/leisure economy | 2.1M |

**Cross-domain trading**: 1 OMNI = 1 ΩLOVE = 1 ΩFOOD = 1 ΩRENT = 1 ΩVACA (atomic)

---

## 2. BLOCKCHAIN PARAMETERS

### 2.1 Block Structure
```
Block Header (128 bytes):
  - version: u32                  (protocol version)
  - timestamp: u64                (Unix seconds)
  - height: u64                   (block number)
  - previous_hash: [32]u8         (SHA-256 of parent)
  - merkle_root: [32]u8           (Merkle tree of txs)
  - pq_root: [32]u8               (Post-quantum commitment)
  - difficulty: u32               (PoW target)
  - nonce: u32                    (PoW solution)

Block Body:
  - transactions: [1024]Tx        (up to 1024 per block)
  - anchor_proof: AnchorProof     (link to BTC/ETH/EGLD/SOL/OPT/BASE)
  - pq_signatures: [4]PQSig       (one per domain)
```

### 2.2 Consensus
- **PoW**: SHA-256d (Bitcoin-compatible)
- **Block Time**: 10 seconds (1/6 of Bitcoin)
- **Difficulty**: Auto-adjust every 10 blocks
- **Finality**: 6-block confirmation
- **Anchor Frequency**: Every 100 OmniBus blocks → 1 anchor tx

### 2.3 Cross-Chain Anchors
OmniBus merkle root committed to Layer 1 every 100 blocks:

| Chain | Anchor Method | Frequency | Cost |
|-------|---------------|-----------|------|
| Bitcoin | OP_RETURN in coinbase | 1/100 blocks | ~$5-20 |
| Ethereum | Event log on contract | 1/100 blocks | ~$2-10 gas |
| EGLD | Smart contract call | 1/100 blocks | ~0.1 EGLD |
| Solana | Instruction memo | 1/100 blocks | ~5000 lamports |
| Optimism | OP Stack commitment | 1/100 blocks | ~$0.50 |
| Base | Coinbase L2 commitment | 1/100 blocks | ~$0.30 |

---

## 3. TRANSACTION TYPES & OPCODES

### 3.1 Transfer Transactions (Opcode 0x01)

```
TransferTx:
  from: [64]u8         (sender address)
  to: [64]u8           (recipient address)
  amount: u64          (in SAT)
  token: u8            (0=OMNI, 1=LOVE, 2=FOOD, 3=RENT, 4=VACA)
  fee: u64             (in SAT, ≥16/byte)
  nonce: u32           (replay protection)
```

**Validation**:
- Signature verification (PQ + classical)
- Balance check (from.balance ≥ amount + fee)
- Nonce increment
- Output: UTXOs (0=unspent, 1=spent)

---

### 3.2 Smart Contract Operations (Opcode 0x02-0x09)

#### 0x02: Contract Deploy
```
DeployTx:
  creator: [64]u8
  contract_code: [4096]u8   (bytecode)
  code_len: u16
  init_state: [1024]u8      (initial state)
  state_len: u16
  gas_limit: u64
```
**Returns**: contract_id (SHA-256 of code + init_state)

#### 0x03: Contract Call
```
CallTx:
  contract_id: [32]u8
  caller: [64]u8
  method: [32]u8      (method name)
  args: [512]u8       (arguments)
  args_len: u16
  value: u64          (OMNI sent)
  gas_limit: u64
```

#### 0x04-0x09: Reserved for DeFi Primitives
- 0x04: Liquidity Pool (DEX)
- 0x05: Staking Vault
- 0x06: Governance Proposal
- 0x07: NFT Mint
- 0x08: Oracle Feed
- 0x09: Futures/Derivatives

---

### 3.3 Domain Management (Opcode 0x0A-0x0F)

#### 0x0A: Domain Anchor
```
DomainAnchorTx:
  domain_id: u8              (0=LOVE, 1=FOOD, 2=RENT, 3=VACA)
  anchor_chain: u8           (0=BTC, 1=ETH, 2=EGLD, 3=SOL, 4=OPT, 5=BASE)
  anchor_address: [64]u8     (domain's address on anchor chain)
  proof: [256]u8             (merkle proof of inclusion)
  proof_len: u16
```
**Effect**: Domain can now receive cross-chain messages

#### 0x0B: Key Rotation
```
KeyRotationTx:
  domain_id: u8
  old_pubkey: [2592]u8       (Dilithium-5 max size)
  old_pubkey_len: u16
  new_pubkey: [2592]u8
  new_pubkey_len: u16
  rotation_proof: [4096]u8   (signed by old key)
```

#### 0x0C: Governance Proposal
```
GovernanceTx:
  proposer: [64]u8
  title: [128]u8
  description: [512]u8
  voting_period: u32         (blocks)
  proposal_type: u8          (0=paramchange, 1=upgrade, 2=emergency)
```

---

### 3.4 Cross-Chain Bridge (Opcode 0x10-0x19)

#### 0x10: Initiate Cross-Chain Transfer
```
BridgeInitTx:
  from: [64]u8
  to_chain: u8               (0=BTC, 1=ETH, 2=EGLD, 3=SOL, 4=OPT, 5=BASE)
  to_address: [64]u8         (on destination chain)
  amount: u64
  token: u8                  (which OMNI token)
  nonce: u32
```
**Effect**: Locks tokens in bridge vault, emits cross-chain message

#### 0x11: Confirm Cross-Chain
```
BridgeConfirmTx:
  original_tx_id: [32]u8
  validator_signatures: [5][96]u8  (3-of-5 multi-sig)
  validator_count: u8
```
**Effect**: Releases tokens on destination chain (via anchor chain)

---

### 3.5 Specialized Operations (Opcode 0x20-0x2F)

#### 0x20: Flash Loan Request
```
FlashLoanTx:
  requester: [64]u8
  amount: u64
  token: u8
  callback: [32]u8           (contract ID to call back)
  fee_bps: u16               (0-500 basis points)
```
**Atomic**: Must repay within same block

#### 0x21: Atomic Swap
```
AtomicSwapTx:
  party_a: [64]u8
  party_b: [64]u8
  asset_a: (token: u8, amount: u64)
  asset_b: (token: u8, amount: u64)
  timeout: u32               (blocks until reversal)
```

#### 0x22: Data Commitment (Oracle)
```
DataCommitmentTx:
  oracle: [64]u8
  data_hash: [32]u8
  data_type: u8              (0=price, 1=weather, 2=sports, ...)
  timestamp: u64
  ttl: u32                   (time-to-live in blocks)
```

#### 0x23: Batch Transfer (Gas Optimization)
```
BatchTransferTx:
  from: [64]u8
  transfers: [100]Transfer   (up to 100)
  transfer_count: u8
  total_fee: u64
```

---

## 4. ADDRESSING SCHEME

### 4.1 OmniBus Address Format

```
Address := <domain_id (1 byte)><public_key_hash (32 bytes)><checksum (4 bytes)>
Length: 37 bytes = 74 hex chars
Example: "0x0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f"

Domain Prefix:
  0x0 = OMNI (main chain)
  0x1 = LOVE domain
  0x2 = FOOD domain
  0x3 = RENT domain
  0x4 = VACA domain
```

### 4.2 Address Derivation (BIP-32/39)

```
Mnemonic (12-24 words)
  → Seed (PBKDF2-SHA512)
  → Master Key (m)
  → Child Keys:
      m/44'/506'/0'/0/0  (OMNI account 0, address 0)
      m/44'/506'/1'/0/0  (LOVE account 1, address 0)
      m/44'/506'/2'/0/0  (FOOD account 2, address 0)
      m/44'/506'/3'/0/0  (RENT account 3, address 0)
      m/44'/506'/4'/0/0  (VACA account 4, address 0)
```

**Coin Type**: 506 (OmniBus)

---

## 5. GAS & FEES

### 5.1 Gas Pricing

| Operation | Base Gas | Per-Byte |
|-----------|----------|----------|
| Transfer | 21,000 | 16 |
| Contract Deploy | 100,000 | 200 |
| Contract Call | 50,000 | 100 |
| Cross-Chain Init | 30,000 | 50 |
| Flash Loan | 25,000 | 32 |

**Gas Unit**: 1 unit = 1 SAT
**Min Fee**: 16 SAT/byte (like Bitcoin)

### 5.2 Fee Distribution

```
Total Fee per Block:
  ├─ 50% → Block Proposer (mining reward)
  ├─ 30% → OMNI staking pool (delegated validators)
  ├─ 15% → Bridge validator set
  └─ 5%  → Treasury (governance fund)
```

---

## 6. WALLET CAPABILITIES

### 6.1 Multi-Chain Support

```
OmniBus Wallet can hold:
  ├─ OMNI (native token, on OmniBus chain)
  ├─ ΩLOVE, ΩFOOD, ΩRENT, ΩVACA (domain tokens)
  ├─ Bridged assets (OMNI on ETH, SOL, etc.)
  ├─ Standard tokens (USDC, USDT, WBTC via DEX)
  └─ NFTs (if implemented)
```

### 6.2 Wallet Features

- **Key Management**: HD wallets, hardware wallet support (Ledger)
- **Multi-Signature**: 2-of-3, 3-of-5, custom
- **Time-Locks**: Transactions locked until block height
- **Whitelisting**: Approved recipient addresses
- **Transaction Batching**: Multiple sends in one tx
- **Staking**: Direct staking interface
- **Bridge Integration**: Easy cross-chain transfers

---

## 7. SMART CONTRACT VM

### 7.1 Contract Bytecode Format

```
Instruction (1 byte opcode + args):
  0x00-0x0F: Arithmetic (ADD, SUB, MUL, DIV, MOD, etc.)
  0x10-0x1F: Logical (AND, OR, XOR, NOT, etc.)
  0x20-0x2F: Stack (PUSH, POP, DUP, SWAP, etc.)
  0x30-0x3F: Memory (MLOAD, MSTORE, etc.)
  0x40-0x4F: Storage (SLOAD, SSTORE, etc.)
  0x50-0x5F: Control (JUMP, JUMPI, CALL, etc.)
  0x60-0x6F: Token operations (TRANSFER, MINT, BURN)
  0x70-0x7F: Domain/Bridge (ANCHOR_CHECK, BRIDGE_CALL)
  0x80-0xFF: Reserved
```

### 7.2 Contract Execution Model

- **Execution**: EVM-like interpreter (deterministic)
- **Gas Metering**: 1 gas per computation step
- **Memory**: 256KB per contract execution
- **Storage**: Persistent key-value store per contract
- **Revert**: Transaction rolls back on gas exhaustion or error

---

## 8. GOVERNANCE

### 8.1 Voting Structure

```
Proposal Lifecycle:
  DRAFT → DISCUSSION (3 days) → VOTING (7 days) → EXECUTION (2 days) → COMPLETED

Voting Power:
  - 1 OMNI token = 1 vote
  - Staked OMNI = 1.5x voting power (quadratic bonus for long-term stakers)
  - Delegation supported
```

### 8.2 Governance Proposals

1. **Parameter Changes** (e.g., block time, gas prices)
2. **Protocol Upgrades** (new opcodes, consensus changes)
3. **Emergency Actions** (e.g., pause bridge due to exploit)
4. **Treasury Spend** (e.g., fund development)

---

## 9. SECURITY MODEL

### 9.1 Post-Quantum Cryptography

**Signature Algorithms** (per transaction):

| Algorithm | Key Size | Signature Size | Security Level |
|-----------|----------|-----------------|-----------------|
| Dilithium-5 (default) | 2,592 B | 2,420 B | NIST Level 5 |
| Falcon-512 (compact) | 897 B | 666 B | NIST Level 1 |
| SPHINCS+ (stateless) | 64 B | 4,096 B | NIST Level 5 |

**Hybrid Signing**: Each transaction signed with:
1. Primary PQ sig (Dilithium-5)
2. Classical ECDSA fallback (for compatibility)

### 9.2 Replay Protection

- **Transaction Nonce**: Per-address sequence number
- **Chain ID**: Encoded in transaction (prevent cross-chain replay)
- **Block Height**: Optional time-lock prevents replays after expiry

---

## 10. NETWORK PROTOCOL

### 10.1 P2P Messaging

```
Message Types:
  0x01: Peer discovery (DHT)
  0x02: Transaction broadcast (mempool)
  0x03: Block propagation
  0x04: Sync request (catchup)
  0x05: Consensus voting (PoW)
  0x06: Cross-chain message
  0x07: State sync (Merkle proofs)
```

### 10.2 Validator Set

- **Proof-of-Stake validators** (100-200 active)
- **Delegated via OMNI staking**
- **Slashing** for misbehavior (double-sign, offline)
- **Rotation** every epoch (1,000 blocks)

---

## 11. PERFORMANCE METRICS

| Metric | Target | Implementation |
|--------|--------|-----------------|
| Block Time | 10 sec | PoW |
| Throughput | 1,000 TPS | Batching + sharding ready |
| Finality | 1 min (6 blocks) | Confirmation depth |
| Cross-chain Latency | 100-600 sec | 1 anchor per 100 blocks |
| Tx Size | ~500 bytes avg | Optimized encoding |

---

## 12. DEPLOYMENT TIMELINE

| Phase | Target | Description |
|-------|--------|-------------|
| Phase 50 (Now) | Q1 2026 | Core chain + token system |
| Phase 51 | Q2 2026 | Smart contracts + DEX |
| Phase 52 | Q3 2026 | Cross-chain bridges (live) |
| Phase 53 | Q4 2026 | Governance (mainnet) |

---

## 13. EXAMPLE WORKFLOWS

### 13.1 User Onboarding

```
1. Generate wallet (BIP-39 mnemonic)
2. Derive addresses for all 4 domains
3. User receives 1,000 OMNI airdrop
4. User can trade OMNI ↔ USDC on local_exchange
5. User can stake OMNI for validator rewards
```

### 13.2 Cross-Chain Transfer

```
User wants: Send 100 OMNI from OmniBus → Ethereum

1. Initiate BridgeInitTx on OmniBus
   - Lock 100 OMNI in bridge vault
   - Emit bridge message
2. Message anchored to Ethereum (next 100-block epoch)
3. Wait for 3-of-5 validator signatures
4. Call bridge contract on Ethereum
5. User receives 100 OMNI-wrapped on Ethereum
```

### 13.3 Flash Loan

```
Attacker wants: Borrow 1M OMNI for atomic arbitrage

1. Submit FlashLoanTx (callback = my_contract)
2. 1M OMNI transferred to my_contract
3. Execute trades (BTC/OMNI on local_exchange + Uniswap)
4. Callback must repay 1M + 0.5% fee (5,000 OMNI)
5. If repay fails → entire tx reverts, 1M OMNI returned
```

---

## 14. COMPATIBILITY

- **Bitcoin**: Address format, OP_RETURN anchors
- **Ethereum**: EVM-like contract opcodes, event logs
- **Solana**: SPL token standard (for bridged OMNI)
- **EGLD**: esdt token format

---

## References

- BIP-39/32: Hierarchical Deterministic Wallets
- NIST FIPS 203: Dilithium Post-Quantum Signature
- OP Stack: Optimism Stack (for Base integration)
- EIP-155: Chain ID in transactions
- NIP-01: Nostr protocol (optional peer discovery)

---

**Status**: ✅ Specification Complete (v2.1.0)
**Next**: Implement omni_token.zig, omnibus_wallet.zig, cross_chain_bridge.zig
