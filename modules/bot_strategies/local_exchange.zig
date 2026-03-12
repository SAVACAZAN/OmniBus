// Local Exchange – Proprietary orderbook with matching engine
// Matches buy/sell orders and executes trades atomically
// Fully integrated with wallet_state and user_accounts

const std = @import("std");
const wallet_state = @import("wallet_state.zig");
const user_accounts = @import("user_accounts.zig");

// ============================================================================
// TRADING PAIR & MARKET
// ============================================================================

pub const TradingPair = struct {
    base_token: wallet_state.TokenId,  // Token being bought/sold (e.g., BTC)
    quote_token: wallet_state.TokenId, // Token used for price (e.g., USDC)
    base_chain: wallet_state.ChainId,
    quote_chain: wallet_state.ChainId,
};

pub const MarketPrice = struct {
    pair: TradingPair,
    last_trade_price: i64,
    bid_price: i64,      // Best buy order
    ask_price: i64,      // Best sell order
    mid_price: i64,      // (bid + ask) / 2
    volume_24h: i64,
    last_updated: u64,
};

// ============================================================================
// ORDER TYPES
// ============================================================================

pub const OrderStatus = enum(u8) {
    PENDING = 0,
    ACTIVE = 1,
    PARTIALLY_FILLED = 2,
    FILLED = 3,
    CANCELLED = 4,
    REJECTED = 5,
};

pub const Order = struct {
    order_id: u64,
    user_id: u64,

    pair: TradingPair,
    side: enum { BUY, SELL },
    order_type: enum { LIMIT, MARKET },

    price: i64,            // Fixed-point (e.g., 50000_00 for $50,000)
    quantity: i64,         // Amount of base token
    filled_quantity: i64,
    avg_fill_price: i64,

    status: OrderStatus,

    created_at: u64,
    submitted_at: u64 = 0,
    filled_at: u64 = 0,

    fees_paid: i64 = 0,
    net_proceeds: i64 = 0, // For sells: revenue - fees
    net_cost: i64 = 0,     // For buys: cost + fees
};

pub const OrderBook = struct {
    // Max 8,192 active orders
    orders: [8192]Order = undefined,
    order_count: u32 = 0,

    // Separate buy/sell books for fast matching
    buy_orders: [4096]u64 = undefined, // order_ids, sorted by price DESC
    buy_count: u32 = 0,

    sell_orders: [4096]u64 = undefined, // order_ids, sorted by price ASC
    sell_count: u32 = 0,

    // Statistics
    total_orders: u64 = 0,
    total_filled: u64 = 0,
    total_volume: i64 = 0,
    total_fees_collected: i64 = 0,
};

pub const Exchange = struct {
    // Exchange state
    wallets: *wallet_state.WalletState,
    accounts: *user_accounts.AccountsState,

    // Trading pairs
    pairs: [64]TradingPair = undefined,
    pair_count: u8 = 0,

    // Market prices
    prices: [64]MarketPrice = undefined,

    // Order books per pair
    books: [64]OrderBook = undefined,

    // Statistics
    total_trades: u64 = 0,
    total_volume: i64 = 0,
    total_fees: i64 = 0,

    // Fee structure (in basis points: 1 = 0.01%)
    maker_fee: u16 = 10,   // 0.1% for maker
    taker_fee: u16 = 25,   // 0.25% for taker
};

// ============================================================================
// EXCHANGE INITIALIZATION
// ============================================================================

pub fn init_exchange(
    wallets: *wallet_state.WalletState,
    accounts: *user_accounts.AccountsState,
) Exchange {
    return .{
        .wallets = wallets,
        .accounts = accounts,
    };
}

/// Register trading pair
pub fn register_pair(
    exchange: *Exchange,
    base_token: wallet_state.TokenId,
    quote_token: wallet_state.TokenId,
    base_chain: wallet_state.ChainId,
    quote_chain: wallet_state.ChainId,
) bool {
    if (exchange.pair_count >= 64) return false;

    const pair = TradingPair{
        .base_token = base_token,
        .quote_token = quote_token,
        .base_chain = base_chain,
        .quote_chain = quote_chain,
    };

    exchange.pairs[exchange.pair_count] = pair;
    exchange.books[exchange.pair_count] = .{};
    exchange.prices[exchange.pair_count] = .{
        .pair = pair,
        .last_trade_price = 0,
        .bid_price = 0,
        .ask_price = 0,
        .mid_price = 0,
        .volume_24h = 0,
        .last_updated = 0,
    };

    exchange.pair_count += 1;
    return true;
}

// ============================================================================
// ORDER PLACEMENT
// ============================================================================

/// Place limit order on exchange
pub fn place_limit_order(
    exchange: *Exchange,
    user_id: u64,
    pair_idx: u8,
    side: enum { BUY, SELL },
    quantity: i64,
    price: i64,
    timestamp: u64,
) u64 {
    if (pair_idx >= exchange.pair_count) return 0;
    if (quantity <= 0 or price <= 0) return 0;

    const account = user_accounts.find_account(exchange.accounts, user_id) orelse return 0;
    if (account.account_status != .ACTIVE) return 0;
    if (account.kyc_status == .UNVERIFIED or account.kyc_status == .PENDING_VERIFICATION) return 0;

    const book = &exchange.books[pair_idx];
    const pair = exchange.pairs[pair_idx];

    // Lock tokens for the order
    if (side == .BUY) {
        const cost = (price * quantity) / 100_000_000; // Fixed-point division
        if (!wallet_state.lock_for_order(
            exchange.wallets,
            user_id,
            pair.quote_token,
            pair.quote_chain,
            cost,
            timestamp,
        )) {
            return 0; // Insufficient balance
        }
    } else {
        if (!wallet_state.lock_for_order(
            exchange.wallets,
            user_id,
            pair.base_token,
            pair.base_chain,
            quantity,
            timestamp,
        )) {
            return 0; // Insufficient balance
        }
    }

    // Create order
    if (book.order_count >= 8192) {
        // Unlock and fail
        if (side == .BUY) {
            const cost = (price * quantity) / 100_000_000;
            _ = wallet_state.unlock_from_order(
                exchange.wallets,
                user_id,
                pair.quote_token,
                pair.quote_chain,
                cost,
                timestamp,
            );
        } else {
            _ = wallet_state.unlock_from_order(
                exchange.wallets,
                user_id,
                pair.base_token,
                pair.base_chain,
                quantity,
                timestamp,
            );
        }
        return 0;
    }

    const order_id = exchange.total_trades + 1;

    book.orders[book.order_count] = .{
        .order_id = order_id,
        .user_id = user_id,
        .pair = pair,
        .side = side,
        .order_type = .LIMIT,
        .price = price,
        .quantity = quantity,
        .filled_quantity = 0,
        .avg_fill_price = 0,
        .status = .ACTIVE,
        .created_at = timestamp,
        .submitted_at = timestamp,
    };

    book.order_count += 1;
    exchange.total_orders += 1;

    // Try to match immediately
    _ = match_orders(exchange, pair_idx, timestamp);

    return order_id;
}

// ============================================================================
// ORDER MATCHING ENGINE
// ============================================================================

fn match_orders(
    exchange: *Exchange,
    pair_idx: u8,
    timestamp: u64,
) u32 {
    const book = &exchange.books[pair_idx];
    const pair = exchange.pairs[pair_idx];

    var matches_made: u32 = 0;

    // Find best buy order
    var best_buy_idx: ?usize = null;
    var best_buy_price: i64 = 0;

    // Find best sell order
    var best_sell_idx: ?usize = null;
    var best_sell_price: i64 = std.math.maxInt(i64);

    // Scan for best orders
    for (0..book.order_count) |i| {
        const order = &book.orders[i];
        if (order.status != .ACTIVE and order.status != .PARTIALLY_FILLED) continue;

        if (order.side == .BUY and order.price > best_buy_price) {
            best_buy_price = order.price;
            best_buy_idx = i;
        }

        if (order.side == .SELL and order.price < best_sell_price) {
            best_sell_price = order.price;
            best_sell_idx = i;
        }
    }

    // Check if prices cross
    if (best_buy_idx != null and best_sell_idx != null and best_buy_price >= best_sell_price) {
        const buy_order = &book.orders[best_buy_idx.?];
        const sell_order = &book.orders[best_sell_idx.?];

        // Execute at mid-price (average of the two)
        const execution_price = (best_buy_price + best_sell_price) / 2;
        const quantity = if (buy_order.quantity - buy_order.filled_quantity <
            sell_order.quantity - sell_order.filled_quantity)
            buy_order.quantity - buy_order.filled_quantity
        else
            sell_order.quantity - sell_order.filled_quantity;

        // Record fills
        record_fill(book, best_buy_idx.?, quantity, execution_price);
        record_fill(book, best_sell_idx.?, quantity, execution_price);

        // Update wallets (atomic trade)
        const taker_fee = (execution_price * quantity) * @as(i64, @intCast(exchange.taker_fee)) / 1_000_000;
        const maker_fee = (execution_price * quantity) * @as(i64, @intCast(exchange.maker_fee)) / 1_000_000;

        // Buy order pays quote, receives base minus fee
        _ = wallet_state.complete_order(
            exchange.wallets,
            buy_order.user_id,
            pair.quote_token,
            pair.quote_chain,
            (execution_price * quantity) / 100_000_000,
            pair.base_token,
            pair.base_chain,
            quantity - (taker_fee / quantity), // Simplified fee calculation
            timestamp,
        );

        // Sell order pays base, receives quote minus fee
        _ = wallet_state.complete_order(
            exchange.wallets,
            sell_order.user_id,
            pair.base_token,
            pair.base_chain,
            quantity,
            pair.quote_token,
            pair.quote_chain,
            (execution_price * quantity) / 100_000_000 - maker_fee,
            timestamp,
        );

        // Update market price
        exchange.prices[pair_idx].last_trade_price = execution_price;
        exchange.prices[pair_idx].mid_price = execution_price;
        exchange.prices[pair_idx].volume_24h += quantity;
        exchange.prices[pair_idx].last_updated = timestamp;

        exchange.total_volume += quantity;
        exchange.total_fees += taker_fee + maker_fee;

        matches_made = 1;
    }

    return matches_made;
}

fn record_fill(
    book: *OrderBook,
    order_idx: usize,
    fill_qty: i64,
    fill_price: i64,
) void {
    const order = &book.orders[order_idx];

    const old_filled = order.filled_quantity;
    order.filled_quantity += fill_qty;

    // Update average fill price
    if (order.filled_quantity > 0) {
        const total_cost = (order.avg_fill_price * old_filled) + (fill_price * fill_qty);
        order.avg_fill_price = total_cost / order.filled_quantity;
    }

    // Check if fully filled
    if (order.filled_quantity >= order.quantity) {
        order.status = .FILLED;
    } else {
        order.status = .PARTIALLY_FILLED;
    }
}

// ============================================================================
// CANCEL ORDER
// ============================================================================

pub fn cancel_order(
    exchange: *Exchange,
    pair_idx: u8,
    order_id: u64,
    timestamp: u64,
) bool {
    if (pair_idx >= exchange.pair_count) return false;

    const book = &exchange.books[pair_idx];
    const pair = exchange.pairs[pair_idx];

    for (0..book.order_count) |i| {
        const order = &book.orders[i];
        if (order.order_id == order_id) {
            if (order.status == .FILLED or order.status == .CANCELLED) {
                return false; // Can't cancel
            }

            // Unlock remaining tokens
            const remaining = order.quantity - order.filled_quantity;

            if (order.side == .BUY) {
                const cost = (order.price * remaining) / 100_000_000;
                _ = wallet_state.unlock_from_order(
                    exchange.wallets,
                    order.user_id,
                    pair.quote_token,
                    pair.quote_chain,
                    cost,
                    timestamp,
                );
            } else {
                _ = wallet_state.unlock_from_order(
                    exchange.wallets,
                    order.user_id,
                    pair.base_token,
                    pair.base_chain,
                    remaining,
                    timestamp,
                );
            }

            order.status = .CANCELLED;
            return true;
        }
    }

    return false;
}

// ============================================================================
// QUERIES
// ============================================================================

pub fn get_order(
    exchange: *const Exchange,
    pair_idx: u8,
    order_id: u64,
) ?*const Order {
    if (pair_idx >= exchange.pair_count) return null;

    const book = &exchange.books[pair_idx];
    for (0..book.order_count) |i| {
        if (book.orders[i].order_id == order_id) {
            return &book.orders[i];
        }
    }

    return null;
}

pub fn get_market_price(
    exchange: *const Exchange,
    pair_idx: u8,
) ?*const MarketPrice {
    if (pair_idx >= exchange.pair_count) return null;
    return &exchange.prices[pair_idx];
}

pub fn get_exchange_stats(exchange: *const Exchange) struct {
    total_trades: u64,
    total_volume: i64,
    total_fees: i64,
    active_pairs: u8,
} {
    return .{
        .total_trades = exchange.total_trades,
        .total_volume = exchange.total_volume,
        .total_fees = exchange.total_fees,
        .active_pairs = exchange.pair_count,
    };
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

pub fn example_exchange_trading(
    exchange: *Exchange,
    timestamp: u64,
) void {
    // Assume we have pair 0: BTC/USDC on Polygon
    // User 1 wants to BUY 1 BTC at $50,000
    // User 2 wants to SELL 1 BTC at $50,100

    const user1_buy_order = place_limit_order(
        exchange,
        1,
        0,
        .BUY,
        1_00_000_000, // 1 BTC (8 decimals)
        50000_00,     // $50,000 per BTC
        timestamp,
    );

    const user2_sell_order = place_limit_order(
        exchange,
        2,
        0,
        .SELL,
        1_00_000_000, // 1 BTC
        50100_00,     // $50,100 per BTC
        timestamp + 1,
    );

    if (user1_buy_order > 0 and user2_sell_order > 0) {
        // Orders should match at ~$50,050 mid-price
        const stats = get_exchange_stats(exchange);

        // After matching:
        // User 1: paid ~$50,050 in USDC, received 1 BTC (minus fees)
        // User 2: paid 1 BTC, received ~$50,050 in USDC (minus fees)
        // Exchange collected fees on both sides

        if (stats.total_trades > 0) {
            // Trade was executed!
        }
    }
}
