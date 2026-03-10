// multi_exchange.zig — Phase 10: Multi-Exchange Arbitrage Detection
// Detects spread opportunities across Kraken ↔ Coinbase ↔ LCX
// Identifies triangular arbitrage: BUY cheap exchange → SELL expensive exchange

const types = @import("types.zig");
const feed_reader = @import("feed_reader.zig");

/// Exchange IDs matching SourceId enum in types.zig
pub const EXCHANGE_KRAKEN = 0;
pub const EXCHANGE_COINBASE = 1;
pub const EXCHANGE_LCX = 2;

/// Spread opportunity: BUY at one exchange, SELL at another
pub const ArbitrageOpportunity = struct {
    pair_id: u16,           // BTC_USD=0, ETH_USD=1, LCX_USD=2
    buy_exchange: u8,       // Cheapest exchange
    sell_exchange: u8,      // Most expensive exchange
    buy_price: u64,         // Price in cents
    sell_price: u64,        // Price in cents
    spread_cents: u64,      // Profit per unit (sell - buy)
    spread_pct: u32,        // Spread as basis points (0-10000 = 0-100%)
    volume_available: u64,  // Min of buy/sell volumes
};

/// Detect arbitrage opportunities for a given pair
/// Returns null if no significant spread found
pub fn detectOpportunity(pair_id: u16, min_spread_bps: u32) ?ArbitrageOpportunity {
    if (pair_id >= 3) return null; // Only BTC, ETH, LCX

    // Read prices from all 3 exchanges
    const kraken_price = feed_reader.readPrice(pair_id) orelse return null;
    const coinbase_price = feed_reader.readPrice(pair_id + 64) orelse kraken_price; // Fallback
    const lcx_price = feed_reader.readPrice(pair_id + 128) orelse kraken_price; // Fallback

    // Find cheapest and most expensive
    var cheapest_exchange: u8 = EXCHANGE_KRAKEN;
    var cheapest_price: u64 = kraken_price;
    var most_expensive_exchange: u8 = EXCHANGE_KRAKEN;
    var most_expensive_price: u64 = kraken_price;

    // Check Coinbase
    if (coinbase_price < cheapest_price) {
        cheapest_exchange = EXCHANGE_COINBASE;
        cheapest_price = coinbase_price;
    }
    if (coinbase_price > most_expensive_price) {
        most_expensive_exchange = EXCHANGE_COINBASE;
        most_expensive_price = coinbase_price;
    }

    // Check LCX
    if (lcx_price < cheapest_price) {
        cheapest_exchange = EXCHANGE_LCX;
        cheapest_price = lcx_price;
    }
    if (lcx_price > most_expensive_price) {
        most_expensive_exchange = EXCHANGE_LCX;
        most_expensive_price = lcx_price;
    }

    // Calculate spread
    const spread_cents = most_expensive_price - cheapest_price;
    if (spread_cents == 0) return null;

    // Calculate spread percentage (basis points: 10000 = 100%)
    const spread_pct: u32 = @intCast((spread_cents * 10000) / cheapest_price);

    // Check if spread meets minimum threshold
    if (spread_pct < min_spread_bps) return null;

    // Get volumes (simplified: use balance from order book)
    const buy_volume = 1000000000; // 10 BTC in satoshis (hardcoded for now)
    const sell_volume = 1000000000;
    const volume_available = if (buy_volume < sell_volume) buy_volume else sell_volume;

    return .{
        .pair_id = pair_id,
        .buy_exchange = cheapest_exchange,
        .sell_exchange = most_expensive_exchange,
        .buy_price = cheapest_price,
        .sell_price = most_expensive_price,
        .spread_cents = spread_cents,
        .spread_pct = spread_pct,
        .volume_available = volume_available,
    };
}

/// Scan all trading pairs for opportunities
pub fn scanAllPairs(min_spread_bps: u32) struct {
    btc_opportunity: ?ArbitrageOpportunity,
    eth_opportunity: ?ArbitrageOpportunity,
    lcx_opportunity: ?ArbitrageOpportunity,
} {
    return .{
        .btc_opportunity = detectOpportunity(0, min_spread_bps), // BTC_USD
        .eth_opportunity = detectOpportunity(1, min_spread_bps), // ETH_USD
        .lcx_opportunity = detectOpportunity(2, min_spread_bps), // LCX_USD
    };
}

/// Calculate profit for an opportunity
/// profit = (sell_price - buy_price) × quantity - fees
pub fn calculateProfit(opp: *const ArbitrageOpportunity, quantity: u64, fee_bps: u32) i64 {
    const gross_profit: i64 = @intCast((opp.spread_cents * quantity) / 100000000);
    const fees: i64 = @intCast(@divTrunc(gross_profit * @as(i64, @intCast(fee_bps)), 10000));
    return gross_profit - fees;
}

/// Get exchange name for logging
pub fn exchangeName(exchange_id: u8) [8]u8 {
    return switch (exchange_id) {
        EXCHANGE_KRAKEN => "Kraken\x00\x00".*,
        EXCHANGE_COINBASE => "Coinbase".*,
        EXCHANGE_LCX => "LCX\x00\x00\x00\x00\x00".*,
        else => "Unknown\x00\x00".*,
    };
}

/// Get pair name for logging
pub fn pairName(pair_id: u16) [8]u8 {
    return switch (pair_id) {
        0 => "BTC_USD\x00\x00".*,
        1 => "ETH_USD\x00\x00".*,
        2 => "LCX_USD\x00\x00".*,
        else => "Unknown\x00\x00".*,
    };
}
