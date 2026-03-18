// mev_guard_types.zig — MEV protection and sandwich attack detection
// L20: Maximal Extractable Value (MEV) resistance layer
// Memory: 0x3B0000–0x3BFFFF (64KB)

pub const MEV_GUARD_BASE: usize = 0x3B0000;
pub const MAX_SANDWICH_WINDOWS: usize = 16;
pub const MEV_WINDOW_CYCLES: u32 = 256; // Cycles to consider same "block"

/// MEV attack type enumeration
pub const AttackType = enum(u8) {
    None = 0,
    Sandwich = 1,
    FrontRun = 2,
    BackRun = 3,
    FlashLoan = 4,
};

/// Sandwich attack detection window (32 bytes)
pub const SandwichWindow = extern struct {
    window_id: u16,           // 0  — Window identifier
    attack_type: u8,          // 2  — AttackType enum
    confirmed: u8,            // 3  — 1 if attack confirmed, 0 if suspected
    price_before: i32,        // 4  — Price at window open
    price_mid: i32,           // 8  — Price during suspected attack
    price_after: i32,         // 12 — Price at window close
    buy_cycle: u64,           // 16 — Cycle of detected buy
    sell_cycle: u64,          // 24 — Cycle of detected sell
    // = 32 bytes
};

/// MEV Guard state (128 bytes @ 0x3B0000)
pub const MevGuardState = extern struct {
    magic: u32 = 0x4D455647,            // 0  — "MEVG" magic
    flags: u8,                          // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,     // 5  — alignment
    cycle_count: u64,                   // 8  — Total cycles executed

    // Detection statistics
    sandwiches_detected: u32,           // 16 — Total sandwich attacks found
    frontrun_detected: u32,             // 20 — Front-running patterns detected
    backrun_detected: u32,              // 24 — Back-running patterns detected
    attacks_blocked: u32,               // 28 — Attacks blocked by timing jitter

    // Timing jitter for order obfuscation
    jitter_cycles: u16,                 // 32 — Current jitter to apply
    jitter_seed: u16,                   // 34 — LFSR seed for randomness
    orders_delayed: u32,                // 36 — Total orders delayed by jitter

    // Window management
    window_head: u8,                    // 40 — Ring buffer write index
    window_count: u8,                   // 41 — Active windows (0-16)
    _pad2: [6]u8 = [_]u8{0} ** 6,     // 42 — alignment

    // Detection thresholds
    price_spike_threshold: u16,         // 48 — bps threshold (default: 50 = 0.5%)
    window_size_cycles: u32,            // 50 — MEV window duration (default: 256)

    // Escalation
    escalation_triggered: u8,           // 54 — Flag: MEV attack ongoing
    escalation_reason: u8,              // 55 — Error code
    _pad5: [72]u8 = [_]u8{0} ** 72,   // 56 → 128 bytes
};

/// Get default jitter range (0-8 cycles)
pub fn getDefaultMaxJitter() u16 {
    return 8;
}
