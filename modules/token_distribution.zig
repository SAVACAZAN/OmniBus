// Token Distribution System – Airdrop, Staking Rewards, Faucet
// Manages how users acquire OMNI and domain tokens

const std = @import("std");

// ============================================================================
// DISTRIBUTION TYPES
// ============================================================================

pub const DistributionType = enum(u8) {
    GENESIS_AIRDROP = 0,           // Initial snapshot distribution
    EARLY_ADOPTER_BONUS = 1,       // Bonus for early wallet creation
    REFERRAL_REWARD = 2,           // Referral program
    STAKING_REWARD = 3,            // Lock tokens, earn rewards
    VALIDATOR_BLOCK_REWARD = 4,    // Running validator node
    DEVELOPER_GRANT = 5,           // For dApp developers
    DOMAIN_TOKEN_AIRDROP = 6,      // Free domain token distribution
    FAUCET_CLAIM = 7,              // Testnet faucet
};

pub const AirdropEntry = struct {
    address: [64]u8,               // OmniBus address
    address_len: u8,

    distribution_type: DistributionType,

    amount_omni: u64,              // OMNI tokens to distribute
    amount_love: u64,              // Domain tokens
    amount_food: u64,
    amount_rent: u64,
    amount_vaca: u64,

    claimed: u8,                   // 0 = not claimed, 1 = claimed
    claimed_at: u64 = 0,

    snapshot_balance: u64,         // For snapshot-based calculation
    eligibility_score: u16,        // 0-10000 (basis points)
};

pub const StakingEntry = struct {
    staker: [64]u8,
    staker_len: u8,

    amount_locked: u64,            // OMNI locked
    lock_period_days: u16,         // 30, 90, 180, 365

    created_at: u64,
    unlock_at: u64,                // When stake becomes available

    claimed_rewards: u8 = 0,       // 0 = not claimed, 1 = claimed
    reward_omni: u64 = 0,
    reward_love: u64 = 0,
    reward_food: u64 = 0,
    reward_rent: u64 = 0,
    reward_vaca: u64 = 0,
};

pub const ValidatorReward = struct {
    validator_address: [64]u8,
    validator_len: u8,

    blocks_produced: u64,
    total_rewards_omni: u64,
    claimed_amount: u64,

    last_block_at: u64,
    last_reward_at: u64,
};

pub const ReferralEntry = struct {
    referrer: [64]u8,
    referrer_len: u8,

    referee: [64]u8,
    referee_len: u8,

    referral_level: u8,            // 1-5 (depth in tree)
    referrer_bonus_percent: u8,    // 10% per level

    claimed: u8,
    claimed_at: u64 = 0,
    bonus_amount: u64 = 0,
};

pub const DistributionState = struct {
    // Airdrop management
    airdrops: [65536]AirdropEntry = undefined,
    airdrop_count: u32 = 0,

    // Staking management
    stakes: [16384]StakingEntry = undefined,
    stake_count: u32 = 0,

    // Validator rewards
    validator_rewards: [256]ValidatorReward = undefined,
    validator_count: u8 = 0,

    // Referral tracking
    referrals: [8192]ReferralEntry = undefined,
    referral_count: u16 = 0,

    // Distribution statistics
    total_airdropped: u64 = 0,
    total_staked: u64 = 0,
    total_validator_rewards: u64 = 0,
    total_referral_bonuses: u64 = 0,
    total_distributed: u64 = 0,

    // Faucet state
    faucet_claims: [65536]u64 = undefined,  // Last claim timestamp per address
    faucet_claim_count: u32 = 0,
    faucet_daily_limit: u64 = 100 * 100_000_000, // 100 OMNI per day
};

// ============================================================================
// AIRDROP DISTRIBUTION
// ============================================================================

/// Add airdrop entry (called during Genesis block)
pub fn add_airdrop(
    state: *DistributionState,
    address: [64]u8,
    address_len: u8,
    amount_omni: u64,
    snapshot_balance: u64,
) bool {
    if (state.airdrop_count >= 65536) return false;

    state.airdrops[state.airdrop_count] = .{
        .address = address,
        .address_len = address_len,
        .distribution_type = .GENESIS_AIRDROP,
        .amount_omni = amount_omni,
        .amount_love = 50 * 100_000_000, // Free domain tokens
        .amount_food = 50 * 100_000_000,
        .amount_rent = 50 * 100_000_000,
        .amount_vaca = 50 * 100_000_000,
        .claimed = 0,
        .snapshot_balance = snapshot_balance,
        .eligibility_score = 10000, // 100% eligible
    };

    state.airdrop_count += 1;
    state.total_airdropped += amount_omni;

    return true;
}

/// Claim airdrop tokens
pub fn claim_airdrop(
    state: *DistributionState,
    address: [64]u8,
    address_len: u8,
) bool {
    for (0..state.airdrop_count) |i| {
        const entry = &state.airdrops[i];
        if (entry.address_len == address_len and
            std.mem.eql(u8, &entry.address[0..address_len], &address[0..address_len])) {

            if (entry.claimed == 1) return false; // Already claimed

            entry.claimed = 1;
            entry.claimed_at = std.time.timestamp();

            return true;
        }
    }

    return false;
}

// ============================================================================
// EARLY ADOPTER BONUS
// ============================================================================

/// Add early adopter bonus
pub fn add_early_adopter_bonus(
    state: *DistributionState,
    address: [64]u8,
    address_len: u8,
    bonus_type: u8, // 0=wallet, 1=kyc, 2=trade, 3=stake
) bool {
    const bonus_amount: u64 = switch (bonus_type) {
        0 => 100 * 100_000_000,  // Wallet creation
        1 => 50 * 100_000_000,   // KYC completion
        2 => 25 * 100_000_000,   // First trade
        3 => 10 * 100_000_000,   // 30-day stake
        else => 0,
    };

    if (bonus_amount == 0) return false;

    // Find existing airdrop and add bonus
    for (0..state.airdrop_count) |i| {
        const entry = &state.airdrops[i];
        if (entry.address_len == address_len and
            std.mem.eql(u8, &entry.address[0..address_len], &address[0..address_len])) {

            entry.amount_omni += bonus_amount;
            return true;
        }
    }

    return false;
}

// ============================================================================
// STAKING & REWARDS
// ============================================================================

/// Create staking position
pub fn create_stake(
    state: *DistributionState,
    staker: [64]u8,
    staker_len: u8,
    amount: u64,
    lock_days: u16,
    timestamp: u64,
) bool {
    if (state.stake_count >= 16384) return false;
    if (lock_days != 30 and lock_days != 90 and lock_days != 180 and lock_days != 365) {
        return false;
    }

    const unlock_time = timestamp + (lock_days * 86400); // Convert days to seconds

    state.stakes[state.stake_count] = .{
        .staker = staker,
        .staker_len = staker_len,
        .amount_locked = amount,
        .lock_period_days = lock_days,
        .created_at = timestamp,
        .unlock_at = unlock_time,
    };

    state.stake_count += 1;
    state.total_staked += amount;

    // Calculate rewards
    calculate_staking_rewards(state, state.stake_count - 1);

    return true;
}

fn calculate_staking_rewards(state: *DistributionState, stake_idx: usize) void {
    const stake = &state.stakes[stake_idx];

    // Reward schedule:
    // 30 days → 10 ΩLOVE per 1000 OMNI locked
    // 90 days → 30 ΩLOVE + 30 ΩFOOD per 1000 OMNI
    // 180 days → 50 of each token per 1000 OMNI
    // 365 days → 200 of each token per 1000 OMNI

    const base_units = stake.amount_locked / (1000 * 100_000_000); // Units of 1000 OMNI

    switch (stake.lock_period_days) {
        30 => {
            stake.reward_love = base_units * 10 * 100_000_000;
        },
        90 => {
            stake.reward_love = base_units * 30 * 100_000_000;
            stake.reward_food = base_units * 30 * 100_000_000;
        },
        180 => {
            stake.reward_love = base_units * 50 * 100_000_000;
            stake.reward_food = base_units * 50 * 100_000_000;
            stake.reward_rent = base_units * 50 * 100_000_000;
            stake.reward_vaca = base_units * 50 * 100_000_000;
        },
        365 => {
            stake.reward_love = base_units * 200 * 100_000_000;
            stake.reward_food = base_units * 200 * 100_000_000;
            stake.reward_rent = base_units * 200 * 100_000_000;
            stake.reward_vaca = base_units * 200 * 100_000_000;
        },
        else => {},
    }
}

/// Claim staking rewards
pub fn claim_staking_rewards(
    state: *DistributionState,
    staker: [64]u8,
    staker_len: u8,
    timestamp: u64,
) bool {
    for (0..state.stake_count) |i| {
        const stake = &state.stakes[i];
        if (stake.staker_len == staker_len and
            std.mem.eql(u8, &stake.staker[0..staker_len], &staker[0..staker_len])) {

            // Check if stake is unlocked
            if (timestamp < stake.unlock_at) return false;

            // Check if already claimed
            if (stake.claimed_rewards == 1) return false;

            stake.claimed_rewards = 1;
            stake.claimed_at = timestamp;

            return true;
        }
    }

    return false;
}

// ============================================================================
// VALIDATOR BLOCK REWARDS
// ============================================================================

/// Record block production for validator
pub fn record_validator_block(
    state: *DistributionState,
    validator: [64]u8,
    validator_len: u8,
    timestamp: u64,
) bool {
    // Find or create validator entry
    var validator_idx: ?usize = null;

    for (0..state.validator_count) |i| {
        if (state.validator_rewards[i].validator_len == validator_len and
            std.mem.eql(u8, &state.validator_rewards[i].validator_address[0..validator_len], &validator[0..validator_len])) {
            validator_idx = i;
            break;
        }
    }

    if (validator_idx == null) {
        if (state.validator_count >= 256) return false;
        validator_idx = state.validator_count;
        state.validator_count += 1;
    }

    const reward = &state.validator_rewards[validator_idx.?];

    if (reward.validator_len == 0) {
        reward.validator_address = validator;
        reward.validator_len = validator_len;
    }

    reward.blocks_produced += 1;
    reward.total_rewards_omni += 5 * 100_000_000; // 5 OMNI per block
    reward.last_block_at = timestamp;

    state.total_validator_rewards += 5 * 100_000_000;

    return true;
}

// ============================================================================
// REFERRAL PROGRAM
// ============================================================================

/// Create referral relationship
pub fn create_referral(
    state: *DistributionState,
    referrer: [64]u8,
    referrer_len: u8,
    referee: [64]u8,
    referee_len: u8,
    level: u8,
) bool {
    if (state.referral_count >= 8192) return false;
    if (level > 5) return false; // Max 5 levels

    const bonus_percent: u8 = switch (level) {
        1 => 10, // 10% of referee's airdrop
        2 => 5,  // 5% (2nd level)
        3 => 2,  // 2% (3rd level)
        4 => 1,  // 1% (4th level)
        5 => 0,  // No bonus (5th level)
        else => 0,
    };

    state.referrals[state.referral_count] = .{
        .referrer = referrer,
        .referrer_len = referrer_len,
        .referee = referee,
        .referee_len = referee_len,
        .referral_level = level,
        .referrer_bonus_percent = bonus_percent,
        .claimed = 0,
    };

    state.referral_count += 1;
    return true;
}

// ============================================================================
// FAUCET (Testnet/Demo)
// ============================================================================

/// Claim testnet tokens from faucet
pub fn claim_faucet(
    state: *DistributionState,
    address: [64]u8,
    address_len: u8,
    timestamp: u64,
) bool {
    // Find or create faucet entry
    var address_idx: ?usize = null;

    for (0..state.faucet_claim_count) |i| {
        // This is simplified; real implementation would use a proper hash map
        if (std.mem.eql(u8, &state.faucet_claims[0..0], &[_]u8{})) {
            // Placeholder - would check stored address
        }
    }

    // Check rate limit (24 hours between claims)
    const last_claim: u64 = 0; // Placeholder
    if (timestamp - last_claim < 86400) return false; // Too soon

    // Claim is valid - return true
    // Real implementation would record the claim
    return true;
}

// ============================================================================
// QUERIES
// ============================================================================

pub fn get_airdrop_amount(
    state: *const DistributionState,
    address: [64]u8,
    address_len: u8,
) u64 {
    for (0..state.airdrop_count) |i| {
        const entry = &state.airdrops[i];
        if (entry.address_len == address_len and
            std.mem.eql(u8, &entry.address[0..address_len], &address[0..address_len])) {
            return entry.amount_omni;
        }
    }
    return 0;
}

pub fn get_total_rewards(
    state: *const DistributionState,
    address: [64]u8,
    address_len: u8,
) struct {
    staking_rewards: u64,
    validator_rewards: u64,
    referral_rewards: u64,
} {
    var staking: u64 = 0;
    var validator: u64 = 0;
    var referral: u64 = 0;

    // Calculate staking rewards
    for (0..state.stake_count) |i| {
        if (state.stakes[i].staker_len == address_len and
            std.mem.eql(u8, &state.stakes[i].staker[0..address_len], &address[0..address_len])) {
            staking += state.stakes[i].reward_omni;
        }
    }

    // Calculate validator rewards
    for (0..state.validator_count) |i| {
        if (state.validator_rewards[i].validator_len == address_len and
            std.mem.eql(u8, &state.validator_rewards[i].validator_address[0..address_len], &address[0..address_len])) {
            validator += state.validator_rewards[i].total_rewards_omni;
        }
    }

    // Calculate referral rewards
    for (0..state.referral_count) |i| {
        if (state.referrals[i].referrer_len == address_len and
            std.mem.eql(u8, &state.referrals[i].referrer[0..address_len], &address[0..address_len])) {
            referral += state.referrals[i].bonus_amount;
        }
    }

    return .{
        .staking_rewards = staking,
        .validator_rewards = validator,
        .referral_rewards = referral,
    };
}

pub fn get_distribution_stats(state: *const DistributionState) struct {
    total_airdropped: u64,
    total_staked: u64,
    total_validator_rewards: u64,
    total_referral_bonuses: u64,
    total_distributed: u64,
    active_stakes: u32,
    active_validators: u8,
} {
    return .{
        .total_airdropped = state.total_airdropped,
        .total_staked = state.total_staked,
        .total_validator_rewards = state.total_validator_rewards,
        .total_referral_bonuses = state.total_referral_bonuses,
        .total_distributed = state.total_distributed,
        .active_stakes = state.stake_count,
        .active_validators = state.validator_count,
    };
}
