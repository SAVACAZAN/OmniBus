// Arbitrage Execution API – Coordinated multi-venue order placement
// Handles complex arbitrage scenarios: BUY on venue 1, SELL on venue 2
// Each execution involves multiple actions with interdependencies

const std = @import("std");
const local_ob = @import("local_orderbook.zig");
const cex_ob = @import("cex_orderbook.zig");
const dex_ob = @import("dex_orderbook.zig");
const order_router = @import("order_router.zig");

// ============================================================================
// ARBITRAGE EXECUTION TYPES
// ============================================================================

pub const ArbitrageExecution = struct {
    execution_id: u64,
    buy_venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID },
    sell_venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID },
    symbol: [16]u8,

    // Buy leg (leg 1)
    buy_local_id: u64,
    buy_cex_order_id: [32]u8 = undefined,
    buy_cex_order_id_len: u16 = 0,
    buy_tx_hash: [64]u8 = undefined,
    buy_tx_hash_len: u16 = 0,
    buy_quantity: i64,
    buy_price: i64,
    buy_status: enum { PENDING, SUBMITTED, FILLED, FAILED } = .PENDING,
    buy_filled_quantity: i64 = 0,

    // Sell leg (leg 2)
    sell_local_id: u64,
    sell_cex_order_id: [32]u8 = undefined,
    sell_cex_order_id_len: u16 = 0,
    sell_tx_hash: [64]u8 = undefined,
    sell_tx_hash_len: u16 = 0,
    sell_quantity: i64,
    sell_price: i64,
    sell_status: enum { PENDING, SUBMITTED, FILLED, FAILED } = .PENDING,
    sell_filled_quantity: i64 = 0,

    // Execution metadata
    spread_bps: i64,  // Spread in basis points
    risk_score: u8,   // 0-100, higher = riskier
    expected_profit: i64,
    realized_profit: i64 = 0,

    created_at: u64,
    buy_submitted_at: u64 = 0,
    sell_submitted_at: u64 = 0,
    completed_at: u64 = 0,
};

pub const ArbitrageExecutionState = struct {
    executions: [256]ArbitrageExecution = undefined,
    execution_count: u32 = 0,

    total_initiated: u64 = 0,
    total_completed: u64 = 0,
    total_failed: u64 = 0,
    total_profit: i64 = 0,
};

// ============================================================================
// EXECUTE ARBITRAGE – Two-legged order placement
// ============================================================================

/// Execute arbitrage: BUY on venue 1, SELL on venue 2
/// Step 1: Create local orders for both legs
/// Step 2: Submit buy order to first venue
/// Step 3: If buy fills, submit sell order to second venue
pub fn execute_arbitrage(
    state: *ArbitrageExecutionState,
    router: *order_router.OrderRouter,
    buy_venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID },
    sell_venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID },
    symbol: [16]u8,
    quantity: i64,
    buy_price: i64,
    sell_price: i64,
    spread_bps: i64,
    risk_score: u8,
    timestamp: u64,
) u64 {
    if (state.execution_count >= 256) return 0;

    const execution_id = state.execution_count + 1;
    const expected_profit = (sell_price - buy_price) * quantity;

    // Step 1: Create local orders for both legs
    const buy_local_id = router.place_local_order(symbol, .BUY, .LIMIT, buy_price, quantity, timestamp);
    if (buy_local_id == 0) return 0;

    const sell_local_id = router.place_local_order(symbol, .SELL, .LIMIT, sell_price, quantity, timestamp);
    if (sell_local_id == 0) return 0;

    // Record execution
    state.executions[state.execution_count] = .{
        .execution_id = execution_id,
        .buy_venue = buy_venue,
        .sell_venue = sell_venue,
        .symbol = symbol,
        .buy_local_id = buy_local_id,
        .sell_local_id = sell_local_id,
        .buy_quantity = quantity,
        .buy_price = buy_price,
        .sell_quantity = quantity,
        .sell_price = sell_price,
        .spread_bps = spread_bps,
        .risk_score = risk_score,
        .expected_profit = expected_profit,
        .created_at = timestamp,
    };

    state.execution_count += 1;
    state.total_initiated += 1;

    return execution_id;
}

/// Submit buy leg of arbitrage to exchange
pub fn submit_buy_leg(
    state: *ArbitrageExecutionState,
    execution_id: u64,
    router: *order_router.OrderRouter,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    timestamp: u64,
) bool {
    const execution = find_execution_mut(state, execution_id) orelse return false;

    if (execution.buy_status != .PENDING) return false;

    // Route to CEX
    if (is_cex_venue(execution.buy_venue)) {
        const cex_id = venue_to_cex_id(execution.buy_venue);
        const success = router.route_to_cex(
            execution.buy_local_id,
            cex_id,
            cex_order_id,
            cex_order_id_len,
            timestamp,
        );

        if (success) {
            execution.buy_cex_order_id = cex_order_id;
            execution.buy_cex_order_id_len = cex_order_id_len;
            execution.buy_status = .SUBMITTED;
            execution.buy_submitted_at = timestamp;
            return true;
        }
    }

    return false;
}

/// Submit sell leg of arbitrage to exchange
pub fn submit_sell_leg(
    state: *ArbitrageExecutionState,
    execution_id: u64,
    router: *order_router.OrderRouter,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    timestamp: u64,
) bool {
    const execution = find_execution_mut(state, execution_id) orelse return false;

    if (execution.sell_status != .PENDING) return false;

    // Only submit sell if buy has filled
    if (execution.buy_status != .FILLED) return false;

    // Route to CEX
    if (is_cex_venue(execution.sell_venue)) {
        const cex_id = venue_to_cex_id(execution.sell_venue);
        const success = router.route_to_cex(
            execution.sell_local_id,
            cex_id,
            cex_order_id,
            cex_order_id_len,
            timestamp,
        );

        if (success) {
            execution.sell_cex_order_id = cex_order_id;
            execution.sell_cex_order_id_len = cex_order_id_len;
            execution.sell_status = .SUBMITTED;
            execution.sell_submitted_at = timestamp;
            return true;
        }
    }

    return false;
}

/// Record fill for buy leg
pub fn record_buy_fill(
    state: *ArbitrageExecutionState,
    execution_id: u64,
    fill_qty: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    _ = fill_price;
    _ = timestamp;
    const execution = find_execution_mut(state, execution_id) orelse return false;

    execution.buy_filled_quantity += fill_qty;

    // Check if fully filled
    if (execution.buy_filled_quantity >= execution.buy_quantity) {
        execution.buy_status = .FILLED;
        return true;
    }

    return true;
}

/// Record fill for sell leg
pub fn record_sell_fill(
    state: *ArbitrageExecutionState,
    execution_id: u64,
    fill_qty: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    const execution = find_execution_mut(state, execution_id) orelse return false;

    execution.sell_filled_quantity += fill_qty;

    // Check if fully filled
    if (execution.sell_filled_quantity >= execution.sell_quantity) {
        execution.sell_status = .FILLED;

        // Calculate realized profit
        const buy_cost = execution.buy_quantity * execution.buy_price;
        const sell_revenue = execution.sell_quantity * fill_price;
        execution.realized_profit = sell_revenue - buy_cost;

        execution.completed_at = timestamp;
        return true;
    }

    return true;
}

/// Mark execution as failed
pub fn mark_execution_failed(
    state: *ArbitrageExecutionState,
    execution_id: u64,
) bool {
    const execution = find_execution_mut(state, execution_id) orelse return false;

    if (execution.buy_status == .PENDING) {
        execution.buy_status = .FAILED;
    }
    if (execution.sell_status == .PENDING) {
        execution.sell_status = .FAILED;
    }

    state.total_failed += 1;
    return true;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_execution_mut(state: *ArbitrageExecutionState, execution_id: u64) ?*ArbitrageExecution {
    for (0..state.execution_count) |i| {
        if (state.executions[i].execution_id == execution_id) {
            return &state.executions[i];
        }
    }
    return null;
}

pub fn get_execution(state: *const ArbitrageExecutionState, execution_id: u64) ?*const ArbitrageExecution {
    for (0..state.execution_count) |i| {
        if (state.executions[i].execution_id == execution_id) {
            return &state.executions[i];
        }
    }
    return null;
}

/// Get pending executions waiting for buy fill
pub fn get_pending_buy_fills(state: *const ArbitrageExecutionState) u32 {
    var count: u32 = 0;
    for (0..state.execution_count) |i| {
        if (state.executions[i].buy_status == .SUBMITTED) {
            count += 1;
        }
    }
    return count;
}

/// Get pending executions waiting for sell submission
pub fn get_pending_sell_submissions(state: *const ArbitrageExecutionState) u32 {
    var count: u32 = 0;
    for (0..state.execution_count) |i| {
        if (state.executions[i].buy_status == .FILLED and state.executions[i].sell_status == .PENDING) {
            count += 1;
        }
    }
    return count;
}

pub fn get_execution_stats(state: *const ArbitrageExecutionState) struct {
    total_initiated: u64,
    total_completed: u64,
    total_failed: u64,
    pending_buy_fills: u32,
    pending_sell_submissions: u32,
    total_profit: i64,
} {
    return .{
        .total_initiated = state.total_initiated,
        .total_completed = state.total_completed,
        .total_failed = state.total_failed,
        .pending_buy_fills = get_pending_buy_fills(state),
        .pending_sell_submissions = get_pending_sell_submissions(state),
        .total_profit = state.total_profit,
    };
}

// ============================================================================
// HELPERS
// ============================================================================

fn is_cex_venue(venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID }) bool {
    return switch (venue) {
        .CEX_KRAKEN, .CEX_LCX, .CEX_COINBASE => true,
        else => false,
    };
}

fn venue_to_cex_id(venue: enum { CEX_KRAKEN, CEX_LCX, CEX_COINBASE, DEX_UNISWAP_V3, DEX_UNISWAP_V4, DEX_HYPERLIQUID }) cex_ob.CexId {
    return switch (venue) {
        .CEX_KRAKEN => .KRAKEN,
        .CEX_LCX => .LCX,
        .CEX_COINBASE => .COINBASE,
        else => .KRAKEN, // Default fallback
    };
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

/// Example: CEX-to-CEX arbitrage (buy on Kraken, sell on Coinbase)
pub fn example_cex_to_cex_arbitrage(
    state: *ArbitrageExecutionState,
    router: *order_router.OrderRouter,
    timestamp: u64,
) void {
    // Step 1: Detect opportunity (BTC: buy Kraken @$50,000, sell Coinbase @$50,100)
    const execution_id = execute_arbitrage(
        state,
        router,
        .CEX_KRAKEN,
        .CEX_COINBASE,
        "BTC/USD" ++ "\x00" ** 8,
        1_00_000_000, // 1 BTC in satoshis
        50000_00,      // Buy price: $50,000
        50100_00,      // Sell price: $50,100
        100,           // Spread: 100 bps = 1.00%
        25,            // Risk score: 25/100 (low risk)
        timestamp,
    );

    if (execution_id > 0) {
        // Step 2: Submit buy order to Kraken
        const kraken_order_id: [32]u8 = "kraken_buy_xyz_123456789abc" ++ "\x00" ** 5;
        _ = submit_buy_leg(state, execution_id, router, kraken_order_id, 27, timestamp);

        // Step 3: Wait for Kraken fill (via market data)
        // record_buy_fill(state, execution_id, 1_00_000_000, 50000_00, timestamp + 2);

        // Step 4: Submit sell order to Coinbase (only after buy fills)
        // const coinbase_order_id: [32]u8 = "coinbase_sell_abc_987654321xyz" ++ "\x00" ** 2;
        // submit_sell_leg(state, execution_id, router, coinbase_order_id, 30, timestamp + 3);

        // Step 5: Record sell fill and complete arbitrage
        // record_sell_fill(state, execution_id, 1_00_000_000, 50100_00, timestamp + 5);
    }
}

/// Example: CEX-to-DEX arbitrage (buy on Kraken, sell on Uniswap)
pub fn example_cex_to_dex_arbitrage(
    state: *ArbitrageExecutionState,
    router: *order_router.OrderRouter,
    timestamp: u64,
) void {
    // Step 1: Detect opportunity (ETH: buy Kraken @$3,000, sell Uniswap @$3,050)
    const execution_id = execute_arbitrage(
        state,
        router,
        .CEX_KRAKEN,
        .DEX_UNISWAP_V3,
        "ETH/USD" ++ "\x00" ** 8,
        10_000_000_000, // 10 ETH in wei
        3000_00,        // Buy price: $3,000
        3050_00,        // Sell price: $3,050
        167,            // Spread: 167 bps = 1.67%
        35,             // Risk score: 35/100 (moderate, blockchain latency)
        timestamp,
    );

    if (execution_id > 0) {
        // Note: This is a simplified flow - full execution would involve:
        // 1. Buy on Kraken (CEX API)
        // 2. Wait for fill
        // 3. Sell on Uniswap (blockchain swap)
        // 4. Wait for on-chain confirmation
    }
}
