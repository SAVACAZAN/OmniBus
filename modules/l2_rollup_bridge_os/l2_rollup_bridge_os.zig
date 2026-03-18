const types = @import("rollup_types.zig");

fn getRollupStatePtr() *volatile types.L2RollupBridgeState {
    return @as(*volatile types.L2RollupBridgeState, @ptrFromInt(types.ROLLUP_BASE));
}

pub fn init_plugin() void {
    const state = getRollupStatePtr();
    state.magic = 0x524F4C4C;
    state.flags = 0;
    state.cycle_count = 0;
    state.transactions_bridged = 0;
    state.total_volume = 0;
    state.optimistic_proofs = 0;
    state.zk_proofs = 0;
    state.pending_finality = 0;
}

pub fn submit_optimistic_proof(tx_id: u32, amount: u64) void {
    const state = getRollupStatePtr();
    _ = tx_id;
    state.transactions_bridged +|= 1;
    state.total_volume +|= amount;
    state.optimistic_proofs +|= 1;
}

pub fn submit_zk_proof(tx_id: u32) void {
    _ = tx_id;
}

pub fn run_rollup_cycle() void {
    const state = getRollupStatePtr();
    state.cycle_count +|= 1;
}
