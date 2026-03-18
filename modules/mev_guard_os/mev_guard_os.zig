// mev_guard_os.zig — MEV resistance and sandwich attack detection
// L20: Maximal Extractable Value (MEV) protection layer
// Memory: 0x3B0000–0x3BFFFF (64KB)

const std = @import("std");
const types = @import("mev_guard_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getMevGuardStatePtr() *volatile types.MevGuardState {
    return @as(*volatile types.MevGuardState, @ptrFromInt(types.MEV_GUARD_BASE));
}

fn getSandwichWindowBuffer() [*]volatile types.SandwichWindow {
    // Windows start at offset 128 (after state struct)
    return @as([*]volatile types.SandwichWindow, @ptrFromInt(types.MEV_GUARD_BASE + 128));
}

/// Linear Feedback Shift Register for pseudo-random jitter
fn lfsr_step(seed: u16) u16 {
    const feedback: u16 = ((seed >> 15) ^ (seed >> 13) ^ (seed >> 12) ^ (seed >> 10)) & 1;
    return ((seed << 1) | feedback) & 0xFFFF;
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize MEV Guard OS
export fn init_plugin() void {
    if (initialized) return;

    const state = getMevGuardStatePtr();

    // Initialize state
    state.magic = 0x4D455647; // "MEVG"
    state.flags = 0x01;
    state.cycle_count = 0;
    state.sandwiches_detected = 0;
    state.frontrun_detected = 0;
    state.backrun_detected = 0;
    state.attacks_blocked = 0;
    state.jitter_cycles = 0;
    state.jitter_seed = 0xA5F3; // Non-zero seed
    state.orders_delayed = 0;
    state.window_head = 0;
    state.window_count = 0;
    state.price_spike_threshold = 50; // 50 bps = 0.5%
    state.window_size_cycles = types.MEV_WINDOW_CYCLES;
    state.escalation_triggered = 0;
    state.escalation_reason = 0;

    // Zero-init sandwich window buffer
    const windows = getSandwichWindowBuffer();
    var i: usize = 0;
    while (i < types.MAX_SANDWICH_WINDOWS) : (i += 1) {
        windows[i].window_id = 0;
        windows[i].attack_type = 0;
        windows[i].confirmed = 0;
        windows[i].price_before = 0;
        windows[i].price_mid = 0;
        windows[i].price_after = 0;
        windows[i].buy_cycle = 0;
        windows[i].sell_cycle = 0;
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Update jitter and finalize sandwich detection
// ============================================================================

/// Run MEV Guard cycle - process jitter and detect confirmed attacks
export fn run_mev_guard_cycle() void {
    if (!initialized) return;

    const state = getMevGuardStatePtr();
    cycle_count += 1;
    state.cycle_count = cycle_count;

    // Update LFSR for jitter randomness
    state.jitter_seed = lfsr_step(state.jitter_seed);
    const max_jitter = types.getDefaultMaxJitter();
    state.jitter_cycles = (state.jitter_seed % (max_jitter + 1));

    // Scan windows for completed sandwich detection
    const windows = getSandwichWindowBuffer();
    var window_idx: u8 = 0;
    while (window_idx < state.window_count) : (window_idx += 1) {
        const win_index = (window_idx) % @as(u8, @intCast(types.MAX_SANDWICH_WINDOWS));
        const window = &windows[win_index];

        // Skip if already confirmed or empty
        if (window.window_id == 0) continue;
        if (window.confirmed == 1) continue;

        // Check if enough cycles have passed to close window
        if (cycle_count >= (window.buy_cycle + state.window_size_cycles)) {
            // Window closed - analyze for sandwich pattern
            const price_delta = window.price_after - window.price_before;
            if (price_delta != 0) {
                // Price changed significantly - possible sandwich
                const threshold_delta = @divTrunc((state.price_spike_threshold * window.price_before), 10000);
                if (price_delta > threshold_delta or price_delta < -threshold_delta) {
                    window.confirmed = 1;
                    const attack_type = @as(types.AttackType, @enumFromInt(window.attack_type));
                    switch (attack_type) {
                        types.AttackType.Sandwich => state.sandwiches_detected += 1,
                        types.AttackType.FrontRun => state.frontrun_detected += 1,
                        types.AttackType.BackRun => state.backrun_detected += 1,
                        else => {},
                    }
                }
            }
        }
    }
}

/// Record a price event (buy/sell pressure detected)
export fn record_price_event(price: i32, direction: u8) u8 {
    if (!initialized) return 0;
    // direction: 0=neutral, 1=buy_pressure, 2=sell_pressure

    const state = getMevGuardStatePtr();
    const windows = getSandwichWindowBuffer();

    // If buy pressure, open new sandwich window
    if (direction == 1) {
        if (state.window_count < types.MAX_SANDWICH_WINDOWS) {
            const idx = state.window_head;
            state.window_head = (state.window_head + 1) % @as(u8, @intCast(types.MAX_SANDWICH_WINDOWS));

            windows[idx].window_id = @as(u16, @intCast(state.window_count + 1));
            windows[idx].attack_type = @intFromEnum(types.AttackType.Sandwich);
            windows[idx].confirmed = 0;
            windows[idx].price_before = price;
            windows[idx].price_mid = price;
            windows[idx].buy_cycle = cycle_count;
            windows[idx].sell_cycle = 0;

            if (state.window_count < 255) {
                state.window_count += 1;
            }

            return 1; // Event opened
        }
        return 0; // Window buffer full
    }

    // If sell pressure and we have open windows, record sell and check for sandwich
    if (direction == 2 and state.window_count > 0) {
        var window_idx: u8 = 0;
        while (window_idx < state.window_count) : (window_idx += 1) {
            const win_index = window_idx % @as(u8, @intCast(types.MAX_SANDWICH_WINDOWS));
            const window = &windows[win_index];

            if (window.window_id > 0 and window.sell_cycle == 0) {
                // Record sell and price after
                window.price_mid = price;
                window.sell_cycle = cycle_count;
                window.price_after = price;
                return 1; // Sell recorded
            }
        }
    }

    return 0; // No action taken
}

/// Check if order is safe to submit (not during detected MEV)
export fn check_order_safe(price: i32, side: u8) u8 {
    if (!initialized) return 1;
    // price: current price (API parameter, not used in this check)
    // side: 0=buy, 1=sell (API parameter, not used in this check)

    // Mark parameters as intentionally unused
    _ = price;
    _ = side;

    const state = getMevGuardStatePtr();

    // If escalation is triggered, consider orders unsafe
    if (state.escalation_triggered != 0) {
        return 0;
    }

    // If there are confirmed sandwich attacks in flight, delay orders
    const windows = getSandwichWindowBuffer();
    var window_idx: u8 = 0;
    while (window_idx < state.window_count) : (window_idx += 1) {
        const win_index = window_idx % @as(u8, @intCast(types.MAX_SANDWICH_WINDOWS));
        const window = &windows[win_index];

        // Check if window is open and we're in it
        if (window.window_id > 0 and window.confirmed == 0) {
            if (cycle_count < (window.buy_cycle + state.window_size_cycles)) {
                // We're inside an open window - flag as unsafe
                state.escalation_triggered = 1;
                state.escalation_reason = 1; // MEV activity detected
                return 0;
            }
        }
    }

    return 1; // Order appears safe
}

/// Get jitter cycles to apply before submitting order
export fn get_order_jitter() u16 {
    if (!initialized) return 0;

    const state = getMevGuardStatePtr();
    const jitter = state.jitter_cycles;

    // Step LFSR for next call
    state.jitter_seed = lfsr_step(state.jitter_seed);
    const max_jitter = types.getDefaultMaxJitter();
    state.jitter_cycles = (state.jitter_seed % (max_jitter + 1));

    // Track orders being delayed
    if (jitter > 0) {
        state.orders_delayed +%= 1;
    }

    return jitter;
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_sandwiches_detected() u32 {
    const state = getMevGuardStatePtr();
    return state.sandwiches_detected;
}

export fn get_frontrun_detected() u32 {
    const state = getMevGuardStatePtr();
    return state.frontrun_detected;
}

export fn get_backrun_detected() u32 {
    const state = getMevGuardStatePtr();
    return state.backrun_detected;
}

export fn get_attacks_blocked() u32 {
    const state = getMevGuardStatePtr();
    return state.attacks_blocked;
}

export fn get_orders_delayed() u32 {
    const state = getMevGuardStatePtr();
    return state.orders_delayed;
}

export fn get_current_jitter() u16 {
    const state = getMevGuardStatePtr();
    return state.jitter_cycles;
}

export fn get_escalation_triggered() u8 {
    const state = getMevGuardStatePtr();
    return state.escalation_triggered;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
