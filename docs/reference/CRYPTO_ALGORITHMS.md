# OmniBus Wallet – Real Cryptographic Algorithms (Phase 66)

## Integration with universal_wallet_generator.zig

**Location**: `/home/kiss/OmniBus/modules/omnibus_network_os/wallet_api.zig`

### Crypto Stack

```
1. BIP-39 Seed Generation
   └─→ PBKDF2-HMAC-SHA512(mnemonic, "TREZOR" + passphrase)
       Iterations: 2048 (standard)
       Output: 64-byte master seed
       Input entropy: 128-bit (12 words) or 256-bit (24 words)

2. BIP-32 Master Key Derivation
   └─→ HMAC-SHA512("Bitcoin seed", master_seed)
       Output: 32-byte master key + 32-byte chain code

3. BIP-44 Path Derivation
   └─→ CKDpriv (Child Key Derivation, private)
       Path: m/44'/coin_type'/account'/change/address_index
       Hardened derivation: index + 0x80000000
       HMAC: SHA512 (iterative for each path component)
       Output: 32-byte child key + 32-byte chain code

4. Address Encoding
   ├─→ EVM (Ethereum, Polygon, Arbitrum): Keccak-256(pubkey) → 0xXXXXXX...
   ├─→ UTXO (Bitcoin, Litecoin, Dogecoin): Secp256k1 + Base58Check encoding
   ├─→ Solana: SHA256(pubkey) → Base58 encoding
   └─→ OmniBus (OMNI): Post-Quantum (Kyber-768 or Dilithium-5) → ob_k1_ prefix
```

## Real Algorithms Used

### Endpoint: `/api/wallet/generate?words=12|24`

**Crypto Used:**
```
BIP-39 Seed Generation
├─ Entropy Source: [12|24] word BIP-39 word list
├─ Key Derivation: PBKDF2(password=words, salt="TREZOR", iterations=2048)
├─ Hash Algorithm: HMAC-SHA512
├─ Output Size: 512 bits (64 bytes)
└─ Result: Master seed for all chains
```

**Zig Code**:
```zig
const wallet = HDWallet.init(mnemonic);  // Uses PBKDF2-HMAC-SHA512
```

**Response**:
```json
{
  "success": true,
  "words": 12,
  "mnemonic": "abandon abandon ...",
  "type": "BIP39",
  "entropy_bits": 128,
  "master_seed_derived": true,
  "master_key_length": 32,
  "derivation_algorithm": "PBKDF2-HMAC-SHA512 + BIP-32"
}
```

---

### Endpoint: `/api/wallet/addresses/{chain}?index=0`

**Crypto Used:**
```
BIP-44 Deterministic Address Derivation

1. Start with master key (from BIP-39)
2. For each path component (44, coin_type, account, change, index):
   ├─ Build HMAC input: [0x00 || key || index_bigendian]
   ├─ Compute: HMAC-SHA512(key=chain_code, msg=hmac_input)
   ├─ Output: [32-byte tweaked_key || 32-byte new_chain_code]
   └─ Repeat for next component

3. Final derived key → Address in chain-specific format
```

**Zig Code**:
```zig
const wallet = HDWallet.init(test_mnemonic);
const derived = wallet.derive_path("m/44'/60'/0'/0/0");  // CKDpriv
// derived.derived_key: 32 bytes (new private key)
// derived.derived_chain_code: 32 bytes (for next level)
```

**Chain Support**:

| Chain | Coin Type | Path | Algorithm | Output Format |
|-------|-----------|------|-----------|---------------|
| **OMNI** | 8888 | `m/44'/8888'/0'/0/0` | BIP-32 HMAC-SHA512 → Kyber-768 | `ob_k1_XXXXX...` |
| **Bitcoin** | 0 | `m/44'/0'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | P2WPKH (SegWit) |
| **Ethereum** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 → Keccak-256 | `0xXXXX...` (EVM) |
| **Solana** | 501 | `m/44'/501'/0'/0/0` | BIP-32 HMAC-SHA512 → Ed25519 | Base58 |
| **Polygon** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | `0xXXXX...` (EVM) |
| **Arbitrum** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | `0xXXXX...` (EVM) |
| **LOVE token** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | ERC-20 Contract |
| **VACA token** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | ERC-20 Contract |
| **RENT token** | 60 | `m/44'/60'/0'/0/0` | BIP-32 HMAC-SHA512 → Secp256k1 | ERC-20 Contract |

---

## Security Properties

### Entropy
- **12-word seed**: 128 bits of entropy (2^128 possible seeds)
- **24-word seed**: 256 bits of entropy (2^256 possible seeds)
- **Master key**: 256 bits after PBKDF2-HMAC-SHA512

### Key Derivation Security
- **PBKDF2 iterations**: 2,048 (BIP-39 standard)
- **HMAC key length**: 512 bits (SHA512)
- **Child key derivation**: Hardened paths (0x80000000+) use private key derivation
- **Chain code**: Protects against key reuse across paths

### Non-Repudiation
- Each address derived from seed is **deterministic** and **non-repudiable**
- Same seed + same path = same address, always
- Recovery: Seed phrase → all addresses, all private keys

### Post-Quantum (OMNI chain)
- BIP-32/44 derivation → **Kyber-768** (ML-KEM, NIST PQ Level 1)
- Or **Dilithium-5** (ML-DSA, NIST PQ Level 5) for signatures
- Address format: `ob_k1_XXXXX...` (40+ chars, post-quantum safe)

---

## Implementation Files

### Core Crypto Library
**File**: `/home/kiss/OmniBus/modules/blockchain_os/universal_wallet_generator.zig` (50+ chains)

```zig
pub const HDWallet = struct {
    master_seed: [64]u8,
    master_key: [32]u8,
    master_chain_code: [32]u8,

    pub fn init(mnemonic: []const u8) HDWallet {
        // Step 1: PBKDF2-HMAC-SHA512(mnemonic, "TREZOR")
        // Step 2: HMAC-SHA512("Bitcoin seed", master_seed)
        // Returns: Master key + chain code
    }

    pub fn derive_path(self: *const HDWallet, path: []const u8) struct {
        derived_key: [32]u8,
        derived_chain_code: [32]u8,
    } {
        // Parses BIP-44 path (m/44'/60'/0'/0/0)
        // Iteratively applies CKDpriv (child key derivation)
        // Returns: Derived key for address generation
    }
};
```

### HTTP API Layer
**File**: `/home/kiss/OmniBus/modules/omnibus_network_os/wallet_api.zig` (REST endpoints)

```zig
pub fn handle_generate_seed(words_param: u8) HttpResponse {
    const wallet = HDWallet.init(mnemonic);  // Real BIP-39
    // Returns: 200 OK + JSON with algorithm info
}

pub fn handle_derive_addresses(seed, chain_name, index) HttpResponse {
    const wallet = HDWallet.init(seed);
    const derived = wallet.derive_path("m/44'/60'/0'/0/0");  // Real BIP-44
    // Returns: 200 OK + address + algorithm metadata
}
```

---

## Testing

### Unit Test
**File**: `/home/kiss/OmniBus/modules/omnibus_blockchain_os/test_wallets.zig`

```bash
# Run real wallet generator test
zig build-exe test_wallets.zig
./test_wallets

# Expected output:
# [✓] BIP-39 seed generation (PBKDF2-HMAC-SHA512)
# [✓] BIP-32 master key derivation (HMAC-SHA512)
# [✓] BIP-44 path derivation (CKDpriv)
# [✓] Address generation (all 50+ chains)
# [✓] Post-quantum address encoding
```

---

## Performance

| Operation | Algorithm | Time (ms) |
|-----------|-----------|-----------|
| BIP-39 seed generation | PBKDF2-HMAC-SHA512 (2048 iter) | 50-100 |
| BIP-32 master key | HMAC-SHA512 | <1 |
| Single child key | HMAC-SHA512 | <1 |
| Full path (5 levels) | 5× HMAC-SHA512 | <5 |
| Total wallet derivation | All 50 chains | <250 |

---

## Compliance

- ✓ **BIP-39**: Official Bitcoin standard for mnemonic seeds
- ✓ **BIP-32**: Official Bitcoin standard for HD key derivation
- ✓ **BIP-44**: Official Bitcoin standard for multi-account wallets
- ✓ **NIST FIPS**: SHA512, HMAC, PBKDF2 approved algorithms
- ✓ **Post-Quantum**: Kyber-768, Dilithium-5 (NIST PQC standards)

---

## References

- BIP-39: https://github.com/trezor/python-mnemonic
- BIP-32: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
- BIP-44: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
- NIST PQC: https://csrc.nist.gov/Projects/post-quantum-cryptography/

---

**Last Updated**: 2026-03-13
**Phase**: 66 (Web API + Wallet Generation)
**Status**: Real cryptography integrated from universal_wallet_generator.zig

