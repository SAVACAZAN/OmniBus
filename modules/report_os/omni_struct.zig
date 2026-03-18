// omni_struct.zig — Omnibus System Auditor Structure
// Central nervous system coordinating all Tier 1-5 layers
// Memory: 0x400000–0x400200 (512 bytes shared status)

pub const OMNI_BASE: usize = 0x400000;

/// Omnibus Aggregation Structure - read/write by all layers
pub const OmniStruct = extern struct {
    // === HEADER ===
    magic: u32 = 0x4F4D4E49,        // 0  — "OMNI" magic marker
    version: u8 = 1,                // 4  — Protocol version
    flags: u8 = 0,                  // 5  — 0x01=valid, 0x02=audit_failed
    _pad1: [2]u8 = [_]u8{0} ** 2,  // 6  — alignment

    // === TIER 1 AUDIT ===
    tier1_cycle_count: u64,         // 8  — Total kernel cycles
    tier1_timestamp: u64,           // 16 — Last audit TSC

    // Grid OS metrics
    grid_pnl: i64,                  // 24 — Current PnL from Grid
    grid_trades: u32,               // 32 — Active orders
    grid_levels: u32,               // 36 — Active grid levels

    // Execution OS metrics
    exec_fills: u32,                // 40 — Orders filled
    exec_orders: u32,               // 44 — Orders in queue

    // Stealth OS metrics
    mev_prevented: u32,             // 48 — MEV attacks blocked
    sandwich_detected: u32,         // 52 — Sandwich patterns caught

    // Analytics OS metrics
    analytics_consensus: u8,        // 56 — Consensus quality [0-100]%
    _pad2: [3]u8 = [_]u8{0} ** 3,  // 57 — alignment

    // === TIER 2 COORDINATION ===
    // L9: Checksum OS status
    checksum_valid: u8,             // 60 — 0x01 = all Tier 1 checksums pass
    _pad_cs1: [3]u8 = [_]u8{0} ** 3,  // 61-63 — alignment
    checksum_failures: u32,         // 64 — Count of integrity failures
    _pad_cs2: [4]u8 = [_]u8{0} ** 4,  // 68-71 — alignment to 72
    checksum_last_scan: u64,        // 72 — TSC of last Checksum scan (8-byte aligned)

    // L10: AutoRepair OS status
    autorepair_triggered: u8,       // 80 — 0x01 = repair in progress
    _pad_ar1: [3]u8 = [_]u8{0} ** 3,  // 81-83 — alignment
    autorepair_count: u32,          // 84 — Total repairs executed
    _pad_ar2: [4]u8 = [_]u8{0} ** 4,  // 88-91 — alignment to 92
    autorepair_last_action: u64,    // 92 — TSC of last repair (8-byte aligned)

    // === PERFORMANCE AGGREGATES ===
    total_pnl: i64,                 // 86 — Cumulative PnL
    total_trades: u32,              // 94 — All trades executed
    success_rate: u8,               // 98 — Win % [0-100]
    _pad3: [1]u8 = [_]u8{0} ** 1,  // 99 — alignment

    // === UI BRIDGE (L13/L14) ===
    htmx_buffer_ready: u8,          // 100 — 0x01 = output ready for UI
    htmx_update_count: u32,         // 101 — Updates sent to dashboard
    websocket_connected: u8,        // 105 — 0x01 = WS connected to L13
    _pad4: [3]u8 = [_]u8{0} ** 3,  // 106 — alignment

    // === EXPORT BUFFERS ===
    csv_export_ready: u8,           // 109 — 0x01 = CSV ready @ 0x400200
    json_export_ready: u8,          // 110 — 0x01 = JSON ready
    _pad5: [2]u8 = [_]u8{0} ** 2,  // 111 — alignment

    // === INTEGRITY MARKERS ===
    last_update_tsc: u64,           // 113 — When struct was last updated
    audit_cycle_count: u32,         // 121 — How many audits completed
    system_health: u8,              // 125 — 0xFF=healthy, 0x00=critical
    _pad6: [3]u8 = [_]u8{0} ** 3,  // 126 — alignment

    // = 128 bytes (cache line aligned)
};

// === CSV EXPORT BUFFER ===
// Located at 0x400200 (after OmniStruct)
pub const CSV_BUFFER_OFFSET: usize = 0x200;
pub const CSV_BUFFER_SIZE: usize = 0x800; // 2KB for CSV lines

// === JSON EXPORT BUFFER ===
pub const JSON_BUFFER_OFFSET: usize = 0xA00;
pub const JSON_BUFFER_SIZE: usize = 0x800; // 2KB for JSON output

// === HTMX SNIPPET BUFFER ===
pub const HTMX_BUFFER_OFFSET: usize = 0x1200;
pub const HTMX_BUFFER_SIZE: usize = 0x400; // 1KB for HTML snippets

// Total allocated: 0x400000-0x4021FF (8.5KB)
pub const TOTAL_SIZE: usize = 0x2200;
