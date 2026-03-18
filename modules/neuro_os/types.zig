// types.zig — Neuro OS type definitions
// Genetic algorithm structures and shared memory layout

// ============================================================================
// Memory Layout
// ============================================================================

pub const NEURO_BASE: usize = 0x2D0000;
pub const KERNEL_AUTH: usize = 0x100050;

// ============================================================================
// Population Constants (Week 1)
// ============================================================================

pub const POPULATION_SIZE: u32 = 100; // GA population size
pub const MAX_GENERATION: u32 = 10000; // Max evolution cycles

// ============================================================================
// NeuroState — Module Header
// ============================================================================

pub const NeuroState = struct {
    magic: u32,                    // 0x4E45524F = "NERO"
    flags: u32,                    // Active flag + settings
    generation: u64,               // Current generation count
    evolution_cycles: u64,         // Total cycles run
    best_fitness: f64,             // Best fitness in population
    worst_fitness: f64,            // Worst fitness in population
    tsc_last_update: u64,          // Last TSC timestamp
    _reserved: [40]u8 = undefined, // Padding to 128 bytes
};

// ============================================================================
// Individual — Genome for Grid Trading Strategy
// ============================================================================

pub const Individual = struct {
    grid_spacing: f64,      // Distance between grid levels (in basis points)
    rebalance_trigger: f64, // Trigger % for rebalancing (e.g., 0.02 = 2%)
    order_size: f64,        // Base order size in USD
    position_max: f64,      // Maximum position size
    _reserved: [32]u8 = undefined, // Padding to 96 bytes
};

// ============================================================================
// GridParameters — Shared with Grid OS (0x110000)
// ============================================================================

pub const GridParameters = struct {
    grid_spacing: f64,
    rebalance_trigger: f64,
    order_size: f64,
    position_max: f64,
    _reserved: [48]u8 = undefined, // Padding to 96 bytes
};

// ============================================================================
// GridMetrics — Performance Data From Grid OS
// ============================================================================

pub const GridMetrics = struct {
    total_profit: f64,      // Realized profit in USD
    winning_trades: u32,    // Count of profitable trades
    losing_trades: u32,     // Count of losing trades
    total_trades: u32,      // Total trades executed
    max_drawdown: f64,      // Maximum drawdown (%/100)
    win_rate: f64,          // Win rate (0.0 - 1.0)
    _reserved: [40]u8 = undefined, // Padding to 128 bytes
};

// ============================================================================
// FitnessScore — Evaluation Result
// ============================================================================

pub const FitnessScore = struct {
    profit: f64,           // Profit component
    volatility: f64,       // Volatility penalty
    drawdown: f64,         // Drawdown penalty
    win_rate: f64,         // Win rate bonus
    total: f64,            // Combined fitness score
};
