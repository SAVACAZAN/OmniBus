// autorepair_os_types.zig — AutoRepair OS data types
// L10: Self-Healing Layer
// Memory: 0x320000–0x32FFFF (64KB)

pub const AUTOREPAIR_BASE: usize = 0x320000;

/// AutoRepair state machine (128 bytes)
pub const AutoRepairState = extern struct {
    magic: u32 = 0x41524550,         // 0  — "AREP" magic (4 bytes)
    flags: u8,                          // 4  — 0x01=enabled, 0x02=repair_in_progress
    _pad1: [3]u8 = [_]u8{0} ** 3,     // 5  — alignment
    cycle_count: u64,                   // 8  — Total cycles executed

    // Repair request (from Checksum OS)
    request_pending: u8,                // 16 — 0x01 = repair request waiting
    failed_module_id: u8,               // 17 — which module failed (0-6)
    _pad2: [6]u8 = [_]u8{0} ** 6,     // 18-23 — alignment

    // Repair execution state
    repair_in_progress: u8,             // 24 — 0x01 = actively repairing
    repair_phase: u8,                   // 25 — 0=read_disk, 1=reload_mem, 2=init_plugin, 3=verify
    _pad3: [2]u8 = [_]u8{0} ** 2,     // 26-27 — alignment
    repair_attempts: u32,               // 28 — attempts for current module
    repair_max_attempts: u32,           // 32 — max retries before escalate (e.g., 3)

    // Repair history (per module)
    grid_repairs: u32,                  // 36 — Grid OS repairs
    analytics_repairs: u32,             // 40 — Analytics OS repairs
    execution_repairs: u32,             // 44 — Execution OS repairs
    blockchain_repairs: u32,            // 48 — BlockchainOS repairs
    neuro_repairs: u32,                 // 52 — NeuroOS repairs
    bank_repairs: u32,                  // 56 — BankOS repairs
    stealth_repairs: u32,               // 60 — StealthOS repairs

    // Repair timing
    last_repair_tsc: u64,               // 64 — TSC of last successful repair
    last_failed_tsc: u64,               // 72 — TSC of last detected failure

    // Status flags (per module, bitmask)
    recovery_status: u8,                // 80 — 0xFF=all healthy, bits set=recovered
    escalation_triggered: u8,           // 81 — 0x01 = exceeded max repairs, need manual intervention
    _pad4: [6]u8 = [_]u8{0} ** 6,     // 82-87 — alignment

    // Escalation info
    escalation_reason: u32,             // 88 — error code explaining why escalation happened
    escalation_tsc: u64,                // 92 — when escalation was triggered

    _pad5: [28]u8 = [_]u8{0} ** 28,   // 100 — reserved
    // = 128 bytes
};

/// Module disk image locations
pub const ModuleImage = extern struct {
    module_id: u8,
    _pad: [7]u8 = [_]u8{0} ** 7,
    disk_sector_start: u32,             // LBA sector where module binary starts on disk
    disk_sector_count: u32,             // Number of sectors to read
    memory_address: u64,                // Where to load (0x110000, 0x150000, etc.)
    memory_size: u32,                   // Size of memory region
    init_plugin_offset: u32,            // Offset to init_plugin function in binary
    // = 32 bytes per module
};

/// Module metadata for repair
pub const MODULE_METADATA: [7]ModuleImage = .{
    .{ .module_id = 0, .disk_sector_start = 4096,  .disk_sector_count = 256,  .memory_address = 0x110000, .memory_size = 0x20000, .init_plugin_offset = 0x100 },  // Grid OS
    .{ .module_id = 1, .disk_sector_start = 4352,  .disk_sector_count = 1024, .memory_address = 0x150000, .memory_size = 0x80000, .init_plugin_offset = 0x000 },  // Analytics OS
    .{ .module_id = 2, .disk_sector_start = 5376,  .disk_sector_count = 256,  .memory_address = 0x130000, .memory_size = 0x20000, .init_plugin_offset = 0x3c0 },  // Execution OS
    .{ .module_id = 3, .disk_sector_start = 5632,  .disk_sector_count = 384,  .memory_address = 0x250000, .memory_size = 0x30000, .init_plugin_offset = 0x000 },  // BlockchainOS
    .{ .module_id = 4, .disk_sector_start = 6016,  .disk_sector_count = 1024, .memory_address = 0x2D0000, .memory_size = 0x80000, .init_plugin_offset = 0x000 },  // NeuroOS
    .{ .module_id = 5, .disk_sector_start = 7040,  .disk_sector_count = 384,  .memory_address = 0x280000, .memory_size = 0x30000, .init_plugin_offset = 0x000 },  // BankOS
    .{ .module_id = 6, .disk_sector_start = 7424,  .disk_sector_count = 384,  .memory_address = 0x2C0000, .memory_size = 0x30000, .init_plugin_offset = 0x640 },  // StealthOS
};
