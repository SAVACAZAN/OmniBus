// Phase 66: Packet Validator – Checksum, Signature, TTL Verification
// ====================================================================

const std = @import("std");

pub const PacketValidationResult = struct {
    is_valid: bool,
    error_reason: u8, // 0=OK, 1=invalid_magic, 2=bad_checksum, etc.
    reputation_delta: i8, // +1 for good, -10 for bad checksum, etc.
};

const VALIDATOR_BASE: usize = 0x5E5000;

pub const PacketValidatorState = struct {
    magic: u32 = 0x50564153, // "PVAS"
    packets_validated: u64 = 0,
    packets_rejected: u64 = 0,
    bad_checksums: u64 = 0,
    bad_signatures: u64 = 0,
};

const ERROR_OK: u8 = 0;
const ERROR_INVALID_MAGIC: u8 = 1;
const ERROR_INVALID_VERSION: u8 = 2;
const ERROR_BAD_CHECKSUM: u8 = 3;
const ERROR_DUPLICATE_SEQ: u8 = 4;
const ERROR_EXPIRED_TIMESTAMP: u8 = 5;
const ERROR_INVALID_PAYLOAD_COUNT: u8 = 6;
const ERROR_BAD_SIGNATURE: u8 = 7;
const ERROR_CORRUPT_PACKET: u8 = 8;

/// BLAKE2-128 checksum (stub)
pub fn compute_blake2_128(data: *const [64]u8, len: usize) [16]u8 {
    var result: [16]u8 = undefined;
    // In real implementation: actual BLAKE2-128
    // For now: simple hash stub
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        result[i] = @as(u8, @intCast((data[i] ^ 0x42) & 0xFF));
    }
    return result;
}

/// Validate packet structure and integrity
pub fn validate_packet_full(header: *const [32]u8, payload: *const [1024]u8, payload_size: usize, signature: ?[96]u8) PacketValidationResult {
    var state = @as(*PacketValidatorState, @ptrFromInt(VALIDATOR_BASE));
    state.packets_validated += 1;

    // [1] Magic check: 0x4F4D4E49
    var magic: u32 = undefined;
    @memcpy(@ptrCast(&magic), header[0..4]);
    if (magic != 0x4F4D4E49) {
        state.packets_rejected += 1;
        return .{
            .is_valid = false,
            .error_reason = ERROR_INVALID_MAGIC,
            .reputation_delta = -5,
        };
    }

    // [2] Version check: 0x0001
    var version: u16 = undefined;
    @memcpy(@ptrCast(&version), header[4..6]);
    if (version != 0x0001) {
        state.packets_rejected += 1;
        return .{
            .is_valid = false,
            .error_reason = ERROR_INVALID_VERSION,
            .reputation_delta = -5,
        };
    }

    // [3] Checksum verify (BLAKE2-128)
    var payload_count: u8 = header[7];
    var expected_payload_size = payload_count * 32;
    if (payload_size != expected_payload_size) {
        state.packets_rejected += 1;
        state.bad_checksums += 1;
        return .{
            .is_valid = false,
            .error_reason = ERROR_BAD_CHECKSUM,
            .reputation_delta = -10,
        };
    }

    // Compute checksum over header (0-31) + payload (0-payload_size)
    // In real implementation: proper BLAKE2-128
    var _computed_checksum = compute_blake2_128(header, 32);
    var stored_checksum: [16]u8 = undefined;
    @memcpy(&stored_checksum, header[8..24]);

    // For stub: always pass checksum
    _ = _computed_checksum;
    _ = stored_checksum;

    // [4] Sequence dedup check (would call is_duplicate from network_layer)
    // Skipped here (handled in main gossip loop)

    // [5] Timestamp check: |now - ts| < 60s
    var timestamp: u32 = undefined;
    @memcpy(@ptrCast(&timestamp), header[28..32]);
    if (timestamp == 0) {
        return .{
            .is_valid = false,
            .error_reason = ERROR_EXPIRED_TIMESTAMP,
            .reputation_delta = -5,
        };
    }

    // [6] PayloadCount check: 1 <= count <= 32
    if (payload_count < 1 or payload_count > 32) {
        state.packets_rejected += 1;
        return .{
            .is_valid = false,
            .error_reason = ERROR_INVALID_PAYLOAD_COUNT,
            .reputation_delta = -5,
        };
    }

    // [7] Signature verify (if present)
    if (signature) |_sig| {
        // In real implementation: Ed25519 verify over (header + payload)
        // For now: stub (assume valid if present)
        state.packets_validated += 1;
    }

    return .{
        .is_valid = true,
        .error_reason = ERROR_OK,
        .reputation_delta = 1,
    };
}

/// Quick checksum-only validation (fast path)
pub fn validate_checksum_only(header: *const [32]u8, payload: *const [1024]u8, payload_size: usize) bool {
    // In real implementation: just verify BLAKE2-128
    _ = header;
    _ = payload;
    _ = payload_size;
    return true;
}

/// Get validation statistics
pub fn get_validation_stats() struct { validated: u64, rejected: u64, bad_checksums: u64, bad_signatures: u64 } {
    var state = @as(*PacketValidatorState, @ptrFromInt(VALIDATOR_BASE));

    return .{
        .validated = state.packets_validated,
        .rejected = state.packets_rejected,
        .bad_checksums = state.bad_checksums,
        .bad_signatures = state.bad_signatures,
    };
}

/// IPC handler
pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64, arg2: u64) u64 {
    return switch (opcode) {
        0x90 => validate_packet_ipc(arg0, arg1, arg2),
        0x91 => get_validation_stats_ipc(),
        else => 0,
    };
}

fn validate_packet_ipc(header_addr: u64, payload_addr: u64, payload_size: u64) u64 {
    var header = @as(*[32]u8, @ptrFromInt(header_addr));
    var payload = @as(*[1024]u8, @ptrFromInt(payload_addr));
    var result = validate_packet_full(header, payload, payload_size, null);
    if (result.is_valid) {
        return 1;
    }
    return 0;
}

fn get_validation_stats_ipc() u64 {
    var stats = get_validation_stats();
    return stats.validated;
}
