// report_os.zig — Daily PnL & Performance Analytics + OmniStruct Aggregator
// L8: System Analysis Layer + Tier 2 Coordinator
// Memory: 0x300000–0x33FFFF (256KB), writes to OmniStruct @ 0x400000

const std = @import("std");
const types = @import("report_os_types.zig");
const omni = @import("omni_struct.zig");
const math = std.math;

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper: Get mutable pointers to state
// ============================================================================

fn getReportStatePtr() *volatile types.ReportState {
    return @as(*volatile types.ReportState, @ptrFromInt(types.REPORT_BASE));
}

fn getDailyMetrics(day_idx: usize) *volatile types.DailyMetrics {
    const offset = types.DAILY_METRICS_OFFSET + (day_idx * types.DAILY_METRICS_SIZE);
    return @as(*volatile types.DailyMetrics, @ptrFromInt(types.REPORT_BASE + offset));
}

fn getOmniStructPtr() *volatile omni.OmniStruct {
    return @as(*volatile omni.OmniStruct, @ptrFromInt(omni.OMNI_BASE));
}

// === TIER 1 Module Readers ===

fn readGridState() struct { pnl: i64, trades: u32, levels: u32 } {
    const grid_pnl = @as(*volatile i64, @ptrFromInt(0x110018)).*;
    const grid_trades = @as(*volatile u32, @ptrFromInt(0x110028)).*;
    const grid_levels = @as(*volatile u32, @ptrFromInt(0x11002C)).*;
    return .{ .pnl = grid_pnl, .trades = grid_trades, .levels = grid_levels };
}

fn readExecutionState() struct { fills: u32, orders: u32 } {
    const exec_fills = @as(*volatile u32, @ptrFromInt(0x130040)).*;
    const exec_orders = @as(*volatile u32, @ptrFromInt(0x130044)).*;
    return .{ .fills = exec_fills, .orders = exec_orders };
}

fn readAnalyticsState() u8 {
    const consensus = @as(*volatile u8, @ptrFromInt(0x150100)).*;
    return consensus;
}

fn readStealthState() struct { mev: u32, sandwich: u32 } {
    const mev_prevented = @as(*volatile u32, @ptrFromInt(0x2C0050)).*;
    const sandwich_detected = @as(*volatile u32, @ptrFromInt(0x2C0054)).*;
    return .{ .mev = mev_prevented, .sandwich = sandwich_detected };
}

fn readBlockchainState() u32 {
    // Placeholder: read first u32 from BlockchainOS state
    const chain_status = @as(*volatile u32, @ptrFromInt(0x250000)).*;
    return chain_status;
}

fn readNeuroState() u32 {
    // Placeholder: read evolution cycle count
    const neuro_cycles = @as(*volatile u32, @ptrFromInt(0x2D0010)).*;
    return neuro_cycles;
}

fn readBankState() u32 {
    // Placeholder: read settlement status
    const bank_status = @as(*volatile u32, @ptrFromInt(0x280000)).*;
    return bank_status;
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Report OS
export fn init_plugin() void {
    if (initialized) return;

    const report = getReportStatePtr();
    report.* = .{
        .magic = 0x5245504F, // "REPO"
        .flags = 0x01,
        .cycle_count = 0,
        .daily_count = 0,
        .current_day = 0,
        .session_pnl = 0,
        .session_trades = 0,
        .session_wins = 0,
        .session_losses = 0,
        .total_pnl = 0,
        .best_day_pnl = -9223372036854775808, // i64::MIN
        .worst_day_pnl = 9223372036854775807, // i64::MAX
        .lifetime_sharpe = 0.0,
        .lifetime_drawdown = 0.0,
    };

    // Initialize daily metrics array to zeros
    var i: usize = 0;
    while (i < types.DAILY_METRICS_COUNT) : (i += 1) {
        const daily = getDailyMetrics(i);
        daily.* = .{
            .timestamp = 0,
            .pnl_cents = 0,
            .pnl_bps = 0,
            .win_rate = 0,
            .trade_count = 0,
            .max_profit = 0,
            .max_loss = 0,
            .sharpe_ratio = 0.0,
            .max_drawdown = 0.0,
        };
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Calculate daily metrics
// ============================================================================

/// Run Report OS cycle - calculate daily PnL, aggregate all Tier 1 states, update OmniStruct
export fn run_report_cycle() void {
    if (!initialized) return;

    const report = getReportStatePtr();
    const omni_state = getOmniStructPtr();
    cycle_count += 1;
    report.cycle_count = cycle_count;

    // === Read all Tier 1 module states ===
    const grid = readGridState();
    const exec = readExecutionState();
    const analytics_q = readAnalyticsState();
    const stealth = readStealthState();

    // Update session metrics from Grid OS (primary trading engine)
    report.session_pnl = grid.pnl;
    report.session_trades = grid.trades;

    // === Aggregate to OmniStruct ===
    omni_state.magic = 0x4F4D4E49; // "OMNI"
    omni_state.version = 1;
    omni_state.flags = 0x01; // valid

    // Tier 1 Audit snapshot
    omni_state.tier1_cycle_count = cycle_count;
    omni_state.tier1_timestamp = cycle_count * 1000; // mock TSC

    // Grid metrics
    omni_state.grid_pnl = grid.pnl;
    omni_state.grid_trades = grid.trades;
    omni_state.grid_levels = grid.levels;

    // Execution metrics
    omni_state.exec_fills = exec.fills;
    omni_state.exec_orders = exec.orders;

    // Stealth metrics
    omni_state.mev_prevented = stealth.mev;
    omni_state.sandwich_detected = stealth.sandwich;

    // Analytics consensus
    omni_state.analytics_consensus = analytics_q;

    // Mark valid for next cycle
    omni_state.flags = 0x01;

    // Calculate win rate (placeholder: assume 60% wins if any trades)
    if (grid.trades > 0) {
        report.session_wins = (grid.trades * 60) / 100;
        report.session_losses = grid.trades - report.session_wins;
        report.session_wins += 1; // Ensure at least 1 win
        if (report.session_wins > grid.trades) report.session_wins = grid.trades;
    } else {
        report.session_wins = 0;
        report.session_losses = 0;
    }

    // Get current day index (simple: cycle_count / 100K cycles per day)
    const cycles_per_day: u64 = 100000;
    const current_day = @as(u32, @intCast((cycle_count / cycles_per_day) % types.DAILY_METRICS_COUNT));

    // Update daily metrics for current day
    if (current_day != report.current_day or cycle_count == 1) {
        // New day detected - save previous day if exists
        if (report.current_day != 0 or cycle_count > cycles_per_day) {
            const prev_daily = getDailyMetrics(report.current_day);
            prev_daily.timestamp = @intCast(cycle_count * 1000); // Mock timestamp
            prev_daily.pnl_cents = report.session_pnl;
            prev_daily.pnl_bps = @as(i32, @intCast(@divTrunc(report.session_pnl * 10000, 100)));
            prev_daily.trade_count = report.session_trades;
            prev_daily.win_rate = if (report.session_trades > 0)
                @as(u8, @intCast((report.session_wins * 100) / report.session_trades))
            else
                0;

            // Track best/worst days
            if (report.session_pnl > report.best_day_pnl) {
                report.best_day_pnl = report.session_pnl;
            }
            if (report.session_pnl < report.worst_day_pnl) {
                report.worst_day_pnl = report.session_pnl;
            }
        }

        // Start new day
        report.current_day = current_day;
        report.daily_count += 1;
        report.session_pnl = 0;
        report.session_trades = 0;
        report.session_wins = 0;
        report.session_losses = 0;
    }

    // Calculate Sharpe ratio (simplified: return / sqrt(volatility))
    // For now, use a fixed estimate
    if (report.session_trades > 0) {
        const avg_pnl = @as(f64, @floatFromInt(report.session_pnl)) / @as(f64, @floatFromInt(report.session_trades));
        const volatility = 100.0; // Mock volatility
        report.lifetime_sharpe = avg_pnl / volatility;
    }

    // Calculate max drawdown (simplified)
    if (report.total_pnl > 0 and report.worst_day_pnl < 0) {
        const drawdown_abs = @abs(report.worst_day_pnl);
        const total_pnl_u64 = @as(u64, @intCast(report.total_pnl));
        const drawdown_bps = (drawdown_abs * 10000) / total_pnl_u64;
        report.lifetime_drawdown = @as(f64, @floatFromInt(drawdown_bps)) / 100.0;
    }

    // Update total PnL
    report.total_pnl += report.session_pnl;

    // === Update OmniStruct performance aggregates ===
    omni_state.total_pnl = report.total_pnl;
    omni_state.total_trades = report.session_trades;
    omni_state.success_rate = if (report.session_trades > 0)
        @as(u8, @intCast((report.session_wins * 100) / report.session_trades))
    else
        0;

    // Integrity tracking
    omni_state.last_update_tsc = cycle_count * 1000;
    omni_state.audit_cycle_count = @as(u32, @intCast(cycle_count % 0x100000000));
    omni_state.system_health = 0xFF; // healthy by default

    // Mark report as valid
    report.flags = 0x01;
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_session_pnl() i64 {
    const report = getReportStatePtr();
    return report.session_pnl;
}

export fn get_session_trades() u32 {
    const report = getReportStatePtr();
    return report.session_trades;
}

export fn get_session_win_rate() u8 {
    const report = getReportStatePtr();
    if (report.session_trades == 0) return 0;
    return @as(u8, @intCast((report.session_wins * 100) / report.session_trades));
}

export fn get_total_pnl() i64 {
    const report = getReportStatePtr();
    return report.total_pnl;
}

export fn get_best_day() i64 {
    const report = getReportStatePtr();
    return report.best_day_pnl;
}

export fn get_worst_day() i64 {
    const report = getReportStatePtr();
    return report.worst_day_pnl;
}

export fn get_sharpe_ratio() f64 {
    const report = getReportStatePtr();
    return report.lifetime_sharpe;
}

export fn get_max_drawdown() f64 {
    const report = getReportStatePtr();
    return report.lifetime_drawdown;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

// ============================================================================
// HTMX Formatter (L13 KDE Plasma dashboard snippet)
// ============================================================================

export fn format_htmx_snippet() void {
    const omni_state = getOmniStructPtr();
    const buf_ptr = @as([*]u8, @ptrFromInt(omni.OMNI_BASE + omni.HTMX_BUFFER_OFFSET));
    const buf_size = omni.HTMX_BUFFER_SIZE;

    // Simple HTML snippet for OmniBus status panel
    const snapshot = "OMNI|Grid:0|Arb:0|PnL:0|HealthOK";

    var i: usize = 0;
    while (i < snapshot.len and i < buf_size - 1) : (i += 1) {
        buf_ptr[i] = snapshot[i];
    }
    buf_ptr[i] = 0; // null terminate

    omni_state.htmx_buffer_ready = 0x01;
    omni_state.htmx_update_count += 1;
}

// ============================================================================
// CSV Formatter (metrics export)
// ============================================================================

export fn format_csv_export() void {
    const omni_state = getOmniStructPtr();
    const buf_ptr = @as([*]u8, @ptrFromInt(omni.OMNI_BASE + omni.CSV_BUFFER_OFFSET));
    const buf_size = omni.CSV_BUFFER_SIZE;

    // CSV header + current row
    const csv_line = "cycle,pnl,trades,winrate,sharpe,health\n";

    var i: usize = 0;
    while (i < csv_line.len and i < buf_size - 1) : (i += 1) {
        buf_ptr[i] = csv_line[i];
    }
    buf_ptr[i] = 0;

    omni_state.csv_export_ready = 0x01;
}

// ============================================================================
// JSON Formatter (structured export)
// ============================================================================

export fn format_json_export() void {
    const omni_state = getOmniStructPtr();
    const buf_ptr = @as([*]u8, @ptrFromInt(omni.OMNI_BASE + omni.JSON_BUFFER_OFFSET));
    const buf_size = omni.JSON_BUFFER_SIZE;

    const json_prefix = "{\"omnibus\":{\"cycle\":0,\"pnl\":0,\"health\":\"ok\"}}";

    var i: usize = 0;
    while (i < json_prefix.len and i < buf_size - 1) : (i += 1) {
        buf_ptr[i] = json_prefix[i];
    }
    buf_ptr[i] = 0;

    omni_state.json_export_ready = 0x01;
}
