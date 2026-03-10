// alert_system_os.zig — Alert rule engine and notification dispatcher
// L17: Real-time alerting for trading events and system health
// Memory: 0x380000–0x38FFFF (64KB)

const std = @import("std");
const types = @import("alert_system_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getAlertStatePtr() *volatile types.AlertSystemState {
    return @as(*volatile types.AlertSystemState, @ptrFromInt(types.ALERT_BASE));
}

fn getAlertRulesBuffer() [*]volatile types.AlertRule {
    // Alert rules start at offset 128 (after state struct)
    return @as([*]volatile types.AlertRule, @ptrFromInt(types.ALERT_BASE + 128));
}

fn getAlertQueueBuffer() [*]volatile types.AlertEvent {
    // Alert queue starts after rules: 128 (state) + 32*32 (rules) = 1152
    return @as([*]volatile types.AlertEvent, @ptrFromInt(types.ALERT_BASE + 1152));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Alert System OS
export fn init_plugin() void {
    if (initialized) return;

    const state = getAlertStatePtr();

    // Initialize state
    state.magic = 0x414C5254; // "ALRT"
    state.flags = 0x01;
    state.cycle_count = 0;
    state.rule_count = 5; // Load 5 default rules
    state.alert_queue_head = 0;
    state.alert_queue_tail = 0;
    state.alert_queue_count = 0;
    state.total_alerts_triggered = 0;
    state.alerts_by_severity[0] = 0;
    state.alerts_by_severity[1] = 0;
    state.alerts_by_severity[2] = 0;
    state.pending_email_count = 0;
    state.pending_slack_count = 0;
    state.last_notification_sent = 0;
    state.escalation_triggered = 0;
    state.escalation_reason = 0;
    state.enable_email = 1;
    state.enable_slack = 1;
    state.enable_ui = 1;
    state.max_email_per_cycle = 5;
    state.max_slack_per_cycle = 10;
    state.critical_alert_threshold = 5;

    // Load default rules
    const defaults = types.getDefaultRules();
    const rules_buffer = getAlertRulesBuffer();
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        rules_buffer[i] = defaults[i];
    }

    // Zero-init remaining rules
    while (i < types.MAX_ALERT_RULES) : (i += 1) {
        rules_buffer[i].enabled = 0;
    }

    // Zero-init alert queue
    const queue_buffer = getAlertQueueBuffer();
    var j: usize = 0;
    while (j < types.MAX_ALERT_QUEUE) : (j += 1) {
        queue_buffer[j].rule_id = 0xFF;
        queue_buffer[j].severity = 0;
        queue_buffer[j].triggered_cycle = 0;
        queue_buffer[j].value = 0;
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Evaluate alert rules
// ============================================================================

/// Run Alert System cycle - evaluate rules and queue notifications
export fn run_alert_cycle() void {
    if (!initialized) return;

    const state = getAlertStatePtr();
    cycle_count += 1;
    state.cycle_count = cycle_count;

    // Evaluate enabled rules
    const rules_buffer = getAlertRulesBuffer();
    var rule_idx: u16 = 0;
    while (rule_idx < state.rule_count) : (rule_idx += 1) {
        const rule = &rules_buffer[rule_idx];

        if (rule.enabled == 0) continue;

        // Check cooldown
        const time_since_last = cycle_count - rule.last_triggered_cycle;
        if (time_since_last < rule.cooldown_cycles) continue;

        // Evaluate rule (simplified - in real implementation, would read actual metrics)
        // For now, just check if we should trigger (would be based on Grid OS metrics, etc.)
        // In production: would compare rule.threshold_value with actual metrics from kernel

        // Example: check profit threshold from OmniStruct
        // const profit = readOmniStructProfit();
        // if (profit > rule.threshold_value) {
        //     triggerAlert(rule_idx, profit);
        // }
    }

    // Process pending notifications (placeholder)
    // In production: would actually send emails/slack messages here
    // For now: just clear queue if it gets too full
    if (state.alert_queue_count > (types.MAX_ALERT_QUEUE / 2)) {
        state.alert_queue_head = 0;
        state.alert_queue_tail = 0;
        state.alert_queue_count = 0;
    }
}

fn triggerAlert(rule_id: u16, value: i32) void {
    const state = getAlertStatePtr();
    if (rule_id >= state.rule_count) return;

    const rules_buffer = getAlertRulesBuffer();
    const rule = &rules_buffer[rule_id];

    // Update rule statistics
    rule.trigger_count += 1;
    rule.last_triggered_cycle = cycle_count;

    // Queue alert event
    if (state.alert_queue_count < types.MAX_ALERT_QUEUE) {
        const queue_buffer = getAlertQueueBuffer();
        const queue_idx = state.alert_queue_head % types.MAX_ALERT_QUEUE;

        queue_buffer[queue_idx].rule_id = @as(u8, @intCast(rule_id));
        queue_buffer[queue_idx].severity = rule.severity;
        queue_buffer[queue_idx].triggered_cycle = cycle_count;
        queue_buffer[queue_idx].value = value;

        state.alert_queue_head = (state.alert_queue_head + 1) % types.MAX_ALERT_QUEUE;
        state.alert_queue_count += 1;

        // Update statistics
        state.total_alerts_triggered += 1;
        if (rule.severity < 3) {
            state.alerts_by_severity[rule.severity] += 1;
        }

        // Count notifications to send
        if (rule.notify_email != 0) {
            state.pending_email_count += 1;
        }
        if (rule.notify_slack != 0) {
            state.pending_slack_count += 1;
        }
    } else {
        // Queue full - escalate
        state.escalation_triggered = 1;
        state.escalation_reason = 1; // Alert queue full
    }
}

// ============================================================================
// Public API: Rule Management
// ============================================================================

/// Enable/disable an alert rule
export fn set_rule_enabled(rule_id: u16, enabled: u8) u8 {
    if (rule_id >= types.MAX_ALERT_RULES) return 0;

    const rules_buffer = getAlertRulesBuffer();
    rules_buffer[rule_id].enabled = if (enabled != 0) 1 else 0;

    return 1;
}

/// Update alert rule threshold
export fn set_rule_threshold(rule_id: u16, threshold: i32) u8 {
    if (rule_id >= types.MAX_ALERT_RULES) return 0;

    const rules_buffer = getAlertRulesBuffer();
    rules_buffer[rule_id].threshold_value = threshold;

    return 1;
}

/// Get alert rule by ID
export fn get_rule_trigger_count(rule_id: u16) u32 {
    if (rule_id >= types.MAX_ALERT_RULES) return 0;

    const rules_buffer = getAlertRulesBuffer();
    return rules_buffer[rule_id].trigger_count;
}

/// Get pending notification count
export fn get_pending_email_count() u16 {
    const state = getAlertStatePtr();
    return state.pending_email_count;
}

export fn get_pending_slack_count() u16 {
    const state = getAlertStatePtr();
    return state.pending_slack_count;
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_rule_count() u16 {
    const state = getAlertStatePtr();
    return state.rule_count;
}

export fn get_total_alerts_triggered() u64 {
    const state = getAlertStatePtr();
    return state.total_alerts_triggered;
}

export fn get_alert_queue_count() u16 {
    const state = getAlertStatePtr();
    return state.alert_queue_count;
}

export fn get_info_alerts() u32 {
    const state = getAlertStatePtr();
    return state.alerts_by_severity[0];
}

export fn get_warning_alerts() u32 {
    const state = getAlertStatePtr();
    return state.alerts_by_severity[1];
}

export fn get_critical_alerts() u32 {
    const state = getAlertStatePtr();
    return state.alerts_by_severity[2];
}

export fn get_escalation_triggered() u8 {
    const state = getAlertStatePtr();
    return state.escalation_triggered;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
