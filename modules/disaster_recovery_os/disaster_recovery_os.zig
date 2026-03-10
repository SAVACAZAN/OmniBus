const types = @import("recovery_types.zig");

fn getRecoveryStatePtr() *volatile types.RecoveryState {
    return @as(*volatile types.RecoveryState, @ptrFromInt(types.RECOVERY_BASE));
}

pub fn init_plugin() void {
    const state = getRecoveryStatePtr();
    state.magic = 0x52434F56;
    state.flags = 0;
    state.cycle_count = 0;
    state.checkpoints_created = 0;
    state.recovery_attempts = 0;
    state.last_checkpoint_cycle = 0;
    state.checkpoint_interval = 262144;
    state.enabled = 1;
}

pub fn create_checkpoint() void {
    const state = getRecoveryStatePtr();
    state.checkpoints_created +|= 1;
    state.last_checkpoint_cycle = state.cycle_count;
}

pub fn run_recovery_cycle() void {
    const state = getRecoveryStatePtr();
    state.cycle_count +|= 1;
    if ((state.cycle_count - state.last_checkpoint_cycle) > state.checkpoint_interval) {
        create_checkpoint();
    }
}
