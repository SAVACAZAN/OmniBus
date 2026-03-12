// Order Router – Orchestrates order flow across 3 orderbook systems
// Pattern: LOCAL → CEX/DEX → UNIFIED tracking
// Single point of order creation and routing

const std = @import("std");
const local_ob = @import("local_orderbook.zig");
const cex_ob = @import("cex_orderbook.zig");
const dex_ob = @import("dex_orderbook.zig");

// ============================================================================
// ORDER ROUTING STATE
// ============================================================================

pub const OrderRouter = struct {
    local_orderbook: *local_ob.LocalOrderBookState,
    cex_orderbook: *cex_ob.CexOrderBookState,
    dex_orderbook: *dex_ob.DexOrderBookState,

    total_orders_routed: u64 = 0,
    total_to_cex: u64 = 0,
    total_to_dex: u64 = 0,
};

/// Initialize order router with references to all 3 orderbooks
pub fn init_router(
    lob: *local_ob.LocalOrderBookState,
    cob: *cex_ob.CexOrderBookState,
    dob: *dex_ob.DexOrderBookState,
) OrderRouter {
    return .{
        .local_orderbook = lob,
        .cex_orderbook = cob,
        .dex_orderbook = dob,
    };
}

// ============================================================================
// PLACE ORDER IN LOCAL (Step 1)
// ============================================================================

/// Create local order (private OmniBus tracking only)
pub fn place_local_order(
    router: *OrderRouter,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    const order_id = local_ob.create_order(
        router.local_orderbook,
        symbol,
        side,
        order_type,
        price,
        quantity,
        timestamp,
    );

    if (order_id > 0) {
        router.total_orders_routed += 1;
    }

    return order_id;
}

// ============================================================================
// ROUTE TO CEX (Step 2A)
// ============================================================================

/// Route order from LOCAL to CEX and submit
pub fn route_to_cex(
    router: *OrderRouter,
    local_order_id: u64,
    cex_id: cex_ob.CexId,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    timestamp: u64,
) bool {
    // Step 1: Mark local order as pending submit
    if (!local_ob.mark_pending_submit(router.local_orderbook, local_order_id, timestamp)) {
        return false;
    }

    // Step 2: Get local order details
    const local_order = local_ob.get_order(router.local_orderbook, local_order_id) orelse return false;

    // Step 3: Add to CEX orderbook
    const success = cex_ob.add_order(
        router.cex_orderbook,
        local_order_id,
        cex_id,
        local_order.symbol,
        local_order.side,
        local_order.order_type,
        local_order.price,
        local_order.quantity,
        cex_order_id,
        cex_order_id_len,
        timestamp,
    );

    if (success) {
        // Step 4: Mark local as submitted
        _ = local_ob.mark_submitted(router.local_orderbook, local_order_id, timestamp);
        router.total_to_cex += 1;
    }

    return success;
}

/// Sync CEX fill back to LOCAL
pub fn sync_cex_fill_to_local(
    router: *OrderRouter,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    fill_qty: i64,
    fill_price: i64,
    timestamp: u64,
) bool {
    // Step 1: Record in CEX orderbook
    const cex_fill_ok = cex_ob.record_fill(
        router.cex_orderbook,
        cex_order_id,
        cex_order_id_len,
        fill_qty,
        fill_price,
        timestamp,
    );

    if (!cex_fill_ok) return false;

    // Step 2: Get CEX order to find local order ID
    const cex_order = cex_ob.get_order(router.cex_orderbook, cex_order_id, cex_order_id_len) orelse return false;

    // Step 3: Sync fill to local orderbook
    const local_fill_ok = local_ob.record_fill(
        router.local_orderbook,
        cex_order.local_order_id,
        fill_qty,
        fill_price,
        timestamp,
    );

    return local_fill_ok;
}

// ============================================================================
// ROUTE TO DEX (Step 2B)
// ============================================================================

/// Route order from LOCAL to DEX and submit
pub fn route_to_dex(
    router: *OrderRouter,
    local_order_id: u64,
    dex_id: dex_ob.DexId,
    chain_id: u32,
    token_in: [32]u8,
    token_out: [32]u8,
    amount_in: u64,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    timestamp: u64,
) bool {
    // Step 1: Mark local order as pending submit
    if (!local_ob.mark_pending_submit(router.local_orderbook, local_order_id, timestamp)) {
        return false;
    }

    // Step 2: Get local order details
    const local_order = local_ob.get_order(router.local_orderbook, local_order_id) orelse return false;

    // Step 3: Add to DEX orderbook
    const success = dex_ob.add_order(
        router.dex_orderbook,
        local_order_id,
        dex_id,
        chain_id,
        local_order.symbol,
        local_order.side,
        token_in,
        token_out,
        amount_in,
        local_order.price,
        local_order.quantity,
        tx_hash,
        tx_hash_len,
        timestamp,
    );

    if (success) {
        // Step 4: Mark local as submitted
        _ = local_ob.mark_submitted(router.local_orderbook, local_order_id, timestamp);
        router.total_to_dex += 1;
    }

    return success;
}

/// Sync DEX confirmation (on-chain) back to LOCAL
pub fn sync_dex_confirmation_to_local(
    router: *OrderRouter,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    timestamp: u64,
) bool {
    // Step 1: Confirm on DEX orderbook
    _ = dex_ob.confirm_on_chain(router.dex_orderbook, tx_hash, tx_hash_len, timestamp);

    // Step 2: Get DEX order to find local order ID
    const dex_order = dex_ob.get_order(router.dex_orderbook, tx_hash, tx_hash_len) orelse return false;

    // Step 3: Mark local as active (confirmed)
    _ = local_ob.mark_active(router.local_orderbook, dex_order.local_order_id);

    return true;
}

/// Sync DEX swap output (completion) back to LOCAL
pub fn sync_dex_output_to_local(
    router: *OrderRouter,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    amount_out: u64,
    gas_paid: u64,
    timestamp: u64,
) bool {
    // Step 1: Record swap output in DEX orderbook
    const dex_fill_ok = dex_ob.record_swap_output(
        router.dex_orderbook,
        tx_hash,
        tx_hash_len,
        amount_out,
        gas_paid,
        timestamp,
    );

    if (!dex_fill_ok) return false;

    // Step 2: Get DEX order to find local order ID
    const dex_order = dex_ob.get_order(router.dex_orderbook, tx_hash, tx_hash_len) orelse return false;

    // Step 3: Sync fill to local orderbook
    const local_fill_ok = local_ob.record_fill(
        router.local_orderbook,
        dex_order.local_order_id,
        @as(i64, @intCast(amount_out)),
        dex_order.price,
        timestamp,
    );

    // Step 4: Record gas as fees in local
    if (local_fill_ok and gas_paid > 0) {
        _ = local_ob.add_fees(
            router.local_orderbook,
            dex_order.local_order_id,
            @as(i64, @intCast(gas_paid)),
        );
    }

    return local_fill_ok;
}

// ============================================================================
// CANCEL ORDERS
// ============================================================================

/// Cancel order across all systems
pub fn cancel_order_all_systems(
    router: *OrderRouter,
    local_order_id: u64,
) bool {
    // Cancel in local
    _ = local_ob.cancel_order(router.local_orderbook, local_order_id, 0);

    // Cancel in CEX (if it exists there)
    // (would need to iterate through CEX orders or have a lookup)

    // Cancel in DEX (if it exists there)
    // (would need to iterate through DEX orders or have a lookup)

    return true;
}

// ============================================================================
// UNIFIED STATISTICS
// ============================================================================

pub const RouterStats = struct {
    total_orders_routed: u64,
    total_to_cex: u64,
    total_to_dex: u64,

    // Local stats
    local_created: u64,
    local_submitted: u64,
    local_filled: u64,
    local_pnl: i64,

    // CEX stats
    cex_submitted: u64,
    cex_filled: u64,
    cex_fees: i64,
    cex_pnl: i64,

    // DEX stats
    dex_submitted: u64,
    dex_confirmed: u64,
    dex_filled: u64,
    dex_gas: u64,
    dex_pnl: i64,
};

/// Get combined statistics from all 3 systems
pub fn get_router_stats(router: *const OrderRouter) RouterStats {
    const local_stats = local_ob.get_stats(router.local_orderbook);
    const cex_stats = cex_ob.get_stats(router.cex_orderbook);
    const dex_stats = dex_ob.get_stats(router.dex_orderbook);

    return .{
        .total_orders_routed = router.total_orders_routed,
        .total_to_cex = router.total_to_cex,
        .total_to_dex = router.total_to_dex,

        .local_created = local_stats.total_created,
        .local_submitted = local_stats.total_submitted,
        .local_filled = local_stats.total_filled,
        .local_pnl = local_stats.realized_pnl,

        .cex_submitted = cex_stats.total_submitted,
        .cex_filled = cex_stats.total_filled,
        .cex_fees = cex_stats.total_fees,
        .cex_pnl = cex_stats.realized_pnl,

        .dex_submitted = dex_stats.total_submitted,
        .dex_confirmed = dex_stats.total_confirmed,
        .dex_filled = dex_stats.total_filled,
        .dex_gas = dex_stats.total_gas_paid,
        .dex_pnl = dex_stats.realized_pnl,
    };
}
