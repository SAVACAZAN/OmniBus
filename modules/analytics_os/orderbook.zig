// orderbook.zig — Orderbook state management for Analytics OS
// Tracks live orderbook snapshots from all exchanges for MEV detection

const types = @import("types.zig");
const std = @import("std");

// Get pointer to orderbook state
fn getOrderbookStatePtr() *volatile types.OrderbookState {
    return @as(*volatile types.OrderbookState, @ptrFromInt(types.ORDERBOOK_BASE));
}

// Initialize orderbook state
pub fn init() void {
    const state = getOrderbookStatePtr();

    // Zero-initialize all orderbook slices
    var pair_idx: usize = 0;
    while (pair_idx < 3) : (pair_idx += 1) {
        var exchange_idx: usize = 0;
        while (exchange_idx < 3) : (exchange_idx += 1) {
            state.slices[pair_idx][exchange_idx].pair_id = @intCast(pair_idx);
            state.slices[pair_idx][exchange_idx].exchange_id = @intCast(exchange_idx);
            state.slices[pair_idx][exchange_idx].bid_count = 0;
            state.slices[pair_idx][exchange_idx].ask_count = 0;
            state.slices[pair_idx][exchange_idx].best_bid = 0;
            state.slices[pair_idx][exchange_idx].best_ask = 0;
            state.slices[pair_idx][exchange_idx].spread_bps = 0;
            state.slices[pair_idx][exchange_idx].update_tsc = 0;
        }
    }

    state.cycle_count = 0;
    state.updates_received = 0;
    state.stale_count = 0;
}

// Update orderbook snapshot for a specific pair/exchange
pub fn updateOrderbook(
    pair_id: u16,
    exchange_id: u8,
    bids: [*]const types.OrderbookLevel,
    bid_count: u8,
    asks: [*]const types.OrderbookLevel,
    ask_count: u8,
    tsc: u64,
) void {
    if (pair_id >= 3 or exchange_id >= 3) return;

    const state = getOrderbookStatePtr();
    var slice = &state.slices[pair_id][exchange_id];

    // Copy bids (top 20 levels)
    slice.bid_count = if (bid_count > 20) 20 else bid_count;
    var i: u8 = 0;
    while (i < slice.bid_count) : (i += 1) {
        slice.bids[i] = bids[i];
    }

    // Copy asks (top 20 levels)
    slice.ask_count = if (ask_count > 20) 20 else ask_count;
    i = 0;
    while (i < slice.ask_count) : (i += 1) {
        slice.asks[i] = asks[i];
    }

    // Calculate best bid/ask and spread
    if (slice.bid_count > 0 and slice.ask_count > 0) {
        slice.best_bid = slice.bids[0].price_cents;
        slice.best_ask = slice.asks[0].price_cents;

        // Spread in basis points: (ask - bid) / bid × 10000
        if (slice.best_bid > 0) {
            const spread_raw = (slice.best_ask - slice.best_bid) * 10000 / slice.best_bid;
            slice.spread_bps = @intCast(@min(spread_raw, 65535));  // Cap at u16 max
        } else {
            slice.spread_bps = 0;
        }
    }

    slice.update_tsc = tsc;
    state.updates_received +%= 1;
}

// Get best bid for a pair across all exchanges
pub fn getBestBid(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;

    const state = getOrderbookStatePtr();
    var best: u64 = 0;

    var exchange_idx: u8 = 0;
    while (exchange_idx < 3) : (exchange_idx += 1) {
        const slice = &state.slices[pair_id][exchange_idx];
        if (slice.best_bid > best) {
            best = slice.best_bid;
        }
    }

    return best;
}

// Get best ask for a pair across all exchanges
pub fn getBestAsk(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;

    const state = getOrderbookStatePtr();
    var best: u64 = 0xFFFFFFFFFFFFFFFF;

    var exchange_idx: u8 = 0;
    while (exchange_idx < 3) : (exchange_idx += 1) {
        const slice = &state.slices[pair_id][exchange_idx];
        if (slice.best_ask > 0 and slice.best_ask < best) {
            best = slice.best_ask;
        }
    }

    return if (best == 0xFFFFFFFFFFFFFFFF) 0 else best;
}

// Get spread between best bid and ask
pub fn getSpread(pair_id: u16) u16 {
    const bid = getBestBid(pair_id);
    const ask = getBestAsk(pair_id);

    if (bid == 0 or ask == 0 or bid >= ask) return 0;

    const spread_raw = (ask - bid) * 10000 / bid;
    return @intCast(@min(spread_raw, 65535));
}

// Get specific exchange orderbook slice
pub fn getOrderbookSlice(pair_id: u16, exchange_id: u8) ?*volatile types.OrderbookSlice {
    if (pair_id >= 3 or exchange_id >= 3) return null;

    const state = getOrderbookStatePtr();
    return &state.slices[pair_id][exchange_id];
}

// Check if orderbook is fresh (within 5 seconds)
pub fn isFresh(pair_id: u16, exchange_id: u8, current_tsc: u64) bool {
    const slice = getOrderbookSlice(pair_id, exchange_id) orelse return false;

    // Assume ~2GHz CPU: 5 seconds = 10B cycles
    // For determinism, use fixed threshold
    const MAX_AGE_CYCLES: u64 = 10_000_000_000;  // 5 seconds at 2GHz

    return (current_tsc - slice.update_tsc) < MAX_AGE_CYCLES;
}

// Increment cycle counter
pub fn updateCycleCount() void {
    const state = getOrderbookStatePtr();
    state.cycle_count +%= 1;
}

// Get current cycle count
pub fn getCycleCount() u64 {
    const state = getOrderbookStatePtr();
    return state.cycle_count;
}
