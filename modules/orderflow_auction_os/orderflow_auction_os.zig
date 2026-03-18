const types = @import("auction_types.zig");

fn getAuctionStatePtr() *volatile types.OrderflowAuctionState {
    return @as(*volatile types.OrderflowAuctionState, @ptrFromInt(types.AUCTION_BASE));
}

pub fn init_plugin() void {
    const state = getAuctionStatePtr();
    state.magic = 0x4F524441;
    state.flags = 0;
    state.cycle_count = 0;
    state.bundles_auctioned = 0;
    state.mev_captured = 0;
    state.total_revenue = 0;
    state.active_bundles = 0;
}

pub fn submit_bundle(bundle_id: u16, encrypted_payload: u64, bid: u64) void {
    const state = getAuctionStatePtr();
    _ = bundle_id;
    _ = encrypted_payload;
    state.bundles_auctioned +|= 1;
    state.total_revenue +|= bid;
    state.mev_captured +|= bid;
}

pub fn finalize_bundle(bundle_id: u16) void {
    _ = bundle_id;
}

pub fn run_auction_cycle() void {
    const state = getAuctionStatePtr();
    state.cycle_count +|= 1;
}
