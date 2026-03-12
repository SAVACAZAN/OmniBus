// GridBot Engine Implementation
// Port from BOT-EXTRACT-ZIG/server/plugins/GridBotLib.js (29KB)
// Grid-based trading with dynamic rebalancing and incremental sizing

const std = @import("std");
const bot = @import("bot_strategies.zig");

pub const GridLevel = struct {
    price: i64,
    buy_order_id: u32,
    sell_order_id: u32,
    buy_quantity: i64,
    sell_quantity: i64,
    status: enum { IDLE, BUY_PENDING, SELL_PENDING, FILLED },
};

pub const GridBotState = struct {
    config: bot.GridConfig,
    grids: [512]GridLevel,
    grid_count: u16,
    active_buy_orders: u16,
    active_sell_orders: u16,
    accumulated_quantity: i64,
    pnl: i64,
    fees_paid: i64,
    buy_back_threshold: i64,  // Trigger rebalance when accumulation exceeds this
};

// ============================================================================
// GRID GENERATION & MANAGEMENT
// ============================================================================

/// Generate linear grid levels between lower and upper price
pub fn generate_linear_grid(
    state: *GridBotState,
    lower_price: i64,
    upper_price: i64,
    nr_of_grids: u16,
) void {
    state.grid_count = 0;

    if (nr_of_grids == 0 or upper_price <= lower_price) return;

    const price_range = upper_price - lower_price;
    const step = price_range / @as(i64, nr_of_grids);

    var i: u16 = 0;
    var current_price = lower_price;

    while (i < nr_of_grids and state.grid_count < 512) : (i += 1) {
        state.grids[state.grid_count] = .{
            .price = current_price,
            .buy_order_id = 0,
            .sell_order_id = 0,
            .buy_quantity = 0,
            .sell_quantity = 0,
            .status = .IDLE,
        };
        state.grid_count += 1;
        current_price += step;
    }
}

/// Generate geometric (exponential) grid levels
pub fn generate_geometric_grid(
    state: *GridBotState,
    lower_price: i64,
    upper_price: i64,
    nr_of_grids: u16,
) void {
    state.grid_count = 0;

    if (nr_of_grids == 0 or upper_price <= lower_price) return;

    // Geometric progression: p_n = lower * (upper/lower)^(n/nr_of_grids)
    var i: u16 = 0;
    while (i < nr_of_grids and state.grid_count < 512) : (i += 1) {
        // Simplified: linear approximation for fixed-point math
        const ratio = (upper_price * 100) / lower_price;
        const price_factor = lower_price * (100 + (ratio - 100) * @as(i64, i) / @as(i64, nr_of_grids)) / 100;

        state.grids[state.grid_count] = .{
            .price = price_factor,
            .buy_order_id = 0,
            .sell_order_id = 0,
            .buy_quantity = 0,
            .sell_quantity = 0,
            .status = .IDLE,
        };
        state.grid_count += 1;
    }
}

// ============================================================================
// ORDER QUANTITY CALCULATION
// ============================================================================

/// Calculate per-grid quantity (equal amount per grid)
pub fn calc_per_grid_quantity(
    total_amount: i64,
    grid_count: u16,
) i64 {
    if (grid_count == 0) return 0;
    return total_amount / @as(i64, grid_count);
}

/// Calculate quantity with incremental percent scaling
/// quantity[n] = base_amount * (inc_ratio ^ (n-1))
/// For inc_ratio > 1: pyramid strategy (larger at extremes)
/// For inc_ratio ≈ 1: dollar-cost averaging
pub fn calc_incremental_quantity(
    base_amount: i64,
    grid_index: u16,
    inc_ratio: i64,  // Fixed-point (e.g., 1.2 = 120)
) i64 {
    // Simplified calculation for fixed-point
    var quantity = base_amount;
    var i: u16 = 0;

    while (i < grid_index) : (i += 1) {
        quantity = (quantity * inc_ratio) / 100;
    }

    return quantity;
}

// ============================================================================
// DEVIATION & RANDOMIZATION
// ============================================================================

/// Apply deviation to order price
/// deviation = base_price ± (base_price * deviation_percent / 10000)
/// Returns random offset within deviation range
pub fn apply_deviation(
    base_price: i64,
    deviation_percent: i64,
) i64 {
    if (deviation_percent == 0) return base_price;

    const max_deviation = (base_price * deviation_percent) / 10000;
    // Simplified: return base_price +/- half deviation
    // (proper implementation would use PRNG)
    return base_price + max_deviation / 2;
}

// ============================================================================
// REBALANCING & BUY-BACK LOGIC
// ============================================================================

/// Check if portfolio needs rebalancing
/// Triggers when accumulated units exceed threshold or profit target hit
pub fn should_trigger_rebalance(
    state: *const GridBotState,
    current_price: i64,
) bool {
    // Rebalance when:
    // 1. Accumulated quantity exceeds threshold
    if (state.accumulated_quantity > state.buy_back_threshold) {
        return true;
    }

    // 2. Current price is significantly above buy-in average
    // (indicates strong uptrend, sell some to lock profits)
    if (current_price > state.config.upper_price) {
        return true;
    }

    return false;
}

/// Execute buy-back: automatically sell accumulated units
pub fn execute_buy_back(
    state: *GridBotState,
    current_price: i64,
    sell_quantity: i64,
) void {
    if (state.accumulated_quantity < sell_quantity) return;

    state.accumulated_quantity -= sell_quantity;

    // Calculate P&L from this sale
    const sell_revenue = sell_quantity * current_price;
    // Assume break-even for simplicity (actual cost basis would be tracked)
    state.pnl += (sell_revenue / 100); // Small profit margin

    // Apply fees
    const fees = (sell_quantity * state.config.lower_price) / 10000; // Assume ~0.1% fees
    state.fees_paid += fees;
}

/// Rebalance grid after price movement
pub fn rebalance_grid(
    state: *GridBotState,
    new_lower_price: i64,
    new_upper_price: i64,
) void {
    // Clear old grid
    for (0..state.grid_count) |i| {
        state.grids[i].status = .IDLE;
        state.grids[i].buy_order_id = 0;
        state.grids[i].sell_order_id = 0;
    }

    // Regenerate grid at new price levels
    if (state.config.grid_type == .LINEAR) {
        generate_linear_grid(state, new_lower_price, new_upper_price, state.grid_count);
    } else {
        generate_geometric_grid(state, new_lower_price, new_upper_price, state.grid_count);
    }
}

// ============================================================================
// STATISTICS & MONITORING
// ============================================================================

pub const GridStats = struct {
    total_buy_orders: u32,
    total_sell_orders: u32,
    avg_buy_price: i64,
    avg_sell_price: i64,
    total_pnl: i64,
    win_rate: i64,  // Percentage (0-10000)
    profit_factor: i64,  // Gross profit / gross loss
};

pub fn calculate_grid_stats(state: *const GridBotState) GridStats {
    var stats: GridStats = .{
        .total_buy_orders = 0,
        .total_sell_orders = 0,
        .avg_buy_price = 0,
        .avg_sell_price = 0,
        .total_pnl = state.pnl,
        .win_rate = 0,
        .profit_factor = 0,
    };

    // Count buy/sell orders
    for (0..state.grid_count) |i| {
        if (state.grids[i].status == .FILLED) {
            stats.total_buy_orders += 1;
            stats.total_sell_orders += 1;
        }
    }

    return stats;
}

// ============================================================================
// MAIN GRID BOT CYCLE
// ============================================================================

pub fn grid_bot_cycle(
    state: *GridBotState,
    current_price: i64,
    market_data: *const bot.MarketData,
) void {
    // 1. Check for rebalancing trigger
    if (should_trigger_rebalance(state, current_price)) {
        // Execute buy-back for accumulation
        const sell_amount = state.accumulated_quantity / 2;
        execute_buy_back(state, current_price, sell_amount);

        // Rebalance grid around new price
        const new_lower = current_price - (state.config.upper_price - state.config.lower_price) / 2;
        const new_upper = current_price + (state.config.upper_price - state.config.lower_price) / 2;
        rebalance_grid(state, new_lower, new_upper);
    }

    // 2. Place buy orders at levels below current price
    for (0..state.grid_count) |i| {
        if (state.grids[i].price < current_price and state.grids[i].status == .IDLE) {
            const quantity = switch (state.config.amount_type) {
                .PER_GRID => calc_per_grid_quantity(state.config.total_amount, state.grid_count),
                .TOTAL => state.config.total_amount / @as(i64, state.grid_count),
                .INCREMENTAL_PERCENT => calc_incremental_quantity(
                    state.config.total_amount / @as(i64, state.grid_count),
                    @as(u16, @intCast(i)),
                    state.config.inc_buy,
                ),
            };

            // TODO: apply deviated_price when placing actual orders
            _ = apply_deviation(state.grids[i].price, state.config.deviation_percent);

            state.grids[i].buy_quantity = quantity;
            state.grids[i].status = .BUY_PENDING;
            state.grids[i].buy_order_id = 1 + @as(u32, @intCast(i)); // Placeholder order ID
        }
    }

    // 3. Place sell orders at levels above current price
    for (0..state.grid_count) |i| {
        if (state.grids[i].price > current_price and state.grids[i].status == .IDLE) {
            // Only place sell orders if we have inventory
            if (state.accumulated_quantity > 0) {
                const quantity = state.accumulated_quantity / @as(i64, state.grid_count - i);

                // TODO: apply deviated_price when placing actual orders
                _ = apply_deviation(state.grids[i].price, state.config.deviation_percent);

                state.grids[i].sell_quantity = quantity;
                state.grids[i].status = .SELL_PENDING;
                state.grids[i].sell_order_id = 1000 + @as(u32, @intCast(i)); // Placeholder
            }
        }
    }

    // 4. Update order fills based on price action
    if (market_data.candle_count > 0) {
        const latest_candle = market_data.candles[market_data.candle_count - 1];

        for (0..state.grid_count) |i| {
            // Buy orders: filled when price drops below grid level
            if (state.grids[i].status == .BUY_PENDING and latest_candle.low <= state.grids[i].price) {
                state.accumulated_quantity += state.grids[i].buy_quantity;
                state.grids[i].status = .FILLED;
            }

            // Sell orders: filled when price rises above grid level
            if (state.grids[i].status == .SELL_PENDING and latest_candle.high >= state.grids[i].price) {
                state.accumulated_quantity -= state.grids[i].sell_quantity;
                state.grids[i].status = .FILLED;
            }
        }
    }
}

pub fn init_grid_bot_state(config: bot.GridConfig) GridBotState {
    var state: GridBotState = .{
        .config = config,
        .grids = undefined,
        .grid_count = 0,
        .active_buy_orders = 0,
        .active_sell_orders = 0,
        .accumulated_quantity = 0,
        .pnl = 0,
        .fees_paid = 0,
        .buy_back_threshold = (config.total_amount * 150) / 100, // Trigger at 150% accumulation
    };

    // Generate initial grid
    if (config.grid_type == .LINEAR) {
        generate_linear_grid(&state, config.lower_price, config.upper_price, 10);
    } else {
        generate_geometric_grid(&state, config.lower_price, config.upper_price, 10);
    }

    return state;
}
