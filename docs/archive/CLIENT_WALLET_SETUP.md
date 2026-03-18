# Phase 72: Client Wallet Setup & Sepolia Testing Guide 🚀

**Goal**: Generate your personal client wallet and test USDC on-ramp with real Sepolia testnet transfers.

---

## ⚡ Step 1: Boot OmniBus & Capture Wallet Addresses (2 minutes)

```bash
cd /home/kiss/OmniBus
make clean && make build
make qemu 2>&1 | tee qemu_output.log &
sleep 15
```

**Watch for boot sequence** in QEMU serial output:
```
[BOOT] OmniBus Stage 1
[BOOT] OmniBus Stage 2
[KERNEL] Protected mode enabled
...
[C]lient wallet registry ready
[W]allet generated for client
...
===== CLIENT WALLET REGISTRY =====
```

**Extract Your Addresses** (from QEMU output):

Look for:
```
[CLIENT WALLET]
ID: 1 | Name: User
ERC20 (send USDC here): 0x...42... (42 chars)
Quantum (receive OMNI): 0x...66... (66 chars)
```

**Save These Addresses**:
```bash
# Create a local file with your addresses
cat > MY_WALLET.txt <<'EOF'
Client ID: 1
Name: User
ERC20 Address (Sepolia deposit):
0x[PASTE_FROM_QEMU_OUTPUT]

Quantum Address (OmniBus receipt):
0x[PASTE_FROM_QEMU_OUTPUT]

Chain: Sepolia Testnet
USDC Contract: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
Bridge Endpoint: Infura wss://sepolia.infura.io/v3/4f39f708444a45a881b0b65117675cec
EOF
```

---

## 💰 Step 2: Get Sepolia Assets (5-10 minutes)

### Get Sepolia ETH (needed for gas)

Pick ONE:
```
1. Alchemy Faucet (FAST, 0.5 ETH/day)
   https://www.alchemy.com/faucets/sepolia
   → Paste your ERC20 address
   → Claim 0.5 ETH
   → Wait ~30 seconds

2. Sepolia Faucet (Alternative, 0.05 ETH)
   https://sepoliafaucet.com

3. Faucet Link (Alternative, 0.05 ETH)
   https://faucetlink.to/sepolia
```

### Get Sepolia USDC.e (the stablecoin)

**Option A: Bridge from Mainnet USDC** (Recommended)
```
1. Go to: https://www.lido.fi/bridge (or Stargate)
2. Select: Ethereum → Sepolia
3. Send: 1 USDC from mainnet
4. Receive: 1 USDC.e on Sepolia (in ~5 min)
```

**Option B: Testnet Faucet**
```
Go to: https://compound.finance/governance/comp
→ Request testnet USDC.e
```

---

## 🔗 Step 3: Send USDC.e to Your ERC20 Address (3 minutes)

Use **MetaMask** or **Ethers.js**:

```javascript
// Example: Send 0.1 USDC.e using Ethers.js
const contract = new ethers.Contract(
  "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",  // USDC.e
  ["function transfer(address to, uint256 amount) returns (bool)"],
  signer
);

const tx = await contract.transfer(
  "0xYOUR_ERC20_ADDRESS_FROM_QEMU",  // YOUR address
  ethers.parseUnits("0.1", 6)  // 0.1 USDC.e
);
```

Or use **MetaMask**:
1. Add Sepolia network if needed: https://chainlist.org (search "Sepolia")
2. Import USDC.e token: Contract `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
3. Send 0.1 USDC.e to **YOUR ERC20 ADDRESS**
4. Wait for confirmation (~12 seconds on Sepolia)

**Track TX** on Etherscan:
```
https://sepolia.etherscan.io/tx/YOUR_TX_HASH
```

Look for:
```
Status: ✓ Success
From: Your wallet (0x...)
To: YOUR_ERC20_ADDRESS (from QEMU)
Token: USDC.e (0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
Value: 0.1 (or 100000 in base units)
```

---

## 👀 Step 4: Watch QEMU for On-Ramp Confirmation (1-2 minutes)

**In QEMU serial output, watch for**:

```
===== USDC ERC20 ON-RAMP STATUS =====
Bridge Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72

[TRANSFER STATISTICS]
Total USDC Received: 100000 (with 6 decimals)  ← YOUR 0.1 USDC
Total OMNI Minted: 100000000000000000 (with 18 decimals)

Successful Mints: 1 | Pending: 0 | Failed: 0

[ETHEREUM STATUS]
Current Block: 5432100 | Last Polled: 5432099
Polls Executed: 256

[RECENT TRANSFERS]
Transfer 0: 100000 USDC (MINTED) → 100000000000000000 OMNI
```

**And in BLOCK EXPLORER**:
```
===== BLOCK EXPLORER =====
[RECENT BLOCKS]
Block 42: Agent balance: 100001000000000000 OMNI
Block 41: ...
Block 40: ...

[AGENT BALANCE]
OMNI: 100001000000000000
Blocks Mined: 43
```

---

## ✅ Expected Timeline

| Step | Time | Status |
|------|------|--------|
| Boot QEMU | 0-15s | `[W]allet generated` |
| Copy addresses | 15-30s | Have ERC20 + Quantum |
| Get Sepolia ETH | 30-90s | Faucet request |
| Get USDC.e | 2-5m | Bridge or faucet |
| Send 0.1 USDC.e | 5m | TX pending |
| Confirm on Etherscan | 5-20s | TX success ✓ |
| QEMU detects transfer | 20s-2m | Poll cycle finds it |
| OMNI minted | <1s after detect | Status shows +0.1 OMNI |
| **TOTAL** | **5-10 minutes** | **Complete!** |

---

## 🔍 Troubleshooting

### "Can't find my ERC20 address in QEMU output"
```bash
# Search output log
grep "ERC20" qemu_output.log
# or
grep "send USDC" qemu_output.log
```

### "Faucet says 'already claimed'"
```
→ Faucets have rate limits
→ Try different faucet or wait 24h
→ Alternative: Swap ETH for USDC.e on testnet DEX
```

### "USDC.e arrived in wallet but OMNI didn't mint"
```
Check:
1. Did you send to the CORRECT ERC20 address? (copy-paste)
2. Is QEMU still running? (check if still polling)
3. QEMU needs ~6 blocks confirmation (30-60 seconds)
4. Check Etherscan: https://sepolia.etherscan.io/tx/YOUR_HASH
   → Is it "Success"? (not pending/failed)
5. Watch QEMU for: "Transfer recorded at block XXX"
```

### "QEMU shows transfer but OMNI amount wrong"
```
Check decimal conversion:
- You sent 0.1 USDC (6 decimals) = 100,000 units
- Should mint 0.1 OMNI (18 decimals) = 100,000,000,000,000,000 units
- Multiply by 1e12 (10^12)

If wrong: check usdc_erc20_onramp.zig line 179
```

---

## 📊 What's Happening Behind the Scenes

1. **You send USDC.e to YOUR_ERC20_ADDRESS on Sepolia**
   ```
   TX: Sepolia blockchain
   From: Your MetaMask wallet
   To: YOUR_ERC20_ADDRESS (generated by OmniBus)
   Amount: 0.1 USDC.e (100,000 units)
   ```

2. **QEMU polls Ethereum RPC every 16 cycles**
   ```
   Call: eth_getLogs
   Filter: USDC.e contract → YOUR_ERC20_ADDRESS
   Response: Found your Transfer event
   ```

3. **Agent detects transfer, looks up client**
   ```
   Sender: YOUR_ERC20_ADDRESS
   Lookup: client_wallet registry
   Found: Client ID 1, Quantum Address 0xQua...
   ```

4. **Agent mints OMNI and sends to YOUR Quantum Address**
   ```
   Mint: 100,000 × 1e12 = 100,000,000,000,000,000 OMNI
   Send to: YOUR_QUANTUM_ADDRESS
   Block: 42 (OmniBus internal blockchain)
   ```

5. **You receive OMNI on OmniBus blockchain**
   ```
   Wallet: YOUR_QUANTUM_ADDRESS
   Balance: +100,000,000,000,000,000 OMNI
   Status: Confirmed in Block Explorer
   ```

---

## 🎯 Success Criteria

**Test passes when**:
- ✅ QEMU boots and displays both addresses
- ✅ You have Sepolia ETH + USDC.e in your wallet
- ✅ TX sent to YOUR_ERC20_ADDRESS confirms on Etherscan
- ✅ QEMU detects transfer within 2 minutes
- ✅ OMNI balance shows on block explorer
- ✅ Amount is correct: 0.1 USDC.e = 100M OMNI

---

## 🚀 Next Steps (After Successful Test)

1. **Send 10 More Transfers** (stress test)
   - Vary amounts: 0.01, 0.05, 0.5, 1.0, etc.
   - Verify all mint correctly
   - Monitor QEMU stability

2. **Test with Different Client** (multi-user)
   - Generate Client ID 2 in code
   - Send from different address
   - Verify routing to correct Quantum address

3. **Mainnet Dry-Run** (Phase 73)
   - Small USDC transfer ($1-$5)
   - Real ETH gas costs (~$5)
   - Verify end-to-end on mainnet

---

## 📝 Test Log Template

Save this after testing:

```
Date: 2026-03-18
Chain: Sepolia
Network: Testnet

CLIENT WALLET:
- Client ID: 1
- ERC20 Address: 0x...
- Quantum Address: 0x...

FIRST TRANSFER:
- USDC Amount: 0.1 USDC.e
- TX Hash: 0x...
- Etherscan: https://sepolia.etherscan.io/tx/0x...
- Status: ✓ Success
- Block: 5432100

QEMU DETECTION:
- Detected: YES
- Block Confirmed: 5432106 (6 block finality)
- OMNI Minted: 100000000000000000
- Time to detect: ~45 seconds

RESULT: ✅ PASS - On-ramp working correctly
```

---

**Ready to test? Let me know when you have your addresses! 🎯**
