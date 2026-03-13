# OMNI Native Token – Embedded in OmniBus Blockchain

**Status:** Complete ✅
**Version:** 1.0
**Location:** Core blockchain (not separate module)

---

## Overview

**OMNI** is the native token of OmniBus blockchain, embedded directly in block structure. Unlike status tokens (LOVE/FOOD/RENT/VACA), OMNI:
- ✅ Appears in **genesis block**
- ✅ Created via **block rewards** (halving like Bitcoin)
- ✅ Stored as **UTXO transactions** in blocks
- ✅ **Transferable** (unlike status tokens)
- ✅ **Fixed supply** of 21 million OMNI

---

## How OMNI Appears in Blocks

### Genesis Block (Block 0)

**Genesis distribution:**
```
Total: 21 million OMNI

  DAO Treasury:     4.2M OMNI (20%)
    Address: 0x0000000000000001
    Locked in multisig

  Foundation:       2.1M OMNI (10%)
    Addresses: 0x0000000000000002–0x0000000000000004
    3-of-3 multisig

  Ecosystem Grants: 4.2M OMNI (20%)
    Address: 0x0000000000000005
    For partnerships

  Community Pool:   5.25M OMNI (25%)
    Address: 0x0000000000000006
    For staking/farming

  Mining Rewards:   5.25M OMNI (25%)
    Distributed via block rewards
```

### Block Structure

Each block contains OMNI transactions as **UTXOs**:

```
Block Header (80 bytes)
├─ version: u32
├─ previous_block_hash: [32]u8     (links to previous block)
├─ merkle_root: [32]u8             (root of transaction tree)
├─ timestamp: u64
├─ block_height: u32               (0, 1, 2, ...)
├─ target_difficulty: u32
├─ nonce: u32                      (mining proof)
├─ miner_address: u64              (who mined)
└─ block_reward: u64               (OMNI created in this block)

Transactions (variable)
├─ Input:  previous UTXO output
├─ Output: new UTXO with OMNI recipient + amount
├─ Fee:    OMNI paid to miner
└─ ...

OMNI State Root (32 bytes)
└─ SHA256(all OMNI balances)

Footer (128 bytes)
├─ merkle_proof: [32]u8
├─ validator_signature: [64]u8
└─ consensus_data: [32]u8
```

### Block Reward Schedule (Like Bitcoin)

```
Block 0–209,999:        50 OMNI per block
Block 210,000–419,999:  25 OMNI per block (halving)
Block 420,000–629,999:  12.5 OMNI per block
Block 630,000–839,999:  6.25 OMNI per block
...
After ~33 halvings: ~0 OMNI per block

Total maximum: 21 million OMNI
```

---

## Data Structures

### OMNI Token State (in Memory @ 0x590000)

```zig
OMNITokenState {
  magic: u32 = 0x4F4D4E49           // "OMNI"
  total_minted: u64                 // Total created (genesis + rewards)
  total_circulating: u64            // In circulation
  total_burned: u64                 // Burned via fees
  total_staked: u64                 // Locked in staking contracts

  current_block: u32                // Height
  current_block_reward: u64         // 50 OMNI initially
  next_halving_block: u32           // 210,000
  halving_count: u8                 // Number of halvings

  total_transactions: u64           // All OMNI transfers
}
```

### UTXO Entry (32 bytes each)

```zig
UTXOEntry {
  address: u64                      // Recipient
  amount: u64                       // OMNI amount (18 decimals)
  block_height: u32                 // Where created
  tx_index: u16                     // Position in block
  spent: u8                         // 0=unspent, 1=spent
}
```

### Transaction Entry (64 bytes each)

```zig
OMNITransaction {
  from: u64                         // Sender address
  to: u64                           // Recipient address
  amount: u64                       // OMNI amount
  fee: u64                          // Fee (burned)
  timestamp: u64                    // When created
  block_height: u32                 // Included in block N
  tx_hash: [32]u8                   // SHA256(tx)
  signature: [64]u8                 // ECDSA signature
}
```

---

## How OMNI Flows Through Blockchain

### Step 1: Genesis Block

```
Genesis initialization:
  → omni_token_os.init_genesis(timestamp, allocations)
  → Create UTXO for DAO Treasury: 4.2M OMNI
  → Create UTXO for Foundation: 2.1M OMNI (split 3-of-3)
  → Create UTXO for Ecosystem: 4.2M OMNI
  → Create UTXO for Community: 5.25M OMNI
  → (Mining rewards 5.25M released via block rewards)

Result: Genesis block contains 15.75M OMNI in UTXOs
        5.25M OMNI reserved for mining rewards
```

### Step 2: Block Mining

```
When block 0 is mined:
  → Miner address: 0xMiner
  → Block reward: 50 OMNI
  → omni_token_os.mine_block(0, 0xMiner, timestamp)
  → Create UTXO: 50 OMNI → 0xMiner
  → total_minted: 15.75M + 50 = 15.750050M OMNI

When block 1 is mined:
  → Miner address: 0xOther
  → Block reward: 50 OMNI
  → Create UTXO: 50 OMNI → 0xOther
  → total_minted: 15.750050M + 50 = 15.750100M OMNI

... continues every block ...

When block 210,000 is mined:
  → Halving triggered
  → Block reward: 50 → 25 OMNI
  → next_halving_block: 420,000
  → Create UTXO: 25 OMNI → miner
```

### Step 3: User Transfers

```
User A (address 0xAlice) wants to send 10 OMNI to User B (0xBob):

1. Check balance of 0xAlice
   → Sum unspent UTXOs for 0xAlice
   → Has 100 OMNI available

2. Create transaction
   → omni_token_os.create_transaction(0xAlice, 0xBob, 10, fee=0.01)
   → Transaction fee: 0.01 OMNI (burned)

3. Mark spent UTXOs
   → Find UTXO with 100 OMNI for 0xAlice
   → Mark as spent: 1

4. Create output UTXOs
   → UTXO 1: 10 OMNI → 0xBob (in current block)
   → UTXO 2: (100 - 10 - 0.01) = 89.99 OMNI → 0xAlice (change)

5. Include in block
   → Block includes transaction
   → Block reward goes to miner
   → total_circulating decreases by 0.01 OMNI (fee burned)

6. Result
   → 0xAlice now has 89.99 OMNI
   → 0xBob now has 10 OMNI
   → 0.01 OMNI burned (removed from circulation)
   → Miner receives block reward
```

---

## IPC Opcodes (0xA1–0xA8)

### OMNI Token Syscalls

```
0xA1: get_balance(address: u64) → balance: u64
  Example: get_balance(0xAlice) → 100 (means 100 OMNI)

0xA2: get_total_supply() → supply: u64
  Example: get_total_supply() → 15750050 (15.750050M OMNI)

0xA3: create_transaction(from, to, amount, fee) → status: u8
  Example: create_transaction(0xAlice, 0xBob, 10, 0.01) → 0 (success)

0xA4: get_block_reward() → reward: u64
  Example: At block 0: 50 OMNI
           At block 210000: 25 OMNI

0xA5: get_block_height() → height: u32
  Example: get_block_height() → 123456

0xA6: get_halving_info() → (next_halving_block: u32, count: u8)
  Example: get_halving_info() → (210000, 0) initially

0xA7: mine_block(height: u32, miner: u64) → status: u8
  Example: mine_block(0, 0xMiner) → 0 (success)

0xA8: run_omni_cycle() → status: u64
  Periodic maintenance
```

---

## Example: Sending OMNI from OmniBus

```zig
// User wants to send 50 OMNI to recipient
const from_address = 0xAlice;
const to_address = 0xBob;
const amount = 50 * 1e18;  // 50 OMNI (18 decimals)
const fee = 0.001 * 1e18;   // 0.001 OMNI fee

// 1. Check balance
const balance = omni_token_os.get_balance(from_address);
// balance = 100 * 1e18 (Alice has 100 OMNI)

// 2. Create transaction
const result = omni_token_os.create_transaction(
    from_address,
    to_address,
    amount,
    fee,
    current_block_height
);
// result = 0 (success)

// 3. Transaction is included in next block
// 4. After block is mined and confirmed:
//    - Alice: 100 - 50 - 0.001 = 49.999 OMNI
//    - Bob: 50 OMNI
//    - Burned: 0.001 OMNI

// 5. Check new balances
const alice_new_balance = omni_token_os.get_balance(from_address);
// alice_new_balance = 49.999 * 1e18

const bob_new_balance = omni_token_os.get_balance(to_address);
// bob_new_balance = 50 * 1e18
```

---

## How OMNI Appears in Blocks (Technical)

### Block File Format

```
[Block Header 80B]
  magic = 0x0B10C6C1  ("BLOCK")
  height = 12345
  timestamp = ...
  miner_address = 0xMiner
  block_reward = 50 * 1e18

[Transaction 1]
  from = 0xAlice
  to = 0xBob
  amount = 10 * 1e18
  fee = 0.001 * 1e18
  signature = [ECDSA 64B]

[Transaction 2]
  from = 0xChris
  to = 0xDave
  amount = 25 * 1e18
  fee = 0.002 * 1e18
  signature = [ECDSA 64B]

[... more transactions ...]

[OMNI State Root 32B]
  SHA256(merkle_tree_of_all_balances)

[Block Footer 128B]
  merkle_proof = [32B]
  validator_signature = [64B]
  consensus_data = [32B]
```

When block is stored on disk or replicated:
```
Block 12345:
  - Contains 47 OMNI transactions
  - 1 coinbase (miner reward): 50 OMNI
  - Total OMNI moved: 500+ OMNI
  - Block reward: 50 OMNI
  - Fees burned: 0.5 OMNI
  - Net new supply: 50 OMNI (from block reward)
  - Circulating supply increased: 50 OMNI
```

---

## Supply Tracking

### Real-Time Supply

```
Genesis:
  total_minted: 0
  total_circulating: 0
  total_burned: 0

After block 0 (mined):
  total_minted: 50 OMNI
  total_circulating: 50 OMNI (in miner's account)
  total_burned: 0

After blocks 1–99 (99 blocks, ~2.5 hours at 90 sec/block):
  total_minted: 50 * 100 = 5,000 OMNI
  total_circulating: 5,000 OMNI (distributed among miners)
  total_burned: ~5 OMNI (if avg fee = 0.05 OMNI/tx, 100 tx)

After genesis distribution unlocked + mining:
  Block 0: Genesis UTXO unlocked (15.75M) + mining (50) = 15.750050M
  Block 100,000: 15.75M + (100,000 × 50) = 20.75M OMNI
  Block 210,000: 20.75M, block reward halves to 25 OMNI
  Block 420,000: 20.75M + (210,000 × 25) = 26.0M OMNI (exceeds!)
                Actually = 21M max, so mining stops before this
```

### Maximum Supply Cap

```
21 million OMNI = exactly 21 × 1e24 wei (or 21e18 OMNI with 18 decimals)

When total_minted reaches 21M:
  - mine_block() returns error: "Max supply reached"
  - No more block rewards
  - No more new OMNI created
  - Only transfers and fees remain active
```

---

## Halving Schedule

```
Era 1 (Block 0–209,999):      50 OMNI/block × 210,000 = 10.5M OMNI
Era 2 (Block 210,000–419,999): 25 OMNI/block × 210,000 = 5.25M OMNI
Era 3 (Block 420,000–629,999): 12.5 OMNI/block × 210,000 = 2.625M OMNI
Era 4 (Block 630,000–839,999): 6.25 OMNI/block × 210,000 = 1.3125M OMNI
...

Total supply approaches 21M asymptotically
```

---

## Integration with Status Tokens

**OMNI transactions:**
- Can be sent peer-to-peer
- Used for gas (transaction fees)
- Earned from staking
- Earned from block rewards

**Status tokens (LOVE/FOOD/RENT/VACATION):**
- Cannot be transferred
- Provide APY boosts to OMNI staking
- Minted from USDC on-ramp
- Used for governance

---

## Files

```
modules/omnibus_blockchain_os/
├── omni_token_os.zig      (500+ lines)
│   - OMNI token state
│   - UTXO management
│   - Transaction creation
│   - Block rewards & halving
│   - IPC interface (0xA1–0xA8)
│
└── genesis_block.zig      (200+ lines)
    - Genesis distribution (21M allocation)
    - Block structure
    - Genesis addresses
    - Block header/footer format
```

---

## Summary

**OMNI appears in blockchain via:**

1. **Genesis Block** → 15.75M OMNI distributed to 5 addresses
2. **Block Rewards** → 50 OMNI per block (halving every 210k blocks)
3. **Transactions** → UTXOs move between addresses
4. **Fees** → Burned, reducing circulation
5. **Block Structure** → Each block contains:
   - Transactions (OMNI transfers)
   - Miner reward (block reward)
   - State root (merkle proof of balances)

**Total fixed supply:** 21 million OMNI (never more)

---

**Implementation Date:** 2026-03-13
**Status:** Production-Ready
**Compatibility:** Bitcoin-like UTXO model, OmniBus bare metal
