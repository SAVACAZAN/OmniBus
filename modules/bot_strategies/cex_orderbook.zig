// CEX OrderBook – Centralized Exchange order tracking
// Represents actual orders placed on Kraken, LCX, Coinbase
// Syncs with venue APIs, tracks fills from market data

const std = @import("std");

// ============================================================================
// CEX ORDER TYPES
// ============================================================================

pub const CexId = enum(u8) {
    KRAKEN = 0,
    LCX = 1,
    COINBASE = 2,
};

pub const CexOrderStatus = enum(u8) {
    PENDING = 0,       // Awaiting confirmation from CEX
    OPEN = 1,          // Active on CEX orderbook
    PARTIALLY_FILLED = 2,
    FILLED = 3,
    CANCELLED = 4,
    EXPIRED = 5,
    REJECTED = 6,
};

pub const CexOrder = struct {
    local_order_id: u64,        // Reference to local orderbook
    cex_order_id: [32]u8,       // CEX-assigned order ID
    cex_order_id_len: u16,

    cex_id: CexId,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },

    price: i64,
    quantity: i64,
    filled_quantity: i64,
    avg_fill_price: i64,

    status: CexOrderStatus,

    submitted_at: u64,
    filled_at: u64 = 0,
    last_update: u64,

    fees_paid: i64 = 0,
    pnl: i64 = 0,
};

pub const CexOrderBookState = struct {
    orders: [2048]CexOrder = undefined,
    order_count: u32 = 0,

    // Per-exchange stats
    kraken_orders: u32 = 0,
    lcx_orders: u32 = 0,
    coinbase_orders: u32 = 0,

    total_submitted: u64 = 0,
    total_filled: u64 = 0,
    total_cancelled: u64 = 0,

    total_volume: i64 = 0,
    total_fees: i64 = 0,
    realized_pnl: i64 = 0,
};

// ============================================================================
// ORDER PLACEMENT
// ============================================================================

/// Add new CEX order (after venue API confirms)
pub fn add_order(
    cob: *CexOrderBookState,
    local_order_id: u64,
    cex_id: CexId,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    timestamp: u64,
) bool {
    if (cob.order_count >= 2048) return false;

    cob.orders[cob.order_count] = .{
        .local_order_id = local_order_id,
        .cex_order_id = cex_order_id,
        .cex_order_id_len = cex_order_id_len,
        .cex_id = cex_id,
        .symbol = symbol,
        .side = side,
        .order_type = order_type,
        .price = price,
        .quantity = quantity,
        .filled_quantity = 0,
        .avg_fill_price = 0,
        .status = .PENDING,
        .submitted_at = timestamp,
        .filled_at = 0,
        .last_update = timestamp,
        .fees_paid = 0,
        .pnl = 0,
    };

    cob.order_count += 1;
    cob.total_submitted += 1;
    cob.total_volume += price * quantity;

    switch (cex_id) {
        .KRAKEN => cob.kraken_orders += 1,
        .LCX => cob.lcx_orders += 1,
        .COINBASE => cob.coinbase_orders += 1,
    }

    return true;
}

// ============================================================================
// ORDER UPDATES FROM VENUE
// ============================================================================

/// Update order status from CEX API
pub fn update_status(
    cob: *CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    new_status: CexOrderStatus,
    timestamp: u64,
) bool {
    if (find_order_mut(cob, cex_order_id, cex_order_id_len)) |order| {
        order.status = new_status;
        order.last_update = timestamp;
        return true;
    }
    return false;
}

/// Record fill from venue (via API or market data)
pub fn record_fill(
    cob: *CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    fill_qty: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    if (find_order_mut(cob, cex_order_id, cex_order_id_len)) |order| {
        order.filled_quantity += fill_qty;

        // Update average fill price
        if (order.filled_quantity > 0) {
            const total_cost = (order.avg_fill_price * (order.filled_quantity - fill_qty)) +
                (fill_price * fill_qty);
            order.avg_fill_price = total_cost / order.filled_quantity;
        }

        // Update status
        if (order.filled_quantity >= order.quantity) {
            order.status = .FILLED;
            order.filled_at = timestamp;
            cob.total_filled += 1;

            // Calculate P&L
            const cost = order.quantity * order.avg_fill_price;
            const revenue = order.quantity * fill_price;
            order.pnl = revenue - cost - order.fees_paid;
            cob.realized_pnl += order.pnl;
        } else {
            order.status = .PARTIALLY_FILLED;
        }

        order.last_update = timestamp;
        return true;
    }
    return false;
}

/// Cancel order
pub fn cancel_order(
    cob: *CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
) bool {
    if (find_order_mut(cob, cex_order_id, cex_order_id_len)) |order| {
        if (order.status != .FILLED and order.status != .CANCELLED) {
            order.status = .CANCELLED;
            cob.total_cancelled += 1;
            return true;
        }
    }
    return false;
}

/// Record trading fees
pub fn add_fees(
    cob: *CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    fee_amount: i64,
) bool {
    if (find_order_mut(cob, cex_order_id, cex_order_id_len)) |order| {
        order.fees_paid += fee_amount;
        cob.total_fees += fee_amount;
        return true;
    }
    return false;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_order_mut(
    cob: *CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
) ?*CexOrder {
    for (0..cob.order_count) |i| {
        if (cob.orders[i].cex_order_id_len == cex_order_id_len and
            std.mem.eql(u8,
                &cob.orders[i].cex_order_id[0..cex_order_id_len],
                &cex_order_id[0..cex_order_id_len])) {
            return &cob.orders[i];
        }
    }
    return null;
}

/// Get order by CEX ID
pub fn get_order(
    cob: *const CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
) ?*const CexOrder {
    for (0..cob.order_count) |i| {
        if (cob.orders[i].cex_order_id_len == cex_order_id_len and
            std.mem.eql(u8,
                &cob.orders[i].cex_order_id[0..cex_order_id_len],
                &cex_order_id[0..cex_order_id_len])) {
            return &cob.orders[i];
        }
    }
    return null;
}

/// Get active orders on exchange
pub fn get_active_orders(
    cob: *const CexOrderBookState,
    cex_id: CexId,
    symbol: [16]u8,
) u32 {
    var count: u32 = 0;
    for (0..cob.order_count) |i| {
        const order = &cob.orders[i];
        if (order.cex_id == cex_id and
            std.mem.eql(u8, &order.symbol, &symbol) and
            (order.status == .OPEN or order.status == .PARTIALLY_FILLED)) {
            count += 1;
        }
    }
    return count;
}

/// Get statistics
pub fn get_stats(cob: *const CexOrderBookState) struct {
    total_submitted: u64,
    total_filled: u64,
    total_cancelled: u64,
    kraken_orders: u32,
    lcx_orders: u32,
    coinbase_orders: u32,
    total_volume: i64,
    total_fees: i64,
    realized_pnl: i64,
} {
    return .{
        .total_submitted = cob.total_submitted,
        .total_filled = cob.total_filled,
        .total_cancelled = cob.total_cancelled,
        .kraken_orders = cob.kraken_orders,
        .lcx_orders = cob.lcx_orders,
        .coinbase_orders = cob.coinbase_orders,
        .total_volume = cob.total_volume,
        .total_fees = cob.total_fees,
        .realized_pnl = cob.realized_pnl,
    };
}
