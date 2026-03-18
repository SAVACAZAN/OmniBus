// feed_reader.zig — Read price consensus from Analytics OS at 0x150000
// Reads PriceFeedSlot structures written by Analytics OS
// All prices in cents (× 100)

const types = @import("types.zig");

// ============================================================================
// Feed Access
// ============================================================================

/// Get mutable pointer to Analytics price feed array
/// Each slot is 128 bytes at [0x150000 + pair_id * 128]
fn getFeedBase() [*]volatile types.PriceFeedSlot {
    return @as([*]volatile types.PriceFeedSlot, @ptrFromInt(types.ANALYTICS_BASE));
}

// ============================================================================
// Price Reading Functions
// ============================================================================

/// Read consensus price for a trading pair
/// Returns null if pair_id is invalid or price is stale
pub fn readPrice(pair_id: u16) ?u64 {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    // Check if price is valid (flag bit 0x01)
    if ((slot.flags & 0x01) == 0) {
        return null; // Stale or invalid
    }

    return slot.consensus_price; // u64 in cents
}

/// Read bid and ask prices for a trading pair
/// Returns null if pair_id is invalid or price is stale
pub fn readBidAsk(pair_id: u16) ?struct { bid: u64, ask: u64 } {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    // Check if price is valid
    if ((slot.flags & 0x01) == 0) {
        return null; // Stale
    }

    return .{
        .bid = slot.bid_price,
        .ask = slot.ask_price,
    };
}

/// Read full price slot with metadata
pub fn readSlot(pair_id: u16) ?types.PriceFeedSlot {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = feed[pair_id];

    // Only return if valid
    if ((slot.flags & 0x01) == 0) {
        return null;
    }

    return slot;
}

/// Check if a price is stale (flag bit 0x02 set)
pub fn isStale(pair_id: u16) bool {
    if (pair_id >= 64) return true;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    return (slot.flags & 0x02) != 0;
}

/// Get exchange count (number of sources in consensus)
pub fn getExchangeCount(pair_id: u16) u8 {
    if (pair_id >= 64) return 0;

    const feed = getFeedBase();
    return feed[pair_id].exchange_count;
}

/// Get 24h high price for a pair
pub fn getHigh24h(pair_id: u16) ?u64 {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    if ((slot.flags & 0x01) == 0) return null;

    return if (slot.high_24h > 0) slot.high_24h else null;
}

/// Get 24h low price for a pair
pub fn getLow24h(pair_id: u16) ?u64 {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    if ((slot.flags & 0x01) == 0) return null;

    return if (slot.low_24h > 0) slot.low_24h else null;
}

/// Get VWAP (Volume Weighted Average Price)
pub fn getVwap(pair_id: u16) ?u64 {
    if (pair_id >= 64) return null;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    if ((slot.flags & 0x01) == 0) return null;

    return if (slot.vwap > 0) slot.vwap else null;
}

/// Get last update TSC for timing decisions
pub fn getLastUpdateTsc(pair_id: u16) u64 {
    if (pair_id >= 64) return 0;

    const feed = getFeedBase();
    return feed[pair_id].last_update_tsc;
}

/// Get consensus volume (24h or latest)
pub fn getVolume(pair_id: u16) u64 {
    if (pair_id >= 64) return 0;

    const feed = getFeedBase();
    return feed[pair_id].consensus_volume;
}

// ============================================================================
// Validation & Utility
// ============================================================================

/// Check if price has been updated since last check
/// Compare against previous TSC value
pub fn isPriceNewer(pair_id: u16, previous_tsc: u64) bool {
    if (pair_id >= 64) return false;

    const feed = getFeedBase();
    return feed[pair_id].last_update_tsc > previous_tsc;
}

/// Validate spread between bid and ask
/// Returns true if spread is within reasonable bounds (< 10% for debugging)
pub fn isSpreadValid(pair_id: u16) bool {
    if (pair_id >= 64) return false;

    const bid_ask = readBidAsk(pair_id) orelse return false;

    if (bid_ask.ask <= bid_ask.bid) return false;

    const spread_cents = bid_ask.ask - bid_ask.bid;
    const spread_pct = (spread_cents * 10000) / bid_ask.bid;

    return spread_pct < 10000; // < 100% spread (reasonable sanity check)
}
