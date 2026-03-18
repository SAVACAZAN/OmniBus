// zorin_os_types.zig — Zorin OS data types
// L13: Security & Compliance Layer
// Memory: 0x330000–0x33FFFF (64KB)

pub const ZORIN_BASE: usize = 0x330000;

/// Geographic zones for regulatory compliance
pub const Zone = enum(u8) {
    London = 0,         // EU/FCA jurisdiction
    Frankfurt = 1,      // EURO zone/ECB
    NewYork = 2,        // US/SEC jurisdiction
    Tokyo = 3,          // APAC/FSA jurisdiction
    Unknown = 255,
};

/// Module permission matrix (7 modules × 7 modules = 49 cells)
/// Permission[from][to] = allowed operations bitmask
pub const Permission = packed struct(u8) {
    read: u1 = 0,       // bit 0: can read state
    write: u1 = 0,      // bit 1: can modify state
    execute: u1 = 0,    // bit 2: can execute functions
    audit: u1 = 0,      // bit 3: can be audited
    _reserved: u4 = 0,
};

/// Access Control List entry
pub const ACLEntry = extern struct {
    source_module: u8,           // 0-6: which module requesting access
    target_module: u8,           // 0-6: which module being accessed
    zone: u8,                    // 0-3: geographic zone
    permission: u8,              // packed Permission bits
    // = 4 bytes
};

/// Zorin OS state machine (128 bytes)
pub const ZorinState = extern struct {
    magic: u32 = 0x5A4F5249,    // 0  — "ZORI" magic
    flags: u8,                   // 4  — 0x01=enabled, 0x02=audit_mode
    _pad1: [3]u8 = [_]u8{0} ** 3, // 5 — alignment
    cycle_count: u64,            // 8  — Total cycles executed

    // Current operation context
    current_zone: u8,            // 16 — active zone for this cycle
    current_module: u8,          // 17 — module initiating access
    target_module: u8,           // 18 — module being accessed
    operation_type: u8,          // 19 — 0=read, 1=write, 2=execute, 3=audit

    // Access control statistics
    allowed_accesses: u32,       // 20 — successful permission grants
    denied_accesses: u32,        // 24 — denied due to ACL
    audit_events: u32,           // 28 — events logged

    // Zone routing
    zone_grid_routes: u8,        // 32 — bitmask of active zones for Grid
    zone_analytics_routes: u8,   // 33 — bitmask for Analytics
    zone_execution_routes: u8,   // 34 — bitmask for Execution
    zone_blockchain_routes: u8,  // 35 — bitmask for Blockchain
    zone_neuro_routes: u8,       // 36 — bitmask for Neuro
    zone_bank_routes: u8,        // 37 — bitmask for Bank
    zone_stealth_routes: u8,     // 38 — bitmask for Stealth

    // Violation tracking
    violation_count: u32,        // 39 — total violations detected
    last_violation_tsc: u64,     // 43 — timestamp of last violation
    violation_module: u8,        // 51 — which module violated ACL
    _pad2: [7]u8 = [_]u8{0} ** 7, // 52-58 — alignment

    // Escalation
    escalation_triggered: u8,    // 59 — 0x01 = security breach detected
    escalation_reason: u32,      // 60 — why escalation happened
    escalation_tsc: u64,         // 64 — when escalation triggered

    _pad3: [52]u8 = [_]u8{0} ** 52, // 72-123 — reserved
    // = 128 bytes
};

/// Module permission matrix (7x7 = 49 entries, stored row-major)
pub const MODULE_ACL: [7][7]Permission = .{
    // Grid OS (0) can:
    .{ .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // read/write/exec/audit itself
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Analytics, audit
       .{.read = 0, .write = 1, .execute = 0, .audit = 1}, // write to Execution, audit
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Blockchain
       .{.read = 0, .write = 1, .execute = 0, .audit = 1}, // write to Neuro params
       .{.read = 0, .write = 1, .execute = 0, .audit = 1}, // write to Bank (settlement)
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}  // read Stealth (MEV status)
    },
    // Analytics OS (1) can:
    .{ .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Grid
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // full access to itself
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Execution
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Blockchain
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}  // audit only
    },
    // Execution OS (2) can:
    .{ .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Grid
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Analytics
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // full access to itself
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Blockchain
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 1, .execute = 0, .audit = 1}, // write settlement to Bank
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}  // audit only
    },
    // BlockchainOS (3) can:
    .{ .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Grid
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Analytics
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Execution
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // full access to itself
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 1, .execute = 0, .audit = 1}, // write to Bank (settlement)
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}  // read Stealth
    },
    // NeuroOS (4) can:
    .{ .{.read = 1, .write = 1, .execute = 0, .audit = 1}, // read/write Grid params
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Analytics
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Execution
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // full access to itself
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}  // audit only
    },
    // BankOS (5) can:
    .{ .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Grid
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Execution
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Blockchain
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}, // full access to itself
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}  // audit only
    },
    // StealthOS (6) can:
    .{ .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Grid (for MEV detection)
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Analytics
       .{.read = 1, .write = 1, .execute = 0, .audit = 1}, // write MEV signals to Execution
       .{.read = 1, .write = 0, .execute = 0, .audit = 1}, // read Blockchain
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 0, .write = 0, .execute = 0, .audit = 1}, // audit only
       .{.read = 1, .write = 1, .execute = 1, .audit = 1}  // full access to itself
    },
};
