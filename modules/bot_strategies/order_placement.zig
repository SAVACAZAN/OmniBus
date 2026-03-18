// Order Placement API – Simple 3-function interface
// Direct placement functions: LOCAL, CEX, DEX
// Each function is independent - no auto-sync between zones

const std = @import("std");
const local_ob = @import("local_orderbook.zig");
const cex_ob = @import("cex_orderbook.zig");
const dex_ob = @import("dex_orderbook.zig");

// ============================================================================
// PLACEMENT API
// ============================================================================

/// **Zone 1**: Place order in LOCAL (private OmniBus tracking)
/// Returns: local_order_id (1-4096)
/// Effect: Creates order in LOCAL ZONE ONLY
pub fn place_local_order(
    lob: *local_ob.LocalOrderBookState,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    return local_ob.create_order(lob, symbol, side, order_type, price, quantity, timestamp);
}

/// **Zone 2**: Place order on CEX (Kraken, LCX, Coinbase)
/// Prerequisites:
///   - Order must be created locally first (get local_order_id)
///   - CEX API call must succeed (get cex_order_id from response)
/// Returns: true if added to CEX orderbook
/// Effect: Creates order in CEX ZONE ONLY
pub fn place_cex_order(
    cob: *cex_ob.CexOrderBookState,
    local_order_id: u64,
    cex_id: cex_ob.CexId,
    symbol: [16]u8,
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,
    quantity: i64,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
    timestamp: u64,
) bool {
    return cex_ob.add_order(
        cob,
        local_order_id,
        cex_id,
        symbol,
        side,
        order_type,
        price,
        quantity,
        cex_order_id,
        cex_order_id_len,
        timestamp,
    );
}

/// **Zone 3**: Place order on DEX (Uniswap, Hyperliquid)
/// Prerequisites:
///   - Order must be created locally first (get local_order_id)
///   - Blockchain transaction must be submitted (get tx_hash)
/// Returns: true if added to DEX orderbook
/// Effect: Creates order in DEX ZONE ONLY
pub fn place_dex_order(
    dob: *dex_ob.DexOrderBookState,
    local_order_id: u64,
    dex_id: dex_ob.DexId,
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
    return dex_ob.add_order(
        dob,
        local_order_id,
        dex_id,
        chain_id,
        symbol,
        side,
        token_in,
        token_out,
        amount_in,
        price,
        quantity,
        tx_hash,
        tx_hash_len,
        timestamp,
    );
}

// ============================================================================
// EXAMPLE USAGE PATTERNS
// ============================================================================

/// Example 1: Trade only in LOCAL (private tracking, no submission)
/// Use case: Pre-plan trades without executing
pub fn example_local_only(
    lob: *local_ob.LocalOrderBookState,
    timestamp: u64,
) void {
    // Step 1: Create order in LOCAL
    const order_id = place_local_order(
        lob,
        "BTC/USD" ++ "\x00" ** 8,
        .BUY,
        .LIMIT,
        50000_00, // $50,000
        1_00_000_000, // 1 BTC (in satoshis)
        timestamp,
    );

    if (order_id > 0) {
        // Order is now in LOCAL zone only
        // Not visible on CEX or DEX
        // Can query it, update it, cancel it locally
        // But it's not submitted to any venue
    }
}

/// Example 2: Trade on CEX only (Kraken)
/// Use case: Centralized exchange trading
pub fn example_cex_only(
    lob: *local_ob.LocalOrderBookState,
    cob: *cex_ob.CexOrderBookState,
    timestamp: u64,
) void {
    // Step 1: Create order in LOCAL
    const local_id = place_local_order(
        lob,
        "BTC/USD" ++ "\x00" ** 8,
        .BUY,
        .LIMIT,
        50000_00,
        1_00_000_000,
        timestamp,
    );

    if (local_id > 0) {
        // Step 2: Submit to CEX (would call Kraken API here)
        // const cex_response = kraken_api.submit_order(...)
        const cex_order_id: [32]u8 = "order_12345678901234567890" ++ "\x00" ** 6;
        const cex_order_id_len = 26;

        // Step 3: Add to CEX zone
        _ = place_cex_order(
            cob,
            local_id,
            .KRAKEN,
            "BTC/USD" ++ "\x00" ** 8,
            .BUY,
            .LIMIT,
            50000_00,
            1_00_000_000,
            cex_order_id,
            cex_order_id_len,
            timestamp,
        );

        // Now order exists in TWO zones:
        // - LOCAL: Private tracking
        // - CEX: Live on Kraken orderbook
        // They are INDEPENDENT - fills don't auto-sync
    }
}

/// Example 3: Trade on DEX only (Uniswap)
/// Use case: Decentralized swaps
pub fn example_dex_only(
    lob: *local_ob.LocalOrderBookState,
    dob: *dex_ob.DexOrderBookState,
    timestamp: u64,
) void {
    // Step 1: Create order in LOCAL
    const local_id = place_local_order(
        lob,
        "BTC/USD" ++ "\x00" ** 8,
        .BUY,
        .LIMIT,
        50000_00,
        1_00_000_000,
        timestamp,
    );

    if (local_id > 0) {
        // Step 2: Submit swap to blockchain (would call Uniswap router here)
        // const tx_response = uniswap.swap(token_in, token_out, amount_in, ...)
        const tx_hash: [64]u8 = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";

        // Step 3: Add to DEX zone
        _ = place_dex_order(
            dob,
            local_id,
            .UNISWAP_V3,
            1, // Ethereum mainnet
            "BTC/USD" ++ "\x00" ** 8,
            .BUY,
            "0x2260fac5e5542a773aa44fbcff0b601ebcb64bef2" ++ "\x00" ** 8, // WBTC
            "0xc02aaa39b223fe8d0a0e8e4c5764736f6a0a2f54" ++ "\x00" ** 8, // WETH
            1_00_000_000,
            50000_00,
            1_00_000_000,
            tx_hash,
            64,
            timestamp,
        );

        // Now order exists in TWO zones:
        // - LOCAL: Private tracking
        // - DEX: Live on blockchain (pending confirmation)
        // They are INDEPENDENT
    }
}

/// Example 4: Multi-venue arbitrage
/// Use case: Buy on CEX, sell on DEX simultaneously
pub fn example_cex_and_dex(
    lob: *local_ob.LocalOrderBookState,
    cob: *cex_ob.CexOrderBookState,
    dob: *dex_ob.DexOrderBookState,
    timestamp: u64,
) void {
    // Step 1: Create TWO separate local orders
    const buy_local_id = place_local_order(
        lob,
        "BTC/USD" ++ "\x00" ** 8,
        .BUY,
        .MARKET,
        50000_00,
        1_00_000_000,
        timestamp,
    );

    const sell_local_id = place_local_order(
        lob,
        "BTC/USD" ++ "\x00" ** 8,
        .SELL,
        .MARKET,
        50100_00, // Slightly higher
        1_00_000_000,
        timestamp,
    );

    if (buy_local_id > 0) {
        // Step 2: Submit BUY to CEX (Kraken)
        _ = place_cex_order(
            cob,
            buy_local_id,
            .KRAKEN,
            "BTC/USD" ++ "\x00" ** 8,
            .BUY,
            .MARKET,
            50000_00,
            1_00_000_000,
            "kraken_buy_order_123" ++ "\x00" ** 10,
            20,
            timestamp,
        );
    }

    if (sell_local_id > 0) {
        // Step 3: Submit SELL to DEX (Uniswap)
        _ = place_dex_order(
            dob,
            sell_local_id,
            .UNISWAP_V3,
            1,
            "BTC/USD" ++ "\x00" ** 8,
            .SELL,
            "0x2260fac5e5542a773aa44fbcff0b601ebcb64bef2" ++ "\x00" ** 8,
            "0xc02aaa39b223fe8d0a0e8e4c5764736f6a0a2f54" ++ "\x00" ** 8,
            1_00_000_000,
            50100_00,
            1_00_000_000,
            "0xabc..." ++ "\x00" ** 29,
            16,
            timestamp,
        );
    }

    // Now:
    // - LOCAL has 2 orders (buy + sell)
    // - CEX has 1 order (buy on Kraken)
    // - DEX has 1 order (sell on Uniswap)
    // All independent, all tracked separately
}

// ============================================================================
// ZONE QUERIES
// ============================================================================

/// Get order from LOCAL zone
pub fn get_local_order(
    lob: *const local_ob.LocalOrderBookState,
    order_id: u64,
) ?*const local_ob.LocalOrder {
    return local_ob.get_order(lob, order_id);
}

/// Get order from CEX zone
pub fn get_cex_order(
    cob: *const cex_ob.CexOrderBookState,
    cex_order_id: [32]u8,
    cex_order_id_len: u16,
) ?*const cex_ob.CexOrder {
    return cex_ob.get_order(cob, cex_order_id, cex_order_id_len);
}

/// Get order from DEX zone
pub fn get_dex_order(
    dob: *const dex_ob.DexOrderBookState,
    tx_hash: [64]u8,
    tx_hash_len: u16,
) ?*const dex_ob.DexOrder {
    return dex_ob.get_order(dob, tx_hash, tx_hash_len);
}
