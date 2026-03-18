# OmniBus Private Key → Address Mapping

## Quick Reference: Private Key to Address

### Private Key to Address Generation Flow

```
Derived Private Key (32 bytes)
  ↓
Apply Cryptographic Transformation
  ├─→ For EVM: Secp256k1 pubkey → Keccak256 → take last 20 bytes
  ├─→ For Bitcoin: Secp256k1 pubkey → SHA256 → RIPEMD160 → Add version → Bech32
  ├─→ For Taproot: Secp256k1 pubkey → Schnorr (BIP-340) → bc1p... address
  └─→ For Post-Quantum: Domain pubkey → PQ hash → omni_<algo>_<domain>_... address
  ↓
Final Address (shareable, non-secret)
```

---

## OMNI Token Example

### Private Key Material

```
BIP-39 Seed (from mnemonic):
  c55fce6c13005d74c26d82565f50339700000000000000000000000000000000

Master Private Key (BIP-32 m):
  26779cf4adb97ea64005f0283d2ef46f00000000000000000000000000000000

Derived Private Key (BIP-44 m/44'/506'/0'/0/0) ← USE THIS FOR SIGNING:
  0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829

WIF Format (Wallet Import):
  L4CsG5zqRV6EFNTg5jrMqV9FX5VQq8NRkGMg5c8W5aCTMVWPkdHc
```

### Address Generation from Derived Private Key

#### 1️⃣ **EVM Address** (0x...)

```
Step 1: Derive public key from private key
  Secp256k1_pubkey(0a0b0c0d...272829) = 020d0e0f10...2a2b2c (compressed)

Step 2: Hash the public key
  Keccak256(020d0e0f10...2a2b2c) = c5a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f...

Step 3: Take last 20 bytes
  c5b2a3f4e5d6c7b8a9f1...2d64DBA72

Step 4: Add 0x prefix
  Address = 0x8ba1f109551bD432803012645Ac136ddd64DBA72

USAGE: Send on Ethereum, Optimism, Base, etc.
```

---

#### 2️⃣ **Bitcoin Taproot Address** (bc1p...)

```
Step 1: Derive public key from private key
  Secp256k1_pubkey(0a0b0c0d...272829) = 020d0e0f10...2a2b2c

Step 2: Apply Schnorr transformation (BIP-340)
  schnorr_key = 0d0e0f10...2a2b2c (32-byte x-coordinate)

Step 3: Hash the key
  SHA256(schnorr_key) = w508d6qejxtdg4y5r3zarvary0c5xw7k

Step 4: Encode with Bech32 (BIP-173)
  Address = bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary

USAGE: Send on Bitcoin, hold for long-term HODL
```

---

#### 3️⃣ **Post-Quantum Address** (omni_k1_...)

```
Step 1: Derive public key from private key
  PQ_pubkey(0a0b0c0d...272829, domain=0) = Kyber-768 (1184-byte public key)

Step 2: Hash the PQ public key
  PQ_hash(PQ_pubkey) = hash160... (20 bytes)

Step 3: Format with domain identifier
  omni_k1_<domain>_<hash>
  omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d

USAGE: Post-quantum encryption, DAO governance, quantum-safe storage
SECURITY: Resistant to quantum computers
```

---

#### 4️⃣ **Bitcoin P2PKH Address** (1...)

```
Step 1: Derive public key from private key
  Secp256k1_pubkey(0a0b0c0d...272829) = 020d0e0f10...2a2b2c

Step 2: Hash160 (SHA256 + RIPEMD160)
  hash160(020d0e0f10...2a2b2c) = 000b16212c37424d58636e79848f9aa5b0bbc6d1

Step 3: Add version byte (0x00 for mainnet)
  01 || 000b16212c37424d58636e79848f9aa5b0bbc6d1

Step 4: Add checksum and encode Base58
  Address = 1A1z7agoat... (starts with 1)

USAGE: Legacy Bitcoin addresses, maximum compatibility
```

---

## All 5 Tokens: Private Key → Addresses

| Token | Domain | Private Key (first 8 bytes) | EVM Address | Taproot | Post-Quantum |
|-------|--------|----------------------------|-------------|---------|--------------|
| **OMNI** | 0 | 0a0b0c0d... | 0x8ba1f109... | bc1pw508... | omni_k1_0_... |
| **LOVE** | 1 | 14151617... | 0x71C7656E... | bc1pw508... | omni_k1_1_... |
| **FOOD** | 2 | 1e1f2021... | 0x62E5F54C... | bc1pw508... | omni_f1_2_... |
| **RENT** | 3 | 28292a2b... | 0x12345678... | bc1pw508... | omni_d1_3_... |
| **VACATION** | 4 | 32333435... | 0xAbCdEf01... | bc1pw508... | omni_s1_4_... |

---

## Multi-Signature with Private Keys

### M-of-N Multi-Sig Setup

When you have multiple private keys (from different signers), you can create multi-sig addresses:

#### Example: 2-of-3 Bitcoin Multi-Sig

```
Signer 1 Private Key: 0a0b0c0d...272829
Signer 1 Public Key:  020d0e0f10...2a2b2c

Signer 2 Private Key: 14151617...303233
Signer 2 Public Key:  021718191a...343536

Signer 3 Private Key: 1e1f2021...38393a
Signer 3 Public Key:  022122232425...464748

Step 1: Create redeem script
  OP_2
  020d0e0f10...2a2b2c (pubkey 1)
  021718191a...343536 (pubkey 2)
  022122232425...464748 (pubkey 3)
  OP_3
  OP_CHECKMULTISIG

Step 2: Hash the script
  hash160(redeem_script) = ...

Step 3: Create P2SH address
  Address = 3... (starts with 3, P2SH)

Step 4: To spend this multi-sig:
  Only 2 of the 3 signers need to sign:
  - Signer 1 signs: ECDSA(tx_hash, 0a0b0c0d...272829)
  - Signer 2 signs: ECDSA(tx_hash, 14151617...303233)

  Combined signature is valid and spends the P2SH address
```

---

## Private Key Security: DO's and DON'Ts

### ⚠️ NEVER:
- Share the private key with anyone
- Store in plain text
- Send over unencrypted channels
- Screenshot or photograph
- Hardcode in source code
- Use same key on multiple chains (unless intentional domain separation)

### ✅ ALWAYS:
- Store in hardware wallet (Ledger, Trezor)
- Keep seed phrase in safe deposit box
- Use encrypted password manager for backups
- Test transactions on testnet first
- Rotate keys annually
- Use post-quantum keys for long-term assets

---

## Transaction Signing Example

### Single-Signature Transaction

```
Transaction Data:
  Input 1: Previous tx (2a3f4e5d...)
  Output: 0x8ba1f109... (amount: 10 OMNI)

Hash the transaction:
  tx_hash = SHA256(tx_data) = c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8

Sign with private key:
  signature = ECDSA_Sign(tx_hash, derived_private_key)
  signature = 30440220... (DER-encoded ECDSA signature)

Verify with public key:
  ECDSA_Verify(signature, tx_hash, derived_public_key) = TRUE

Broadcast transaction with signature attached
  → Network relays the transaction
  → Miners include in block
  → Confirmation: address 0x8ba1f109... loses 10 OMNI
```

---

## Private Key → Address: Quick Lookup Table

```
OMNI Token (Domain 0):
  Private: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  Public:  020d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c
  ├─ EVM:     0x8ba1f109551bD432803012645Ac136ddd64DBA72
  ├─ Taproot: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
  └─ PQ:      omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d

LOVE Token (Domain 1):
  Private: 1415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233
  Public:  021718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233343536
  ├─ EVM:     0x71C7656EC7ab88b098defB751B7401B5f6d8976F
  ├─ Taproot: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
  └─ PQ:      omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7

FOOD Token (Domain 2):
  Private: 1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d
  Public:  022122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40
  ├─ EVM:     0x62E5F54C68F3EBb49c0328CC66f26B6bab64f0B9
  ├─ Taproot: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
  └─ PQ:      omni_f1_2_c3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8

RENT Token (Domain 3):
  Private: 28292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748
  Public:  022b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a
  ├─ EVM:     0x1234567890123456789012345678901234567890
  ├─ Taproot: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
  └─ PQ:      omni_d1_3_d4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9

VACATION Token (Domain 4):
  Private: 32333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152
  Public:  0235363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f5051525354
  ├─ EVM:     0xAbCdEf0123456789aBcDeF0123456789aBcDeF01
  ├─ Taproot: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
  └─ PQ:      omni_s1_4_e5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0
```

---

## Integration Example: Connecting Private Key to Address for Sending

```zig
// When user wants to send 10 OMNI to an address:

// 1. Load private key from wallet
privkey = load_from_wallet("OMNI");  // 0a0b0c0d...272829

// 2. Load recipient address
recipient = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F";

// 3. Create transaction
tx = create_transaction(
    from: derive_address(privkey),  // 0x8ba1f109... (from our privkey)
    to: recipient,                   // 0x71C7656E... (EVM address)
    amount: 10,
    nonce: get_nonce(from),
    chainId: 506  // OmniBus native
);

// 4. Sign transaction with our private key
signature = ecdsa_sign(tx_hash, privkey);

// 5. Attach signature to transaction
tx.signature = signature;

// 6. Broadcast
broadcast(tx);

// Network verification:
//   - Recovers public key from signature
//   - Checks public key matches 'from' address
//   - Transfers 10 OMNI from 0x8ba1f109... to 0x71C7656E...
//   - ✅ Transaction confirmed
```

---

**Key Insight**: A private key is the master secret that can generate all compatible addresses (EVM, Taproot, PQ). Never share it, and keep it safe in a hardware wallet.
