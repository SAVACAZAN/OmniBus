# Quick Start: OmniBus Monetization System

**Time to deployment:** ~30 minutes

---

## Prerequisites

```bash
# Node.js 18+
node --version

# npm 9+
npm --version

# Hardhat installed globally (optional, but helpful)
npm install -g hardhat
```

---

## Installation

### 1. Install Dependencies

```bash
cd /home/kiss/OmniBus
npm install
```

**Expected output:**
```
added 250 packages
```

### 2. Compile Contracts

```bash
npx hardhat compile
```

**Expected output:**
```
Compiling 3 contracts
✔ Compilation successful
```

---

## Deployment

### 3. Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit .env with your values
nano .env
```

**Required fields:**
```
OMNIBUS_RPC=http://localhost:8545
DEPLOYER_PRIVATE_KEY=0x...
AGENT_PRIVATE_KEY=0x...
ON_RAMP_ADDRESS=0x...
```

### 4. Deploy Contracts

```bash
npx hardhat run scripts/deploy-status-tokens.js --network omnibus
```

**Expected output:**
```
🚀 Deploying Status Tokens on OmniBus...
Deployer: 0x...
Network: omnibus

📦 Deploying LOVE...
   ✓ Deployed at 0x...

📦 Deploying FOOD...
   ✓ Deployed at 0x...

📦 Deploying RENT...
   ✓ Deployed at 0x...

📦 Deploying VACATION...
   ✓ Deployed at 0x...

📦 Deploying TokenOnRamp...
   ✓ Deployed at 0x...

📦 Deploying StakingWithBoost...
   ✓ Deployed at 0x...

✅ Deployment Complete!
📄 Deployment saved to: ./deployments/omnibus-1710325523456.json
```

### 5. Update .env with Deployment Addresses

```bash
# Copy from deployment output
LOVE_OMNIBUS_ADDRESS=0x...
FOOD_OMNIBUS_ADDRESS=0x...
RENT_OMNIBUS_ADDRESS=0x...
VACATION_OMNIBUS_ADDRESS=0x...
ON_RAMP_ADDRESS=0x...
STAKING_ADDRESS=0x...
```

---

## Start Agent Service

### 6. Run Agent

```bash
node services/agent-on-ramp-service.js
```

**Expected output:**
```
🚀 Initializing Agent On-Ramp Service...
✓ Connected to Ethereum
✓ Connected to Base
✓ Agent wallet: 0x...
✓ Starting Ethereum at block 19425801
✓ Starting Base at block 12895430

📡 Agent On-Ramp Service initialized successfully

👂 Starting to listen for USDC deposits...
```

### 7. Send Test USDC (Development)

In another terminal:

```bash
# For Sepolia testnet USDC, send to agent address
npx hardhat run scripts/send-test-usdc.js --network sepolia
```

**You should see in agent terminal:**
```
💰 USDC Deposit Detected on ETHEREUM
   Token: LOVE
   From: 0x...
   Amount: 100 USDC
   Tx: 0x...
   ✓ Confirmed with 12 confirmations

🔄 Minting LOVE on OmniBus...
   ✓ Minting complete!
```

---

## Verify Deployment

### 8. Check Status Tokens

```bash
# In Hardhat console
npx hardhat console --network omnibus

# Inside console:
const love = await ethers.getContractAt('StatusToken', '0x...');
const balance = await love.balanceOf('0xUser...');
console.log(balance.toString());
```

### 9. Check Staking

```bash
# Check user's boost multiplier
const staking = await ethers.getContractAt('StakingWithBoost', '0x...');
const multiplier = await staking.getBoostMultiplier('0xUser...');
console.log(multiplier.toString()); // 150 = 1.5x
```

### 10. Check Revenue

```bash
# Check total revenue collected
const onRamp = await ethers.getContractAt('TokenOnRamp', '0x...');
const revenue = await onRamp.getRevenueSummary();
console.log({
  total: revenue[0].toString(),
  dao: revenue[1].toString(),
  liquidity: revenue[2].toString(),
  operator: revenue[3].toString(),
  development: revenue[4].toString(),
});
```

---

## Common Commands

### Development

```bash
# Compile contracts
npm run compile

# Run tests
npm test

# Deploy to testnet
npm run deploy:sepolia
npm run deploy:base-sepolia

# Start local hardhat node
npm run node:hardhat
```

### Agent Service

```bash
# Start agent (production)
npm run agent

# Start agent with auto-reload (development)
npm run agent:dev

# Run agent tests
npm test test/agent-on-ramp.test.js
```

### Contract Management

```bash
# Verify contract on Etherscan
npm run verify -- 0xContractAddress "Constructor Arguments"

# Generate gas report
npm run gas-report

# Generate documentation
npm run docs
```

---

## Monitoring

### Check Agent Health

```bash
# Terminal 1: Start agent
npm run agent

# Terminal 2: Monitor logs
tail -f logs/on-ramp-transactions.jsonl

# See formatted output
tail -f logs/on-ramp-transactions.jsonl | jq .
```

### Monitor Smart Contract Events

```bash
# In hardhat console
const onRamp = await ethers.getContractAt('TokenOnRamp', '0x...');

const depositFilter = onRamp.filters.DepositReceived();
const events = await onRamp.queryFilter(depositFilter, 0, 'latest');
events.forEach(e => console.log(e.args));
```

---

## Troubleshooting

### Issue: "Cannot connect to OmniBus RPC"

```bash
# Check RPC is running
curl http://localhost:8545

# If error, start OmniBus node:
make qemu  # from OmniBus root directory
```

### Issue: "Minting failed"

```bash
# Check on-ramp has minter permission
const token = await ethers.getContractAt('StatusToken', '0x...');
const minter = await token.minter();
console.log(minter);  // Should match ON_RAMP_ADDRESS
```

### Issue: "Agent not detecting deposits"

```bash
# Check agent wallet has balance
const balance = await ethers.provider.getBalance('0xAgent...');
console.log(ethers.formatEther(balance));  // Should be > 0
```

---

## Example: Full User Flow

### Step 1: User Receives USDC on Ethereum

```
0xUser123... receives 100 USDC
```

### Step 2: User Sends to Agent

```
Send 100 USDC to 0xAgent...
Tx: 0xabc...
```

### Step 3: Agent Detects & Confirms

```
Agent sees deposit after 12 blocks
Verifies transaction successful
```

### Step 4: Status Tokens Minted

```
Agent calls: TokenOnRamp.mintFromDeposit(0xUser..., "LOVE", 100e6, 0xabc...)
100 LOVE minted to user on OmniBus
```

### Step 5: User Stakes

```
User stakes 100 OMNI on OmniBus
Gets 10% base APY
With LOVE (1.5x multiplier) = 15% APY
```

### Step 6: Revenue Recorded

```
$100 deposit - $3 gas = $97 profit
DAO:          $48.50
Liquidity:    $29.10
Operators:    $14.55
Development:  $4.85
```

---

## Files Created

```
contracts/
  ├── StatusToken.sol              # Non-transferable token contract
  ├── TokenOnRamp.sol              # USDC deposit listener & minter
  └── StakingWithBoost.sol         # Staking with boost multipliers

scripts/
  └── deploy-status-tokens.js      # Deployment script

services/
  └── agent-on-ramp-service.js     # USDC listener and minting agent

.env.example                        # Environment configuration template
package.json                        # Dependencies and scripts
hardhat.config.js                   # Hardhat configuration
MONETIZATION_SYSTEM.md              # Complete documentation
QUICK_START_MONETIZATION.md         # This file
```

---

## Next Steps

1. **Customize Revenue Split** – Edit staking multipliers in `deploy-status-tokens.js`
2. **Add Webhook Notifications** – Notify users when tokens are minted
3. **Integrate with UI** – Show status token balances and APY in wallet
4. **Multi-Sig Vaults** – Secure large revenue distributions
5. **DAO Governance** – Vote on revenue allocation and parameters

---

## Support

- **Documentation:** See `MONETIZATION_SYSTEM.md`
- **Smart Contracts:** See `contracts/` directory
- **Agent Service:** See `services/agent-on-ramp-service.js`
- **Examples:** See git history for deployment logs

---

**Ready to deploy?** → `npm run deploy:omnibus` 🚀
