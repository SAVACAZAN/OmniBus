pub const BREAKER_BASE: usize = 0x450000;

pub const CircuitBreakerState = extern struct {
    magic: u32 = 0x42524541,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    circuit_status: u8,
    trip_count: u32,
    last_trip_cycle: u64,
    trip_threshold: u32,
    recovery_cycles: u32,
    max_loss_percent: u16,
    _pad2: [70]u8 = [_]u8{0} ** 70,
};
