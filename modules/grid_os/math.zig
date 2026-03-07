// math.zig — Fixed-point arithmetic for Grid OS
// All prices in cents (× 100), sizes in satoshis (× 1e8)
// No floating-point: all calculations use u64/i64

const types = @import("types.zig");

// ============================================================================
// Basis Points Calculations
// ============================================================================

/// Convert percentage to basis points (e.g., 0.50% → 50 bps)
pub fn percentToBps(percent_100x: u32) u32 {
    return percent_100x;
}

/// Convert basis points to fixed-point decimal factor
/// E.g., 50 bps → factor that reduces price by 0.5%
/// factor = 10000 - bps (for fee deduction)
pub fn bpsToFactor(bps: u32) u32 {
    if (bps >= 10000) return 0;
    return 10000 - bps;
}

/// Apply basis points reduction: value * (1 - bps/10000)
/// Used for fee deduction
pub fn applyBpsReduction(value: u64, bps: u32) u64 {
    if (bps >= 10000) return 0;
    return (value * @as(u64, 10000 - bps)) / 10000;
}

/// Calculate basis points: (diff / base) * 10000
/// Used for spread calculation: spread_bps = (ask - bid) / bid * 10000
pub fn calcBasisPoints(diff: i64, base: u64) i32 {
    if (base == 0) return 0;
    const scaled_diff = diff * 10000;
    const base_i64 = @as(i64, @intCast(base));
    const bps = @divTrunc(scaled_diff, base_i64);
    return @as(i32, @intCast(bps));
}

// ============================================================================
// Fee Calculations
// ============================================================================

/// Get fee schedule (taker) for an exchange
/// Returns basis points
pub fn getFeeForExchange(exchange_id: u8) u32 {
    return switch (exchange_id) {
        0 => types.FEE_KRAKEN_TAKER_BPS,      // Kraken
        1 => types.FEE_COINBASE_TAKER_BPS,    // Coinbase
        2 => types.FEE_LCX_TAKER_BPS,         // LCX
        else => 100, // Unknown: assume 1% fee as default
    };
}

/// Calculate net arbitrage profit in basis points
/// profit_bps = (bid_b - ask_a) / ask_a * 10000 - fee_a - fee_b
/// Returns negative if loss, positive if profit
pub fn calcNetProfitBps(ask_a_cents: u64, bid_b_cents: u64, fee_a_bps: u32, fee_b_bps: u32) i32 {
    if (ask_a_cents == 0 or bid_b_cents <= ask_a_cents) {
        return -1000; // Large loss if price inverted
    }

    const spread_cents = bid_b_cents - ask_a_cents;

    // spread_bps = spread / ask * 10000
    const spread_bps = @divTrunc(
        @as(i64, @intCast(spread_cents * 10000)),
        @as(i64, @intCast(ask_a_cents)),
    );

    // net_profit_bps = spread_bps - total_fees
    const total_fees = @as(i32, @intCast(fee_a_bps + fee_b_bps));
    const net_bps = @as(i32, @intCast(spread_bps)) - total_fees;

    return net_bps;
}

/// Calculate profit in cents given buy/sell prices
/// profit = (sell_price - buy_price - fees) * quantity
pub fn calcProfitCents(buy_price_cents: u64, sell_price_cents: u64, quantity_sats: u64, total_fee_bps: u32) i64 {
    if (sell_price_cents <= buy_price_cents) {
        return -1;
    }

    const gross_profit_per_sat = sell_price_cents - buy_price_cents;
    const fee_per_sat = (buy_price_cents * @as(u64, total_fee_bps)) / 10000;

    if (fee_per_sat >= gross_profit_per_sat) {
        return -1; // Fees exceed profit
    }

    const net_profit_per_sat = gross_profit_per_sat - fee_per_sat;

    // Avoid overflow: scale down if necessary
    if (quantity_sats > (18446744073709551615 / net_profit_per_sat)) {
        // Would overflow: scale down
        return @as(i64, @intCast((quantity_sats / 1000000000) * (net_profit_per_sat / 1000)));
    }

    return @as(i64, @intCast(quantity_sats * net_profit_per_sat));
}

// ============================================================================
// Grid Price Calculations
// ============================================================================

/// Generate buy levels below current price
/// Returns array of prices, highest first (closest to current)
pub fn generateBuyLevels(current_price: u64, step_cents: u64, lower_bound: u64, max_levels: usize) [types.MAX_LEVELS]u64 {
    var levels: [types.MAX_LEVELS]u64 = [_]u64{0} ** types.MAX_LEVELS;
    var count: usize = 0;
    var price = current_price;

    while (price > lower_bound and count < max_levels) {
        levels[count] = price;
        count += 1;

        if (step_cents > price) break; // Prevent underflow
        price -= step_cents;
    }

    return levels;
}

/// Generate sell levels above current price
/// Returns array of prices, lowest first (closest to current)
pub fn generateSellLevels(current_price: u64, step_cents: u64, upper_bound: u64, max_levels: usize) [types.MAX_LEVELS]u64 {
    var levels: [types.MAX_LEVELS]u64 = [_]u64{0} ** types.MAX_LEVELS;
    var count: usize = 0;
    var price = current_price + step_cents;

    while (price < upper_bound and count < max_levels) {
        levels[count] = price;
        count += 1;

        if (price > upper_bound - step_cents) break; // Prevent overflow
        price += step_cents;
    }

    return levels;
}

// ============================================================================
// Rebalance Triggers
// ============================================================================

/// Check if price drift exceeds threshold for rebalancing
/// trigger_pct = percentage change from grid midpoint
/// Returns true if |current - midpoint| / midpoint > trigger_pct
pub fn shouldRebalance(current_price: u64, lower_bound: u64, upper_bound: u64, trigger_pct: u32) bool {
    if (lower_bound == 0 or upper_bound <= lower_bound) return false;

    const midpoint = lower_bound + ((upper_bound - lower_bound) / 2);

    if (current_price == midpoint) return false;

    const drift_cents: i64 = @as(i64, @intCast(current_price)) - @as(i64, @intCast(midpoint));
    const abs_drift = @abs(drift_cents);

    const drift_pct = @as(u64, @intCast(abs_drift * 10000)) / @as(u64, midpoint);

    return drift_pct > @as(u64, trigger_pct);
}

/// Calculate new grid bounds after rebalancing
/// If price drifted up: shift grid up by step * shift_count
/// If price drifted down: shift grid down
pub fn calcRebalancedBounds(current_price: u64, lower_bound: u64, upper_bound: u64, step_cents: u64) struct { lower: u64, upper: u64 } {
    const mid_price = lower_bound + ((upper_bound - lower_bound) / 2);

    if (current_price > mid_price) {
        // Price drifted up: shift grid up
        const shift = current_price - mid_price;
        const steps = shift / step_cents;
        const shift_amount = steps * step_cents;

        return .{
            .lower = lower_bound + shift_amount,
            .upper = upper_bound + shift_amount,
        };
    } else if (current_price < mid_price) {
        // Price drifted down: shift grid down
        const shift = mid_price - current_price;
        const steps = shift / step_cents;
        const shift_amount = steps * step_cents;

        if (shift_amount > lower_bound) {
            // Prevent underflow
            return .{ .lower = 0, .upper = upper_bound - shift_amount };
        }

        return .{
            .lower = lower_bound - shift_amount,
            .upper = upper_bound - shift_amount,
        };
    }

    // No drift needed
    return .{ .lower = lower_bound, .upper = upper_bound };
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Scale down value by divisor, rounding down (floor division)
pub fn scaleDown(value: u64, divisor: u64) u64 {
    if (divisor == 0) return 0;
    return value / divisor;
}

/// Scale up value by multiplier with overflow check
pub fn scaleUp(value: u64, multiplier: u64) ?u64 {
    // Check for overflow
    if (multiplier > 0 and value > (18446744073709551615 / multiplier)) {
        return null; // Overflow
    }
    return value * multiplier;
}

/// Convert fixed-point cents to price with decimals (for debug output)
/// E.g., 6350000 cents → "63500.00" USD
pub fn centsToPrice(cents: u64) struct { dollars: u64, cents_frac: u32 } {
    return .{
        .dollars = cents / 100,
        .cents_frac = @as(u32, @intCast(cents % 100)),
    };
}
