// sel4_types.zig — seL4 Microkernel capability-based security
// L22: Formal invariant checking + capability delegation
// Memory: 0x4A0000–0x4AFFFF (64KB)

pub const SEL4_BASE: usize = 0x4A0000;
pub const MAX_CAPS: usize = 32;
pub const MAX_DECISIONS: usize = 16;

pub const CapType = enum(u8) {
    Null = 0,
    Memory = 1,
    Thread = 2,
    Endpoint = 3,
    Notification = 4,
    CNode = 5,
    Untyped = 6,
};

pub const CapabilityEntry = extern struct {
    cap_id: u16 = 0,                // 0
    cap_type: u8 = 0,               // 2 — CapType enum
    rights: u8 = 0,                 // 3 — bitmap: read=1, write=2, execute=4
    base_addr: u32 = 0,             // 4 — protected region base
    size_kb: u16 = 0,               // 8 — protected region size (KB)
    owner_layer: u8 = 0,            // 10 — owning OS layer index (0-31)
    granted_to: u8 = 0xFF,          // 11 — granted-to layer (0xFF = all)
    _pad: [20]u8 = [_]u8{0} ** 20,  // 12 — fill to 32B
    // = 32 bytes
};

pub const DecisionRecord = extern struct {
    decision_id: u16 = 0,                    // 0
    decision_type: u8 = 0,                   // 2 — 0=memory, 1=order, 2=ipc, 3=capability
    ada_result: u8 = 0,                      // 3 — 0=deny, 1=allow
    sel4_result: u8 = 0,                     // 4 — 0=deny, 1=allow
    diverged: u8 = 0,                        // 5 — 1 if mismatch
    cycle_lo: u32 = 0,                       // 6 — cycle counter (lo32)
    addr_or_price: u64 = 0,                  // 10 — address or price
    _pad: [14]u8 = [_]u8{0} ** 14,           // 18
    // = 32 bytes
};

pub const Sel4State = extern struct {
    magic: u32 = 0x53454C34,                 // "SEL4" @ 0x4A0000
    flags: u8 = 0,                           // 4
    _pad1: [3]u8 = [_]u8{0} ** 3,            // 5
    cycle_count: u64 = 0,                    // 8

    // Capability stats
    caps_allocated: u16 = 0,                 // 16
    caps_revoked: u16 = 0,                   // 18
    access_grants: u32 = 0,                  // 20
    access_denials: u32 = 0,                 // 24

    // Decision tracking
    decisions_made: u32 = 0,                 // 28
    decisions_head: u8 = 0,                  // 32 — ring buffer head (0-15)
    _pad2: [3]u8 = [_]u8{0} ** 3,            // 33

    // Formal invariants
    invariants_checked: u32 = 0,             // 36
    invariants_violated: u8 = 0,             // 40 — non-zero = formal violation
    isolation_verified: u8 = 1,              // 41 — 1 = memory isolation holds
    _pad3: [2]u8 = [_]u8{0} ** 2,            // 42

    // Escalation
    escalation_triggered: u8 = 0,            // 44
    escalation_reason: u8 = 0,               // 45 — 1=cap_violation, 2=isolation, 3=divergence
    _pad4: [40]u8 = [_]u8{0} ** 40,          // 46 — fill to 128B
    // = 128 bytes (total)
};
