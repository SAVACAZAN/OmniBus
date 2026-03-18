pub const COMPLIANCE_BASE: usize = 0x410000;

pub const ComplianceViolation = extern struct {
    violation_id: u16,
    violation_type: u8,
    severity: u8,
    timestamp_cycle: u64,
    entity_id: u16,
    _pad: u16 = 0,
};

pub const ComplianceState = extern struct {
    magic: u32 = 0x434F4D50,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    violations_detected: u32,
    violations_resolved: u32,
    last_audit_cycle: u64,
    audit_interval: u32,
    active_cases: u16,
    _pad2: [76]u8 = [_]u8{0} ** 76,
};
