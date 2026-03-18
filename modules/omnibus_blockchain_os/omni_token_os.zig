// ============================================================================
// OMNI Token OS (Zig/Bare Metal)
// Native token embedded in OmniBus blockchain
// Appears in genesis block and transaction outputs
// ============================================================================

const std = @import("std");

// Memory layout (0x590000 – 0x59FFFF, 64KB)
const OMNI_TOKEN_BASE: usize = 0x590000;

// OMNI Token Constants
const OMNI_DECIMALS: u8 = 18;
const OMNI_MAX_SUPPLY: u64 = 21_000_000 * (1 << 18); // 21 million OMNI
const OMNI_INITIAL_BLOCK_REWARD: u64 = 50 * (1 << 18); // 50 OMNI per block
const OMNI_HALVING_INTERVAL: u32 = 210_000; // Every 210k blocks (like Bitcoin)

// OMNI Token State Header (128 bytes @ 0x590000)
const OMNITokenState = struct {
    magic: u32 = 0x4F4D4E49,    // "OMNI"
    version: u16 = 1,
    reserved: u16 = 0,

    // Supply tracking
    total_minted: u64,           // Total OMNI created (genesis + rewards)
    total_circulating: u64,      // Total in circulation (minted - burned)
    total_burned: u64,           // Total burned
    total_staked: u64,           // Total staked in contracts

    // Block info
    current_block: u32,          // Current blockchain height
    current_block_reward: u64,   // Current reward per block
    next_halving_block: u32,     // Block height for next halving
    halving_count: u8,           // Number of halvings so far

    // Metadata
    genesis_timestamp: u64,      // When blockchain started
    last_block_time: u64,        // Timestamp of last block
    total_transactions: u64,     // Total OMNI transactions
    reserved_field: u64 = 0,
};

// UTXO Entry (32 bytes each, like Bitcoin)
const UTXOEntry = struct {
    address: u64,               // Recipient address
    amount: u64,                // OMNI amount (u64, 18 decimals)
    block_height: u32,          // Block where UTXO created
    tx_index: u16,              // Transaction index in block
    spent: u8,                  // 0=unspent, 1=spent
    reserved: [7]u8,
};

// Transaction Entry (64 bytes each)
const OMNITransaction = struct {
    from: u64,                  // Sender address
    to: u64,                    // Recipient address
    amount: u64,                // OMNI amount
    fee: u64,                   // Transaction fee (in SAT, 1e-18 OMNI)
    timestamp: u64,             // Tx timestamp
    block_height: u32,          // Block included in
    tx_hash: [32]u8,            // Tx hash (SHA256)
    signature: [64]u8,          // ECDSA signature
};

var omni_state: OMNITokenState = .{
    .magic = 0x4F4D4E49,
    .version = 1,
    .total_minted = 0,
    .total_circulating = 0,
    .total_burned = 0,
    .total_staked = 0,
    .current_block = 0,
    .current_block_reward = OMNI_INITIAL_BLOCK_REWARD,
    .next_halving_block = OMNI_HALVING_INTERVAL,
    .halving_count = 0,
    .genesis_timestamp = 0,
    .last_block_time = 0,
    .total_transactions = 0,
    .reserved_field = 0,
};

// UTXO storage (512 entries @ 0x590080)
var utxos: [512]UTXOEntry = undefined;

// Transaction log (256 entries @ 0x598080)
var transactions: [256]OMNITransaction = undefined;

// ============================================================================
// PUBLIC API
// ============================================================================

/// Initialize OMNI token system (called at genesis)
pub fn init_genesis(genesis_time: u64, initial_distribution_count: u32) void {
    omni_state.genesis_timestamp = genesis_time;
    omni_state.last_block_time = genesis_time;
    omni_state.current_block = 0;
    omni_state.current_block_reward = OMNI_INITIAL_BLOCK_REWARD;
    omni_state.next_halving_block = OMNI_HALVING_INTERVAL;
    omni_state.halving_count = 0;

    // Clear UTXO and transaction arrays
    for (0..512) |i| {
        utxos[i] = .{
            .address = 0,
            .amount = 0,
            .block_height = 0,
            .tx_index = 0,
            .spent = 1,
            .reserved = .{0} ** 7,
        };
    }

    for (0..256) |i| {
        transactions[i] = .{
            .from = 0,
            .to = 0,
            .amount = 0,
            .fee = 0,
            .timestamp = 0,
            .block_height = 0,
            .tx_hash = .{0} ** 32,
            .signature = .{0} ** 64,
        };
    }

    _ = initial_distribution_count;
}

/// Create genesis block with initial distribution
/// Distributes initial OMNI to addresses (e.g., treasury, foundation, community)
pub fn create_genesis_utxo(address: u64, amount: u64) u8 {
    if (omni_state.current_block != 0) {
        return 1; // Can only create genesis UTXOs before first block
    }

    // Find empty UTXO slot
    var slot: usize = undefined;
    var found = false;
    for (0..512) |i| {
        if (utxos[i].address == 0 and utxos[i].spent == 1) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 2; // UTXO pool full
    }

    if (omni_state.total_minted +| amount > OMNI_MAX_SUPPLY) {
        return 3; // Would exceed max supply
    }

    // Create UTXO
    utxos[slot] = .{
        .address = address,
        .amount = amount,
        .block_height = 0,
        .tx_index = 0,
        .spent = 0,
        .reserved = .{0} ** 7,
    };

    omni_state.total_minted +|= amount;
    omni_state.total_circulating +|= amount;

    return 0; // Success
}

/// Mine a block and create block reward
pub fn mine_block(block_height: u32, miner_address: u64, block_timestamp: u64) u8 {
    // Check for halving
    if (block_height >= omni_state.next_halving_block and omni_state.halving_count < 32) {
        omni_state.current_block_reward = omni_state.current_block_reward >> 1;
        omni_state.next_halving_block += OMNI_HALVING_INTERVAL;
        omni_state.halving_count += 1;
    }

    // Check if supply exceeded
    if (omni_state.total_minted +| omni_state.current_block_reward > OMNI_MAX_SUPPLY) {
        return 1; // Cannot mint more, max supply reached
    }

    // Create block reward UTXO
    var slot: usize = undefined;
    var found = false;
    for (0..512) |i| {
        if (utxos[i].address == 0 and utxos[i].spent == 1) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 2; // UTXO pool full
    }

    utxos[slot] = .{
        .address = miner_address,
        .amount = omni_state.current_block_reward,
        .block_height = block_height,
        .tx_index = 0xFFFF, // Coinbase transaction
        .spent = 0,
        .reserved = .{0} ** 7,
    };

    omni_state.total_minted +|= omni_state.current_block_reward;
    omni_state.total_circulating +|= omni_state.current_block_reward;
    omni_state.current_block = block_height;
    omni_state.last_block_time = block_timestamp;

    return 0; // Success
}

/// Transfer OMNI (create new transaction)
pub fn create_transaction(
    from: u64,
    to: u64,
    amount: u64,
    fee: u64,
    block_height: u32,
) u8 {
    if (amount == 0) {
        return 1; // Invalid amount
    }

    // Find balance of sender
    const sender_balance = get_balance(from);
    if (sender_balance < amount +| fee) {
        return 2; // Insufficient balance
    }

    // Find empty transaction slot
    var tx_slot: usize = undefined;
    var found = false;
    for (0..256) |i| {
        if (transactions[i].from == 0) {
            tx_slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 3; // Transaction log full
    }

    // Record transaction
    transactions[tx_slot] = .{
        .from = from,
        .to = to,
        .amount = amount,
        .fee = fee,
        .timestamp = get_tsc(),
        .block_height = block_height,
        .tx_hash = .{0} ** 32, // TODO: Calculate SHA256
        .signature = .{0} ** 64, // TODO: ECDSA sign
    };

    omni_state.total_transactions += 1;

    // Mark sender's UTXOs as spent (simplified)
    // In production, would implement proper UTXO selection (coin selection)
    var remaining_to_spend = amount +| fee;
    for (0..512) |i| {
        if (utxos[i].address == from and utxos[i].spent == 0 and remaining_to_spend > 0) {
            if (utxos[i].amount <= remaining_to_spend) {
                utxos[i].spent = 1;
                remaining_to_spend -= utxos[i].amount;
            } else {
                // Create change UTXO
                utxos[i].amount -= remaining_to_spend;
                remaining_to_spend = 0;
                break;
            }
        }
    }

    // Create output UTXO for recipient
    var found_output = false;
    for (0..512) |i| {
        if (utxos[i].address == 0 and utxos[i].spent == 1) {
            utxos[i] = .{
                .address = to,
                .amount = amount,
                .block_height = block_height,
                .tx_index = @intCast(tx_slot & 0xFFFF),
                .spent = 0,
                .reserved = .{0} ** 7,
            };
            found_output = true;
            break;
        }
    }

    if (!found_output) {
        return 4; // Output UTXO pool full
    }

    // Burn fee (remove from circulation)
    omni_state.total_circulating -|= fee;
    omni_state.total_burned +|= fee;

    return 0; // Success
}

/// Get balance of address (sum of unspent UTXOs)
pub fn get_balance(address: u64) u64 {
    var balance: u64 = 0;

    for (0..512) |i| {
        if (utxos[i].address == address and utxos[i].spent == 0) {
            balance +|= utxos[i].amount;
        }
    }

    return balance;
}

/// Get total supply (current circulating + staked)
pub fn get_total_supply() u64 {
    return omni_state.total_circulating +| omni_state.total_staked;
}

/// Get current block reward
pub fn get_block_reward() u64 {
    return omni_state.current_block_reward;
}

/// Get current block height
pub fn get_block_height() u32 {
    return omni_state.current_block;
}

/// Get next halving block
pub fn get_next_halving_block() u32 {
    return omni_state.next_halving_block;
}

/// Get halving count (how many halvings have occurred)
pub fn get_halving_count() u8 {
    return omni_state.halving_count;
}

/// Get OMNI state info
pub fn get_state() *const OMNITokenState {
    return &omni_state;
}

// ============================================================================
// IPC Interface (Opcodes 0xA1–0xA8)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0xA1 => get_balance_ipc(arg0, 0),              // get_balance(address)
        0xA2 => get_total_supply_ipc(),                // get_total_supply()
        0xA3 => create_transaction_ipc(arg0, arg1),    // create_transaction(from, to)
        0xA4 => get_block_reward_ipc(),                // get_block_reward()
        0xA5 => get_block_height_ipc(),                // get_block_height()
        0xA6 => get_halving_info_ipc(),                // get_halving_info()
        0xA7 => mine_block_ipc(arg0, arg1),            // mine_block(height, miner)
        0xA8 => run_omni_cycle(),                      // run_omni_cycle()
        else => 0xFFFFFFFF,
    };
}

fn get_balance_ipc(address: u64, _unused: u64) u64 {
    _ = _unused;
    return get_balance(address);
}

fn get_total_supply_ipc() u64 {
    return get_total_supply();
}

fn create_transaction_ipc(from_to: u64, amount_fee: u64) u64 {
    const from: u64 = from_to >> 32;
    const to: u64 = from_to & 0xFFFFFFFF;
    const amount: u64 = amount_fee >> 32;
    const fee: u64 = amount_fee & 0xFFFFFFFF;

    const result = create_transaction(from, to, amount, fee, omni_state.current_block);
    return if (result == 0) 1 else 0;
}

fn get_block_reward_ipc() u64 {
    return get_block_reward();
}

fn get_block_height_ipc() u64 {
    return omni_state.current_block;
}

fn get_halving_info_ipc() u64 {
    const next_halving = omni_state.next_halving_block;
    const halving_count = omni_state.halving_count;
    return (next_halving << 8) | halving_count;
}

fn mine_block_ipc(block_height: u64, miner_address: u64) u64 {
    const result = mine_block(@intCast(block_height), miner_address, get_tsc());
    return if (result == 0) 1 else 0;
}

fn run_omni_cycle() u64 {
    // Periodic OMNI system maintenance
    omni_state.last_block_time = get_tsc();
    return 1;
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn get_tsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile (
        \\rdtsc
        : [low] "=a" (low),
          [high] "=d" (high),
    );

    return (@as(u64, high) << 32) | low;
}
