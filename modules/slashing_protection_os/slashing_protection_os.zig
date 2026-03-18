const types = @import("slashing_types.zig");

fn getSlashingStatePtr() *volatile types.SlashingProtectionState {
    return @as(*volatile types.SlashingProtectionState, @ptrFromInt(types.SLASHING_BASE));
}

pub fn init_plugin() void {
    const state = getSlashingStatePtr();
    state.magic = 0x534C4153;
    state.flags = 0;
    state.cycle_count = 0;
    state.slashing_events = 0;
    state.total_penalties = 0;
    state.insured_amount = 0;
    state.active_validators = 0;
}

pub fn record_slashing_event(validator_id: u16, event_type: u8, penalty: u64) void {
    const state = getSlashingStatePtr();
    _ = validator_id;
    _ = event_type;
    state.slashing_events +|= 1;
    state.total_penalties +|= penalty;
}

pub fn claim_insurance() u64 {
    const state = getSlashingStatePtr();
    const payout = state.insured_amount;
    state.insured_amount = 0;
    return payout;
}

pub fn run_slashing_cycle() void {
    const state = getSlashingStatePtr();
    state.cycle_count +|= 1;
}
