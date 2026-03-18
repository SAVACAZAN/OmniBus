// OmniBus Arbitrage Engine – CEX vs DEX spotting and execution
// Cross-venue arbitrage: CEX (Kraken, LCX, Coinbase) vs DEX (Uniswap, Hyperliquid)
// Detects price discrepancies and automatically routes orders to best venue

const std = @import("std");
const bot = @import("bot_strategies.zig");
const dex = @import("dex_interface.zig");
const unified_ob = @import("unified_orderbook.zig");

// ============================================================================
// ARBITRAGE CONFIGURATION
// ============================================================================

pub const ArbitrageConfig = struct {
    symbol: [16]u8,
    enabled: bool = true,
    min_spread_bps: i64 = 10,         // Minimum spread to trade (10 = 0.1%)
    max_position_size: i64 = 1_000_000, // Max position (satoshis or wei)
    rebalance_threshold_bps: i64 = 20, // Rebalance when position deviates 0.2%
    use_cex: bool = true,
    use_dex_uniswap: bool = true,
    use_dex_hyperliquid: bool = true,
};

pub const ArbitrageState = struct {
    config: ArbitrageConfig,
    unified_orderbook: *unified_ob.UnifiedOrderBookState,

    // Price tracking
    cex_bid: i64,            // Best CEX bid price
    cex_ask: i64,            // Best CEX ask price
    dex_uniswap_price: i64,  // Uniswap spot price
    dex_hl_price: i64,       // Hyperliquid mark price

    // Current positions
    cex_position: i64,
    dex_position: i64,
    total_position: i64,

    // Arbitrage metrics
    arbitrage_count: u32,
    successful_arbs: u32,
    failed_arbs: u32,
    total_arb_profit: i64,
    max_spread_bps: i64,     // Highest spread detected
};

/// Initialize arbitrage engine
pub fn init_arbitrage_engine(
    config: ArbitrageConfig,
    uob: *unified_ob.UnifiedOrderBookState,
) ArbitrageState {
    return .{
        .config = config,
        .unified_orderbook = uob,
        .cex_bid = 0,
        .cex_ask = 0,
        .dex_uniswap_price = 0,
        .dex_hl_price = 0,
        .cex_position = 0,
        .dex_position = 0,
        .total_position = 0,
        .arbitrage_count = 0,
        .successful_arbs = 0,
        .failed_arbs = 0,
        .total_arb_profit = 0,
        .max_spread_bps = 0,
    };
}

// ============================================================================
// PRICE DISCOVERY
// ============================================================================

/// Update CEX best bid/ask from market data
pub fn update_cex_prices(
    state: *ArbitrageState,
    market_data: *const bot.MarketData,
) void {
    if (market_data.candle_count == 0) return;

    const latest_candle = market_data.candles[market_data.candle_count - 1];

    // Estimate bid/ask from candle data
    // Bid = close - (high - low) * 0.25 (conservative)
    // Ask = close + (high - low) * 0.25 (conservative)
    const spread_range = latest_candle.high - latest_candle.low;
    const bid_offset = (spread_range * 25) / 100; // 0.25x spread
    const ask_offset = (spread_range * 25) / 100;

    state.cex_bid = latest_candle.close - bid_offset;
    state.cex_ask = latest_candle.close + ask_offset;
}

/// Update DEX prices (Uniswap, Hyperliquid)
pub fn update_dex_prices(
    state: *ArbitrageState,
    uniswap_price: i64,
    hyperliquid_price: i64,
) void {
    state.dex_uniswap_price = uniswap_price;
    state.dex_hl_price = hyperliquid_price;
}

/// Calculate spread between two prices in basis points
fn calculate_spread_bps(price_a: i64, price_b: i64) i64 {
    if (price_b == 0) return 0;

    const diff = if (price_a > price_b)
        price_a - price_b
    else
        price_b - price_a;

    return (diff * 10000) / price_b;
}

// ============================================================================
// ARBITRAGE DETECTION
// ============================================================================

pub const ArbitrageOpportunity = struct {
    symbol: [16]u8,
    buy_venue: enum { CEX, UNISWAP, HYPERLIQUID },
    sell_venue: enum { CEX, UNISWAP, HYPERLIQUID },
    buy_price: i64,
    sell_price: i64,
    spread_bps: i64,
    estimated_profit: i64,
    risk_score: i64,       // 0-100 (gas cost, liquidity risk, etc.)
};

/// Scan for arbitrage opportunities across all venues
pub fn detect_arb_opportunity(
    state: *const ArbitrageState,
) ?ArbitrageOpportunity {
    var best_opp: ?ArbitrageOpportunity = null;
    var best_spread: i64 = 0;

    // Check CEX buy, Uniswap sell
    if (state.config.use_cex and state.config.use_dex_uniswap) {
        const spread = calculate_spread_bps(state.dex_uniswap_price, state.cex_bid);
        if (spread > best_spread and state.dex_uniswap_price > state.cex_bid) {
            best_spread = spread;
            best_opp = .{
                .symbol = state.config.symbol,
                .buy_venue = .CEX,
                .sell_venue = .UNISWAP,
                .buy_price = state.cex_bid,
                .sell_price = state.dex_uniswap_price,
                .spread_bps = spread,
                .estimated_profit = 0,
                .risk_score = 30, // CEX buy + DEX sell has moderate risk
            };
        }
    }

    // Check CEX buy, Hyperliquid sell (perps, more complex)
    if (state.config.use_cex and state.config.use_dex_hyperliquid) {
        const spread = calculate_spread_bps(state.dex_hl_price, state.cex_bid);
        if (spread > best_spread and state.dex_hl_price > state.cex_bid) {
            best_spread = spread;
            best_opp = .{
                .symbol = state.config.symbol,
                .buy_venue = .CEX,
                .sell_venue = .HYPERLIQUID,
                .buy_price = state.cex_bid,
                .sell_price = state.dex_hl_price,
                .spread_bps = spread,
                .estimated_profit = 0,
                .risk_score = 60, // Perps add leverage/funding risk
            };
        }
    }

    // Check Uniswap buy, CEX sell
    if (state.config.use_dex_uniswap and state.config.use_cex) {
        const spread = calculate_spread_bps(state.cex_ask, state.dex_uniswap_price);
        if (spread > best_spread and state.cex_ask > state.dex_uniswap_price) {
            best_spread = spread;
            best_opp = .{
                .symbol = state.config.symbol,
                .buy_venue = .UNISWAP,
                .sell_venue = .CEX,
                .buy_price = state.dex_uniswap_price,
                .sell_price = state.cex_ask,
                .spread_bps = spread,
                .estimated_profit = 0,
                .risk_score = 40, // DEX buy + CEX sell has slippage risk
            };
        }
    }

    // Filter by minimum spread
    if (best_opp) |opp| {
        if (opp.spread_bps >= state.config.min_spread_bps) {
            return opp;
        }
    }

    return null;
}

// ============================================================================
// ARBITRAGE EXECUTION
// ============================================================================

/// Execute arbitrage opportunity
pub fn execute_arbitrage(
    state: *ArbitrageState,
    opp: *const ArbitrageOpportunity,
    amount: i64,
    timestamp: u64,
) bool {
    if (std.mem.eql(u8, &opp.symbol, &[_]u8{0} ** 16)) return false;

    // Step 1: Execute buy on buy_venue
    const buy_order_id = switch (opp.buy_venue) {
        .CEX => execute_cex_buy(state, opp.buy_price, amount, timestamp),
        .UNISWAP => execute_uniswap_buy(state, opp.buy_price, amount, timestamp),
        .HYPERLIQUID => execute_hyperliquid_buy(state, opp.buy_price, amount, timestamp),
    };

    if (buy_order_id == 0) {
        state.failed_arbs += 1;
        return false;
    }

    // Step 2: Execute sell on sell_venue
    const sell_order_id = switch (opp.sell_venue) {
        .CEX => execute_cex_sell(state, opp.sell_price, amount, timestamp),
        .UNISWAP => execute_uniswap_sell(state, opp.sell_price, amount, timestamp),
        .HYPERLIQUID => execute_hyperliquid_sell(state, opp.sell_price, amount, timestamp),
    };

    if (sell_order_id == 0) {
        // Partial failure - bought but couldn't sell
        state.failed_arbs += 1;
        return false;
    }

    // Success!
    state.arbitrage_count += 1;
    state.successful_arbs += 1;

    // Calculate profit
    const profit = (opp.sell_price * amount) - (opp.buy_price * amount);
    state.total_arb_profit += profit;

    if (opp.spread_bps > state.max_spread_bps) {
        state.max_spread_bps = opp.spread_bps;
    }

    return true;
}

fn execute_cex_buy(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {
    // Call into cex_interface to place buy order
    const order_id = unified_ob.create_cex_order(
        state.unified_orderbook,
        0, // KRAKEN
        state.config.symbol,
        .BUY,
        .MARKET,
        price,
        amount,
        timestamp,
    );

    if (order_id > 0) {
        state.cex_position += amount;
        state.total_position += amount;
    }

    return order_id;
}

fn execute_cex_sell(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {
    const order_id = unified_ob.create_cex_order(
        state.unified_orderbook,
        0, // KRAKEN
        state.config.symbol,
        .SELL,
        .MARKET,
        price,
        amount,
        timestamp,
    );

    if (order_id > 0) {
        state.cex_position -= amount;
        state.total_position -= amount;
    }

    return order_id;
}

fn execute_uniswap_buy(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {
    const order_id = unified_ob.create_dex_order(
        state.unified_orderbook,
        .DEX_UNISWAP_V3,
        state.config.symbol,
        .BUY,
        amount,
        price,
        1, // Ethereum mainnet
        0, // strategy_id
        timestamp,
    );

    if (order_id > 0) {
        state.dex_position += amount;
        state.total_position += amount;
    }

    return order_id;
}

fn execute_uniswap_sell(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {

    const order_id = unified_ob.create_dex_order(
        state.unified_orderbook,
        .DEX_UNISWAP_V3,
        state.config.symbol,
        .SELL,
        amount,
        price,
        1,
        0,
        timestamp,
    );

    if (order_id > 0) {
        state.dex_position -= amount;
        state.total_position -= amount;
    }

    return order_id;
}

fn execute_hyperliquid_buy(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {
    const order_id = unified_ob.create_dex_order(
        state.unified_orderbook,
        .DEX_HYPERLIQUID,
        state.config.symbol,
        .BUY,
        amount,
        price,
        0, // Hyperliquid is off-chain
        0,
        timestamp,
    );

    if (order_id > 0) {
        state.dex_position += amount;
        state.total_position += amount;
    }

    return order_id;
}

fn execute_hyperliquid_sell(
    state: *ArbitrageState,
    price: i64,
    amount: i64,
    timestamp: u64,
) u64 {
    const order_id = unified_ob.create_dex_order(
        state.unified_orderbook,
        .DEX_HYPERLIQUID,
        state.config.symbol,
        .SELL,
        amount,
        price,
        0,
        0,
        timestamp,
    );

    if (order_id > 0) {
        state.dex_position -= amount;
        state.total_position -= amount;
    }

    return order_id;
}

// ============================================================================
// MAIN ARBITRAGE CYCLE
// ============================================================================

/// Run arbitrage detection and execution cycle
pub fn arbitrage_cycle(
    state: *ArbitrageState,
    market_data: *const bot.MarketData,
    uniswap_price: i64,
    hyperliquid_price: i64,
    timestamp: u64,
) bool {
    // Step 1: Update prices
    update_cex_prices(state, market_data);
    update_dex_prices(state, uniswap_price, hyperliquid_price);

    // Step 2: Detect opportunity
    if (detect_arb_opportunity(state)) |opp| {
        // Step 3: Execute if position allows
        if (state.total_position < state.config.max_position_size) {
            const amount = state.config.max_position_size - state.total_position;
            return execute_arbitrage(state, &opp, amount, timestamp);
        }
    }

    return false;
}

/// Get arbitrage performance statistics
pub fn get_arb_stats(state: *const ArbitrageState) struct {
    arb_count: u32,
    successful: u32,
    failed: u32,
    success_rate: i64,
    total_profit: i64,
    max_spread_detected_bps: i64,
} {
    const success_rate = if (state.arbitrage_count > 0)
        (state.successful_arbs * 100) / @as(i64, @intCast(state.arbitrage_count))
    else
        0;

    return .{
        .arb_count = state.arbitrage_count,
        .successful = state.successful_arbs,
        .failed = state.failed_arbs,
        .success_rate = success_rate,
        .total_profit = state.total_arb_profit,
        .max_spread_detected_bps = state.max_spread_bps,
    };
}
