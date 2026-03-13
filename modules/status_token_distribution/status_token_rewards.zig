// ============================================================================
// Status Token Rewards (Zig/Bare Metal)
// Earn LOVE/FOOD/RENT/VACATION through participation
// ============================================================================

const std = @import("std");

// Memory layout (0x5A0000 – 0x5AFFFF, 64KB)
const STATUS_REWARD_BASE: usize = 0x5A0000;

// Activity types that earn status tokens
const ActivityType = enum(u8) {
    VALIDATOR = 1,        // Run validator node → LOVE
    MINER = 2,            // Mine blocks → FOOD
    DAPP_INTERACTION = 3, // Use smart contracts → RENT
    TRANSACTION = 4,      // Perform transactions → VACATION
    STAKING = 5,          // Stake OMNI long-term → LOVE (stacking)
    LIQUIDITY = 6,        // Provide liquidity → FOOD (stacking)
};

// Participant Activity Record (40 bytes each)
const ActivityRecord = struct {
    address: u64,                    // User/validator address
    activity_type: u8,              // 1=validator, 2=miner, 3=dapp, 4=tx, 5=staking
    status_token_earned: u8,        // Which token (1=LOVE, 2=FOOD, 3=RENT, 4=VACATION)
    amount_earned: u64,             // Tokens earned
    participation_count: u32,       // Number of times participated
    last_activity_time: u64,        // Last activity (TSC)
    total_time_engaged: u64,        // Cumulative participation time
    level: u8,                      // 0-255 (participation level)
    reserved: [7]u8,
};

// Status Token Rewards State Header (128 bytes @ 0x5A0000)
const StatusRewardState = struct {
    magic: u32 = 0x53524557,        // "SREW" (Status REWards)
    version: u16 = 1,
    reserved: u16 = 0,

    // Validator rewards
    validator_love_per_epoch: u64,  // LOVE per epoch for validators
    validator_count: u32,           // Active validators
    validator_reward_pool: u64,     // Total LOVE for validators

    // Miner rewards
    miner_food_per_block: u64,      // FOOD per block for miners
    miner_count: u32,               // Active miners
    miner_reward_pool: u64,         // Total FOOD for miners

    // DApp interaction rewards
    dapp_rent_per_interaction: u64, // RENT per smart contract call
    dapp_interaction_count: u64,    // Total interactions
    dapp_reward_pool: u64,          // Total RENT for DApp users

    // Transaction rewards
    tx_vacation_per_tx: u64,        // VACATION per transaction
    tx_count: u64,                  // Total transactions
    tx_reward_pool: u64,            // Total VACATION for active users

    // Staking bonuses
    staking_bonus_multiplier: u16,  // 150 = 1.5x more rewards
    liquidity_bonus_multiplier: u16,// 200 = 2.0x more rewards

    // Tracking
    total_rewards_distributed: u64, // Total status tokens distributed
    epoch: u32,                     // Current epoch (blocks/1000)
    last_distribution_block: u32,   // When last rewards were distributed
};

// Activity storage (256 records @ 0x5A0080)
var activity_records: [256]ActivityRecord = undefined;

var reward_state: StatusRewardState = .{
    .magic = 0x53524557,
    .version = 1,
    .validator_love_per_epoch = 100,        // 100 LOVE per epoch
    .validator_count = 0,
    .validator_reward_pool = 0,
    .miner_food_per_block = 10,             // 10 FOOD per block
    .miner_count = 0,
    .miner_reward_pool = 0,
    .dapp_rent_per_interaction = 1,         // 1 RENT per interaction
    .dapp_interaction_count = 0,
    .dapp_reward_pool = 0,
    .tx_vacation_per_tx = 0.5,              // 0.5 VACATION per tx (fixed point)
    .tx_count = 0,
    .tx_reward_pool = 0,
    .staking_bonus_multiplier = 150,        // 1.5x bonus
    .liquidity_bonus_multiplier = 200,      // 2.0x bonus
    .total_rewards_distributed = 0,
    .epoch = 0,
    .last_distribution_block = 0,
};

// ============================================================================
// PUBLIC API
// ============================================================================

pub fn init_plugin() void {
    // Clear activity records
    for (0..256) |i| {
        activity_records[i] = .{
            .address = 0,
            .activity_type = 0,
            .status_token_earned = 0,
            .amount_earned = 0,
            .participation_count = 0,
            .last_activity_time = 0,
            .total_time_engaged = 0,
            .level = 0,
            .reserved = .{0} ** 7,
        };
    }
}

/// Record validator participation (running a validator node)
/// Returns LOVE tokens
pub fn record_validator_participation(validator_address: u64, epoch_number: u32) u8 {
    const slot = find_or_create_activity_slot(validator_address, 1) orelse return 2; // 1 = VALIDATOR
    const activity = &activity_records[slot];

    const love_earned = reward_state.validator_love_per_epoch;

    activity.activity_type = 1; // VALIDATOR
    activity.status_token_earned = 1; // LOVE token
    activity.amount_earned +|= love_earned;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= 1000; // ~1 epoch in TSC units

    // Update level based on participation count
    if (activity.participation_count > 100) {
        activity.level = 10;
    } else if (activity.participation_count > 50) {
        activity.level = 5;
    } else {
        activity.level = 1;
    }

    reward_state.validator_count +|= 1;
    reward_state.validator_reward_pool +|= love_earned;
    reward_state.total_rewards_distributed +|= love_earned;

    return 0; // Success
}

/// Record miner block production
/// Returns FOOD tokens
pub fn record_miner_block(miner_address: u64, block_height: u32) u8 {
    const slot = find_or_create_activity_slot(miner_address, 2) orelse return 2; // 2 = MINER
    const activity = &activity_records[slot];

    const food_earned = reward_state.miner_food_per_block;

    activity.activity_type = 2; // MINER
    activity.status_token_earned = 2; // FOOD token
    activity.amount_earned +|= food_earned;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= 10; // 1 block ≈ ~10 TSC units

    reward_state.miner_count +|= 1;
    reward_state.miner_reward_pool +|= food_earned;
    reward_state.total_rewards_distributed +|= food_earned;

    _ = block_height; // For future use (difficulty scaling)

    return 0; // Success
}

/// Record DApp interaction (smart contract call)
/// Returns RENT tokens
pub fn record_dapp_interaction(user_address: u64, dapp_id: u32) u8 {
    const slot = find_or_create_activity_slot(user_address, 3) orelse return 2; // 3 = DAPP
    const activity = &activity_records[slot];

    var rent_earned = reward_state.dapp_rent_per_interaction;

    activity.activity_type = 3; // DAPP_INTERACTION
    activity.status_token_earned = 3; // RENT token
    activity.amount_earned +|= rent_earned;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= 50; // DApp interaction ≈ 50 TSC units

    reward_state.dapp_interaction_count +|= 1;
    reward_state.dapp_reward_pool +|= rent_earned;
    reward_state.total_rewards_distributed +|= rent_earned;

    _ = dapp_id;

    return 0; // Success
}

/// Record transaction participation
/// Returns VACATION tokens
pub fn record_transaction_participation(user_address: u64, tx_amount: u64) u8 {
    const slot = find_or_create_activity_slot(user_address, 4) orelse return 2; // 4 = TRANSACTION
    const activity = &activity_records[slot];

    var vacation_earned = reward_state.tx_vacation_per_tx;

    // Bonus for larger transactions
    if (tx_amount > 1000 * 1e18) {
        vacation_earned = (vacation_earned * 2) / 10; // 2x for large txs
    } else if (tx_amount > 100 * 1e18) {
        vacation_earned = (vacation_earned * 15) / 10; // 1.5x for medium txs
    }

    activity.activity_type = 4; // TRANSACTION
    activity.status_token_earned = 4; // VACATION token
    activity.amount_earned +|= vacation_earned;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= 30; // Transaction ≈ 30 TSC units

    reward_state.tx_count +|= 1;
    reward_state.tx_reward_pool +|= vacation_earned;
    reward_state.total_rewards_distributed +|= vacation_earned;

    return 0; // Success
}

/// Record long-term staking (bonus for holding OMNI)
/// Boosts LOVE token earnings
pub fn record_staking_engagement(user_address: u64, stake_duration_days: u32) u8 {
    const slot = find_or_create_activity_slot(user_address, 5) orelse return 2; // 5 = STAKING
    const activity = &activity_records[slot];

    // Calculate bonus based on duration
    var bonus_multiplier: u16 = 100; // 1.0x base
    if (stake_duration_days > 365) {
        bonus_multiplier = 300; // 3.0x for 1+ year
    } else if (stake_duration_days > 180) {
        bonus_multiplier = 200; // 2.0x for 6+ months
    } else if (stake_duration_days > 90) {
        bonus_multiplier = 150; // 1.5x for 3+ months
    }

    const love_bonus = (reward_state.validator_love_per_epoch * bonus_multiplier) / 100;

    activity.activity_type = 5; // STAKING
    activity.status_token_earned = 1; // LOVE token (bonus)
    activity.amount_earned +|= love_bonus;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= @intCast(stake_duration_days) * 1000;
    activity.level = @intCast((stake_duration_days / 30) & 0xFF); // Level = months

    reward_state.total_rewards_distributed +|= love_bonus;

    return 0; // Success
}

/// Record liquidity provision (bonus for providing DEX liquidity)
/// Boosts FOOD token earnings
pub fn record_liquidity_provision(user_address: u64, liquidity_amount: u64) u8 {
    const slot = find_or_create_activity_slot(user_address, 6) orelse return 2; // 6 = LIQUIDITY
    const activity = &activity_records[slot];

    // Bonus based on liquidity amount
    var bonus_multiplier: u16 = 100;
    if (liquidity_amount > 100_000 * 1e18) {
        bonus_multiplier = 250; // 2.5x for large pools
    } else if (liquidity_amount > 10_000 * 1e18) {
        bonus_multiplier = 200; // 2.0x for medium pools
    } else if (liquidity_amount > 1_000 * 1e18) {
        bonus_multiplier = 150; // 1.5x for small pools
    }

    const food_bonus = (reward_state.miner_food_per_block * bonus_multiplier) / 100;

    activity.activity_type = 6; // LIQUIDITY
    activity.status_token_earned = 2; // FOOD token (bonus)
    activity.amount_earned +|= food_bonus;
    activity.participation_count +|= 1;
    activity.last_activity_time = get_tsc();
    activity.total_time_engaged +|= 100;

    reward_state.total_rewards_distributed +|= food_bonus;

    return 0; // Success
}

/// Get total status tokens earned by user
pub fn get_user_status_tokens(user_address: u64) u64 {
    var total: u64 = 0;

    for (0..256) |i| {
        if (activity_records[i].address == user_address) {
            total +|= activity_records[i].amount_earned;
        }
    }

    return total;
}

/// Get participation level (0-255)
pub fn get_participation_level(user_address: u64) u8 {
    for (0..256) |i| {
        if (activity_records[i].address == user_address) {
            return activity_records[i].level;
        }
    }

    return 0;
}

/// Get activity count
pub fn get_activity_count(user_address: u64) u32 {
    for (0..256) |i| {
        if (activity_records[i].address == user_address) {
            return activity_records[i].participation_count;
        }
    }

    return 0;
}

// ============================================================================
// IPC Interface (Opcodes 0xB1–0xB8)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0xB1 => record_validator_ipc(arg0, arg1),      // validator participation
        0xB2 => record_miner_ipc(arg0, arg1),          // miner block
        0xB3 => record_dapp_ipc(arg0, arg1),           // dapp interaction
        0xB4 => record_transaction_ipc(arg0, arg1),    // transaction
        0xB5 => get_user_tokens_ipc(arg0, 0),          // get status tokens
        0xB6 => get_level_ipc(arg0, 0),                // get level
        0xB7 => get_activity_ipc(arg0, 0),             // get activity count
        0xB8 => run_reward_cycle(),                    // run_reward_cycle()
        else => 0xFFFFFFFF,
    };
}

fn record_validator_ipc(validator: u64, epoch: u64) u64 {
    const result = record_validator_participation(validator, @intCast(epoch));
    return if (result == 0) 1 else 0;
}

fn record_miner_ipc(miner: u64, block_height: u64) u64 {
    const result = record_miner_block(miner, @intCast(block_height));
    return if (result == 0) 1 else 0;
}

fn record_dapp_ipc(user: u64, dapp_id: u64) u64 {
    const result = record_dapp_interaction(user, @intCast(dapp_id));
    return if (result == 0) 1 else 0;
}

fn record_transaction_ipc(user: u64, amount: u64) u64 {
    const result = record_transaction_participation(user, amount);
    return if (result == 0) 1 else 0;
}

fn get_user_tokens_ipc(user: u64, _unused: u64) u64 {
    _ = _unused;
    return get_user_status_tokens(user);
}

fn get_level_ipc(user: u64, _unused: u64) u64 {
    _ = _unused;
    return get_participation_level(user);
}

fn get_activity_ipc(user: u64, _unused: u64) u64 {
    _ = _unused;
    return get_activity_count(user);
}

fn run_reward_cycle() u64 {
    // Periodic reward distribution
    // Could trigger batch token minting, level updates, etc.
    reward_state.last_distribution_block = get_tsc();
    return 1;
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn find_or_create_activity_slot(address: u64, activity_type: u8) ?usize {
    // First, try to find existing record for this address
    for (0..256) |i| {
        if (activity_records[i].address == address) {
            return i;
        }
    }

    // Otherwise, find empty slot
    for (0..256) |i| {
        if (activity_records[i].address == 0) {
            activity_records[i].address = address;
            activity_records[i].activity_type = activity_type;
            return i;
        }
    }

    return null; // No space
}

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
