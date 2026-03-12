// DCA Bot Strategy – Dollar Cost Averaging with Moving Average + RSI signals
// Ports dcaBotStrategy.js to Zig with technical indicator support
// DCA = systematic accumulation at set intervals regardless of price

const std = @import("std");
const bot = @import("bot_strategies.zig");

// ============================================================================
// DCA CONFIGURATION
// ============================================================================

pub const DCAStrategy = struct {
    symbol: [8]u8,
    enabled: bool,
    buy_interval_seconds: u64,      // Interval between buy orders
    buy_amount_per_order: i64,       // Fixed amount per buy order (satoshis)
    ma12_period: u16 = 12,
    ma21_period: u16 = 21,
    rsi_period: u16 = 14,
    rsi_overbought_level: i64 = 80,
    rsi_oversold_level: i64 = 20,
    use_ma_crossover: bool = true,
    use_rsi_filter: bool = true,
};

pub const DCAState = struct {
    config: DCAStrategy,
    last_buy_timestamp: u64,
    total_cost: i64,                 // Total spent on buys
    total_units: i64,                // Total units accumulated
    avg_cost: i64,                   // Average cost per unit
    buy_count: u32,
    sell_count: u32,
    current_position: i64,           // 0 = neutral, positive = long
    position_entry_price: i64,       // Entry price for current position
    realized_pnl: i64,               // Closed P&L
    unrealized_pnl: i64,             // Open P&L
};

pub const DCASignal = struct {
    signal_type: enum { BUY, SELL, NEUTRAL },
    price: i64,
    confidence: i64,                 // 0-100
    reason: enum { MA_CROSSUP, MA_CROSSDOWN, RSI_OVERSOLD, RSI_OVERBOUGHT, INTERVAL, NONE },
};

// ============================================================================
// MA CROSSOVER DETECTION
// ============================================================================

/// Detect MA12 x MA21 crossover (BUY when MA12 crosses above MA21, SELL when below)
pub fn detect_ma_crossover(
    ma12_values: []const i64,
    ma21_values: []const i64,
) DCASignal {
    if (ma12_values.len < 2 or ma21_values.len < 2) {
        return .{
            .signal_type = .NEUTRAL,
            .price = 0,
            .confidence = 0,
            .reason = .NONE,
        };
    }

    // Calculate offset (MA12 may be shorter)
    const offset = if (ma12_values.len > ma21_values.len)
        ma12_values.len - ma21_values.len
    else
        0;

    // Get last two MA12 values relative to MA21
    const len = ma21_values.len;
    const ma12_prev_idx = if (offset + len >= 2) len - 2 else 0;
    const ma12_curr_idx = if (offset + len >= 1) len - 1 else 0;

    const ma12_prev = if (offset + ma12_prev_idx < ma12_values.len)
        ma12_values[offset + ma12_prev_idx]
    else
        0;
    const ma12_curr = if (offset + ma12_curr_idx < ma12_values.len)
        ma12_values[offset + ma12_curr_idx]
    else
        0;

    const ma21_prev = if (len >= 2) ma21_values[len - 2] else 0;
    const ma21_curr = if (len >= 1) ma21_values[len - 1] else 0;

    // Detect crossover
    const was_below = ma12_prev <= ma21_prev;
    const is_above = ma12_curr > ma21_curr;
    const was_above = ma12_prev > ma21_prev;
    const is_below = ma12_curr <= ma21_curr;

    if (was_below and is_above) {
        return .{
            .signal_type = .BUY,
            .price = ma12_curr,
            .confidence = 75,
            .reason = .MA_CROSSUP,
        };
    }

    if (was_above and is_below) {
        return .{
            .signal_type = .SELL,
            .price = ma12_curr,
            .confidence = 75,
            .reason = .MA_CROSSDOWN,
        };
    }

    return .{
        .signal_type = .NEUTRAL,
        .price = ma12_curr,
        .confidence = 0,
        .reason = .NONE,
    };
}

// ============================================================================
// RSI FILTER
// ============================================================================

/// Generate signal based on RSI levels
pub fn detect_rsi_signal(
    rsi_values: []const i64,
    config: *const DCAStrategy,
) DCASignal {
    if (rsi_values.len < 2) {
        return .{
            .signal_type = .NEUTRAL,
            .price = 0,
            .confidence = 0,
            .reason = .NONE,
        };
    }

    const rsi_curr = rsi_values[rsi_values.len - 1];
    const rsi_prev = rsi_values[rsi_values.len - 2];

    // Overbought (>80) = SELL signal
    if (rsi_curr > config.rsi_overbought_level and rsi_prev <= config.rsi_overbought_level) {
        return .{
            .signal_type = .SELL,
            .price = rsi_curr,
            .confidence = 60,
            .reason = .RSI_OVERBOUGHT,
        };
    }

    // Oversold (<20) = BUY signal
    if (rsi_curr < config.rsi_oversold_level and rsi_prev >= config.rsi_oversold_level) {
        return .{
            .signal_type = .BUY,
            .price = rsi_curr,
            .confidence = 60,
            .reason = .RSI_OVERSOLD,
        };
    }

    return .{
        .signal_type = .NEUTRAL,
        .price = rsi_curr,
        .confidence = 0,
        .reason = .NONE,
    };
}

// ============================================================================
// MAIN DCA CYCLE
// ============================================================================

/// Generate next DCA signal based on market data
pub fn dca_bot_cycle(
    state: *DCAState,
    market_data: *const bot.MarketData,
    current_timestamp: u64,
) DCASignal {
    // Calculate technical indicators if not provided
    var ma12_buf: [256]i64 = undefined;
    var ma21_buf: [256]i64 = undefined;
    var rsi_buf: [256]i64 = undefined;

    var signal: DCASignal = .{
        .signal_type = .NEUTRAL,
        .price = 0,
        .confidence = 0,
        .reason = .NONE,
    };

    // Extract candle close prices
    const close_prices = market_data.candles[0..market_data.candle_count];

    // Calculate MA12
    if (market_data.candle_count >= state.config.ma12_period) {
        const ma12 = bot.calculateMA(close_prices, state.config.ma12_period);
        ma12_buf[0] = ma12;
    }

    // Calculate MA21
    if (market_data.candle_count >= state.config.ma21_period) {
        const ma21 = bot.calculateMA(close_prices, state.config.ma21_period);
        ma21_buf[0] = ma21;
    }

    // Calculate RSI
    if (market_data.candle_count >= state.config.rsi_period) {
        const rsi = bot.calculateRSI(close_prices, state.config.rsi_period);
        rsi_buf[0] = rsi;
    }

    // Check MA crossover signal
    if (state.config.use_ma_crossover and ma12_buf[0] != 0 and ma21_buf[0] != 0) {
        const ma_signal = detect_ma_crossover(&ma12_buf, &ma21_buf);
        if (ma_signal.signal_type != .NEUTRAL) {
            signal = ma_signal;
        }
    }

    // Check RSI filter (can override or confirm MA signal)
    if (state.config.use_rsi_filter and rsi_buf[0] != 0) {
        const rsi_signal = detect_rsi_signal(&rsi_buf, &state.config);
        // RSI oversold can trigger BUY even without MA crossover
        if (rsi_signal.reason == .RSI_OVERSOLD and signal.signal_type == .NEUTRAL) {
            signal = rsi_signal;
        }
        // RSI overbought can confirm SELL
        if (rsi_signal.reason == .RSI_OVERBOUGHT and signal.signal_type == .SELL) {
            signal.confidence = (signal.confidence + rsi_signal.confidence) / 2;
        }
    }

    // DCA Interval check: if no signal and enough time passed, do periodic buy
    const time_since_last_buy = current_timestamp - state.last_buy_timestamp;
    if (signal.signal_type == .NEUTRAL and
        time_since_last_buy >= state.config.buy_interval_seconds and
        state.config.buy_interval_seconds > 0) {
        signal = .{
            .signal_type = .BUY,
            .price = if (market_data.candle_count > 0)
                market_data.candles[market_data.candle_count - 1].close
            else 0,
            .confidence = 50,
            .reason = .INTERVAL,
        };
    }

    // Update state if signal generated
    if (signal.signal_type == .BUY) {
        state.last_buy_timestamp = current_timestamp;
        state.total_cost += state.config.buy_amount_per_order;
        state.total_units += state.config.buy_amount_per_order / signal.price;
        state.buy_count += 1;
        if (state.total_units > 0) {
            state.avg_cost = state.total_cost / state.total_units;
        }
        state.current_position = state.total_units;
    } else if (signal.signal_type == .SELL) {
        if (state.current_position > 0) {
            const exit_value = state.current_position * signal.price;
            const profit = exit_value - (state.current_position * state.avg_cost);
            state.realized_pnl += profit;
            state.current_position = 0;
            state.sell_count += 1;
        }
    }

    return signal;
}

/// Update unrealized P&L based on current market price
pub fn update_unrealized_pnl(
    state: *DCAState,
    current_price: i64,
) void {
    if (state.current_position > 0) {
        state.unrealized_pnl = (current_price - state.avg_cost) * state.current_position;
    } else {
        state.unrealized_pnl = 0;
    }
}

/// Get strategy performance statistics
pub fn get_dca_stats(state: *const DCAState) struct {
    total_invested: i64,
    total_units: i64,
    avg_cost: i64,
    buy_count: u32,
    sell_count: u32,
    realized_pnl: i64,
    unrealized_pnl: i64,
    roi_percent: i64,  // (realized_pnl + unrealized_pnl) / total_invested * 100
} {
    const total_return = state.realized_pnl + state.unrealized_pnl;
    const roi = if (state.total_cost > 0)
        (total_return * 100) / state.total_cost
    else
        0;

    return .{
        .total_invested = state.total_cost,
        .total_units = state.total_units,
        .avg_cost = state.avg_cost,
        .buy_count = state.buy_count,
        .sell_count = state.sell_count,
        .realized_pnl = state.realized_pnl,
        .unrealized_pnl = state.unrealized_pnl,
        .roi_percent = roi,
    };
}

/// Initialize DCA strategy
pub fn init_dca_strategy(
    symbol: [8]u8,
    buy_interval: u64,
    buy_amount: i64,
) DCAState {
    return .{
        .config = .{
            .symbol = symbol,
            .enabled = true,
            .buy_interval_seconds = buy_interval,
            .buy_amount_per_order = buy_amount,
        },
        .last_buy_timestamp = 0,
        .total_cost = 0,
        .total_units = 0,
        .avg_cost = 0,
        .buy_count = 0,
        .sell_count = 0,
        .current_position = 0,
        .position_entry_price = 0,
        .realized_pnl = 0,
        .unrealized_pnl = 0,
    };
}
