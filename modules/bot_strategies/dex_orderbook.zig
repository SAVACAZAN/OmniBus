// DEX OrderBook – Decentralized Exchange order tracking
// Represents swaps on Uniswap and perpetuals on Hyperliquid
// Syncs with blockchain or DEX APIs, tracks on-chain transactions

const std = @import("std");

// ============================================================================
// DEX ORDER TYPES
// ============================================================================

pub const DexId = enum(u8) {
    UNISWAP_V3 = 0,
    UNISWAP_V4 = 1,
    HYPERLIQUID = 2,
};

pub const DexOrderStatus = enum(u8) {
    PENDING = 0,       // Transaction submitted to network
    CONFIRMED = 1,     // On-chain confirmed (1+ blocks)
    PARTIALLY_FILLED = 2,
    FILLED = 3,
    FAILED = 4,
    CANCELLED = 5,
};

pub const DexOrder = struct {
    local_order_id: u64,        // Reference to local orderbook
    tx_hash: [64]u8,            // Blockchain transaction hash (hex)
    tx_hash_len: u16,

    dex_id: DexId,
    chain_id: u32,              // 1=Eth, 42161=Arb, 10=Opt
    symbol: [16]u8,
    side: enum { BUY, SELL },

    token_in: [32]u8,           // Contract address
    token_out: [32]u8,
    amount_in: u64,             // Amount to swap
    amount_out_received: u64,   // Actual amount received

    price: i64,                 // Entry price (fixed-point)
    quantity: i64,              // Full order size

    status: DexOrderStatus,

    submitted_at: u64,          // When tx was submitted to network
    confirmed_at: u64 = 0,      // When confirmed on-chain
    filled_at: u64 = 0,

    gas_paid: u64 = 0,          // Gas cost in wei
    slippage_percent: i64 = 0,  // Actual slippage (50 = 0.5%)
    pnl: i64 = 0,
};

pub const DexOrderBookState = struct {
    orders: [2048]DexOrder = undefined,
    order_count: u32 = 0,

    // Per-DEX stats
    uniswap_v3_orders: u32 = 0,
    uniswap_v4_orders: u32 = 0,
    hyperliquid_orders: u32 = 0,

    // Per-chain stats
    eth_orders: u32 = 0,
    arb_orders: u32 = 0,
    opt_orders: u32 = 0,

    total_submitted: u64 = 0,
    total_confirmed: u64 = 0,
    total_filled: u64 = 0,
    total_failed: u64 = 0,

    total_volume: i64 = 0,
    total_gas_paid: u64 = 0,
    realized_pnl: i64 = 0,
};

// ============================================================================
// ORDER PLACEMENT
// ============================================================================

/// Add new DEX order (after transaction submitted to network)
pub fn add_order(
    dob: *DexOrderBookState,
    local_order_id: u64,
    dex_id: DexId,
    chain_id: u32,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    token_in: [32]u8,
    token_out: [32]u8,
    amount_in: u64,
    price: i64,
    quantity: i64,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    timestamp: u64,
) bool {
    if (dob.order_count >= 2048) return false;

    dob.orders[dob.order_count] = .{
        .local_order_id = local_order_id,
        .tx_hash = tx_hash,
        .tx_hash_len = tx_hash_len,
        .dex_id = dex_id,
        .chain_id = chain_id,
        .symbol = symbol,
        .side = side,
        .token_in = token_in,
        .token_out = token_out,
        .amount_in = amount_in,
        .amount_out_received = 0,
        .price = price,
        .quantity = quantity,
        .status = .PENDING,
        .submitted_at = timestamp,
        .confirmed_at = 0,
        .filled_at = 0,
        .gas_paid = 0,
        .slippage_percent = 0,
        .pnl = 0,
    };

    dob.order_count += 1;
    dob.total_submitted += 1;
    dob.total_volume += price * quantity;

    switch (dex_id) {
        .UNISWAP_V3 => dob.uniswap_v3_orders += 1,
        .UNISWAP_V4 => dob.uniswap_v4_orders += 1,
        .HYPERLIQUID => dob.hyperliquid_orders += 1,
    }

    switch (chain_id) {
        1 => dob.eth_orders += 1,
        42161 => dob.arb_orders += 1,
        10 => dob.opt_orders += 1,
        else => {},
    }

    return true;
}

// ============================================================================
// BLOCKCHAIN UPDATES
// ============================================================================

/// Update order status from blockchain confirmation
pub fn confirm_on_chain(
    dob: *DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    timestamp: u64,
) bool {
    if (find_order_mut(dob, tx_hash, tx_hash_len)) |order| {
        order.status = .CONFIRMED;
        order.confirmed_at = timestamp;
        dob.total_confirmed += 1;
        return true;
    }
    return false;
}

/// Record swap output (swap success)
pub fn record_swap_output(
    dob: *DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
    amount_out: u64,
    gas_paid: u64,
    timestamp: u64,
) bool {
    if (find_order_mut(dob, tx_hash, tx_hash_len)) |order| {
        order.amount_out_received = amount_out;
        order.gas_paid = gas_paid;
        dob.total_gas_paid += gas_paid;

        // Calculate slippage
        if (order.quantity > 0) {
            const expected = order.quantity;
            if (amount_out < expected) {
                const slippage_bps = ((expected - amount_out) * 10000) / expected;
                order.slippage_percent = @as(i64, @intCast(slippage_bps));
            }
        }

        // Mark as filled
        order.status = .FILLED;
        order.filled_at = timestamp;
        dob.total_filled += 1;

        // Calculate P&L
        const cost = order.quantity;
        const revenue = amount_out;
        order.pnl = @as(i64, @intCast(revenue)) - @as(i64, @intCast(cost)) - @as(i64, @intCast(gas_paid));
        dob.realized_pnl += order.pnl;

        return true;
    }
    return false;
}

/// Mark transaction as failed
pub fn mark_failed(
    dob: *DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
) bool {
    if (find_order_mut(dob, tx_hash, tx_hash_len)) |order| {
        order.status = .FAILED;
        dob.total_failed += 1;
        return true;
    }
    return false;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_order_mut(
    dob: *DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
) ?*DexOrder {
    for (0..dob.order_count) |i| {
        if (dob.orders[i].tx_hash_len == tx_hash_len and
            std.mem.eql(u8,
                &dob.orders[i].tx_hash[0..tx_hash_len],
                &tx_hash[0..tx_hash_len])) {
            return &dob.orders[i];
        }
    }
    return null;
}

/// Get order by transaction hash
pub fn get_order(
    dob: *const DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
) ?*const DexOrder {
    for (0..dob.order_count) |i| {
        if (dob.orders[i].tx_hash_len == tx_hash_len and
            std.mem.eql(u8,
                &dob.orders[i].tx_hash[0..tx_hash_len],
                &tx_hash[0..tx_hash_len])) {
            return &dob.orders[i];
        }
    }
    return null;
}

/// Get pending confirmations
pub fn get_pending_confirmations(dob: *const DexOrderBookState) u32 {
    var count: u32 = 0;
    for (0..dob.order_count) |i| {
        if (dob.orders[i].status == .PENDING) {
            count += 1;
        }
    }
    return count;
}

/// Get statistics
pub fn get_stats(dob: *const DexOrderBookState) struct {
    total_submitted: u64,
    total_confirmed: u64,
    total_filled: u64,
    total_failed: u64,
    uniswap_v3_orders: u32,
    uniswap_v4_orders: u32,
    hyperliquid_orders: u32,
    eth_orders: u32,
    arb_orders: u32,
    opt_orders: u32,
    total_volume: i64,
    total_gas_paid: u64,
    realized_pnl: i64,
} {
    return .{
        .total_submitted = dob.total_submitted,
        .total_confirmed = dob.total_confirmed,
        .total_filled = dob.total_filled,
        .total_failed = dob.total_failed,
        .uniswap_v3_orders = dob.uniswap_v3_orders,
        .uniswap_v4_orders = dob.uniswap_v4_orders,
        .hyperliquid_orders = dob.hyperliquid_orders,
        .eth_orders = dob.eth_orders,
        .arb_orders = dob.arb_orders,
        .opt_orders = dob.opt_orders,
        .total_volume = dob.total_volume,
        .total_gas_paid = dob.total_gas_paid,
        .realized_pnl = dob.realized_pnl,
    };
}
