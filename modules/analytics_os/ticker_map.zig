// ticker_map.zig — Compile-time pair ID lookup (no allocator)
// Maps exchange-specific pair strings to universal u16 pair IDs

const std = @import("std");
const types = @import("types.zig");

// Supported pairs: BTC/USD, ETH/USD, XRP/USD (can extend)
pub const PairId = enum(u16) {
    BTC_USD = 0,
    ETH_USD = 1,
    XRP_USD = 2,
    unknown = 0xFFFF,
};

pub const ExchangePairMapping = struct {
    pair_id: PairId,
    kraken_name: [*:0]const u8,
    coinbase_name: [*:0]const u8,
    lcx_name: [*:0]const u8,
};

// Compile-time pair database
const PAIR_DB = [_]ExchangePairMapping{
    .{
        .pair_id = .BTC_USD,
        .kraken_name = "XBT/USD",
        .coinbase_name = "BTC-USD",
        .lcx_name = "BTC/USD",
    },
    .{
        .pair_id = .ETH_USD,
        .kraken_name = "ETH/USD",
        .coinbase_name = "ETH-USD",
        .lcx_name = "ETH/USD",
    },
    .{
        .pair_id = .XRP_USD,
        .kraken_name = "XRP/USD",
        .coinbase_name = "XRP-USD",
        .lcx_name = "XRP/USD",
    },
};

// String comparison: returns true if strings match
fn streq(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (true) {
        if (a[i] != b[i]) return false;
        if (a[i] == 0) return true;
        i += 1;
    }
}

// Lookup pair ID from Kraken symbol
pub fn krakenToId(symbol: [*:0]const u8) PairId {
    for (PAIR_DB) |mapping| {
        if (streq(symbol, mapping.kraken_name)) return mapping.pair_id;
    }
    return .unknown;
}

// Lookup pair ID from Coinbase product ID
pub fn coinbaseToId(product_id: [*:0]const u8) PairId {
    for (PAIR_DB) |mapping| {
        if (streq(product_id, mapping.coinbase_name)) return mapping.pair_id;
    }
    return .unknown;
}

// Lookup pair ID from LCX symbol
pub fn lcxToId(symbol: [*:0]const u8) PairId {
    for (PAIR_DB) |mapping| {
        if (streq(symbol, mapping.lcx_name)) return mapping.pair_id;
    }
    return .unknown;
}

// Convert pair ID to Kraken symbol (for subscription)
pub fn idToKraken(pair_id: PairId) ?[*:0]const u8 {
    for (PAIR_DB) |mapping| {
        if (mapping.pair_id == pair_id) return mapping.kraken_name;
    }
    return null;
}

// Convert pair ID to Coinbase product ID (for subscription)
pub fn idToCoinbase(pair_id: PairId) ?[*:0]const u8 {
    for (PAIR_DB) |mapping| {
        if (mapping.pair_id == pair_id) return mapping.coinbase_name;
    }
    return null;
}

// Convert pair ID to LCX symbol (for subscription)
pub fn idToLcx(pair_id: PairId) ?[*:0]const u8 {
    for (PAIR_DB) |mapping| {
        if (mapping.pair_id == pair_id) return mapping.lcx_name;
    }
    return null;
}

// Get pair ID from source-specific symbol
pub fn pairFromExchange(source: types.SourceId, symbol: [*:0]const u8) PairId {
    return switch (source) {
        .kraken => krakenToId(symbol),
        .coinbase => coinbaseToId(symbol),
        .lcx => lcxToId(symbol),
        .unknown => .unknown,
    };
}
