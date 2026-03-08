// fill_tracker.zig — Track and writeback exchange fill responses
// Reads FillResult array, updates Grid OS order status, marks opportunities as executed

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// FillResult Access
// ============================================================================

/// Get mutable pointer to FillResult array (256 slots)
fn getFillResultArray() [*]volatile types.FillResult {
    return @as([*]volatile types.FillResult, @ptrFromInt(types.EXECUTION_BASE + types.FILL_RESULT_OFFSET));
}

// ============================================================================
// Grid OS Order Array Access (for writeback)
// ============================================================================

/// Grid OS Order struct (copied for reference)
const GridOrder = extern struct {
    pair_id: u16,
    side: u8,
    status: u8,              // 0=pending, 1=filled, 2=partial, 3=cancelled, 4=rejected
    price_cents: u64,
    quantity_sats: u64,
    filled_sats: u64,
    exchange_id: u16,
    _pad: [6]u8 = [_]u8{0} ** 6,
};

/// Get mutable pointer to Grid OS order array (writeback)
fn getGridOrderArray() [*]volatile GridOrder {
    return @as([*]volatile GridOrder, @ptrFromInt(types.GRID_ORDER_ARRAY));
}

// ============================================================================
// Arbitrage Opportunity Writeback (0x113840)
// ============================================================================

const ArbitrageOpportunity = extern struct {
    exchange_a: u8,
    exchange_b: u8,
    pair_id: u16,
    bid_exchange: u8,
    ask_exchange: u8,
    bid_price: u64,
    ask_price: u64,
    profit_bps: u32,
    status: u8,              // 0=pending, 1=executing, 2=executed, 3=failed
    _pad: [19]u8 = [_]u8{0} ** 19,
};

/// Get mutable pointer to arbitrage opportunity array
fn getArbOpportunityArray() [*]volatile ArbitrageOpportunity {
    return @as([*]volatile ArbitrageOpportunity, @ptrFromInt(types.GRID_ARB_BASE));
}

// ============================================================================
// Fill Status Constants
// ============================================================================

const FILL_STATUS_PENDING = 0;
const FILL_STATUS_FILLED = 1;
const FILL_STATUS_PARTIAL = 2;
const FILL_STATUS_REJECTED = 3;

const GRID_ORDER_STATUS_PENDING = 0;
const GRID_ORDER_STATUS_FILLED = 1;
const GRID_ORDER_STATUS_PARTIAL = 2;
const GRID_ORDER_STATUS_CANCELLED = 3;
const GRID_ORDER_STATUS_REJECTED = 4;

// ============================================================================
// Fill Processing
// ============================================================================

/// Process a single FillResult and writeback to Grid OS
/// Returns true if result was processed, false if empty
pub fn processFill(fill_idx: u32) bool {
    if (fill_idx >= types.MAX_FILL_RESULTS) {
        return false;
    }

    const fills = getFillResultArray();
    const fill = fills[fill_idx];

    // Skip empty results (order_id == 0)
    if (fill.order_id == 0) {
        return false;
    }

    // Writeback to Grid OS orders array
    const orders = getGridOrderArray();

    // Find matching order by order_id (simplified: assume order_id is index)
    // In production, would need proper order ID mapping
    if (fill.order_id < types.MAX_SIGNED_SLOTS) {
        const order_idx = fill.order_id;
        orders[order_idx].filled_sats = fill.filled_sats;
        orders[order_idx].status = switch (fill.status) {
            FILL_STATUS_PENDING => GRID_ORDER_STATUS_PENDING,
            FILL_STATUS_FILLED => GRID_ORDER_STATUS_FILLED,
            FILL_STATUS_PARTIAL => GRID_ORDER_STATUS_PARTIAL,
            FILL_STATUS_REJECTED => GRID_ORDER_STATUS_REJECTED,
            else => GRID_ORDER_STATUS_PENDING,
        };
    }

    return true;
}

/// Scan all FillResult slots and process any filled orders
/// Returns count of processed results
pub fn processAllFills() u32 {
    var count: u32 = 0;
    var i: u32 = 0;

    while (i < types.MAX_FILL_RESULTS) : (i += 1) {
        if (processFill(i)) {
            count += 1;
        }
    }

    return count;
}

// ============================================================================
// Opportunity Execution Tracking
// ============================================================================

/// Mark an arbitrage opportunity as executed
/// opp_idx: index in arbitrage opportunity array at 0x113840
pub fn markOpportunityExecuted(opp_idx: u32) void {
    if (opp_idx >= 256) {  // Assume max 256 opportunities
        return;
    }

    const opportunities = getArbOpportunityArray();
    opportunities[opp_idx].status = 2;  // Mark as executed
}

/// Mark an opportunity as failed
pub fn markOpportunityFailed(opp_idx: u32) void {
    if (opp_idx >= 256) {
        return;
    }

    const opportunities = getArbOpportunityArray();
    opportunities[opp_idx].status = 3;  // Mark as failed
}

// ============================================================================
// State Management
// ============================================================================

/// Check if a FillResult slot is occupied
pub fn isFillResultValid(fill_idx: u32) bool {
    if (fill_idx >= types.MAX_FILL_RESULTS) {
        return false;
    }

    const fills = getFillResultArray();
    return fills[fill_idx].order_id != 0;
}

/// Get count of valid FillResult entries
pub fn countValidFills() u32 {
    var count: u32 = 0;
    var i: u32 = 0;

    while (i < types.MAX_FILL_RESULTS) : (i += 1) {
        if (isFillResultValid(i)) {
            count += 1;
        }
    }

    return count;
}

/// Clear all FillResult entries (for reset)
pub fn clearAllFills() void {
    const fills = getFillResultArray();
    var i: u32 = 0;

    while (i < types.MAX_FILL_RESULTS) : (i += 1) {
        fills[i].order_id = 0;
        fills[i].status = 0;
    }
}

/// Write a test FillResult (for debugging)
pub fn writeTestFill(fill_idx: u32, order_id: u32, status: u8, filled_sats: u64) void {
    if (fill_idx >= types.MAX_FILL_RESULTS) {
        return;
    }

    const fills = getFillResultArray();
    fills[fill_idx].order_id = order_id;
    fills[fill_idx].pair_id = 0;
    fills[fill_idx].exchange_id = 0;
    fills[fill_idx].status = status;
    fills[fill_idx].filled_sats = filled_sats;
    fills[fill_idx].price_cents = 6_350_000;
    fills[fill_idx].tsc = 0;
}

// ============================================================================
// Debug Exports
// ============================================================================

/// Count current FillResult entries
export fn get_fill_result_count() u32 {
    return countValidFills();
}

/// Process all pending fills
export fn process_all_fills() u32 {
    return processAllFills();
}

/// Get specific FillResult (for inspection)
export fn get_fill_result(fill_idx: u32) types.FillResult {
    if (fill_idx >= types.MAX_FILL_RESULTS) {
        return .{
            .order_id = 0,
            .pair_id = 0,
            .exchange_id = 0,
            .status = 0,
            .filled_sats = 0,
            .price_cents = 0,
            .tsc = 0,
            ._reserved = [_]u8{0} ** 36,
        };
    }

    const fills = getFillResultArray();
    return fills[fill_idx];
}

/// Test: write a sample fill result
export fn test_write_fill() void {
    writeTestFill(0, 1, FILL_STATUS_FILLED, 100_000_000);
}

/// Test: process fills
export fn test_process_fills() u32 {
    return processAllFills();
}
