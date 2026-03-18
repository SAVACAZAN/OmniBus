// OneClick Bot Engine
// Ported from BOT-EXTRACT-ZIG/server/plugins/OneClickBotLib.js (12KB)
// Execute all orders instantly at market price — simplest high-frequency strategy

const std = @import("std");
const bot = @import("bot_strategies.zig");

pub const OneClickConfig = struct {
    symbol: [8]u8,
    exchange: enum { COINBASE, KRAKEN, LCX },
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT },
    quantity: i64,
    price: i64,            // For limit orders
    take_profit_percent: i64,  // Auto-sell at this % above entry
    stop_loss_percent: i64,    // Auto-sell at this % below entry
};

pub const OneClickState = struct {
    config: OneClickConfig,
    position_open: bool,
    entry_price: i64,
    entry_quantity: i64,
    entry_time: u64,
    tp_price: i64,
    sl_price: i64,
    pnl: i64,
    fees_paid: i64,
    execution_count: u32,
};

// ============================================================================
// INSTANT MARKET EXECUTION
// ============================================================================

/// Execute market order instantly at current price
pub fn execute_market_order(
    state: *OneClickState,
    current_price: i64,
    timestamp: u64,
) void {
    if (state.position_open) return; // Already have position

    state.entry_price = current_price;
    state.entry_quantity = state.config.quantity;
    state.entry_time = timestamp;
    state.position_open = true;
    state.execution_count += 1;

    // Set TP/SL targets
    if (state.config.take_profit_percent > 0) {
        state.tp_price = current_price + (current_price * state.config.take_profit_percent) / 10000;
    } else {
        state.tp_price = 0; // No TP set
    }

    if (state.config.stop_loss_percent > 0) {
        state.sl_price = current_price - (current_price * state.config.stop_loss_percent) / 10000;
    } else {
        state.sl_price = 0; // No SL set
    }

    // Apply fees (assume 0.1% taker fee)
    const fee = (state.entry_quantity * current_price) / 1000;
    state.fees_paid += fee;
}

/// Execute limit order (wait for price level)
pub fn execute_limit_order(
    state: *OneClickState,
    limit_price: i64,
    current_price: i64,
    timestamp: u64,
) bool {
    if (state.position_open) return false;

    // Check if limit price is reached
    if (state.config.side == .BUY and current_price <= limit_price) {
        execute_market_order(state, limit_price, timestamp);
        return true;
    } else if (state.config.side == .SELL and current_price >= limit_price) {
        execute_market_order(state, limit_price, timestamp);
        return true;
    }

    return false;
}

// ============================================================================
// POSITION MANAGEMENT
// ============================================================================

/// Close position at market price
pub fn close_position(
    state: *OneClickState,
    exit_price: i64,
    _timestamp: u64,
) void {
    _ = _timestamp;
    if (!state.position_open) return;

    // Calculate P&L
    if (state.config.side == .BUY) {
        state.pnl = (exit_price - state.entry_price) * state.entry_quantity;
    } else {
        state.pnl = (state.entry_price - exit_price) * state.entry_quantity;
    }

    // Subtract fees
    state.pnl -= state.fees_paid;

    state.position_open = false;
}

/// Check if position should auto-exit (TP or SL hit)
pub fn check_auto_exit(
    state: *OneClickState,
    high: i64,
    low: i64,
) bool {
    if (!state.position_open) return false;

    // Check take profit
    if (state.tp_price > 0 and high >= state.tp_price) {
        return true;
    }

    // Check stop loss
    if (state.sl_price > 0 and low <= state.sl_price) {
        return true;
    }

    return false;
}

// ============================================================================
// BATCH ORDER EXECUTION (Multiple OneClick orders)
// ============================================================================

pub const BatchOneClickOrder = struct {
    symbol: [8]u8,
    side: enum { BUY, SELL },
    quantity: i64,
    price: i64,
    status: enum { PENDING, FILLED, CANCELLED },
    filled_price: i64,
    filled_quantity: i64,
    timestamp: u64,
};

pub const BatchOneClickState = struct {
    orders: [256]BatchOneClickOrder,
    order_count: u16,
    total_filled: u32,
    total_cancelled: u16,
    total_pnl: i64,
};

/// Add order to batch execution queue
pub fn add_batch_order(
    state: *BatchOneClickState,
    order: BatchOneClickOrder,
) bool {
    if (state.order_count >= 256) return false;

    state.orders[state.order_count] = order;
    state.order_count += 1;
    return true;
}

/// Process all orders in batch
pub fn execute_batch(
    state: *BatchOneClickState,
    current_price: i64,
    _timestamp: u64,
) void {
    _ = _timestamp;
    for (0..state.order_count) |i| {
        // Fill buy orders below current price
        if (state.orders[i].side == .BUY and state.orders[i].price >= current_price and
            state.orders[i].status == .PENDING) {
            state.orders[i].filled_price = current_price;
            state.orders[i].filled_quantity = state.orders[i].quantity;
            state.orders[i].status = .FILLED;
            state.total_filled += 1;

            // Add P&L
            state.total_pnl += (state.orders[i].quantity * current_price) / 100;
        }
        // Fill sell orders above current price
        else if (state.orders[i].side == .SELL and state.orders[i].price <= current_price and
            state.orders[i].status == .PENDING) {
            state.orders[i].filled_price = current_price;
            state.orders[i].filled_quantity = state.orders[i].quantity;
            state.orders[i].status = .FILLED;
            state.total_filled += 1;

            // Add P&L
            state.total_pnl += (state.orders[i].quantity * current_price) / 100;
        }
    }
}

/// Cancel all unfilled orders
pub fn cancel_pending_orders(state: *BatchOneClickState) void {
    for (0..state.order_count) |i| {
        if (state.orders[i].status == .PENDING) {
            state.orders[i].status = .CANCELLED;
            state.total_cancelled += 1;
        }
    }
}

// ============================================================================
// PERFORMANCE METRICS
// ============================================================================

pub const OneClickMetrics = struct {
    total_trades: u32,
    winning_trades: u32,
    losing_trades: u32,
    total_pnl: i64,
    avg_trade_duration: u64,
    win_rate: i64,  // Percentage (0-10000)
    profit_factor: i64,
};

pub fn calculate_metrics(state: *const OneClickState, avg_hold_ms: u64) OneClickMetrics {
    return .{
        .total_trades = state.execution_count,
        .winning_trades = if (state.pnl > 0) 1 else 0,
        .losing_trades = if (state.pnl <= 0) 1 else 0,
        .total_pnl = state.pnl,
        .avg_trade_duration = avg_hold_ms,
        .win_rate = if (state.execution_count > 0) (100 * 100) else 0, // Simplified
        .profit_factor = if (state.pnl > 0) 150 else 50, // Placeholder
    };
}

// ============================================================================
// CYCLE FUNCTION
// ============================================================================

pub fn oneclick_bot_cycle(
    state: *OneClickState,
    current_price: i64,
    timestamp: u64,
) void {
    if (!state.position_open) {
        // Try to open position
        if (state.config.order_type == .MARKET) {
            execute_market_order(state, current_price, timestamp);
        }
    } else {
        // Check for auto exit
        const should_exit = check_auto_exit(state, current_price, current_price);
        if (should_exit) {
            close_position(state, current_price, timestamp);
        }
    }
}

pub fn init_oneclick_state(config: OneClickConfig) OneClickState {
    return .{
        .config = config,
        .position_open = false,
        .entry_price = 0,
        .entry_quantity = 0,
        .entry_time = 0,
        .tp_price = 0,
        .sl_price = 0,
        .pnl = 0,
        .fees_paid = 0,
        .execution_count = 0,
    };
}

pub fn init_batch_state() BatchOneClickState {
    return .{
        .orders = undefined,
        .order_count = 0,
        .total_filled = 0,
        .total_cancelled = 0,
        .total_pnl = 0,
    };
}
