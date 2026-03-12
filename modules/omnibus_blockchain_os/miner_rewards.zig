// Miner Rewards – GPU/ASIC Mining Reward Distribution
// Integrates GPU miners + ASIC miners with token distribution system
// Awards OMNI to miners for valid block solutions

const std = @import("std");
const distribution = @import("token_distribution.zig");

// ============================================================================
// MINER TYPES
// ============================================================================

pub const MinerType = enum(u8) {
    GPU_NVIDIA = 0,      // Nvidia RTX (CUDA)
    GPU_AMD = 1,         // AMD RDNA (HIP)
    ASIC_ANTMINER = 2,   // Bitmain Antminer S-series
    ASIC_WHATSMINER = 3, // MicroBT Whatsminer
    CPU = 4,             // CPU mining fallback
};

pub const MinerReward = struct {
    miner_address: [64]u8,
    address_len: u8,
    miner_type: MinerType,

    blocks_found: u64,           // Total valid blocks submitted
    blocks_confirmed: u64,       // Blocks that made it into chain
    total_reward_omni: u64,      // Total OMNI earned

    last_block_time: u64,        // Timestamp of last block
    last_claim_time: u64,        // When rewards were last claimed

    hashrate: u64,               // Hashes per second (for stats)
    uptime_seconds: u64,         // How long mining

    gpu_memory_mb: u32 = 0,      // For GPU: memory size
    gpu_cores: u16 = 0,          // GPU core count
    asic_power_watts: u16 = 0,   // For ASIC: power consumption
};

pub const MinerPoolEntry = struct {
    pool_name: [32]u8,
    pool_len: u8,

    pool_address: [64]u8,
    address_len: u8,

    miners_count: u32,           // Miners in this pool
    total_hashrate: u64,         // Combined hashrate
    total_blocks_found: u64,     // Total shares converted to blocks
    pool_reward_omni: u64,       // Accumulated rewards
};

pub const MinerRewardsState = struct {
    // Individual miner tracking
    miners: [1024]MinerReward = undefined,
    miner_count: u32 = 0,

    // Pool tracking
    pools: [64]MinerPoolEntry = undefined,
    pool_count: u8 = 0,

    // Statistics
    total_miners_active: u32 = 0,
    total_hashrate: u64 = 0,      // Global hashrate
    total_blocks_mined: u64 = 0,
    total_omni_distributed: u64 = 0,

    // Block reward config
    base_reward_per_block: u64 = 50_000_000_000, // 50 OMNI in smallest units
    difficulty_adjustment_period: u32 = 2016,
    current_difficulty: u32 = 1,

    // Mining parameters
    target_block_time_seconds: u32 = 600, // 10 minutes (like Bitcoin)
    block_reward_halving_interval: u64 = 210_000, // Halve every 210k blocks

    // Difficulty bonus for confirmed blocks
    bonus_percent_per_confirmation: u8 = 2, // +2% reward after N confirmations
};

var miner_state: MinerRewardsState = undefined;

// ============================================================================
// MINER REGISTRATION
// ============================================================================

/// Register a new miner (GPU or ASIC)
pub fn register_miner(
    address: [64]u8,
    address_len: u8,
    miner_type: MinerType,
    hashrate: u64,
) bool {
    if (miner_state.miner_count >= 1024) return false;

    var miner: MinerReward = undefined;
    miner.miner_address = address;
    miner.address_len = address_len;
    miner.miner_type = miner_type;
    miner.blocks_found = 0;
    miner.blocks_confirmed = 0;
    miner.total_reward_omni = 0;
    miner.last_block_time = 0;
    miner.last_claim_time = std.time.timestamp();
    miner.hashrate = hashrate;
    miner.uptime_seconds = 0;

    miner_state.miners[miner_state.miner_count] = miner;
    miner_state.miner_count += 1;
    miner_state.total_miners_active += 1;
    miner_state.total_hashrate += hashrate;

    return true;
}

/// Register a mining pool
pub fn register_pool(
    pool_name: [32]u8,
    pool_len: u8,
    pool_address: [64]u8,
    address_len: u8,
) bool {
    if (miner_state.pool_count >= 64) return false;

    var pool: MinerPoolEntry = undefined;
    pool.pool_name = pool_name;
    pool.pool_len = pool_len;
    pool.pool_address = pool_address;
    pool.address_len = address_len;
    pool.miners_count = 0;
    pool.total_hashrate = 0;
    pool.total_blocks_found = 0;
    pool.pool_reward_omni = 0;

    miner_state.pools[miner_state.pool_count] = pool;
    miner_state.pool_count += 1;

    return true;
}

// ============================================================================
// BLOCK REWARD DISTRIBUTION
// ============================================================================

/// Award OMNI to miner for finding a valid block
pub fn award_block_reward(
    miner_address: [64]u8,
    address_len: u8,
    block_height: u64,
) bool {
    // Find miner in registry
    var miner_idx: ?usize = null;
    for (0..miner_state.miner_count) |i| {
        if (miner_state.miners[i].address_len == address_len and
            std.mem.eql(u8, &miner_state.miners[i].miner_address[0..address_len], &miner_address[0..address_len])) {
            miner_idx = i;
            break;
        }
    }

    if (miner_idx == null) return false;

    var miner = &miner_state.miners[miner_idx.?];

    // Calculate reward (includes halving)
    const reward = calculate_block_reward(block_height);

    miner.blocks_found += 1;
    miner.total_reward_omni += reward;
    miner.last_block_time = std.time.timestamp();

    miner_state.total_blocks_mined += 1;
    miner_state.total_omni_distributed += reward;

    return true;
}

fn calculate_block_reward(block_height: u64) u64 {
    const halving_interval = miner_state.block_reward_halving_interval;
    const base_reward = miner_state.base_reward_per_block;

    const halvings = block_height / halving_interval;

    // Prevent overflow: cap at 64 halvings
    if (halvings >= 64) {
        return 0; // No more reward after 64 halvings
    }

    // Reward = base / 2^halvings
    return base_reward >> @intCast(halvings);
}

/// Claim accumulated rewards for a miner
pub fn claim_miner_rewards(
    miner_address: [64]u8,
    address_len: u8,
) u64 {
    // Find miner
    for (0..miner_state.miner_count) |i| {
        if (miner_state.miners[i].address_len == address_len and
            std.mem.eql(u8, &miner_state.miners[i].miner_address[0..address_len], &miner_address[0..address_len])) {

            const miner = &miner_state.miners[i];
            const reward_amount = miner.total_reward_omni;

            // Transfer to miner's account via token system
            // TODO: Call token distribution system to transfer tokens

            miner.total_reward_omni = 0;
            miner.last_claim_time = std.time.timestamp();

            return reward_amount;
        }
    }

    return 0;
}

// ============================================================================
// MINING DIFFICULTY & ADJUSTMENT
// ============================================================================

/// Adjust mining difficulty based on block production rate
pub fn adjust_difficulty(current_block_height: u64) void {
    if (current_block_height % miner_state.difficulty_adjustment_period == 0) {
        // Difficulty adjustment logic:
        // - If blocks are coming too fast: increase difficulty
        // - If blocks are coming too slow: decrease difficulty
        // - Aim for target_block_time_seconds average

        if (current_block_height == 0) return;

        const period = miner_state.difficulty_adjustment_period;
        _ = if (current_block_height >= period) period else current_block_height;

        // Adjustment: max 4x up or 0.25x down per period
        if (current_block_height > period) {
            // Compare actual vs target
            if (miner_state.total_hashrate > 0) {
                // Simplified: increase difficulty if hashrate grows
                miner_state.current_difficulty = miner_state.current_difficulty +| 1;
            }
        }
    }
}

// ============================================================================
// STATISTICS & QUERIES
// ============================================================================

/// Get total OMNI earned by a miner so far
pub fn get_miner_earnings(
    miner_address: [64]u8,
    address_len: u8,
) u64 {
    for (0..miner_state.miner_count) |i| {
        if (miner_state.miners[i].address_len == address_len and
            std.mem.eql(u8, &miner_state.miners[i].miner_address[0..address_len], &miner_address[0..address_len])) {
            return miner_state.miners[i].total_reward_omni;
        }
    }
    return 0;
}

/// Get miner statistics
pub fn get_miner_stats(
    miner_address: [64]u8,
    address_len: u8,
) struct {
    blocks_found: u64,
    blocks_confirmed: u64,
    total_reward_omni: u64,
    hashrate: u64,
    uptime_seconds: u64,
} {
    for (0..miner_state.miner_count) |i| {
        if (miner_state.miners[i].address_len == address_len and
            std.mem.eql(u8, &miner_state.miners[i].miner_address[0..address_len], &miner_address[0..address_len])) {
            const m = &miner_state.miners[i];
            return .{
                .blocks_found = m.blocks_found,
                .blocks_confirmed = m.blocks_confirmed,
                .total_reward_omni = m.total_reward_omni,
                .hashrate = m.hashrate,
                .uptime_seconds = m.uptime_seconds,
            };
        }
    }

    return .{
        .blocks_found = 0,
        .blocks_confirmed = 0,
        .total_reward_omni = 0,
        .hashrate = 0,
        .uptime_seconds = 0,
    };
}

/// Get global mining statistics
pub fn get_global_stats() struct {
    total_miners: u32,
    total_hashrate: u64,
    total_blocks_mined: u64,
    total_omni_distributed: u64,
    current_difficulty: u32,
    current_block_reward: u64,
} {
    return .{
        .total_miners = miner_state.total_miners_active,
        .total_hashrate = miner_state.total_hashrate,
        .total_blocks_mined = miner_state.total_blocks_mined,
        .total_omni_distributed = miner_state.total_omni_distributed,
        .current_difficulty = miner_state.current_difficulty,
        .current_block_reward = miner_state.base_reward_per_block,
    };
}

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init() void {
    miner_state.miner_count = 0;
    miner_state.pool_count = 0;
    miner_state.total_miners_active = 0;
    miner_state.total_hashrate = 0;
    miner_state.total_blocks_mined = 0;
    miner_state.total_omni_distributed = 0;
    miner_state.current_difficulty = 1;
}
