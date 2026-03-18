pub const SLASHING_BASE: usize = 0x430000;
pub const MAX_VIOLATIONS: usize = 64;

pub const SlashingEvent = extern struct {
    validator_id: u16,
    event_type: u8,
    severity: u8,
    timestamp_cycle: u64,
    penalty_amount: u64,
};

pub const SlashingProtectionState = extern struct {
    magic: u32 = 0x534C4153,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    slashing_events: u32,
    total_penalties: u64,
    insured_amount: u64,
    active_validators: u16,
    _pad2: [76]u8 = [_]u8{0} ** 76,
};
