// checksum_os_types.zig — Checksum OS data types
// L9: System Validation Layer
// Memory: 0x310000–0x31FFFF (64KB)

pub const CHECKSUM_BASE: usize = 0x310000;

/// Checksum validation state (128 bytes)
pub const ChecksumState = extern struct {
    magic: u32 = 0x43534D41,           // 0  — "CSMA" magic
    flags: u8,                          // 4  — 0x01=valid, 0x02=scanning
    _pad1: [3]u8 = [_]u8{0} ** 3,     // 5  — alignment
    cycle_count: u64,                   // 8  — Total cycles executed

    // Tier 1 CRC-64 checksums (7 modules × 8 bytes each = 56 bytes)
    grid_crc: u64,                      // 16 — Grid OS state CRC
    analytics_crc: u64,                 // 24 — Analytics OS state CRC
    execution_crc: u64,                 // 32 — Execution OS state CRC
    blockchain_crc: u64,                // 40 — BlockchainOS state CRC
    neuro_crc: u64,                     // 48 — NeuroOS state CRC
    bank_crc: u64,                      // 56 — BankOS state CRC
    stealth_crc: u64,                   // 64 — StealthOS state CRC

    // Validation results
    all_valid: u8,                      // 72 — 0x01 = all checksums pass
    failed_mask: u8,                    // 73 — bitmask of failed modules
    failure_count: u32,                 // 74 — total validation failures
    last_scan_tsc: u64,                 // 78 — TSC of last checksum scan

    // Repair triggers
    autorepair_needed: u8,              // 86 — 0x01 = trigger AutoRepair OS
    repair_module_id: u8,               // 87 — which module needs repair (0-6)
    repair_attempt_count: u32,          // 88 — number of repair attempts

    _pad2: [28]u8 = [_]u8{0} ** 28,   // 92 — reserved
    // = 128 bytes
};

/// Module metadata for CRC validation
pub const ModuleMetadata = extern struct {
    module_id: u8,                      // 0  — 0=Grid, 1=Analytics, 2=Exec, 3=Blockchain, 4=Neuro, 5=Bank, 6=Stealth
    _pad: [7]u8 = [_]u8{0} ** 7,      // 1  — alignment
    base_address: u64,                  // 8  — memory address of module state
    state_size: u32,                    // 16 — bytes to validate
    _pad2: [4]u8 = [_]u8{0} ** 4,     // 20 — alignment
    // = 24 bytes
};

pub const MODULE_METADATA: [7]ModuleMetadata = .{
    .{ .module_id = 0, .base_address = 0x110000, .state_size = 256 },  // Grid OS
    .{ .module_id = 1, .base_address = 0x150000, .state_size = 256 },  // Analytics OS
    .{ .module_id = 2, .base_address = 0x130000, .state_size = 256 },  // Execution OS
    .{ .module_id = 3, .base_address = 0x250000, .state_size = 256 },  // BlockchainOS
    .{ .module_id = 4, .base_address = 0x2D0000, .state_size = 256 },  // NeuroOS
    .{ .module_id = 5, .base_address = 0x280000, .state_size = 256 },  // BankOS
    .{ .module_id = 6, .base_address = 0x2C0000, .state_size = 256 },  // StealthOS
};
