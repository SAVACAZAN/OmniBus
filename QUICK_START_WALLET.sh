#!/bin/bash
# QUICK START: Client Wallet Generation & Sepolia Testing
# Usage: bash QUICK_START_WALLET.sh

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  OmniBus Phase 72: Client Wallet Setup & Testing Guide    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Build & Boot
echo "📦 Step 1: Building OmniBus..."
cd /home/kiss/OmniBus
make clean > /dev/null 2>&1 &
BUILD_PID=$!
wait $BUILD_PID

echo "🚀 Step 2: Booting QEMU (wait 15 seconds for wallet generation)..."
echo ""
echo "   → Watch for: [C]lient wallet registry ready"
echo "   → Then: [W]allet generated for client"
echo "   → Look for: [CLIENT WALLET] section with addresses"
echo ""

timeout 60 make qemu 2>&1 | tee qemu_wallet_output.log || true &
QEMU_PID=$!

# Give QEMU 15 seconds to generate wallet
sleep 15

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📋 YOUR WALLET ADDRESSES (extracted from QEMU):"
echo "════════════════════════════════════════════════════════════"
echo ""

# Extract addresses
ERC20_ADDR=$(grep -o "0x[a-f0-9]\{40\}" qemu_wallet_output.log 2>/dev/null | head -1 || echo "NOT FOUND")
QUANTUM_ADDR=$(grep -o "0x[a-f0-9]\{64\}" qemu_wallet_output.log 2>/dev/null | head -1 || echo "NOT FOUND")

echo "✓ ERC20 Address (Sepolia deposit address):"
echo "  $ERC20_ADDR"
echo ""
echo "✓ Quantum Address (OmniBus receiving address):"
echo "  $QUANTUM_ADDR"
echo ""

# Save to file
cat > YOUR_WALLET.txt <<EOF
═══════════════════════════════════════════════
     YOUR OMNIBUS CLIENT WALLET
═══════════════════════════════════════════════

Generated: $(date)
Client ID: 1
Name: User

ERC20 Address (Sepolia - send USDC.e here):
$ERC20_ADDR

Quantum Address (OmniBus - receive OMNI here):
$QUANTUM_ADDR

Network: Sepolia Testnet
USDC.e Contract: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
Infura RPC: https://sepolia.infura.io/v3/4f39f708444a45a881b0b65117675cec

═══════════════════════════════════════════════
NEXT STEPS:
═══════════════════════════════════════════════

1. Get Sepolia ETH (gas):
   https://www.alchemy.com/faucets/sepolia
   (Paste: $ERC20_ADDR)

2. Get USDC.e:
   https://www.lido.fi/bridge (Ethereum → Sepolia)
   or
   https://compound.finance/governance/comp

3. Send 0.1 USDC.e to your ERC20 Address:
   From: Your MetaMask wallet
   To: $ERC20_ADDR
   Amount: 0.1 USDC.e

4. Watch QEMU output for on-ramp confirmation:
   - "Transfer recorded at block XXX"
   - "OMNI minted: 100000000000000000"

5. Check Block Explorer in QEMU:
   Your Quantum Address balance: +100 million OMNI

═══════════════════════════════════════════════
EOF

echo "📄 Wallet saved to: YOUR_WALLET.txt"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎯 TESTING CHECKLIST:"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "□ Step 1: Boot QEMU (done above)"
echo "□ Step 2: Get Sepolia ETH from faucet"
echo "□ Step 3: Get USDC.e (bridge or faucet)"
echo "□ Step 4: Send 0.1 USDC.e to ERC20 address above"
echo "□ Step 5: Watch QEMU for 'Transfer recorded' message"
echo "□ Step 6: See OMNI minting confirmation"
echo "□ Step 7: Check block explorer shows OMNI balance"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "📊 QEMU IS RUNNING IN BACKGROUND:"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "To kill QEMU when done:"
echo "  pkill -f qemu-system"
echo ""
echo "To view QEMU output in real-time:"
echo "  tail -f qemu_wallet_output.log"
echo ""
echo "🚀 Ready! Head to CLIENT_WALLET_SETUP.md for full guide"
echo ""
