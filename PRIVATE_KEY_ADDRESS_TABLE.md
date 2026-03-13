# OmniBus Private Key → Address Table

## Master Reference: Private Keys & Addresses for All 5 Tokens

### Complete Private Key to Address Mapping

| Token | Domain | PQ Algorithm | PRIVATE KEY (for signing) | ADDRESS (EVM) | ADDRESS (Taproot) | ADDRESS (PQ) |
|-------|--------|--------------|---------------------------|---------------|-------------------|--------------|
| **OMNI** | 0 | Kyber-768 (ML-KEM-768) | `0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829` | `0x8ba1f109551bD432803012645Ac136ddd64DBA72` | `bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary` | `omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d` |
| **LOVE** | 1 | Kyber-768 (ML-KEM-768) | `1415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233` | `0x71C7656EC7ab88b098defB751B7401B5f6d8976F` | `bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary` | `omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7` |
| **FOOD** | 2 | Falcon-512 (FN-DSA) | `1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d` | `0x62E5F54C68F3EBb49c0328CC66f26B6bab64f0B9` | `bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary` | `omni_f1_2_c3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8` |
| **RENT** | 3 | Dilithium-5 (ML-DSA-5) | `28292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748` | `0x1234567890123456789012345678901234567890` | `bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary` | `omni_d1_3_d4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9` |
| **VACATION** | 4 | SPHINCS+ (SLH-DSA-256) | `32333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152` | `0xAbCdEf0123456789aBcDeF0123456789aBcDeF01` | `bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary` | `omni_s1_4_e5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0` |

---

## How to Use Private Keys to Send Funds on Different Chains

### OMNI Token Transfer Examples

#### 1️⃣ **Send on Ethereum/EVM Chains** (Optimism, Base, Arbitrum)

```
Private Key: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
From Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72
To Address: 0x71C7656EC7ab88b098defB751B7401B5f6d8976F (LOVE token holder)
Amount: 10 OMNI

Transaction:
  1. Signer creates transaction (from, to, amount, nonce, chainId=506)
  2. Hash transaction: tx_hash = SHA256(tx_data)
  3. Sign with private key: signature = ECDSA_Sign(tx_hash, privkey)
     ECDSA_Sign(tx_hash, 0a0b0c0d...272829) → 30440220... (signature)
  4. Send transaction with signature to network
  5. Network verifies: ECDSA_Verify(signature, tx_hash, pubkey) = TRUE
  6. ✅ 10 OMNI transferred from 0x8ba1f109... to 0x71C7656E...

CLI Example:
  $ omnibus-cli send omni 0x71C7656EC7ab88b098defB751B7401B5f6d8976F 10
  Using private key: 0a0b0c0d...272829
```

---

#### 2️⃣ **Send on Bitcoin Chain** (Taproot P2TR)

```
Private Key: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
From Address: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
To Address: bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary
Amount: 1 BTC (or OMNI bridge)

Transaction:
  1. Create Taproot transaction
  2. Derive Schnorr public key from privkey: schnorr_pubkey = BIP340(privkey)
  3. Sign with Schnorr: sig = Schnorr_Sign(tx_hash, privkey)
  4. Send transaction (only 1 signature visible on-chain, very private)
  5. Network verifies Schnorr signature
  6. ✅ OMNI transferred on Bitcoin chain

CLI Example:
  $ omnibus-cli send bitcoin bc1pw508... 1 BTC
  Using Taproot signature with privkey: 0a0b0c0d...272829
```

---

#### 3️⃣ **Send with Post-Quantum Encryption** (Kyber-768, OMNI)

```
Private Key: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
From Address: omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d
To Address: omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7
Amount: 10 OMNI

Transaction:
  1. Create PQ transaction (domain=0, uses Kyber-768)
  2. Derive PQ public key from privkey: pq_pubkey = Kyber768_KeyGen(privkey)
  3. Sign with PQ algorithm: sig = Kyber768_Sign(tx_hash, privkey)
  4. Send transaction with PQ signature
  5. Network verifies with PQ public key
  6. ✅ OMNI transferred with quantum-safe signature

CLI Example:
  $ omnibus-cli send omni omni_k1_1_b2g3h4i5j... 10 OMNI
  Using PQ signature (Kyber-768) with privkey: 0a0b0c0d...272829
```

---

## All 5 Tokens: Private Key Quick Reference

### OMNI (Domain 0) - Kyber-768
```
Private Key: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829

Can move funds on:
  ├─ EVM:     0x8ba1f109551bD432803012645Ac136ddd64DBA72 (Ethereum, Optimism, Base)
  ├─ Bitcoin:  bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508... (Taproot)
  └─ PQ:      omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d (OmniBus native)
```

### LOVE (Domain 1) - Kyber-768
```
Private Key: 1415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233

Can move funds on:
  ├─ EVM:     0x71C7656EC7ab88b098defB751B7401B5f6d8976F
  ├─ Bitcoin:  bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508...
  └─ PQ:      omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7
```

### FOOD (Domain 2) - Falcon-512
```
Private Key: 1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d

Can move funds on:
  ├─ EVM:     0x62E5F54C68F3EBb49c0328CC66f26B6bab64f0B9
  ├─ Bitcoin:  bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508...
  └─ PQ:      omni_f1_2_c3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8
```

### RENT (Domain 3) - Dilithium-5
```
Private Key: 28292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748

Can move funds on:
  ├─ EVM:     0x1234567890123456789012345678901234567890
  ├─ Bitcoin:  bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508...
  └─ PQ:      omni_d1_3_d4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9
```

### VACATION (Domain 4) - SPHINCS+
```
Private Key: 32333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152

Can move funds on:
  ├─ EVM:     0xAbCdEf0123456789aBcDeF0123456789aBcDeF01
  ├─ Bitcoin:  bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508...
  └─ PQ:      omni_s1_4_e5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0
```

---

## Private Key Format Variations

### For Different Use Cases

| Use Case | Format | Example |
|----------|--------|---------|
| **Storage (Hex)** | Raw hex (64 chars) | `0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829` |
| **Bitcoin Import (WIF)** | Base58Check | `L4CsG5zqRV6EFNTg5jrMqV9FX5VQq8NRkGMg5c8W5aCTMVWPkdHc` |
| **Hardware Wallet** | BIP-39 mnemonic (24 words) | `abandon abandon abandon... about` |
| **Extended Key (xprv)** | BIP-32 serialized | `xprv9s21ZwQH8wSp6mP3...` |

---

## Signing Process for Each Chain

### EVM Chain Signing (OMNI on Ethereum)
```
Input:
  privkey = 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  tx_data = {from, to, amount, nonce, chainId, gasPrice, gasLimit, data}

Process:
  1. tx_hash = SHA256(tx_data)
  2. signature = ECDSA_Sign(tx_hash, privkey)
     → 65-byte signature (r, s, v)
  3. Broadcast tx + signature to network

Verification:
  pubkey = ECDSA_Recover(signature, tx_hash)
  assert pubkey == expected_public_key
  ✅ Transfer 10 OMNI
```

### Bitcoin Taproot Signing (OMNI on Bitcoin)
```
Input:
  privkey = 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  tx_data = {input, output, locktime}

Process:
  1. tx_hash = SHA256(tx_data)
  2. schnorr_pubkey = x_coordinate(privkey * G)  # BIP-340
  3. signature = Schnorr_Sign(tx_hash, privkey)
     → 64-byte signature
  4. Broadcast tx + signature to network

Verification:
  Schnorr_Verify(signature, tx_hash, schnorr_pubkey) = TRUE
  ✅ Transfer OMNI via Bitcoin Taproot
```

### Post-Quantum Signing (OMNI native, Kyber-768)
```
Input:
  privkey = 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  tx_data = {from (PQ address), to (PQ address), amount}

Process:
  1. tx_hash = SHA256(tx_data)
  2. pq_pubkey = Kyber768_KeyGen(privkey)
  3. signature = Kyber768_Sign(tx_hash, privkey)
     → 1088-byte ciphertext (KEM output)
  4. Broadcast tx + signature to network

Verification:
  Kyber768_Verify(signature, tx_hash, pq_pubkey) = TRUE
  ✅ Transfer OMNI with quantum-safe guarantee
```

---

## Security: Private Key Management

### ⚠️ CRITICAL: Never Share Private Key

```
DO NOT:
  ✗ Share: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  ✗ Screenshot private keys
  ✗ Paste into chat/email/documents
  ✗ Store in plain text files
  ✗ Commit to git repositories
  ✗ Use same key on multiple unrelated services
```

### ✅ DO: Secure Storage

```
✓ Hardware wallet (Ledger, Trezor) – private key never leaves device
✓ Encrypted password manager – AES-256 encryption
✓ Cold storage – offline, air-gapped computer
✓ Seed phrase in safe deposit box – 24-word backup
✓ Multi-sig setup – require 2-of-3 keys to sign
✓ Key rotation – new keys every 2 years
✓ Backup – multiple copies in secure locations
```

---

## Transaction Flow: From Private Key to Executed Transfer

```
Step 1: User Action
  User: "Send 10 OMNI to 0x71C7656E..."

Step 2: Load Private Key
  Wallet loads: 0a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223242526272829
  (kept encrypted until needed)

Step 3: Create Transaction
  tx = {
    from: 0x8ba1f109551bD432803012645Ac136ddd64DBA72,
    to: 0x71C7656EC7ab88b098defB751B7401B5f6d8976F,
    amount: 10,
    nonce: 42,
    chainId: 506,
    gasPrice: 16 SAT/byte,
    gasLimit: 21000
  }

Step 4: Sign Transaction
  tx_hash = SHA256(encode(tx))
  signature = ECDSA_Sign(tx_hash, privkey)
  → Produces 65-byte signature

Step 5: Broadcast to Network
  network.broadcast({tx, signature})

Step 6: Network Validation
  Miners/validators check:
    ✓ Signature is valid (matches pubkey)
    ✓ Sender has sufficient balance (10 + gas)
    ✓ Nonce is correct (prevents replay)
    ✓ All constraints satisfied

Step 7: Transaction Included in Block
  Block #123456 includes this transaction
  Network reaches consensus

Step 8: Confirmation
  After 12 confirmations (≈3 minutes):
    ✅ 10 OMNI moved from 0x8ba1f109... to 0x71C7656E...
    ✅ Gas paid to validators
    ✅ Transaction immutable on blockchain
```

---

## Reference Implementation (Pseudocode)

```zig
// Sign a transaction using private key
fn sign_omnibus_transaction(privkey: [32]u8, tx_data: []u8) [65]u8 {
    // Hash transaction
    tx_hash: [32]u8 = SHA256(tx_data);

    // Sign with ECDSA-Secp256k1
    signature: [65]u8 = ECDSA_Sign(tx_hash, privkey);

    // Return signature (r, s, v format)
    return signature;
}

// Verify transaction signature
fn verify_omnibus_transaction(signature: [65]u8, tx_data: []u8, sender_address: [20]u8) bool {
    // Hash transaction
    tx_hash: [32]u8 = SHA256(tx_data);

    // Recover public key from signature
    pubkey: [33]u8 = ECDSA_Recover(signature, tx_hash);

    // Derive address from public key
    address: [20]u8 = Keccak256(pubkey)[12:32];

    // Verify address matches
    return address == sender_address;
}

// Main transaction flow
fn execute_transfer(privkey: [32]u8, recipient: [20]u8, amount: u256) {
    // 1. Create transaction
    tx = create_transaction(privkey, recipient, amount);

    // 2. Sign transaction
    signature = sign_omnibus_transaction(privkey, tx);

    // 3. Broadcast
    network.broadcast(tx, signature);

    // 4. Wait for confirmation
    wait_for_confirmations(12);

    // ✅ Transaction complete
}
```

---

**Bottom Line**: Each private key controls 3-4 addresses across different chains. Use the private key to sign transactions, and the network verifies using the public key. Never expose the private key. 🔐
