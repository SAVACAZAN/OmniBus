// convergence_test_types.zig — Dual-kernel convergence validation
// L25: v2.0.0 readiness gate — 1000+ cycles + divergence detection test
// Memory: 0x4D0000–0x4DFFFF (64KB)

pub const CONVERGENCE_BASE: usize = 0x4D0000;
pub const CONVERGENCE_TARGET: u32 = 1000; // target consecutive agreements

pub const ConvergenceTestState = extern struct {
    magic: u32 = 0x43565354,             // "CVST" @ 0x4D0000
    flags: u8 = 0,                       // 4
    _pad1: [3]u8 = [_]u8{0} ** 3,        // 5

    cycle_count: u64 = 0,                // 8

    // Convergence tracking
    consecutive_agreements: u32 = 0,     // 16 — resets to 0 on divergence
    convergence_confirmed: u8 = 0,       // 20 — 1 when >= 1000 consecutive
    _pad2: [3]u8 = [_]u8{0} ** 3,        // 21
    peak_agreements: u32 = 0,            // 24 — max consecutive seen

    // Divergence detection validation
    injection_test_run: u8 = 0,          // 28 — 0=not run, 1=in progress, 2=passed, 3=failed
    injection_detected: u8 = 0,          // 29 — 1 if injected fault was caught
    test_phase: u8 = 0,                  // 30 — 0=normal, 1=injecting, 2=recovery
    _pad3: u8 = 0,                       // 31

    // Saved state for injection test
    saved_divergence_count: u32 = 0,     // 32 — baseline divergence count

    // v2.0 readiness gate
    v2_ready: u8 = 0,                    // 36 — 1 when convergence_confirmed=1 AND injection_test_run=2
    _pad4: [3]u8 = [_]u8{0} ** 3,        // 37

    // Escalation
    escalation_triggered: u8 = 0,        // 40
    escalation_reason: u8 = 0,           // 41
    _pad5: [86]u8 = [_]u8{0} ** 86,      // 42 — fill to 128B
    // = 128 bytes total
};
