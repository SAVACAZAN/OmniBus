# Cross-Module Communication Protocol
## Grid OS ↔ NeuroOS Optimization Feedback Loop

---

## Architecture Overview

```
Grid OS (0x110000)               NeuroOS (0x2D0000)
├─ Trading state                 ├─ Population (100 individuals)
├─ Active orders                 ├─ Fitness scores
├─ Trade history                 ├─ Current best parameters
└─ Performance metrics ──────────→ (read metrics for fitness calc)
                                 │
                                 └─→ Optimized parameters
                                        (write back evolved params)
                ↑─────────────────────────┘
```

---

## Shared Memory Layout

### Grid OS Metrics Export (0x120000, 256 bytes)
```c
struct GridMetricsExport {
    u64 total_profit;           // Total realized profit (USD)
    u64 winning_trades;         // Number of profitable trades
    u64 losing_trades;          // Number of losing trades
    u64 total_trades;           // Total trades executed
    f64 max_drawdown;           // Maximum drawdown (fraction)
    f64 win_rate;               // Win rate (0.0-1.0)
    f64 sharpe_ratio;           // Sharpe ratio
    u64 timestamp;              // Last update timestamp (TSC)
    u8  valid;                  // Flag: metrics are current (1=valid, 0=stale)
    u8  _pad[39];               // Padding to 128 bytes
};
```

### NeuroOS Parameters Export (0x120080, 256 bytes)
```c
struct NeuroParametersExport {
    f64 grid_spacing;           // Optimal grid spacing (basis points)
    f64 rebalance_trigger;      // Rebalance threshold (%)
    f64 order_size;             // Optimal order size (USD)
    f64 position_max;           // Maximum position size
    u64 generation;             // Generation count when params evolved
    u64 timestamp;              // Last update timestamp (TSC)
    u8  valid;                  // Flag: parameters are evolved (1=ready, 0=pending)
    u8  _pad[49];               // Padding to 128 bytes
};
```

---

## Communication Protocol

### Phase 1: Grid OS exposes metrics (passive)
1. Grid OS continuously updates shared memory @ 0x120000
2. Sets `valid = 1` when metrics are fresh
3. Updates `timestamp` with TSC counter
4. NeuroOS reads from this location

### Phase 2: NeuroOS reads + evolves
1. Scheduler triggers NeuroOS every 512 cycles
2. NeuroOS reads Grid metrics @ 0x120000
3. Incorporates profit/win_rate into fitness function
4. Evolves population against actual trading performance
5. Selects best individual parameters

### Phase 3: NeuroOS writes optimized parameters
1. NeuroOS writes best_individual to 0x120080
2. Sets `valid = 1` when parameters are ready
3. Updates `timestamp` with generation count

### Phase 4: Grid OS reads + applies parameters
1. Scheduler asks Grid OS to update from 0x120080
2. Grid OS reads `valid` flag
3. If `valid == 1`, applies new parameters
4. Updates internal grid_spacing, rebalance_trigger, etc.
5. Sets `valid = 0` to acknowledge receipt

---

## Implementation Roadmap

### Phase 11: Grid Metrics Export
- Grid OS: Export trading metrics to 0x120000
- Scheduler: Trigger on every cycle (always available)
- Size: ~128 bytes

### Phase 12: NeuroOS Metrics Integration
- NeuroOS: Read Grid metrics in fitness calculation
- Update `evaluate_fitness()` to include Grid win_rate + profit
- Multi-objective: GA evolves against real trading data

### Phase 13: Parameter Feedback Loop
- Grid OS: Add parameter update handler
- Read from 0x120080 when triggered
- Apply evolved parameters to next trading cycle

### Phase 14: Synchronization & Timing
- Add generation/cycle counter to both modules
- Ensure Grid+Neuro stay in sync
- Prevent race conditions with validity flags

---

## Benefits

1. **Closed-loop optimization**: NeuroOS evolves directly against trading performance
2. **No module execution**: Uses memory-mapped data, not function calls
3. **Asynchronous**: Grid and Neuro work independently, synchronize via shared memory
4. **Scalable**: Easy to add other modules (e.g., Analytics → Grid metrics)

---

## Example Data Flow

```
Cycle 1-255:   Grid OS trades, accumulates profit
Cycle 256:     NeuroOS reads Grid metrics, updates fitness scores
Cycle 257-511: Grid continues with old parameters
Cycle 512:     NeuroOS evolves population, writes best parameters → 0x120080
Cycle 513:     Grid OS reads evolved parameters, applies them
Cycle 514+:    Grid trades with optimized parameters
```

This creates a continuous feedback loop where NeuroOS improves Grid performance over time.
