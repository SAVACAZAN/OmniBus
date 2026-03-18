// cross_validator_types.zig — Dual-kernel divergence detection
// L23: Compare Ada Mother OS vs seL4 Microkernel decisions
// Memory: 0x4B0000–0x4BFFFF (64KB)

pub const CV_BASE: usize = 0x4B0000;
pub const MAX_DIVERGENCES: usize = 8;

pub const DivergenceRecord = extern struct {
    record_id: u16 = 0,                      // 0
    decision_type: u8 = 0,                   // 2 — 0=memory, 1=order, 2=ipc, 3=capability
    ada_result: u8 = 0,                      // 3 — 0=deny, 1=allow
    sel4_result: u8 = 0,                     // 4 — 0=deny, 1=allow
    severity: u8 = 0,                        // 5 — 0=info, 1=warn, 2=critical
    _pad: u16 = 0,                           // 6
    cycle_lo: u64 = 0,                       // 8 — cycle counter
    addr_or_price: u64 = 0,                  // 16 — associated address or price
    _pad2: [6]u8 = [_]u8{0} ** 6,            // 24 — fill to 32B
    // = 32 bytes
};

pub const CrossValidatorState = extern struct {
    magic: u32 = 0x43564C44,                 // "CVLD" @ 0x4B0000
    flags: u8 = 0,                           // 4
    _pad1: [3]u8 = [_]u8{0} ** 3,            // 5
    cycle_count: u64 = 0,                    // 8

    // Decision tracking
    ada_decisions: u32 = 0,                  // 16 — decisions from Ada
    sel4_decisions: u32 = 0,                 // 20 — decisions from seL4
    agreements: u32 = 0,                     // 24 — decisions that match
    divergences: u32 = 0,                    // 28 — decisions that diverge

    halt_triggered: u8 = 0,                  // 32 — 1 = system should halt
    halt_reason: u8 = 0,                     // 33 — reason code for halt
    critical_divergences: u8 = 0,            // 34 — count of critical divergences
    div_head: u8 = 0,                        // 35 — ring buffer head (0-7)

    last_divergence_cycle: u64 = 0,          // 36 — cycle of most recent divergence

    // Escalation
    escalation_triggered: u8 = 0,            // 44
    escalation_reason: u8 = 0,               // 45
    _pad4: [42]u8 = [_]u8{0} ** 42,          // 46 — fill to 128B
    // = 128 bytes (total)
};
