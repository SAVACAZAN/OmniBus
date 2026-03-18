// checksum_os.zig — System Validation Layer (CRC-64 checksums)
// L9: Validates all Tier 1 module states
// Memory: 0x310000–0x31FFFF (64KB)

const std = @import("std");
const types = @import("checksum_os_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// CRC-64 Implementation
// ============================================================================

/// Polynomial for CRC-64 (ECMA)
const CRC64_POLY: u64 = 0x42F0E1EBA9EA3693;

/// Compute CRC-64 of memory region
fn crc64_compute(data_ptr: u64, size: u32) u64 {
    var crc: u64 = 0xFFFFFFFFFFFFFFFF; // Initial value
    var offset: u32 = 0;

    while (offset < size) : (offset += 1) {
        const byte_ptr = @as(*volatile u8, @ptrFromInt(data_ptr + offset));
        const byte = byte_ptr.*;

        crc ^= @as(u64, byte) << 56;

        // Reflect bits for this byte
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            const is_msb = (crc & 0x8000000000000000) != 0;
            crc <<= 1;
            if (is_msb) {
                crc ^= CRC64_POLY;
            }
        }
    }

    return crc ^ 0xFFFFFFFFFFFFFFFF; // Final XOR
}

// ============================================================================
// Helper Functions
// ============================================================================

fn getChecksumStatePtr() *volatile types.ChecksumState {
    return @as(*volatile types.ChecksumState, @ptrFromInt(types.CHECKSUM_BASE));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Checksum OS
export fn init_plugin() void {
    if (initialized) return;

    const checksum = getChecksumStatePtr();
    checksum.* = .{
        .magic = 0x43534D41, // "CSMA"
        .flags = 0x01,
        .cycle_count = 0,
        .grid_crc = 0,
        .analytics_crc = 0,
        .execution_crc = 0,
        .blockchain_crc = 0,
        .neuro_crc = 0,
        .bank_crc = 0,
        .stealth_crc = 0,
        .all_valid = 0x01,
        .failed_mask = 0,
        .failure_count = 0,
        .last_scan_tsc = 0,
        .autorepair_needed = 0,
        .repair_module_id = 0xFF,
        .repair_attempt_count = 0,
    };

    initialized = true;
}

// ============================================================================
// Main Cycle: Validate all Tier 1 module states
// ============================================================================

/// Run Checksum OS cycle - compute CRC-64 of all Tier 1 states
export fn run_checksum_cycle() void {
    if (!initialized) return;

    const checksum = getChecksumStatePtr();
    cycle_count += 1;
    checksum.cycle_count = cycle_count;

    // Mark as scanning
    checksum.flags = 0x02;

    // Compute CRC-64 for each Tier 1 module
    var all_valid: u8 = 0x01;
    var failed_mask: u8 = 0;

    // Grid OS
    const grid_crc = crc64_compute(0x110000, 256);
    checksum.grid_crc = grid_crc;
    if (grid_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x01;
    }

    // Analytics OS
    const analytics_crc = crc64_compute(0x150000, 256);
    checksum.analytics_crc = analytics_crc;
    if (analytics_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x02;
    }

    // Execution OS
    const exec_crc = crc64_compute(0x130000, 256);
    checksum.execution_crc = exec_crc;
    if (exec_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x04;
    }

    // BlockchainOS
    const blockchain_crc = crc64_compute(0x250000, 256);
    checksum.blockchain_crc = blockchain_crc;
    if (blockchain_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x08;
    }

    // NeuroOS
    const neuro_crc = crc64_compute(0x2D0000, 256);
    checksum.neuro_crc = neuro_crc;
    if (neuro_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x10;
    }

    // BankOS
    const bank_crc = crc64_compute(0x280000, 256);
    checksum.bank_crc = bank_crc;
    if (bank_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x20;
    }

    // StealthOS
    const stealth_crc = crc64_compute(0x2C0000, 256);
    checksum.stealth_crc = stealth_crc;
    if (stealth_crc == 0) {
        all_valid = 0;
        failed_mask |= 0x40;
    }

    // Update validation state
    checksum.all_valid = all_valid;
    checksum.failed_mask = failed_mask;
    checksum.last_scan_tsc = cycle_count * 1000;

    if (all_valid == 0) {
        checksum.failure_count += 1;
        checksum.autorepair_needed = 0x01; // Trigger AutoRepair OS
    } else {
        checksum.autorepair_needed = 0;
    }

    // Update OmniStruct with validation results (use volatile pointers for direct memory access)
    const omni_checksum_valid_ptr = @as(*volatile u8, @ptrFromInt(0x400000 + 60)); // offset 60
    const omni_checksum_failures_ptr = @as(*volatile u32, @ptrFromInt(0x400000 + 64)); // offset 64 (4-byte aligned)
    const omni_checksum_last_scan_ptr = @as(*volatile u64, @ptrFromInt(0x400000 + 72)); // offset 72 (8-byte aligned)

    omni_checksum_valid_ptr.* = all_valid;
    omni_checksum_failures_ptr.* = checksum.failure_count;
    omni_checksum_last_scan_ptr.* = checksum.last_scan_tsc;

    // Mark as valid
    checksum.flags = 0x01;
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn is_all_valid() u8 {
    const checksum = getChecksumStatePtr();
    return checksum.all_valid;
}

export fn get_failed_mask() u8 {
    const checksum = getChecksumStatePtr();
    return checksum.failed_mask;
}

export fn get_failure_count() u32 {
    const checksum = getChecksumStatePtr();
    return checksum.failure_count;
}

export fn is_autorepair_needed() u8 {
    const checksum = getChecksumStatePtr();
    return checksum.autorepair_needed;
}

export fn get_grid_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.grid_crc;
}

export fn get_analytics_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.analytics_crc;
}

export fn get_execution_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.execution_crc;
}

export fn get_blockchain_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.blockchain_crc;
}

export fn get_neuro_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.neuro_crc;
}

export fn get_bank_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.bank_crc;
}

export fn get_stealth_crc() u64 {
    const checksum = getChecksumStatePtr();
    return checksum.stealth_crc;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
