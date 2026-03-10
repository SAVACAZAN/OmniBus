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
const multi_exchange = @import("multi_exchange.zig");

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

/// Neuro feedback state (for metrics tracking)
var last_population_size: u64 = 0;
var last_generation: u64 = 0;
var feedback_updates: u64 = 0;

/// Read NeuroOS evolved parameters from export buffer (0x120040+)
/// Returns adjusted step_cents based on population size feedback
fn readNeuroOSParameters() u64 {
    const neuro_export_base: usize = 0x120040;
    const population_size = @as(*volatile u64, @ptrFromInt(neuro_export_base)).*;
    const generation = @as(*volatile u64, @ptrFromInt(neuro_export_base + 8)).*;
    const valid_flag = @as(*volatile u8, @ptrFromInt(neuro_export_base + 16)).*;

    // Use population size to adjust grid spacing
    // Higher population = more aggressive spacing (smaller step)
    // Lower population = wider spacing (larger step)
    if (valid_flag == 0x01) {
        // Track feedback metrics
        if (population_size != last_population_size or generation != last_generation) {
            last_population_size = population_size;
            last_generation = generation;
            feedback_updates += 1;
        }

        // Population ranges 1-256, we map to step adjustment
        // Base step = 100 cents, scale by population
        const adjusted_step = (100 * (256 - population_size)) / 256;
        return if (adjusted_step > 10) adjusted_step else 10; // Min 10 cents
    }

    return 100; // Default step if no valid neuro parameters
}

/// Export feedback metrics to shared buffer for monitoring
/// Called by kernel to report how many times NeuroOS parameters changed Grid behavior
pub fn getNeuroFeedbackStats() u64 {
    return feedback_updates;
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

    // === PHASE 20: READ NEURO PARAMETERS (Throttled) ===
    // Get evolved parameters from NeuroOS (feedback loop)
    // OPTIMIZATION: Only re-read every 64 cycles (parameter changes rarely)
    if (cycle_count % 64 == 0) {
        // Poll NeuroOS parameters at most once per 64 cycles
        _ = readNeuroOSParameters();
    }
    const evolved_step = readNeuroOSParameters();

    // === PHASE 10: MULTI-EXCHANGE ARBITRAGE (Hoisted) ===
    // OPTIMIZATION: Detect opportunities once per cycle BEFORE main loop
    // This replaces 64 × 9 volatile reads with just 9 reads per cycle
    const min_spread_bps = 50; // 0.5% minimum spread to execute
    const opportunities = multi_exchange.scanAllPairs(min_spread_bps);

    // Bounded loop: process max 64 operations per cycle for determinism
    var processed: u32 = 0;
    const max_per_cycle: u32 = 64;

    while (processed < max_per_cycle) : (processed += 1) {
        // Read current price from Analytics OS
        const price = feed_reader.readPrice(0) orelse break; // Pair 0: BTC_USD

        // Update grid state TSC
        const grid_state = getGridStatePtr();
        grid_state.tsc_last_update = rdtsc();

        // Update grid spacing from NeuroOS feedback
        grid_state.step_cents = evolved_step;

        // Check rebalance trigger
        const bid_ask = feed_reader.readBidAsk(0) orelse break;
        if (rebalance.shouldRebalance(price, grid_state.lower_bound, grid_state.upper_bound)) {
            // Shift grid and regenerate levels with evolved parameters
            const new_count = rebalance.rebalanceGrid(
                price,
                grid_state.lower_bound,
                grid_state.upper_bound,
                evolved_step,  // Use evolved step instead of fixed
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

        // === PROCESS CACHED OPPORTUNITIES ===
        // Use opportunities detected before loop (hoisted from inner loop)
        // Check BTC opportunities
        if (opportunities.btc_opportunity) |btc_opp| {
            const profit = multi_exchange.calculateProfit(&btc_opp, btc_opp.volume_available, 30); // 0.3% fees
            if (profit > 0) {
                total_profit += profit;
                cycle_count += 1; // Count successful multi-exchange executions
            }
        }

        // Check ETH opportunities
        if (opportunities.eth_opportunity) |eth_opp| {
            const profit = multi_exchange.calculateProfit(&eth_opp, eth_opp.volume_available, 30);
            if (profit > 0) {
                total_profit += profit;
                cycle_count += 1;
            }
        }

        // Check LCX opportunities
        if (opportunities.lcx_opportunity) |lcx_opp| {
            const profit = multi_exchange.calculateProfit(&lcx_opp, lcx_opp.volume_available, 30);
            if (profit > 0) {
                total_profit += profit;
                cycle_count += 1;
            }
        }

        // === LEGACY: TWO-EXCHANGE DETECTION ===
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

// ============================================================================
// PHASE 12: METRICS EXPORT (Cross-module feedback)
// ============================================================================

/// GridMetricsExport structure (matches kernel @ 0x120000)
const GridMetricsExport = extern struct {
    total_profit: u64,          // Total realized profit (USD)
    winning_trades: u64,        // Number of profitable trades
    losing_trades: u64,         // Number of losing trades
    total_trades: u64,          // Total trades executed
    max_drawdown: u64,          // Max drawdown (packed f64)
    win_rate: u64,              // Win rate (packed f64, 0.0-1.0)
    valid: u8,                  // Validity flag (1=current, 0=stale)
    _pad: u8,
    timestamp: u64,             // Last update (TSC)
};

/// Export Grid OS metrics to shared memory (0x120000)
/// Called by scheduler every cycle to update trading performance data
export fn export_metrics() void {
    if (!initialized) return;

    const metrics = @as(*volatile GridMetricsExport, @ptrFromInt(0x120000));

    // Pack current state into metrics structure
    metrics.total_profit = @as(u64, @intCast(@max(0, total_profit)));
    metrics.winning_trades = 0;      // TODO: Track from order history
    metrics.losing_trades = 0;       // TODO: Track from order history
    metrics.total_trades = @as(u64, @intCast(order.countActiveOrders()));
    metrics.max_drawdown = 0;        // TODO: Calculate from historical profit
    metrics.win_rate = if (metrics.total_trades > 0)
        @as(u64, @bitCast(@as(f64, @floatFromInt(metrics.winning_trades)) / @as(f64, @floatFromInt(metrics.total_trades))))
    else
        @as(u64, @bitCast(@as(f64, 0.0)));

    // Mark as valid and update timestamp
    metrics.timestamp = rdtsc();
    metrics.valid = 1;
}

// ============================================================================
// IPC Dispatch (Phase 14)
// ============================================================================

/// IPC request dispatcher
/// Modules call this periodically to check for kernel requests
/// IPC Dispatch: Handle requests from kernel scheduler
/// Called periodically by kernel through entry point wrapper
export fn ipc_dispatch() void {
    // Ensure module is initialized on first call
    if (!initialized) {
        init_plugin();
    }

    // Read IPC request from control block @ 0x100110
    const ipc_request_ptr = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status_ptr = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_return_ptr = @as(*volatile i64, @ptrFromInt(0x100120));

    const request = ipc_request_ptr.*;

    switch (request) {
        0x00 => {
            // REQUEST_NONE: idle, do nothing
        },
        0x01 => {
            // REQUEST_BLOCKCHAIN_CYCLE: BlockchainOS requested (shouldn't reach here)
        },
        0x02 => {
            // REQUEST_NEURO_CYCLE: NeuroOS requested (shouldn't reach here)
        },
        0x03 => {
            // REQUEST_GRID_METRICS: Grid OS should export metrics
            export_metrics();
            ipc_return_ptr.* = 0; // Success
            ipc_status_ptr.* = 0x02; // STATUS_DONE
        },
        else => {
            // Unknown request
            ipc_return_ptr.* = -1; // Error
            ipc_status_ptr.* = 0x03; // STATUS_ERROR
        },
    }
}
