// crypto.zig — Cryptographic primitives for order signing
// Ported from Zig-toolz-Assembly backend/src/exchange/http_client.zig
// HMAC-SHA256, HMAC-SHA512, SHA-256, RDRAND
// Zero allocations, pure crypto, works in freestanding mode

const std = @import("std");

// ============================================================================
// HMAC-SHA256 — 32 bytes output
// ============================================================================

/// Generate HMAC-SHA256 signature (32 bytes)
/// Used for: LCX signing
pub fn hmacSha256(out: *[32]u8, message: []const u8, key: []const u8) void {
    std.crypto.auth.hmac.sha2.HmacSha256.create(out, message, key);
}

// ============================================================================
// HMAC-SHA512 — 64 bytes output
// ============================================================================

/// Generate HMAC-SHA512 signature (64 bytes)
/// Used for: Kraken signing
pub fn hmacSha512(out: *[64]u8, message: []const u8, key: []const u8) void {
    std.crypto.auth.hmac.sha2.HmacSha512.create(out, message, key);
}

// ============================================================================
// SHA-256 — 32 bytes output
// ============================================================================

/// Generate SHA-256 hash (32 bytes)
/// Used for: Kraken pre-hash before HMAC, Coinbase JWT signing
pub fn sha256(out: *[32]u8, message: []const u8) void {
    std.crypto.hash.sha2.Sha256.hash(message, out, .{});
}

// ============================================================================
// HMAC-SHA256 → Hex String (64 chars)
// ============================================================================

/// Generate HMAC-SHA256 and encode as lowercase hex string (64 chars)
/// Used for: API response verification (if needed)
pub fn hmacSha256Hex(out: *[64]u8, message: []const u8, key: []const u8) void {
    var mac: [32]u8 = undefined;
    hmacSha256(&mac, message, key);
    const hex = std.fmt.bytesToHex(mac, .lower);
    @memcpy(out, &hex);
}

// ============================================================================
// Hardware RNG — RDRAND instruction
// ============================================================================

/// Get 64-bit random value from RDRAND instruction
/// Used for: Nonce generation (Coinbase JWT), random values
pub fn getRandom64() u64 {
    var result: u64 = 0;
    asm volatile ("rdrand %[out]"
        : [out] "=r" (result),
    );
    // Note: In a bare-metal environment, RDRAND may fail if not supported
    // If carry flag is clear, fall back to RDTSC-based entropy
    return result;
}

/// Get 64-bit entropy from RDTSC (Time Stamp Counter)
/// Fallback if RDRAND is unavailable
pub fn getTscEntropy() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
