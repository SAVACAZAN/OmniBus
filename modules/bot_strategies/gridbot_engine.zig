// GridBotEngine - Active Order Lifecycle Manager
// Manages grid order placement, fill detection, and dynamic reposting
// Adapts order quantities and prices based on market evolution

const std = @import("std");
const bot = @import("bot_strategies.zig");
const grid = @import("grid_bot.zig");

// ============================================================================
// ORDERSTATE & LIFECYCLE TRACKING
// ============================================================================

pub const OrderState = enum {
    IDLE,           // Not posted
    PENDING,        // Posted, waiting for fill
    FILLED,         // Filled at average price
    CANCELLED,      // Manually cancelled
    EXPIRED,        // Timeout repost window
};

pub const FilledOrder = struct {
    order_id: u32,
    grid_index: u16,
    side: enum { BUY, SELL },
    entry_price: i64,      // Price at which order filled
    quantity: i64,         // Actual filled amount
    fill_time: u64,        // Timestamp of fill
    repost_count: u8,      // How many times reposted
    accumulated_pnl: i64,  // P&L from this grid level
};

pub const PriceEvolution = struct {
    current_price: i64,
    prev_price: i64,
    high_24h: i64,
    low_24h: i64,
    moving_avg_20: i64,    // 20-candle moving average
    volatility: i64,       // Basis points (100 = 1%)
    trend: enum { UP, DOWN, NEUTRAL },
};

pub const GridBotEngineState = struct {
    grid_state: grid.GridBotState,
    filled_orders: [256]FilledOrder,
    filled_order_count: u16,
    price_evolution: PriceEvolution,
    last_repost_time: u64,
    repost_interval: u64,  // Minimum cycles between reposts per grid
    total_reposts: u32,
    repost_pnl: i64,       // P&L from reposting strategy
};

// ============================================================================
// PRICE EVOLUTION DETECTION
// ============================================================================

/// Analyze market conditions to detect trend and volatility
pub fn detect_price_evolution(
    market_data: *const bot.MarketData,
    current_price: i64,
) PriceEvolution {
    var evolution: PriceEvolution = .{
        .current_price = current_price,
        .prev_price = if (market_data.candle_count > 0)
            market_data.candles[market_data.candle_count - 1].close
        else
            current_price,
        .high_24h = current_price,
        .low_24h = current_price,
        .moving_avg_20 = current_price,
        .volatility = 0,
        .trend = .NEUTRAL,
    };

    if (market_data.candle_count == 0) return evolution;

    // Calculate 24h high/low (assuming 1-hour candles, 24 periods)
    const lookback = if (market_data.candle_count > 24) 24 else market_data.candle_count;
    var high: i64 = 0;
    var low: i64 = 0x7FFFFFFFFFFFFFFF;
    var sum_close: i64 = 0;
    var sum_volatility: i64 = 0;

    for ((market_data.candle_count - lookback)..market_data.candle_count) |i| {
        const candle = market_data.candles[i];
        if (candle.high > high) high = candle.high;
        if (candle.low < low) low = candle.low;
        sum_close += candle.close;

        // Calculate intra-candle volatility
        if (candle.close != candle.open) {
            const range = (candle.high - candle.low) * 10000 / candle.close;
            if (range > sum_volatility) sum_volatility = range;
        }
    }

    evolution.high_24h = high;
    evolution.low_24h = low;
    evolution.moving_avg_20 = sum_close / @as(i64, lookback);
    evolution.volatility = sum_volatility / @as(i64, lookback);

    // Detect trend
    if (current_price > evolution.moving_avg_20) {
        evolution.trend = .UP;
    } else if (current_price < evolution.moving_avg_20) {
        evolution.trend = .DOWN;
    } else {
        evolution.trend = .NEUTRAL;
    }

    return evolution;
}

// ============================================================================
// ORDER FILL DETECTION & TRACKING
// ============================================================================

/// Check if grid level order was filled based on market data
pub fn check_order_fill(
    grid_level: *const grid.GridLevel,
    latest_candle: *const bot.Candle,
) bool {
    return switch (grid_level.status) {
        .BUY_PENDING => latest_candle.low <= grid_level.buy_deviated_price,
        .SELL_PENDING => latest_candle.high >= grid_level.sell_deviated_price,
        else => false,
    };
}

/// Record a filled order and track it for reposting
pub fn record_filled_order(
    engine_state: *GridBotEngineState,
    grid_index: u16,
    grid_level: *const grid.GridLevel,
    fill_price: i64,
    timestamp: u64,
) bool {
    if (engine_state.filled_order_count >= 256) return false;

    const is_buy = grid_level.status == .BUY_PENDING;
    const order_id = if (is_buy) grid_level.buy_order_id else grid_level.sell_order_id;
    const side = if (is_buy) @as(@TypeOf(FilledOrder.side), .BUY) else @as(@TypeOf(FilledOrder.side), .SELL);
    const quantity = if (is_buy) grid_level.buy_quantity else grid_level.sell_quantity;

    const order: FilledOrder = .{
        .order_id = order_id,
        .grid_index = grid_index,
        .side = side,
        .entry_price = fill_price,
        .quantity = quantity,
        .fill_time = timestamp,
        .repost_count = 0,
        .accumulated_pnl = 0,
    };

    engine_state.filled_orders[engine_state.filled_order_count] = order;
    engine_state.filled_order_count += 1;
    return true;
}

// ============================================================================
// REPOSTING LOGIC
// ============================================================================

/// Calculate new price for repost based on price evolution
pub fn calculate_repost_price(
    entry_price: i64,
    side: enum { BUY, SELL },
    price_evolution: *const PriceEvolution,
    repost_count: u8,
) i64 {
    // Base repost distance: 0.5% per repost, increases with volatility
    var base_distance = (entry_price * 50) / 10000;
    base_distance = (base_distance * (100 + repost_count * 10)) / 100; // Increase distance per repost

    // Adjust for trend
    const volatility_adjustment = (price_evolution.volatility * base_distance) / 10000;
    const trend_bias = switch (price_evolution.trend) {
        .UP => volatility_adjustment / 2,    // Less aggressive on uptrend
        .DOWN => volatility_adjustment,      // More aggressive on downtrend
        .NEUTRAL => volatility_adjustment / 2,
    };

    return switch (side) {
        .BUY => entry_price - base_distance - trend_bias,
        .SELL => entry_price + base_distance + trend_bias,
    };
}

/// Calculate new quantity for repost with amount deviation scaling
pub fn calculate_repost_quantity(
    original_quantity: i64,
    repost_count: u8,
    amount_deviation: i64,
) i64 {
    var quantity = original_quantity;

    // Scale down slightly each repost (less aggressive as price moves)
    for (0..repost_count) |_| {
        quantity = (quantity * 98) / 100; // 2% reduction per repost
    }

    // Apply amount deviation
    if (amount_deviation != 0) {
        const factor = 10000 + amount_deviation;
        quantity = (quantity * factor) / 10000;
    }

    return if (quantity > 0) quantity else original_quantity / 2;
}

/// Repost a filled order at new price level
pub fn repost_filled_order(
    engine_state: *GridBotEngineState,
    filled_order_index: u16,
    current_price: i64,
    new_order_id: u32,
    timestamp: u64,
) bool {
    if (filled_order_index >= engine_state.filled_order_count) return false;

    var filled = &engine_state.filled_orders[filled_order_index];
    const grid_index = filled.grid_index;

    if (grid_index >= engine_state.grid_state.grid_count) return false;

    var grid_level = &engine_state.grid_state.grids[grid_index];

    // Calculate new repost parameters
    const new_price = calculate_repost_price(
        filled.entry_price,
        filled.side,
        &engine_state.price_evolution,
        filled.repost_count,
    );

    const amount_deviation = switch (filled.side) {
        .BUY => engine_state.grid_state.config.deviation_amount_buy,
        .SELL => engine_state.grid_state.config.deviation_amount_sell,
    };

    const new_quantity = calculate_repost_quantity(
        filled.quantity,
        filled.repost_count,
        amount_deviation,
    );

    // Update grid level for repost
    switch (filled.side) {
        .BUY => {
            grid_level.buy_quantity = new_quantity;
            grid_level.buy_deviated_price = new_price;
            grid_level.buy_order_id = new_order_id;
            grid_level.status = .BUY_PENDING;
        },
        .SELL => {
            grid_level.sell_quantity = new_quantity;
            grid_level.sell_deviated_price = new_price;
            grid_level.sell_order_id = new_order_id;
            grid_level.status = .SELL_PENDING;
        },
    }

    // Update fill tracking
    filled.repost_count += 1;
    filled.fill_time = timestamp;
    engine_state.total_reposts += 1;

    // Track P&L from repost
    const price_delta = if (filled.side == .BUY)
        current_price - new_price
    else
        new_price - current_price;

    filled.accumulated_pnl += (price_delta * new_quantity) / 100;

    return true;
}

// ============================================================================
// ADAPTIVE GRID MANAGEMENT
// ============================================================================

/// Check if grid should shift based on price movement
pub fn should_shift_grid(
    engine_state: *const GridBotEngineState,
    current_price: i64,
) bool {
    const price_range = engine_state.grid_state.config.upper_price -
        engine_state.grid_state.config.lower_price;
    const center = (engine_state.grid_state.config.upper_price +
        engine_state.grid_state.config.lower_price) / 2;
    const shift_threshold = price_range / 4; // 25% of range

    return (current_price > center + shift_threshold) or
        (current_price < center - shift_threshold);
}

/// Shift grid to follow price action
pub fn shift_grid_to_price(
    engine_state: *GridBotEngineState,
    current_price: i64,
) void {
    const price_range = engine_state.grid_state.config.upper_price -
        engine_state.grid_state.config.lower_price;
    const margin = price_range / 10; // 10% margin on each side

    const new_lower = current_price - margin;
    const new_upper = current_price + margin + (price_range * 4) / 5;

    grid.rebalance_grid(&engine_state.grid_state, new_lower, new_upper);
}

// ============================================================================
// MAIN ENGINE CYCLE
// ============================================================================

pub fn gridbot_engine_cycle(
    engine_state: *GridBotEngineState,
    market_data: *const bot.MarketData,
    current_price: i64,
    timestamp: u64,
) void {
    // Step 1: Update price evolution
    engine_state.price_evolution = detect_price_evolution(market_data, current_price);

    // Step 2: Check for order fills
    if (market_data.candle_count > 0) {
        const latest_candle = market_data.candles[market_data.candle_count - 1];

        for (0..engine_state.grid_state.grid_count) |i| {
            var grid_level = &engine_state.grid_state.grids[i];

            if (grid_level.status == .BUY_PENDING or grid_level.status == .SELL_PENDING) {
                if (check_order_fill(grid_level, &latest_candle)) {
                    const fill_price = if (grid_level.status == .BUY_PENDING)
                        grid_level.buy_deviated_price
                    else
                        grid_level.sell_deviated_price;

                    // Record filled order
                    _ = record_filled_order(
                        engine_state,
                        @as(u16, @intCast(i)),
                        grid_level,
                        fill_price,
                        timestamp,
                    );

                    grid_level.status = .FILLED;
                }
            }
        }
    }

    // Step 3: Repost filled orders
    var repost_count: u16 = 0;
    for (0..engine_state.filled_order_count) |i| {
        if (repost_count >= 16) break; // Limit reposts per cycle

        const should_repost = (timestamp - engine_state.filled_orders[i].fill_time) >
            engine_state.repost_interval;

        if (should_repost and engine_state.filled_orders[i].repost_count < 10) {
            const new_order_id = 10000 + engine_state.total_reposts;
            _ = repost_filled_order(
                engine_state,
                @as(u16, @intCast(i)),
                current_price,
                new_order_id,
                timestamp,
            );
            repost_count += 1;
        }
    }

    // Step 4: Check if grid should shift
    if (should_shift_grid(engine_state, current_price)) {
        shift_grid_to_price(engine_state, current_price);
    }

    // Step 5: Place new orders from grid
    grid.grid_bot_cycle(&engine_state.grid_state, current_price, market_data);
}

// ============================================================================
// INITIALIZATION & HELPERS
// ============================================================================

pub fn init_gridbot_engine(config: bot.GridConfig) GridBotEngineState {
    var engine: GridBotEngineState = .{
        .grid_state = grid.init_grid_bot_state(config),
        .filled_orders = undefined,
        .filled_order_count = 0,
        .price_evolution = .{
            .current_price = config.lower_price,
            .prev_price = config.lower_price,
            .high_24h = config.upper_price,
            .low_24h = config.lower_price,
            .moving_avg_20 = (config.lower_price + config.upper_price) / 2,
            .volatility = 0,
            .trend = .NEUTRAL,
        },
        .last_repost_time = 0,
        .repost_interval = 10,  // Reposts after 10 cycles
        .total_reposts = 0,
        .repost_pnl = 0,
    };

    // Initialize filled orders array
    for (0..256) |i| {
        engine.filled_orders[i] = .{
            .order_id = 0,
            .grid_index = 0,
            .side = .BUY,
            .entry_price = 0,
            .quantity = 0,
            .fill_time = 0,
            .repost_count = 0,
            .accumulated_pnl = 0,
        };
    }

    return engine;
}

/// Get statistics on reposting performance
pub const RepostStats = struct {
    total_filled: u16,
    total_reposts: u32,
    avg_reposts_per_order: i64,
    total_repost_pnl: i64,
    active_orders: u16,
};

pub fn get_repost_stats(engine_state: *const GridBotEngineState) RepostStats {
    var active = 0;
    var total_repost_count: u32 = 0;

    for (0..engine_state.filled_order_count) |i| {
        if (engine_state.filled_orders[i].repost_count > 0) {
            total_repost_count += engine_state.filled_orders[i].repost_count;
            active += 1;
        }
    }

    const avg_reposts = if (engine_state.filled_order_count > 0)
        @as(i64, total_repost_count) * 100 / @as(i64, engine_state.filled_order_count)
    else
        0;

    return .{
        .total_filled = engine_state.filled_order_count,
        .total_reposts = engine_state.total_reposts,
        .avg_reposts_per_order = avg_reposts,
        .total_repost_pnl = engine_state.repost_pnl,
        .active_orders = active,
    };
}
