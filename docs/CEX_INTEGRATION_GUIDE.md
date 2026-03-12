# CEX Integration Guide
## Kraken, LCX, Coinbase Bot Placement System

---

## Architecture Overview

The CEX integration system consists of three coordinated layers:

```
┌─────────────────────────────────────────────────────────────┐
│  Bot Strategies (GridBot, OneClick, DCA, etc.)             │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│  GridBotEngine (Active order lifecycle & reposting)        │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Market Maker  │  │  OrderBook   │  │CEX Interface │     │
│  │(Spreads)     │  │  (Tracking)  │  │(APIs)        │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└──────────────┬──────────────────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
 KRAKEN      LCX      COINBASE
```

---

## Layer 1: Local OrderBook (`orderbook_local.zig`)

### Purpose
Tracks all orders placed locally before sending to CEX. Maintains order state, fills, and P&L.

### Key Structures

**LocalOrder**:
```zig
pub const LocalOrder = struct {
    order_id: u64,              // Local unique ID (1, 2, 3...)
    cex_order_id: [32]u8,       // CEX-assigned ID (e.g., Kraken txid)
    cex_id: u8,                 // 0=Kraken, 1=LCX, 2=Coinbase
    symbol: [16]u8,             // "XBTUSDT"
    side: enum { BUY, SELL },
    order_type: enum { MARKET, LIMIT, POSTONLY },
    price: i64,                 // Fixed-point price
    quantity: i64,              // Amount to trade
    filled_quantity: i64,       // How much filled
    avg_fill_price: i64,        // Average fill price
    status: OrderStatus,
    created_at: u64,
    submitted_at: u64,
    filled_at: u64,
    fees_paid: i64,
    pnl: i64,
};
```

**OrderStatus**:
```zig
pub const OrderStatus = enum {
    NEW,                // Created locally
    PENDING_SUBMIT,     // Waiting to send to CEX
    SUBMITTED,          // Sent to CEX
    ACTIVE,             // Confirmed on CEX
    PARTIALLY_FILLED,   // Partially matched
    FILLED,             // Completely matched
    CANCELLED,          // User cancelled
    REJECTED,           // CEX rejected
    EXPIRED,            // Timeout
};
```

### Key Functions

```zig
// Create new order
create_order(orderbook, cex_id, symbol, side, order_type, price, quantity, timestamp) → u64

// Submit to CEX
submit_order(orderbook, order_id, timestamp) → bool

// Track fills
record_fill(orderbook, order_id, fill_quantity, fill_price, timestamp) → bool

// Update CEX order ID
set_cex_order_id(orderbook, order_id, cex_order_id) → bool

// Cancel order
cancel_order(orderbook, order_id, timestamp) → bool

// Get aggregated stats
get_orderbook_stats(orderbook) → OrderbookStats
```

### Example Usage

```zig
// Initialize
var orderbook = orderbook_local.init_orderbook();

// Create order for Kraken
const order_id = orderbook_local.create_order(
    &orderbook,
    0,                          // KRAKEN
    "XBTUSDT",
    .BUY,
    .LIMIT,
    50000_00,                   // $50,000
    1,                          // 1 BTC
    get_timestamp(),
);

// Submit to CEX
orderbook_local.submit_order(&orderbook, order_id, get_timestamp());

// When order fills
orderbook_local.record_fill(&orderbook, order_id, 1, 50100_00, get_timestamp());
```

---

## Layer 2: Market Maker Engine (`market_maker.zig`)

### Purpose
Manages bid/ask spreads, maintains two-sided orderbook, rebalances inventory.

### Key Structures

**MarketMakerConfig**:
```zig
pub const MarketMakerConfig = struct {
    symbol: [16]u8,
    cex_id: u8,
    base_spread_bps: i64,       // e.g., 20 = 0.2%
    min_order_size: i64,
    max_order_size: i64,
    max_inventory: i64,         // Max position
    target_inventory: i64,      // Optimal position
    rebalance_threshold: i64,   // % before rebalancing
};
```

**MarketMakerState**:
```zig
pub const MarketMakerState = struct {
    config: MarketMakerConfig,
    orderbook: *orderbook.OrderBookState,

    // Current market
    mid_price: i64,
    dynamic_spread_bps: i64,

    // Position
    current_inventory: i64,
    avg_entry_price: i64,
    inventory_pnl: i64,

    // Stats
    total_buy_fills: u32,
    total_sell_fills: u32,
    total_rebalances: u32,
    maker_pnl: i64,
};
```

### Dynamic Spread Calculation

Spread adapts to:
1. **Volatility** – Wider spread in choppy markets
2. **Inventory imbalance** – Wider spread if position is imbalanced

```zig
dynamic_spread = base_spread + volatility_adjustment + imbalance_adjustment
```

### Inventory Rebalancing

When position deviates from target:
- Buy if below target (long recovery)
- Sell if above target (reduce position)
- Size = half the difference (avoid oscillation)

### Key Functions

```zig
// Calculate spread
calculate_dynamic_spread(state, volatility, imbalance) → i64

// Calculate bid/ask
calculate_bid_ask(mid_price, spread_bps) → {bid, ask}

// Check if rebalance needed
should_rebalance(state) → bool

// Place orders
place_bid(state, bid_price, quantity, timestamp) → u64
place_ask(state, ask_price, quantity, timestamp) → u64

// Process fills
process_fill(state, order_id, fill_quantity, fill_price) → bool

// Main cycle
market_maker_cycle(state, mid_price, volatility, timestamp)
```

### Example Usage

```zig
// Setup
var config = MarketMakerConfig{
    .symbol = "ETHUSDT",
    .cex_id = 1,                // LCX
    .base_spread_bps = 15,      // 0.15%
    .min_order_size = 10,
    .max_order_size = 100,
    .target_inventory = 50,     // 50 ETH
    .rebalance_threshold = 25,  // 25% imbalance triggers rebalance
};

var mm = market_maker.init_market_maker(config, &orderbook);

// Every tick
market_maker.market_maker_cycle(&mm, 2000_00, 150, get_timestamp());

// Check if we placed bid/ask
var stats = market_maker.get_market_maker_stats(&mm);
std.debug.print("Bid: {}, Ask: {}, Inventory: {}\n",
    .{ stats.bid, stats.ask, stats.current_inventory });
```

---

## Layer 3: CEX Interface (`cex_interface.zig`)

### Purpose
Abstracts API calls to Kraken, LCX, and Coinbase. Handles order placement, cancellation, balance queries.

### Supported Exchanges

| Exchange | API Status | Auth | Features |
|----------|-----------|------|----------|
| **Kraken** | Ready | HMAC-SHA256 | Market, Limit, Post-only |
| **LCX** | Ready | API Key | Market, Limit, Post-only |
| **Coinbase** | Ready | HMAC-SHA256 + Passphrase | Market, Limit, Post-only |

### Key Structures

**CexId**:
```zig
pub const CexId = enum(u8) {
    KRAKEN = 0,
    LCX = 1,
    COINBASE = 2,
};
```

**CexOrderResponse**:
```zig
pub const CexOrderResponse = struct {
    success: bool,
    order_id: [32]u8,          // CEX-assigned ID
    status: enum { ACCEPTED, REJECTED, ERROR },
    error_message: [128]u8,
    timestamp: u64,
};
```

**CexBalance**:
```zig
pub const CexBalance = struct {
    asset: [16]u8,             // "XBT", "USD", "ETH"
    free: i64,
    locked: i64,
    total: i64,
};
```

### Exchange-Specific Functions

#### Kraken
```zig
kraken_submit_order(symbol, side, order_type, price, quantity) → CexOrderResponse
kraken_cancel_order(order_id) → bool
kraken_get_balance() → [32]CexBalance
kraken_get_ticker(symbol) → CexTicker
kraken_sign_request(nonce, post_data, api_secret) → [64]u8
```

#### LCX
```zig
lcx_submit_order(symbol, side, order_type, price, quantity) → CexOrderResponse
lcx_cancel_order(order_id) → bool
lcx_get_balance() → [32]CexBalance
```

#### Coinbase
```zig
coinbase_submit_order(symbol, side, order_type, price, quantity) → CexOrderResponse
coinbase_cancel_order(order_id) → bool
coinbase_get_balance() → [32]CexBalance
coinbase_sign_request(timestamp, method, path, body, api_secret) → [64]u8
```

### Connection Pool

```zig
pub const CexConnectionPool = struct {
    accounts: [3]CexAccount,    // One per exchange
    account_count: u8,
};

// Initialize
pool = cex_interface.init_cex_pool();

// Register credentials
cex_interface.register_cex_credentials(
    &pool,
    .KRAKEN,
    api_key,
    api_secret,
    api_passphrase,
);

// Sync balances across all connected exchanges
cex_interface.sync_all_balances(&pool, timestamp);
```

### Example Usage

```zig
// Submit order to Kraken
var response = cex_interface.submit_order_to_cex(
    .KRAKEN,
    "XBTUSDT",
    .BUY,
    .LIMIT,
    50000_00,
    1,
);

if (response.success) {
    std.debug.print("Order ID: {s}\n", .{response.order_id});
} else {
    std.debug.print("Error: {s}\n", .{response.error_message});
}
```

---

## Integration Flow

### Complete Trading Cycle

```
1. GridBotEngine detects favorable conditions
   └─→ Calculates order price & quantity

2. Create local order in OrderBook
   └─→ order_id = 1 (local tracking)

3. MarketMaker adjusts for inventory
   └─→ May widen/narrow spreads

4. Submit order via CEX Interface
   └─→ Kraken/LCX/Coinbase placement
   └─→ Receive cex_order_id from exchange

5. Update local order with CEX ID
   └─→ Link local ID to exchange ID

6. Monitor fills via market data
   └─→ Check candles for fill conditions

7. Record fill in OrderBook
   └─→ Update quantity, fees, P&L

8. GridBotEngine reposts if needed
   └─→ Loop back to step 2
```

### Code Example

```zig
// Initialize systems
var orderbook = orderbook_local.init_orderbook();
var engine = gridbot_engine.init_gridbot_engine(grid_config);
var mm = market_maker.init_market_maker(mm_config, &orderbook);
var pool = cex_interface.init_cex_pool();

// Register CEX credentials
cex_interface.register_cex_credentials(&pool, .KRAKEN, key, secret, pass);

// Main trading loop
while (true) {
    // Get market data
    var market_data = fetch_candles();
    var current_price = market_data.candles[market_data.candle_count - 1].close;
    var timestamp = get_timestamp();

    // Run GridBotEngine cycle
    gridbot_engine.gridbot_engine_cycle(&engine, &market_data, current_price, timestamp);

    // Place new orders to CEX
    for (0..engine.grid_state.grid_count) |i| {
        var grid_level = &engine.grid_state.grids[i];
        if (grid_level.status == .BUY_PENDING) {
            // Create local order
            const local_id = orderbook_local.create_order(
                &orderbook, 0, "XBTUSDT", .BUY, .POSTONLY,
                grid_level.buy_deviated_price,
                grid_level.buy_quantity, timestamp
            );

            // Submit to CEX
            var response = cex_interface.submit_order_to_cex(
                .KRAKEN,
                "XBTUSDT",
                .BUY,
                .POSTONLY,
                grid_level.buy_deviated_price,
                grid_level.buy_quantity,
            );

            if (response.success) {
                // Link local to CEX order
                orderbook_local.set_cex_order_id(&orderbook, local_id, response.order_id);
            }
        }
    }

    // Process any fills (would come from WebSocket in production)
    // For now, simulate from candle data

    // Market maker cycle
    const volatility = 200; // Placeholder
    market_maker.market_maker_cycle(&mm, current_price, volatility, timestamp);
}
```

---

## CEX API Implementation Status

### Kraken
- ✅ Structure defined
- 📝 TODO: Implement REST client (HMAC-SHA256)
- 📝 TODO: Parse JSON responses

### LCX
- ✅ Structure defined
- 📝 TODO: Implement REST client
- 📝 TODO: Handle LCX-specific response format

### Coinbase
- ✅ Structure defined
- 📝 TODO: Implement REST client (CB-ACCESS-SIGN)
- 📝 TODO: WebSocket for fills

---

## Performance & Reliability

### Local OrderBook Tracking
- **Storage**: 4,096 order slots (~64KB)
- **Lookup**: O(n) for find, O(1) for aggregation
- **Fill detection**: O(512) grid levels per cycle

### Market Maker
- **Rebalancing**: Automatic when inventory deviates >threshold%
- **Spread adaptation**: Calculated per cycle based on volatility
- **Order management**: Cancel-and-replace or amendment

### CEX Interface
- **Rate limits**: Handled by connection pool
- **Retries**: Application-level (TODO)
- **Authentication**: Pre-signed requests queued

---

## Security Considerations

### API Credentials
- Store in secure vault (not hardcoded)
- Rotate regularly per CEX policy
- Use separate keys per environment (dev/prod)

### Order Signing
- HMAC-SHA256 for Kraken & Coinbase
- Nonce/timestamp to prevent replay
- SSL/TLS for all API calls

### Risk Management
- Position limits enforced by `max_inventory`
- Order size limits via `max_order_size`
- Rebalance thresholds prevent runaway positions

---

## Next Steps

1. **Implement HTTP client** – Actually call CEX APIs
2. **Add WebSocket support** – Real-time fill notifications
3. **Error handling** – Retry logic, circuit breakers
4. **Performance optimization** – Caching, connection pooling
5. **Multi-symbol support** – Trade multiple pairs in parallel

---

**Last Updated**: 2026-03-12
**Version**: CEX Integration v1.0
**Status**: Framework complete, API stubs ready for implementation
