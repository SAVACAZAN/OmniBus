const types = @import("staking_types.zig");

fn getStakingStatePtr() *volatile types.LiquidStakingState {
    return @as(*volatile types.LiquidStakingState, @ptrFromInt(types.STAKING_BASE));
}

pub fn init_plugin() void {
    const state = getStakingStatePtr();
    state.magic = 0x5354414B;
    state.flags = 0;
    state.cycle_count = 0;
    state.total_staked = 0;
    state.total_rewards = 0;
    state.active_validators = 0;
    state.pending_unstakes = 0;
    state.avg_apr = 800; // 8% APR
}

pub fn stake_eth(validator_id: u16, amount: u64) void {
    const state = getStakingStatePtr();
    _ = validator_id;
    state.total_staked +|= amount;
    state.active_validators +|= 1;
}

pub fn claim_rewards() u64 {
    const state = getStakingStatePtr();
    const rewards = state.total_rewards;
    state.total_rewards = 0;
    return rewards;
}

pub fn run_staking_cycle() void {
    const state = getStakingStatePtr();
    state.cycle_count +|= 1;
    const accrual: u64 = (state.total_staked * 8) / 10000;
    state.total_rewards +|= accrual;
}
