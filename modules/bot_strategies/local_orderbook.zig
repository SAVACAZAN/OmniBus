// Local OrderBook – Private OmniBus order tracking (in-memory only)
// Single source of truth for all orders created locally before venue submission
// No external API calls - pure state management for order lifecycle

const std = @import("std");

// ============================================================================
// LOCAL ORDER TRACKING
// ============================================================================

pub const LocalOrderStatus = enum(u8) {
    NEW = 0,           // Created locally, not yet submitted
    PENDING_SUBMIT = 1, // Queued for submission to venue
    SUBMITTED = 2,     // Sent to CEX/DEX API
    ACTIVE = 3,        // Confirmed on venue
    PARTIALLY_FILLED = 4,
    FILLED = 5,
    CANCELLED = 6,
    REJECTED = 7,
    EXPIRED = 8,
};

pub const LocalOrder = struct {
    order_id: u64,              // Local unique ID (1, 2, 3, ...)
    symbol: [16]u8,             // "BTC/USD", "ETH", etc.
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },

    price: i64,                 // Fixed-point price
    quantity: i64,              // Original quantity ordered
    filled_quantity: i64,       // How much has been filled so far
    avg_fill_price: i64,        // Average price of filled portion

    status: LocalOrderStatus,

    created_at: u64,            // When order was created locally
    submitted_at: u64 = 0,      // When sent to venue
    filled_at: u64 = 0,         // When fully filled

    fees_paid: i64 = 0,         // Accumulated fees/costs
    pnl: i64 = 0,               // Realized profit/loss
};

pub const LocalOrderBookState = struct {
    orders: [4096]LocalOrder = undefined,
    order_count: u32 = 0,

    // Statistics
    total_created: u64 = 0,
    total_submitted: u64 = 0,
    total_filled: u64 = 0,
    total_cancelled: u64 = 0,

    total_volume: i64 = 0,      // Sum of all (price * quantity)
    total_fees: i64 = 0,
    realized_pnl: i64 = 0,
};

// ============================================================================
// ORDER CREATION
// ============================================================================

/// Create new local order (no venue interaction)
pub fn create_order(
    lob: *LocalOrderBookState,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    if (lob.order_count >= 4096) return 0;

    const order_id = @as(u64, @intCast(lob.order_count)) + 1;

    lob.orders[lob.order_count] = .{
        .order_id = order_id,
        .symbol = symbol,
        .side = side,
        .order_type = order_type,
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
    };

    lob.order_count += 1;
    lob.total_created += 1;
    lob.total_volume += price * quantity;

    return order_id;
}

// ============================================================================
// ORDER STATE TRANSITIONS
// ============================================================================

/// Mark order as ready to submit to venue
pub fn mark_pending_submit(
    lob: *LocalOrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    _ = timestamp;
    if (find_order_mut(lob, order_id)) |order| {
        if (order.status == .NEW) {
            order.status = .PENDING_SUBMIT;
            return true;
        }
    }
    return false;
}

/// Record that order was submitted to venue
pub fn mark_submitted(
    lob: *LocalOrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        if (order.status == .PENDING_SUBMIT or order.status == .NEW) {
            order.status = .SUBMITTED;
            order.submitted_at = timestamp;
            lob.total_submitted += 1;
            return true;
        }
    }
    return false;
}

/// Mark order as confirmed on venue
pub fn mark_active(
    lob: *LocalOrderBookState,
    order_id: u64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        if (order.status == .SUBMITTED) {
            order.status = .ACTIVE;
            return true;
        }
    }
    return false;
}

/// Record a partial or full fill
pub fn record_fill(
    lob: *LocalOrderBookState,
    order_id: u64,
    fill_qty: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        // Update filled quantity
        const old_filled = order.filled_quantity;
        order.filled_quantity += fill_qty;

        // Update average fill price
        if (order.filled_quantity > 0) {
            const total_cost = (order.avg_fill_price * old_filled) + (fill_price * fill_qty);
            order.avg_fill_price = total_cost / order.filled_quantity;
        }

        // Update status
        if (order.filled_quantity >= order.quantity) {
            order.status = .FILLED;
            order.filled_at = timestamp;
            lob.total_filled += 1;

            // Calculate realized P&L
            const cost = order.quantity * order.avg_fill_price;
            const revenue = order.quantity * fill_price;
            order.pnl = revenue - cost - order.fees_paid;
            lob.realized_pnl += order.pnl;
        } else {
            order.status = .PARTIALLY_FILLED;
        }

        return true;
    }
    return false;
}

/// Cancel order
pub fn cancel_order(
    lob: *LocalOrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        if (order.status == .NEW or order.status == .PENDING_SUBMIT or
            order.status == .SUBMITTED or order.status == .ACTIVE) {
            order.status = .CANCELLED;
            lob.total_cancelled += 1;
            return true;
        }
    }
    _ = timestamp;
    return false;
}

/// Reject order (venue rejected it)
pub fn reject_order(
    lob: *LocalOrderBookState,
    order_id: u64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        order.status = .REJECTED;
        return true;
    }
    return false;
}

/// Record fees paid
pub fn add_fees(
    lob: *LocalOrderBookState,
    order_id: u64,
    fee_amount: i64,
) bool {
    if (find_order_mut(lob, order_id)) |order| {
        order.fees_paid += fee_amount;
        lob.total_fees += fee_amount;
        return true;
    }
    return false;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_order_mut(lob: *LocalOrderBookState, order_id: u64) ?*LocalOrder {
    for (0..lob.order_count) |i| {
        if (lob.orders[i].order_id == order_id) {
            return &lob.orders[i];
        }
    }
    return null;
}

fn find_order(lob: *const LocalOrderBookState, order_id: u64) ?*const LocalOrder {
    for (0..lob.order_count) |i| {
        if (lob.orders[i].order_id == order_id) {
            return &lob.orders[i];
        }
    }
    return null;
}

/// Get specific order
pub fn get_order(lob: *const LocalOrderBookState, order_id: u64) ?*const LocalOrder {
    return find_order(lob, order_id);
}

/// Get best bid among unfilled orders
pub fn get_best_bid(lob: *const LocalOrderBookState, symbol: [16]u8) i64 {
    var best: i64 = 0;
    for (0..lob.order_count) |i| {
        const order = &lob.orders[i];
        if (std.mem.eql(u8, &order.symbol, &symbol) and
            order.side == .BUY and
            order.status != .FILLED and
            order.status != .CANCELLED) {
            if (order.price > best) {
                best = order.price;
            }
        }
    }
    return best;
}

/// Get best ask among unfilled orders
pub fn get_best_ask(lob: *const LocalOrderBookState, symbol: [16]u8) i64 {
    var best: i64 = std.math.maxInt(i64);
    for (0..lob.order_count) |i| {
        const order = &lob.orders[i];
        if (std.mem.eql(u8, &order.symbol, &symbol) and
            order.side == .SELL and
            order.status != .FILLED and
            order.status != .CANCELLED) {
            if (order.price < best) {
                best = order.price;
            }
        }
    }
    return if (best == std.math.maxInt(i64)) 0 else best;
}

/// Get mid price (average of bid/ask)
pub fn get_mid_price(lob: *const LocalOrderBookState, symbol: [16]u8) i64 {
    const bid = get_best_bid(lob, symbol);
    const ask = get_best_ask(lob, symbol);
    if (bid > 0 and ask > 0) {
        return (bid + ask) / 2;
    }
    return 0;
}

/// Get total position in symbol (sum of filled buy orders - sell orders)
pub fn get_position(lob: *const LocalOrderBookState, symbol: [16]u8) i64 {
    var position: i64 = 0;
    for (0..lob.order_count) |i| {
        const order = &lob.orders[i];
        if (std.mem.eql(u8, &order.symbol, &symbol) and order.status == .FILLED) {
            const qty = if (order.side == .BUY)
                order.filled_quantity
            else
                -order.filled_quantity;
            position += qty;
        }
    }
    return position;
}

/// Get statistics
pub fn get_stats(lob: *const LocalOrderBookState) struct {
    total_created: u64,
    total_submitted: u64,
    total_filled: u64,
    total_cancelled: u64,
    total_volume: i64,
    total_fees: i64,
    realized_pnl: i64,
    pending_orders: u32,
} {
    var pending: u32 = 0;
    for (0..lob.order_count) |i| {
        const status = lob.orders[i].status;
        if (status != .FILLED and status != .CANCELLED and status != .REJECTED) {
            pending += 1;
        }
    }

    return .{
        .total_created = lob.total_created,
        .total_submitted = lob.total_submitted,
        .total_filled = lob.total_filled,
        .total_cancelled = lob.total_cancelled,
        .total_volume = lob.total_volume,
        .total_fees = lob.total_fees,
        .realized_pnl = lob.realized_pnl,
        .pending_orders = pending,
    };
}
