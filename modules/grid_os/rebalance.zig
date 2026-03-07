// rebalance.zig — Grid rebalancing when price drifts beyond bounds
// Shifts grid up/down and manages order cancellation/creation

const types = @import("types.zig");
const math = @import("math.zig");
const grid = @import("grid.zig");
const order = @import("order.zig");
const feed_reader = @import("feed_reader.zig");

// ============================================================================
// Rebalance State
// ============================================================================

/// Rebalance state structure at 0x114700
const RebalanceState = extern struct {
    trigger_pct: u32,              // Threshold percentage (e.g., 500 = 5%)
    last_rebalance_tsc: u64,       // TSC of last rebalance
    rebalance_count: u32,          // Total rebalances performed
    pending_fill_count: u32,       // Unfilled orders from old grid
    _pad: [8]u8 = [_]u8{0} ** 8,  // = 32 bytes
};

/// Get mutable pointer to rebalance state
fn getRebalanceState() *volatile RebalanceState {
    return @as(*volatile RebalanceState, @ptrFromInt(types.GRID_BASE + types.REBALANCE_STATE_OFFSET));
}

// ============================================================================
// Rebalance Detection
// ============================================================================

/// Check if rebalancing should be triggered
pub fn shouldRebalance(current_price: u64, lower_bound: u64, upper_bound: u64) bool {
    const state = getRebalanceState();
    return math.shouldRebalance(current_price, lower_bound, upper_bound, state.trigger_pct);
}

/// Get price drift from grid center
pub fn getPriceDrift(current_price: u64, lower_bound: u64, upper_bound: u64) struct {
    drift_cents: i64,
    drift_pct: u32,
} {
    const midpoint = grid.getGridCenter(lower_bound, upper_bound);

    const drift_cents: i64 = @as(i64, @intCast(current_price)) - @as(i64, @intCast(midpoint));
    const abs_drift = @abs(drift_cents);

    const drift_pct = @as(u32, @intCast((abs_drift * 10000) / @max(midpoint, 1)));

    return .{
        .drift_cents = drift_cents,
        .drift_pct = drift_pct,
    };
}

// ============================================================================
// Rebalance Execution
// ============================================================================

/// Execute full grid rebalance
/// 1. Shift bounds
/// 2. Cancel unfilled orders outside new bounds
/// 3. Generate new levels
/// Returns new level count
pub fn rebalanceGrid(
    current_price: u64,
    old_lower: u64,
    old_upper: u64,
    step_cents: u64,
    quantity_per_level: u64,
) u32 {
    // Calculate new bounds (shift by step * (drift / step))
    const new_bounds = math.calcRebalancedBounds(current_price, old_lower, old_upper, step_cents);

    // Mark pending fills (orders outside new bounds will be cancelled)
    const state = getRebalanceState();
    state.pending_fill_count = countOrdersOutsideBounds(new_bounds.lower, new_bounds.upper);

    // Clear grid and regenerate
    grid.clearGrid();

    // Generate new levels
    const new_level_count = grid.calculateGrid(
        0,
        current_price,
        new_bounds.lower,
        new_bounds.upper,
        step_cents,
        quantity_per_level,
    );

    // Update rebalance state
    state.last_rebalance_tsc = rdtsc();
    state.rebalance_count += 1;

    return new_level_count;
}

/// Count orders outside price bounds
fn countOrdersOutsideBounds(lower: u64, upper: u64) u32 {
    const orders = @as([*]volatile types.Order, @ptrFromInt(types.GRID_BASE + types.ORDER_OFFSET));
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;

        if (orders[i].price_cents < lower or orders[i].price_cents > upper) {
            if (orders[i].status == .pending) {
                count += 1;
            }
        }
    }

    return count;
}

// ============================================================================
// Rebalance State Management
// ============================================================================

/// Set rebalance trigger threshold
pub fn setTriggerThreshold(trigger_pct: u32) void {
    const state = getRebalanceState();
    state.trigger_pct = trigger_pct;
}

/// Get current rebalance count
pub fn getRebalanceCount() u32 {
    const state = getRebalanceState();
    return state.rebalance_count;
}

/// Get time since last rebalance (TSC cycles)
pub fn getTimeSinceLastRebalance() u64 {
    const state = getRebalanceState();
    const current = rdtsc();

    return if (current > state.last_rebalance_tsc)
        current - state.last_rebalance_tsc
    else
        0;
}

/// Get pending fill count from last rebalance
pub fn getPendingFillCount() u32 {
    const state = getRebalanceState();
    return state.pending_fill_count;
}

/// Initialize rebalance state
pub fn init(trigger_pct: u32) void {
    const state = getRebalanceState();
    state.* = .{
        .trigger_pct = trigger_pct,
        .last_rebalance_tsc = 0,
        .rebalance_count = 0,
        .pending_fill_count = 0,
    };
}

// ============================================================================
// Rebalance Strategy Helpers
// ============================================================================

/// Determine if should shift grid up (price above midpoint)
pub fn isPriceAboveCenter(current_price: u64, lower: u64, upper: u64) bool {
    const center = grid.getGridCenter(lower, upper);
    return current_price > center;
}

/// Determine if should shift grid down (price below midpoint)
pub fn isPriceBelowCenter(current_price: u64, lower: u64, upper: u64) bool {
    const center = grid.getGridCenter(lower, upper);
    return current_price < center;
}

/// Calculate shift amount needed (in steps)
pub fn calcShiftSteps(current_price: u64, lower: u64, upper: u64, step_cents: u64) i32 {
    const center = grid.getGridCenter(lower, upper);

    if (current_price > center) {
        const drift = current_price - center;
        return @as(i32, @intCast(drift / step_cents));
    } else {
        const drift = center - current_price;
        return -@as(i32, @intCast(drift / step_cents));
    }
}

/// Check if pending orders should be converted to market orders
/// (if new price is far from old levels)
pub fn shouldForceCancelPending(distance_cents: u64, max_distance: u64) bool {
    return distance_cents > max_distance;
}

// ============================================================================
// Utilities
// ============================================================================

/// Read current TSC
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
