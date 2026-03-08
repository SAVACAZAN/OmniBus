// order_format.zig — Fixed-point to string conversions for API formatting
// Formats: prices (×100 cents), quantities (×1e8 satoshis), pair symbols

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// Integer to String Conversion (no allocator)
// ============================================================================

/// Convert u64 to decimal string, returns length written
fn intToStr(buf: *[32]u8, value: u64) usize {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    var digits: [20]u8 = undefined;
    var digit_count: usize = 0;
    var remaining = value;

    while (remaining > 0) {
        digits[digit_count] = '0' + @as(u8, @intCast(remaining % 10));
        digit_count += 1;
        remaining /= 10;
    }

    // Reverse digits into output buffer
    var i: usize = 0;
    while (i < digit_count) {
        buf[i] = digits[digit_count - 1 - i];
        i += 1;
    }

    return digit_count;
}

// ============================================================================
// Price Formatting: u64 cents → "XXXXX.XX" (up to 32 chars)
// ============================================================================

/// Format price from fixed-point cents to decimal string
/// Example: 6350000 → "63500.00"
/// Input: 6350000 (means $63,500.00 in cents)
/// Output: buf filled with "63500.00", returns slice
pub fn formatPrice(buf: *[32]u8, cents: u64) []const u8 {
    const dollars = cents / 100;
    const cents_only = cents % 100;

    // Format: "<dollars>.<cents>"
    const len = intToStr(buf, dollars);
    buf[len] = '.';

    // Always 2 digits for cents
    buf[len + 1] = '0' + @as(u8, @intCast(cents_only / 10));
    buf[len + 2] = '0' + @as(u8, @intCast(cents_only % 10));

    return buf[0 .. len + 3];
}

// ============================================================================
// Quantity Formatting: u64 satoshis → "X.XXXXXXXX" (up to 32 chars)
// ============================================================================

/// Format quantity from fixed-point satoshis to decimal string
/// Example: 100000000 → "1.00000000"
/// Input: 100000000 satoshis (means 1 BTC)
/// Output: buf filled with "1.00000000", returns slice
pub fn formatQty(buf: *[32]u8, sats: u64) []const u8 {
    const btc = sats / 100_000_000;
    const sats_only = sats % 100_000_000;

    // Format: "<btc>.<satoshis>"
    const len = intToStr(buf, btc);
    buf[len] = '.';

    // Always 8 digits for satoshis
    var i: u32 = 0;
    var remaining = sats_only;
    while (i < 8) : (i += 1) {
        remaining = remaining * 10;
        buf[len + 1 + i] = '0' + @as(u8, @intCast(remaining / 100_000_000));
        remaining = remaining % 100_000_000;
    }

    return buf[0 .. len + 1 + 8];
}

// ============================================================================
// Pair Symbol Mapping
// ============================================================================

/// Get trading pair symbol for given exchange
/// pair_id: 0=BTC_USD, 1=ETH_USD, 2=XRP_USD
/// exchange_id: 0=Kraken, 1=Coinbase, 2=LCX
/// Returns: static string like "XXBTZUSD", "BTC-USD", "BTC/EUR"
pub fn pairSymbol(exchange_id: u8, pair_id: u16) []const u8 {
    switch (exchange_id) {
        types.KRAKEN => {
            return switch (pair_id) {
                0 => "XXBTZUSD",    // BTC_USD
                1 => "XETHZUSD",    // ETH_USD
                2 => "XXRPZUSD",    // XRP_USD
                else => "UNKNOWN",
            };
        },
        types.COINBASE => {
            return switch (pair_id) {
                0 => "BTC-USD",     // BTC_USD
                1 => "ETH-USD",     // ETH_USD
                2 => "XRP-USD",     // XRP_USD
                else => "UNKNOWN",
            };
        },
        types.LCX => {
            return switch (pair_id) {
                0 => "BTC/EUR",     // BTC_USD (LCX uses EUR instead)
                1 => "ETH/EUR",     // ETH_USD
                2 => "XRP/EUR",     // XRP_USD
                else => "UNKNOWN",
            };
        },
        else => return "UNKNOWN",
    }
}

// ============================================================================
// Side String (buy/sell)
// ============================================================================

/// Format side (0=buy, 1=sell) as string
/// Kraken expects "buy"/"sell", Coinbase expects "BUY"/"SELL"
pub fn sideLowercase(side: u8) []const u8 {
    return if (side == 0) "buy" else "sell";
}

pub fn sideUppercase(side: u8) []const u8 {
    return if (side == 0) "BUY" else "SELL";
}

// ============================================================================
// Pair ID to String
// ============================================================================

pub fn pairIdName(pair_id: u16) []const u8 {
    return switch (pair_id) {
        0 => "BTC_USD",
        1 => "ETH_USD",
        2 => "XRP_USD",
        else => "UNKNOWN",
    };
}

// ============================================================================
// Exchange ID to String
// ============================================================================

pub fn exchangeName(exchange_id: u8) []const u8 {
    return switch (exchange_id) {
        types.KRAKEN => "kraken",
        types.COINBASE => "coinbase",
        types.LCX => "lcx",
        else => "unknown",
    };
}
