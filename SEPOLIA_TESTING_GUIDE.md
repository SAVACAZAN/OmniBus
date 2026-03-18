# OmniBus Phase 72: Sepolia USDC On-Ramp Testing Guide

## Overview

This guide walks through testing the **USDC → OMNI bridge** with **real Ethereum Sepolia testnet**.

Agent wallet with:
- **1 ERC20 address** (Ethereum EOA) for USDC transfers on Sepolia
- **5 OMNI addresses** (post-quantum) for receiving native OMNI on OmniBus

---

## Part 1: Boot OmniBus and Extract Addresses

### Step 1: Start QEMU with Serial Output

```bash
cd /home/kiss/OmniBus
make qemu 2>&1 | tee qemu_boot.log &
```

Expected serial output:
```
[BOOT]  OmniBus Stage 1
[BOOT]  OmniBus Stage 2
[KERNEL] Protected mode enabled
[KERNEL] Paging initialized
[KERNEL] All 54 modules loaded
[KERNEL] OmniBus running v2.0.0
```

### Step 2: Monitor Agent Wallet Initialization

Watch for agent wallet export (from `agent_wallet.zig:export_to_log()`):

```
╔═══════════════════════════════════════════════════════════╗
║         OMNIBUS AGENT WALLET – MULTI-DOMAIN               ║
║    (BIP-39 + BIP-32 + Post-Quantum Cryptography)         ║
╚═══════════════════════════════════════════════════════════╝

📝 MNEMONIC (12 words, 128-bit entropy):
   abandon ability absence absorb abstract academy accept accident account achieve acid acoustic

🔑 MASTER SEED (first 16 bytes hex):
   60 3d eb 10 15 ca 67 14 bf d0 9c f7 07 bb 30 7f

💰 INITIAL BALANCE:
   1,000,000 OMNI (100,000,000,000 SAT)

💳 ERC20 ON-RAMP (Send USDC to buy OMNI):
   Ethereum Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72
   Networks: Ethereum, Optimism, Base (same address)

═══════════════════════════════════════════════════════════
🪙  CLASSICAL CHAINS (BIP-44)
═══════════════════════════════════════════════════════════

  Bitcoin
    Path: m/44'/0'/0'/0/0
    Address: bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4

  Ethereum
    Path: m/44'/60'/0'/0/0
    Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72

  ... (other classical chains) ...

═══════════════════════════════════════════════════════════
🔐 POST-QUANTUM DOMAINS (Non-Transferable, NIST PQ Crypto)
═══════════════════════════════════════════════════════════

omnibus.omni
  Algorithm: Dilithium-5 + Kyber-768 (Hybrid)
  Short ID: OMNI-5k7m-OMNI
  Address: ob_omni_5d7k768kyber5dil_native
  Pub Key: xxxx bytes | Secret Key: xxxx bytes
  Security: 256-bit quantum (native chain)

omnibus.love
  Algorithm: Kyber-768 (ML-KEM-768)
  Short ID: OMNI-4a8f-LOVE
  Address: ob_k1_2a5f8b1e9c3d6f4a7e2b5c8d1f4a7e2b
  Pub Key: 1184 bytes | Secret Key: 2400 bytes
  Security: 256-bit quantum

omnibus.food
  Algorithm: Falcon-512
  Short ID: OMNI-3b7c-FOOD
  Address: ob_f5_1b4e9d2a5f8c3e6b9d2f5a8c1e4b7d0f
  Pub Key: 897 bytes | Secret Key: 1281 bytes
  Security: 192-bit quantum

omnibus.rent
  Algorithm: Dilithium-5 (ML-DSA-5)
  Short ID: OMNI-6d2e-RENT
  Address: ob_d5_5c7a1f3d9e2b6f4a8c1d5e9f2a6c1d4f
  Pub Key: 2592 bytes | Secret Key: 4896 bytes
  Security: 256-bit quantum

omnibus.vacation
  Algorithm: SPHINCS+ (SLH-DSA-256)
  Short ID: OMNI-8f1a-VACA
  Address: ob_s3_9a2d5c1f4e7b2a5f8c3d6e9a1d4c7f2a
  Pub Key: 32 bytes | Secret Key: 64 bytes
  Security: 128-bit eternal

═══════════════════════════════════════════════════════════
✅ Agent wallet initialized. Ready for trading.
```

### Step 3: Extract Key Information

Save from serial output:
- **Agent ERC20 Address:** `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
- **5 OMNI Addresses:** (one per domain, prefixed with ob_)

---

## Part 2: Create Client Wallet on Sepolia

### Step 4: Get Sepolia Testnet USDC

1. **Request Sepolia ETH from faucet:**
   - Go to: https://sepoliafaucet.com/
   - Paste your MetaMask address (personal wallet, not agent)
   - Get ~0.5 ETH

2. **Get Sepolia USDC.e:**
   - Go to: https://sepolia-faucet.vercel.app/ (Aave Sepolia faucet)
   - Select "USDC" (token)
   - Paste your MetaMask address
   - Get 100 USDC.e

**OR** use contract directly:
```javascript
// In web3.py or ethers.js:
// USDC.e address on Sepolia: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
// Mint test USDC yourself using ABI
```

### Step 5: Verify USDC in MetaMask

1. Import USDC contract to MetaMask:
   - Token contract: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
   - Decimals: 6
   - Symbol: USDC

2. Confirm balance: Should see **100 USDC** in MetaMask

---

## Part 3: Test USDC → OMNI Bridge

### Step 6: Send USDC to Bridge Address

**Bridge Address (Agent's ERC20):**
```
0x8ba1f109551bD432803012645Ac136ddd64DBA72
```

In MetaMask:
1. Click "Send"
2. Paste bridge address: `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
3. Amount: **10 USDC** (10 × 10^6 units)
4. Confirm & send

**Transaction details:**
- To: `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
- Value: 10,000,000 (10 USDC with 6 decimals)
- Network: Sepolia (11155111)
- Gas: ~50,000-100,000 (standard transfer)

### Step 7: Monitor QEMU Serial Output

Watch for on-ramp detection:

```
===== USDC ERC20 ON-RAMP STATUS =====
Bridge Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72
USDC Contract: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

[TRANSFER STATISTICS]
Total USDC Received: 10000000 (with 6 decimals)
Total OMNI Minted: 10000000000000000000 (with 18 decimals)
Successful Mints: 1 | Pending: 0 | Failed: 0

[ETHEREUM STATUS]
Current Block: <block_number>
Last Polled: <block_number>
Polls Executed: <count>

[RECENT TRANSFERS]
Transfer 0: 10000000 USDC (MINTED)
Transfer 1: ...
```

### Step 8: Monitor Client Wallet Registry

Expected output:

```
===== CLIENT WALLET REGISTRY =====
Total Clients: 1
Total USDC Received: 10000000
Total OMNI Sent: 10000000000000000000

[RECENT CLIENTS]
Client 0: YourClientName
  ERC20: 0x8ba1f109551bD432803012645Ac136ddd...
```

---

## Part 4: Verify Complete Wallet

### Step 9: Display Full Client Wallet

Expected comprehensive output:

```
╔═══════════════════════════════════════════════════════════╗
║               CLIENT MULTI-DOMAIN WALLET                 ║
╚═══════════════════════════════════════════════════════════╝

ID: 0 | Name: TestClient

═══════════════════════════════════════════════════════════
📥 ERC20 ON-RAMP (Send USDC on Sepolia):
═══════════════════════════════════════════════════════════
0x8ba1f109551bD432803012645Ac136ddd64DBA72

═══════════════════════════════════════════════════════════
🔐 POST-QUANTUM DOMAINS (Receive OMNI):
═══════════════════════════════════════════════════════════

Domain 1: omnibus.omni
  Algorithm: Dilithium-5 + Kyber-768 (Hybrid)
  Address: ob_omni_<hash>
  Security: 256-bit quantum (native chain)

Domain 2: omnibus.love
  Algorithm: Kyber-768 (ML-KEM-768)
  Address: ob_k1_<hash>
  Security: 256-bit quantum

Domain 3: omnibus.food
  Algorithm: Falcon-512
  Address: ob_f5_<hash>
  Security: 192-bit quantum

Domain 4: omnibus.rent
  Algorithm: Dilithium-5 (ML-DSA-5)
  Address: ob_d5_<hash>
  Security: 256-bit quantum

Domain 5: omnibus.vacation
  Algorithm: SPHINCS+ (SLH-DSA-256)
  Address: ob_s3_<hash>
  Security: 128-bit eternal

═══════════════════════════════════════════════════════════
💰 BALANCE & ACTIVITY:
═══════════════════════════════════════════════════════════
Total USDC Received: 10000000
Total OMNI Minted: 10000000000000000000
```

---

## Part 5: Repeat Tests (Multiple Clients)

### Step 10: Create Additional Clients

In OmniBus:
```zig
const client2 = client_wallet.generate_client_wallet(1, "Client2", 7);
const client3 = client_wallet.generate_client_wallet(2, "Client3", 7);
```

Each client gets:
- Unique ERC20 address (derived from client_id)
- 5 unique OMNI addresses (different hash per domain)
- Independent USDC/OMNI tracking

### Step 11: Test Multiple Transfers

Send USDC from different MetaMask accounts to each client's ERC20 address:
- Client 1: 10 USDC → ob_omni_... receives 10,000,000,000,000,000,000 SAT (10 OMNI)
- Client 2: 20 USDC → ob_omni_... receives 20,000,000,000,000,000,000 SAT (20 OMNI)
- Client 3: 5 USDC → ob_omni_... receives 5,000,000,000,000,000,000 SAT (5 OMNI)

Verify registry:
```
Total Clients: 3
Total USDC Received: 35000000
Total OMNI Sent: 35000000000000000000
```

---

## Part 6: Debugging & Troubleshooting

### Issue: "USDC not detected"

1. **Verify bridge address:**
   - Check: `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
   - Should match `ETH_BRIDGE_ADDRESS` in `usdc_erc20_onramp.zig`

2. **Verify USDC contract:**
   - Sepolia USDC.e: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
   - Should match `USDC_CONTRACT_ETH` in code

3. **Check Infura RPC:**
   - API key: `4f39f708444a45a881b0b65117675cec`
   - Endpoint: `https://sepolia.infura.io/v3/4f39f708444a45a881b0b65117675cec`
   - Test: `curl https://sepolia.infura.io/v3/4f39f708444a45a881b0b65117675cec -X POST ...`

4. **Verify transaction on Sepolia:**
   - Go to: https://sepolia.etherscan.io/
   - Search for bridge address: `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
   - Should see incoming USDC transfers

### Issue: "OMNI not minted"

1. **Check block finality:** Requires 6 blocks on Sepolia
2. **Verify client lookup:** Check `find_client_by_erc20()` logic
3. **Inspect transaction:** Should execute `record_usdc_transfer()` and `record_omni_transfer()`

### Issue: "Address format wrong"

1. **ERC20 addresses:** Must be lowercase `0x<40 hex chars>`
2. **OMNI addresses:** Must start with correct prefix:
   - `ob_omni_` (hybrid)
   - `ob_k1_` (Kyber-768)
   - `ob_f5_` (Falcon-512)
   - `ob_d5_` (Dilithium-5)
   - `ob_s3_` (SPHINCS+)

---

## Expected Timeline

| Step | Action | Time |
|------|--------|------|
| 1-3 | Boot QEMU, extract addresses | ~2 min |
| 4 | Get Sepolia ETH | ~5 min (faucet) |
| 5 | Get USDC | ~5 min (faucet) |
| 6-7 | Send USDC → bridge | ~30 sec (tx) + 12 sec (6 blocks) |
| 8 | Verify registry | ~1 min |
| 9 | Display full wallet | ~1 min |
| **Total** | | **~25-30 minutes** |

---

## Success Criteria

✅ **Agent wallet initialized with:**
- 1 ERC20 address (0x format)
- 5 OMNI addresses (ob_* format, one per domain)
- Correct algorithms per domain
- Proper security levels

✅ **USDC transfer detected:**
- Show in `USDC ERC20 ON-RAMP STATUS`
- Count incremented: "Total USDC Received"
- Transfer status: MINTED (not PENDING/FAILED)

✅ **OMNI minted correctly:**
- Amount scaled from 6 decimals → 18 decimals
- 10 USDC = 10 × 10^12 SAT = 10,000,000,000,000,000,000 SAT
- Recorded in client wallet registry

✅ **Client wallet displays all 5 domains:**
- Each domain with correct algorithm
- Each with unique address
- All with ob_* prefix format

---

## Next Steps (Phase 73+)

1. **Real testnet deployment:** Test against public Sepolia RPC
2. **Multi-client on-ramp:** Support arbitrary client generation
3. **Mainnet migration:** Switch to Ethereum mainnet (chain ID 1)
4. **DEX integration:** Swap USDC ↔ other assets on Uniswap
5. **Governance:** DAO voting on on-ramp parameters

---

**Documentation:** Phase 72 Client Multi-Domain Wallet
**Created:** 2026-03-18
**Testnet:** Ethereum Sepolia (11155111)
**Bridge Address:** 0x8ba1f109551bD432803012645Ac136ddd64DBA72
