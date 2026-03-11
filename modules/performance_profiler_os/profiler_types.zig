pub const PROFILER_BASE: usize = 0x3E0000;
pub const MAX_FUNCTIONS: usize = 64;
pub const MAX_MODULES: usize = 33;

pub const FunctionProfile = extern struct {
    func_id: u16,
    call_count: u32,
    total_cycles: u64,
    min_cycles: u32,
    max_cycles: u32,
    _pad: u16 = 0,
};

pub const ModuleProfile = extern struct {
    module_id: u16,          // 0-32 for each OS layer
    _pad1: u16 = 0,
    call_count: u32,         // Total cycles of dispatch
    total_cycles: u64,       // Cumulative time in module
    min_cycles: u32,         // Fastest single cycle
    max_cycles: u32,         // Slowest single cycle
    avg_cycles: u32,         // Moving average (last 100 cycles)
    last_call_cycles: u32,   // Most recent cycle latency
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

    // Module-level profiling
    modules_profiled: u16,
    scheduler_cycles_total: u64,
    scheduler_jitter_max: u32,
    slowest_module_id: u16,
    fastest_module_id: u16,
    _pad2: [52]u8 = [_]u8{0} ** 52,
};
