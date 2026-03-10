// parameter_tuning_os.zig — Dynamic parameter management for Grid OS
// L15: Real-time trading parameter tuning
// Memory: 0x360000–0x36FFFF (64KB)

const std = @import("std");
const types = @import("parameter_tuning_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getParamTuningStatePtr() *volatile types.ParameterTuningState {
    return @as(*volatile types.ParameterTuningState, @ptrFromInt(types.PARAM_TUNING_BASE));
}

fn getOmniStructPtr() *volatile u8 {
    // OmniStruct is at 0x400000 for status reporting
    return @as(*volatile u8, @ptrFromInt(0x400000));
}

fn validateGridParams(params: *volatile types.GridParams, state: *volatile types.ParameterTuningState) u8 {
    // Check grid step within bounds
    if (params.grid_step < state.min_grid_step or params.grid_step > state.max_grid_step) {
        return @intFromEnum(types.ParamStatus.OutOfRange);
    }

    // Check grid levels within bounds
    if (params.grid_levels < state.min_levels or params.grid_levels > state.max_levels) {
        return @intFromEnum(types.ParamStatus.OutOfRange);
    }

    // Check price bounds
    if (params.min_price >= params.max_price) {
        return @intFromEnum(types.ParamStatus.InvalidCombination);
    }

    // Check spread threshold is reasonable
    if (params.min_spread_bps > 500) { // More than 5% spread is suspicious
        return @intFromEnum(types.ParamStatus.InvalidCombination);
    }

    // Check risk percentage (1-5%)
    if (params.risk_percent < 1 or params.risk_percent > 5) {
        return @intFromEnum(types.ParamStatus.RiskLimitExceeded);
    }

    // Check order timeout is reasonable (100ms - 60s)
    if (params.order_timeout_ms < 100 or params.order_timeout_ms > 60000) {
        return @intFromEnum(types.ParamStatus.InvalidCombination);
    }

    return @intFromEnum(types.ParamStatus.Ok);
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Parameter Tuning OS
export fn init_plugin() void {
    if (initialized) return;

    const pt = getParamTuningStatePtr();
    const defaults = types.getDefaultGridParams();

    pt.* = .{
        .magic = 0x50414241, // "PABA"
        .flags = 0x01,
        .cycle_count = 0,
        .grid_params = defaults,
        .prev_grid_params = defaults,
        .param_change_count = 0,
        .last_change_cycle = 0,
        .last_change_field = 0,
        .pending_update = 0,
        .pending_validation_status = 0,
        .max_grid_step = 500,     // Max 5% steps
        .min_grid_step = 5,       // Min 0.05% steps
        .max_levels = 10,         // Max 10 levels
        .min_levels = 1,          // Min 1 level
        .total_updates_applied = 0,
        .total_updates_rejected = 0,
        .last_rejection_reason = 0,
        .escalation_triggered = 0,
    };

    initialized = true;
}

// ============================================================================
// Main Cycle: Apply pending parameter updates
// ============================================================================

/// Run Parameter Tuning cycle - apply and validate parameter changes
export fn run_param_tuning_cycle() void {
    if (!initialized) return;

    const pt = getParamTuningStatePtr();
    cycle_count += 1;
    pt.cycle_count = cycle_count;

    // Check if there's a pending parameter update
    if (pt.pending_update == 1) {
        // Validate the pending parameters
        const validation_result = validateGridParams(&pt.grid_params, pt);

        if (validation_result == @intFromEnum(types.ParamStatus.Ok)) {
            // Parameters are valid, apply them
            pt.prev_grid_params = pt.grid_params; // Save previous params
            pt.last_change_cycle = cycle_count;
            pt.param_change_count += 1;
            pt.total_updates_applied += 1;
            pt.pending_validation_status = 0; // Accepted
        } else {
            // Invalid parameters, reject and rollback
            pt.grid_params = pt.prev_grid_params; // Restore previous
            pt.total_updates_rejected += 1;
            pt.last_rejection_reason = validation_result;
            pt.pending_validation_status = validation_result;

            // Escalate if too many rejections
            if (pt.total_updates_rejected >= 10) {
                pt.escalation_triggered = 0x01;
            }
        }

        pt.pending_update = 0; // Clear pending flag
    }
}

// ============================================================================
// Public API: Parameter Management
// ============================================================================

/// Request parameter update (from dashboard)
export fn request_parameter_update(
    grid_step: u32,
    grid_levels: u8,
    min_spread_bps: u32,
    risk_percent: u8,
) u8 {
    const pt = getParamTuningStatePtr();

    // Set new parameters
    pt.grid_params.grid_step = grid_step;
    pt.grid_params.grid_levels = grid_levels;
    pt.grid_params.min_spread_bps = min_spread_bps;
    pt.grid_params.risk_percent = risk_percent;

    // Mark as pending validation
    pt.pending_update = 1;
    pt.last_change_field = 1; // Grid tuning
    pt.pending_validation_status = 2; // Pending

    // Return immediately (validation happens in next cycle)
    return 1;
}

/// Get current grid parameters
export fn get_grid_params_snapshot() types.GridParams {
    const pt = getParamTuningStatePtr();
    return pt.grid_params;
}

/// Get previous grid parameters (for undo)
export fn get_prev_grid_params_snapshot() types.GridParams {
    const pt = getParamTuningStatePtr();
    return pt.prev_grid_params;
}

/// Enable/disable trading
export fn set_trading_enabled(enabled: u8) void {
    const pt = getParamTuningStatePtr();
    pt.grid_params.trading_enabled = if (enabled != 0) 1 else 0;
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_grid_step() u32 {
    const pt = getParamTuningStatePtr();
    return pt.grid_params.grid_step;
}

export fn get_grid_levels() u8 {
    const pt = getParamTuningStatePtr();
    return pt.grid_params.grid_levels;
}

export fn get_min_spread_bps() u32 {
    const pt = getParamTuningStatePtr();
    return pt.grid_params.min_spread_bps;
}

export fn get_risk_percent() u8 {
    const pt = getParamTuningStatePtr();
    return pt.grid_params.risk_percent;
}

export fn get_trading_enabled() u8 {
    const pt = getParamTuningStatePtr();
    return pt.grid_params.trading_enabled;
}

export fn get_param_change_count() u32 {
    const pt = getParamTuningStatePtr();
    return pt.param_change_count;
}

export fn get_total_updates_applied() u32 {
    const pt = getParamTuningStatePtr();
    return pt.total_updates_applied;
}

export fn get_total_updates_rejected() u32 {
    const pt = getParamTuningStatePtr();
    return pt.total_updates_rejected;
}

export fn get_last_rejection_reason() u32 {
    const pt = getParamTuningStatePtr();
    return pt.last_rejection_reason;
}

export fn get_pending_validation_status() u8 {
    const pt = getParamTuningStatePtr();
    return pt.pending_validation_status;
}

export fn get_escalation_triggered() u8 {
    const pt = getParamTuningStatePtr();
    return pt.escalation_triggered;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
