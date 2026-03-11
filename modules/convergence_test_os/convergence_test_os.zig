// convergence_test_os.zig — Dual-kernel convergence verification
// Tests: 1000+ consecutive zero-divergence cycles + injected fault detection
// L25: v2.0 readiness gate

const std = @import("std");
const types = @import("convergence_test_types.zig");

fn getConvergenceStatePtr() *volatile types.ConvergenceTestState {
    return @as(*volatile types.ConvergenceTestState, @ptrFromInt(types.CONVERGENCE_BASE));
}

export fn init_plugin() void {
    const state = getConvergenceStatePtr();
    state.magic = 0x43565354;
    state.flags = 0x01;
    state.cycle_count = 0;

    state.consecutive_agreements = 0;
    state.convergence_confirmed = 0;
    state.peak_agreements = 0;

    state.injection_test_run = 0;
    state.injection_detected = 0;
    state.test_phase = 0;
    state.saved_divergence_count = 0;

    state.v2_ready = 0;

    state.escalation_triggered = 0;
    state.escalation_reason = 0;
}

export fn run_convergence_cycle() void {
    const state = getConvergenceStatePtr();
    state.cycle_count +|= 1;

    // Phase 1: Normal convergence tracking (cycles 1-499, 501+)
    if (state.test_phase == 0 or state.test_phase == 2) {
        // Read Cross-Validator state @ 0x4B0000
        const cv_div_ptr: *volatile u32 = @ptrFromInt(0x4B001C); // divergences offset
        const cv_divergences: u32 = cv_div_ptr.*;

        // Read Proof Checker state @ 0x4C0000
        const proof_ptr: *volatile u8 = @ptrFromInt(0x4C0020); // proof_score offset
        const proof_score: u8 = proof_ptr.*;

        // Check convergence criterion: all 4 theorems proven + no divergences
        const is_converged: bool = (proof_score == 4) and (cv_divergences == state.saved_divergence_count);

        if (is_converged) {
            state.consecutive_agreements +|= 1;
            if (state.consecutive_agreements > state.peak_agreements) {
                state.peak_agreements = state.consecutive_agreements;
            }

            // Check convergence milestone
            if (state.consecutive_agreements >= types.CONVERGENCE_TARGET) {
                state.convergence_confirmed = 1;
            }
        } else {
            // Reset on any divergence
            state.consecutive_agreements = 0;
        }
    }

    // Phase 2: Divergence detection validation (injected fault test)
    if (state.cycle_count == 500 and state.injection_test_run == 0) {
        // Start injection test
        state.injection_test_run = 1;
        state.test_phase = 1; // injecting

        // Save baseline divergence count
        const cv_div_ptr: *volatile u32 = @ptrFromInt(0x4B001C);
        state.saved_divergence_count = cv_div_ptr.*;

        // Inject a fault: write 0 to seL4 isolation_verified flag @ 0x4A0029 (offset 41)
        const sel4_isolation_ptr: *volatile u8 = @ptrFromInt(0x4A0029);
        sel4_isolation_ptr.* = 0x00;
    }

    // Phase 2B: Wait for divergence to be detected (cycles 501-510)
    if (state.test_phase == 1) {
        const cv_div_ptr: *volatile u32 = @ptrFromInt(0x4B001C);
        const cv_divergences: u32 = cv_div_ptr.*;

        // Check if divergence was detected
        if (cv_divergences > state.saved_divergence_count) {
            state.injection_detected = 1;
            state.injection_test_run = 2; // passed
            state.test_phase = 2; // recovery

            // Restore seL4 isolation_verified = 1 (recover)
            const sel4_isolation_ptr: *volatile u8 = @ptrFromInt(0x4A0029);
            sel4_isolation_ptr.* = 0x01;
        }

        // Timeout: if divergence not detected by cycle 520, mark as failed
        if (state.cycle_count > 520 and state.injection_test_run == 1) {
            state.injection_test_run = 3; // failed
            state.test_phase = 2;

            // Restore anyway
            const sel4_isolation_ptr: *volatile u8 = @ptrFromInt(0x4A0029);
            sel4_isolation_ptr.* = 0x01;
        }
    }

    // v2.0 Readiness Gate: both convergence AND injection test pass
    if (state.convergence_confirmed == 1 and state.injection_test_run == 2) {
        state.v2_ready = 1;
    }
}

// Accessors
export fn get_consecutive_agreements() u32 {
    return getConvergenceStatePtr().consecutive_agreements;
}

export fn get_peak_agreements() u32 {
    return getConvergenceStatePtr().peak_agreements;
}

export fn is_convergence_confirmed() u8 {
    return getConvergenceStatePtr().convergence_confirmed;
}

export fn is_injection_test_passed() u8 {
    const state = getConvergenceStatePtr();
    return if (state.injection_test_run == 2) 1 else 0;
}

export fn is_v2_ready() u8 {
    return getConvergenceStatePtr().v2_ready;
}

export fn get_test_phase() u8 {
    return getConvergenceStatePtr().test_phase;
}

export fn get_injection_detected() u8 {
    return getConvergenceStatePtr().injection_detected;
}

export fn get_cycle_count() u64 {
    return getConvergenceStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getConvergenceStatePtr();
    return if (state.magic == 0x43565354) 1 else 0;
}
