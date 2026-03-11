// cross_validator_os.zig — Dual-kernel divergence detection & arbitration
// Compares Ada Mother OS + seL4 Microkernel decisions
// Triggers system halt on divergence (Byzantine fault tolerance)

const std = @import("std");
const types = @import("cross_validator_types.zig");

fn getCVStatePtr() *volatile types.CrossValidatorState {
    return @as(*volatile types.CrossValidatorState, @ptrFromInt(types.CV_BASE));
}

fn getDivergenceLog() [*]volatile types.DivergenceRecord {
    return @as([*]volatile types.DivergenceRecord, @ptrFromInt(types.CV_BASE + 128));
}

export fn init_plugin() void {
    const state = getCVStatePtr();
    state.magic = 0x43564C44;
    state.flags = 0x01;
    state.cycle_count = 0;

    state.ada_decisions = 0;
    state.sel4_decisions = 0;
    state.agreements = 0;
    state.divergences = 0;

    state.halt_triggered = 0;
    state.halt_reason = 0;
    state.critical_divergences = 0;
    state.div_head = 0;

    state.last_divergence_cycle = 0;

    state.escalation_triggered = 0;
    state.escalation_reason = 0;
}

export fn run_validator_cycle() void {
    const state = getCVStatePtr();
    state.cycle_count +|= 1;

    // Read Ada Mother OS decision flag @ 0x100050 (auth gate)
    const ada_gate: *volatile u8 = @ptrFromInt(0x100050);
    const ada_decision: u8 = ada_gate.*;

    // Read seL4 isolation_verified flag @ 0x4A0041 (in sel4 state)
    const sel4_state_ptr: *volatile u8 = @ptrFromInt(0x4A0041);
    const sel4_isolation: u8 = sel4_state_ptr.*;

    // Simple comparison: both should indicate "okay" (1)
    // Ada: 0x70 typically means "validated"
    // seL4: 0x01 means "isolated"
    const ada_ok = if (ada_decision > 0) @as(u8, 1) else @as(u8, 0);
    const sel4_ok = if (sel4_isolation > 0) @as(u8, 1) else @as(u8, 0);

    if (ada_ok == sel4_ok) {
        state.agreements +|= 1;
    } else {
        state.divergences +|= 1;
        state.critical_divergences +|= 1;
        state.last_divergence_cycle = state.cycle_count;

        // Record divergence
        record_divergence_internal(2, ada_ok, sel4_ok);

        // If >= 3 critical divergences, halt system
        if (state.critical_divergences >= 3) {
            state.halt_triggered = 1;
            state.halt_reason = 3; // divergence threshold
            state.escalation_triggered = 1;
            state.escalation_reason = 3;
        }
    }
}

fn record_divergence_internal(severity: u8, ada_result: u8, sel4_result: u8) void {
    const state = getCVStatePtr();
    const log = getDivergenceLog();

    if (state.div_head >= types.MAX_DIVERGENCES) {
        return; // ring buffer full
    }

    const idx = state.div_head;
    log[idx].record_id = idx;
    log[idx].decision_type = 0; // memory/isolation
    log[idx].ada_result = ada_result;
    log[idx].sel4_result = sel4_result;
    log[idx].severity = severity;
    log[idx].cycle_lo = @as(u64, @intCast(state.cycle_count & 0xFFFFFFFF));

    state.div_head = idx + 1;
}

export fn record_decision(decision_type: u8, ada_result: u8, sel4_result: u8) u8 {
    const state = getCVStatePtr();

    state.ada_decisions +|= 1;
    state.sel4_decisions +|= 1;

    if (ada_result == sel4_result) {
        state.agreements +|= 1;
        return 0; // no divergence
    }

    state.divergences +|= 1;
    state.critical_divergences +|= 1;
    state.last_divergence_cycle = state.cycle_count;

    // Record in ring buffer
    const log = getDivergenceLog();
    if (state.div_head < types.MAX_DIVERGENCES) {
        const idx = state.div_head;
        log[idx].record_id = idx;
        log[idx].decision_type = decision_type;
        log[idx].ada_result = ada_result;
        log[idx].sel4_result = sel4_result;
        log[idx].severity = if (decision_type == 0) 2 else 1; // memory = critical
        log[idx].cycle_lo = @as(u64, @intCast(state.cycle_count & 0xFFFFFFFF));
        state.div_head +|= 1;
    }

    // If critical divergences >= 3, halt
    if (state.critical_divergences >= 3) {
        state.halt_triggered = 1;
        state.halt_reason = 3;
        state.escalation_triggered = 1;
        state.escalation_reason = 3;
    }

    return 1; // divergence detected
}

export fn check_halt() u8 {
    return getCVStatePtr().halt_triggered;
}

export fn get_divergences() u32 {
    return getCVStatePtr().divergences;
}

export fn get_agreements() u32 {
    return getCVStatePtr().agreements;
}

export fn get_critical_divergences() u8 {
    return getCVStatePtr().critical_divergences;
}

export fn get_cycle_count() u64 {
    return getCVStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getCVStatePtr();
    return if (state.magic == 0x43564C44) 1 else 0;
}
