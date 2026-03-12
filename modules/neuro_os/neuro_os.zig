// neuro_os.zig — Neuro OS genetic algorithm optimizer
// Memory: 0x2D0000–0x34FFFF (512KB)
// Continuous AI optimization feedback loop (Week 1-12)
// Evolves Grid OS parameters for maximum profit over time

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var generation_count: u64 = 0;
var evolution_cycles: u64 = 0;

// Genetic algorithm population (Week 1-2)
var population: [types.POPULATION_SIZE]types.Individual = undefined;
var fitness_scores: [types.POPULATION_SIZE]f64 = undefined;

// ============================================================================
// NeuroState Access (Week 1)
// ============================================================================

/// Get mutable pointer to Neuro OS state header (0x2D0000)
fn getNeuroStatePtr() *volatile types.NeuroState {
    return @as(*volatile types.NeuroState, @ptrFromInt(types.NEURO_BASE));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Neuro OS plugin
/// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Initialize state header
    const state = getNeuroStatePtr();
    state.* = .{
        .magic = 0x4E45524F, // "NERO"
        .flags = 0x01,        // Mark as active
        .generation = 0,
        .evolution_cycles = 0,
        .best_fitness = 0.0,
        .worst_fitness = 1e9,
        .tsc_last_update = 0,
        ._reserved = [_]u8{0} ** 40,
    };

    // Initialize population with random individuals (Week 1)
    var i: u32 = 0;
    while (i < types.POPULATION_SIZE) : (i += 1) {
        population[i] = .{
            .grid_spacing = 100.0 + (@as(f64, @floatFromInt(i)) * 10.0),   // 100-1090
            .rebalance_trigger = 0.02 + (@as(f64, @floatFromInt(i % 10)) * 0.01), // 2-11%
            .order_size = 1000.0 + (@as(f64, @floatFromInt(i)) * 100.0),   // 1000-11900
            .position_max = 50000.0 + (@as(f64, @floatFromInt(i)) * 1000.0), // 50k-150k
            ._reserved = [_]u8{0} ** 32,
        };
        fitness_scores[i] = 0.0;
    }

    initialized = true;
}

// ============================================================================
// Main Evolution Cycle (Week 1-2: Fitness Function)
// ============================================================================

/// Main evolution cycle
/// Called every N trades by Ada Mother OS scheduler
/// Week 2: Calculate fitness based on Grid OS performance
export fn run_evolution_cycle() void {
    if (!initialized) return;

    // Check auth gate
    const auth = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH)).*;
    if (auth != 0x70) return;

    const state = getNeuroStatePtr();

    // Step 1: Read current Grid OS performance metrics
    const grid_metrics = readGridMetrics();

    // Step 2: Evaluate fitness of current population (Week 2)
    evaluateFitness(&grid_metrics);

    // Step 3: Selection and reproduction (Week 3-4)
    performSelection();

    // Step 4: Crossover and mutation (Week 4)
    performCrossover();
    performMutation();

    // Step 5: Apply best weights back to Grid OS
    applyBestWeightsToGrid();

    // Update counters
    evolution_cycles += 1;
    generation_count += 1;
    state.generation = generation_count;
    state.evolution_cycles = evolution_cycles;
    state.tsc_last_update = rdtsc();
}

// ============================================================================
// Fitness Evaluation (Week 2)
// ============================================================================

/// Week 2: Calculate fitness for entire population
/// Multi-objective: maximize profit, minimize drawdown, minimize volatility
fn evaluateFitness(grid_metrics: *const types.GridMetrics) void {
    var best_fitness: f64 = -1e9;
    var worst_fitness: f64 = 1e9;

    var i: u32 = 0;
    while (i < types.POPULATION_SIZE) : (i += 1) {
        const fitness = calculateFitness(&population[i], grid_metrics);
        fitness_scores[i] = fitness;

        if (fitness > best_fitness) best_fitness = fitness;
        if (fitness < worst_fitness) worst_fitness = fitness;
    }

    const state = getNeuroStatePtr();
    state.best_fitness = best_fitness;
    state.worst_fitness = worst_fitness;
}

/// Week 2: Fitness function (multi-objective)
/// Combines profit, drawdown, volatility, and win rate
fn calculateFitness(individual: *const types.Individual, metrics: *const types.GridMetrics) f64 {
    // Weights: profit (70%), win_rate (15%), size_efficiency (10%), drawdown (-5%)
    const profit_score = metrics.total_profit * 0.7;
    const win_rate_f = @as(f64, @floatFromInt(metrics.winning_trades));
    const total_f = @as(f64, @floatFromInt(metrics.total_trades + 1));
    const win_rate_score = (win_rate_f / total_f) * 0.15 * 1000.0;
    const size_score = (individual.order_size / 100000.0) * 0.10 * 1000.0; // Normalize to 100k base
    const drawdown_penalty = metrics.max_drawdown * (-5.0);

    const fitness = profit_score + win_rate_score + size_score + drawdown_penalty;
    return fitness;
}

// ============================================================================
// Selection (Week 3)
// ============================================================================

/// Week 3: Tournament selection of two parents
fn performSelection() void {
    // Simple tournament: pick 2 random individuals, keep the fittest
    var selected_indices: [2]u32 = undefined;
    var i: u32 = 0;
    while (i < 2) : (i += 1) {
        const idx1 = @mod(@as(u32, @truncate(rdtsc() >> 32)), types.POPULATION_SIZE);
        const idx2 = @mod(@as(u32, @truncate(rdtsc() >> 16)), types.POPULATION_SIZE);

        if (fitness_scores[idx1] > fitness_scores[idx2]) {
            selected_indices[i] = idx1;
        } else {
            selected_indices[i] = idx2;
        }
    }

    // Store selected for crossover step
    const state = getNeuroStatePtr();
    state._reserved[0] = @as(u8, @truncate(selected_indices[0]));
    state._reserved[1] = @as(u8, @truncate(selected_indices[1]));
}

// ============================================================================
// Crossover (Week 4)
// ============================================================================

/// Week 4: Crossover operator
/// Blend parameters from two parents
fn performCrossover() void {
    const state = getNeuroStatePtr();
    const parent1_idx = state._reserved[0];
    const parent2_idx = state._reserved[1];

    // Find worst individual to replace
    var worst_idx: u32 = 0;
    var worst_fitness: f64 = fitness_scores[0];
    var i: u32 = 1;
    while (i < types.POPULATION_SIZE) : (i += 1) {
        if (fitness_scores[i] < worst_fitness) {
            worst_fitness = fitness_scores[i];
            worst_idx = i;
        }
    }

    // Blend: average of parents
    const parent1 = population[parent1_idx];
    const parent2 = population[parent2_idx];

    population[worst_idx] = .{
        .grid_spacing = (parent1.grid_spacing + parent2.grid_spacing) / 2.0,
        .rebalance_trigger = (parent1.rebalance_trigger + parent2.rebalance_trigger) / 2.0,
        .order_size = (parent1.order_size + parent2.order_size) / 2.0,
        .position_max = (parent1.position_max + parent2.position_max) / 2.0,
        ._reserved = [_]u8{0} ** 32,
    };

    fitness_scores[worst_idx] = 0.0; // Reset for re-evaluation
}

// ============================================================================
// Mutation (Week 4)
// ============================================================================

/// Week 4: Mutation operator
/// Small random perturbations to maintain diversity
fn performMutation() void {
    // Mutate 10% of population
    var i: u32 = 0;
    const mutation_count = types.POPULATION_SIZE / 10;
    while (i < mutation_count) : (i += 1) {
        const shift_amount = @min(i * 8, 63);
        const idx = @mod(@as(u32, @truncate(rdtsc() >> @as(u6, @intCast(shift_amount)))), types.POPULATION_SIZE);
        const mutation_rate = 0.05; // 5% perturbation

        // Apply small random changes
        population[idx].grid_spacing *= (1.0 + mutation_rate);
        population[idx].rebalance_trigger *= (1.0 - mutation_rate / 2.0);
        population[idx].order_size *= (1.0 + mutation_rate / 2.0);

        // Clamp to valid ranges
        if (population[idx].grid_spacing < 10.0) population[idx].grid_spacing = 10.0;
        if (population[idx].grid_spacing > 10000.0) population[idx].grid_spacing = 10000.0;
        if (population[idx].rebalance_trigger < 0.001) population[idx].rebalance_trigger = 0.001;
        if (population[idx].rebalance_trigger > 0.5) population[idx].rebalance_trigger = 0.5;

        fitness_scores[idx] = 0.0; // Reset for re-evaluation
    }
}

// ============================================================================
// Apply Best Weights to Grid OS (Week 5)
// ============================================================================

/// Week 5: Feedback loop — apply best individual to Grid OS
/// Writes evolved parameters back to Grid OS @ 0x110000
fn applyBestWeightsToGrid() void {
    // Find best individual
    var best_idx: u32 = 0;
    var best_fitness: f64 = fitness_scores[0];
    var i: u32 = 1;
    while (i < types.POPULATION_SIZE) : (i += 1) {
        if (fitness_scores[i] > best_fitness) {
            best_fitness = fitness_scores[i];
            best_idx = i;
        }
    }

    // Write best individual to Grid OS memory
    const best = population[best_idx];

    // Grid OS shared memory @ 0x110000
    const grid_params_ptr = @as(*volatile types.GridParameters, @ptrFromInt(0x110000));
    grid_params_ptr.* = .{
        .grid_spacing = best.grid_spacing,
        .rebalance_trigger = best.rebalance_trigger,
        .order_size = best.order_size,
        .position_max = best.position_max,
        ._reserved = [_]u8{0} ** 48,
    };
}

// ============================================================================
// Grid Metrics Reader (Interfacing with Grid OS)
// ============================================================================

/// Read Grid OS performance metrics for fitness evaluation
/// Week 2: Called every evolution cycle to update performance data
fn readGridMetrics() types.GridMetrics {
    // Read from Grid OS metrics export @ 0x120000
    // Grid OS publishes real trading performance here every cycle
    const metrics_ptr = @as(*volatile types.GridMetrics, @ptrFromInt(0x120000));

    // Copy metrics from shared memory
    const metrics = metrics_ptr.*;

    // Validate metrics (if valid flag not set, return defaults)
    const valid_flag = @as(*volatile u8, @ptrFromInt(0x120000 + 64));
    if (valid_flag.* != 1) {
        // Grid metrics not yet ready, return neutral defaults
        return .{
            .total_profit = 0.0,
            .winning_trades = 0,
            .losing_trades = 0,
            .total_trades = 1, // Avoid division by zero
            .max_drawdown = 0.0,
            .win_rate = 0.0,
            ._reserved = [_]u8{0} ** 40,
        };
    }

    // Return actual metrics from Grid OS
    return metrics;
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get current generation count
export fn get_generation() u64 {
    return generation_count;
}

/// Get evolution cycles
export fn get_evolution_cycles() u64 {
    return evolution_cycles;
}

/// Get best fitness in current population
export fn get_best_fitness() f64 {
    var best: f64 = fitness_scores[0];
    var i: u32 = 1;
    while (i < types.POPULATION_SIZE) : (i += 1) {
        if (fitness_scores[i] > best) best = fitness_scores[i];
    }
    return best;
}

/// Get initialized state
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

// ============================================================================
// Debug & Testing Exports
// ============================================================================

/// Get individual parameter at index i
export fn get_individual_grid_spacing(idx: u32) f64 {
    if (idx >= types.POPULATION_SIZE) return 0.0;
    return population[idx].grid_spacing;
}

/// Get fitness score at index i
export fn get_fitness_score(idx: u32) f64 {
    if (idx >= types.POPULATION_SIZE) return 0.0;
    return fitness_scores[idx];
}

// ============================================================================
// Utilities
// ============================================================================

/// Read current TSC (Time Stamp Counter)
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// ============================================================================
// PHASE 10: IPC DISPATCHER (Kernel ↔ Module Communication)
// ============================================================================

/// IPC Control Block structure (shared with kernel @ 0x100110)
const IpcControlBlock = extern struct {
    request: u8,
    status: u8,
    module_id: u16,
    _pad: u32,
    cycle_count: u64,
    return_value: u64,
};

/// IPC Request Codes
const REQUEST_NONE = 0x00;
const REQUEST_NEURO_CYCLE = 0x02;

/// IPC Status Codes
const STATUS_IDLE = 0x00;
const STATUS_BUSY = 0x01;
const STATUS_DONE = 0x02;
const STATUS_ERROR = 0x03;

/// Get pointer to IPC control block (shared kernel memory)
fn getIpcBlockPtr() *volatile IpcControlBlock {
    return @as(*volatile IpcControlBlock, @ptrFromInt(0x100110));
}

/// IPC Dispatcher: Kernel calls this to invoke module functions
/// Returns 0 on success, non-zero on error
export fn ipc_dispatch() u64 {
    const ipc = getIpcBlockPtr();
    const req = ipc.request;

    // Initialize module on first call
    if (!initialized) {
        init_plugin();
    }

    // Route request to appropriate handler
    switch (req) {
        REQUEST_NEURO_CYCLE => {
            // Execute evolution cycle
            run_evolution_cycle();
            ipc.return_value = generation_count;
            ipc.status = STATUS_DONE;
            return 0;  // Success
        },
        else => {
            // Unknown request
            ipc.return_value = 0;
            ipc.status = STATUS_ERROR;
            return 1;  // Error
        },
    }
}
