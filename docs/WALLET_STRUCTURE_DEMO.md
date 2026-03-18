# OmniBus Multi-Domain Wallet Structure (Corrected)

## Executive Summary
Agent wallet with 5 **post-quantum cryptographic** addresses:
- **1 Native OMNI** (hybrid Dilithium-5 + Kyber-768)
- **4 Domain Addresses** (each using different NIST PQ algorithm)

Each address has corresponding ERC20/USDC counterpart on Ethereum Sepolia for on-ramp.

---

## Complete Wallet Address Mapping

```
┌─────────────────────────────────────────────────────────────────┐
│                 AGENT WALLET (1,000,000 OMNI)                   │
│                                                                  │
│ 📝 Mnemonic: 12 words (128-bit entropy)                         │
│ 🔑 Master Seed: BIP-39 PBKDF2-SHA512                           │
└─────────────────────────────────────────────────────────────────┘
```

### ═══════════════════════════════════════════════════════════════
### 💰 NATIVE OMNI ADDRESS (Hybrid PQ Cryptography)
### ═══════════════════════════════════════════════════════════════

**Domain:** `omnibus.omni`
**Algorithm:** Dilithium-5 (ML-DSA-5) + Kyber-768 (ML-KEM-768) – Hybrid
**Short ID:** `OMNI-5k7m-OMNI`
**Address Prefix:** `ob_omni_`
**Full Address:** `ob_omni_5d7k768kyber5dil_native`

| Property | Value |
|----------|-------|
| **Domain** | omnibus.omni |
| **Crypto** | Dilithium-5 + Kyber-768 (Hybrid) |
| **Pub Key Size** | 3,776 bytes (1,184 Kyber + 2,592 Dilithium) |
| **Secret Key Size** | 7,296 bytes (2,400 Kyber + 4,896 Dilithium) |
| **Security Level** | 256-bit quantum (native chain) |
| **ERC20 Bridge (Sepolia)** | `0x8ba1f109551bD432803012645Ac136ddd64DBA72` |
| **Balance** | 1,000,000 OMNI (100,000,000,000 SAT) |

---

### ═══════════════════════════════════════════════════════════════
### 🔐 POST-QUANTUM DOMAIN ADDRESSES
### ═══════════════════════════════════════════════════════════════

#### Domain 1: omnibus.love (Kyber-768 Key Encapsulation)

| Property | Value |
|----------|-------|
| **Domain** | omnibus.love |
| **Algorithm** | Kyber-768 (ML-KEM-768) – Key Encapsulation |
| **Address Prefix** | `ob_k1_` |
| **Full Address** | `ob_k1_2a5f8b1e9c3d6f4a7e2b5c8d1f4a7e2b` |
| **Short ID** | `OMNI-4a8f-LOVE` |
| **Pub Key Size** | 1,184 bytes |
| **Secret Key Size** | 2,400 bytes |
| **Security Level** | 256-bit quantum |
| **Use Case** | Key encapsulation, encryption (non-transferable) |

---

#### Domain 2: omnibus.food (Falcon-512 Signature)

| Property | Value |
|----------|-------|
| **Domain** | omnibus.food |
| **Algorithm** | Falcon-512 – Lattice-based Signature |
| **Address Prefix** | `ob_f5_` |
| **Full Address** | `ob_f5_1b4e9d2a5f8c3e6b9d2f5a8c1e4b7d0f` |
| **Short ID** | `OMNI-3b7c-FOOD` |
| **Pub Key Size** | 897 bytes |
| **Secret Key Size** | 1,281 bytes |
| **Security Level** | 192-bit quantum |
| **Use Case** | Cryptographic signatures (non-transferable) |

---

#### Domain 3: omnibus.rent (Dilithium-5 Signature)

| Property | Value |
|----------|-------|
| **Domain** | omnibus.rent |
| **Algorithm** | Dilithium-5 (ML-DSA-5) – NIST-approved Signature |
| **Address Prefix** | `ob_d5_` |
| **Full Address** | `ob_d5_5c7a1f3d9e2b6f4a8c1d5e9f2a6c1d4f` |
| **Short ID** | `OMNI-6d2e-RENT` |
| **Pub Key Size** | 2,592 bytes |
| **Secret Key Size** | 4,896 bytes |
| **Security Level** | 256-bit quantum |
| **Use Case** | NIST PQ signature standard (non-transferable) |

---

#### Domain 4: omnibus.vacation (SPHINCS+ Signature)

| Property | Value |
|----------|-------|
| **Domain** | omnibus.vacation |
| **Algorithm** | SPHINCS+ (SLH-DSA-256) – Hash-based Signature |
| **Address Prefix** | `ob_s3_` |
| **Full Address** | `ob_s3_9a2d5c1f4e7b2a5f8c3d6e9a1d4c7f2a` |
| **Short ID** | `OMNI-8f1a-VACA` |
| **Pub Key Size** | 32 bytes |
| **Secret Key Size** | 64 bytes |
| **Security Level** | 128-bit eternal (stateless hash-based) |
| **Use Case** | Long-term archival, eternal security (non-transferable) |

---

## ═══════════════════════════════════════════════════════════════
## 🌉 ERC20 ON-RAMP FLOW (USDC → OMNI Bridge)
## ═══════════════════════════════════════════════════════════════

### Step 1: Client sends USDC to bridge address
```
User's MetaMask/EOA (Sepolia)
    ↓
    Sends X USDC.e to:
    0x8ba1f109551bD432803012645Ac136ddd64DBA72
    ↓
    Bridge verifies sender address
```

### Step 2: Agent wallet receives USDC
```
Bridge Address
    ↓
    Tracks USDC transfers on Sepolia chain
    ↓
    Calls usdc_erc20_onramp module
```

### Step 3: Agent mints OMNI to client
```
Client identified by ERC20 sender address
    ↓
    OMNI minted to client's wallet:
    Amount: X USDC × 1e12 = X OMNI (1:1 peg)
    ↓
    Client receives OMNI in their assigned OMNI address
```

### Example Transaction
```
USDC On Sepolia:  100 USDC (100,000,000 units @ 6 decimals)
    ↓
Conversion (1:1): 100 OMNI
    ↓
Scaled to 18 decimals: 100 × 10^12 SAT = 100,000,000,000,000,000,000 SAT
```

---

## ═══════════════════════════════════════════════════════════════
## 📋 CLASSICAL CHAINS (BIP-44, for reference)
## ═══════════════════════════════════════════════════════════════

Agent also holds addresses on classical blockchains (for trading liquidity):

| Chain | Path | Address |
|-------|------|---------|
| **Bitcoin** | m/44'/0'/0'/0/0 | `bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4` |
| **Ethereum** | m/44'/60'/0'/0/0 | `0x8ba1f109551bD432803012645Ac136ddd64DBA72` |
| **Solana** | m/44'/501'/0'/0/0 | `FPAcAKxJ8dXJGKwKmMgLCqEchKsYRCG7bkkxRSDRd4t7` |
| **EGLD** | m/44'/508'/0'/0/0 | `erd1qyu8zcm5n0hf3mxvjkq5w7pqyt7g0mqnp8l2qxh` |
| **Optimism** | m/44'/60'/0'/0/0 | `0x8ba1f109551bD432803012645Ac136ddd64DBA72` |
| **Base** | m/44'/60'/0'/0/0 | `0x8ba1f109551bD432803012645Ac136ddd64DBA72` |

---

## ═══════════════════════════════════════════════════════════════
## 🔐 Security & Non-Transferability
## ═══════════════════════════════════════════════════════════════

**Post-Quantum Domain Addresses ARE NOT FOR TRANSFERS.**

- ✅ **Use for:** Encryption, signatures, governance, archival
- ❌ **Do NOT use for:** On-chain transfers (no blockchain address format)
- ⚠️ **Quantum-resistant:** Survived NIST standardization (ML-KEM-768, ML-DSA-5)

**Classical Ethereum Address** (`0x8ba1f109...`):
- ✅ **Use for:** USDC transfers, bridge interaction
- ✅ **ERC20-compatible:** Works with MetaMask, transfers, DEX swaps
- ✅ **Testnet:** Available on Sepolia, Mainnet, Optimism, Base

---

## ═══════════════════════════════════════════════════════════════
## ✅ Testing Checklist
## ═══════════════════════════════════════════════════════════════

- [ ] Generate agent wallet (mnemonic + all 5 PQ addresses)
- [ ] Display wallet export to UART serial (via `export_to_log()`)
- [ ] Send USDC.e to bridge address on Sepolia
- [ ] Verify transfer detected by `poll_ethereum_for_usdc()`
- [ ] Confirm OMNI minted to correct client wallet
- [ ] Display client registry with all transfers
- [ ] Boot OmniBus in QEMU, monitor serial output
- [ ] Verify all address prefixes (ob_k1_, ob_f5_, ob_d5_, ob_s3_, ob_omni_)

---

**Version:** 1.0 – Corrected per agent_wallet.zig Phase 68+
**Last Updated:** 2026-03-18
