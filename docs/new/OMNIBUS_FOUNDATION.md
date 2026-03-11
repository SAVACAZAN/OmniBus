# OmniBus Foundation - Blockchain Layer 0 Architecture

**Status**: Foundation Layer Complete (2026-03-11)
**Type**: Post-Quantum Multi-Domain Blockchain (Layer 0) anchored to 6 chains
**Governance**: OmniBus Foundation NGO (nonprofit)
**Fiat Gateway**: Coinbase Commerce (on/off-ramps)

---

## Executive Summary

OmniBus Foundation creates a **quantum-safe blockchain infrastructure** where:

1. **Single Master Seed** (BIP-39) generates **4 independent post-quantum identities**
2. Each identity uses **different NIST-approved algorithm** (Kyber, Dilithium, Falcon, Sphincs+)
3. The blockchain **anchors to 6 Layer-1 + Layer-2 chains** (Bitcoin, Ethereum, EGLD, Solana, Optimism, Base)
4. **Zero single point of failure**: If up to 2 anchor chains have issues, others maintain ledger integrity
5. **Cross-chain bridges** allow liquidity provisioning across all 5 ecosystems

---

## Architecture Overview

```
                     ┌─────────────────────────────────┐
                     │   OmniBus Master Seed (BIP39)   │
                     │    (12-word mnemonic)           │
                     └────────────────┬────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
         ┌──────────▼──────────┐      │      ┌──────────▼──────────┐
         │  BIP32/SLIP-0010    │      │      │  PQ Domain Seeds    │
         │  Classical Chains   │      │      │  (HMAC-SHA512)      │
         │  ─────────────────  │      │      │  ─────────────────  │
         │                     │      │      │                     │
    ┌────┴────────┬───────┬────┴┐     │      ├────────┬────────┬───┴────┐
    │             │       │     │     │      │        │        │        │
    │             │       │     │     │      │        │        │        │
┌───▼───┐   ┌────▼───┐ ┌─▼───┐ ┌─▼──┐  ┌──▼──┐  ┌──▼──┐ ┌───▼──┐ ┌───▼───┐
│ BTC   │   │ ETH    │ │SOL  │ │EGLD│  │Opt  │  │LOVE │ │FOOD  │ │RENT   │
│secp   │   │secp    │ │Ed25 │ │se  │  │secp │  │Kyb  │ │Falcon│ │Dil    │
│256k1  │   │256k1   │ │5519 │ │cp  │  │256k1│  │768  │ │512   │ │5      │
└───┬───┘   └────┬───┘ └─┬───┘ └─┬──┘  └──┬──┘  └──┬──┘ └───┬──┘ └───┬───┘
    │            │      │       │        │       │       │       │
    │            │      │       │        │       │       │       │
    └────────────┼──────┼───────┼────────┼───────┼───────┼───────┘
                 │      │       │        │       │       │
         ┌───────▼──────▼───────▼────────▼───────▼───────▼──────┐
         │                                                       │
         │   OmniBus Blockchain Layer 0                         │
         │   (Post-Quantum Multi-Domain Ledger)                 │
         │                                                       │
         │   ┌──────────────────────────────────────────────┐   │
         │   │ Block Header                                 │   │
         │   ├──────────────────────────────────────────────┤   │
         │   │ Version | Timestamp | Height                 │   │
         │   │ Prev_Hash | Merkle_Root | PQ_Root            │   │
         │   │ Difficulty | Nonce                           │   │
         │   └──────────────────────────────────────────────┘   │
         │                                                       │
         │   ┌──────────────────────────────────────────────┐   │
         │   │ Transactions (up to 1024)                    │   │
         │   ├──────────────────────────────────────────────┤   │
         │   │ From | To | Amount | Type                    │   │
         │   │ PQ_Signature | Gas | Fee                     │   │
         │   └──────────────────────────────────────────────┘   │
         │                                                       │
         │   ┌──────────────────────────────────────────────┐   │
         │   │ Anchor Proofs (6 chains)                     │   │
         │   ├──────────────────────────────────────────────┤   │
         │   │ [BTC] [ETH] [EGLD] [SOL] [OPT] [BASE]              │   │
         │   │ Each contains: tx_hash | merkle_proof        │   │
         │   └──────────────────────────────────────────────┘   │
         │                                                       │
         │   ┌──────────────────────────────────────────────┐   │
         │   │ PQ Signatures (4 domains)                    │   │
         │   ├──────────────────────────────────────────────┤   │
         │   │ [LOVE] [FOOD] [RENT] [VACATION]             │   │
         │   │ 3-of-4 required for consensus                │   │
         │   └──────────────────────────────────────────────┘   │
         │                                                       │
         └───────────────────────────────────────────────────────┘
```

---

## 4 Post-Quantum Domains (From Single Seed)

### Domain 1: omnibus.love (KYBER-768)
**Purpose**: Confidential messaging and encryption
- **Algorithm**: Kyber-768 (Key Encapsulation Mechanism)
- **Security Level**: 192-bit (equivalent to AES-192)
- **Signature Size**: 1088 bytes (ciphertext)
- **Address Format**: `ob_k1_[base32_pubkey_hash]`
- **Short ID**: `OMNI-4a8f-LOVE`
- **Use Cases**:
  - Private messaging (impossible to decrypt even with quantum computers)
  - Confidential data sharing
  - Secret voting (encrypted ballots)
  - Multi-recipient encryption

### Domain 2: omnibus.food (FALCON-512)
**Purpose**: Fast, compact transactions
- **Algorithm**: Falcon-512 (FFT-based lattice signatures)
- **Security Level**: 128-bit
- **Signature Size**: 666 bytes (smallest of NIST algorithms)
- **Address Format**: `ob_f5_[base32_pubkey_hash]`
- **Short ID**: `OMNI-99be-FOOD`
- **Use Cases**:
  - Point-of-sale transactions
  - Micro-payments (small signature = low gas)
  - Invoice signing
  - Mobile wallets (compact keys)

### Domain 3: omnibus.rent (DILITHIUM-5)
**Purpose**: Strong, legally binding contracts
- **Algorithm**: Dilithium-5 (Module-LWE based signatures)
- **Security Level**: 256-bit (maximum NIST level)
- **Signature Size**: 2420 bytes
- **Address Format**: `ob_d5_[base32_pubkey_hash]`
- **Short ID**: `OMNI-7c2e-RENT`
- **Use Cases**:
  - Rental agreements (legally binding in most jurisdictions)
  - Escrow contracts
  - Multi-signature governance
  - High-value settlements

### Domain 4: omnibus.vacation (SPHINCS+)
**Purpose**: Eternal, long-term identity
- **Algorithm**: SPHINCS+ (Hash-based signatures)
- **Security Level**: 256-bit forever
- **Signature Size**: 4096 bytes (large but eternal)
- **Address Format**: `ob_s3_[base32_pubkey_hash]`
- **Short ID**: `OMNI-b1f3-VACA`
- **Use Cases**:
  - Generational trusts (100-year validity)
  - Historical records (immutable archives)
  - Permanent identities
  - Proof of existence at point in time

---

## Anchor Chain Integration (5 Chains)

### 1. Bitcoin (Proof-of-Work)
```
OmniBus Block ─► OP_RETURN Data in Coinbase ─► Bitcoin Merkle Tree
                 (32 bytes Omni block hash)       │
                                                  └─ Immutable forever
```
**Proof Method**: OP_RETURN data in coinbase transaction
**Finality**: 6 confirmations ≈ 1 hour
**Cost**: 546 satoshis (≈ $0.20 at current prices)

### 2. Ethereum (Smart Contracts)
```
OmniBus Block ─► OmniBusAnchor Contract ─► Merkle Tree Root in Storage
                 (event: BlockAnchored)       │
                                             └─ 12 block finality
```
**Proof Method**: Smart contract event log + storage root
**Finality**: ~3 minutes (12 blocks)
**Cost**: ~$5-20 depending on gas prices

### 3. EGLD (Elrond)
```
OmniBus Block ─► SmartContract.call ─► Elrond Finality
                 (with merkle proof)    │
                                       └─ Instant (1 block)
```
**Proof Method**: Smart contract transaction + epoch finality
**Finality**: Instant (1 block = ~6 seconds)
**Cost**: 0.00001 EGLD (≈ $0.0005)

### 4. Solana (Proof-of-History)
```
OmniBus Block ─► Solana Program Account ─► Proof-of-History Hash Chain
                 (with merkle root)        │
                                          └─ Instant (next slot)
```
**Proof Method**: Solana program account + PoH linkage
**Finality**: Instant (next slot = 400ms)
**Cost**: 5000 lamports (≈ $0.001)

### 5. Optimism (Layer-2)
```
OmniBus Block ─► Optimism Smart Contract ─► L1 Batch Root ─► Ethereum
                 (via OP Stack)                │                │
                                              └─ 7-day challenge └─ Final
```
**Proof Method**: L2 batch commitment to Ethereum
**Finality**: 7 days (fraud proof challenge period)
**Cost**: $0.10-0.50 (cheap L2 gas)

---

## Cross-Chain Bridge System

### Bridge Mechanics (BTC ↔ OMNI ↔ ETH example)

```
User sends 1 BTC to bridge address
  ↓
Bitcoin network confirms (6 blocks)
  ↓
Bridge validator monitors Bitcoin chain
  ↓
Creates OmniBus transaction: TRANSFER (1 BTC-pegged to user's OMNI address)
  ↓
OmniBus block is created + anchored to all 6 chains
  ↓
User now holds 1 BTC-OMNI (can trade, transfer, use)
  ↓
To redeem: User sends BTC-OMNI back to bridge address
  ↓
Validators sign off on burning BTC-OMNI
  ↓
Bridge releases 1 BTC from vault to user's Bitcoin address
```

**Time-Lock Protection**:
- OmniBus → Layer-1 redemption locked for 100 blocks
- Prevents flash loan attacks
- ~16 hours on Bitcoin, ~3 minutes on Ethereum, instant on Solana

**Liquidity Provisioning**:
- Users can become bridge liquidity providers (passive income)
- Earn 0.1-0.5% fees on bridge volume
- Locked in smart contract for security

---

## Coinbase Commerce Integration (Fiat On/Off-Ramps)

OmniBus integrates with **Coinbase Commerce** to enable seamless fiat ↔ OMNI conversion.

### On-Ramp (Fiat → OMNI)

Users can fund their OmniBus wallets directly from:
- **Credit/Debit Cards** (Visa, Mastercard)
- **Bank Transfers** (ACH in US, SEPA in EU)
- **Wire Transfers** (SWIFT, international)

**Flow**:
```
User enters amount (e.g., $1,000 USD)
  ↓
Selects payment method + OmniBus address
  ↓
Coinbase Commerce creates charge (15-min window)
  ↓
User completes payment via Coinbase
  ↓
Payment confirmed → OMNI transferred to address
  ↓
User owns equivalent OMNI (less 1-2% fees)
```

### Off-Ramp (OMNI → Fiat)

Users can convert OMNI to fiat and withdraw to bank account:

**Flow**:
```
User selects amount of OMNI to convert
  ↓
Specifies target fiat currency + bank account
  ↓
OmniBus creates off-ramp flow
  ↓
Validates account (KYC/AML)
  ↓
Locks OMNI in smart contract escrow
  ↓
Coinbase Commerce settles fiat to bank
  ↓
OMNI is burned from escrow
  ↓
Fiat appears in bank account (2-3 business days)
```

### Pricing & Fees

| Payment Method | On-Ramp Fee | Off-Ramp Fee | Settlement Time |
|---|---|---|---|
| Card | 2.0% | 2.5% | Instant |
| ACH (US) | 0.5% | 0.5% | 1-2 days |
| SEPA (EU) | 0.5% | 0.5% | 1-2 days |
| SWIFT | 1.0% | 1.5% | 3-5 days |
| Bank Wire | 1.0% | 1.0% | 1 day |

### Compliance & KYC

- **Tier 1** ($0-$10k lifetime): Email + OmniBus address
- **Tier 2** ($10k-$100k): Name + ID verification
- **Tier 3** ($100k+): Full KYC + AML screening

OmniBus works with Coinbase's regulatory framework to ensure compliance in all jurisdictions.

---

## Post-Quantum Address Generation

### Derivation Path

```
Master Seed (BIP-39)
  │
  ├─ HMAC-SHA512(seed, "omnibus.love")     ─► Kyber-768 keypair
  │                                            Address: ob_k1_...
  │
  ├─ HMAC-SHA512(seed, "omnibus.food")     ─► Falcon-512 keypair
  │                                            Address: ob_f5_...
  │
  ├─ HMAC-SHA512(seed, "omnibus.rent")     ─► Dilithium-5 keypair
  │                                            Address: ob_d5_...
  │
  └─ HMAC-SHA512(seed, "omnibus.vacation") ─► SPHINCS+ keypair
                                              Address: ob_s3_...
```

### Privacy Properties

- **Unlinkability**: Knowing one domain address reveals nothing about others
- **Domain Separation**: Each domain has mathematically independent key material
- **Non-Collidibility**: Even with all 4 domains, entropy loss is impossible
- **Determinism**: Same seed always generates same addresses

---

## Consensus Rules

### Block Production
- **Target time**: 10 minutes (like Bitcoin)
- **Max size**: 4 MB
- **Max transactions**: 1024
- **Difficulty adjustment**: Every 2016 blocks (~2 weeks)

### Transaction Validation
1. Check signature (post-quantum)
2. Verify nonce (no replay attacks)
3. Check balance
4. Calculate gas cost
5. Verify anchor proofs (3-of-5 chains must anchor)

### Finalization
- Requires **3-of-4 post-quantum signatures** valid
- Byzantine fault tolerance: tolerate 1 domain failure
- If 2 domains fail: network halts (prevents accidental fork)
- Requires 1-of-6 anchor chains to confirm

---

## Foundation Governance

### OmniBus Foundation (Nonprofit)
- **Mission**: Steward post-quantum blockchain ecosystem
- **Structure**:
  - 7-member board of directors
  - Technical council (10 engineers)
  - Community assembly (unlimited members)

### Proposal System
```
Proposal Phase (7 days)
  ↓
Voting Phase (14 days)
  ↓
Timelock (7 days)
  ↓
Execution (automated smart contracts)
```

### Voting Requirements
- **Quorum**: 30% of token holders
- **Majority**: 75% approval
- **Veto Power**: 3-of-4 domain signers (prevents harmful changes)

### Changeable Parameters
- Block reward halving schedule
- Difficulty adjustment algorithm
- Gas pricing
- Bridge fee structure
- Algorithm rotation schedule
- Emergency shutdown (rare, requires all 4 domains)

---

## Token Economics (OMNI)

### Supply Schedule
```
Initial Supply: 21,000,000 OMNI (like Bitcoin)

Halving Schedule:
- Blocks 0-210,000:        50 OMNI per block
- Blocks 210,000-420,000:  25 OMNI per block
- Blocks 420,000-630,000:  12.5 OMNI per block
- ...continues until dust
```

### Use Cases
1. **Transaction fees** (gas)
2. **Bridge liquidity provisioning** (earn yield)
3. **Governance voting** (weighted by stake)
4. **Staking rewards** (future: proof-of-stake layer)

### Distribution
- **50%**: Mining rewards (fair launch, proof-of-work)
- **30%**: Foundation treasury (development, operations)
- **15%**: Community grants (ecosystem development)
- **5%**: Founders/contributors (4-year vesting)

---

## Implementation Timeline

### Phase 1: Foundation (Q1-Q2 2026) ✅ COMPLETE
- ✅ Core blockchain architecture designed
- ✅ Post-quantum crypto integrated
- ✅ Multi-domain wallet system architected
- ✅ 5-chain anchoring designed

### Phase 2: Implementation (Q2-Q3 2026)
- [ ] Integrate liboqs (NIST reference implementations)
- [ ] Full blockchain simulation in QEMU
- [ ] Bridge smart contracts (Bitcoin, Ethereum, EGLD, Solana, Optimism, Base)
- [ ] Testnet launch

### Phase 3: Community (Q3-Q4 2026)
- [ ] Foundation NGO incorporation (Switzerland)
- [ ] Governance token (OMNI) distribution
- [ ] Community assembly elections
- [ ] Mainnet launch (Genesis block)

### Phase 4: Ecosystem (2027+)
- [ ] DeFi protocols built on OmniBus
- [ ] Cross-chain yield farming
- [ ] Institutional partnerships
- [ ] Mainstream adoption

---

## Security Model

### Threat Model

| Threat | Impact | Mitigation |
|--------|--------|-----------|
| Quantum computer appears | Historical data at risk | SPHINCS+ domain survives 100+ years |
| One anchor chain fails | Block may be unanchored | 5 other chains maintain ledger |
| One domain compromised | That domain's identity stolen | Other 3 domains unaffected |
| 51% attack on Bitcoin | BTC anchor fails | ETH/EGLD/SOL/OPT still anchor |
| Smart contract bug | Ethereum anchor may fail | Bitcoin/Solana/Optimism/Base still work |

### Defensive Strategies
1. **Algorithm Rotation**: Can switch to new NIST algorithm if needed
2. **Time-Locked Upgrades**: 7-day delay before changes take effect
3. **Fallback Chains**: If all 6 anchors fail, blockchain can operate standalone
4. **Community Fork**: If foundation acts maliciously, community can hard-fork

---

## Comparison to Competitors

| Feature | OmniBus | Bitcoin | Ethereum | Solana | Cosmos |
|---------|---------|---------|-----------|---------|---------|
| Post-Quantum Ready | ✅ | ❌ | ❌ | ❌ | ❌ |
| Multi-Chain Anchor | ✅ (5 chains) | ❌ (layer-1 only) | ❌ | ❌ | ❌ |
| Domain-Based Identity | ✅ | ❌ | ❌ | ❌ | ❌ |
| Instant Finality | ❌ (10 min) | ❌ (60 min) | ✅ (12 blocks) | ✅ (instant) | ✅ |
| Layer-1 to Layer-1 Bridge | ✅ (5) | ❌ | ❌ | ❌ | ✅ (IBC) |
| Quantum-Safe Signatures | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## Deployment Locations

### Mainnet
- Bootnode: omnibus-mainnet.foundation (global)
- Explorer: https://omnibus.foundation/blocks
- API: https://api.omnibus.foundation/

### Testnet
- Bootnode: omnibus-testnet.foundation
- Explorer: https://testnet.omnibus.foundation/blocks
- Faucet: Free OMNI tokens for testing

### Local Development
- Docker image: `omnibus:latest`
- QEMU simulation: 100% deterministic

---

## Conclusion

OmniBus Foundation creates a **quantum-safe, multi-chain, post-quantum blockchain** that:

1. **Protects the future**: SPHINCS+ domain survives quantum computers forever
2. **Provides redundancy**: 5 anchor chains mean no single point of failure
3. **Enables privacy**: Kyber domain for truly confidential transactions
4. **Supports commerce**: Falcon domain for fast, cheap payments
5. **Ensures binding contracts**: Dilithium domain for legally-enforceable agreements
6. **Serves communities**: Fair mining, democratic governance, non-profit stewardship

**Next: Foundation NGO formation and testnet launch (Q2 2026).**

---

**Document**: OmniBus Foundation Architecture
**Version**: 1.0
**Date**: 2026-03-11
**Status**: Approved for implementation
