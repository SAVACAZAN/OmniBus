// Unified Orderbook – CEX + DEX + Local orders in single state machine
// Extends orderbook_local.zig with DEX (Uniswap, Hyperliquid) support
// Single source of truth for all trading activity across venues

const std = @import("std");
const orderbook_local = @import("orderbook_local.zig");

// ============================================================================
// UNIFIED ORDER TYPES
// ============================================================================

pub const VenueType = enum(u8) {
    LOCAL = 0,          // Local tracking only
    CEX_KRAKEN = 1,
    CEX_LCX = 2,
    CEX_COINBASE = 3,
    DEX_UNISWAP_V3 = 4,
    DEX_UNISWAP_V4 = 5,
    DEX_HYPERLIQUID = 6,
};

pub const UnifiedOrderStatus = enum(u8) {
    NEW = 0,           // Created locally
    PENDING_SUBMIT = 1, // Waiting to send to venue
    SUBMITTED = 2,      // Sent (CEX/DEX API call made)
    ACTIVE = 3,        // Confirmed on venue
    PARTIALLY_FILLED = 4,
    FILLED = 5,        // 100% complete
    CANCELLED = 6,
    REJECTED = 7,
    EXPIRED = 8,
    ERROR = 9,
};

pub const UnifiedOrder = struct {
    order_id: u64,             // Local unique ID
    venue_id: u8,              // VenueType
    venue_order_id: [64]u8,    // CEX/blockchain order ID
    venue_order_id_len: u16,
    tx_hash: [64]u8,           // DEX: transaction hash
    tx_hash_len: u16,

    symbol: [16]u8,            // "BTC/USD" or "ETH"
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },

    price: i64,                // Fixed-point price
    quantity: i64,             // Original quantity
    filled_quantity: i64,      // How much filled
    avg_fill_price: i64,       // Average fill price

    status: UnifiedOrderStatus,

    created_at: u64,
    submitted_at: u64,
    filled_at: u64,

    fees_paid: i64,            // CEX: trading fees, DEX: gas costs
    pnl: i64,                  // Realized P&L

    // DEX-specific fields
    slippage_actual: i64,      // Actual slippage (0.5% = 50)
    gas_used: u64,             // Gas units (DEX)

    // Metadata
    strategy_id: u32,          // Which strategy placed this
    chain_id: u32,             // 1=Eth, 42161=Arb, 10=Opt (for DEX)
};

// ============================================================================
// UNIFIED ORDERBOOK STATE
// ============================================================================

pub const UnifiedOrderBookState = struct {
    // Local orderbook reference
    local_ob: *orderbook_local.OrderBookState,

    // DEX order tracking (separate from CEX)
    dex_orders: [2048]UnifiedOrder = undefined,
    dex_order_count: u32 = 0,

    // Cross-venue stats
    total_orders_placed: u64 = 0,
    total_filled: u64 = 0,
    total_cancelled: u64 = 0,
    total_cex_volume_usd: u64 = 0,
    total_dex_volume_usd: u64 = 0,
    total_fees_paid: i64 = 0,
    total_gas_paid: i64 = 0,
    realized_pnl: i64 = 0,

    // Venue-specific stats
    venue_stats: [7]struct {
        orders_count: u32,
        filled_count: u32,
        cancelled_count: u32,
        volume_usd: u64,
        fees_paid: i64,
    } = undefined,
};

/// Initialize unified orderbook
pub fn init_unified_orderbook(
    local_ob: *orderbook_local.OrderBookState,
) UnifiedOrderBookState {
    return .{
        .local_ob = local_ob,
        .dex_order_count = 0,
    };
}

// ============================================================================
// CEX ORDERS (delegated to local orderbook)
// ============================================================================

/// Create CEX order via local orderbook
pub fn create_cex_order(
    uob: *UnifiedOrderBookState,
    cex_id: u8,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    const order_id = orderbook_local.create_order(
        uob.local_ob,
        cex_id,
        symbol,
        side,
        order_type,
        price,
        quantity,
        timestamp,
    );

    if (order_id > 0) {
        uob.total_orders_placed += 1;
        uob.venue_stats[cex_id].orders_count += 1;
    }

    return order_id;
}

/// Record CEX fill via local orderbook
pub fn record_cex_fill(
    uob: *UnifiedOrderBookState,
    order_id: u64,
    fill_quantity: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    const success = orderbook_local.record_fill(
        uob.local_ob,
        order_id,
        fill_quantity,
        fill_price,
        timestamp,
    );

    if (success) {
        uob.total_filled += 1;
        const cex_id = 0; // TODO: lookup actual CEX ID
        uob.venue_stats[cex_id].filled_count += 1;
    }

    return success;
}

// ============================================================================
// DEX ORDERS (new unified tracking)
// ============================================================================

/// Create DEX order (Uniswap swap or Hyperliquid limit)
pub fn create_dex_order(
    uob: *UnifiedOrderBookState,
    venue_id: VenueType,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    quantity: i64,
    price: i64,
    chain_id: u32,
    strategy_id: u32,
    timestamp: u64,
) u64 {
    if (uob.dex_order_count >= 2048) return 0;

    const order_id = @as(u64, @intCast(uob.dex_order_count)) + 100000; // Offset to avoid collision with CEX IDs

    uob.dex_orders[uob.dex_order_count] = .{
        .order_id = order_id,
        .venue_id = @intFromEnum(venue_id),
        .venue_order_id = .{0} ** 64,
        .venue_order_id_len = 0,
        .tx_hash = .{0} ** 64,
        .tx_hash_len = 0,
        .symbol = symbol,
        .side = side,
        .order_type = .LIMIT,
        .price = price,
        .quantity = quantity,
        .filled_quantity = 0,
        .avg_fill_price = 0,
        .status = .NEW,
        .created_at = timestamp,
        .submitted_at = 0,
        .filled_at = 0,
        .fees_paid = 0,
        .pnl = 0,
        .slippage_actual = 0,
        .gas_used = 0,
        .strategy_id = strategy_id,
        .chain_id = chain_id,
    };

    uob.dex_order_count += 1;
    uob.total_orders_placed += 1;

    const venue_idx = @intFromEnum(venue_id);
    if (venue_idx < 7) {
        uob.venue_stats[venue_idx].orders_count += 1;
    }

    return order_id;
}

/// Submit DEX order (to blockchain or API)
pub fn submit_dex_order(
    uob: *UnifiedOrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    // Find order in dex_orders array
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].order_id == order_id) {
            uob.dex_orders[i].status = .PENDING_SUBMIT;
            uob.dex_orders[i].submitted_at = timestamp;
            return true;
        }
    }
    return false;
}

/// Record DEX fill (from blockchain or API event)
pub fn record_dex_fill(
    uob: *UnifiedOrderBookState,
    order_id: u64,
    fill_quantity: i64,
    fill_price: i64,
    gas_cost: i64,
    timestamp: u64,
) bool {
    // Find order
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].order_id == order_id) {
            var order = &uob.dex_orders[i];

            // Update fill info
            order.filled_quantity += fill_quantity;
            order.fees_paid += gas_cost;
            order.gas_used += @as(u64, @intCast(gas_cost));
            order.filled_at = timestamp;

            // Update average fill price
            if (order.filled_quantity > 0) {
                const total_cost = (order.avg_fill_price * (order.filled_quantity - fill_quantity)) + (fill_price * fill_quantity);
                order.avg_fill_price = total_cost / order.filled_quantity;
            }

            // Update status
            if (order.filled_quantity >= order.quantity) {
                order.status = .FILLED;

                // Calculate P&L
                const cost = order.quantity * order.avg_fill_price;
                const revenue = order.quantity * fill_price;
                order.pnl = revenue - cost - order.fees_paid;

                uob.total_filled += 1;
                const venue_idx = order.venue_id;
                if (venue_idx < 7) {
                    uob.venue_stats[venue_idx].filled_count += 1;
                }
            } else {
                order.status = .PARTIALLY_FILLED;
            }

            // Update global stats
            uob.total_fees_paid += gas_cost;
            uob.realized_pnl += order.pnl;

            return true;
        }
    }
    return false;
}

/// Cancel DEX order
pub fn cancel_dex_order(
    uob: *UnifiedOrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].order_id == order_id) {
            uob.dex_orders[i].status = .CANCELLED;

            uob.total_cancelled += 1;
            const venue_idx = uob.dex_orders[i].venue_id;
            if (venue_idx < 7) {
                uob.venue_stats[venue_idx].cancelled_count += 1;
            }

            _ = timestamp;
            return true;
        }
    }
    return false;
}

/// Link DEX transaction hash to order
pub fn set_dex_tx_hash(
    uob: *UnifiedOrderBookState,
    order_id: u64,
    tx_hash: [64]u8,
    tx_hash_len: u16,
) bool {
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].order_id == order_id) {
            uob.dex_orders[i].tx_hash = tx_hash;
            uob.dex_orders[i].tx_hash_len = tx_hash_len;
            uob.dex_orders[i].status = .SUBMITTED;
            return true;
        }
    }
    return false;
}

// ============================================================================
// CROSS-VENUE QUERIES
// ============================================================================

/// Get total position across all venues (CEX + DEX)
pub fn get_total_position(
    uob: *const UnifiedOrderBookState,
    symbol: [16]u8,
) i64 {
    var total: i64 = 0;

    // Add CEX positions from local orderbook
    // (would need to extract this from local_ob)

    // Add DEX positions
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].status == .FILLED and
            std.mem.eql(u8, &uob.dex_orders[i].symbol, &symbol)) {

            const qty = if (uob.dex_orders[i].side == .BUY)
                uob.dex_orders[i].filled_quantity
            else
                -uob.dex_orders[i].filled_quantity;

            total += qty;
        }
    }

    return total;
}

/// Get average entry price across all filled orders
pub fn get_avg_entry_price(
    uob: *const UnifiedOrderBookState,
    symbol: [16]u8,
) i64 {
    var total_cost: i64 = 0;
    var total_qty: i64 = 0;

    // Scan DEX orders
    for (0..uob.dex_order_count) |i| {
        if (uob.dex_orders[i].status == .FILLED and
            std.mem.eql(u8, &uob.dex_orders[i].symbol, &symbol) and
            uob.dex_orders[i].side == .BUY) {

            total_cost += uob.dex_orders[i].avg_fill_price * uob.dex_orders[i].filled_quantity;
            total_qty += uob.dex_orders[i].filled_quantity;
        }
    }

    if (total_qty > 0) {
        return total_cost / total_qty;
    }
    return 0;
}

/// Get combined P&L across all venues
pub fn get_total_pnl(uob: *const UnifiedOrderBookState) struct {
    realized_pnl: i64,
    total_fees: i64,
    total_gas: i64,
} {
    return .{
        .realized_pnl = uob.realized_pnl,
        .total_fees = uob.total_fees_paid,
        .total_gas = uob.total_gas_paid,
    };
}

/// Get venue breakdown
pub fn get_venue_summary(
    uob: *const UnifiedOrderBookState,
) [7]struct {
    venue_name: [16]u8,
    orders: u32,
    filled: u32,
    cancelled: u32,
    volume: u64,
    fees: i64,
} {
    var summary: [7]struct {
        venue_name: [16]u8,
        orders: u32,
        filled: u32,
        cancelled: u32,
        volume: u64,
        fees: i64,
    } = undefined;

    var venue_names: [7][16]u8 = undefined;
    _ = std.fmt.bufPrint(&venue_names[0], "LOCAL", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[1], "CEX_KRAKEN", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[2], "CEX_LCX", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[3], "CEX_COINBASE", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[4], "DEX_UNISWAP_V3", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[5], "DEX_UNISWAP_V4", .{}) catch {};
    _ = std.fmt.bufPrint(&venue_names[6], "DEX_HYPERLIQUID", .{}) catch {};

    for (0..7) |i| {
        summary[i] = .{
            .venue_name = venue_names[i],
            .orders = uob.venue_stats[i].orders_count,
            .filled = uob.venue_stats[i].filled_count,
            .cancelled = uob.venue_stats[i].cancelled_count,
            .volume = uob.venue_stats[i].volume_usd,
            .fees = uob.venue_stats[i].fees_paid,
        };
    }

    return summary;
}
