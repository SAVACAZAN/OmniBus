// historical_analytics_types.zig — Historical metrics aggregation
// L16: Time-series data collection for dashboards and analysis
// Memory: 0x370000–0x37FFFF (64KB)

pub const HIST_ANALYTICS_BASE: usize = 0x370000;
pub const MAX_HISTORY_POINTS: usize = 256; // 256 data points = ~256 seconds @ 1 point/sec

/// Single historical data point (32 bytes)
pub const HistoryPoint = extern struct {
    timestamp_ms: u64,              // 0  — Kernel timestamp in milliseconds
    grid_profit_pnl: i32,           // 8  — Grid OS profit in satoshis
    grid_active_orders: u16,        // 12 — Number of active orders
    best_spread_bps: u16,           // 14 — Best arbitrage spread in basis points
    checksum_failures: u16,         // 16 — Checksum validation failures this cycle
    autorepair_repairs: u8,         // 18 — Number of repairs attempted
    param_changes: u8,              // 19 — Number of parameter updates
    zorin_violations: u16,          // 20 — Access control violations
    system_health: u8,              // 22 — 0=healthy, 1=degraded, 2=critical
    _pad: u8 = 0,                   // 23 — alignment
    cpu_cycles: u32,                // 24 — CPU cycles used this period
    // = 28 bytes (used), 4 bytes padding
};

/// Historical analytics state (128 bytes @ 0x370000)
pub const HistoricalAnalyticsState = extern struct {
    magic: u32 = 0x48495354,                  // 0  — "HIST" magic
    flags: u8,                                // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,           // 5  — alignment
    cycle_count: u64,                         // 8  — Total cycles executed

    // Ring buffer management
    history_head: u16,                        // 16 — Next write index in ring buffer
    history_count: u16,                       // 18 — Number of points currently stored (0-256)
    _pad2: [4]u8 = [_]u8{0} ** 4,           // 20 — alignment

    // Aggregation window
    aggregate_window_cycles: u32,             // 24 — How often to aggregate (e.g., 256 = aggregate every 256 cycles)
    aggregate_cycle_counter: u32,             // 28 — Counter for aggregation timing

    // Statistics
    total_points_recorded: u64,               // 32 — Total historical points ever recorded
    last_aggregation_tsc: u64,                // 40 — When last aggregation happened

    // Min/Max tracking (for chart scaling)
    max_profit_pnl: i32,                      // 48 — Max profit recorded
    min_profit_pnl: i32,                      // 52 — Min profit (loss) recorded
    max_spread_bps: u16,                      // 56 — Max spread observed
    avg_spread_bps: u16,                      // 58 — Average spread

    // Trend analysis
    profit_trend: i8,                         // 60 — -1=down, 0=flat, 1=up
    spread_trend: i8,                         // 61 — -1=down, 0=flat, 1=up
    health_trend: i8,                         // 62 — -1=degrading, 0=stable, 1=improving
    _pad3: u8 = 0,                           // 63 — alignment

    // Export state
    csv_export_ready: u8,                     // 64 — 0x01 = CSV export buffer ready
    json_export_ready: u8,                    // 65 — 0x01 = JSON export buffer ready
    last_export_cycle: u64,                   // 66 — When last export happened

    // Escalation
    escalation_triggered: u8,                 // 74 — 0x01 = storage full or corruption
    escalation_reason: u8,                    // 75 — Error code
    _pad4: [4]u8 = [_]u8{0} ** 4,           // 76 — alignment

    _pad5: [48]u8 = [_]u8{0} ** 48,         // 80 — reserved
    // = 128 bytes
};

/// Get default aggregation window (every 256 cycles = ~256ms at 1000 Hz)
pub fn getDefaultAggregationWindow() u32 {
    return 256;
}
