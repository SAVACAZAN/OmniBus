pub const PROFILER_BASE: usize = 0x3E0000;
pub const MAX_FUNCTIONS: usize = 64;

pub const FunctionProfile = extern struct {
    func_id: u16,
    call_count: u32,
    total_cycles: u64,
    min_cycles: u32,
    max_cycles: u32,
    _pad: u16 = 0,
};

pub const ProfilerState = extern struct {
    magic: u32 = 0x50524F46,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    functions_tracked: u32,
    total_calls: u64,
    avg_call_time: u32,
    max_latency: u32,
    hottest_function: u16,
    _pad2: [78]u8 = [_]u8{0} ** 78,
};
