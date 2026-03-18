// asic_optimizer_types.zig — ASIC mining optimization (freq scaling, voltage tuning, power profiling)

pub const ASIC_OPTIMIZER_BASE: usize = 0x5A0000;
pub const MAX_ASICS: u32 = 4;
pub const MAX_POWER_SAMPLES: u32 = 128;

pub const PowerProfile = enum(u8) {
    balanced = 0,               // 600 MHz, 900mV, ~50W per chip
    performance = 1,            // 800 MHz, 950mV, ~100W per chip
    efficiency = 2,             // 500 MHz, 850mV, ~30W per chip
    custom = 3,                 // User-defined freq/voltage
};

pub const FrequencyScalingMode = enum(u8) {
    static = 0,                 // Fixed frequency
    dynamic = 1,                // Adjust based on temperature
    predictive = 2,             // ML-based scaling (future)
};

pub const ASICOptimizationState = extern struct {
    magic: u32 = 0x414F5054,    // "AOPT"
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    asic_count: u8 = 0,
    active_asics: u8 = 0,

    power_profile: u8 = @intFromEnum(PowerProfile.balanced),
    freq_scaling_mode: u8 = @intFromEnum(FrequencyScalingMode.dynamic),

    // Global power management
    total_power_draw: u32 = 0,                 // Watts
    avg_power_per_chip: u32 = 0,              // Watts
    power_efficiency: u32 = 0,                // GH/s per Watt * 1000

    // Frequency scaling stats
    target_frequency: u16 = 600,               // MHz
    min_frequency: u16 = 500,
    max_frequency: u16 = 800,
    frequency_adjustment_factor: i32 = 0,     // PPM

    // Voltage optimization
    core_voltage_mv: u16 = 900,               // millivolts
    target_voltage_mv: u16 = 900,

    // Thermal management
    max_temp_observed: u8 = 0,
    thermal_throttle_count: u32 = 0,

    // Fault detection
    chips_degraded: u8 = 0,
    chips_failed: u8 = 0,
    last_fault_cycle: u64 = 0,

    _pad2: [32]u8 = [_]u8{0} ** 32,
};

pub const ASICChipOptimization = extern struct {
    chip_id: u32 = 0,
    asic_slot: u8 = 0,
    chip_index: u8 = 0,
    status: u8 = 0,                           // 0=healthy, 1=degraded, 2=failed

    current_frequency: u16 = 600,             // MHz
    target_frequency: u16 = 600,
    voltage_mv: u16 = 900,                   // millivolts

    temperature: u8 = 0,                     // Celsius
    power_draw: u16 = 0,                     // Watts

    hashes_computed: u64 = 0,
    power_samples: [16]u16 = [_]u16{0} ** 16,  // Last 16 power readings
    power_sample_idx: u8 = 0,

    last_error_cycle: u64 = 0,
    error_count: u32 = 0,

    _pad: [16]u8 = [_]u8{0} ** 16,
};

pub const PowerSample = extern struct {
    cycle: u64 = 0,
    asic_id: u8 = 0,
    power_watts: u16 = 0,
    frequency_mhz: u16 = 0,
    temperature: u8 = 0,
    voltage_mv: u16 = 0,

    _pad: [8]u8 = [_]u8{0} ** 8,
};

pub const ASIC_OPT_STATE_BASE: usize = ASIC_OPTIMIZER_BASE;
pub const ASIC_OPT_CHIPS_BASE: usize = ASIC_OPTIMIZER_BASE + 0x100;
pub const ASIC_OPT_SAMPLES_BASE: usize = ASIC_OPTIMIZER_BASE + 0x800;
