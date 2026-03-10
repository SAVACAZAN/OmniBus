// historical_analytics_os.zig — Time-series metrics collection
// L16: Historical data aggregation for charting and analysis
// Memory: 0x370000–0x37FFFF (64KB)

const std = @import("std");
const types = @import("historical_analytics_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getHistoricalStatePtr() *volatile types.HistoricalAnalyticsState {
    return @as(*volatile types.HistoricalAnalyticsState, @ptrFromInt(types.HIST_ANALYTICS_BASE));
}

fn getHistoryBuffer() [*]volatile types.HistoryPoint {
    // History buffer starts at offset 128 (after state struct)
    return @as([*]volatile types.HistoryPoint, @ptrFromInt(types.HIST_ANALYTICS_BASE + 128));
}

fn getGridStatePtr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(0x110000));
}

fn getOmniStructPtr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(0x400000));
}

fn getChecksumStatePtr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(0x310000));
}

fn getAutorepairStatePtr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(0x320000));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Historical Analytics OS
export fn init_plugin() void {
    if (initialized) return;

    const state = getHistoricalStatePtr();
    state.* = .{
        .magic = 0x48495354, // "HIST"
        .flags = 0x01,
        .cycle_count = 0,
        .history_head = 0,
        .history_count = 0,
        .aggregate_window_cycles = types.getDefaultAggregationWindow(),
        .aggregate_cycle_counter = 0,
        .total_points_recorded = 0,
        .last_aggregation_tsc = 0,
        .max_profit_pnl = 0,
        .min_profit_pnl = 0,
        .max_spread_bps = 0,
        .avg_spread_bps = 0,
        .profit_trend = 0,
        .spread_trend = 0,
        .health_trend = 0,
        .csv_export_ready = 0,
        .json_export_ready = 0,
        .last_export_cycle = 0,
        .escalation_triggered = 0,
        .escalation_reason = 0,
    };

    // Zero-initialize history buffer
    const buffer = getHistoryBuffer();
    var i: u32 = 0;
    while (i < types.MAX_HISTORY_POINTS) : (i += 1) {
        buffer[i].timestamp_ms = 0;
        buffer[i].grid_profit_pnl = 0;
        buffer[i].grid_active_orders = 0;
        buffer[i].best_spread_bps = 0;
        buffer[i].checksum_failures = 0;
        buffer[i].autorepair_repairs = 0;
        buffer[i].param_changes = 0;
        buffer[i].zorin_violations = 0;
        buffer[i].system_health = 0;
        buffer[i].cpu_cycles = 0;
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Collect and aggregate historical data
// ============================================================================

/// Run Historical Analytics cycle - collect metrics and update time-series
export fn run_historical_analytics_cycle() void {
    if (!initialized) return;

    const state = getHistoricalStatePtr();
    cycle_count += 1;
    state.cycle_count = cycle_count;

    // Increment aggregation counter
    state.aggregate_cycle_counter += 1;

    // Check if it's time to aggregate
    if (state.aggregate_cycle_counter >= state.aggregate_window_cycles) {
        state.aggregate_cycle_counter = 0;

        // Collect current metrics from other OS layers
        const point = collectMetricsSnapshot();

        // Add to ring buffer
        const max_points: u16 = @as(u16, @intCast(types.MAX_HISTORY_POINTS));
        if (state.history_count < max_points) {
            state.history_count += 1;
        }

        const buffer = getHistoryBuffer();
        buffer[state.history_head] = point;

        // Advance head pointer (ring buffer wraps)
        state.history_head = (state.history_head + 1) % max_points;
        state.total_points_recorded += 1;
        state.last_aggregation_tsc = cycle_count * 1000;

        // Update trend analysis
        updateTrends(state);

        // Mark export buffers as ready
        state.csv_export_ready = 1;
        state.json_export_ready = 1;
    }
}

fn collectMetricsSnapshot() types.HistoryPoint {
    const point: types.HistoryPoint = .{
        .timestamp_ms = cycle_count * 1, // Rough timestamp (1ms per cycle assumed)
        .grid_profit_pnl = 0,
        .grid_active_orders = 0,
        .best_spread_bps = 0,
        .checksum_failures = 0,
        .autorepair_repairs = 0,
        .param_changes = 0,
        .zorin_violations = 0,
        .system_health = 0,
        .cpu_cycles = 0,
    };

    // Read Grid OS metrics @ 0x110000 + offset
    // This is simplified; real implementation would parse Grid state structure
    const grid_ptr = getGridStatePtr();
    // In a real implementation, would check grid_ptr.* and update point fields
    if (grid_ptr.* == 0) {
        // Grid OS not initialized yet
    }

    // Read Checksum OS failures @ 0x310000 + offset
    const checksum_ptr = getChecksumStatePtr();
    // In a real implementation, would check checksum_ptr.* and update point fields
    if (checksum_ptr.* == 0) {
        // Checksum OS not initialized yet
    }

    // Read AutoRepair OS repairs @ 0x320000 + offset
    const autorepair_ptr = getAutorepairStatePtr();
    // In a real implementation, would check autorepair_ptr.* and update point fields
    if (autorepair_ptr.* == 0) {
        // AutoRepair OS not initialized yet
    }

    return point;
}

fn updateTrends(state: *volatile types.HistoricalAnalyticsState) void {
    const max_points: u16 = @as(u16, @intCast(types.MAX_HISTORY_POINTS));

    // Simple trend detection: compare last few points
    if (state.history_count >= 2) {
        const buffer = getHistoryBuffer();
        const current_idx = if (state.history_head > 0) state.history_head - 1 else max_points - 1;
        const prev_idx = if (current_idx > 0) current_idx - 1 else max_points - 1;

        const current = buffer[current_idx];
        const prev = buffer[prev_idx];

        // Profit trend
        if (current.grid_profit_pnl > prev.grid_profit_pnl) {
            state.profit_trend = 1; // Up
        } else if (current.grid_profit_pnl < prev.grid_profit_pnl) {
            state.profit_trend = -1; // Down
        } else {
            state.profit_trend = 0; // Flat
        }

        // Spread trend
        if (current.best_spread_bps > prev.best_spread_bps) {
            state.spread_trend = 1; // Up (wider spreads)
        } else if (current.best_spread_bps < prev.best_spread_bps) {
            state.spread_trend = -1; // Down (tighter spreads)
        } else {
            state.spread_trend = 0; // Flat
        }

        // Update min/max
        if (current.grid_profit_pnl > state.max_profit_pnl) {
            state.max_profit_pnl = current.grid_profit_pnl;
        }
        if (current.grid_profit_pnl < state.min_profit_pnl) {
            state.min_profit_pnl = current.grid_profit_pnl;
        }
        if (current.best_spread_bps > state.max_spread_bps) {
            state.max_spread_bps = current.best_spread_bps;
        }

        // Calculate average spread
        if (state.history_count > 0) {
            var sum: u32 = 0;
            var i: u16 = 0;
            while (i < state.history_count) : (i += 1) {
                const idx = (state.history_head + i) % max_points;
                sum += buffer[idx].best_spread_bps;
            }
            state.avg_spread_bps = @as(u16, @intCast(sum / state.history_count));
        }
    }
}

// ============================================================================
// Public API: Data Retrieval
// ============================================================================

/// Get historical point at index (0 = oldest in buffer, count-1 = newest)
export fn get_history_point(index: u16) types.HistoryPoint {
    const max_points: u16 = @as(u16, @intCast(types.MAX_HISTORY_POINTS));
    if (index >= max_points) {
        return .{
            .timestamp_ms = 0,
            .grid_profit_pnl = 0,
            .grid_active_orders = 0,
            .best_spread_bps = 0,
            .checksum_failures = 0,
            .autorepair_repairs = 0,
            .param_changes = 0,
            .zorin_violations = 0,
            .system_health = 0,
            .cpu_cycles = 0,
        };
    }

    const state = getHistoricalStatePtr();
    const buffer = getHistoryBuffer();

    // Calculate actual index in ring buffer
    if (index < state.history_count) {
        const actual_idx = (state.history_head + index) % max_points;
        return buffer[actual_idx];
    }

    return .{
        .timestamp_ms = 0,
        .grid_profit_pnl = 0,
        .grid_active_orders = 0,
        .best_spread_bps = 0,
        .checksum_failures = 0,
        .autorepair_repairs = 0,
        .param_changes = 0,
        .zorin_violations = 0,
        .system_health = 0,
        .cpu_cycles = 0,
    };
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_history_count() u16 {
    const state = getHistoricalStatePtr();
    return state.history_count;
}

export fn get_total_points_recorded() u64 {
    const state = getHistoricalStatePtr();
    return state.total_points_recorded;
}

export fn get_max_profit_pnl() i32 {
    const state = getHistoricalStatePtr();
    return state.max_profit_pnl;
}

export fn get_min_profit_pnl() i32 {
    const state = getHistoricalStatePtr();
    return state.min_profit_pnl;
}

export fn get_max_spread_bps() u16 {
    const state = getHistoricalStatePtr();
    return state.max_spread_bps;
}

export fn get_avg_spread_bps() u16 {
    const state = getHistoricalStatePtr();
    return state.avg_spread_bps;
}

export fn get_profit_trend() i8 {
    const state = getHistoricalStatePtr();
    return state.profit_trend;
}

export fn get_spread_trend() i8 {
    const state = getHistoricalStatePtr();
    return state.spread_trend;
}

export fn get_health_trend() i8 {
    const state = getHistoricalStatePtr();
    return state.health_trend;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
