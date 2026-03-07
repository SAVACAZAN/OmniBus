// order.zig — Order state machine and lifecycle management
// Tracks orders from creation through fill and cancellation
// All prices in cents (× 100), sizes in satoshis (× 1e8)

const types = @import("types.zig");

// ============================================================================
// Order Array Access
// ============================================================================

/// Get pointer to order array at 0x110840
fn getOrderBase() [*]volatile types.Order {
    return @as([*]volatile types.Order, @ptrFromInt(types.GRID_BASE + types.ORDER_OFFSET));
}

/// Get mutable pointer to specific order
fn getOrder(index: u32) ?[*]volatile types.Order {
    if (index >= types.MAX_ORDERS) return null;

    const orders = getOrderBase();
    return &orders[index];
}

// ============================================================================
// Order Creation
// ============================================================================

/// Create new order from grid level
/// Returns order index if successful, null if order array is full
pub fn createOrder(
    exchange_id: u16,
    pair_id: u16,
    side: types.Side,
    price_cents: u64,
    quantity_sats: u64,
    order_id: u32,
) ?u32 {
    const orders = getOrderBase();

    // Find first unused slot
    var index: u32 = 0;
    while (index < types.MAX_ORDERS) : (index += 1) {
        const order = &orders[index];

        // Empty slot has zero price
        if (order.price_cents == 0) {
            order.* = .{
                .exchange_id = exchange_id,
                .pair_id = pair_id,
                .side = side,
                .status = .pending,
                .price_cents = price_cents,
                .quantity_sats = quantity_sats,
                .filled_sats = 0,
                .order_id = order_id,
                .tsc_created = rdtsc(),
                .tsc_filled = 0,
            };

            return index;
        }
    }

    return null; // Order array full
}

/// Create order from grid level struct
pub fn createFromLevel(
    exchange_id: u16,
    pair_id: u16,
    level: types.GridLevel,
) ?u32 {
    return createOrder(
        exchange_id,
        pair_id,
        level.side,
        level.price_cents,
        level.quantity_sats,
        level.order_id,
    );
}

// ============================================================================
// Order State Updates
// ============================================================================

/// Update order status
pub fn setStatus(order_index: u32, status: types.OrderStatus) bool {
    if (order_index >= types.MAX_ORDERS) return false;

    const orders = getOrderBase();
    orders[order_index].status = status;

    if (status == .filled) {
        orders[order_index].tsc_filled = rdtsc();
    }

    return true;
}

/// Partially fill order
pub fn partialFill(order_index: u32, filled_sats: u64) bool {
    if (order_index >= types.MAX_ORDERS) return false;

    const orders = getOrderBase();
    const order = &orders[order_index];

    if (order.filled_sats + filled_sats > order.quantity_sats) {
        return false; // Would exceed order quantity
    }

    order.filled_sats += filled_sats;

    // Check if fully filled
    if (order.filled_sats >= order.quantity_sats) {
        order.status = .filled;
        order.tsc_filled = rdtsc();
    }

    return true;
}

/// Completely fill order
pub fn completeFill(order_index: u32) bool {
    if (order_index >= types.MAX_ORDERS) return false;

    const orders = getOrderBase();
    const order = &orders[order_index];

    order.filled_sats = order.quantity_sats;
    order.status = .filled;
    order.tsc_filled = rdtsc();

    return true;
}

/// Cancel order (if not filled)
pub fn cancelOrder(order_index: u32) bool {
    if (order_index >= types.MAX_ORDERS) return false;

    const orders = getOrderBase();
    const order = &orders[order_index];

    if (order.status == .filled) return false; // Cannot cancel filled order

    order.status = .cancelled;
    order.price_cents = 0; // Mark slot as available

    return true;
}

// ============================================================================
// Order Queries
// ============================================================================

/// Get order by index
pub fn getOrderByIndex(index: u32) ?types.Order {
    if (index >= types.MAX_ORDERS) return null;

    const orders = getOrderBase();
    const order = orders[index];

    if (order.price_cents == 0) return null; // Empty slot

    return order;
}

/// Count total active orders
pub fn countActiveOrders() u32 {
    const orders = getOrderBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;
        count += 1;
    }

    return count;
}

/// Count orders by status
pub fn countByStatus(status: types.OrderStatus) u32 {
    const orders = getOrderBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;

        if (orders[i].status == status) {
            count += 1;
        }
    }

    return count;
}

/// Count orders by side
pub fn countBySide(side: types.Side) u32 {
    const orders = getOrderBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;

        if (orders[i].side == side) {
            count += 1;
        }
    }

    return count;
}

/// Count orders by exchange
pub fn countByExchange(exchange_id: u16) u32 {
    const orders = getOrderBase();
    var count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;

        if (orders[i].exchange_id == exchange_id) {
            count += 1;
        }
    }

    return count;
}

// ============================================================================
// Order Analysis
// ============================================================================

/// Get total quantity across all active orders
pub fn getTotalQuantity() u64 {
    const orders = getOrderBase();
    var total: u64 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;
        total += orders[i].quantity_sats;
    }

    return total;
}

/// Get total filled quantity across all orders
pub fn getTotalFilled() u64 {
    const orders = getOrderBase();
    var total: u64 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;
        total += orders[i].filled_sats;
    }

    return total;
}

/// Get total unfilled quantity
pub fn getTotalUnfilled() u64 {
    const orders = getOrderBase();
    var total: u64 = 0;

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        if (orders[i].price_cents == 0) break;

        const unfilled = orders[i].quantity_sats - orders[i].filled_sats;
        total += unfilled;
    }

    return total;
}

/// Calculate fill percentage for order (0-100)
pub fn getFillPercent(order_index: u32) u8 {
    if (order_index >= types.MAX_ORDERS) return 0;

    const orders = getOrderBase();
    const order = orders[order_index];

    if (order.quantity_sats == 0) return 0;

    return @as(u8, @intCast((order.filled_sats * 100) / order.quantity_sats));
}

/// Find first pending order for a pair
pub fn getFirstPendingForPair(pair_id: u16) ?u32 {
    const orders = getOrderBase();

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        const order = &orders[i];
        if (order.price_cents == 0) break;

        if (order.pair_id == pair_id and order.status == .pending) {
            return i;
        }
    }

    return null;
}

// ============================================================================
// Timing Utilities
// ============================================================================

/// Read current TSC (Time Stamp Counter)
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

/// Get order age in TSC cycles
pub fn getOrderAgeTsc(order_index: u32) u64 {
    if (order_index >= types.MAX_ORDERS) return 0;

    const orders = getOrderBase();
    const order = orders[order_index];
    const current_tsc = rdtsc();

    return if (current_tsc > order.tsc_created)
        current_tsc - order.tsc_created
    else
        0;
}

// ============================================================================
// Cleanup & Reset
// ============================================================================

/// Clear all orders (reset for new grid)
pub fn clearAll() void {
    const orders = getOrderBase();

    var i: u32 = 0;
    while (i < types.MAX_ORDERS) : (i += 1) {
        orders[i] = .{
            .exchange_id = 0,
            .pair_id = 0,
            .side = .buy,
            .status = .cancelled,
            .price_cents = 0,
            .quantity_sats = 0,
            .filled_sats = 0,
            .order_id = 0,
            .tsc_created = 0,
            .tsc_filled = 0,
        };
    }
}
