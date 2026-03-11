// logging_types.zig — Structured Logging Hub (Phase 57)
// Serilog + ELK Stack + Application Insights integration

pub const LOG_BASE: usize = 0x5A0000;
pub const MAX_LOG_EVENTS: usize = 256;
pub const LOG_BUFFER_SIZE: usize = 4096;

pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,
};

pub const LogEvent = extern struct {
    timestamp: u64,           // Cycle count when logged
    correlation_id: u64,      // Trace ID (spans providers)
    source_module: u8,        // 0=Grid, 1=Exec, 2=Analytics, etc.
    source_provider: u8,      // 0=MS, 1=Oracle, 2=AWS, 3=VMWare, 4=GCP
    log_level: u8,            // LogLevel enum
    _pad1: u8,
    message_len: u16,
    message: [256]u8,
};

pub const LoggingOsState = extern struct {
    magic: u32,               // 'LOGS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_events_logged: u32,
    total_events_forwarded: u32,
    total_events_dropped: u32,
    buffer_overflow_count: u32,
    pending_debug: u8,
    pending_info: u8,
    pending_warn: u8,
    pending_error: u8,
    last_error: u8,
    _pad2: [63]u8,
};
