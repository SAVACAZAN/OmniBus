// GridBot Engine Implementation (with GridBotPlus Extensions)
// Port from BOT-EXTRACT-ZIG/server/plugins/GridBotLib.js (29KB)
// Grid-based trading with dynamic rebalancing, incremental sizing, and per-side configuration
//
// GridBotPlus Features:
// 1. Side-specific deviation: Separate price deviation for BUY vs SELL orders
//    - deviationPriceBuy: Basis points for buy-side price adjustment (lower = better)
//    - deviationPriceSell: Basis points for sell-side price adjustment (higher = better)
// 2. Grid side configuration: Control which orders are placed
//    - grid_side.BUY_ONLY: Only place buy orders below current price
//    - grid_side.SELL_ONLY: Only place sell orders above current price
//    - grid_side.BOTH: Place both buy and sell orders (default)
// 3. Amount deviation: Dynamic quantity scaling per grid level
//    - deviationAmountBuy: Basis points for buy-side quantity scaling
//    - deviationAmountSell: Basis points for sell-side quantity scaling
// 4. Dynamic grid increment: Incremental quantity calculation with per-side deviation

const std = @import("std");
const bot = @import("bot_strategies.zig");

pub const GridLevel = struct {
    price: i64,
    buy_order_id: u32,
    sell_order_id: u32,
    buy_quantity: i64,
    sell_quantity: i64,
    status: enum { IDLE, BUY_PENDING, SELL_PENDING, FILLED },
    buy_deviated_price: i64,  // Price after buy-side deviation applied
    sell_deviated_price: i64, // Price after sell-side deviation applied
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
            .buy_deviated_price = 0,
            .sell_deviated_price = 0,
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
            .buy_deviated_price = 0,
            .sell_deviated_price = 0,
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

/// Calculate quantity with incremental percent scaling and side-specific deviation
/// quantity[n] = base_amount * (inc_ratio ^ (n-1)) * (1 ± amount_deviation)
/// For inc_ratio > 1: pyramid strategy (larger at extremes)
/// For inc_ratio ≈ 1: dollar-cost averaging
/// amount_deviation allows per-side scaling (buy side can scale differently from sell side)
pub fn calc_incremental_quantity(
    base_amount: i64,
    grid_index: u16,
    inc_ratio: i64,  // Fixed-point (e.g., 1.2 = 120)
    amount_deviation_percent: i64,  // Basis points for dynamic scaling
) i64 {
    // Calculate base quantity with incremental scaling
    var quantity = base_amount;
    var i: u16 = 0;

    while (i < grid_index) : (i += 1) {
        quantity = (quantity * inc_ratio) / 100;
    }

    // Apply amount deviation (difference scaling per grid level)
    if (amount_deviation_percent != 0) {
        const deviation_factor = (10000 + amount_deviation_percent);
        quantity = (quantity * deviation_factor) / 10000;
    }

    return quantity;
}

// ============================================================================
// DEVIATION & RANDOMIZATION
// ============================================================================

/// Apply deviation to order price with side-specific handling
/// For BUY orders: deviation is subtracted (lower price more attractive)
/// For SELL orders: deviation is added (higher price more attractive)
/// deviation = base_price ± (base_price * deviation_percent / 10000)
pub fn apply_deviation(
    base_price: i64,
    deviation_percent: i64,
    side: enum { BUY, SELL },
) i64 {
    if (deviation_percent == 0) return base_price;

    const max_deviation = (base_price * deviation_percent) / 10000;
    // For BUY: subtract deviation (lower is better for buys)
    // For SELL: add deviation (higher is better for sells)
    // Using half deviation as simplified randomization
    return switch (side) {
        .BUY => base_price - max_deviation / 2,
        .SELL => base_price + max_deviation / 2,
    };
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

    // 2. Place buy orders at levels below current price (if grid_side allows)
    if (state.config.grid_side == .BUY_ONLY or state.config.grid_side == .BOTH) {
        for (0..state.grid_count) |i| {
            if (state.grids[i].price < current_price and state.grids[i].status == .IDLE) {
                const quantity = switch (state.config.amount_type) {
                    .PER_GRID => calc_per_grid_quantity(state.config.total_amount, state.grid_count),
                    .TOTAL => state.config.total_amount / @as(i64, state.grid_count),
                    .INCREMENTAL_PERCENT => calc_incremental_quantity(
                        state.config.total_amount / @as(i64, state.grid_count),
                        @as(u16, @intCast(i)),
                        state.config.inc_buy,
                        state.config.deviation_amount_buy,
                    ),
                };

                // Apply buy-side deviation to price
                const deviated_price = apply_deviation(
                    state.grids[i].price,
                    state.config.deviation_price_buy,
                    .BUY,
                );

                state.grids[i].buy_quantity = quantity;
                state.grids[i].buy_deviated_price = deviated_price;
                state.grids[i].status = .BUY_PENDING;
                state.grids[i].buy_order_id = 1 + @as(u32, @intCast(i)); // Placeholder order ID
            }
        }
    }

    // 3. Place sell orders at levels above current price (if grid_side allows)
    if (state.config.grid_side == .SELL_ONLY or state.config.grid_side == .BOTH) {
        for (0..state.grid_count) |i| {
            if (state.grids[i].price > current_price and state.grids[i].status == .IDLE) {
                // Only place sell orders if we have inventory
                if (state.accumulated_quantity > 0) {
                    // Base quantity divided across remaining grids
                    var quantity = state.accumulated_quantity / @as(i64, state.grid_count - i);

                    // Apply sell-side amount deviation to quantity
                    if (state.config.deviation_amount_sell != 0) {
                        const deviation_factor = (10000 + state.config.deviation_amount_sell);
                        quantity = (quantity * deviation_factor) / 10000;
                    }

                    // Apply sell-side deviation to price
                    const deviated_price = apply_deviation(
                        state.grids[i].price,
                        state.config.deviation_price_sell,
                        .SELL,
                    );

                    state.grids[i].sell_quantity = quantity;
                    state.grids[i].sell_deviated_price = deviated_price;
                    state.grids[i].status = .SELL_PENDING;
                    state.grids[i].sell_order_id = 1000 + @as(u32, @intCast(i)); // Placeholder
                }
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

// ============================================================================
// GRIDBOTPLUS CONFIGURATION HELPERS
// ============================================================================

/// Create a buy-only GridBot configuration (accumulate coins on dips)
pub fn create_buyonly_config(
    symbol: [8]u8,
    lower_price: i64,
    upper_price: i64,
    total_amount: i64,
    deviation_price: i64,  // Basis points
) bot.GridConfig {
    return .{
        .symbol = symbol,
        .lower_price = lower_price,
        .upper_price = upper_price,
        .nr_of_grids = 10,
        .grid_type = .LINEAR,
        .amount_type = .PER_GRID,
        .total_amount = total_amount,
        .deviation_percent = 0,
        .inc_buy = 100,
        .inc_sell = 100,
        .grid_side = .BUY_ONLY,
        .deviation_price_buy = deviation_price,
        .deviation_price_sell = 0,
        .deviation_amount_buy = 0,
        .deviation_amount_sell = 0,
    };
}

/// Create a sell-only GridBot configuration (distribute coins on rallies)
pub fn create_sellonly_config(
    symbol: [8]u8,
    lower_price: i64,
    upper_price: i64,
    total_amount: i64,
    deviation_price: i64,  // Basis points
) bot.GridConfig {
    return .{
        .symbol = symbol,
        .lower_price = lower_price,
        .upper_price = upper_price,
        .nr_of_grids = 10,
        .grid_type = .LINEAR,
        .amount_type = .PER_GRID,
        .total_amount = total_amount,
        .deviation_percent = 0,
        .inc_buy = 100,
        .inc_sell = 100,
        .grid_side = .SELL_ONLY,
        .deviation_price_buy = 0,
        .deviation_price_sell = deviation_price,
        .deviation_amount_buy = 0,
        .deviation_amount_sell = 0,
    };
}

/// Create a balanced GridBot configuration (buy low, sell high)
pub fn create_balanced_config(
    symbol: [8]u8,
    lower_price: i64,
    upper_price: i64,
    total_amount: i64,
    buy_deviation: i64,   // Basis points for buy side
    sell_deviation: i64,  // Basis points for sell side
) bot.GridConfig {
    return .{
        .symbol = symbol,
        .lower_price = lower_price,
        .upper_price = upper_price,
        .nr_of_grids = 10,
        .grid_type = .LINEAR,
        .amount_type = .INCREMENTAL_PERCENT,
        .total_amount = total_amount,
        .deviation_percent = 0,
        .inc_buy = 105,   // 5% increment per level
        .inc_sell = 105,
        .grid_side = .BOTH,
        .deviation_price_buy = buy_deviation,
        .deviation_price_sell = sell_deviation,
        .deviation_amount_buy = 50,   // 0.5% amount scaling for buys
        .deviation_amount_sell = 50,  // 0.5% amount scaling for sells
    };
}
