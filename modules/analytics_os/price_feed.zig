// price_feed.zig — Write validated consensus prices to 0x150000 output
// Read by Grid OS via PriceFeedSlot array

const types = @import("types.zig");
const market_matrix = @import("market_matrix.zig");
const consensus = @import("consensus.zig");

// Get pointer to price feed output array at 0x150000
fn getFeedBase() [*]volatile types.PriceFeedSlot {
    return @as([*]volatile types.PriceFeedSlot, @ptrFromInt(types.ANALYTICS_BASE));
}

// Get current TSC
fn getTsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// Write a consensus price to the output feed
pub fn write(pair_id: u16, result: types.ConsensusResult, tick: types.Tick) void {
    if (pair_id >= 64 or !result.valid) return;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    // Update slot (volatile writes)
    slot.pair_id = pair_id;
    slot.exchange_count = consensus.getCount(pair_id);
    slot.flags = 0x01; // Mark as valid
    slot.consensus_price = result.price;
    slot.consensus_volume = tick.size_sats; // Volume from latest tick
    slot.bid_price = tick.bid_cents;
    slot.ask_price = tick.ask_cents;
    slot.last_update_tsc = getTsc();

    // Update 24h high/low
    if (slot.high_24h == 0 or result.price > slot.high_24h) {
        slot.high_24h = result.price;
    }
    if (slot.low_24h == 0 or result.price < slot.low_24h) {
        slot.low_24h = result.price;
    }

    // Placeholder: compute VWAP from matrix data
    slot.vwap = result.price; // Could integrate market matrix volumes here
}

// Mark a pair as stale (when consensus count < 7)
pub fn markStale(pair_id: u16) void {
    if (pair_id >= 64) return;

    const feed = getFeedBase();
    const slot = &feed[pair_id];
    slot.flags = 0x02; // Mark as stale
}

// Initialize feed (zero-fill)
pub fn init() void {
    const feed = getFeedBase();
    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        feed[i] = .{
            .pair_id = @as(u16, @intCast(i)),
            .exchange_count = 0,
            .flags = 0x00, // Stale initially
            ._pad0 = 0,
            .consensus_price = 0,
            .consensus_volume = 0,
            .bid_price = 0,
            .ask_price = 0,
            .last_update_tsc = 0,
            .high_24h = 0,
            .low_24h = 0,
            .vwap = 0,
            ._reserved = [_]u8{0} ** 60,
        };
    }
}

// Get current price for a pair (read by Grid OS)
pub fn getPrice(pair_id: u16) u64 {
    if (pair_id >= 64) return 0;

    const feed = getFeedBase();
    const slot = &feed[pair_id];

    // Only return if valid
    if ((slot.flags & 0x01) != 0) {
        return slot.consensus_price;
    }
    return 0;
}

// Get exchange count for debugging
pub fn getExchangeCount(pair_id: u16) u8 {
    if (pair_id >= 64) return 0;

    const feed = getFeedBase();
    return feed[pair_id].exchange_count;
}
