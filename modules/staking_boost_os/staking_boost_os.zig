// ============================================================================
// Staking Boost OS (Zig/Bare Metal)
// OMNI staking with status token APY multipliers
// Non-transferable tokens provide boost without being transferred
// ============================================================================

const std = @import("std");

// Memory layout (0x580000 – 0x58FFFF, 64KB)
const STAKING_BASE: usize = 0x580000;

// Staking record (32 bytes each)
const StakeRecord = struct {
    staker_address: u64,        // OmniBus address
    amount_staked: u64,         // OMNI amount
    start_time: u64,            // Staking start timestamp
    last_claim: u64,            // Last reward claim timestamp
};

// Staking State Header (128 bytes @ 0x580000)
const StakingState = struct {
    magic: u32 = 0x5354424B,   // "STBK"
    version: u16 = 1,
    reserved: u16 = 0,

    // Base APY: 10% per year
    base_apy: u16 = 1000,       // 10% (stored as 10x)
    reserved2: u16 = 0,

    // Boost multipliers (stored as 100x, so 150 = 1.5x)
    boost_love: u16 = 150,      // LOVE: 1.5x
    boost_food: u16 = 180,      // FOOD: 1.8x
    boost_rent: u16 = 200,      // RENT: 2.0x
    boost_vaca: u16 = 250,      // VACATION: 2.5x

    // Tracking
    total_staked: u64,          // Total OMNI staked
    total_rewards_paid: u64,    // Total rewards claimed
    stake_count: u32,           // Number of stakers
    reserved3: u32 = 0,

    // Addresses
    omni_token_address: u64,    // OMNI token (for balanceOf)
    status_token_reader: u64,   // Module that reads status token balances
    last_update: u64,           // Timestamp
};

// Staking storage (256 records @ 0x580080)
const STAKES_ADDR: usize = STAKING_BASE + 128;
const MAX_STAKES: usize = 256;

var staking_state: StakingState = .{
    .magic = 0x5354424B,
    .version = 1,
    .base_apy = 1000,    // 10%
    .boost_love = 150,   // 1.5x
    .boost_food = 180,   // 1.8x
    .boost_rent = 200,   // 2.0x
    .boost_vaca = 250,   // 2.5x
    .total_staked = 0,
    .total_rewards_paid = 0,
    .stake_count = 0,
    .omni_token_address = 0x1000,
    .status_token_reader = 0x5600,
    .last_update = 0,
};

var stakes: [MAX_STAKES]StakeRecord = undefined;

// ============================================================================
// PUBLIC API
// ============================================================================

pub fn init_plugin() void {
    // Clear stake records
    for (0..MAX_STAKES) |i| {
        stakes[i] = .{
            .staker_address = 0,
            .amount_staked = 0,
            .start_time = 0,
            .last_claim = 0,
        };
    }

    staking_state.last_update = get_tsc();
}

/// Stake OMNI tokens
/// Returns: 0=success, 1=invalid, 2=full
pub fn stake(staker_address: u64, amount: u64) u8 {
    if (amount == 0) {
        return 1; // Invalid amount
    }

    // Find or create stake record
    var slot: usize = undefined;
    var found = false;
    var empty_slot: usize = undefined;

    for (0..MAX_STAKES) |i| {
        if (stakes[i].staker_address == staker_address) {
            slot = i;
            found = true;
            break;
        }
        if (!found and stakes[i].staker_address == 0) {
            empty_slot = i;
        }
    }

    if (!found) {
        // New staker
        for (0..MAX_STAKES) |i| {
            if (stakes[i].staker_address == 0) {
                slot = i;
                found = true;
                break;
            }
        }
    }

    if (!found) {
        return 2; // No space
    }

    const now = get_tsc();

    if (stakes[slot].staker_address == 0) {
        // New stake
        stakes[slot] = .{
            .staker_address = staker_address,
            .amount_staked = amount,
            .start_time = now,
            .last_claim = now,
        };
        staking_state.stake_count += 1;
    } else {
        // Add to existing stake
        stakes[slot].amount_staked +|= amount;
        stakes[slot].last_claim = now;
    }

    staking_state.total_staked +|= amount;
    staking_state.last_update = now;

    return 0; // Success
}

/// Unstake OMNI tokens
pub fn unstake(staker_address: u64, amount: u64) u8 {
    // Find stake
    var slot: usize = undefined;
    var found = false;
    for (0..MAX_STAKES) |i| {
        if (stakes[i].staker_address == staker_address) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 1; // Not staking
    }

    const stake = &stakes[slot];

    if (stake.amount_staked < amount) {
        return 1; // Insufficient stake
    }

    // Claim rewards first
    _ = claim_rewards(staker_address);

    stake.amount_staked -= amount;
    staking_state.total_staked -|= amount;

    if (stake.amount_staked == 0) {
        stake.staker_address = 0;
        staking_state.stake_count -|= 1;
    }

    staking_state.last_update = get_tsc();

    return 0; // Success
}

/// Calculate pending rewards based on boost multiplier
pub fn calculate_rewards(staker_address: u64) u64 {
    // Find stake
    const slot = find_stake(staker_address) orelse return 0;
    const stake = stakes[slot];

    if (stake.amount_staked == 0) {
        return 0;
    }

    // Time elapsed in seconds
    const now = get_tsc();
    const time_elapsed = if (now > stake.last_claim)
        now - stake.last_claim
    else
        0;

    // Skip if very recent
    if (time_elapsed < 1) {
        return 0;
    }

    // Get boost multiplier based on status token balance
    const multiplier = get_boost_multiplier(staker_address);

    // Calculate rewards: amount * base_apy * time_elapsed / seconds_per_year
    // Simplified for fixed-point: amount * 10% * time / 365 days
    const seconds_per_year: u64 = 365 * 24 * 60 * 60;

    const base_reward = ((stake.amount_staked / 100) * (staking_state.base_apy / 10)) * time_elapsed / seconds_per_year;

    // Apply multiplier (stored as 100x)
    const boosted_reward = (base_reward * multiplier) / 100;

    return boosted_reward;
}

/// Claim pending rewards
pub fn claim_rewards(staker_address: u64) u8 {
    const rewards = calculate_rewards(staker_address);

    if (rewards == 0) {
        return 0; // No rewards
    }

    // Find stake
    const slot = find_stake(staker_address) orelse return 1;
    const stake = &stakes[slot];

    // In production, would transfer/mint OMNI rewards here
    // For now, just update state
    stake.amount_staked +|= rewards;
    stake.last_claim = get_tsc();

    staking_state.total_rewards_paid +|= rewards;
    staking_state.total_staked +|= rewards;
    staking_state.last_update = get_tsc();

    return 0; // Success
}

/// Get boost multiplier based on status token holdings
/// Returns: multiplier as 100x (150 = 1.5x, 200 = 2.0x)
pub fn get_boost_multiplier(staker_address: u64) u16 {
    var multiplier: u16 = 100; // Base 1.0x

    // Check LOVE balance (token_type=1)
    const love_balance = get_status_token_balance(staker_address, 1);
    if (love_balance > 0) {
        multiplier += staking_state.boost_love - 100;
    }

    // Check FOOD balance (token_type=2)
    const food_balance = get_status_token_balance(staker_address, 2);
    if (food_balance > 0) {
        multiplier += staking_state.boost_food - 100;
    }

    // Check RENT balance (token_type=3)
    const rent_balance = get_status_token_balance(staker_address, 3);
    if (rent_balance > 0) {
        multiplier += staking_state.boost_rent - 100;
    }

    // Check VACATION balance (token_type=4)
    const vaca_balance = get_status_token_balance(staker_address, 4);
    if (vaca_balance > 0) {
        multiplier += staking_state.boost_vaca - 100;
    }

    return multiplier;
}

/// Get effective APY with boosts
pub fn get_effective_apy(staker_address: u64) u16 {
    const multiplier = get_boost_multiplier(staker_address);
    return (staking_state.base_apy * multiplier) / 100;
}

/// Get stake info
pub fn get_stake_info(staker_address: u64) ?StakeRecord {
    const slot = find_stake(staker_address) orelse return null;
    return stakes[slot];
}

/// Get total staked
pub fn get_total_staked() u64 {
    return staking_state.total_staked;
}

// ============================================================================
// IPC Interface (Opcodes 0x91–0x98)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0x91 => stake_ipc(arg0, arg1),              // stake(address, amount)
        0x92 => unstake_ipc(arg0, arg1),            // unstake(address, amount)
        0x93 => calculate_rewards_ipc(arg0, 0),     // calculate_rewards(address)
        0x94 => claim_rewards_ipc(arg0, 0),         // claim_rewards(address)
        0x95 => get_boost_multiplier_ipc(arg0, 0),  // get_boost_multiplier(address)
        0x96 => get_effective_apy_ipc(arg0, 0),     // get_effective_apy(address)
        0x97 => get_total_staked_ipc(),             // get_total_staked()
        0x98 => run_staking_cycle(),                // run_staking_cycle()
        else => 0xFFFFFFFF,
    };
}

fn stake_ipc(address: u64, amount: u64) u64 {
    const result = stake(address, amount);
    return if (result == 0) 1 else 0;
}

fn unstake_ipc(address: u64, amount: u64) u64 {
    const result = unstake(address, amount);
    return if (result == 0) 1 else 0;
}

fn calculate_rewards_ipc(address: u64, _unused: u64) u64 {
    _ = _unused;
    return calculate_rewards(address);
}

fn claim_rewards_ipc(address: u64, _unused: u64) u64 {
    _ = _unused;
    const result = claim_rewards(address);
    return if (result == 0) 1 else 0;
}

fn get_boost_multiplier_ipc(address: u64, _unused: u64) u64 {
    _ = _unused;
    return get_boost_multiplier(address);
}

fn get_effective_apy_ipc(address: u64, _unused: u64) u64 {
    _ = _unused;
    return get_effective_apy(address);
}

fn get_total_staked_ipc() u64 {
    return get_total_staked();
}

fn run_staking_cycle() u64 {
    // Periodic staking maintenance
    // Could trigger reward distribution, multiplier updates, etc.
    staking_state.last_update = get_tsc();
    return 1;
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn find_stake(staker_address: u64) ?usize {
    for (0..MAX_STAKES) |i| {
        if (stakes[i].staker_address == staker_address) {
            return i;
        }
    }
    return null;
}

fn get_status_token_balance(address: u64, token_type: u8) u64 {
    // Call status token module via IPC (opcode 0x73)
    const balance = call_status_token_ipc(0x73, token_type, address);
    return balance;
}

fn call_status_token_ipc(opcode: u8, token_type: u8, address: u64) u64 {
    _ = opcode;
    _ = token_type;
    _ = address;
    // TODO: Implement actual IPC to status token module
    // For now, return 0 (no boost)
    return 0;
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
