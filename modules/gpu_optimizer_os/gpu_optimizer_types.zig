// gpu_optimizer_types.zig — GPU mining optimization (SIMD Keccak, adaptive difficulty, thermal)

pub const GPU_OPTIMIZER_BASE: usize = 0x590000;
pub const MAX_GPUS: u32 = 8;
pub const MAX_WORK_BATCHES: u32 = 16;

pub const OptimizationLevel = enum(u8) {
    off = 0,                    // No optimization
    basic = 1,                  // Standard loop unrolling
    simd = 2,                   // AVX2 4x parallel
    avx512 = 3,                 // AVX-512 8x parallel
};

pub const ThermalState = enum(u8) {
    normal = 0,
    warm = 1,                   // 70-85°C: reduce clocks 5%
    hot = 2,                    // 85-90°C: reduce clocks 15%
    critical = 3,               // >90°C: reduce clocks 30%
};

pub const GPUOptimizationState = extern struct {
    magic: u32 = 0x474F5054,    // "GOPT"
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    gpu_count: u8 = 0,
    active_gpus: u8 = 0,
    opt_level: u8 = @intFromEnum(OptimizationLevel.simd),
    _pad2: u8 = 0,

    // Performance tracking
    keccak_rounds_per_cycle: u64 = 1_000_000,  // ~1M Keccak rounds
    simd_speedup: u32 = 100,                   // Percentage (100 = 1x)
    thermal_reduction: u32 = 0,                // % clock reduction due to temp

    // Difficulty adaptation
    difficulty_target: u32 = 24,               // Target leading zeros
    difficulty_adjustment: i32 = 0,            // Delta from baseline
    hashrate_ma_cycles: u64 = 0,              // Moving average denominator

    // Work pipeline stats
    work_batches_queued: u32 = 0,
    work_batches_processed: u32 = 0,
    gpu_idle_cycles: u64 = 0,

    // Thermal stats per GPU
    gpu_temps: [8]u8 = [_]u8{0} ** 8,
    gpu_thermal_states: [8]u8 = [_]u8{0} ** 8,
    gpu_freq_reductions_pct: [8]u8 = [_]u8{0} ** 8,

    _pad3: [48]u8 = [_]u8{0} ** 48,
};

pub const KeccakBatch = extern struct {
    batch_id: u32 = 0,
    gpu_id: u8 = 0,
    batch_size: u32 = 0,                      // Number of nonces
    nonce_start: u64 = 0,
    nonce_end: u64 = 0,

    status: u8 = 0,                           // 0=pending, 1=processing, 2=complete
    _pad: [3]u8 = [_]u8{0} ** 3,

    cycles_used: u64 = 0,                    // Actual CPU cycles spent
    shares_found: u64 = 0,

    _pad2: [64]u8 = [_]u8{0} ** 64,
};

pub const AdaptiveDifficultyState = extern struct {
    current_difficulty: u32 = 24,
    baseline_difficulty: u32 = 24,
    target_hashrate: u64 = 100_000_000_000,  // 100 GH/s
    measured_hashrate: u64 = 0,
    hashrate_ma_window: u32 = 100,            // 100-cycle moving average

    adjustment_factor: i32 = 0,               // PPM adjustment
    last_adjustment_cycle: u64 = 0,
    overadjustment_limiter: u32 = 0,         // Anti-oscillation

    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const GPU_OPT_STATE_BASE: usize = GPU_OPTIMIZER_BASE;
pub const GPU_OPT_WORK_BATCH_BASE: usize = GPU_OPTIMIZER_BASE + 0x200;
pub const GPU_OPT_DIFFICULTY_BASE: usize = GPU_OPTIMIZER_BASE + 0x1000;
