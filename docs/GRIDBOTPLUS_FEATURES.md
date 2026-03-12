# GridBotPlus: Advanced Grid Trading Features

## Overview

GridBotPlus extends the core GridBot engine with advanced trading features for sophisticated grid-based strategies:
1. **Side-Specific Deviation** – Separate price adjustments for buy vs sell orders
2. **Grid Side Configuration** – Choose buy-only, sell-only, or balanced grids
3. **Amount Deviation** – Dynamic quantity scaling per grid level and side
4. **Dynamic Grid Increment** – Incremental sizing that adapts to market conditions

---

## Feature Details

### 1. Side-Specific Deviation

**Problem**: Standard deviation applies equally to all orders, but buying and selling have different dynamics:
- BUY orders: You want lower prices (attractive entries) → deviation subtracts
- SELL orders: You want higher prices (attractive exits) → deviation adds

**Solution**: Separate deviation values for each side.

**Configuration Fields**:
```zig
deviation_price_buy: i64,    // Basis points for buy-side price deviation
deviation_price_sell: i64,   // Basis points for sell-side price deviation
```

**Example**:
- Grid level at 50,000 USD
- `deviation_price_buy = 50` (0.5% discount)
- `deviation_price_sell = 30` (0.3% premium)
- Buy order placed at: 50,000 - (50,000 × 0.5% / 2) = 49,875 USD (better entry)
- Sell order placed at: 50,000 + (50,000 × 0.3% / 2) = 50,075 USD (better exit)

---

### 2. Grid Side Configuration

**Problem**: Sometimes you only want to accumulate (BUY) or distribute (SELL), not both.

**Solution**: `grid_side` enum controls order placement behavior.

**Configuration**:
```zig
grid_side: enum { BUY_ONLY, SELL_ONLY, BOTH } = .BOTH
```

**Behaviors**:

| Mode | Below Current Price | Above Current Price | Use Case |
|------|---------------------|---------------------|----------|
| **BUY_ONLY** | Place BUY orders | No SELL orders | Accumulation phase |
| **SELL_ONLY** | No BUY orders | Place SELL orders | Distribution phase |
| **BOTH** | Place BUY orders | Place SELL orders | Continuous trading |

**Example**:
```zig
// During a downtrend, only accumulate coins
var config = create_buyonly_config(
    .symbol = "BTC/USD",
    .lower_price = 40_000_00,
    .upper_price = 45_000_00,
    .total_amount = 1_000_000_00,  // 10 BTC worth
    .deviation_price = 50,          // 0.5% discount on buys
);

// Later, during uptrend, only distribute
var config2 = create_sellonly_config(
    .symbol = "BTC/USD",
    .lower_price = 55_000_00,
    .upper_price = 60_000_00,
    .total_amount = 10,  // number of BTC to sell
    .deviation_price = 30,
);
```

---

### 3. Amount Deviation

**Problem**: Quantity per grid might be identical, but market conditions call for different sizing at different levels.

**Solution**: `deviation_amount_buy/sell` scales quantities per grid level.

**Configuration**:
```zig
deviation_amount_buy: i64,   // Basis points for buy-side quantity scaling
deviation_amount_sell: i64,  // Basis points for sell-side quantity scaling
```

**Calculation**:
```
adjusted_quantity = base_quantity * (1 + deviation_amount_percent / 10000)
```

**Example**:
- Base amount: 10 BTC per grid
- `deviation_amount_buy = 100` (1% more per level)
- Grid 1: 10 × 1.01 = 10.1 BTC
- Grid 2: 10 × 1.01 = 10.1 BTC (each grid gets 1% extra)

**Use Case**: Pyramid trading where you want to increase size on dips or decrease on rallies.

---

### 4. Dynamic Grid Increment

**Problem**: Fixed increment (e.g., always 5% more per level) doesn't adapt to actual amount differences.

**Solution**: Enhanced `calc_incremental_quantity()` applies per-side amount deviation.

**Calculation**:
```
quantity[n] = base * (inc_ratio ^ n) * (1 ± amount_deviation)
```

**Example Configuration**:
```zig
.amount_type = .INCREMENTAL_PERCENT,
.inc_buy = 105,                // 5% larger per buy level
.inc_sell = 105,               // 5% larger per sell level
.deviation_amount_buy = 50,    // 0.5% extra scaling for buys
.deviation_amount_sell = 50,   // 0.5% extra scaling for sells
```

**Result**:
- Grid 1: 100 × 1.05 × 1.005 = 105.525 units
- Grid 2: 105.525 × 1.05 × 1.005 = 111.33 units
- Grid 3: 111.33 × 1.05 × 1.005 = 117.55 units

---

## Helper Functions

GridBotPlus provides three configuration builders:

### `create_buyonly_config()`
Builds a buy-only accumulation grid.

```zig
var state = grid_bot.init_grid_bot_state(
    grid_bot.create_buyonly_config(
        .symbol = "BTC/USD",
        .lower_price = 40_000_00,
        .upper_price = 50_000_00,
        .total_amount = 1_000_000_00,
        .deviation_price = 50,  // 0.5% discount
    )
);
```

### `create_sellonly_config()`
Builds a sell-only distribution grid.

```zig
var state = grid_bot.init_grid_bot_state(
    grid_bot.create_sellonly_config(
        .symbol = "ETH/USD",
        .lower_price = 2_000_00,
        .upper_price = 2_500_00,
        .total_amount = 100,  // 100 ETH to distribute
        .deviation_price = 30,  // 0.3% premium
    )
);
```

### `create_balanced_config()`
Builds a balanced buy+sell grid with separate deviations.

```zig
var state = grid_bot.init_grid_bot_state(
    grid_bot.create_balanced_config(
        .symbol = "SOL/USD",
        .lower_price = 100_00,
        .upper_price = 150_00,
        .total_amount = 500_000,
        .buy_deviation = 50,   // 0.5% discount on buys
        .sell_deviation = 30,  // 0.3% premium on sells
    )
);
```

---

## Implementation Details

### Modified Structures

**GridConfig** (bot_strategies.zig):
```zig
pub const GridConfig = struct {
    // ... existing fields ...
    grid_side: enum { BUY_ONLY, SELL_ONLY, BOTH } = .BOTH,
    deviation_price_buy: i64,
    deviation_price_sell: i64,
    deviation_amount_buy: i64,
    deviation_amount_sell: i64,
};
```

**GridLevel** (grid_bot.zig):
```zig
pub const GridLevel = struct {
    // ... existing fields ...
    buy_deviated_price: i64,   // Computed price after buy deviation
    sell_deviated_price: i64,  // Computed price after sell deviation
};
```

### Modified Functions

**apply_deviation()**: Now takes side parameter
```zig
pub fn apply_deviation(
    base_price: i64,
    deviation_percent: i64,
    side: enum { BUY, SELL },
) i64
```
- For BUY: Subtracts deviation (lower price is better)
- For SELL: Adds deviation (higher price is better)

**calc_incremental_quantity()**: Now applies amount deviation
```zig
pub fn calc_incremental_quantity(
    base_amount: i64,
    grid_index: u16,
    inc_ratio: i64,
    amount_deviation_percent: i64,
) i64
```
- Scales quantity by `inc_ratio` per level
- Further scales by `amount_deviation_percent` for dynamic adjustment

**grid_bot_cycle()**: Now respects grid_side
```zig
if (state.config.grid_side == .BUY_ONLY or state.config.grid_side == .BOTH) {
    // Place buy orders
}
if (state.config.grid_side == .SELL_ONLY or state.config.grid_side == .BOTH) {
    // Place sell orders
}
```

---

## Trading Strategies Enabled

### 1. Pyramid Accumulation (BUY_ONLY)
Buy larger amounts as price dips, accumulate inventory for later distribution.
```zig
grid_bot.create_buyonly_config(
    .symbol = "BTC/USD",
    .lower_price = 30_000_00,
    .upper_price = 40_000_00,
    .total_amount = 2_000_000_00,  // 20 BTC allocation
    .deviation_price = 100,  // 1% extra discount per level
)
```

### 2. Dollar-Cost Averaging (BUY_ONLY + INCREMENTAL)
Buy consistent amounts at each level, but with slight scaling.
```zig
grid_bot.create_buyonly_config(
    .symbol = "ETH/USD",
    .lower_price = 1_500_00,
    .upper_price = 2_000_00,
    .total_amount = 500_000,
    .deviation_price = 25,  // Small discount
)
```

### 3. Range Trading (BOTH + BALANCED)
Buy at support levels, sell at resistance levels with geometric grid.
```zig
grid_bot.create_balanced_config(
    .symbol = "SOL/USD",
    .lower_price = 80_00,
    .upper_price = 200_00,
    .total_amount = 1_000_000,
    .buy_deviation = 50,
    .sell_deviation = 40,
)
```

### 4. Position Distribution (SELL_ONLY)
Gradually sell holdings as price rallies, lock in profits at multiple levels.
```zig
grid_bot.create_sellonly_config(
    .symbol = "BTC/USD",
    .lower_price = 60_000_00,
    .upper_price = 70_000_00,
    .total_amount = 5,  // Sell 5 BTC
    .deviation_price = 30,
)
```

---

## Performance Metrics

All GridBotPlus orders maintain:
- **Position tracking** via `accumulated_quantity`
- **Profit/loss tracking** via `pnl` and `fees_paid`
- **Order statistics** via `active_buy_orders` and `active_sell_orders`

Grid rebalancing automatically triggers when accumulated inventory exceeds `buy_back_threshold` (150% by default).

---

## Compilation & Testing

Build the bot_strategies module:
```bash
make build/bot_strategies.bin
```

Expected output:
```
[ZIG] Compiling Bot Strategies to object file...
[LD] Linking Bot Strategies ELF...
[OC] Converting Bot Strategies to binary...
  Bot Strategies binary: build/bot_strategies.bin (size: 185 bytes)
```

---

## Next Steps

1. **IPC Integration** – Route grid orders through Grid OS (0x110000) for actual placement
2. **Real-Time Monitoring** – Feed market data from Analytics OS (0x150000) into grid_bot_cycle()
3. **Extended Strategies** – Add support for:
   - Geometric vs arithmetic grid scaling
   - Price group clustering (priceGroupBuy/Sell)
   - Multi-level take-profit cascades
4. **ML Enhancement** – Use NeuroOS (0x2D0000) to dynamically adjust `deviation_price_buy/sell` based on volatility

---

**Last Updated**: 2026-03-12
**Version**: GridBotPlus v1.0
**Status**: Compiled & Ready for Integration
