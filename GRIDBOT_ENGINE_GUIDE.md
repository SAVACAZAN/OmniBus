# GridBotEngine: Active Order Lifecycle Management Library

## Overview

GridBotEngine is an advanced trading library that transforms passive grid definitions into active, self-managing order systems. Unlike basic grid placement, GridBotEngine:

1. **Tracks Order Fills** – Monitors when grid levels get filled
2. **Detects Price Evolution** – Analyzes market trends and volatility
3. **Automatically Reposts** – Moves filled orders to new price levels
4. **Adapts Quantities** – Scales order sizes based on market conditions
5. **Shifts Grid Dynamically** – Repositions the entire grid to follow price movement

---

## Core Concepts

### Order Lifecycle

Every grid order follows a lifecycle:

```
IDLE → PENDING → FILLED → (repost) → PENDING → FILLED → ...
```

**States**:
- **IDLE**: Not yet posted to the market
- **PENDING**: Posted, waiting for fill
- **FILLED**: Matched at desired price level
- **CANCELLED**: Manually cancelled
- **EXPIRED**: Timeout in repost window exceeded

### Price Evolution Tracking

GridBotEngine continuously monitors:
- **Trend**: UP / DOWN / NEUTRAL (vs 20-candle MA)
- **Volatility**: Intra-candle price range as basis points
- **High/Low 24h**: Price extremes for range calculations
- **Moving Average**: 20-candle MA for baseline

This data drives reposting decisions:
- **Uptrend**: Less aggressive reposting (wider levels)
- **Downtrend**: More aggressive reposting (tighter levels)
- **High volatility**: Larger price distances between reposts

### Filled Order Tracking

Maintains detailed history per filled order:
```zig
pub const FilledOrder = struct {
    order_id: u32,              // Original order ID
    grid_index: u16,            // Which grid level
    side: enum { BUY, SELL },   // Order direction
    entry_price: i64,           // Price at fill
    quantity: i64,              // Amount filled
    fill_time: u64,             // When filled
    repost_count: u8,           // How many times reposted
    accumulated_pnl: i64,       // P&L from this grid level
};
```

---

## Key Functions

### Price Evolution Detection

```zig
pub fn detect_price_evolution(
    market_data: *const bot.MarketData,
    current_price: i64,
) PriceEvolution
```

**Input**: Market candles + current price
**Output**: Trend, volatility, moving averages

**Used by**: Reposting logic to adjust price distances and aggressiveness

**Example**:
```zig
var evolution = gridbot_engine.detect_price_evolution(&market_data, 50000_00);
// evolution.trend = .UP
// evolution.volatility = 250 (2.5% intra-candle range)
```

---

### Order Fill Detection

```zig
pub fn check_order_fill(
    grid_level: *const grid.GridLevel,
    latest_candle: *const bot.Candle,
) bool
```

**Logic**:
- **BUY order**: Filled if `candle.low <= grid_level.buy_deviated_price`
- **SELL order**: Filled if `candle.high >= grid_level.sell_deviated_price`

**Used by**: `gridbot_engine_cycle()` to detect fills on every candle

---

### Recording Filled Orders

```zig
pub fn record_filled_order(
    engine_state: *GridBotEngineState,
    grid_index: u16,
    grid_level: *const grid.GridLevel,
    fill_price: i64,
    timestamp: u64,
) bool
```

Stores filled order in tracking array for later reposting.

---

### Repost Price Calculation

```zig
pub fn calculate_repost_price(
    entry_price: i64,
    side: enum { BUY, SELL },
    price_evolution: *const PriceEvolution,
    repost_count: u8,
) i64
```

**Algorithm**:
```
base_distance = (entry_price * 50) / 10000           // 0.5% base
base_distance *= (100 + repost_count * 10) / 100     // Increase per repost (+1% each)
volatility_adjustment = volatility * base_distance / 10000
trend_bias = volatility_adjustment * trend_factor    // UP: /2, DOWN: ×1

For BUY:  new_price = entry_price - base_distance - trend_bias
For SELL: new_price = entry_price + base_distance + trend_bias
```

**Example**: Entry at 50,000 USD, uptrend, 2% volatility, 2nd repost:
```
base_distance = (50000 * 50) / 10000 = 250
base_distance *= 120 / 100 = 300
volatility_adjustment = 200 * 300 / 10000 = 6
trend_bias = 6 / 2 = 3 (uptrend)
BUY repost price = 50000 - 300 - 3 = 49,697
SELL repost price = 50000 + 300 + 3 = 50,303
```

---

### Repost Quantity Calculation

```zig
pub fn calculate_repost_quantity(
    original_quantity: i64,
    repost_count: u8,
    amount_deviation: i64,
) i64
```

**Algorithm**:
```
quantity = original_quantity
For each repost: quantity *= 98 / 100     // 2% smaller each time
Apply amount_deviation: quantity *= (10000 + amount_deviation) / 10000
```

**Effect**: Orders get progressively smaller on each repost (less aggressive), but adjusted by amount_deviation.

---

### Reposting Orders

```zig
pub fn repost_filled_order(
    engine_state: *GridBotEngineState,
    filled_order_index: u16,
    current_price: i64,
    new_order_id: u32,
    timestamp: u64,
) bool
```

**Steps**:
1. Calculate new price based on price evolution
2. Calculate new quantity with decay and deviation
3. Update grid level with new order parameters
4. Mark order as PENDING again
5. Track P&L from the repost price

---

### Grid Shifting

```zig
pub fn should_shift_grid(
    engine_state: *const GridBotEngineState,
    current_price: i64,
) bool
```

Shifts grid when price moves beyond 25% of grid range from center.

```zig
pub fn shift_grid_to_price(
    engine_state: *GridBotEngineState,
    current_price: i64,
) void
```

Repositions entire grid around current price with margins.

---

### Main Engine Cycle

```zig
pub fn gridbot_engine_cycle(
    engine_state: *GridBotEngineState,
    market_data: *const bot.MarketData,
    current_price: i64,
    timestamp: u64,
) void
```

**Execution Order** (every cycle):
1. Update price evolution from latest candle
2. Check all pending orders for fills
3. Repost eligible filled orders (oldest first, limited to 16/cycle)
4. Check if grid should shift position
5. Place new orders from grid definition

---

## Usage Example

### Simple Buy-and-Repost Strategy

```zig
// Setup
var config = grid_bot.create_buyonly_config(
    .symbol = "BTC/USD",
    .lower_price = 40_000_00,
    .upper_price = 50_000_00,
    .total_amount = 1_000_000_00,  // 10 BTC
    .deviation_price = 50,  // 0.5% discount on buys
);

var engine = gridbot_engine.init_gridbot_engine(config);
engine.repost_interval = 5;  // Repost after 5 cycles

// Main trading loop
while (trading) {
    // Get fresh market data
    var market_data = fetch_candles();
    var current_price = market_data.candles[market_data.candle_count - 1].close;
    var timestamp = get_timestamp();

    // Run engine cycle
    gridbot_engine.gridbot_engine_cycle(&engine, &market_data, current_price, timestamp);

    // Check stats
    var stats = gridbot_engine.get_repost_stats(&engine);
    std.debug.print("Reposts: {}, Active Orders: {}, PnL: {}\n",
        .{ stats.total_reposts, stats.active_orders, stats.total_repost_pnl });
}
```

### Balanced Buy+Sell Strategy

```zig
var config = grid_bot.create_balanced_config(
    .symbol = "ETH/USD",
    .lower_price = 1_500_00,
    .upper_price = 2_500_00,
    .total_amount = 500_000,
    .buy_deviation = 50,   // 0.5% discount on buys
    .sell_deviation = 30,  // 0.3% premium on sells
);

var engine = gridbot_engine.init_gridbot_engine(config);
engine.repost_interval = 10;  // Slower reposting for balanced strategy

// Run same cycle...
```

---

## Performance Metrics

### RepostStats Structure

```zig
pub const RepostStats = struct {
    total_filled: u16,              // Orders that have been filled at least once
    total_reposts: u32,             // Total number of repost operations
    avg_reposts_per_order: i64,     // Average (in 100ths, divide by 100)
    total_repost_pnl: i64,          // Cumulative P&L from reposting
    active_orders: u16,             // Currently pending orders
};

pub fn get_repost_stats(engine_state: *const GridBotEngineState) RepostStats
```

**Example Output**:
```
total_filled: 42
total_reposts: 127
avg_reposts_per_order: 302  (÷100 = 3.02 reposts/order)
total_repost_pnl: 850_000   (8,500 USD in repost profits)
active_orders: 18
```

---

## Configuration Reference

### GridBotEngineState Fields

```zig
grid_state: grid.GridBotState,      // Underlying grid definition
filled_orders: [256]FilledOrder,    // History of filled orders
filled_order_count: u16,            // How many orders have filled
price_evolution: PriceEvolution,    // Current market analysis
last_repost_time: u64,              // Timestamp of last repost
repost_interval: u64,               // Minimum cycles between reposts (default: 10)
total_reposts: u32,                 // Lifetime repost count
repost_pnl: i64,                    // Cumulative P&L from reposting
```

### Tuning Parameters

| Parameter | Purpose | Range | Default |
|-----------|---------|-------|---------|
| `repost_interval` | Min cycles between reposts | 5-100 | 10 |
| `max_reposts_per_cycle` | Repost rate limiter | 5-50 | 16 |
| `max_repost_count` | Max reposts per order | 5-20 | 10 |
| `quantity_decay` | Reduction per repost | 95-99% | 98% |

---

## Trade Dynamics

### Buy-Only Accumulation Pattern

**Goal**: Accumulate coins as price dips

**Configuration**:
```zig
grid_side = .BUY_ONLY
deviation_price_buy = 50-100    // Aggressive discount
repost_interval = 5              // Fast reposting
```

**What Happens**:
1. Buy orders placed at grid levels below current price
2. When filled, order reposts 0.5% + margin below original entry
3. If price stays low, multiple reposts accumulate more coins
4. If price rallies, stop reposting (no new fills available)

**P&L**: Accumulated coin position grows, costs driven down by reposting

---

### Range Trading Pattern

**Goal**: Buy at support, sell at resistance, profit from bounces

**Configuration**:
```zig
grid_side = .BOTH
deviation_price_buy = 50
deviation_price_sell = 30
repost_interval = 10
```

**What Happens**:
1. Buy orders below price, sell orders above price
2. Buy fills → accumulates coins
3. Sell fills → distributes coins at higher prices
4. Both reposts independently based on price evolution
5. Profit = (sell_price - buy_price) × quantity, minus fees

**P&L**: Repeating small profits from bounces within range

---

### Dynamic Grid Shifting

**Trigger**: Price moves beyond 25% of grid range from center

**Action**:
1. Detects trend change (uptrend/downtrend)
2. Shifts entire grid to new price center
3. Preserves filled order tracking
4. Continues reposting from new positions

**Effect**: Keeps orders "relevant" even if market moves significantly

---

## Integration with Grid OS

GridBotEngine prepares orders for dispatch to Grid OS (0x110000):

1. **order_id** – Sent to Grid OS for placement
2. **deviated_price** – Final price for order book submission
3. **quantity** – Final size for order book
4. **side** – BUY or SELL direction

Each `gridbot_engine_cycle()` produces orders ready for:
```zig
// Pseudo-code
grid_os.place_order(grid_level.buy_order_id, grid_level.buy_deviated_price, grid_level.buy_quantity, .BUY);
```

---

## Performance Considerations

### Memory Usage
- **256 filled order records** = ~6KB
- **512 grid levels** = ~8KB
- **Total engine state** = ~15KB

### CPU per Cycle
- Price evolution detection: O(n) where n = lookback period (24 candles)
- Fill detection: O(512) grid levels checked
- Reposting: Limited to 16/cycle, so O(16) average
- Grid shift: O(512) if triggered

**Expected cycle time**: <1ms on modern CPU

---

## Troubleshooting

### Orders not reposting
- Check `repost_interval` – may be too high
- Verify `calculate_repost_price()` is moving far enough from entry
- Ensure market data candles are being updated

### P&L not tracking correctly
- Confirm `accumulated_pnl` calc in `repost_filled_order()`
- Check that `price_evolution.trend` is being detected (requires MA calculation)
- Verify entry/exit prices in `FilledOrder` records

### Grid not shifting
- Check `should_shift_grid()` threshold (25% of range)
- Verify `current_price` is being passed correctly
- Ensure grid range is wide enough to trigger shift

---

## Next Steps

1. **Real Order Submission** – Integrate with Grid OS IPC for live order placement
2. **Advanced Repost Logic** – Add support for:
   - Time-weighted reposting (slower as inventory accumulates)
   - Volatility-adapted distances (wider in choppy markets)
   - ML-predicted price levels
3. **Multi-Symbol Support** – Run multiple GridBotEngine instances in parallel
4. **Position Management** – Add TP/SL targeting integrated with repost logic

---

**Last Updated**: 2026-03-12
**Version**: GridBotEngine v1.0
**Status**: Compiled & Ready for Grid OS Integration
