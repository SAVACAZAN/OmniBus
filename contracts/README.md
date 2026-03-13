# OmniBus Smart Contracts

## Overview

Three core smart contracts implement the OmniBus monetization system:

1. **StatusToken.sol** – Non-transferable status tokens (LOVE, FOOD, RENT, VACATION)
2. **TokenOnRamp.sol** – USDC deposit listener and status token minter
3. **StakingWithBoost.sol** – OMNI staking with status token APY multipliers

---

## Contract 1: StatusToken.sol

### Purpose
Non-transferable status token contract. Implements a modified ERC20 where tokens cannot be transferred, only minted and burned.

### Key Features
- ✅ Minting (by authorized minter only)
- ✅ Burning (by token holder)
- ❌ No transfers allowed
- ❌ No approvals allowed
- ✅ Ownership and minter management

### Public Functions

#### `mint(address _to, uint256 _amount)`
Mint new tokens (only minter can call)
```solidity
token.mint(0xUser..., ethers.parseEther('100'));
```

#### `burn(uint256 _amount)`
Burn tokens from caller
```solidity
token.burn(ethers.parseEther('50'));
```

#### `setMinter(address _newMinter)`
Set new minter address (only owner can call)
```solidity
token.setMinter(0xOnRamp...);
```

#### `balanceOf(address account)`
Get token balance
```solidity
const balance = await token.balanceOf(0xUser...);
```

### Events

```solidity
event Mint(address indexed to, uint256 amount);
event Burn(address indexed from, uint256 amount);
event MinterUpdated(address indexed newMinter);
event Transfer(address indexed from, address indexed to, uint256 value);
```

### Gas Usage (Approximate)
- Deployment: ~800,000 gas
- Mint: ~65,000 gas
- Burn: ~40,000 gas
- SetMinter: ~30,000 gas

---

## Contract 2: TokenOnRamp.sol

### Purpose
Listen for USDC deposits on Ethereum and Base chains, and mint equivalent status tokens on OmniBus.

### Key Features
- ✅ Multi-chain deposit tracking (Ethereum, Base)
- ✅ Token configuration management
- ✅ Revenue tracking and split (50/30/15/5)
- ✅ Deposit deduplication
- ✅ Minting authorization

### Public Functions

#### `mintFromDeposit(address _depositor, string memory _tokenName, uint256 _usdcAmount, bytes32 _txHash)`
Mint status tokens from USDC deposit (only agent/minter can call)
```solidity
onRamp.mintFromDeposit(
    0xUser...,
    "LOVE",
    ethers.parseUnits('100', 6),  // 100 USDC (6 decimals)
    0xTxHash...
);
```

#### `setTokenAddress(string memory _tokenName, address _statusTokenAddress, address _usdcAddress)`
Configure token contract addresses (only owner can call)
```solidity
onRamp.setTokenAddress(
    "LOVE",
    0xLoveToken...,
    0xUSDC...
);
```

#### `calculateRevenue(uint256 _depositAmount)`
Calculate revenue split for a deposit
```solidity
const (dao, liquidity, operator, dev) = onRamp.calculateRevenue(ethers.parseUnits('100', 6));
```

#### `getTokenConfig(string memory _tokenName)`
Get token configuration
```solidity
const config = await onRamp.getTokenConfig("LOVE");
```

#### `getDeposit(bytes32 _txHash)`
Get deposit details by transaction hash
```solidity
const deposit = await onRamp.getDeposit(0xTxHash...);
```

#### `getRevenueSummary()`
Get total revenue collected
```solidity
const (total, dao, liquidity, operator, dev) = await onRamp.getRevenueSummary();
```

### Events

```solidity
event DepositReceived(
    address indexed depositor,
    string tokenName,
    uint256 usdcAmount,
    uint256 statusTokenAmount,
    uint256 timestamp
);

event TokensMinted(
    address indexed recipient,
    string tokenName,
    uint256 amount,
    bytes32 indexed txHash
);

event ConfigUpdated(string tokenName, address statusTokenAddress);
```

### Gas Usage (Approximate)
- Deployment: ~1,200,000 gas
- MintFromDeposit: ~120,000 gas
- SetTokenAddress: ~80,000 gas
- GetTokenConfig: ~50,000 gas (view, no gas cost on call)

---

## Contract 3: StakingWithBoost.sol

### Purpose
Stake OMNI tokens and earn APY rewards, with multiplier boosts from status token holdings.

### Key Features
- ✅ OMNI staking with 10% base APY
- ✅ Status token boost multipliers (1.5x–2.5x)
- ✅ Compound rewards on claim
- ✅ Dynamic APY calculation
- ✅ Flexible stake/unstake

### Public Functions

#### `stake(uint256 _amount)`
Stake OMNI tokens
```solidity
staking.stake(ethers.parseEther('100'));
```

#### `claimRewards()`
Claim pending staking rewards
```solidity
staking.claimRewards();
```

#### `unstake(uint256 _amount)`
Unstake OMNI tokens (claims rewards first)
```solidity
staking.unstake(ethers.parseEther('50'));
```

#### `addBoost(string memory _tokenName, address _tokenAddress, uint256 _boostMultiplier)`
Add a status token boost configuration (only owner can call)
```solidity
staking.addBoost(
    "LOVE",
    0xLoveToken...,
    150  // 1.5x multiplier
);
```

#### `getBoostMultiplier(address _staker)`
Get current boost multiplier based on status token holdings
```solidity
const multiplier = await staking.getBoostMultiplier(0xUser...);
// 100 = 1.0x (no boost)
// 150 = 1.5x (LOVE holder)
// 200+ = Multiple tokens
```

#### `calculateRewards(address _staker)`
Calculate pending rewards
```solidity
const (baseReward, boostedReward, multiplier) = await staking.calculateRewards(0xUser...);
```

#### `getEffectiveAPY(address _staker)`
Get effective APY including boosts
```solidity
const apy = await staking.getEffectiveAPY(0xUser...);
// 100 = 10% APY
// 150 = 15% APY
// 200 = 20% APY
```

### APY Multipliers

```
Base APY: 10% per year

Status Token Boosts:
  LOVE:     1.5x → 15% APY
  FOOD:     1.8x → 18% APY
  RENT:     2.0x → 20% APY
  VACATION: 2.5x → 25% APY

Stacking:
  LOVE + FOOD: 10% × (1.5x + 1.8x) / 2 = 16.5% APY (simplified)
  All 4 tokens: 10% × 3.0x+ = 30%+ APY
```

### Events

```solidity
event Staked(address indexed staker, uint256 amount, uint256 timestamp);
event RewardsClaimed(address indexed staker, uint256 rewards, uint256 multiplier);
event Unstaked(address indexed staker, uint256 amount, uint256 timestamp);
event BoostAdded(string tokenName, address tokenAddress, uint256 multiplier);
```

### Gas Usage (Approximate)
- Deployment: ~1,000,000 gas
- Stake: ~85,000 gas
- ClaimRewards: ~90,000 gas
- Unstake: ~95,000 gas
- AddBoost: ~75,000 gas

---

## Deployment

### Prerequisites
```bash
npm install -D hardhat @nomicfoundation/hardhat-toolbox ethers
```

### Compile
```bash
npx hardhat compile
```

### Deploy
```bash
npx hardhat run scripts/deploy-status-tokens.js --network omnibus
```

### Verify
```bash
npx hardhat verify --network omnibus 0xContractAddress "constructor args"
```

---

## Security Considerations

### StatusToken
- ✅ Minting restricted to authorized minter only
- ✅ Non-transferability enforced at contract level
- ✅ Burning possible to reduce supply
- ❌ No upgrade mechanism (immutable)

### TokenOnRamp
- ✅ Double-spend prevention (processed flag)
- ✅ Multi-chain confirmation requirements
- ✅ Agent authorization checks
- ⚠️ Off-chain bridge trust required (agent service)

### StakingWithBoost
- ✅ Read-only access to status token balances
- ✅ No direct transfer of staked tokens
- ✅ Timestamp-based reward calculation
- ⚠️ No reentrancy guard (not needed, no external calls)

---

## Testing

```bash
# Run all tests
npm test

# Run specific test
npx hardhat test test/StatusToken.test.js

# Run with coverage
npx hardhat coverage
```

---

## Interfaces

### IERC20 (Partial)
Used for minimal ERC20 compatibility
```solidity
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
```

### IStatusToken
Used by OnRamp and Staking contracts
```solidity
interface IStatusToken {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}
```

---

## Integration Examples

### Minting Status Tokens
```javascript
const onRamp = await ethers.getContractAt('TokenOnRamp', '0x...');
await onRamp.mintFromDeposit(
    '0xUser...',
    'LOVE',
    ethers.parseUnits('100', 6),  // 100 USDC
    '0xTxHash...'
);
```

### Staking with Boosts
```javascript
const staking = await ethers.getContractAt('StakingWithBoost', '0x...');

// Stake
await staking.stake(ethers.parseEther('100'));

// Check boost
const boost = await staking.getBoostMultiplier('0xUser...');

// Get rewards
const (base, boosted, mult) = await staking.calculateRewards('0xUser...');

// Claim
await staking.claimRewards();
```

### Revenue Tracking
```javascript
const onRamp = await ethers.getContractAt('TokenOnRamp', '0x...');
const (total, dao, liquidity, operator, dev) = await onRamp.getRevenueSummary();

console.log(`Total Revenue: ${ethers.formatUnits(total, 6)} USDC`);
console.log(`DAO: ${ethers.formatUnits(dao, 6)} USDC`);
console.log(`Liquidity: ${ethers.formatUnits(liquidity, 6)} USDC`);
```

---

## Future Enhancements

- [ ] Token bridge for cross-chain status tokens
- [ ] Multi-sig vault for large revenue distributions
- [ ] Governance token minting based on revenue
- [ ] Automated fee distribution
- [ ] DAO treasury management
- [ ] Upgrade mechanism for bugfixes

---

## Files

```
contracts/
├── StatusToken.sol          # Non-transferable token (4 instances: LOVE, FOOD, RENT, VACA)
├── TokenOnRamp.sol          # USDC listener and minter (1 instance)
├── StakingWithBoost.sol     # Staking with boosts (1 instance)
└── README.md                # This file
```

---

**Version:** 1.0
**Solidity:** ^0.8.20
**License:** MIT
**Audited:** No (not production-ready until audited)

For full documentation, see [MONETIZATION_SYSTEM.md](../MONETIZATION_SYSTEM.md)
