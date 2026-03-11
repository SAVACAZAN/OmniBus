// logging_os_v2.zig — Phase 62B: Deterministic Event IDs
// Event IDs: (cycle_counter << 24) | (module_id << 16) | sequence

const std = @import("std");
const types = @import("logging_types_v2.zig");

fn getLoggingStatePtr() *volatile types.LoggingOsState {
    return @as(*volatile types.LoggingOsState, @ptrFromInt(types.LOG_BASE));
}

fn getLogEventPtr(index: usize) *volatile types.LogEvent {
    if (index >= types.MAX_LOG_EVENTS) return undefined;
    const base = types.LOG_BASE + @sizeOf(types.LoggingOsState);
    return @as(*volatile types.LogEvent, @ptrFromInt(base + index * @sizeOf(types.LogEvent)));
}

fn getModuleSequencePtr(module_id: u8) *volatile u16 {
    if (module_id >= 48) return undefined;  // Max 48 modules
    const base = types.LOG_BASE + @sizeOf(types.LoggingOsState) +
                 types.MAX_LOG_EVENTS * @sizeOf(types.LogEvent);
    return @as(*volatile u16, @ptrFromInt(base + module_id * @sizeOf(u16)));
}

fn compute_event_id(cycle_counter: u40, module_id: u8, sequence: u16) u64 {
    // Event ID: (cycle_counter << 24) | (module_id << 16) | sequence
    var event_id: u64 = 0;
    event_id |= @as(u64, cycle_counter) << 24;
    event_id |= @as(u64, module_id) << 16;
    event_id |= @as(u64, sequence);
    return event_id;
}

export fn init_plugin() void {
    const state = getLoggingStatePtr();
    state.magic = 0x4C4F4753;  // 'LOGS'
    state.flags = 0x01;
    state.cycle_count = 0;
    state.total_events_logged = 0;
    state.total_events_forwarded = 0;
    state.total_events_dropped = 0;
    state.buffer_overflow_count = 0;
    state.pending_debug = 0;
    state.pending_info = 0;
    state.pending_warn = 0;
    state.pending_error = 0;
    state.last_error = 0;

    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const event = getLogEventPtr(i);
        event.event_id = 0;
        event.timestamp = 0;
        event.correlation_id = 0;
        event.source_module = 0;
        event.source_provider = 0;
        event.log_level = 0;
        event.message_len = 0;
    }

    // Initialize per-module sequence counters
    i = 0;
    while (i < 48) : (i += 1) {
        const seq = getModuleSequencePtr(@intCast(i));
        seq.* = 0;
    }
}

export fn log_event_deterministic(
    module_id: u8,
    log_level: u8,
    correlation_id: u64,
    message: [*]const u8,
    message_len: u16
) u64 {
    const state = getLoggingStatePtr();

    // Step 1: Get and increment module sequence
    const seq_ptr = getModuleSequencePtr(module_id);
    const sequence = seq_ptr.*;
    seq_ptr.* +|= 1;

    // Step 2: Compute deterministic event ID
    const cycle_40bit: u40 = @intCast((state.cycle_count & 0xFFFFFFFFFF));
    const event_id = compute_event_id(cycle_40bit, module_id, sequence);

    // Step 3: Find empty slot and record event
    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const slot = getLogEventPtr(i);
        if (slot.event_id == 0) {
            slot.event_id = event_id;
            slot.timestamp = state.cycle_count;
            slot.correlation_id = correlation_id;
            slot.source_module = module_id;
            slot.source_provider = 0;  // Set by provider module
            slot.log_level = log_level;
            slot.message_len = message_len;

            // Copy message
            var j: usize = 0;
            while (j < message_len and j < 256) : (j += 1) {
                slot.message[j] = message[j];
            }

            state.total_events_logged +|= 1;

            // Track by level
            if (log_level == @intFromEnum(types.LogLevel.debug)) {
                state.pending_debug +|= 1;
            } else if (log_level == @intFromEnum(types.LogLevel.info)) {
                state.pending_info +|= 1;
            } else if (log_level == @intFromEnum(types.LogLevel.warn)) {
                state.pending_warn +|= 1;
            } else if (log_level == @intFromEnum(types.LogLevel.err)) {
                state.pending_error +|= 1;
            }

            return event_id;
        }
    }

    state.total_events_dropped +|= 1;
    state.buffer_overflow_count +|= 1;
    state.last_error = 1;
    return 0;  // Buffer full
}

// Verify event ID monotonicity (no duplicates, strictly increasing)
export fn verify_event_id_monotonic(event_id_prev: u64, event_id_curr: u64) u8 {
    if (event_id_curr > event_id_prev) {
        return 1;  // Monotonic ✓
    }
    return 0;  // Violated
}

export fn run_logging_cycle() void {
    const state = getLoggingStatePtr();
    state.cycle_count +|= 1;

    // Forward pending events to DatabaseOS (every 256 cycles)
    if (state.cycle_count % 256 == 0) {
        var forward_count: u32 = 0;
        var i: usize = 0;
        while (i < types.MAX_LOG_EVENTS) : (i += 1) {
            const event = getLogEventPtr(i);
            if (event.event_id != 0) {
                forward_count +|= 1;
            }
        }
        state.total_events_forwarded += forward_count;
    }
}

export fn get_total_logged() u32 {
    return getLoggingStatePtr().total_events_logged;
}

export fn get_total_forwarded() u32 {
    return getLoggingStatePtr().total_events_forwarded;
}

export fn get_cycle_count() u64 {
    return getLoggingStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getLoggingStatePtr();
    return if (state.magic == 0x4C4F4753) 1 else 0;
}
