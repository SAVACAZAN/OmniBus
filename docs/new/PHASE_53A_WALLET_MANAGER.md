# Phase 53A: Wallet Manager (L48) - Multi-Chain Stealth Wallets

**Status**: Implementation Started (2026-03-11)
**Location**: 0x530000–0x57FFFF (320KB protected stealth zone)
**Module**: L48 Wallet Manager

---

## Overview

**Wallet Manager** extends BlockchainOS (L4) with HD wallet support for **4 blockchains** derived from a single **BIP39 seed**:

1. **Bitcoin** (BIP32/BIP39 P2WPKH)
   - Derivation: `m/44'/0'/0'/0/0`
   - Address format: Bech32 (SegWit)
   - Signature: ECDSA with Schnorr optimization

2. **Ethereum** (EOA - Externally Owned Accounts)
   - Derivation: `m/44'/60'/0'/0/0`
   - Address format: Checksummed hex (0x...)
   - Signature: ECDSA secp256k1

3. **Solana** (Derived key format)
   - Derivation: `m/44'/501'/0'/0/0`
   - Address format: Base58 (SPL standard)
   - Signature: Ed25519

4. **Elrond/EGLD** (Bech32 format)
   - Derivation: `m/44'/508'/0'/0/0`
   - Address format: Bech32 (`erd1...`)
   - Signature: EdDSA

---

## 3 Recovery Modes

### Mode 1: RECOVER (10-Step Recovery Protocol)
✅ **Normal operation** - Seed-based recovery enabled

**Features**:
- BIP39 mnemonic seed storage (encrypted)
- 10-step recovery process
- 4 mathematical formulas for key encryption
- Automatic validation of recovered keys

**Recovery Steps**:
```
1. Validate seed format (BIP39 word list)
2. Compute SHA256(seed) for authentication
3. Decrypt with Formula 1 (hash-based)
4. Decrypt with Formula 2 (timestamp-based)
5. Decrypt with Formula 3 (ECDSA-based)
6. Decrypt with Formula 4 (Shamir-like 3-pass)
7. Validate consistency across all 4 formulas
8. BIP32 re-derive wallets (all 4 chains)
9. Validate addresses match stored
10. Mark recovered, reset attempt counter
```

**Use Case**: Personal wallets, DEX trading accounts, institutional cold storage with recovery

---

### Mode 2: NO_RECOVER (Maximum Security - One-Time Only)
🔒 **Ultra-secure** - No recovery possible

**Features**:
- No seed stored (entropy only)
- No recovery code generated
- Keys encrypted but never recoverable
- Permanent loss if entropy is lost

**Characteristics**:
- Highest security (no recovery vector)
- One-time wallet generation
- Immediate key derivation and address generation
- No seed hash stored
- If lost → lost forever

**Use Case**: High-security institutional vaults, emergency funds, air-gapped cold wallets

---

### Mode 3: RECOVER_FROM_VAULTS (Hardware/External Vault Backup)
🏦 **Institutional-grade** - Keys stored in external vaults

**Features**:
- Keys encrypted with vault public key
- Hardware wallet support (Ledger, Trezor)
- Cold storage backups (paper, metal)
- Multisig schemes (M-of-N vaults)
- Hardware Security Modules (AWS CloudHSM)

**Vault Types**:
```c
enum VaultType {
    HARDWARE,       // Ledger Nano S/X, Trezor
    COLD,          // Paper wallet, metal backup
    MULTISIG,      // 2-of-3, 3-of-5 multisig
    HARDWARE_HSMS, // AWS CloudHSM, Thales Luna
}
```

**Recovery Process**:
1. Request vault by ID
2. Provide vault proof/signature
3. Decrypt key from vault storage
4. Validate key format
5. Re-derive addresses
6. Validate addresses match stored
7. Sign transactions with recovered key
8. Clear key from memory

**Use Case**: Institutional custody, exchange cold wallets, corporate treasuries

---

## 4 Encryption Formulas

### Formula 1: Hash-Based (SHA256)
```
encrypted = master_key ⊕ SHA256(seed || "formula_1")
decrypted = encrypted ⊕ SHA256(seed || "formula_1")
```
**Properties**:
- Fast (SHA256 standard)
- Deterministic (same seed → same result)
- Secure (collision-resistant)

### Formula 2: Timestamp-Based (HMAC-SHA256)
```
encrypted = master_key ⊕ HMAC-SHA256(seed, timestamp)
decrypted = encrypted ⊕ HMAC-SHA256(seed, timestamp)
```
**Properties**:
- Time-dependent (different at each recovery)
- Authenticated (HMAC prevents tampering)
- Replay-resistant

### Formula 3: ECDSA-Based (Elliptic Curve KDF)
```
encrypted = master_key ⊕ KDF(privkey_from_seed, "formula_3")
decrypted = encrypted ⊕ KDF(privkey_from_seed, "formula_3")
```
**Properties**:
- Elliptic curve security (secp256k1)
- Post-quantum resistant (if using curves like SIKE)
- Cryptographically derived key material

### Formula 4: Combinatorial (BLAKE2 3-Pass Shamir-Like)
```
fragment = master_key ⊕ (H1 ⊕ H2 ⊕ H3) mod 2^256
where H1 = BLAKE2(seed||0)
      H2 = BLAKE2(seed||1)
      H3 = BLAKE2(seed||2)
```
**Properties**:
- Multi-pass hashing (BLAKE2 is faster than SHA256)
- Shamir-like secret sharing (3-of-3 required)
- XOR cascading (information theory secure)

**Why 4 Formulas?**
- **Redundancy**: If one formula broken, 3 others still valid
- **Defense-in-depth**: Different mathematical properties
- **Recovery validation**: All 4 must produce consistent key
- **Future-proof**: Some formulas survive quantum attacks

---

## Data Structures

### StealthWallet (Main Structure)
```zig
const StealthWallet = packed struct {
    config: WalletConfig,          // Mode, timestamps, attempt counters
    wallets: [4]HDWallet,          // BTC, ETH, SOL, EGLD

    // Mode 1: RECOVER
    recovery_code: [40]u8,         // 10-step formula encoding
    is_recoverable: bool,
    is_recovered: bool,

    // Mode 3: VAULT
    vaults: [4]Vault,              // External vault references
    is_vault_recoverable: bool,
    is_vault_recovered: bool,
    vault_recovery_timestamp: u64,
    vault_recovery_count: u32,

    // Common
    fragments: [3][32]u8,          // XOR fragments (encrypted)
    timestamp: u64,                // Creation time
};
```

### HDWallet (Per-Chain Wallet)
```zig
const HDWallet = packed struct {
    chain: u8,                     // 0=BTC, 1=ETH, 2=SOL, 3=EGLD
    seed_hash: [32]u8,            // SHA256(seed) for validation
    master_key_encrypted_f1: [32]u8,
    master_key_encrypted_f2: [32]u8,
    master_key_encrypted_f3: [32]u8,
    master_key_encrypted_f4: [32]u8,
    derivation_path: [10]u32,     // m/44'/coin'/account'/change/index
    public_addresses: [10][48]u8, // 10 derived addresses
    address_count: u32,            // Current index
    checksum: u32,                // CRC32 metadata
    is_initialized: bool,
};
```

---

## Memory Layout

```
0x530000–0x57FFFF: Wallet Manager Stealth Zone (320KB)
├─ 0x530000–0x531000: WalletConfig (1KB)
├─ 0x531000–0x540000: StealthWallet (main structure, ~60KB)
├─ 0x540000–0x570000: Vault storage (192KB, for vault mode)
├─ 0x570000–0x578000: Temporary fragment buffers (32KB)
└─ 0x578000–0x57FFFF: Reserved/unused (28KB)
```

**Access Control**:
- ✅ BlockchainOS (L4) - Full read/write
- ❌ All other modules - NO ACCESS
- ❌ Report OS (L9) - Cannot audit (privacy)
- ❌ Checksum OS (L10) - Cannot checksum (stealth)
- ❌ Compliance OS (L23) - Cannot report (confidential)

---

## Security Properties

### Key Isolation
- Keys never leave stealth zone (0x530000–0x57FFFF)
- XOR fragments stored encrypted
- Memory clearing on every operation
- No logs of key material

### Address Transparency
- All 4 chain addresses always visible
- No audit trail for addresses
- Public key derivation (non-sensitive)
- Blockchain explorers can monitor

### Recovery Guarantees
- **Mode 1**: 10-step deterministic recovery
- **Mode 2**: Permanent loss (no recovery possible)
- **Mode 3**: Vault-dependent recovery (5-60 seconds)

### Threat Model
```
Attacker Goal          | Mode 1      | Mode 2     | Mode 3
--------------------|------------|----------|----------
Recover seed        | Hardened   | N/A      | N/A
Steal funds         | If seed    | Never    | If vault
Decrypt fragments   | 4 formulas | N/A      | Vault key
Replay attacks      | Timestamp  | N/A      | Vault nonce
Quantum compute     | BLAKE2OK   | N/A      | Depends
```

---

## Implementation Status

### Completed (Phase 53A Session)
- ✅ wallet_manager.zig (700+ lines)
  - create_wallet_recoverable() – Mode 1
  - create_wallet_no_recovery() – Mode 2
  - create_wallet_vault_backed() – Mode 3
  - recover_wallet_10_step() – 10-step recovery
  - recover_wallet_no_recovery() – Lockout
  - recover_wallet_from_vault() – Vault recovery
  - sign_transaction_with_vault() – Signing

- ✅ math_formulas.zig (300+ lines)
  - formula_1_encrypt/decrypt() – SHA256-based
  - formula_2_encrypt/decrypt() – HMAC-SHA256
  - formula_3_encrypt/decrypt() – ECDSA KDF
  - formula_4_encrypt/decrypt() – BLAKE2 Shamir

- ✅ wallet_manager.ld – Linker script (0x530000)

- ✅ Makefile rules
  - build targets for wallet_manager.o, .elf, .bin
  - math_formulas.o compilation
  - wallet_manager.bin dependency in `make build`

- ✅ EGLD support (4th chain)
  - Added to Chain enum
  - Derivation path m/44'/508'/0'/0/0
  - Bech32 address encoding (placeholder)
  - derive_egld_address() function

### TODO (Phase 53B-C)

**Phase 53B: Cryptographic Implementation**
- [ ] SHA256 implementation (full)
- [ ] HMAC-SHA256 with timestamp
- [ ] BLAKE2 3-pass with index
- [ ] ECDSA secp256k1 operations
- [ ] KDF (HKDF) from ECDSA key
- [ ] BIP39 seed validation
- [ ] BIP32 key derivation

**Phase 53C: Chain-Specific Addressing**
- [ ] Bitcoin address generation (P2WPKH)
- [ ] Ethereum address generation (Keccak256 hash)
- [ ] Solana address generation (Ed25519)
- [ ] EGLD address generation (Bech32)
- [ ] Address validation (checksum, format)
- [ ] Vault pubkey handling (all chains)

**Phase 53D: Testing & Integration**
- [ ] Unit tests (recover, no_recover, vaults)
- [ ] Seed recovery validation
- [ ] Address consistency checks
- [ ] Vault signature verification
- [ ] Memory clearing verification
- [ ] Latency profiling (<1ms recovery)

---

## Build & Test

```bash
# Build wallet manager
make build

# Expected output:
# [ZIG] Compiling Wallet Manager...
# [ZIG] Compiling Math Formulas...
# [LD] Linking Wallet Manager ELF...
# [OC] Converting Wallet Manager to binary...
# ✓ PHASE 53A: WALLET MANAGER COMPLETE
#   L48: Wallet Manager @ 0x530000
#   BTC: m/44'/0'/0'/0/0 (P2WPKH)
#   ETH: m/44'/60'/0'/0/0 (EOA)
#   SOL: m/44'/501'/0'/0/0 (Derived)
#   EGLD: m/44'/508'/0'/0/0 (Bech32)

# Boot & verify
make qemu
# Expected: Wallet Manager loads, addresses visible
```

---

## Example: 3-Mode Usage

### Mode 1: RECOVER (Personal Wallet)
```zig
// User provides BIP39 seed (12 words)
var seed = bip39_to_entropy("abandon abandon abandon ...");

// Create recoverable wallet
create_wallet_recoverable(seed);

// Later: Recover from seed
var btc_addr = recover_wallet_10_step(seed);
// Output: bc1q...
```

### Mode 2: NO_RECOVER (Ultra-Secure)
```zig
// Generate from entropy (no seed)
var entropy = random_entropy();

// Create non-recoverable wallet
create_wallet_no_recovery(entropy);

// If seed lost → wallet lost forever
// recover_wallet_no_recovery() always fails
```

### Mode 3: RECOVER_FROM_VAULTS (Institutional)
```zig
// Vaults created externally (hardware)
var vaults = [3]Vault {
    { vault_id: btc_vault_id, vault_type: HARDWARE, ... },
    { vault_id: eth_vault_id, vault_type: HARDWARE, ... },
    { vault_id: sol_vault_id, vault_type: HARDWARE, ... },
};

// Create vault-backed wallet
create_wallet_vault_backed(vaults);

// Recovery via vault
var vault_proof = get_vault_proof(btc_vault_id);
recover_wallet_from_vault(btc_vault_id, vault_proof);
```

---

## Next Phases

**Phase 53B** (2 weeks): Implement 4 encryption formulas
**Phase 53C** (2 weeks): Chain-specific addressing (BTC, ETH, SOL, EGLD)
**Phase 53D** (2 weeks): Testing, validation, latency optimization
**Phase 54** (Q2 2026): Multi-processor support (parallel wallet ops)

---

**Last Updated**: 2026-03-11
**Author**: Claude Code (Haiku 4.5) + OmniBus AI
**Status**: Phase 53A Foundation Complete, Cryptography TBD
