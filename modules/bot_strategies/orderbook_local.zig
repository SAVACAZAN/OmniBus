// Local OrderBook Manager
// Tracks all orders placed locally and on CEX
// Maintains order state, fills, and cancellations

const std = @import("std");
const bot = @import("bot_strategies.zig");

// ============================================================================
// ORDER BOOK STRUCTURES
// ============================================================================

pub const OrderStatus = enum {
    NEW,                // Just created, not yet sent
    PENDING_SUBMIT,     // Waiting to be sent to CEX
    SUBMITTED,          // Sent to CEX, awaiting confirmation
    ACTIVE,             // Confirmed active on CEX orderbook
    PARTIALLY_FILLED,   // Partially filled
    FILLED,             // Completely filled
    CANCELLED,          // User cancelled
    REJECTED,           // CEX rejected
    EXPIRED,            // Order timeout
};

pub const LocalOrder = struct {
    order_id: u64,              // Local unique ID
    cex_order_id: [32]u8,       // CEX order ID (e.g., Kraken order_txid)
    cex_id: u8,                 // 0=Kraken, 1=LCX, 2=Coinbase
    symbol: [16]u8,             // Pair (e.g., "XBTUSDT\0\0")
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,                 // Fixed-point price
    quantity: i64,              // Amount to trade
    filled_quantity: i64,       // How much filled so far
    avg_fill_price: i64,        // Average price of fills
    status: OrderStatus,
    created_at: u64,            // Timestamp created
    submitted_at: u64,          // Timestamp sent to CEX
    filled_at: u64,             // Timestamp when filled
    fees_paid: i64,             // Trading fees paid
    pnl: i64,                   // Realized P&L if closed
};

pub const OrderBookState = struct {
    orders: [4096]LocalOrder,
    order_count: u16,
    next_order_id: u64,

    // Book aggregation
    buy_orders: [512]u64,       // Order IDs of active buys
    buy_count: u16,
    sell_orders: [512]u64,      // Order IDs of active sells
    sell_count: u16,

    // Statistics
    total_orders_placed: u32,
    total_orders_filled: u32,
    total_fees: i64,
    total_pnl: i64,
};

pub const OrderbookStats = struct {
    total_orders: u16,
    active_orders: u16,
    pending_orders: u16,
    filled_orders: u32,
    total_volume_usd: i64,
    total_fees_paid: i64,
    realized_pnl: i64,
    avg_fill_price: i64,
};

// ============================================================================
// ORDER CREATION & SUBMISSION
// ============================================================================

/// Create a new local order
pub fn create_order(
    orderbook: *OrderBookState,
    cex_id: u8,                 // 0=Kraken, 1=LCX, 2=Coinbase
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    if (orderbook.order_count >= 4096) return 0; // Overflow

    const order_id = orderbook.next_order_id;
    orderbook.next_order_id += 1;

    const order: LocalOrder = .{
        .order_id = order_id,
        .cex_order_id = .{0} ** 32,
        .cex_id = cex_id,
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

    orderbook.orders[orderbook.order_count] = order;
    orderbook.order_count += 1;
    orderbook.total_orders_placed += 1;

    return order_id;
}

/// Find order by ID
pub fn find_order(orderbook: *OrderBookState, order_id: u64) ?*LocalOrder {
    for (0..orderbook.order_count) |i| {
        if (orderbook.orders[i].order_id == order_id) {
            return &orderbook.orders[i];
        }
    }
    return null;
}

/// Submit order to CEX (mark as PENDING_SUBMIT)
pub fn submit_order(
    orderbook: *OrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    if (find_order(orderbook, order_id)) |order| {
        if (order.status == .NEW) {
            order.status = .PENDING_SUBMIT;
            order.submitted_at = timestamp;
            return true;
        }
    }
    return false;
}

// ============================================================================
// ORDER FILL TRACKING
// ============================================================================

/// Record a fill for an order
pub fn record_fill(
    orderbook: *OrderBookState,
    order_id: u64,
    fill_quantity: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    if (find_order(orderbook, order_id)) |order| {
        const prev_filled = order.filled_quantity;
        order.filled_quantity += fill_quantity;

        // Update average fill price (weighted)
        if (prev_filled == 0) {
            order.avg_fill_price = fill_price;
        } else {
            order.avg_fill_price = (
                (order.avg_fill_price * prev_filled) +
                (fill_price * fill_quantity)
            ) / order.filled_quantity;
        }

        // Update status
        if (order.filled_quantity >= order.quantity) {
            order.status = .FILLED;
            order.filled_at = timestamp;
            orderbook.total_orders_filled += 1;
        } else if (order.filled_quantity > 0) {
            order.status = .PARTIALLY_FILLED;
        }

        return true;
    }
    return false;
}

/// Set CEX order ID for tracking
pub fn set_cex_order_id(
    orderbook: *OrderBookState,
    order_id: u64,
    cex_order_id: [32]u8,
) bool {
    if (find_order(orderbook, order_id)) |order| {
        order.cex_order_id = cex_order_id;
        order.status = .ACTIVE;
        return true;
    }
    return false;
}

/// Mark order as cancelled
pub fn cancel_order(
    orderbook: *OrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    if (find_order(orderbook, order_id)) |order| {
        if (order.status != .FILLED) {
            order.status = .CANCELLED;
            order.filled_at = timestamp;
            return true;
        }
    }
    return false;
}

/// Mark order as rejected by CEX
pub fn reject_order(
    orderbook: *OrderBookState,
    order_id: u64,
    timestamp: u64,
) bool {
    if (find_order(orderbook, order_id)) |order| {
        order.status = .REJECTED;
        order.filled_at = timestamp;
        return true;
    }
    return false;
}

// ============================================================================
// ORDER BOOK AGGREGATION
// ============================================================================

/// Rebuild active buy/sell order lists
pub fn rebuild_active_orders(orderbook: *OrderBookState) void {
    orderbook.buy_count = 0;
    orderbook.sell_count = 0;

    for (0..orderbook.order_count) |i| {
        const order = &orderbook.orders[i];

        if (order.status == .ACTIVE or order.status == .PARTIALLY_FILLED) {
            if (order.side == .BUY and orderbook.buy_count < 512) {
                orderbook.buy_orders[orderbook.buy_count] = order.order_id;
                orderbook.buy_count += 1;
            } else if (order.side == .SELL and orderbook.sell_count < 512) {
                orderbook.sell_orders[orderbook.sell_count] = order.order_id;
                orderbook.sell_count += 1;
            }
        }
    }
}

/// Get best bid (highest buy price)
pub fn get_best_bid(orderbook: *const OrderBookState) i64 {
    var best: i64 = 0;

    for (0..orderbook.order_count) |i| {
        const order = &orderbook.orders[i];
        if (order.side == .BUY and
            (order.status == .ACTIVE or order.status == .PARTIALLY_FILLED) and
            order.price > best) {
            best = order.price;
        }
    }

    return best;
}

/// Get best ask (lowest sell price)
pub fn get_best_ask(orderbook: *const OrderBookState) i64 {
    var best: i64 = 0x7FFFFFFFFFFFFFFF;

    for (0..orderbook.order_count) |i| {
        const order = &orderbook.orders[i];
        if (order.side == .SELL and
            (order.status == .ACTIVE or order.status == .PARTIALLY_FILLED) and
            order.price < best) {
            best = order.price;
        }
    }

    return if (best == 0x7FFFFFFFFFFFFFFF) 0 else best;
}

/// Calculate mid price
pub fn get_mid_price(orderbook: *const OrderBookState) i64 {
    const bid = get_best_bid(orderbook);
    const ask = get_best_ask(orderbook);

    if (bid == 0 or ask == 0) return 0;
    return (bid + ask) / 2;
}

// ============================================================================
// STATISTICS & REPORTING
// ============================================================================

pub fn get_orderbook_stats(orderbook: *const OrderBookState) OrderbookStats {
    var active = 0;
    var pending = 0;
    var total_volume: i64 = 0;
    var total_fees: i64 = 0;
    var total_pnl: i64 = 0;
    var total_filled_price: i64 = 0;
    var filled_count: u32 = 0;

    for (0..orderbook.order_count) |i| {
        const order = &orderbook.orders[i];

        if (order.status == .ACTIVE or order.status == .PARTIALLY_FILLED) {
            active += 1;
        } else if (order.status == .PENDING_SUBMIT) {
            pending += 1;
        }

        total_volume += order.quantity;
        total_fees += order.fees_paid;

        if (order.status == .FILLED) {
            total_pnl += order.pnl;
            total_filled_price += order.avg_fill_price;
            filled_count += 1;
        }
    }

    const avg_fill = if (filled_count > 0)
        total_filled_price / @as(i64, filled_count)
    else
        0;

    return .{
        .total_orders = orderbook.order_count,
        .active_orders = active,
        .pending_orders = pending,
        .filled_orders = orderbook.total_orders_filled,
        .total_volume_usd = total_volume,
        .total_fees_paid = total_fees,
        .realized_pnl = total_pnl,
        .avg_fill_price = avg_fill,
    };
}

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init_orderbook() OrderBookState {
    var ob: OrderBookState = .{
        .orders = undefined,
        .order_count = 0,
        .next_order_id = 1,
        .buy_orders = undefined,
        .buy_count = 0,
        .sell_orders = undefined,
        .sell_count = 0,
        .total_orders_placed = 0,
        .total_orders_filled = 0,
        .total_fees = 0,
        .total_pnl = 0,
    };

    // Initialize order array
    for (0..4096) |i| {
        ob.orders[i] = .{
            .order_id = 0,
            .cex_order_id = .{0} ** 32,
            .cex_id = 0,
            .symbol = .{0} ** 16,
            .side = .BUY,
            .order_type = .LIMIT,
            .price = 0,
            .quantity = 0,
            .filled_quantity = 0,
            .avg_fill_price = 0,
            .status = .NEW,
            .created_at = 0,
            .submitted_at = 0,
            .filled_at = 0,
            .fees_paid = 0,
            .pnl = 0,
        };
    }

    return ob;
}
