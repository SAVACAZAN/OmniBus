const types = @import("dao_types.zig");

fn getDaoStatePtr() *volatile types.DaoState {
    return @as(*volatile types.DaoState, @ptrFromInt(types.DAO_BASE));
}

pub fn init_plugin() void {
    const state = getDaoStatePtr();
    state.magic = 0x44414F21;
    state.flags = 0;
    state.cycle_count = 0;
    state.proposals_created = 0;
    state.proposals_passed = 0;
    state.proposals_failed = 0;
    state.quorum_percent = 66;
    state.voting_period_cycles = 131072;
    state.proposal_count = 0;
}

pub fn create_proposal(proposal_type: u8) u16 {
    const state = getDaoStatePtr();
    if (state.proposal_count >= types.MAX_PROPOSALS) return 0xFFFF;
    const prop_id: u16 = @as(u16, @intCast(state.proposal_count));
    _ = proposal_type;
    state.proposals_created +|= 1;
    state.proposal_count += 1;
    return prop_id;
}

pub fn run_dao_cycle() void {
    const state = getDaoStatePtr();
    state.cycle_count +|= 1;
}
