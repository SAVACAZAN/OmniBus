# OmniBus Monetization System – Complete Implementation Guide

## Overview

The OmniBus monetization system enables users to earn **status tokens** (LOVE, FOOD, RENT, VACATION) through USDC deposits on Ethereum and Base, with smart contract boost multipliers for staking.

**Key Features:**
- ✅ Non-transferable status tokens (cannot be sent, only minted)
- ✅ Agent-based on-ramp (listens for USDC deposits → mints tokens)
- ✅ Staking rewards with multiplier boosts
- ✅ Revenue sharing (50% DAO, 30% liquidity, 15% operators, 5% development)
- ✅ Post-quantum cryptography integration (domain-specific algorithms)
- ✅ Independent network addresses (no cross-chain bridges)

---

## Architecture

### System Components

```
User → USDC Transfer → ETH/Base Agent Address
         ↓
      Agent Service
    (listens for deposits)
         ↓
    Verify Confirmation
         ↓
   Mint Status Tokens → OmniBus Chain
         ↓
    User Receives
   Non-Transferable Token
         ↓
   Stake in Smart Contract
   (get APY boost multipliers)
```

### Token Types

#### 1. OMNI (Transferable)
- **Type:** Utility/Governance token
- **Supply:** 21 million (fixed, like Bitcoin)
- **Networks:** OmniBus native only
- **Use Cases:**
  - Transfer between wallets
  - Trading on DEX
  - Paying for gas
  - DAO governance voting
  - Staking for rewards

#### 2. LOVE, FOOD, RENT, VACATION (Non-Transferable Status Tokens)
- **Type:** Non-transferable incentive tokens
- **Mint Method:** USDC deposit on ETH/Base → automatic minting on OmniBus
- **Networks:** OmniBus only (no bridges to other chains)
- **Use Cases:**
  - Smart contract boost multipliers (staking APY)
  - Governance participation (voice, no transfer)
  - Status/reputation indicators
  - Community participation proof

#### 3. Post-Quantum Cryptography Binding
- **LOVE:** Kyber-768 (ML-KEM) encryption
- **FOOD:** Falcon-512 (FN-DSA) signing
- **RENT:** Dilithium-5 (ML-DSA) signing
- **VACATION:** SPHINCS+ (SLH-DSA) hash-based signing

---

## Smart Contracts

### 1. StatusToken.sol

**Purpose:** Non-transferable token contract for LOVE, FOOD, RENT, VACATION

```solidity
contract StatusToken is IERC20 {
    // Key functions:
    - mint(address _to, uint256 _amount)  // Only minter (on-ramp)
    - burn(uint256 _amount)                // User can burn their tokens
    - transfer() → reverts              // Non-transferable
    - approve() → reverts               // Cannot be approved
}
```

**Deployment:** 4 separate contracts on OmniBus
```
LOVE:     0x...
FOOD:     0x...
RENT:     0x...
VACATION: 0x...
```

### 2. TokenOnRamp.sol

**Purpose:** Listen for USDC deposits and mint status tokens

```solidity
contract TokenOnRamp {
    // Key functions:
    - mintFromDeposit(
        address _depositor,
        string memory _tokenName,
        uint256 _usdcAmount,
        bytes32 _txHash
      )                                  // Called by agent service

    - calculateRevenue(_depositAmount)   // Revenue split calculation
    - getTokenConfig(string memory _tokenName)  // Token info
    - getDeposit(bytes32 _txHash)       // Deposit tracking
}
```

**Deployment:** 1 contract on OmniBus

### 3. StakingWithBoost.sol

**Purpose:** Stake OMNI and earn APY with status token boost multipliers

```solidity
contract StakingWithBoost {
    // Key functions:
    - stake(uint256 _amount)             // Stake OMNI
    - claimRewards()                     // Claim APY rewards
    - unstake(uint256 _amount)           // Unstake OMNI
    - getBoostMultiplier(address _staker) → uint256  // Check boost
    - calculateRewards(address _staker)  // Calculate pending rewards
    - getEffectiveAPY(address _staker)   // Get effective APY with boosts
}
```

**Base APY:** 10% per year
**Boost Multipliers:**
- LOVE holder: +1.5x (15% APY)
- FOOD holder: +1.8x (18% APY)
- RENT holder: +2.0x (20% APY)
- VACATION holder: +2.5x (25% APY)
- Multiple tokens: Multipliers stack (can reach 3.0x+)

**Deployment:** 1 contract on OmniBus

---

## Agent Service

### Purpose
Listen for USDC deposits on Ethereum and Base chains, verify confirmations, and trigger status token minting on OmniBus.

### Components

#### 1. **Event Monitoring**
- Ethereum: Monitor `Transfer(from, to, value)` to agent address
- Base: Monitor same event to agent address
- Block polling interval: 12 seconds
- Real-time block listeners (fallback)

#### 2. **Confirmation Verification**
- Ethereum: Wait for 12 confirmations (~3 minutes)
- Base: Wait for 3 confirmations (~18 seconds)
- Only mint if transaction status = SUCCESS

#### 3. **Minting Trigger**
- Call `TokenOnRamp.mintFromDeposit()` on OmniBus
- 1:1 conversion ratio (1 USDC = 1 status token)
- Log transaction to local database

### Environment Setup

```bash
# Install dependencies
npm install ethers dotenv

# Create .env file
cp .env.example .env

# Fill in values:
ETHEREUM_RPC=https://eth.llamarpc.com
BASE_RPC=https://mainnet.base.org
OMNIBUS_RPC=http://localhost:8545
AGENT_PRIVATE_KEY=0x...
ON_RAMP_ADDRESS=0x...
```

### Start Service

```bash
node services/agent-on-ramp-service.js
```

**Output:**
```
🚀 Initializing Agent On-Ramp Service...
✓ Connected to Ethereum
✓ Connected to Base
✓ Agent wallet: 0x...
👂 Starting to listen for USDC deposits...

💰 USDC Deposit Detected on ETHEREUM
   Token: LOVE
   From: 0xUser...
   Amount: 100 USDC
   Tx: 0xabcd...
   ✓ Confirmed with 12 confirmations

🔄 Minting LOVE on OmniBus...
   Tx submitted: 0x1234...
   ✓ Minting complete!
```

---

## Deployment Instructions

### Prerequisites
```bash
npm install -g hardhat
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install dotenv
```

### Step 1: Deploy Status Tokens on OmniBus

```bash
# Compile contracts
npx hardhat compile

# Deploy to OmniBus
npx hardhat run scripts/deploy-status-tokens.js --network omnibus
```

**Output:**
```
🚀 Deploying Status Tokens on OmniBus...
Deployer: 0x...
Network: omnibus

📦 Deploying LOVE...
   ✓ Deployed at 0x...
   Post-Quantum Algorithm: Kyber-768

📦 Deploying FOOD...
   ✓ Deployed at 0x...
   Post-Quantum Algorithm: Falcon-512

📦 Deploying RENT...
   ✓ Deployed at 0x...
   Post-Quantum Algorithm: Dilithium-5

📦 Deploying VACATION...
   ✓ Deployed at 0x...
   Post-Quantum Algorithm: SPHINCS+

📦 Deploying TokenOnRamp...
   ✓ Deployed at 0x...

📦 Deploying StakingWithBoost...
   ✓ Deployed at 0x...
```

### Step 2: Update .env

```bash
# Copy deployment addresses to .env
LOVE_OMNIBUS_ADDRESS=0x...
FOOD_OMNIBUS_ADDRESS=0x...
RENT_OMNIBUS_ADDRESS=0x...
VACATION_OMNIBUS_ADDRESS=0x...
ON_RAMP_ADDRESS=0x...
STAKING_ADDRESS=0x...
```

### Step 3: Start Agent Service

```bash
node services/agent-on-ramp-service.js
```

---

## Revenue Model

### Per User Deposit

**Example: $100 USDC deposit**

```
Gross deposit:        $100.00
ETH gas fees:        -$3.00  (typical)
Net profit:           $97.00

Distribution (50/30/15/5 split):
  DAO Treasury:       $48.50 (50%)
  Liquidity Pool:     $29.10 (30%)
  Operators:          $14.55 (15%)
  Development:         $4.85 (5%)
```

### At Scale

**100 users × $100 USDC deposits = $10,000 total**

```
Net profit:           $9,700
  DAO:                $4,850
  Liquidity:          $2,910
  Operators:          $1,455
  Development:          $485
```

### Revenue Tracking

The `TokenOnRamp` contract tracks all revenue:

```solidity
// Check revenue
(uint256 total, uint256 dao, uint256 liquidity, uint256 operator, uint256 dev)
  = onRamp.getRevenueSummary();
```

---

## User Flow Example

### Scenario: User Wants to Earn RENT Status Tokens

**Step 1: User Prepares**
- Has OmniBus wallet address: `0x...` (generated from BIP-39 seed)
- Has 100 USDC on Ethereum or Base

**Step 2: User Sends USDC**
- Sends 100 USDC to agent address for RENT token
- Example:
  ```
  To: 0xAgent_RENT_Address_123...
  Amount: 100 USDC
  Tx: 0xabc123...
  ```

**Step 3: Agent Detects & Confirms**
- Agent listens for incoming transfers
- Detects RENT deposit after 12 confirmations (Ethereum)
- Verifies transaction status = SUCCESS

**Step 4: Status Tokens Minted**
- Agent calls `TokenOnRamp.mintFromDeposit()`
- 100 RENT tokens minted to user's OmniBus address
- User receives non-transferable RENT on OmniBus

**Step 5: User Stakes**
- User stakes 100 OMNI in `StakingWithBoost`
- RENT balance provides 2.0x APY multiplier
- Base APY 10% × 2.0x = 20% effective APY
- User earns ~20 OMNI per year

**Step 6: Revenue Recorded**
- Transaction logged to `on-ramp-transactions.jsonl`
- Revenue split recorded:
  - DAO: $48.50
  - Liquidity: $29.10
  - Operators: $14.55
  - Development: $4.85

---

## Integration Points

### For Wallet Providers

```javascript
// Initialize on-ramp deposit
const usdcAmount = ethers.parseUnits('100', 6);  // 100 USDC
const tokenName = 'RENT';
const agentAddress = '0x...';  // Provided by OmniBus

// User sends USDC to agentAddress
// Status tokens automatically minted on OmniBus
```

### For DEX/Exchanges

```solidity
// Check if user has status token boosts
uint256 boost = staking.getBoostMultiplier(userAddress);
// 100 = 1.0x (no boost)
// 150 = 1.5x (LOVE holder)
// 200+ = Multi-token holder

// Apply boost in trading fees
uint256 tradeFee = baseFee * boost / 100;
```

### For DAO Governance

```solidity
// Status tokens provide voting power
uint256 love = loveToken.balanceOf(voter);
uint256 food = foodToken.balanceOf(voter);
uint256 rent = rentToken.balanceOf(voter);
uint256 vaca = vacaToken.balanceOf(voter);

uint256 votingPower = (love + food + rent + vaca) / 1e18;
// User can vote once per token held
```

---

## Security Considerations

### 1. Non-Transferability Enforcement
- Smart contract reverts on `transfer()` call
- Cannot be sent to another address
- Cannot be approved for spending
- Only way to "move" is burn and re-mint via on-ramp

### 2. Minter Authorization
- Only `TokenOnRamp` contract can mint
- Only agent service can call `mintFromDeposit()`
- Owner can update minter address if key rotation needed

### 3. Deposit Verification
- Multi-chain confirmation requirements
- Transaction hash deduplication
- Processed flag prevents double-minting
- Logs audit trail in JSONL format

### 4. Post-Quantum Readiness
- Each token uses different NIST PQC algorithm
- Future-proof against quantum attacks
- Separate key hierarchy per algorithm
- Domain separation ensures no cross-algorithm attacks

---

## Testing

### Unit Tests

```bash
# Test status token
npx hardhat test test/StatusToken.test.js

# Test on-ramp
npx hardhat test test/TokenOnRamp.test.js

# Test staking
npx hardhat test test/StakingWithBoost.test.js
```

### Integration Tests

```bash
# Full flow: Deposit → Mint → Stake
npx hardhat test test/integration.test.js
```

### Agent Service Tests

```bash
# Mock USDC transfer and verify minting
node test/agent-on-ramp.test.js
```

---

## Monitoring

### Agent Service Health

```bash
# Check service status
curl http://localhost:3000/health

# Response:
{
  "service": "Agent On-Ramp",
  "status": "running",
  "chains": {
    "ethereum": { "lastBlock": 19425801, "connected": true },
    "base": { "lastBlock": 12895430, "connected": true },
    "omnibus": { "connected": true }
  },
  "processedTransactions": 247,
  "timestamp": "2026-03-13T10:45:23.456Z"
}
```

### Transaction Logs

```bash
# View on-ramp transactions
tail -f logs/on-ramp-transactions.jsonl

# Output:
{"timestamp":"2026-03-13T10:45:00Z","depositor":"0x...","tokenName":"LOVE","usdcAmount":"100","statusTokenAmount":"100","sourceChain":"ethereum","sourceChainTx":"0x...","omnibusTx":"0x...","status":"SUCCESS"}
```

### Smart Contract Events

```solidity
// DepositReceived event
event DepositReceived(
    address indexed depositor,
    string tokenName,
    uint256 usdcAmount,
    uint256 statusTokenAmount,
    uint256 timestamp
);

// RewardsClaimed event
event RewardsClaimed(
    address indexed staker,
    uint256 rewards,
    uint256 multiplier
);
```

---

## Troubleshooting

### Issue: Agent not detecting USDC transfers
**Solution:**
1. Verify agent wallet address is set correctly in code
2. Check RPC endpoint connectivity: `npx hardhat test --network ethereum`
3. Verify USDC contract address for the chain
4. Check agent has sufficient ETH/Base for gas fees

### Issue: Status tokens not minting after deposit
**Solution:**
1. Check `ON_RAMP_ADDRESS` is set correctly in agent
2. Verify on-ramp has minter role in status token contracts
3. Check OmniBus RPC is accessible
4. Review agent logs in `logs/on-ramp-transactions.jsonl`

### Issue: Staking rewards not calculating correctly
**Solution:**
1. Verify status token address is set in staking contract
2. Check status token balances: `balanceOf(userAddress)`
3. Verify time elapsed calculation (use local timestamp)
4. Check APY multiplier: `getBoostMultiplier(userAddress)`

---

## Future Enhancements

### Phase 2: Token Bridges
- Wrap status tokens for cross-chain liquidity
- Maintain original token on OmniBus
- Wrapped version can be transferred on other chains

### Phase 3: DAO Staking
- Stake OMNI and earn governance power
- Vote on revenue distribution
- Manage agent and contract parameters

### Phase 4: AMM Integration
- Add liquidity pools for status tokens
- Swap between status tokens
- Swap status tokens for OMNI

### Phase 5: Multi-Signature Vaults
- Multi-sig wallet for revenue distribution
- Required approvals for large transfers
- Security-audited vault contracts

---

## References

- **PRIVATE_KEY_ADDRESS_MAPPING.md** – Address generation from private keys
- **OMNIBUS_WALLET_METADATA_SUMMARY.md** – Complete wallet metadata spec
- **CRYPTO_ALGORITHMS.md** – Post-quantum cryptography details
- **WHITEPAPER.md** – Complete OmniBus v2.0.0 specification

---

**Deployment Date:** 2026-03-13
**Version:** 1.0
**Status:** Production Ready
**Author:** OmniBus AI Team
