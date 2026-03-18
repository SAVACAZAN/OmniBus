const std = @import("std");
const types = @import("profiler_types.zig");

fn getProfilerStatePtr() *volatile types.ProfilerState {
    return @as(*volatile types.ProfilerState, @ptrFromInt(types.PROFILER_BASE));
}

fn getModuleProfilePtr(module_id: u16) *volatile types.ModuleProfile {
    const base = types.PROFILER_BASE + @sizeOf(types.ProfilerState);
    return @as(*volatile types.ModuleProfile, @ptrFromInt(base + @as(usize, module_id) * @sizeOf(types.ModuleProfile)));
}

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

export fn init_plugin() void {
    const state = getProfilerStatePtr();
    state.magic = 0x50524F46;
    state.flags = 0x01;
    state.cycle_count = 0;
    state.functions_tracked = 0;
    state.total_calls = 0;
    state.avg_call_time = 0;
    state.max_latency = 0;
    state.hottest_function = 0xFFFF;
    state.modules_profiled = 0;
    state.scheduler_cycles_total = 0;
    state.scheduler_jitter_max = 0;
    state.slowest_module_id = 0xFFFF;
    state.fastest_module_id = 0xFFFF;

    // Zero-fill all module profiles
    var i: u16 = 0;
    while (i < types.MAX_MODULES) : (i += 1) {
        const profile = getModuleProfilePtr(i);
        profile.module_id = i;
        profile._pad1 = 0;
        profile.call_count = 0;
        profile.total_cycles = 0;
        profile.min_cycles = 0xFFFFFFFF;
        profile.max_cycles = 0;
        profile.avg_cycles = 0;
        profile.last_call_cycles = 0;
    }
}

export fn record_function_call(func_id: u16, cycles: u32) void {
    const state = getProfilerStatePtr();
    _ = func_id;
    state.total_calls +|= 1;
    if (cycles > state.max_latency) {
        state.max_latency = cycles;
    }
}

export fn record_module_cycle(module_id: u16, cycles: u32) void {
    if (module_id >= types.MAX_MODULES) return;

    const state = getProfilerStatePtr();
    const profile = getModuleProfilePtr(module_id);

    profile.call_count +|= 1;
    profile.total_cycles +|= @as(u64, cycles);
    profile.last_call_cycles = cycles;

    // Update min/max
    if (cycles < profile.min_cycles) {
        profile.min_cycles = cycles;
    }
    if (cycles > profile.max_cycles) {
        profile.max_cycles = cycles;
    }

    // Update moving average (very simple: (avg * 99 + current) / 100)
    if (profile.call_count == 1) {
        profile.avg_cycles = cycles;
    } else {
        const prev_avg = @as(u64, profile.avg_cycles);
        const new_avg = (prev_avg * 99 + @as(u64, cycles)) / 100;
        profile.avg_cycles = @as(u32, @intCast(new_avg & 0xFFFFFFFF));
    }

    // Update global state
    state.total_calls +|= 1;
    if (cycles > state.max_latency) {
        state.max_latency = cycles;
        state.slowest_module_id = module_id;
    }
}

export fn run_profiler_cycle() void {
    const state = getProfilerStatePtr();
    state.cycle_count +|= 1;
}

export fn get_module_profile(module_id: u16) types.ModuleProfile {
    if (module_id >= types.MAX_MODULES) {
        return .{
            .module_id = 0xFFFF,
            ._pad1 = 0,
            .call_count = 0,
            .total_cycles = 0,
            .min_cycles = 0,
            .max_cycles = 0,
            .avg_cycles = 0,
            .last_call_cycles = 0,
        };
    }
    const profile = getModuleProfilePtr(module_id);
    return profile.*;
}

export fn get_profiler_state() types.ProfilerState {
    const state = getProfilerStatePtr();
    return state.*;
}

export fn reset_profiler() void {
    init_plugin();
}
