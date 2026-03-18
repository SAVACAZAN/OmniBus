// scanner.zig — Cross-exchange arbitrage opportunity detection
// Ported from Zig-toolz-Assembly backend/src/arbitrage/scanner.zig
// Fixed-point arithmetic, no allocations

const types = @import("types.zig");
const math = @import("math.zig");
const feed_reader = @import("feed_reader.zig");

// ============================================================================
// Price Book Structure
// ============================================================================

/// Minimal order book for arbitrage detection
pub const PriceBook = struct {
    exchange_id: u16,
    pair_id: u16,
    bid_cents: u64,      // Best bid price
    ask_cents: u64,      // Best ask price
    volume_sats: u64,    // Available volume
    tsc: u64,            // Timestamp
};

// ============================================================================
// Arbitrage Opportunity Array
// ============================================================================

/// Get pointer to arbitrage opportunity array at 0x114640
fn getOpportunityBase() [*]volatile types.ArbitrageOpportunity {
    return @as([*]volatile types.ArbitrageOpportunity, @ptrFromInt(types.GRID_BASE + types.ARBITRAGE_OPP_OFFSET));
}

// ============================================================================
// Cross-Exchange Detection
// ============================================================================

/// Detect arbitrage opportunity: buy at exchange_a, sell at exchange_b
/// Returns net profit in basis points (positive = profitable)
fn detectArbitragePair(
    exchange_a: u16,
    ask_a_cents: u64,
    exchange_b: u16,
    bid_b_cents: u64,
) i32 {
    if (ask_a_cents == 0 or bid_b_cents == 0) return -1000;

    const fee_a = math.getFeeForExchange(@as(u8, @intCast(exchange_a)));
    const fee_b = math.getFeeForExchange(@as(u8, @intCast(exchange_b)));

    return math.calcNetProfitBps(ask_a_cents, bid_b_cents, fee_a, fee_b);
}

/// Scan for triangular arbitrage across three exchanges
/// Returns number of opportunities found
pub fn scanTriangular(_pair_id: u16, _confidence: u8) u32 {
    _ = _pair_id;       // Available for future use
    _ = _confidence;    // Available for future use
    // Read prices for this pair from Analytics
    const price_slot = feed_reader.readSlot(0) orelse return 0;

    const bid_price = price_slot.bid_price;
    const ask_price = price_slot.ask_price;

    if (bid_price == 0 or ask_price == 0) return 0;

    // Dummy: in real impl, would have multi-exchange prices
    // For now, detect same-price arbitrage (no real opportunity)
    // Actual impl requires price books from C NIC driver

    return 0;
}

/// Detect simple two-exchange arbitrage
/// exchange_a: buyer (we pay ask), exchange_b: seller (we receive bid)
/// Returns profit in basis points
pub fn detectTwoExchange(
    _pair_id: u16,
    exchange_a: u16,
    price_a_cents: u64, // ask at A
    exchange_b: u16,
    price_b_cents: u64, // bid at B
) i32 {
    _ = _pair_id; // Available for future use
    return detectArbitragePair(exchange_a, price_a_cents, exchange_b, price_b_cents);
}

/// Scan all available opportunity slots and return count
pub fn countOpportunities() u32 {
    const opps = getOpportunityBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_OPPORTUNITIES) : (i += 1) {
        const opp = opps[i];
        if (opp.pair_id == 0 and opp.flags == 0) break;
        if ((opp.flags & 0x01) != 0) count += 1; // Valid flag
    }

    return count;
}

/// Register detected opportunity
/// Returns true if slot found, false if array full
pub fn registerOpportunity(
    pair_id: u16,
    exchange_a: u8,
    exchange_b: u8,
    price_a_cents: u64,
    price_b_cents: u64,
    net_profit_bps: i32,
    confidence_pct: u8,
) bool {
    if (net_profit_bps < types.MIN_PROFIT_BPS) return false; // Below threshold

    const opps = getOpportunityBase();

    // Find first empty slot
    var i: u32 = 0;
    while (i < types.MAX_OPPORTUNITIES) : (i += 1) {
        const opp = &opps[i];

        // Empty slot has zero pair_id and zero flags
        if (opp.pair_id == 0 and opp.flags == 0) {
            opp.* = .{
                .pair_id = pair_id,
                .exchange_a = exchange_a,
                .exchange_b = exchange_b,
                .flags = 0x01, // Mark as valid
                .price_a_cents = price_a_cents,
                .price_b_cents = price_b_cents,
                .net_profit_bps = net_profit_bps,
                .confidence_pct = confidence_pct,
                .tsc = rdtsc(),
            };

            return true;
        }
    }

    return false; // Array full
}

/// Mark opportunity as executed
pub fn markOpportunityExecuted(opp_index: u32) bool {
    if (opp_index >= types.MAX_OPPORTUNITIES) return false;

    const opps = getOpportunityBase();
    opps[opp_index].flags |= 0x02; // Set executed flag

    return true;
}

/// Get opportunity by index
pub fn getOpportunity(index: u32) ?types.ArbitrageOpportunity {
    if (index >= types.MAX_OPPORTUNITIES) return null;

    const opps = getOpportunityBase();
    const opp = opps[index];

    if (opp.pair_id == 0) return null;

    return opp;
}

// ============================================================================
// Opportunity Analysis
// ============================================================================

/// Find best opportunity (highest profit)
pub fn findBestOpportunity() ?struct { index: u32, opp: types.ArbitrageOpportunity } {
    const opps = getOpportunityBase();
    var best_index: u32 = 0xFFFFFFFF;
    var best_profit: i32 = types.MIN_PROFIT_BPS - 1;

    var i: u32 = 0;
    while (i < types.MAX_OPPORTUNITIES) : (i += 1) {
        const opp = opps[i];
        if (opp.pair_id == 0) break;
        if ((opp.flags & 0x01) == 0) continue; // Skip invalid

        if (opp.net_profit_bps > best_profit) {
            best_profit = opp.net_profit_bps;
            best_index = i;
        }
    }

    if (best_index == 0xFFFFFFFF) return null;

    return .{
        .index = best_index,
        .opp = opps[best_index],
    };
}

/// Count unexecuted opportunities
pub fn countPending() u32 {
    const opps = getOpportunityBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_OPPORTUNITIES) : (i += 1) {
        const opp = opps[i];
        if (opp.pair_id == 0) break;

        if ((opp.flags & 0x01) != 0 and (opp.flags & 0x02) == 0) {
            count += 1; // Valid but not executed
        }
    }

    return count;
}

/// Clear all opportunities (reset after processing)
pub fn clearAll() void {
    const opps = getOpportunityBase();

    var i: u32 = 0;
    while (i < types.MAX_OPPORTUNITIES) : (i += 1) {
        opps[i] = .{
            .pair_id = 0,
            .exchange_a = 0,
            .exchange_b = 0,
            .flags = 0,
            .price_a_cents = 0,
            .price_b_cents = 0,
            .net_profit_bps = 0,
            .confidence_pct = 0,
            .tsc = 0,
        };
    }
}

// ============================================================================
// Timing
// ============================================================================

/// Read current TSC
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
