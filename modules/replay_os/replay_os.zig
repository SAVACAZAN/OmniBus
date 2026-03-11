// replay_os.zig — Event-Driven Transaction Replay (Phase 60)
// Deterministic state reconstruction from event journal

const std = @import("std");
const types = @import("replay_types.zig");

fn getReplayStatePtr() *volatile types.ReplayOsState {
    return @as(*volatile types.ReplayOsState, @ptrFromInt(types.REPLAY_BASE));
}

fn getReplayEventPtr(index: usize) *volatile types.ReplayEvent {
    if (index >= types.MAX_REPLAY_EVENTS) return undefined;
    const base = types.REPLAY_BASE + @sizeOf(types.ReplayOsState);
    return @as(*volatile types.ReplayEvent, @ptrFromInt(base + index * @sizeOf(types.ReplayEvent)));
}

fn getCompensationPtr(index: usize) *volatile types.SagaCompensation {
    if (index >= types.MAX_COMPENSATION_QUEUE) return undefined;
    const base = types.REPLAY_BASE + @sizeOf(types.ReplayOsState) +
                 types.MAX_REPLAY_EVENTS * @sizeOf(types.ReplayEvent);
    return @as(*volatile types.SagaCompensation, @ptrFromInt(base + index * @sizeOf(types.SagaCompensation)));
}

export fn init_plugin() void {
    const state = getReplayStatePtr();
    state.magic = 0x52504C59;  // 'RPLY'
    state.flags = 0x01;
    state.cycle_count = 0;
    state.mode = @intFromEnum(types.ReplayMode.idle);
    state.last_replayed_event_id = 0;
    state.total_replays = 0;
    state.total_compensations = 0;
    state.replay_error_count = 0;
    state.last_error_code = 0;
    state.checkpoint_cycle = 0;

    var i: usize = 0;
    while (i < types.MAX_REPLAY_EVENTS) : (i += 1) {
        const event = getReplayEventPtr(i);
        event.event_id = 0;
        event.correlation_id = 0;
        event.trade_id = 0;
        event.event_type = 0;
        event.timestamp = 0;
        event.data_offset = 0;
        event.data_size = 0;
        event.checksum = 0;
        event.status = 0;
    }

    i = 0;
    while (i < types.MAX_COMPENSATION_QUEUE) : (i += 1) {
        const comp = getCompensationPtr(i);
        comp.trade_id = 0;
        comp.saga_step = 0;
        comp.compensation_action = 0;
        comp.status = 0;
        comp.attempts = 0;
        comp.last_error = 0;
    }
}

export fn run_replay_cycle() void {
    const state = getReplayStatePtr();
    state.cycle_count +|= 1;

    // Check for pending replays
    var replayed_count: u32 = 0;
    var i: usize = 0;
    while (i < types.MAX_REPLAY_EVENTS) : (i += 1) {
        const event = getReplayEventPtr(i);
        if (event.event_id == 0 or event.status != 0) continue;

        // Status 0 = PENDING, 1 = REPLAYED, 2 = COMPENSATED
        // Perform forward replay by marking event as REPLAYED
        if (state.mode == @intFromEnum(types.ReplayMode.forward_replay)) {
            event.status = 1;  // REPLAYED
            state.last_replayed_event_id = event.event_id;
            replayed_count +|= 1;
        }
    }

    if (replayed_count > 0) {
        state.total_replays +|= replayed_count;
    }

    // Check for pending compensations
    var compensated_count: u32 = 0;
    i = 0;
    while (i < types.MAX_COMPENSATION_QUEUE) : (i += 1) {
        const comp = getCompensationPtr(i);
        if (comp.trade_id == 0 or comp.status != 0) continue;

        // Status 0 = PENDING, 1 = EXECUTED, 2 = FAILED
        if (state.mode == @intFromEnum(types.ReplayMode.compensation)) {
            comp.status = 1;  // EXECUTED
            compensated_count +|= 1;
        }
    }

    if (compensated_count > 0) {
        state.total_compensations +|= compensated_count;
    }
}

export fn forward_replay() void {
    const state = getReplayStatePtr();
    state.mode = @intFromEnum(types.ReplayMode.forward_replay);
}

export fn backward_replay() void {
    const state = getReplayStatePtr();
    state.mode = @intFromEnum(types.ReplayMode.backward_replay);
    state.last_replayed_event_id = 0;
}

export fn start_compensation(trade_id: u64, saga_step: u8, action: u8) bool {
    const state = getReplayStatePtr();

    var i: usize = 0;
    while (i < types.MAX_COMPENSATION_QUEUE) : (i += 1) {
        const comp = getCompensationPtr(i);
        if (comp.trade_id == 0) {
            comp.trade_id = trade_id;
            comp.saga_step = saga_step;
            comp.compensation_action = action;
            comp.status = 0;  // PENDING
            comp.attempts = 0;
            comp.last_error = 0;
            state.mode = @intFromEnum(types.ReplayMode.compensation);
            return true;
        }
    }

    state.replay_error_count +|= 1;
    state.last_error_code = 1;  // COMPENSATION_QUEUE_FULL
    return false;
}

export fn queue_replay_event(event: types.ReplayEvent) bool {
    const state = getReplayStatePtr();

    var i: usize = 0;
    while (i < types.MAX_REPLAY_EVENTS) : (i += 1) {
        const slot = getReplayEventPtr(i);
        if (slot.event_id == 0) {
            slot.event_id = event.event_id;
            slot.correlation_id = event.correlation_id;
            slot.trade_id = event.trade_id;
            slot.event_type = event.event_type;
            slot.timestamp = event.timestamp;
            slot.data_offset = event.data_offset;
            slot.data_size = event.data_size;
            slot.checksum = event.checksum;
            slot.status = 0;  // PENDING
            return true;
        }
    }

    state.replay_error_count +|= 1;
    state.last_error_code = 2;  // REPLAY_QUEUE_FULL
    return false;
}

export fn get_replay_state() u8 {
    return getReplayStatePtr().mode;
}

export fn get_total_replays() u32 {
    return getReplayStatePtr().total_replays;
}

export fn get_total_compensations() u32 {
    return getReplayStatePtr().total_compensations;
}

export fn get_last_error() u32 {
    return getReplayStatePtr().last_error_code;
}

export fn get_cycle_count() u64 {
    return getReplayStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getReplayStatePtr();
    return if (state.magic == 0x52504C59) 1 else 0;
}
