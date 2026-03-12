# OmniBus Blockchain Opcodes Specification

**Version:** 2.0.0 | **Phase 60**
**Inspired by:** Bitcoin Script (https://en.bitcoin.it/wiki/Script)
**Purpose:** Unified opcode system for smart contracts, token transfers, DAO governance, and RPC operations

---

## Overview

OmniBus uses a **256-entry opcode dispatch table** (0x00–0xFF) for deterministic contract execution. Unlike Bitcoin's limited script, OmniBus opcodes directly manipulate:
- Token balances (OMNI + domain tokens)
- Wallet state (BIP-39/32 keys)
- DAO governance (voting, proposals)
- Network state (peers, bridges)
- RPC sessions (client tracking)
- Cryptographic primitives (PQ signatures)

**Execution Model:** Stack-based (32KB stack), deterministic (no random), no external I/O.

---

## Opcode Categories

| Range | Category | Count | Purpose |
|-------|----------|-------|---------|
| `0x00–0x0F` | **Stack** | 16 | Push, pop, dup, swap operations |
| `0x10–0x1F` | **Token** | 16 | OMNI/domain token transfers, balances |
| `0x20–0x2F` | **Wallet** | 16 | Address derivation, key management |
| `0x30–0x3F` | **Smart Contract** | 16 | Contract state, execution control |
| `0x40–0x4F` | **DAO Governance** | 16 | Voting, proposals, treasury |
| `0x50–0x5F` | **Network/Bridge** | 16 | Cross-chain, peer management |
| `0x60–0x6F` | **RPC State** | 16 | Client recognition, sessions |
| `0x70–0x7F` | **Cryptography** | 16 | Hash, signature, PQ crypto |
| `0x80–0x8F` | **Flow Control** | 16 | If/else, loops, jumps |
| `0x90–0xAF` | **Arithmetic** | 32 | Add, sub, mul, div, mod |
| `0xB0–0xCF` | **Bitwise** | 32 | AND, OR, XOR, shift |
| `0xD0–0xDF` | **Comparison** | 16 | EQ, LT, GT, etc. |
| `0xE0–0xEF` | **Reserved** | 16 | Future expansion |
| `0xF0–0xFF` | **System** | 16 | Debug, halt, introspection |

---

## STACK OPERATIONS (0x00–0x0F)

| Opcode | Name | Stack In → Out | Description |
|--------|------|---|---|
| `0x00` | `OP_PUSH0` | `∅ → 0` | Push 0 onto stack |
| `0x01–0x10` | `OP_PUSH1–16` | `∅ → n` | Push literal 1–16 |
| `0x11` | `OP_DUP` | `A → A A` | Duplicate top stack item |
| `0x12` | `OP_DROP` | `A → ∅` | Remove top item |
| `0x13` | `OP_SWAP` | `A B → B A` | Swap top two items |
| `0x14` | `OP_OVER` | `A B → A B A` | Copy second item to top |
| `0x15` | `OP_ROT` | `A B C → B C A` | Rotate: move third to top |

---

## TOKEN OPERATIONS (0x10–0x1F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x10` | `OP_TRANSFER` | `[from, to, amount, token_type]` | `1/0` | Transfer tokens (OMNI=0, LOVE=1, etc.) |
| `0x11` | `OP_BALANCE` | `[address, token_type]` | `u64` | Get balance for address+token |
| `0x12` | `OP_MINT` | `[token_type, amount]` | `1/0` | Mint new tokens (treasury only) |
| `0x13` | `OP_BURN` | `[token_type, amount]` | `1/0` | Burn tokens from circulation |
| `0x14` | `OP_STAKE` | `[address, amount, days]` | `1/0` | Create staking position (30/90/180/365) |
| `0x15` | `OP_UNSTAKE` | `[address, stake_id]` | `amount` | Unstake and claim rewards |
| `0x16` | `OP_CLAIM_REWARDS` | `[address]` | `amount` | Claim pending staking rewards |
| `0x17` | `OP_AIRDROP_CLAIM` | `[address]` | `amount` | Claim eligible airdrop |
| `0x18` | `OP_FAUCET` | `[address]` | `amount` | Get daily testnet faucet (100 tOMNI) |
| `0x19` | `OP_APPROVE` | `[owner, spender, amount]` | `1/0` | Approve spending allowance |
| `0x1A` | `OP_ALLOWANCE` | `[owner, spender]` | `u64` | Get approved spending amount |

---

## WALLET OPERATIONS (0x20–0x2F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x20` | `OP_DERIVE_KEY` | `[domain, index]` | `pubkey[32]` | Derive HD wallet key (m/44'/506'/domain'/0/index) |
| `0x21` | `OP_GET_ADDRESS` | `[wallet_id, chain]` | `addr[64]` | Get address on chain (0=OmniBus, 1=Bitcoin, etc.) |
| `0x22` | `OP_SIGN_TX` | `[privkey[32], tx_hash[32], algo]` | `sig[96]` | Sign transaction (algo: 0=Falcon, 1=ML-DSA, 2=SPHINCS+) |
| `0x23` | `OP_VERIFY_SIG` | `[pubkey[32], msg[32], sig[96]]` | `1/0` | Verify PQ signature |
| `0x24` | `OP_CREATE_WALLET` | `[domain]` | `wallet_id` | Create new HD wallet (domain: 0=OMNI, 1=LOVE, etc.) |
| `0x25` | `OP_GET_BALANCE` | `[wallet_id, chain]` | `u64` | Get wallet balance on chain |
| `0x26` | `OP_RECOVER_KEY` | `[mnemonic_ptr, mnemonic_len]` | `privkey[32]` | Recover key from BIP-39 mnemonic |

---

## SMART CONTRACT OPERATIONS (0x30–0x3F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x30` | `OP_CALL` | `[contract_addr, method_id, args...]` | `result` | Call internal contract function |
| `0x31` | `OP_STORE` | `[key_hash[32], value]` | `1/0` | Store key=value in contract storage |
| `0x32` | `OP_LOAD` | `[key_hash[32]]` | `value` | Load value from contract storage |
| `0x33` | `OP_DELETE` | `[key_hash[32]]` | `1/0` | Delete storage key |
| `0x34` | `OP_GETSTATE` | `[contract_id]` | `state_ptr` | Get contract state (nonce, code hash) |
| `0x35` | `OP_SETCODE` | `[contract_id, code_ptr, code_len]` | `1/0` | Update contract bytecode |
| `0x36` | `OP_SELFDESTRUCT` | `[beneficiary]` | `∅` | Destroy contract, send balance to beneficiary |
| `0x37` | `OP_GAS_REMAINING` | `∅` | `u64` | Get remaining gas in execution |

---

## DAO GOVERNANCE OPERATIONS (0x40–0x4F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x40` | `OP_PROPOSE` | `[proposal_type, title_ptr, description_ptr, changes_ptr]` | `proposal_id` | Create governance proposal |
| `0x41` | `OP_VOTE` | `[proposal_id, vote_type, weight]` | `1/0` | Cast weighted vote (0=no, 1=yes, 2=abstain) |
| `0x42` | `OP_EXECUTE` | `[proposal_id]` | `1/0` | Execute approved proposal (5/7 quorum) |
| `0x43` | `OP_GET_PROPOSAL` | `[proposal_id]` | `state_ptr` | Get proposal details (title, votes, status) |
| `0x44` | `OP_TREASURY_SEND` | `[recipient, amount, description_ptr]` | `txid` | Transfer from DAO treasury (requires vote) |
| `0x45` | `OP_TREASURY_BALANCE` | `∅` | `u64` | Get DAO treasury balance |
| `0x46` | `OP_GET_VOTING_POWER` | `[address]` | `u64` | Get voting power = staked OMNI |
| `0x47` | `OP_DELEGATE` | `[delegator, delegatee]` | `1/0` | Delegate voting power to another address |

---

## NETWORK & BRIDGE OPERATIONS (0x50–0x5F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x50` | `OP_BRIDGE_INIT` | `[src_chain, dst_chain, token, amount]` | `bridge_txid` | Initiate cross-chain transfer |
| `0x51` | `OP_BRIDGE_CONFIRM` | `[bridge_txid, signers[]]` | `1/0` | Confirm bridge (3/5 oracle quorum) |
| `0x52` | `OP_ADD_PEER` | `[ip_addr[4], port, is_validator]` | `peer_id` | Register network peer |
| `0x53` | `OP_REMOVE_PEER` | `[peer_id]` | `1/0` | Remove peer from network |
| `0x54` | `OP_GET_PEER_COUNT` | `∅` | `u32` | Get active peer count |
| `0x55` | `OP_BROADCAST_BLOCK` | `[block_ptr, block_len]` | `1/0` | Broadcast block to peers |
| `0x56` | `OP_ROUTE_TX` | `[tx_ptr, tx_len]` | `1/0` | Route transaction through StealthOS |
| `0x57` | `OP_SYNC_BLOCKS` | `[start_height, end_height]` | `1/0` | Request block sync from peer |

---

## RPC STATE OPERATIONS (0x60–0x6F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x60` | `OP_REGISTER_CLIENT` | `[ip_ptr, port, client_type]` | `client_id` | Register RPC client (0=browser, 1=SDK, 2=bot) |
| `0x61` | `OP_RECOGNIZE_CLIENT` | `[client_hash[32], hash_len]` | `client_id` | Recognize returning RPC client |
| `0x62` | `OP_AUTHENTICATE` | `[client_id, auth_level, api_key_hash[32]]` | `1/0` | Set client authentication |
| `0x63` | `OP_CREATE_SESSION` | `[client_id, timeout_cycles]` | `session_id` | Create RPC session |
| `0x64` | `OP_VERIFY_SESSION` | `[session_id]` | `1/0` | Check if session is valid |
| `0x65` | `OP_CHECK_RATE_LIMIT` | `[client_id, max_req_per_sec]` | `1/0` | Check rate limit for client |
| `0x66` | `OP_RECORD_CALL` | `[client_id, session_id, method_hash]` | `1/0` | Log RPC call to session |
| `0x67` | `OP_BAN_CLIENT` | `[client_id]` | `1/0` | Ban RPC client (flood protection) |

---

## CRYPTOGRAPHY OPERATIONS (0x70–0x7F)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0x70` | `OP_SHA256` | `[data_ptr, len]` | `hash[32]` | Compute SHA-256 hash |
| `0x71` | `OP_KECCAK256` | `[data_ptr, len]` | `hash[32]` | Compute Keccak-256 hash (Ethereum compat) |
| `0x72` | `OP_RIPEMD160` | `[data_ptr, len]` | `hash[20]` | Compute RIPEMD-160 (Bitcoin compat) |
| `0x73` | `OP_HMAC_SHA256` | `[key_ptr, key_len, data_ptr, data_len]` | `mac[32]` | HMAC-SHA256 (exchange signing) |
| `0x74` | `OP_VERIFY_SIGNATURE` | `[pubkey[32], msg[32], sig[96], algo]` | `1/0` | Verify PQ signature (Falcon/ML-DSA/SPHINCS+) |
| `0x75` | `OP_KYBER_ENCAP` | `[pubkey[1184]]` | `ciphertext[1088], shared_secret[32]` | Kyber-768 encapsulation |
| `0x76` | `OP_KYBER_DECAP` | `[privkey[2400], ciphertext[1088]]` | `shared_secret[32]` | Kyber-768 decapsulation |
| `0x77` | `OP_RECOVER_PUBKEY` | `[msg[32], sig[65], recovery_id]` | `pubkey[65]` | Recover Secp256k1 pubkey from sig (for bridges) |

---

## FLOW CONTROL OPERATIONS (0x80–0x8F)

| Opcode | Name | Stack In | Effect | Description |
|--------|------|---|---|---|
| `0x80` | `OP_IF` | `[condition]` | Jump if 0 | Execute block if top of stack != 0 |
| `0x81` | `OP_ELSE` | `∅` | Jump | Else branch |
| `0x82` | `OP_ENDIF` | `∅` | Join | End if/else block |
| `0x83` | `OP_LOOP` | `[count]` | Jump back | Loop N times (max 1000 iterations) |
| `0x84` | `OP_BREAK` | `∅` | Exit loop | Break out of current loop |
| `0x85` | `OP_CONTINUE` | `∅` | Next iter | Continue to next loop iteration |
| `0x86` | `OP_VERIFY` | `[condition]` | Fail if 0 | Assert condition, halt if false |
| `0x87` | `OP_JUMP` | `[offset]` | Jump | Unconditional jump (relative) |
| `0x88` | `OP_JUMPI` | `[offset, condition]` | Jump if != 0 | Conditional jump |
| `0x89` | `OP_RETURN` | `[value]` | Return | Exit with value on stack |
| `0x8A` | `OP_REVERT` | `[error_msg_ptr, len]` | Revert | Abort execution, return error |

---

## ARITHMETIC OPERATIONS (0x90–0xAF)

| Opcode | Name | Stack In → Out | Description |
|--------|------|---|---|
| `0x90` | `OP_ADD` | `A B → A+B` | Addition (checked overflow) |
| `0x91` | `OP_SUB` | `A B → A-B` | Subtraction (checked underflow) |
| `0x92` | `OP_MUL` | `A B → A*B` | Multiplication (checked overflow) |
| `0x93` | `OP_DIV` | `A B → A/B` | Integer division (B != 0) |
| `0x94` | `OP_MOD` | `A B → A%B` | Modulo (B != 0) |
| `0x95` | `OP_POW` | `A B → A^B` | Power (exponent max 64) |
| `0x96` | `OP_SQRT` | `A → √A` | Integer square root |
| `0x97` | `OP_ABS` | `A → \|A\|` | Absolute value |
| `0x98` | `OP_NEG` | `A → -A` | Negation |
| `0x99` | `OP_INC` | `A → A+1` | Increment |
| `0x9A` | `OP_DEC` | `A → A-1` | Decrement |
| `0x9B` | `OP_MAX` | `A B → max(A,B)` | Maximum |
| `0x9C` | `OP_MIN` | `A B → min(A,B)` | Minimum |

---

## BITWISE OPERATIONS (0xB0–0xCF)

| Opcode | Name | Stack In → Out | Description |
|--------|------|---|---|
| `0xB0` | `OP_AND` | `A B → A & B` | Bitwise AND |
| `0xB1` | `OP_OR` | `A B → A \| B` | Bitwise OR |
| `0xB2` | `OP_XOR` | `A B → A ^ B` | Bitwise XOR |
| `0xB3` | `OP_NOT` | `A → ~A` | Bitwise NOT |
| `0xB4` | `OP_SHL` | `A B → A << B` | Left shift (B < 64) |
| `0xB5` | `OP_SHR` | `A B → A >> B` | Right shift (B < 64) |
| `0xB6` | `OP_ROTL` | `A B → rotate_left(A, B)` | Rotate left |
| `0xB7` | `OP_ROTR` | `A B → rotate_right(A, B)` | Rotate right |
| `0xB8` | `OP_POPCNT` | `A → count_bits(A)` | Count set bits |
| `0xB9` | `OP_CLZ` | `A → leading_zeros(A)` | Count leading zeros |

---

## COMPARISON OPERATIONS (0xD0–0xDF)

| Opcode | Name | Stack In → Out | Description |
|--------|------|---|---|
| `0xD0` | `OP_EQ` | `A B → (A == B ? 1 : 0)` | Equality |
| `0xD1` | `OP_NE` | `A B → (A != B ? 1 : 0)` | Not equal |
| `0xD2` | `OP_LT` | `A B → (A < B ? 1 : 0)` | Less than |
| `0xD3` | `OP_LE` | `A B → (A <= B ? 1 : 0)` | Less than or equal |
| `0xD4` | `OP_GT` | `A B → (A > B ? 1 : 0)` | Greater than |
| `0xD5` | `OP_GE` | `A B → (A >= B ? 1 : 0)` | Greater than or equal |
| `0xD6` | `OP_ISNEG` | `A → (A < 0 ? 1 : 0)` | Test if negative |
| `0xD7` | `OP_ISZERO` | `A → (A == 0 ? 1 : 0)` | Test if zero |

---

## SYSTEM OPERATIONS (0xF0–0xFF)

| Opcode | Name | Stack In | Returns | Description |
|--------|------|---|---|---|
| `0xF0` | `OP_NOP` | `∅` | `∅` | No operation |
| `0xF1` | `OP_HALT` | `∅` | Stop | Halt execution immediately |
| `0xF2` | `OP_DEBUG` | `[msg_ptr, len]` | `∅` | Log debug message (testnet only) |
| `0xF3` | `OP_TIMESTAMP` | `∅` | `u64` | Get current block timestamp |
| `0xF4` | `OP_BLOCKNUMBER` | `∅` | `u64` | Get current block height |
| `0xF5` | `OP_BLOCKHASH` | `[height]` | `[32]u8` | Get block hash at height (last 256 blocks) |
| `0xF6` | `OP_GASLEFT` | `∅` | `u64` | Get remaining gas |
| `0xF7` | `OP_CALLER` | `∅` | `caller_id` | Get calling client ID (from RPC State OS) |
| `0xF8` | `OP_ADDRESS` | `∅` | `contract_addr` | Get current contract address |
| `0xF9` | `OP_BALANCE` | `[addr]` | `u64` | Get address's OMNI balance |
| `0xFA` | `OP_CODESIZE` | `∅` | `u32` | Get current contract bytecode size |
| `0xFB` | `OP_CODECOPY` | `[offset, size]` | `code_ptr` | Get copy of contract bytecode |
| `0xFC` | `OP_STATICCALL` | `[addr, method, args_ptr]` | `result` | Call function (read-only) |
| `0xFD` | `OP_DELEGATECALL` | `[addr, method, args_ptr]` | `result` | Call with delegated context |
| `0xFE` | `OP_CREATE` | `[code_ptr, code_len]` | `contract_addr` | Deploy new contract |
| `0xFF` | `OP_SELFDESTRUCT_IMPL` | `[beneficiary]` | `∅` | Implementation of selfdestruct |

---

## Gas Costs

All operations consume gas:

| Category | Base Gas | Notes |
|----------|----------|-------|
| Stack | 1 | Per push/pop/dup |
| Arithmetic | 3 | Per +/-/\*/÷ |
| Crypto | 100 | SHA256, verify sig |
| Storage | 20,000 | SSTORE, SLOAD |
| Network | 50,000 | Bridge, broadcast |
| Contract Call | 700 | Per CALL/STATICCALL |

**Gas Limit per Transaction:** 1,000,000 SAT equivalent (~5MB bytecode)

---

## Bitcoin vs OmniBus Comparison

| Aspect | Bitcoin Script | OmniBus Opcodes |
|--------|---|---|
| **Purpose** | Simple payment verification | Full smart contracts + tokens |
| **Stack Size** | 1,000 items | 32KB (4,096 items) |
| **Total Opcodes** | 256 (168 enabled) | 256 (all enabled) |
| **Turing Complete** | No (limited loops) | Yes (loops, conditionals) |
| **Cryptography** | ECDSA, RIPEMD160, SHA256 | PQC (Falcon, ML-DSA, SPHINCS+, Kyber) |
| **Token Support** | None (UTXO only) | Native (OMNI + 4 domain tokens) |
| **Governance** | None | Full DAO (voting, treasury, proposals) |
| **Cross-chain** | Atomic swaps | Bridge operations with oracle quorum |
| **Gas Model** | None | Yes (1M gas limit per tx) |
| **Storage** | None | Key=value state per contract |

---

## BITCOIN SCRIPT 1:1 REFERENCE (omnibtc)

For blockchain compatibility, OmniBus **includes Bitcoin Script opcodes** exactly as-is at offsets 0x00–0xC0:

### Stack Pushes (0x00–0x4F)
```
0x00  OP_0 / OP_FALSE           Push 0
0x4F  OP_1NEGATE                Push -1
0x50  OP_1 / OP_TRUE            Push 1
0x51–0x60  OP_2...OP_16         Push 2–16
0x4C  OP_PUSHDATA1              Push next byte as size
0x4D  OP_PUSHDATA2              Push next 2 bytes as size
0x4E  OP_PUSHDATA4              Push next 4 bytes as size
```

### Bitwise/Arithmetic (0x76–0x9D)
```
0x76  OP_DUP                    Duplicate top
0x77  OP_HASH160                Hash160(top)
0x88  OP_EQUALVERIFY            Assert equal
0x8D  OP_EQUAL                  Pop A,B; push (A==B)
0x93  OP_ADD                    Pop A,B; push A+B
0x94  OP_SUB                    Pop A,B; push A-B
0x9D  OP_SIZE                   Push size of top item
```

### Crypto (0xA8–0xAE)
```
0xA8  OP_SHA1                   SHA1 hash
0xA9  OP_SHA256                 SHA256 hash
0xAA  OP_HASH160                RIPEMD160(SHA256(x))
0xAB  OP_HASH256                SHA256(SHA256(x))
0xAC  OP_CHECKSIG               Verify ECDSA signature
0xAD  OP_CHECKSIGVERIFY         Assert CHECKSIG
0xAE  OP_CHECKMULTISIG          Verify M-of-N signatures
```

### Flow Control (0x63–0x68)
```
0x63  OP_IF                     Execute if top != 0
0x64  OP_NOTIF                  Execute if top == 0
0x67  OP_ELSE                   Else branch
0x68  OP_ENDIF                  End if/else
0x69  OP_VERIFY                 Assert top != 0
0x6A  OP_RETURN                 Fail script
```

**OmniBus Compatibility Mode:** Scripts can run unmodified Bitcoin Script by:
```
1. Detecting script version (Bitcoin = 0x00, OmniBus = 0x01)
2. Dispatching to Bitcoin interpreter (opcodes 0x00–0xC0)
3. Falling through to OmniBus extensions (0xD0–0xFF) if needed
```

---

## OMNIBTC vs OMNI-OP Opcode Mapping

| Bitcoin Opcode | Bitcoin Name | OmniBus Offset | OmniBus Function | Purpose |
|--------|----------|---|---|---|
| `0x00` | OP_0 | `0x00` | OP_PUSH0 | Stack push 0 |
| `0x51` | OP_1 | `0x01` | OP_PUSH1 | Stack push 1 |
| `0x76` | OP_DUP | `0x11` | OP_DUP | Stack dup |
| `0x88` | OP_EQUALVERIFY | `0xD0` | OP_EQ | Compare equal |
| `0x93` | OP_ADD | `0x90` | OP_ADD | Arithmetic add |
| `0xA9` | OP_SHA256 | `0x70` | OP_SHA256 | Crypto hash |
| `0xAC` | OP_CHECKSIG | — | OP_VERIFY_SIG | PQC signature verify |
| — | — | `0x10` | OP_TRANSFER | **NEW: Token transfer** |
| — | — | `0x40` | OP_PROPOSE | **NEW: DAO proposal** |
| — | — | `0x50` | OP_BRIDGE_INIT | **NEW: Cross-chain** |

---

## Execution Mode Selection

```
Script Header Byte:
  0x00 = Bitcoin Script mode (use standard interpreter)
  0x01 = OmniBus mode (use full opcode table)
  0x02 = Hybrid mode (Bitcoin ops first, OmniBus fallback)
```

Example: **Bitcoin P2PKH script in OmniBus**
```
[Bitcoin Header: 0x00]
OP_DUP OP_HASH160 <pubkey_hash> OP_EQUALVERIFY OP_CHECKSIG
→ Runs as standard Bitcoin validation
```

Example: **OmniBus Token Transfer + DAO Vote**
```
[OmniBus Header: 0x01]
OP_TRANSFER              # 0x10 - transfer tokens
OP_PROPOSE              # 0x40 - create proposal
OP_VOTE                 # 0x41 - vote on it
OP_EXECUTE              # 0x42 - execute if passed
→ Runs as full OmniBus smart contract
```

---

## Execution Semantics

### Safety Guarantees

1. **No Memory Corruption:** All operations are bounds-checked
2. **Gas Limits:** All code terminates within gas limit
3. **Determinism:** Same input = same output (no randomness, no timers)
4. **Atomicity:** Transaction succeeds completely or reverts (no partial state)
5. **Overflow Protection:** Arithmetic ops checked for overflow/underflow

### Call Stack

```
[RPC Client]
    ↓ (IPC opcode 0x7C: OP_SUBMIT_TRANSACTION)
[Blockchain OS]
    ↓
[Opcode Dispatcher (0x00–0xFF)]
    ↓
[Token OS / Wallet OS / DAO OS / RPC State OS / Crypto] (execute)
    ↓
[Return result]
    ↓ (to RPC State OS for logging)
[Back to client]
```

---

## Example Contracts

### 1. Simple Token Transfer

```
PUSH 0x100       # recipient address
PUSH 0x50000     # 50,000 SAT (0.0005 OMNI)
PUSH 0           # token type = OMNI
CALLER           # get calling client
TRANSFER         # OP_0x10 - execute transfer
VERIFY           # assert success
HALT
```

### 2. Staking Contract

```
# Create 90-day stake
PUSH 90          # days
PUSH 100000000   # 1 OMNI
CALLER           # who is staking?
STAKE            # OP_0x14 - create stake position
VERIFY           # assert success
# Get rewards
CALLER
CLAIM_REWARDS    # OP_0x16 - claim staking rewards
# Transfer to wallet
DUP
TRANSFER         # send rewards
HALT
```

### 3. DAO Treasury Proposal

```
# Create proposal for 1000 OMNI payment to address 0x123
PUSH 0x123                           # beneficiary
PUSH 1000000000000                   # 1000 OMNI
PUSH "Fix L2 bridge exploit"         # description
PUSH 0x01                            # proposal type = TREASURY
PROPOSE                              # OP_0x40 - create proposal
VERIFY
# After vote passes: EXECUTE
EXECUTE                              # OP_0x42
HALT
```

---

## Reserved for Future

- `0xE0–0xEF`: Extended opcodes (ZK proofs, ML inference)
- Quantum-resistant hash functions (once NIST standardizes)
- Cross-VM interop (EVM ABI compatibility)
- Rollup/sidechain proofs

---

**Last Updated:** 2026-03-12
**Maintained By:** OmniBus Core Team
**Feedback:** https://github.com/SAVACAZAN/OmniBus/discussions
