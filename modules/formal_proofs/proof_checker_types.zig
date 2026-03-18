// proof_checker_types.zig — Formal proof verification state
// L24: Runtime theorem checkers for Ada security proofs
// Memory: 0x4C0000–0x4CFFFF (64KB)

pub const PROOF_CHECKER_BASE: usize = 0x4C0000;

pub const ProofCheckerState = extern struct {
    magic: u32 = 0x50524F46,         // "PROF" @ 0x4C0000
    flags: u8 = 0,                   // 4
    _pad1: [3]u8 = [_]u8{0} ** 3,    // 5

    cycle_count: u64 = 0,            // 8

    // Theorem verification results
    t1_memory_isolation: u8 = 1,     // 16 — 1=proven, 0=violated
    t2_ipc_authenticity: u8 = 1,     // 17 — 1=proven, 0=violated
    t3_cap_confinement: u8 = 1,      // 18 — 1=proven, 0=violated
    t4_timing_bound: u8 = 1,         // 19 — 1=proven, 0=violated

    // Statistics
    checks_passed: u32 = 0,          // 20
    checks_failed: u32 = 0,          // 24

    // Last violation
    last_violation_theorem: u8 = 0,  // 28 — theorem index (1-4, 0=none)
    _pad2: [3]u8 = [_]u8{0} ** 3,    // 29

    // Aggregated proof score (0-4 theorems proven)
    proof_score: u8 = 4,             // 32 — count of proven theorems
    is_fully_verified: u8 = 1,       // 33 — 1 if all 4 theorems verified

    // Escalation
    escalation_triggered: u8 = 0,    // 34
    escalation_reason: u8 = 0,       // 35 — 1=memory, 2=ipc, 3=cap, 4=timing

    _pad3: [88]u8 = [_]u8{0} ** 88,  // 36 — fill to 128B
    // = 128 bytes total
};
