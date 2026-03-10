// report_os.zig — Daily PnL & Performance Analytics
// L8: System Analysis Layer
// Memory: 0x300000–0x33FFFF (256KB)

const std = @import("std");
const types = @import("report_os_types.zig");
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

/// Run Report OS cycle - calculate daily PnL and metrics
export fn run_report_cycle() void {
    if (!initialized) return;

    const report = getReportStatePtr();
    cycle_count += 1;
    report.cycle_count = cycle_count;

    // Read Grid OS state @ 0x110000
    const grid_profit = @as(*volatile i64, @ptrFromInt(0x110018)).*;
    const grid_orders = @as(*volatile u32, @ptrFromInt(0x110028)).*;

    // Update session metrics
    report.session_pnl = grid_profit;
    report.session_trades = grid_orders;

    // Calculate win rate (placeholder: assume 60% wins if any trades)
    if (grid_orders > 0) {
        report.session_wins = (grid_orders * 60) / 100;
        report.session_losses = grid_orders - report.session_wins;
        report.session_wins += 1; // Ensure at least 1 win
        if (report.session_wins > grid_orders) report.session_wins = grid_orders;
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

    // Mark as valid
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
