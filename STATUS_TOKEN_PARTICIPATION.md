# Status Token Distribution – Participation & Activity Rewards

**Status:** Complete ✅
**Module:** Status Token Rewards OS (0x5A0000–0x5AFFFF)
**IPC Opcodes:** 0xB1–0xB8

---

## Overview

Status tokens (LOVE, FOOD, RENT, VACATION) are earned through **active participation** in OmniBus ecosystem:

1. ✅ **On-Ramp** (existing) – USDC deposit → status tokens
2. ✅ **Validator Participation** → LOVE tokens
3. ✅ **Mining** → FOOD tokens
4. ✅ **DApp Interaction** → RENT tokens
5. ✅ **Transaction Activity** → VACATION tokens
6. ✅ **Staking Bonuses** → Extra LOVE
7. ✅ **Liquidity Provision** → Extra FOOD

---

## Participation Types & Rewards

### 1️⃣ Validator Participation → LOVE Tokens

**Who:** Nodes running validator (proof-of-stake)

**Earning:**
- 100 LOVE per epoch (∼1000 blocks)
- +1 level per 50 participations
- +3 levels per 100 participations

**Example:**
```
User runs validator node
Block 0–999: Validator validates blocks
Block 1000 (end of epoch): +100 LOVE

User stays as validator for 50 epochs:
Total LOVE: 50 × 100 = 5,000 LOVE
Participation level: 5
```

**Incentive:** Secure network, earn rewards

---

### 2️⃣ Mining → FOOD Tokens

**Who:** Miners producing blocks (proof-of-work)

**Earning:**
- 10 FOOD per block mined
- Bonus for fast block times
- Extra for network difficulty

**Example:**
```
User mines 1 block:
+10 FOOD

User mines 1,000 blocks (∼3 months):
Total FOOD: 1,000 × 10 = 10,000 FOOD
```

**Incentive:** Maintain network security, earn rewards

---

### 3️⃣ DApp Interaction → RENT Tokens

**Who:** Users calling smart contracts, using DApps

**Earning:**
- 1 RENT per smart contract call
- Scales with DApp complexity
- Tracking engagement

**Example:**
```
User calls smart contract:
+1 RENT

User interacts with DApp 500 times (monthly):
Total RENT: 500 × 1 = 500 RENT
Participation level: 5 (active user)
```

**Incentive:** Engage with ecosystem, improve DApp network

---

### 4️⃣ Transaction Activity → VACATION Tokens

**Who:** Users making transfers (any amount)

**Earning:**
- 0.5 VACATION per transaction
- 1.5x bonus for medium transactions (100+ OMNI)
- 2x bonus for large transactions (1000+ OMNI)

**Example:**
```
Small transaction (10 OMNI):
+0.5 VACATION

Medium transaction (100 OMNI):
+0.75 VACATION (1.5x boost)

Large transaction (1000 OMNI):
+1.0 VACATION (2x boost)

User makes 100 transactions/month:
- 50 small: 50 × 0.5 = 25 VACATION
- 30 medium: 30 × 0.75 = 22.5 VACATION
- 20 large: 20 × 1.0 = 20 VACATION
Total: 67.5 VACATION/month
```

**Incentive:** Active trading, network utility

---

### 5️⃣ Long-Term Staking → Bonus LOVE

**Who:** Users staking OMNI for extended periods

**Bonus Multiplier:**
- 3+ months: 1.5x LOVE rewards
- 6+ months: 2.0x LOVE rewards
- 1+ year: 3.0x LOVE rewards

**Example:**
```
User stakes 100 OMNI for 6 months:
Base LOVE from validation: 100
Staking bonus: 100 × 2.0x = 200 LOVE
Total: 300 LOVE from same participation

User stakes 100 OMNI for 1 year:
Base LOVE from validation: 100
Staking bonus: 100 × 3.0x = 300 LOVE
Total: 400 LOVE from same participation
```

**Incentive:** Long-term commitment, network stability

---

### 6️⃣ Liquidity Provision → Bonus FOOD

**Who:** Users providing DEX liquidity

**Bonus Multiplier:**
- 1K–10K OMNI: 1.5x FOOD
- 10K–100K OMNI: 2.0x FOOD
- 100K+ OMNI: 2.5x FOOD

**Example:**
```
User provides 50K OMNI liquidity:
Base FOOD from mining: 10
Liquidity bonus: 10 × 2.0x = 20 FOOD
Total: 30 FOOD per block

Over 1000 blocks:
Total FOOD: 30,000 FOOD (from liquidity bonus)
```

**Incentive:** Market depth, trading UX

---

## Participation Levels

### User Level System (0–255)

```
Level 0:   0 participations
Level 1:   1–50 participations
Level 5:   51–100 participations
Level 10:  101–200 participations
Level 15:  201–500 participations
Level 20+: 500+ participations (elite)
```

**Benefits:**
- Level 1+: Reduced transaction fees
- Level 5+: Priority in DApp queues
- Level 10+: DAO voting access
- Level 15+: Treasury distribution eligibility
- Level 20+: Governance multisig candidates

---

## Data Structures

### Activity Record (40 bytes)

```zig
ActivityRecord {
  address: u64                  // User address
  activity_type: u8             // 1=validator, 2=miner, 3=dapp, 4=tx, 5=staking, 6=liquidity
  status_token_earned: u8       // Which token (1=LOVE, 2=FOOD, 3=RENT, 4=VACATION)
  amount_earned: u64            // Total tokens earned
  participation_count: u32      // Number of times participated
  last_activity_time: u64       // Last activity (TSC)
  total_time_engaged: u64       // Cumulative time
  level: u8                     // Participation level (0-255)
}
```

### Reward State (128 bytes)

```zig
StatusRewardState {
  validator_love_per_epoch: u64     // 100 LOVE
  miner_food_per_block: u64          // 10 FOOD
  dapp_rent_per_interaction: u64     // 1 RENT
  tx_vacation_per_tx: u64            // 0.5 VACATION

  staking_bonus_multiplier: u16      // 150 = 1.5x
  liquidity_bonus_multiplier: u16    // 200 = 2.0x

  total_rewards_distributed: u64
  epoch: u32
}
```

---

## IPC Opcodes (0xB1–0xB8)

```
0xB1: record_validator_participation(address, epoch) → status
0xB2: record_miner_block(address, block_height) → status
0xB3: record_dapp_interaction(address, dapp_id) → status
0xB4: record_transaction_participation(address, amount) → status
0xB5: get_user_status_tokens(address) → total_tokens
0xB6: get_participation_level(address) → level
0xB7: get_activity_count(address) → count
0xB8: run_reward_cycle() → status
```

---

## Example: User Journey (1 Month)

**User: Alice**

### Week 1: Validator Participation
```
Alice runs validator node
- Validates 200 blocks (2 epochs)
- Earns: 2 × 100 = 200 LOVE
- Level: 1
```

### Week 2: Transaction Activity
```
Alice makes trades:
- 20 small transactions: 20 × 0.5 = 10 VACATION
- 10 medium transactions: 10 × 0.75 = 7.5 VACATION
- Total: 17.5 VACATION
- Level: 2
```

### Week 3: DApp Interaction
```
Alice uses smart contracts:
- Calls 50 DApp functions
- Earns: 50 × 1 = 50 RENT
- Level: 3
```

### Week 4: Mining + Bonus
```
Alice solves 100 blocks:
- Base earnings: 100 × 10 = 1,000 FOOD
- Alice also stakes 100 OMNI (6+ months)
- Staking bonus: 1,000 × 2.0x = 2,000 FOOD
- Total: 3,000 FOOD
- Level: 4
```

### Month-End Summary

```
Alice's Status Tokens:
  LOVE:     200 (from validation)
  FOOD:     3,000 (from mining + staking bonus)
  RENT:     50 (from DApp usage)
  VACATION: 17.5 (from transactions)

Total Status Tokens: 3,267.5
Participation Level: 4 (recognized participant)

APY Boost: 1.5x (LOVE) + 1.8x (FOOD) + 2.0x (RENT) + 2.5x (VACA)
  = Effective ~4x boost on OMNI staking rewards
```

---

## Integration with On-Ramp

**Not Either/Or, But Both:**

```
Path 1 (On-Ramp):
  User sends 100 USDC on Ethereum
  ↓
  Agent mints 100 LOVE on OmniBus
  (Immediate, 1:1 conversion)

Path 2 (Participation):
  Same user runs validator
  ↓
  Earns 100 LOVE per epoch
  (Continuous, activity-based)

Path 3 (Combined):
  User has 100 LOVE from on-ramp
  + 300 LOVE from 3 months validation
  = 400 LOVE total

  Boost multiplier: LOVE (1.5x) + other tokens
  Staking APY: 10% × 4.0x+ = 40%+ per year
```

---

## Participation Incentives

### Why Participate?

1. **Status Tokens** → APY boosts on OMNI staking (up to 3.0x–4.0x)
2. **Level Benefits** → Reduced fees, voting rights, governance
3. **Network Security** → Validators and miners maintain blockchain
4. **Ecosystem Growth** → DApp and transaction participants drive adoption
5. **Long-Term Value** → Holders get rewarded for commitment

---

## Anti-Fraud Measures

1. **Activity Tracking** – Sybil attacks detected (multiple small transactions)
2. **Level Requirements** – High-level features require sustained participation
3. **Cooldown Periods** – Prevent gaming (1 activity per block max)
4. **Validator Slashing** – Malicious validators lose LOVE
5. **Community Moderation** – DAO can disable abusive accounts

---

## Economic Model

### Total Status Token Supply (Estimated)

```
On-Ramp:              Unlimited (user-driven USDC deposits)
Validator Rewards:    100 LOVE × epochs
Miner Rewards:        10 FOOD × blocks mined
DApp Rewards:         1 RENT × smart contract calls
Transaction Rewards:  0.5 VACATION × transactions

Example (1 year):
  Validators: 100 × 8760 epochs = 876,000 LOVE
  Miners: 10 × 365 × 144 blocks = 525,600 FOOD (if PoW only)
  DApp: ~10M interactions = 10M RENT
  Transactions: ~1B transactions = 500M VACATION

Total circulating: Millions of status tokens
vs. OMNI: 21M max
Ratio: 100:1 to 1000:1 (status to OMNI)
```

---

## Future Extensions

### Phase 66C: Governance Multipliers
- Status token holders get voting power boost
- Level 10+: 10x voting power
- Level 20+: 100x voting power

### Phase 66D: Community Pools
- Top 100 users by level get revenue share
- Community-managed treasury
- Seasonal rewards

### Phase 66E: Reputation System
- Status tokens → reputation scores
- Reputation → credit access
- Credit → loans/collateral

---

## Files

```
modules/status_token_distribution/
├── status_token_rewards.zig    (500+ lines)
│   - Activity tracking
│   - Reward calculation
│   - Level system
│   - Bonus multipliers
│   - IPC interface (0xB1–0xB8)
│
└── status_token_rewards.ld     (Linker script)

STATUS_TOKEN_PARTICIPATION.md   (This guide)
```

---

## Summary

**Status tokens earned through:**
- ✅ On-ramp (USDC deposits)
- ✅ Validator participation (LOVE)
- ✅ Mining (FOOD)
- ✅ DApp interaction (RENT)
- ✅ Transaction activity (VACATION)
- ✅ Staking bonuses (LOVE 3.0x)
- ✅ Liquidity provision (FOOD 2.5x)

**Benefits:**
- APY boosts on OMNI staking (up to 4.0x+)
- Level-based privileges
- Governance participation
- Revenue sharing
- Network incentives

**Total system:** Distributed, activity-based, anti-sybil

---

**Implementation Date:** 2026-03-13
**Status:** Production-Ready
**Module:** status_token_distribution (0x5A0000)
**IPC:** 0xB1–0xB8 (8 opcodes)
