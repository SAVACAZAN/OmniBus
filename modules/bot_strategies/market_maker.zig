// Market Maker Engine
// Manages bid/ask spreads and maintains two-sided orderbook
// Balances inventory and adapts spreads to market conditions

const std = @import("std");
const bot = @import("bot_strategies.zig");
const orderbook = @import("orderbook_local.zig");

// ============================================================================
// MARKET MAKER STRUCTURES
// ============================================================================

pub const MarketMakerConfig = struct {
    symbol: [16]u8,
    cex_id: u8,                 // 0=Kraken, 1=LCX, 2=Coinbase
    base_spread_bps: i64,       // Basis points (e.g., 20 = 0.2% spread)
    min_order_size: i64,        // Minimum order quantity
    max_order_size: i64,        // Maximum order size
    max_inventory: i64,         // Maximum position to hold
    target_inventory: i64,      // Try to stay near this level
    rebalance_threshold: i64,   // Threshold to rebalance (% of target)
};

pub const MarketMakerState = struct {
    config: MarketMakerConfig,
    orderbook: *orderbook.OrderBookState,

    // Current market state
    mid_price: i64,
    last_bid: i64,
    last_ask: i64,
    bid_volume: i64,
    ask_volume: i64,

    // Position tracking
    current_inventory: i64,     // Current position (positive = long)
    avg_entry_price: i64,       // Average price of current position
    inventory_pnl: i64,         // Unrealized P&L on inventory

    // Spread management
    dynamic_spread_bps: i64,    // Current spread (basis points)
    spread_multiplier: i64,     // Adjust for volatility (in basis points)

    // Statistics
    total_buy_fills: u32,
    total_sell_fills: u32,
    total_rebalances: u32,
    maker_pnl: i64,
};

// ============================================================================
// SPREAD CALCULATION
// ============================================================================

/// Calculate dynamic spread based on market conditions
pub fn calculate_dynamic_spread(
    state: *const MarketMakerState,
    volatility: i64,
    imbalance_percent: i64,
) i64 {
    var spread = state.config.base_spread_bps;

    // Increase spread with volatility
    // volatility in bps, e.g., 250 = 2.5%
    const vol_adjustment = (volatility * 50) / 10000; // 0.5% of volatility
    spread += vol_adjustment;

    // Increase spread if inventory is imbalanced
    // imbalance_percent: 0-100, where 100 = extreme imbalance
    const imbalance_adjustment = (imbalance_percent * spread) / 100;
    spread += imbalance_adjustment / 2;

    return spread;
}

/// Calculate bid/ask prices from mid price and spread
pub fn calculate_bid_ask(
    mid_price: i64,
    spread_bps: i64,
) struct { bid: i64, ask: i64 } {
    const half_spread = (mid_price * spread_bps) / (2 * 10000);
    return .{
        .bid = mid_price - half_spread,
        .ask = mid_price + half_spread,
    };
}

// ============================================================================
// INVENTORY MANAGEMENT
// ============================================================================

/// Calculate inventory imbalance (0-100)
pub fn get_inventory_imbalance(state: *const MarketMakerState) i64 {
    const target = state.config.target_inventory;
    const current = state.current_inventory;

    if (target == 0) return 0;

    const diff = if (current > target)
        ((current - target) * 100) / target
    else
        ((target - current) * 100) / target;

    return if (diff > 100) 100 else diff;
}

/// Check if rebalancing is needed
pub fn should_rebalance(state: *const MarketMakerState) bool {
    const imbalance = get_inventory_imbalance(state);
    return imbalance > state.config.rebalance_threshold;
}

/// Calculate rebalance order size
pub fn calculate_rebalance_size(state: *const MarketMakerState) i64 {
    const target = state.config.target_inventory;
    const current = state.current_inventory;
    const diff = target - current;

    // Use half the difference to avoid oscillation
    var size = if (diff > 0) diff / 2 else -diff / 2;

    if (size > state.config.max_order_size) {
        size = state.config.max_order_size;
    } else if (size < state.config.min_order_size and size > 0) {
        size = state.config.min_order_size;
    }

    return size;
}

// ============================================================================
// ORDER PLACEMENT
// ============================================================================

/// Place bid order (buy)
pub fn place_bid(
    state: *MarketMakerState,
    bid_price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    const order_id = orderbook.create_order(
        state.orderbook,
        state.config.cex_id,
        state.config.symbol,
        .BUY,
        .POSTONLY,           // Post-only to avoid immediate fill
        bid_price,
        quantity,
        timestamp,
    );

    return order_id;
}

/// Place ask order (sell)
pub fn place_ask(
    state: *MarketMakerState,
    ask_price: i64,
    quantity: i64,
    timestamp: u64,
) u64 {
    const order_id = orderbook.create_order(
        state.orderbook,
        state.config.cex_id,
        state.config.symbol,
        .SELL,
        .POSTONLY,           // Post-only to avoid immediate fill
        ask_price,
        quantity,
        timestamp,
    );

    return order_id;
}

/// Place rebalance order
pub fn place_rebalance_order(
    state: *MarketMakerState,
    market_price: i64,
    timestamp: u64,
) u64 {
    const size = calculate_rebalance_size(state);

    if (size <= 0) return 0;

    const is_buy = state.current_inventory < state.config.target_inventory;

    return if (is_buy)
        place_bid(state, market_price - 10, size, timestamp)
    else
        place_ask(state, market_price + 10, size, timestamp);
}

// ============================================================================
// FILL PROCESSING
// ============================================================================

/// Process a fill and update inventory
pub fn process_fill(
    state: *MarketMakerState,
    order_id: u64,
    fill_quantity: i64,
    fill_price: i64,
) bool {
    if (orderbook.find_order(state.orderbook, order_id)) |order| {
        const prev_inventory = state.current_inventory;

        // Update inventory
        if (order.side == .BUY) {
            state.current_inventory += fill_quantity;
        } else {
            state.current_inventory -= fill_quantity;
        }

        // Update average entry price
        if (prev_inventory == 0) {
            state.avg_entry_price = fill_price;
        } else if ((prev_inventory > 0 and order.side == .BUY) or
                   (prev_inventory < 0 and order.side == .SELL)) {
            // Adding to position
            state.avg_entry_price = (
                (state.avg_entry_price * prev_inventory) +
                (fill_price * fill_quantity)
            ) / state.current_inventory;
        } else {
            // Reducing position (lock in P&L)
            const pnl = (fill_price - state.avg_entry_price) *
                if (order.side == .SELL) fill_quantity else -fill_quantity;
            state.maker_pnl += pnl;
        }

        // Update fill counters
        if (order.side == .BUY) {
            state.total_buy_fills += 1;
        } else {
            state.total_sell_fills += 1;
        }

        return true;
    }

    return false;
}

// ============================================================================
// MARKET MAKER CYCLE
// ============================================================================

pub fn market_maker_cycle(
    state: *MarketMakerState,
    current_mid_price: i64,
    volatility: i64,
    timestamp: u64,
) void {
    // Step 1: Update market state
    state.mid_price = current_mid_price;
    state.bid_volume = 0;
    state.ask_volume = 0;

    // Step 2: Calculate dynamic spread
    const imbalance = get_inventory_imbalance(state);
    state.dynamic_spread_bps = calculate_dynamic_spread(
        state,
        volatility,
        imbalance,
    );

    // Step 3: Calculate bid/ask prices
    const prices = calculate_bid_ask(state.mid_price, state.dynamic_spread_bps);
    state.last_bid = prices.bid;
    state.last_ask = prices.ask;

    // Step 4: Cancel and replace orders if spread changed
    orderbook.rebuild_active_orders(state.orderbook);

    // Step 5: Check if we need to rebalance
    if (should_rebalance(state)) {
        _ = place_rebalance_order(state, current_mid_price, timestamp);
        state.total_rebalances += 1;
    }

    // Step 6: Update inventory P&L
    if (state.current_inventory != 0) {
        state.inventory_pnl = (current_mid_price - state.avg_entry_price) *
            state.current_inventory;
    }
}

// ============================================================================
// INITIALIZATION & HELPERS
// ============================================================================

pub fn init_market_maker(
    config: MarketMakerConfig,
    ob: *orderbook.OrderBookState,
) MarketMakerState {
    return .{
        .config = config,
        .orderbook = ob,
        .mid_price = 0,
        .last_bid = 0,
        .last_ask = 0,
        .bid_volume = 0,
        .ask_volume = 0,
        .current_inventory = 0,
        .avg_entry_price = 0,
        .inventory_pnl = 0,
        .dynamic_spread_bps = config.base_spread_bps,
        .spread_multiplier = 100,
        .total_buy_fills = 0,
        .total_sell_fills = 0,
        .total_rebalances = 0,
        .maker_pnl = 0,
    };
}

pub const MarketMakerStats = struct {
    mid_price: i64,
    bid: i64,
    ask: i64,
    spread_bps: i64,
    current_inventory: i64,
    inventory_pnl: i64,
    maker_pnl: i64,
    buy_fills: u32,
    sell_fills: u32,
    rebalances: u32,
};

pub fn get_market_maker_stats(state: *const MarketMakerState) MarketMakerStats {
    return .{
        .mid_price = state.mid_price,
        .bid = state.last_bid,
        .ask = state.last_ask,
        .spread_bps = state.dynamic_spread_bps,
        .current_inventory = state.current_inventory,
        .inventory_pnl = state.inventory_pnl,
        .maker_pnl = state.maker_pnl,
        .buy_fills = state.total_buy_fills,
        .sell_fills = state.total_sell_fills,
        .rebalances = state.total_rebalances,
    };
}
