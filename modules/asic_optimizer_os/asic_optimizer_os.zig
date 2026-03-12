// asic_optimizer_os.zig — ASIC mining optimization (frequency scaling, voltage tuning, power profiling)

const types = @import("asic_optimizer_types.zig");

fn getASICOptStatePtr() *volatile types.ASICOptimizationState {
    return @as(*volatile types.ASICOptimizationState, @ptrFromInt(types.ASIC_OPT_STATE_BASE));
}

fn getASICChipPtr(index: u8) *volatile types.ASICChipOptimization {
    if (index >= types.MAX_ASICS) return undefined;
    const addr = types.ASIC_OPT_CHIPS_BASE + @as(usize, index) * @sizeOf(types.ASICChipOptimization);
    return @as(*volatile types.ASICChipOptimization, @ptrFromInt(addr));
}

fn getPowerSamplePtr(index: u32) *volatile types.PowerSample {
    if (index >= types.MAX_POWER_SAMPLES) return undefined;
    const addr = types.ASIC_OPT_SAMPLES_BASE + @as(usize, index) * @sizeOf(types.PowerSample);
    return @as(*volatile types.PowerSample, @ptrFromInt(addr));
}

/// Dynamic frequency scaling based on temperature
fn scale_frequency_for_temp(chip_id: u8, current_temp: u8) u16 {
    const state = getASICOptStatePtr();
    const chip = getASICChipPtr(chip_id);

    const new_freq = state.target_frequency;

    // Temperature-based scaling (hotter = lower freq)
    if (current_temp > 85) {
        new_freq = state.target_frequency - 50;  // Reduce 50 MHz
    } else if (current_temp > 80) {
        new_freq = state.target_frequency - 25;
    } else if (current_temp < 50) {
        new_freq = state.target_frequency + 50;  // Boost if cold
    }

    // Clamp to safe range
    if (new_freq < state.min_frequency) new_freq = state.min_frequency;
    if (new_freq > state.max_frequency) new_freq = state.max_frequency;

    chip.target_frequency = new_freq;
    chip.temperature = current_temp;

    return new_freq;
}

/// Voltage optimization for power efficiency
fn optimize_voltage(chip_id: u8, frequency_mhz: u16) u16 {
    const state = getASICOptStatePtr();
    const chip = getASICChipPtr(chip_id);

    var voltage: u16 = 900;  // Default 900mV

    // Voltage scaling with frequency
    if (frequency_mhz <= 500) {
        voltage = 850;
    } else if (frequency_mhz <= 600) {
        voltage = 880;
    } else if (frequency_mhz <= 700) {
        voltage = 920;
    } else {
        voltage = 950;
    }

    // Apply profile adjustments
    if (state.power_profile == @intFromEnum(types.PowerProfile.efficiency)) {
        voltage = @as(u16, @intCast(@as(i32, @intCast(voltage)) - 30));
    } else if (state.power_profile == @intFromEnum(types.PowerProfile.performance)) {
        voltage = @as(u16, @intCast(@as(i32, @intCast(voltage)) + 30));
    }

    chip.voltage_mv = voltage;
    return voltage;
}

/// Estimate power consumption based on frequency and voltage
fn estimate_power(frequency_mhz: u16, voltage_mv: u16) u16 {
    // P ≈ C * V^2 * F (simplified)
    // Base: 50W @ 600MHz/900mV
    // Scaling: power ∝ freq * voltage^2

    const base_power: i32 = 50;
    const base_freq: i32 = 600;
    const base_voltage: i32 = 900;

    const freq_ratio = @divTrunc((@as(i32, @intCast(frequency_mhz)) * 1000), base_freq);
    const voltage_cast = @as(i32, @intCast(voltage_mv));
    const voltage_ratio = @divTrunc((voltage_cast * voltage_cast), (base_voltage * base_voltage));

    const estimated = @divTrunc((base_power * freq_ratio * voltage_ratio), 1_000_000);

    if (estimated < 20) return 20;
    if (estimated > 150) return 150;

    return @as(u16, @intCast(estimated));
}

/// Record power sample for profiling
fn record_power_sample(asic_id: u8, power_watts: u16, frequency_mhz: u16, temp: u8) void {
    _ = frequency_mhz;  // Used for future frequency-based power modeling
    _ = temp;           // Used for thermal power coefficient

    const chip = getASICChipPtr(asic_id);

    // Circular buffer in chip struct
    chip.power_samples[@as(usize, chip.power_sample_idx)] = power_watts;
    chip.power_sample_idx = @as(u8, @intCast((chip.power_sample_idx + 1) % 16));
}

/// Detect chip faults and degradation
fn detect_faults(chip_id: u8, hashrate: u64, temp: u8) u8 {
    const state = getASICOptStatePtr();
    const chip = getASICChipPtr(chip_id);

    // Fault criteria:
    // 1. Excessive temperature (>95°C)
    // 2. Low hashrate vs expected (stalled chip)
    // 3. Repeated errors over time

    var fault_detected: u8 = 0;

    if (temp > 95) {
        fault_detected = 1;
        state.thermal_throttle_count += 1;
    }

    // Expected hashrate: ~15-30 GH/s for S19 Pro @ normal freq
    if (hashrate < 1_000_000_000) {  // <1 GH/s = stalled
        fault_detected = 1;
        chip.error_count += 1;
    }

    if (fault_detected == 1) {
        if (chip.status == 0) {
            chip.status = 1;  // Mark degraded
            state.chips_degraded += 1;
        } else if (chip.status == 1 and state.cycle_count - chip.last_error_cycle < 100) {
            chip.status = 2;  // Mark failed
            state.chips_failed += 1;
        }
        chip.last_error_cycle = state.cycle_count;
    }

    return fault_detected;
}

/// Apply power profile to all chips
fn apply_power_profile(profile: u8) void {
    const state = getASICOptStatePtr();

    if (profile > 3) return;

    if (profile == @intFromEnum(types.PowerProfile.balanced)) {
        state.target_frequency = 600;
        state.core_voltage_mv = 900;
    } else if (profile == @intFromEnum(types.PowerProfile.performance)) {
        state.target_frequency = 800;
        state.core_voltage_mv = 950;
    } else if (profile == @intFromEnum(types.PowerProfile.efficiency)) {
        state.target_frequency = 500;
        state.core_voltage_mv = 850;
    }

    state.power_profile = profile;

    // Apply to all active chips
    var i: u8 = 0;
    while (i < state.asic_count) : (i += 1) {
        const chip = getASICChipPtr(i);
        chip.target_frequency = state.target_frequency;
        chip.voltage_mv = state.core_voltage_mv;
    }
}

pub export fn init_plugin() void {
    const state = getASICOptStatePtr();
    state.magic = 0x414F5054;
    state.flags = 0;
    state.cycle_count = 0;
    state.asic_count = 1;  // Assume 1 ASIC for now
    state.active_asics = 1;
    state.power_profile = @intFromEnum(types.PowerProfile.balanced);
    state.freq_scaling_mode = @intFromEnum(types.FrequencyScalingMode.dynamic);
    state.target_frequency = 600;
    state.min_frequency = 500;
    state.max_frequency = 800;
    state.core_voltage_mv = 900;

    // Initialize first chip
    const chip = getASICChipPtr(0);
    chip.chip_id = 0;
    chip.asic_slot = 0;
    chip.status = 0;
    chip.current_frequency = 600;
    chip.target_frequency = 600;
    chip.voltage_mv = 900;
}

pub export fn asic_opt_set_power_profile(profile: u8) u8 {
    apply_power_profile(profile);
    return 1;
}

pub export fn asic_opt_scale_frequency(chip_id: u8, temperature: u8) u16 {
    const state = getASICOptStatePtr();

    if (chip_id >= state.asic_count) return 0;

    const new_freq = scale_frequency_for_temp(chip_id, temperature);
    const chip = getASICChipPtr(chip_id);
    chip.current_frequency = new_freq;

    return new_freq;
}

pub export fn asic_opt_optimize_voltage(chip_id: u8, frequency_mhz: u16) u16 {
    if (chip_id >= getASICOptStatePtr().asic_count) return 0;
    return optimize_voltage(chip_id, frequency_mhz);
}

pub export fn asic_opt_estimate_power(frequency_mhz: u16, voltage_mv: u16) u16 {
    return estimate_power(frequency_mhz, voltage_mv);
}

pub export fn asic_opt_record_sample(asic_id: u8, power_watts: u16, frequency_mhz: u16, temp: u8) void {
    const state = getASICOptStatePtr();
    if (asic_id >= state.asic_count) return;

    record_power_sample(asic_id, power_watts, frequency_mhz, temp);

    // Update global statistics
    const chip = getASICChipPtr(asic_id);
    chip.power_draw = power_watts;
    chip.current_frequency = frequency_mhz;

    var total_power: u32 = 0;
    var i: u8 = 0;
    while (i < state.asic_count) : (i += 1) {
        total_power += getASICChipPtr(i).power_draw;
    }
    state.total_power_draw = total_power;
    state.avg_power_per_chip = total_power / @as(u32, state.asic_count);
}

pub export fn asic_opt_detect_faults(chip_id: u8, hashrate: u64, temp: u8) u8 {
    const state = getASICOptStatePtr();
    if (chip_id >= state.asic_count) return 0;

    return detect_faults(chip_id, hashrate, temp);
}

pub export fn asic_opt_get_chip_status(chip_id: u8) u8 {
    const state = getASICOptStatePtr();
    if (chip_id >= state.asic_count) return 0xFF;

    const chip = getASICChipPtr(chip_id);
    return chip.status;
}

pub export fn asic_opt_get_power_efficiency() u32 {
    const state = getASICOptStatePtr();

    // Calculate GH/s per Watt
    if (state.total_power_draw == 0) return 0;

    const estimated_hashrate: u32 = 30_000;  // 30 GH/s total for balanced profile
    const efficiency = (estimated_hashrate * 1000) / state.total_power_draw;

    return efficiency;
}

pub export fn run_asic_opt_cycle() void {
    const state = getASICOptStatePtr();
    state.cycle_count += 1;

    var i: u8 = 0;
    while (i < state.asic_count) : (i += 1) {
        const chip = getASICChipPtr(i);

        // Simulate temperature (oscillates around 75°C)
        const temp_base: u8 = 75;
        const temp_delta = @as(u8, @intCast((state.cycle_count * 7) % 20));
        const temp = if (temp_delta > 10) temp_base + (temp_delta - 10) else temp_base;

        // Dynamic frequency scaling if enabled
        if (state.freq_scaling_mode == @intFromEnum(types.FrequencyScalingMode.dynamic)) {
            _ = asic_opt_scale_frequency(i, temp);
        }

        // Record power sample
        const power_est = estimate_power(chip.current_frequency, chip.voltage_mv);
        asic_opt_record_sample(i, power_est, chip.current_frequency, temp);

        // Fault detection
        const hashrate = 25_000_000_000;  // Stub: 25 GH/s
        _ = asic_opt_detect_faults(i, hashrate, temp);
    }
}

pub export fn ipc_dispatch() u64 {
    const ipc_req = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    const state = getASICOptStatePtr();
    if (state.magic != 0x414F5054) {
        init_plugin();
    }

    const request = ipc_req.*;
    var result: u64 = 0;

    switch (request) {
        0xA1 => {  // ASIC_OPT_SET_POWER_PROFILE
            const profile = @as(u8, @intCast(ipc_result.* & 0xFF));
            result = asic_opt_set_power_profile(profile);
        },
        0xA2 => {  // ASIC_OPT_SCALE_FREQUENCY
            const chip_id = @as(u8, @intCast(ipc_result.* & 0xFF));
            const temp = @as(u8, @intCast((ipc_result.* >> 8) & 0xFF));
            result = asic_opt_scale_frequency(chip_id, temp);
        },
        0xA3 => {  // ASIC_OPT_OPTIMIZE_VOLTAGE
            const chip_id = @as(u8, @intCast(ipc_result.* & 0xFF));
            const freq = @as(u16, @intCast((ipc_result.* >> 8) & 0xFFFF));
            result = asic_opt_optimize_voltage(chip_id, freq);
        },
        0xA4 => {  // ASIC_OPT_ESTIMATE_POWER
            const freq = @as(u16, @intCast(ipc_result.* & 0xFFFF));
            const voltage = @as(u16, @intCast((ipc_result.* >> 16) & 0xFFFF));
            result = asic_opt_estimate_power(freq, voltage);
        },
        0xA5 => {  // ASIC_OPT_DETECT_FAULTS
            const chip_id = @as(u8, @intCast(ipc_result.* & 0xFF));
            const hashrate = @as(u64, @intCast((ipc_result.* >> 8) & 0xFFFFFFFFFFFF));
            const temp = @as(u8, @intCast((ipc_result.* >> 56) & 0xFF));
            result = asic_opt_detect_faults(chip_id, hashrate, temp);
        },
        0xA6 => {  // ASIC_OPT_GET_EFFICIENCY
            result = asic_opt_get_power_efficiency();
        },
        else => {
            ipc_status.* = 0x03;
            return 1;
        },
    }

    ipc_status.* = 0x02;
    ipc_result.* = result;
    return 0;
}

pub fn main() void {
    init_plugin();
    run_asic_opt_cycle();
}
