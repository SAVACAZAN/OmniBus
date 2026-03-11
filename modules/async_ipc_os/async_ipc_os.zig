const std = @import("std");
const types = @import("async_ipc_types.zig");

fn getAsyncIpcStatePtr() *volatile types.AsyncIpcState {
    return @as(*volatile types.AsyncIpcState, @ptrFromInt(types.AIPC_BASE));
}

fn getEventPtr(priority: u8, index: usize) *volatile types.AsyncEvent {
    if (priority >= 3 or index >= types.QUEUE_DEPTH) return undefined;
    const base = types.AIPC_BASE + @sizeOf(types.AsyncIpcState);
    const offset = priority * types.QUEUE_DEPTH * @sizeOf(types.AsyncEvent) + index * @sizeOf(types.AsyncEvent);
    return @as(*volatile types.AsyncEvent, @ptrFromInt(base + offset));
}

export fn init_plugin() void {
    const state = getAsyncIpcStatePtr();
    state.magic = 0x41495043;
    state.flags = 0x01;
    state.cycle_count = 0;
    state.events_posted = 0;
    state.events_delivered = 0;
    state.events_expired = 0;
    state.events_dropped = 0;
    state.high_watermark = 0;
    state.pending_high = 0;
    state.pending_normal = 0;
    state.pending_low = 0;

    var priority: u8 = 0;
    while (priority < 3) : (priority += 1) {
        var i: usize = 0;
        while (i < types.QUEUE_DEPTH) : (i += 1) {
            const event = getEventPtr(priority, i);
            event.event_id = 0;
            event.status = 0;
            event.payload = 0;
        }
    }
}

export fn run_ipc_cycle() void {
    const state = getAsyncIpcStatePtr();
    state.cycle_count +|= 1;

    var priority: u8 = 0;
    while (priority < 3) : (priority += 1) {
        var i: usize = 0;
        while (i < types.QUEUE_DEPTH) : (i += 1) {
            const event = getEventPtr(priority, i);
            if (event.status == 0) continue;

            if (state.cycle_count > event.deadline_cycle) {
                event.status = 2;
                state.events_expired += 1;
                switch (priority) {
                    0 => state.pending_high = if (state.pending_high > 0) state.pending_high - 1 else 0,
                    1 => state.pending_normal = if (state.pending_normal > 0) state.pending_normal - 1 else 0,
                    else => state.pending_low = if (state.pending_low > 0) state.pending_low - 1 else 0,
                }
            } else {
                event.status = 1;
                state.events_delivered += 1;
                switch (priority) {
                    0 => state.pending_high = if (state.pending_high > 0) state.pending_high - 1 else 0,
                    1 => state.pending_normal = if (state.pending_normal > 0) state.pending_normal - 1 else 0,
                    else => state.pending_low = if (state.pending_low > 0) state.pending_low - 1 else 0,
                }
            }
        }
    }
}

export fn post_event(src: u8, dst: u8, event_type: u8, priority: u8, payload: i64, ttl_cycles: u32) bool {
    const state = getAsyncIpcStatePtr();
    if (priority >= 3) return false;

    var i: usize = 0;
    while (i < types.QUEUE_DEPTH) : (i += 1) {
        const event = getEventPtr(priority, i);
        if (event.status == 0 and event.event_id == 0) {
            event.event_id = @as(u16, @truncate(state.events_posted & 0xFFFF));
            event.src_module = src;
            event.dst_module = dst;
            event.event_type = event_type;
            event.priority = priority;
            event.status = 0;
            event.payload = payload;
            event.deadline_cycle = state.cycle_count + ttl_cycles;
            state.events_posted += 1;

            switch (priority) {
                0 => {
                    state.pending_high += 1;
                    if (state.pending_high > state.high_watermark) {
                        state.high_watermark = state.pending_high;
                    }
                },
                1 => state.pending_normal += 1,
                else => state.pending_low += 1,
            }
            return true;
        }
    }

    state.events_dropped += 1;
    return false;
}

export fn drain_events() u32 {
    var count: u32 = 0;

    var priority: u8 = 0;
    while (priority < 3) : (priority += 1) {
        var i: usize = 0;
        while (i < types.QUEUE_DEPTH) : (i += 1) {
            const event = getEventPtr(priority, i);
            if (event.status == 1 or event.status == 2) {
                count += 1;
                event.event_id = 0;
                event.status = 0;
            }
        }
    }
    return count;
}

export fn get_pending_count(priority: u8) u8 {
    const state = getAsyncIpcStatePtr();
    return switch (priority) {
        0 => state.pending_high,
        1 => state.pending_normal,
        else => state.pending_low,
    };
}

export fn get_events_posted() u32 {
    return getAsyncIpcStatePtr().events_posted;
}

export fn get_cycle_count() u64 {
    return getAsyncIpcStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getAsyncIpcStatePtr();
    return if (state.magic == 0x41495043) 1 else 0;
}
