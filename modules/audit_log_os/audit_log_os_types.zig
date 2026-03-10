// audit_log_os_types.zig — Audit Log OS data types
// L11: Event logging & forensics layer
// Memory: 0x340000–0x35FFFF (256KB)

pub const AUDIT_LOG_BASE: usize = 0x340000;
pub const AUDIT_LOG_SIZE: usize = 256 * 1024; // 256KB total
pub const AUDIT_LOG_HEADER_SIZE: usize = 128;
pub const AUDIT_LOG_RING_SIZE: usize = AUDIT_LOG_SIZE - AUDIT_LOG_HEADER_SIZE; // ~256KB - 128B

/// Event type classification
pub const EventType = enum(u8) {
    Access = 0,         // Module access attempt (check_access())
    Violation = 1,      // ACL/zone violation (Zorin denied)
    Repair = 2,         // AutoRepair event (repair_phase)
    Trade = 3,          // Grid trade (order entry/fill/cancel)
    Checksum = 4,       // Checksum verification (pass/fail)
    _reserved = 255,
};

/// Module enumeration
pub const Module = enum(u8) {
    Grid = 0,
    Analytics = 1,
    Execution = 2,
    Blockchain = 3,
    Neuro = 4,
    Bank = 5,
    Stealth = 6,
    _invalid = 255,
};

/// Operation type
pub const Operation = enum(u8) {
    Read = 0,
    Write = 1,
    Execute = 2,
    Audit = 3,
};

/// Single audit log event (32 bytes fixed)
pub const AuditEvent = extern struct {
    timestamp: u64 = 0,         // Cycle count or TSC
    event_type: u8 = 0,         // EventType enum
    source_module: u8 = 0xFF,   // Module enum (or 0xFF = N/A)
    target_module: u8 = 0xFF,   // Module enum (or 0xFF = N/A)
    operation: u8 = 0xFF,       // Operation enum or trade_type
    allowed: u8 = 0,            // 1 = allowed, 0 = denied
    details: u32 = 0,           // Extra data (trade_id, repair_phase, error_code)
    _pad: [10]u8 = [_]u8{0} ** 10,
    // = 32 bytes
};

/// Audit Log OS state (128 bytes header @ 0x340000)
pub const AuditLogState = extern struct {
    magic: u32 = 0x41554454,    // 0  — "AUDT" magic
    flags: u8 = 0,              // 4  — 0x01=enabled, 0x02=debug_mode
    _pad1: [3]u8 = [_]u8{0} ** 3, // 5 — alignment
    cycle_count: u64 = 0,       // 8  — Total cycles executed

    // Ring buffer management
    log_head: u32 = 0,          // 16 — Next write offset (ring buffer)
    log_tail: u32 = 0,          // 20 — Oldest retained event offset
    total_events: u64 = 0,      // 24 — Cumulative events logged (wraps)

    // Event counters
    violation_count: u32 = 0,   // 32 — Zorin ACL violations
    repair_count: u32 = 0,      // 36 — AutoRepair events
    trade_count: u32 = 0,       // 40 — Grid trades
    checksum_failures: u32 = 0, // 44 — Checksum mismatches detected

    // Timestamp of last event
    last_event_tsc: u64 = 0,    // 48 — TSC/cycle of last event

    // Security escalation
    escalation_triggered: u8 = 0,  // 56 — 0x01 = escalation active
    _pad2: [3]u8 = [_]u8{0} ** 3,  // 57 — alignment
    escalation_reason: u32 = 0,     // 60 — Why escalation triggered
    escalation_tsc: u64 = 0,        // 64 — When escalation triggered

    // Cross-module statistics
    access_attempts: u32 = 0,   // 72 — Total access checks
    access_denied: u32 = 0,     // 76 — Access check denials
    access_allowed: u32 = 0,    // 80 — Access check allowances

    // Module event counts (one per module)
    grid_events: u32 = 0,       // 84 — Grid OS events
    analytics_events: u32 = 0,  // 88 — Analytics OS events
    execution_events: u32 = 0,  // 92 — Execution OS events
    blockchain_events: u32 = 0, // 96 — Blockchain OS events
    neuro_events: u32 = 0,      // 100 — Neuro OS events
    bank_events: u32 = 0,       // 104 — Bank OS events
    stealth_events: u32 = 0,    // 108 — Stealth OS events

    _pad3: [12]u8 = [_]u8{0} ** 12, // 112-123 — reserved
    // = 128 bytes
};
