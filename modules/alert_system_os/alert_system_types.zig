// alert_system_types.zig — Alert rule engine and notification management
// L17: Real-time alerting for trading events and system health
// Memory: 0x380000–0x38FFFF (64KB)

pub const ALERT_BASE: usize = 0x380000;
pub const MAX_ALERT_RULES: usize = 32;
pub const MAX_ALERT_QUEUE: usize = 64;

/// Alert severity levels
pub const AlertSeverity = enum(u8) {
    Info = 0,      // Informational only
    Warning = 1,   // Warning - needs attention
    Critical = 2,  // Critical - immediate action required
};

/// Alert rule types
pub const AlertRuleType = enum(u8) {
    ProfitThreshold = 0,        // Trigger when profit exceeds threshold
    LossThreshold = 1,          // Trigger when loss exceeds threshold
    SpreadThreshold = 2,        // Trigger when spread widens/narrows
    ChecksumFailure = 3,        // Trigger on checksum validation failure
    RepairFailure = 4,          // Trigger when repair attempts exceeded
    HighViolation = 5,          // Trigger on high ACL violation count
    OrderQueueFull = 6,         // Trigger when order queue fills
    LowLiquidity = 7,           // Trigger when liquidity is low
    HighLatency = 8,            // Trigger when latency exceeds threshold
    ParameterChange = 9,        // Notify on parameter updates
};

/// Single alert rule (32 bytes)
pub const AlertRule = extern struct {
    rule_id: u8,                // 0  — Unique rule identifier (0-31)
    rule_type: u8,              // 1  — AlertRuleType enum
    severity: u8,               // 2  — AlertSeverity enum
    enabled: u8,                // 3  — 0x01=enabled, 0x00=disabled

    threshold_value: i32,       // 4  — Integer threshold (profit/loss/spread/latency)
    cooldown_cycles: u32,       // 8  — Minimum cycles between alerts
    last_triggered_cycle: u64,  // 12 — When this rule last triggered

    // Notification destinations (bitflags)
    notify_email: u8,           // 20 — 0x01=send email
    notify_slack: u8,           // 21 — 0x01=send slack
    notify_ui: u8,              // 22 — 0x01=show in dashboard
    _pad: u8 = 0,              // 23 — alignment

    trigger_count: u32,         // 24 — Number of times triggered
    // = 28 bytes (used), 4 bytes padding
};

/// Alert in notification queue (16 bytes)
pub const AlertEvent = extern struct {
    rule_id: u8,                // 0  — Which rule triggered
    severity: u8,               // 1  — Severity level
    _pad1: [2]u8 = [_]u8{0} ** 2, // 2  — alignment
    triggered_cycle: u64,       // 4  — When triggered
    value: i32,                 // 12 — Actual value that triggered alert
};

/// Alert System state (128 bytes @ 0x380000)
pub const AlertSystemState = extern struct {
    magic: u32 = 0x414C5254,              // 0  — "ALRT" magic
    flags: u8,                            // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,       // 5  — alignment
    cycle_count: u64,                     // 8  — Total cycles executed

    // Rule management
    rule_count: u16,                      // 16 — Number of active rules (0-32)
    _pad2: [2]u8 = [_]u8{0} ** 2,       // 18 — alignment

    // Alert queue
    alert_queue_head: u8,                 // 20 — Next write index
    alert_queue_tail: u8,                 // 21 — Next read index
    alert_queue_count: u16,               // 22 — Number of pending alerts

    // Statistics
    total_alerts_triggered: u64,          // 24 — Lifetime alert count
    alerts_by_severity: [3]u32,           // 32 — [Info, Warning, Critical] counts

    // Notification status
    pending_email_count: u16,             // 44 — Emails to send
    pending_slack_count: u16,             // 46 — Slack messages to send
    last_notification_sent: u64,          // 48 — When last notification was sent

    // Escalation
    escalation_triggered: u8,             // 56 — 0x01 = alert system overloaded
    escalation_reason: u8,                // 57 — Error code
    _pad3: [6]u8 = [_]u8{0} ** 6,       // 58 — alignment

    // Configuration
    enable_email: u8,                     // 64 — 0x01=email notifications enabled
    enable_slack: u8,                     // 65 — 0x01=slack notifications enabled
    enable_ui: u8,                        // 66 — 0x01=UI alerts enabled
    _pad4: [5]u8 = [_]u8{0} ** 5,       // 67 — alignment

    // Thresholds
    max_email_per_cycle: u16,             // 72 — Rate limit for emails
    max_slack_per_cycle: u16,             // 74 — Rate limit for slack
    critical_alert_threshold: u16,        // 76 — Consecutive criticals before escalation
    _pad5: [48]u8 = [_]u8{0} ** 48,     // 78 — reserved
    // = 128 bytes
};

/// Get default alert rules (built-in profitability and safety rules)
pub fn getDefaultRules() [10]AlertRule {
    return .{
        // Rule 0: High profit threshold
        .{
            .rule_id = 0,
            .rule_type = @intFromEnum(AlertRuleType.ProfitThreshold),
            .severity = @intFromEnum(AlertSeverity.Info),
            .enabled = 1,
            .threshold_value = 1_000_000, // 1M satoshis
            .cooldown_cycles = 256,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 1,
            .notify_ui = 1,
            .trigger_count = 0,
        },
        // Rule 1: Loss threshold
        .{
            .rule_id = 1,
            .rule_type = @intFromEnum(AlertRuleType.LossThreshold),
            .severity = @intFromEnum(AlertSeverity.Warning),
            .enabled = 1,
            .threshold_value = -500_000, // -500K satoshis
            .cooldown_cycles = 128,
            .last_triggered_cycle = 0,
            .notify_email = 1,
            .notify_slack = 1,
            .notify_ui = 1,
            .trigger_count = 0,
        },
        // Rule 2: Checksum failure
        .{
            .rule_id = 2,
            .rule_type = @intFromEnum(AlertRuleType.ChecksumFailure),
            .severity = @intFromEnum(AlertSeverity.Critical),
            .enabled = 1,
            .threshold_value = 1,
            .cooldown_cycles = 512,
            .last_triggered_cycle = 0,
            .notify_email = 1,
            .notify_slack = 1,
            .notify_ui = 1,
            .trigger_count = 0,
        },
        // Rule 3: High violation count
        .{
            .rule_id = 3,
            .rule_type = @intFromEnum(AlertRuleType.HighViolation),
            .severity = @intFromEnum(AlertSeverity.Warning),
            .enabled = 1,
            .threshold_value = 10,
            .cooldown_cycles = 256,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 1,
            .notify_ui = 1,
            .trigger_count = 0,
        },
        // Rule 4: Repair failure
        .{
            .rule_id = 4,
            .rule_type = @intFromEnum(AlertRuleType.RepairFailure),
            .severity = @intFromEnum(AlertSeverity.Critical),
            .enabled = 1,
            .threshold_value = 1,
            .cooldown_cycles = 1024,
            .last_triggered_cycle = 0,
            .notify_email = 1,
            .notify_slack = 1,
            .notify_ui = 1,
            .trigger_count = 0,
        },
        // Rules 5-9: Unused (zeroed out)
        .{
            .rule_id = 5,
            .rule_type = 0,
            .severity = 0,
            .enabled = 0,
            .threshold_value = 0,
            .cooldown_cycles = 0,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 0,
            .notify_ui = 0,
            .trigger_count = 0,
        },
        .{
            .rule_id = 6,
            .rule_type = 0,
            .severity = 0,
            .enabled = 0,
            .threshold_value = 0,
            .cooldown_cycles = 0,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 0,
            .notify_ui = 0,
            .trigger_count = 0,
        },
        .{
            .rule_id = 7,
            .rule_type = 0,
            .severity = 0,
            .enabled = 0,
            .threshold_value = 0,
            .cooldown_cycles = 0,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 0,
            .notify_ui = 0,
            .trigger_count = 0,
        },
        .{
            .rule_id = 8,
            .rule_type = 0,
            .severity = 0,
            .enabled = 0,
            .threshold_value = 0,
            .cooldown_cycles = 0,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 0,
            .notify_ui = 0,
            .trigger_count = 0,
        },
        .{
            .rule_id = 9,
            .rule_type = 0,
            .severity = 0,
            .enabled = 0,
            .threshold_value = 0,
            .cooldown_cycles = 0,
            .last_triggered_cycle = 0,
            .notify_email = 0,
            .notify_slack = 0,
            .notify_ui = 0,
            .trigger_count = 0,
        },
    };
}
