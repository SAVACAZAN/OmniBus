# Phase 72: Sepolia Testnet Testing Guide 🧪

**Goal**: Test OmniBus USDC on-ramp with **real Sepolia ETH transfers**

---

## ⚡ Quick Start (5 minutes)

### Step 1: Get Infura API Key
```bash
# 1. Go to https://www.infura.io
# 2. Sign up (free account)
# 3. Create project → "OmniBus Sepolia Test"
# 4. Copy API Key (looks like: abc123def456...)
```

### Step 2: Update OmniBus Config
Edit `modules/omnibus_blockchain_os/ethereum_rpc_client.zig`:

```zig
pub const SEPOLIA_CONFIG = EthereumConfig{
    .network = Network.SEPOLIA,
    .chain_id = 11155111,
    .rpc_url = "https://sepolia.infura.io/v3/YOUR_INFURA_KEY_HERE".*,  // ← REPLACE THIS
    .rpc_url_len = 51 + @intCast(YOUR_KEY_LENGTH),
    .usdc_contract = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238".*,  // USDC.e on Sepolia
    .usdc_len = 42,
};
```

### Step 3: Get Sepolia ETH + USDC.e
```bash
# Sepolia Testnet ETH (faucets):
# - https://www.alchemy.com/faucets/sepolia (free, 0.5 ETH/day)
# - https://sepoliafaucet.com (free, 0.05 ETH)
# - https://faucetlink.to/sepolia (free, 0.05 ETH)

# Sepolia USDC.e (bridged stablecoin):
# - Use Compound: https://compound.finance/governance/comp
#   OR Coinbase testnet faucet
#   OR bridge from Ethereum Sepolia testnet USDC
```

### Step 4: Build + Boot
```bash
cd /home/kiss/OmniBus
make clean && make build
make qemu
```

### Step 5: Send Test USDC
In separate terminal:
```bash
# Get your Sepolia wallet (MetaMask or Ethers.js)
# Send 1 USDC.e to bridge address:
#   0x8ba1f109551bD432803012645Ac136ddd64DBA72

# Monitor QEMU output for:
# - [U] USDC on-ramp initialized
# - "Transfer recorded: 1000000 USDC.e"
# - "OMNI minted: 1000000000000000000"
```

---

## 🔍 Testing Checklist

- [ ] Infura RPC endpoint responding to `eth_blockNumber`
- [ ] Block height updating in OmniBus (show in block explorer)
- [ ] Send 0.1 USDC.e to bridge address
- [ ] OmniBus detects Transfer event within 3 blocks
- [ ] OMNI minted = USDC sent × 1e12 (decimal conversion)
- [ ] Agent balance increases in block explorer
- [ ] 10 more transfers received and processed
- [ ] No RPC errors in status display

---

## 🎯 Expected Output (QEMU Serial)

```
[BOOT] OmniBus Stage 1
[BOOT] OmniBus Stage 2
[KERNEL] Protected mode enabled
[KERNEL] Paging initialized
[KERNEL] Long mode enabled

G...Z...W...B...N...
[ETHEREUM RPC] Network: Sepolia (Chain ID: 11155111)
[ETHEREUM RPC] Current Block: 5432100 | Last Polled: 5432099
[USDC ONRAMP] Total USDC Received: 1000000 (with 6 decimals)
[USDC ONRAMP] Total OMNI Minted: 1000000000000000000 (with 18 decimals)
[USDC ONRAMP] Successful Mints: 1 | Pending: 0 | Failed: 0
[BLOCK EXPLORER] Current Height: 42 | Agent Balance: 1000001000000000000 OMNI
```

---

## 📊 Monitoring Real Transactions

### Check Sepolia Etherscan:
```
https://sepolia.etherscan.io/tx/YOUR_TX_HASH
```

Look for:
- **Status**: Success ✓
- **From**: Your wallet
- **To**: 0x8ba1f109551bD432803012645Ac136ddd64DBA72
- **Token**: USDC.e (0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
- **Value**: 1000000 (1 USDC.e)
- **Block Number**: Increment by Confirmation Depth (6 blocks for finality)

### Verify OmniBus Received It:
1. QEMU should show: "Transfer recorded at block XXX"
2. Block explorer displays new transfer in [RECENT TRANSFERS]
3. Agent balance increases by equivalent OMNI

---

## 🔐 Security Checklist

- ✅ Test with **small amounts first** (0.01 USDC.e, not 100)
- ✅ Verify bridge address **exactly**: `0x8ba1f109551bD432803012645Ac136ddd64DBA72`
- ✅ Use **Sepolia testnet only** (not mainnet)
- ✅ Monitor QEMU for errors: "RPC Error", "Invalid response", "Connection timeout"
- ✅ Check Etherscan to confirm your TX reached blockchain
- ✅ Don't expose API key (keep in local config, not in git)

---

## 🚨 Troubleshooting

### "RPC Error: Connection refused"
```
→ Check Infura status: https://status.infura.io
→ Verify API key is correct (no typos)
→ Network may be congested, wait 1 minute
```

### "Transfer recorded but OMNI not minted"
```
→ Check confirmation depth (may need 6+ blocks)
→ Verify recipient address matches ETH_BRIDGE_ADDRESS
→ Check QEMU for parsing errors in JSON response
```

### "Block height not updating"
```
→ eth_blockNumber RPC call failing (see errors above)
→ QEMU showing "Poll error" or "Connection timeout"
→ Try manual test: curl https://sepolia.infura.io/v3/YOUR_KEY \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### "OMNI amount wrong (not 1:1 conversion)"
```
→ Check decimal conversion logic:
   amount_usdc (6 decimals) × 10^12 = amount_omni (18 decimals)
   1 USDC.e = 1,000,000 units = 1,000,000,000,000,000,000 OMNI units
→ Verify in usdc_erc20_onramp.zig line ~179
```

---

## 📈 Performance Expectations

| Metric | Target | Sepolia | Mainnet |
|--------|--------|---------|---------|
| Block time | ~12s | ~12s | ~12s |
| Confirmation depth | 6-12 blocks | 6 blocks | 12 blocks |
| Poll latency | <5s | ~3-5s | ~3-5s |
| RPC response time | <2s | <2s | <2s |
| OMNI mint time | <1s | <1s | <1s |
| End-to-end | 1-2 min | 1-2 min | 2-3 min |

---

## 🎬 Next Steps After Successful Test

1. **Phase 73**: Enhance JSON parsing + error handling
2. **Phase 74**: Test with 10+ USDC transfers (stress test)
3. **Phase 75**: Mainnet dry-run with $10 USDC transfer
4. **Phase 76**: Production mainnet with full security

---

## 📝 Test Log Template

```
Date: 2026-03-18
Network: Sepolia (11155111)
API Key: infura_YOUR_KEY
Bridge Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72

Test 1: Send 0.1 USDC.e
  TX Hash: 0x...
  From: 0x...
  Block: 5432100
  OmniBus detected: YES / NO
  OMNI minted: 100000000000000000 / Expected: 100000000000000000
  Status: PASS / FAIL

Test 2: Send 1.0 USDC.e
  [Same format as Test 1]

Notes:
- RPC latency: ~2.3s
- Confirmation time: ~75 seconds (6 blocks)
- No errors observed ✓
```

---

## 🔗 Useful Links

- **Sepolia Faucet**: https://www.alchemy.com/faucets/sepolia
- **Sepolia Etherscan**: https://sepolia.etherscan.io
- **Infura Status**: https://status.infura.io
- **USDC.e Contract**: https://sepolia.etherscan.io/token/0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
- **Bridge Address**: https://sepolia.etherscan.io/address/0x8ba1f109551bD432803012645Ac136ddd64DBA72
- **OmniBus GitHub**: https://github.com/SAVACAZAN/OmniBus

---

## 💡 Pro Tips

1. **Use MetaMask** for easy Sepolia switching:
   - Add network: https://chainlist.org (search "Sepolia")
   - Get testnet ETH from faucet
   - Send USDC.e to bridge address

2. **Monitor gas prices**: Sepolia is free but good to optimize
   - Standard transfer: ~21,000 gas
   - USDC.e transfer: ~65,000 gas

3. **Keep terminal open**: Watch QEMU output in real-time
   - See block explorer updates
   - Monitor RPC latency
   - Catch any errors

4. **Save successful TX hashes**: For documentation and audit trail

---

**Ready? Send us USDC on Sepolia! 🚀**
