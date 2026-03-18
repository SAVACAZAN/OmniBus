// OmniBus Bot Strategies Module
// Porting all trading strategies from BOT-EXTRACT-ZIG (JavaScript → Zig)
// Core: DCA, GridBot, OneClick, MACD, Pattern Recognition, ML, Support/Resistance

const std = @import("std");

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const Candle = struct {
    time: u64,           // Unix timestamp
    open: i64,           // Price in satoshis (fixed-point)
    high: i64,
    low: i64,
    close: i64,
    volume: u64,
};

pub const Signal = struct {
    symbol: [8]u8,       // e.g., "BTC/USD\0\0"
    time: u64,
    side: enum { BUY, SELL },
    price: i64,
    quantity: i64,
    cost: i64,
    fees: i64,
    profit: i64,
    signal_type: enum { BASE, SAFE, TP, SL, CU, CD, OB, OS, MACD, PATTERN, ML },
    position: i8,        // 0 no position, 1 long, -1 short
};

pub const IndicatorValue = struct {
    time: u64,
    value: i64,
};

pub const BuyOrder = struct {
    price: i64,
    units: i64,
};

pub const TradingStatistics = struct {
    trades: u32,
    base_orders: u32,
    safe_orders: u32,
    tp_orders: u32,
    sl_orders: u32,
    final_balance: i64,
    paid_fees: i64,
    win_loss_ratio: i64,
};

pub const BotState = struct {
    position: i8,
    balance: i64,
    equity: [1024]i64,
    equity_count: u32,
    signals: [2048]Signal,
    signal_count: u32,
    statistics: TradingStatistics,
    buy_orders: [256]BuyOrder,
    buy_order_count: u16,

    total_cost: i64,
    total_amount: i64,
    average_price: i64,
    safe_orders_count: u8,
    entry_cost: i64,
    exit_cost: i64,
    profit: i64,
};

pub const MarketData = struct {
    symbol: [8]u8,
    candles: [4096]Candle,
    candle_count: u32,

    ma12: [2048]IndicatorValue,
    ma12_count: u32,

    ma21: [2048]IndicatorValue,
    ma21_count: u32,

    rsi: [2048]IndicatorValue,
    rsi_count: u32,

    macd: [2048]IndicatorValue,
    macd_count: u32,

    signal_line: [2048]IndicatorValue,
    signal_count: u32,
};

pub const DCAConfig = struct {
    direction: enum { LONG, SHORT },
    max_safe_orders: u8,
    base_order_cost: i64,
    safety_order_cost: i64,
    safety_order_percent: i64,  // In basis points (0.01% = 1)
    stop_loss_percent: i64,
    take_profit_percent: i64,
    taker_fees: i64,            // In basis points
    start_balance: i64,
};

pub const GridConfig = struct {
    symbol: [8]u8,
    lower_price: i64,
    upper_price: i64,
    nr_of_grids: u16,
    grid_type: enum { LINEAR, GEOMETRIC },
    amount_type: enum { PER_GRID, TOTAL, INCREMENTAL_PERCENT },
    total_amount: i64,
    deviation_percent: i64,  // In basis points (legacy, single-sided)
    inc_buy: i64,             // Incremental multiplier (fixed-point)
    inc_sell: i64,
    // GridBotPlus extensions
    grid_side: enum { BUY_ONLY, SELL_ONLY, BOTH } = .BOTH,
    deviation_price_buy: i64,   // Basis points for buy-side price deviation
    deviation_price_sell: i64,  // Basis points for sell-side price deviation
    deviation_amount_buy: i64,  // Basis points for buy-side amount scaling
    deviation_amount_sell: i64, // Basis points for sell-side amount scaling
};

// ============================================================================
// TECHNICAL INDICATORS
// ============================================================================

pub fn calculateMA(prices: []const i64, period: u16) i64 {
    var sum: i64 = 0;
    const start = if (prices.len > period) prices.len - period else 0;
    var count: u16 = 0;

    for (start..prices.len) |i| {
        sum += prices[i];
        count += 1;
    }

    if (count == 0) return 0;
    return sum / @as(i64, count);
}

pub fn calculateRSI(prices: []const i64, period: u16) i64 {
    if (prices.len < period + 1) return 50; // Return neutral RSI

    var gains: i64 = 0;
    var losses: i64 = 0;

    for ((prices.len - period - 1)..prices.len) |i| {
        const change = prices[i] - prices[i - 1];
        if (change > 0) {
            gains += change;
        } else {
            losses += -change;
        }
    }

    const avg_gain = gains / @as(i64, period);
    const avg_loss = losses / @as(i64, period);

    if (avg_loss == 0) return 100;

    const rs = avg_gain * 100 / avg_loss;
    return 100 * 100 / (100 + rs);
}

pub fn calculateMACD(prices: []const i64) struct { macd: i64, signal: i64, histogram: i64 } {
    const ema12 = calculateEMA(prices, 12);
    const ema26 = calculateEMA(prices, 26);
    const macd = ema12 - ema26;

    // Simplified signal line (should use EMA of MACD, but using SMA for simplicity)
    const signal = calculateMA(prices, 9);

    return .{
        .macd = macd,
        .signal = signal,
        .histogram = macd - signal,
    };
}

pub fn calculateEMA(prices: []const i64, period: u16) i64 {
    if (prices.len == 0) return 0;
    if (prices.len < period) {
        return calculateMA(prices, @as(u16, @intCast(prices.len)));
    }

    const sma = calculateMA(prices, period);
    // Simplified EMA: return SMA as base (proper EMA would use smoothing multiplier)
    return sma;
}

pub fn crossUp(line_a: []const i64, line_b: []const i64) bool {
    if (line_a.len < 2 or line_b.len < 2) return false;

    const prev_a = line_a[line_a.len - 2];
    const curr_a = line_a[line_a.len - 1];
    const prev_b = line_b[line_b.len - 2];
    const curr_b = line_b[line_b.len - 1];

    return prev_a <= prev_b and curr_a > curr_b;
}

pub fn crossDown(line_a: []const i64, line_b: []const i64) bool {
    if (line_a.len < 2 or line_b.len < 2) return false;

    const prev_a = line_a[line_a.len - 2];
    const curr_a = line_a[line_a.len - 1];
    const prev_b = line_b[line_b.len - 2];
    const curr_b = line_b[line_b.len - 1];

    return prev_a >= prev_b and curr_a < curr_b;
}

// ============================================================================
// DCA STRATEGY
// ============================================================================

pub fn dca_bot_strategy(data: *const MarketData, config: *const DCAConfig, state: *BotState) void {
    state.position = 0;
    state.balance = config.start_balance;
    state.signal_count = 0;
    state.equity_count = 0;
    state.buy_order_count = 0;

    var safety_order_price: i64 = 0;
    var tp_order_price: i64 = 0;
    var sl_order_price: i64 = 0;
    var current_balance = config.start_balance;

    // Process each candle
    for (0..data.candle_count) |i| {
        const candle = data.candles[i];

        // Simple MA12/MA21 crossover signal
        var buy_signal = false;
        if (data.ma12_count > 0 and data.ma21_count > 0) {
            if (data.ma12[data.ma12_count - 1].value > data.ma21[data.ma21_count - 1].value) {
                buy_signal = true;
            }
        }

        // NO POSITION: Check for entry
        if (state.position == 0 and buy_signal) {
            if (config.direction == .LONG) {
                state.position = 1;

                // Calculate base order amount (avoiding division by zero)
                var base_order_amount = if (candle.close > 0) config.base_order_cost / candle.close else 0;

                // Apply fees
                const fees = (base_order_amount * config.taker_fees) / 10000;
                base_order_amount -= fees;

                state.total_amount = base_order_amount;
                state.total_cost = config.base_order_cost;
                state.entry_cost = config.base_order_cost;

                // Set TP/SL targets
                tp_order_price = candle.close + (candle.close * config.take_profit_percent) / 10000;
                safety_order_price = candle.close - (candle.close * config.safety_order_percent) / 10000;
                sl_order_price = candle.close - (candle.close * config.stop_loss_percent) / 10000;

                // Record signal
                if (state.signal_count < 2048) {
                    state.signals[state.signal_count] = .{
                        .symbol = data.symbol,
                        .time = candle.time,
                        .side = .BUY,
                        .price = candle.close,
                        .quantity = base_order_amount,
                        .cost = config.base_order_cost,
                        .fees = fees,
                        .profit = 0,
                        .signal_type = .BASE,
                        .position = 1,
                    };
                    state.signal_count += 1;
                }

                state.statistics.trades += 1;
                state.statistics.base_orders += 1;
            }
        } else if (state.position == 1) {
            // IN POSITION: Check for TP/SL

            // Take profit
            if (candle.high > tp_order_price) {
                const fees = (state.total_amount * config.taker_fees) / 10000;
                state.total_amount -= fees;
                const exit_cost = state.total_amount * candle.high;
                state.exit_cost = exit_cost;
                state.profit = exit_cost - state.entry_cost;
                current_balance += state.profit;

                if (state.signal_count < 2048) {
                    state.signals[state.signal_count] = .{
                        .symbol = data.symbol,
                        .time = candle.time,
                        .side = .SELL,
                        .price = candle.high,
                        .quantity = state.total_amount,
                        .cost = exit_cost,
                        .fees = fees,
                        .profit = state.profit,
                        .signal_type = .TP,
                        .position = 0,
                    };
                    state.signal_count += 1;
                }

                state.position = 0;
                state.statistics.trades += 1;
                state.statistics.tp_orders += 1;
                safety_order_price = 0;
                tp_order_price = 0;
                sl_order_price = 0;
            }
            // Stop loss
            else if (candle.low < sl_order_price) {
                const fees = (state.total_amount * config.taker_fees) / 10000;
                state.total_amount -= fees;
                const exit_cost = state.total_amount * candle.low;
                state.exit_cost = exit_cost;
                state.profit = exit_cost - state.entry_cost;
                current_balance += state.profit;

                if (state.signal_count < 2048) {
                    state.signals[state.signal_count] = .{
                        .symbol = data.symbol,
                        .time = candle.time,
                        .side = .SELL,
                        .price = candle.low,
                        .quantity = state.total_amount,
                        .cost = exit_cost,
                        .fees = fees,
                        .profit = state.profit,
                        .signal_type = .SL,
                        .position = 0,
                    };
                    state.signal_count += 1;
                }

                state.position = 0;
                state.statistics.trades += 1;
                state.statistics.sl_orders += 1;
                safety_order_price = 0;
                tp_order_price = 0;
                sl_order_price = 0;
            }
            // Safety order
            else if (candle.low < safety_order_price and state.safe_orders_count < config.max_safe_orders) {
                state.safe_orders_count += 1;

                var safety_amount = if (candle.low > 0) config.safety_order_cost / candle.low else 0;
                const fees = (safety_amount * config.taker_fees) / 10000;
                safety_amount -= fees;

                state.total_amount += safety_amount;
                state.total_cost += config.safety_order_cost;
                state.entry_cost += config.safety_order_cost;

                // Update TP based on new average price
                const new_avg_price = if (state.total_amount > 0) state.total_cost / state.total_amount else state.total_cost;
                tp_order_price = new_avg_price + (new_avg_price * config.take_profit_percent) / 10000;
                safety_order_price = candle.low - (candle.low * config.safety_order_percent) / 10000;

                if (state.signal_count < 2048) {
                    state.signals[state.signal_count] = .{
                        .symbol = data.symbol,
                        .time = candle.time,
                        .side = .BUY,
                        .price = candle.low,
                        .quantity = safety_amount,
                        .cost = config.safety_order_cost,
                        .fees = fees,
                        .profit = 0,
                        .signal_type = .SAFE,
                        .position = 1,
                    };
                    state.signal_count += 1;
                }

                state.statistics.trades += 1;
                state.statistics.safe_orders += 1;
            }
        }

        // Track equity
        if (state.equity_count < 1024) {
            state.equity[state.equity_count] = current_balance;
            state.equity_count += 1;
        }
    }

    state.balance = current_balance;
    state.statistics.final_balance = current_balance;
    if (state.statistics.sl_orders > 0) {
        state.statistics.win_loss_ratio = (@as(i64, state.statistics.tp_orders) * 100) / @as(i64, state.statistics.sl_orders);
    }
}

// ============================================================================
// SIMPLE MOVING AVERAGE CROSSOVER STRATEGY
// ============================================================================

pub fn ma_crossover_strategy(data: *const MarketData, state: *BotState) void {
    state.signal_count = 0;
    state.position = 0;

    var ma_short_prev: i64 = 0;
    var ma_long_prev: i64 = 0;

    for (0..data.candle_count) |i| {
        const candle = data.candles[i];

        // Calculate moving averages from historical data
        const prices_slice = data.candles[0..i+1];
        const ma_short = calculateMA(prices_slice, 12);
        const ma_long = calculateMA(prices_slice, 21);

        // Crossover detection
        if (ma_short_prev <= ma_long_prev and ma_short > ma_long) {
            // Golden cross - BUY signal
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .BUY,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .CU,
                    .position = 1,
                };
                state.signal_count += 1;
                state.position = 1;
            }
        } else if (ma_short_prev >= ma_long_prev and ma_short < ma_long) {
            // Death cross - SELL signal
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .SELL,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .CD,
                    .position = 0,
                };
                state.signal_count += 1;
                state.position = 0;
            }
        }

        ma_short_prev = ma_short;
        ma_long_prev = ma_long;
    }
}

// ============================================================================
// RSI OVERBOUGHT/OVERSOLD STRATEGY
// ============================================================================

pub fn rsi_strategy(data: *const MarketData, state: *BotState) void {
    state.signal_count = 0;

    for (0..data.candle_count) |i| {
        const candle = data.candles[i];
        const prices_slice = data.candles[0..i+1];
        const rsi = calculateRSI(prices_slice, 14);

        // Oversold: RSI < 30 → BUY
        if (rsi < 30) {
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .BUY,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .OS,
                    .position = 1,
                };
                state.signal_count += 1;
            }
        }
        // Overbought: RSI > 70 → SELL
        else if (rsi > 70) {
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .SELL,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .OB,
                    .position = 0,
                };
                state.signal_count += 1;
            }
        }
    }
}

// ============================================================================
// MACD STRATEGY
// ============================================================================

pub fn macd_strategy(data: *const MarketData, state: *BotState) void {
    state.signal_count = 0;
    state.position = 0;

    var prev_histogram: i64 = 0;

    for (0..data.candle_count) |i| {
        const candle = data.candles[i];
        const prices_slice = data.candles[0..i+1];

        const macd_result = calculateMACD(prices_slice);
        const histogram = macd_result.histogram;

        // MACD crossover: histogram changes sign
        if (prev_histogram < 0 and histogram >= 0) {
            // BUY: MACD crosses above signal line
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .BUY,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .MACD,
                    .position = 1,
                };
                state.signal_count += 1;
                state.position = 1;
            }
        } else if (prev_histogram > 0 and histogram <= 0) {
            // SELL: MACD crosses below signal line
            if (state.signal_count < 2048) {
                state.signals[state.signal_count] = .{
                    .symbol = data.symbol,
                    .time = candle.time,
                    .side = .SELL,
                    .price = candle.close,
                    .quantity = 1,
                    .cost = candle.close,
                    .fees = 0,
                    .profit = 0,
                    .signal_type = .MACD,
                    .position = 0,
                };
                state.signal_count += 1;
                state.position = 0;
            }
        }

        prev_histogram = histogram;
    }
}

pub fn run_bot_cycle() void {
    // Main bot execution cycle (called from Grid OS)
    // This will be integrated with actual market data from Execution OS
}
