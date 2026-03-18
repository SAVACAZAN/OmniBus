// logging_os.zig — Structured Logging Hub (Phase 57)
// Serilog JSON + ELK Stack + Application Insights

const std = @import("std");
const types = @import("logging_types.zig");

fn getLoggingStatePtr() *volatile types.LoggingOsState {
    return @as(*volatile types.LoggingOsState, @ptrFromInt(types.LOG_BASE));
}

fn getLogEventPtr(index: usize) *volatile types.LogEvent {
    if (index >= types.MAX_LOG_EVENTS) return undefined;
    const base = types.LOG_BASE + @sizeOf(types.LoggingOsState);
    return @as(*volatile types.LogEvent, @ptrFromInt(base + index * @sizeOf(types.LogEvent)));
}

export fn init_plugin() void {
    const state = getLoggingStatePtr();
    state.magic = 0x4C4F4753;
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

    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const event = getLogEventPtr(i);
        event.timestamp = 0;
        event.correlation_id = 0;
        event.source_module = 0;
        event.source_provider = 0;
        event.log_level = 0;
        event.message_len = 0;
    }
}

export fn run_logging_cycle() void {
    const state = getLoggingStatePtr();
    state.cycle_count +|= 1;

    // Process pending log events (batched every cycle)
    var debug_count: u8 = 0;
    var info_count: u8 = 0;
    var warn_count: u8 = 0;
    var error_count: u8 = 0;

    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const event = getLogEventPtr(i);
        if (event.message_len == 0) continue;

        switch (event.log_level) {
            0 => debug_count +|= 1,
            1 => info_count +|= 1,
            2 => warn_count +|= 1,
            3 => error_count +|= 1,
            else => {},
        }
    }

    state.pending_debug = debug_count;
    state.pending_info = info_count;
    state.pending_warn = warn_count;
    state.pending_error = error_count;
}

export fn post_log(
    correlation_id: u64,
    source_module: u8,
    source_provider: u8,
    log_level: u8,
    message: [*]const u8,
    message_len: u16,
) bool {
    const state = getLoggingStatePtr();
    if (message_len > 256) return false;

    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const event = getLogEventPtr(i);
        if (event.message_len == 0) {
            event.timestamp = state.cycle_count;
            event.correlation_id = correlation_id;
            event.source_module = source_module;
            event.source_provider = source_provider;
            event.log_level = log_level;
            event.message_len = message_len;

            var j: usize = 0;
            while (j < message_len) : (j += 1) {
                event.message[j] = message[j];
            }

            state.total_events_logged +|= 1;
            return true;
        }
    }

    state.total_events_dropped +|= 1;
    return false;
}

export fn forward_logs() u32 {
    var count: u32 = 0;

    var i: usize = 0;
    while (i < types.MAX_LOG_EVENTS) : (i += 1) {
        const event = getLogEventPtr(i);
        if (event.message_len > 0) {
            count +|= 1;
            event.message_len = 0;
        }
    }

    const state = getLoggingStatePtr();
    state.total_events_forwarded +|= count;
    return count;
}

export fn get_pending_count(log_level: u8) u8 {
    const state = getLoggingStatePtr();
    return switch (log_level) {
        0 => state.pending_debug,
        1 => state.pending_info,
        2 => state.pending_warn,
        3 => state.pending_error,
        else => 0,
    };
}

export fn get_total_logged() u32 {
    return getLoggingStatePtr().total_events_logged;
}

export fn get_cycle_count() u64 {
    return getLoggingStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getLoggingStatePtr();
    return if (state.magic == 0x4C4F4753) 1 else 0;
}
