const types = @import("breaker_types.zig");

fn getBreakerStatePtr() *volatile types.CircuitBreakerState {
    return @as(*volatile types.CircuitBreakerState, @ptrFromInt(types.BREAKER_BASE));
}

pub fn init_plugin() void {
    const state = getBreakerStatePtr();
    state.magic = 0x42524541;
    state.flags = 0;
    state.cycle_count = 0;
    state.circuit_status = 0;
    state.trip_count = 0;
    state.last_trip_cycle = 0;
    state.trip_threshold = 50;
    state.recovery_cycles = 65536;
    state.max_loss_percent = 500;
}

pub fn check_circuit(loss_percent: u16) u8 {
    const state = getBreakerStatePtr();
    if (loss_percent > state.max_loss_percent) {
        state.circuit_status = 1;
        state.trip_count +|= 1;
        state.last_trip_cycle = state.cycle_count;
        return 1;
    }
    return state.circuit_status;
}

pub fn run_breaker_cycle() void {
    const state = getBreakerStatePtr();
    state.cycle_count +|= 1;
    if (state.circuit_status == 1) {
        if ((state.cycle_count - state.last_trip_cycle) > state.recovery_cycles) {
            state.circuit_status = 0;
        }
    }
}
