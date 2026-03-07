// grid_os.zig — Root Grid OS module
// Exports: init_plugin(), run_grid_cycle(), register_pair(), get_last_profit()
// Memory: 0x110000–0x12FFFF (128KB)

const std = @import("std");

const types = @import("types.zig");
const math = @import("math.zig");
const grid = @import("grid.zig");
const order = @import("order.zig");
const feed_reader = @import("feed_reader.zig");
const scanner = @import("scanner.zig");
const rebalance = @import("rebalance.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var pair_count: u32 = 0;
var cycle_count: u64 = 0;
var total_profit: i64 = 0;

// ============================================================================
// GridState Helper
// ============================================================================

/// Get mutable pointer to grid state header
fn getGridStatePtr() *volatile types.GridState {
    return @as(*volatile types.GridState, @ptrFromInt(types.GRID_BASE + types.GRIDSTATE_OFFSET));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Grid OS plugin
/// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Zero-fill all memory segments
    const grid_state = getGridStatePtr();
    grid_state.* = .{
        .magic = 0x47524944, // "GRID"
        .pair_id = 0,
        .flags = 0,
        .lower_bound = 0,
        .upper_bound = 0,
        .step_cents = 0,
        .last_trade_profit = 0,
        .tsc_last_update = 0,
        .level_count = 0,
        .order_count = 0,
    };

    grid.clearGrid();
    order.clearAll();
    scanner.clearAll();
    rebalance.init(500); // Default 5% rebalance threshold

    initialized = true;
}

/// Main grid trading cycle
/// Called repeatedly by Ada Mother OS scheduler
export fn run_grid_cycle() void {
    // Auth gate: check if Ada's auth byte is set to 0x70
    const auth = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH)).*;
    if (auth != 0x70) return;

    // Bounded loop: process max 64 operations per cycle for determinism
    var processed: u32 = 0;
    const max_per_cycle: u32 = 64;

    while (processed < max_per_cycle) : (processed += 1) {
        // Read current price from Analytics OS
        const price = feed_reader.readPrice(0) orelse break; // Pair 0: BTC_USD

        // Update grid state TSC
        const grid_state = getGridStatePtr();
        grid_state.tsc_last_update = rdtsc();

        // Check rebalance trigger
        const bid_ask = feed_reader.readBidAsk(0) orelse break;
        if (rebalance.shouldRebalance(price, grid_state.lower_bound, grid_state.upper_bound)) {
            // Shift grid and regenerate levels
            const new_count = rebalance.rebalanceGrid(
                price,
                grid_state.lower_bound,
                grid_state.upper_bound,
                grid_state.step_cents,
                100_000_000, // 1 BTC per level
            );

            grid_state.level_count = new_count;
        }

        // Process pending orders: check fills, update status
        const pending = order.getFirstPendingForPair(0);
        if (pending) |pending_idx| {
            // In real system, would check Execution OS for fill status
            // For now, just track pending
            _ = pending_idx;
        }

        // Detect arbitrage opportunities
        if (bid_ask.bid > 0 and bid_ask.ask > 0) {
            const profit_bps = scanner.detectTwoExchange(0, 0, bid_ask.ask, 1, bid_ask.bid);
            if (profit_bps >= types.MIN_PROFIT_BPS) {
                // Register opportunity (would be executed by separate arbitrage module)
                _ = scanner.registerOpportunity(0, 0, 1, bid_ask.ask, bid_ask.bid, profit_bps, 80);
            }
        }
    }

    cycle_count += 1;
}

/// Register a trading pair for this Grid OS instance
/// Called by Ada or configuration module to enable pair tracking
export fn register_pair(pair_id: u16, lower_bound: u64, upper_bound: u64, step_cents: u64) void {
    if (pair_id >= 64 or step_cents == 0) return;

    const grid_state = getGridStatePtr();
    grid_state.pair_id = pair_id;
    grid_state.lower_bound = lower_bound;
    grid_state.upper_bound = upper_bound;
    grid_state.step_cents = step_cents;
    grid_state.flags = 0x01; // Mark as active

    pair_count += 1;

    // Generate initial grid
    const level_count = grid.calculateGrid(pair_id, (lower_bound + upper_bound) / 2, lower_bound, upper_bound, step_cents, 100_000_000);
    grid_state.level_count = @as(u32, @intCast(level_count));
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get current cycle count
export fn get_cycle_count() u64 {
    return cycle_count;
}

/// Get cumulative trading profit
export fn get_last_profit() i64 {
    return total_profit;
}

/// Get initialized state
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

/// Get pair count
export fn get_pair_count() u32 {
    return pair_count;
}

/// Get active order count
export fn get_order_count() u32 {
    return order.countActiveOrders();
}

/// Get grid level count
export fn get_level_count() u32 {
    const grid_state = getGridStatePtr();
    return grid_state.level_count;
}

/// Get total pending opportunities
export fn get_opportunity_count() u32 {
    return scanner.countPending();
}

// ============================================================================
// Debug & Testing Exports
// ============================================================================

/// Force rebalance (for testing)
export fn force_rebalance() void {
    const grid_state = getGridStatePtr();
    if (grid_state.step_cents == 0) return;

    const price = feed_reader.readPrice(0) orelse return;

    const new_count = rebalance.rebalanceGrid(
        price,
        grid_state.lower_bound,
        grid_state.upper_bound,
        grid_state.step_cents,
        100_000_000,
    );

    grid_state.level_count = new_count;
}

/// Test: manually inject DMA-like price update
export fn test_set_price(pair_id: u16, price_cents: u64) void {
    // For QEMU debugging only: would normally come from Analytics OS
    // This is a placeholder for testing the grid generation logic
    _ = pair_id;
    _ = price_cents;
}

/// Test: create sample order
export fn test_create_order(exchange_id: u16, pair_id: u16, side: u8, price_cents: u64, qty_sats: u64) u32 {
    const side_enum = if (side == 0) types.Side.buy else types.Side.sell;
    const order_id = order.createOrder(exchange_id, pair_id, side_enum, price_cents, qty_sats, 0);
    return order_id orelse 0xFFFFFFFF;
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
