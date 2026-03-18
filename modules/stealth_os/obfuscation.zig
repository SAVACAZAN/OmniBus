// obfuscation.zig — Order obfuscation and encryption for MEV protection
// Phase 13: Prevents sandwich attacks through order hiding and timing delays

const types = @import("types.zig");

// ============================================================================
// Order Obfuscation Techniques
// ============================================================================

/// Create an obfuscation key from entropy
pub fn generateObfuscationKey(key_id: u32) types.ObfuscationKey {
    var key = types.ObfuscationKey{
        .key_id = key_id,
        ._pad0 = 0,
        .key_material = [_]u8{0} ** 32,
        .nonce = [_]u8{0} ** 16,
        ._pad1 = [_]u8{0} ** 12,
    };

    // Seed key material from TSC (in real system: use RDRAND)
    const tsc = rdtsc();
    for (0..32) |i| {
        const byte_index = i % 8;
        const shift = @as(u6, @intCast((byte_index * 8) & 63));
        key.key_material[i] = @as(u8, @intCast((tsc >> shift) & 0xFF));
    }

    // Generate nonce from TSC bytes
    for (0..16) |i| {
        const byte_index = i % 8;
        const shift = @as(u6, @intCast((byte_index * 8) & 63));
        key.nonce[i] = @as(u8, @intCast((tsc >> shift) & 0xFF)) ^ @as(u8, @intCast(i));
    }

    return key;
}

/// Simple XOR-based encryption (placeholder for AES-256 in production)
pub fn encryptOrder(
    plaintext: [*]const u8,
    plaintext_len: usize,
    key: *const types.ObfuscationKey,
    ciphertext: [*]u8,
) usize {
    // XOR each byte with key material (rotating through 32-byte key)
    var encrypted_len: usize = 0;

    for (0..plaintext_len) |i| {
        const key_byte = key.key_material[i % 32];
        ciphertext[i] = plaintext[i] ^ key_byte;
        encrypted_len = i + 1;
    }

    return encrypted_len;
}

/// Decrypt order using matching key
pub fn decryptOrder(
    ciphertext: [*]const u8,
    ciphertext_len: usize,
    key: *const types.ObfuscationKey,
    plaintext: [*]u8,
) usize {
    // XOR is symmetric - same operation decrypts
    var decrypted_len: usize = 0;

    for (0..ciphertext_len) |i| {
        const key_byte = key.key_material[i % 32];
        plaintext[i] = ciphertext[i] ^ key_byte;
        decrypted_len = i + 1;
    }

    return decrypted_len;
}

// ============================================================================
// Obfuscation Strategies
// ============================================================================

/// Strategy 1: Order splitting - divide large order into smaller pieces
pub fn splitOrder(
    original_amount_cents: u64,
    num_pieces: u8,
) struct { piece_amount: u64, remainder: u64 } {
    if (num_pieces == 0) return .{ .piece_amount = 0, .remainder = original_amount_cents };

    const piece_amount = original_amount_cents / @as(u64, @intCast(num_pieces));
    const remainder = original_amount_cents % @as(u64, @intCast(num_pieces));

    return .{ .piece_amount = piece_amount, .remainder = remainder };
}

/// Strategy 2: Timing delay - randomize submission time
pub fn calculateDelayMs(min_ms: u32, max_ms: u32) u32 {
    if (min_ms >= max_ms) return min_ms;

    const tsc = rdtsc();
    const range = max_ms - min_ms;
    const random_offset = @as(u32, @intCast((tsc % @as(u64, @intCast(range))) & 0xFFFFFFFF));

    return min_ms + random_offset;
}

/// Strategy 3: Dummy orders - inject decoy orders to confuse sandwich attackers
pub fn createDummyOrder(
    real_amount_cents: u64,
    decoy_ratio: u8, // 0-255, where 128 = 1:1 ratio with real
) u64 {
    // Create dummy order in proportion to real order
    const dummy_amount = (real_amount_cents * @as(u64, @intCast(decoy_ratio))) / 128;
    return dummy_amount;
}

/// Strategy 4: Hybrid - combine multiple techniques
pub fn createHybridObfuscation(
    original_amount_cents: u64,
    split_into_pieces: u8,
    timing_delay_ms: u32,
    add_dummy_orders: bool,
) struct {
    pieces_count: u8,
    piece_amount: u64,
    total_delay_ms: u32,
    dummy_amount: u64,
} {
    _ = timing_delay_ms; // Parameter provided for future use
    const split = splitOrder(original_amount_cents, split_into_pieces);
    const delay = calculateDelayMs(100, 5000); // 100-5000ms randomization
    const dummy = if (add_dummy_orders) createDummyOrder(original_amount_cents, 64) else 0;

    return .{
        .pieces_count = split_into_pieces,
        .piece_amount = split.piece_amount,
        .total_delay_ms = delay,
        .dummy_amount = dummy,
    };
}

// ============================================================================
// Hash-based Commitment Scheme
// ============================================================================

/// Generate order hash for commitment (prevents order substitution)
pub fn hashOrder(
    order_data: [*]const u8,
    order_len: usize,
) [32]u8 {
    var hash: [32]u8 = [_]u8{0} ** 32;

    // Simple rolling hash (placeholder for SHA-256 in production)
    var hash_value: u64 = 0x9e3779b97f4a7c15; // FNV offset basis

    for (0..order_len) |i| {
        hash_value = hash_value ^ @as(u64, @intCast(order_data[i]));
        hash_value = (hash_value << 13) | (hash_value >> 51); // Rotate
        hash_value = hash_value *% 0xbf58476d1ce4e5b9; // Multiply by FNV prime
    }

    // Write hash to array
    for (0..8) |i| {
        const byte_index = i * 8;
        hash[byte_index] = @as(u8, @intCast((hash_value >> @intCast(byte_index * 8)) & 0xFF));
    }

    return hash;
}

/// Verify order commitment (ensure order wasn't tampered with)
pub fn verifyOrderCommitment(
    original_hash: [32]u8,
    current_order: [*]const u8,
    current_order_len: usize,
) bool {
    const current_hash = hashOrder(current_order, current_order_len);

    // Compare hashes
    for (0..32) |i| {
        if (current_hash[i] != original_hash[i]) {
            return false;
        }
    }

    return true;
}

// ============================================================================
// MEV Burn / Fairness Protocol
// ============================================================================

/// Calculate MEV amount to burn for fairness
pub fn calculateMevBurnAmount(profit_cents: u64, mev_burn_percentage_bps: u32) u64 {
    // MEV burn in basis points (10000 = 100%)
    // Example: 1000 profit, 500 bps (5%) = 50 profit burned
    return (profit_cents * @as(u64, @intCast(mev_burn_percentage_bps))) / 10000;
}

// ============================================================================
// Sandwich Attack Detection
// ============================================================================

/// Detect potential sandwich pattern in mempool
pub fn detectSandwichPattern(
    pending_tx_count: u32,
    high_gas_tx_count: u32,
    flash_loan_detected: bool,
) struct { is_sandwich_risk: bool, risk_score: u8 } {
    var risk_score: u8 = 0;

    // High pending transactions + high gas = potential front-running
    if (pending_tx_count > 50) risk_score += 30;
    if (high_gas_tx_count > 20) risk_score += 30;

    // Flash loans are sandwich signature
    if (flash_loan_detected) risk_score += 40;

    return .{
        .is_sandwich_risk = risk_score > 50,
        .risk_score = if (risk_score > 100) 100 else risk_score,
    };
}

// ============================================================================
// Utilities
// ============================================================================

/// Read current TSC (Time Stamp Counter)
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
