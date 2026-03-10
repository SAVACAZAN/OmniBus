const types = @import("profiler_types.zig");

fn getProfilerStatePtr() *volatile types.ProfilerState {
    return @as(*volatile types.ProfilerState, @ptrFromInt(types.PROFILER_BASE));
}

pub fn init_plugin() void {
    const state = getProfilerStatePtr();
    state.magic = 0x50524F46;
    state.flags = 0;
    state.cycle_count = 0;
    state.functions_tracked = 0;
    state.total_calls = 0;
    state.avg_call_time = 0;
    state.max_latency = 0;
    state.hottest_function = 0xFFFF;
}

pub fn record_function_call(func_id: u16, cycles: u32) void {
    const state = getProfilerStatePtr();
    _ = func_id;
    state.total_calls +|= 1;
    if (cycles > state.max_latency) {
        state.max_latency = cycles;
    }
}

pub fn run_profiler_cycle() void {
    const state = getProfilerStatePtr();
    state.cycle_count +|= 1;
}
