// grid.zig — Grid level generation and management
// Generates buy/sell levels at regular price intervals
// All prices in cents (× 100)

const types = @import("types.zig");
const math = @import("math.zig");
const feed_reader = @import("feed_reader.zig");

// ============================================================================
// Grid Generation
// ============================================================================

/// Calculate number of buy levels that fit between current_price and lower_bound
fn calcBuyLevelCount(current_price: u64, lower_bound: u64, step_cents: u64) u32 {
    if (current_price <= lower_bound or step_cents == 0) return 0;

    const spread = current_price - lower_bound;
    return @as(u32, @intCast(@min(spread / step_cents, types.MAX_LEVELS / 2)));
}

/// Calculate number of sell levels that fit between current_price and upper_bound
fn calcSellLevelCount(current_price: u64, upper_bound: u64, step_cents: u64) u32 {
    if (current_price >= upper_bound or step_cents == 0) return 0;

    const spread = upper_bound - current_price;
    return @as(u32, @intCast(@min(spread / step_cents, types.MAX_LEVELS / 2)));
}

/// Get pointer to grid level array at 0x110040
fn getLevelBase() [*]volatile types.GridLevel {
    return @as([*]volatile types.GridLevel, @ptrFromInt(types.GRID_BASE + types.GRIDLEVEL_OFFSET));
}

/// Generate buy levels and write to array
/// Prices stored from highest (closest) to lowest (furthest)
fn generateBuyLevels(
    current_price: u64,
    lower_bound: u64,
    step_cents: u64,
    max_count: u32,
    out_levels: [*]volatile types.GridLevel,
) u32 {
    var count: u32 = 0;
    var price = current_price;

    while (count < max_count and price > lower_bound) {
        if (step_cents > price) break;

        price -= step_cents;
        if (price < lower_bound) break;

        out_levels[count] = .{
            .price_cents = price,
            .side = .buy,
            .status = .pending,
            .quantity_sats = 0, // Will be set by caller
            .order_id = 0xFFFFFFFF, // Unassigned
        };

        count += 1;
    }

    return count;
}

/// Generate sell levels and write to array
/// Prices stored from lowest (closest) to highest (furthest)
fn generateSellLevels(
    current_price: u64,
    upper_bound: u64,
    step_cents: u64,
    max_count: u32,
    out_levels: [*]volatile types.GridLevel,
    offset: u32,
) u32 {
    var count: u32 = 0;
    var price = current_price + step_cents;

    while (count < max_count and price < upper_bound) {
        out_levels[offset + count] = .{
            .price_cents = price,
            .side = .sell,
            .status = .pending,
            .quantity_sats = 0, // Will be set by caller
            .order_id = 0xFFFFFFFF, // Unassigned
        };

        count += 1;

        if (price > upper_bound - step_cents) break;
        price += step_cents;
    }

    return count;
}

// ============================================================================
// Public Grid Management API
// ============================================================================

/// Generate complete grid based on current price and bounds
/// Returns total number of levels created
pub fn calculateGrid(
    pair_id: u16,
    current_price: u64,
    lower_bound: u64,
    upper_bound: u64,
    step_cents: u64,
    quantity_per_level_sats: u64,
) u32 {
    // Validate inputs
    if (pair_id >= 64 or step_cents == 0) return 0;
    if (current_price < lower_bound or current_price > upper_bound) return 0;

    const levels = getLevelBase();
    var buy_count = calcBuyLevelCount(current_price, lower_bound, step_cents);
    var sell_count = calcSellLevelCount(current_price, upper_bound, step_cents);

    // Generate buy levels
    buy_count = generateBuyLevels(current_price, lower_bound, step_cents, buy_count, levels);

    // Generate sell levels (offset after buy levels)
    sell_count = generateSellLevels(current_price, upper_bound, step_cents, sell_count, levels, buy_count);

    // Set quantity for all levels
    const total_levels = buy_count + sell_count;
    var i: u32 = 0;
    while (i < total_levels) : (i += 1) {
        levels[i].quantity_sats = quantity_per_level_sats;
    }

    return total_levels;
}

/// Clear all grid levels (reset for rebalance)
pub fn clearGrid() void {
    const levels = getLevelBase();
    var i: u32 = 0;

    while (i < types.MAX_LEVELS) : (i += 1) {
        levels[i] = .{
            .price_cents = 0,
            .side = .buy,
            .status = .pending,
            .quantity_sats = 0,
            .order_id = 0xFFFFFFFF,
        };
    }
}

/// Get grid level by index
pub fn getLevel(index: u32) ?types.GridLevel {
    if (index >= types.MAX_LEVELS) return null;

    const levels = getLevelBase();
    const level = levels[index];

    if (level.price_cents == 0) return null;

    return level;
}

/// Check if a price level already exists in grid
pub fn levelExists(price_cents: u64, side: types.Side) bool {
    const levels = getLevelBase();
    var i: u32 = 0;

    while (i < types.MAX_LEVELS) : (i += 1) {
        const level = levels[i];
        if (level.price_cents == 0) break;

        if (level.price_cents == price_cents and level.side == side) {
            return true;
        }
    }

    return false;
}

/// Find next unfilled level (for order placement)
pub fn getNextPendingLevel(start_index: u32) ?struct { index: u32, level: types.GridLevel } {
    const levels = getLevelBase();
    var i = start_index;

    while (i < types.MAX_LEVELS) : (i += 1) {
        const level = levels[i];
        if (level.price_cents == 0) break;

        if (level.status == .pending) {
            return .{ .index = i, .level = level };
        }
    }

    return null;
}

/// Update level status after order execution
pub fn updateLevelStatus(index: u32, status: types.OrderStatus, order_id: u32) bool {
    if (index >= types.MAX_LEVELS) return false;

    const levels = getLevelBase();
    const level = &levels[index];

    if (level.price_cents == 0) return false;

    level.status = status;
    level.order_id = order_id;

    return true;
}

/// Count active levels (non-zero price)
pub fn countActiveLevels() u32 {
    const levels = getLevelBase();
    var count: u32 = 0;

    while (count < types.MAX_LEVELS) {
        if (levels[count].price_cents == 0) break;
        count += 1;
    }

    return count;
}

// ============================================================================
// Grid Analysis & Diagnostics
// ============================================================================

/// Calculate grid center price (midpoint of bounds)
pub fn getGridCenter(lower_bound: u64, upper_bound: u64) u64 {
    return lower_bound + ((upper_bound - lower_bound) / 2);
}

/// Check if current price is within grid bounds
pub fn isPriceInGrid(price: u64, lower_bound: u64, upper_bound: u64) bool {
    return price >= lower_bound and price <= upper_bound;
}

/// Count levels by side
pub fn countByLevel(side: types.Side) u32 {
    const levels = getLevelBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_LEVELS) : (i += 1) {
        if (levels[i].price_cents == 0) break;

        if (levels[i].side == side) {
            count += 1;
        }
    }

    return count;
}

/// Get total quantity committed to grid
pub fn getTotalQuantity() u64 {
    const levels = getLevelBase();
    var total: u64 = 0;

    var i: u32 = 0;
    while (i < types.MAX_LEVELS) : (i += 1) {
        if (levels[i].price_cents == 0) break;

        total += levels[i].quantity_sats;
    }

    return total;
}
