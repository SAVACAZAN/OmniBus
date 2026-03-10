// federation_os.zig — IPC message hub and router
// L18: Multi-kernel federation layer
// Memory: 0x3A0000–0x3AFFFF (64KB)

const std = @import("std");
const types = @import("federation_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getFederationStatePtr() *volatile types.FederationState {
    return @as(*volatile types.FederationState, @ptrFromInt(types.FEDERATION_BASE));
}

fn getMessageQueue() [*]volatile types.FederationMessage {
    // Messages start at offset 128 (after state struct)
    return @as([*]volatile types.FederationMessage, @ptrFromInt(types.FEDERATION_BASE + 128));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Federation OS
export fn init_plugin() void {
    if (initialized) return;

    const state = getFederationStatePtr();

    // Initialize state
    state.magic = 0x46454445; // "FEDE"
    state.flags = 0x01;
    state.cycle_count = 0;
    state.queue_head = 0;
    state.queue_tail = 0;
    state.queue_count = 0;
    state.total_sent = 0;
    state.total_delivered = 0;
    state.total_expired = 0;
    state.total_broadcasts = 0;
    state.registered_modules = 18; // Current module count
    state.last_msg_id = 0;
    state.escalation_triggered = 0;
    state.escalation_reason = 0;

    // Zero-init message buffer
    const messages = getMessageQueue();
    var i: usize = 0;
    while (i < types.MAX_MESSAGES) : (i += 1) {
        messages[i].msg_id = 0;
        messages[i].src_module = 0xFF;
        messages[i].dst_module = 0xFF;
        messages[i].msg_type = 0;
        messages[i].status = 0;
        messages[i].payload_type = 0;
        messages[i].payload = 0;
        messages[i].created_cycle = 0;
        messages[i].deadline_cycle = 0;
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Process messages and detect timeouts
// ============================================================================

/// Run Federation cycle - deliver messages and detect expirations
export fn run_federation_cycle() void {
    if (!initialized) return;

    const state = getFederationStatePtr();
    cycle_count += 1;
    state.cycle_count = cycle_count;

    // Scan message queue
    const messages = getMessageQueue();
    var idx: u8 = 0;
    while (idx < state.queue_count) : (idx += 1) {
        const msg_idx = (state.queue_tail + idx) % @as(u8, @intCast(types.MAX_MESSAGES));
        const message = &messages[msg_idx];

        // Skip empty entries
        if (message.src_module == 0xFF) continue;

        const msg_status = @as(types.MessageStatus, @enumFromInt(message.status));

        // Check deadline expiration
        if (message.deadline_cycle > 0 and cycle_count > message.deadline_cycle) {
            message.status = @intFromEnum(types.MessageStatus.Expired);
            state.total_expired += 1;
            continue;
        }

        // Advance message state: Queued → InTransit
        if (msg_status == types.MessageStatus.Queued) {
            message.status = @intFromEnum(types.MessageStatus.InTransit);
            continue;
        }

        // Advance message state: InTransit → Delivered (after 1 cycle)
        if (msg_status == types.MessageStatus.InTransit) {
            message.status = @intFromEnum(types.MessageStatus.Delivered);
            continue;
        }

        // Cleanup: Delivered messages older than 256 cycles can be evicted
        if (msg_status == types.MessageStatus.Delivered and (cycle_count - message.created_cycle) > 256) {
            // Evict by marking src as 0xFF
            message.src_module = 0xFF;
        }
    }
}

/// Send a message from src to dst
export fn send_message(src: u8, dst: u8, mtype: u8, payload: i64) u16 {
    if (!initialized) return 0xFFFF;
    if (src >= types.MAX_MODULES) return 0xFFFF;
    if (dst >= types.MAX_MODULES and dst != 0xFF) return 0xFFFF; // 0xFF = broadcast

    const state = getFederationStatePtr();

    // Check if queue is full
    if (state.queue_count >= types.MAX_MESSAGES) {
        state.escalation_triggered = 1;
        state.escalation_reason = 1; // Message queue full
        return 0xFFFF;
    }

    const messages = getMessageQueue();
    const idx = state.queue_head % @as(u8, @intCast(types.MAX_MESSAGES));

    // Assign message ID
    state.last_msg_id +%= 1;
    const msg_id = state.last_msg_id;

    // Create message
    messages[idx].msg_id = msg_id;
    messages[idx].src_module = src;
    messages[idx].dst_module = dst;
    messages[idx].msg_type = mtype;
    messages[idx].status = @intFromEnum(types.MessageStatus.Queued);
    messages[idx].payload_type = 0;
    messages[idx].payload = payload;
    messages[idx].created_cycle = cycle_count;
    messages[idx].deadline_cycle = cycle_count + types.getDefaultMessageTimeout();

    state.queue_head = (state.queue_head + 1) % @as(u8, @intCast(types.MAX_MESSAGES));
    state.queue_count += 1;
    state.total_sent += 1;

    // Track broadcasts
    if (dst == 0xFF) {
        state.total_broadcasts += 1;
    }

    return msg_id;
}

/// Receive oldest InTransit message for dst module
export fn receive_message(dst_module: u8) u16 {
    if (!initialized) return 0xFFFF;
    if (dst_module >= types.MAX_MODULES) return 0xFFFF;

    const state = getFederationStatePtr();
    const messages = getMessageQueue();

    // Find oldest InTransit message for this destination
    var idx: u8 = 0;
    while (idx < state.queue_count) : (idx += 1) {
        const msg_idx = (state.queue_tail + idx) % @as(u8, @intCast(types.MAX_MESSAGES));
        const message = &messages[msg_idx];

        // Skip if not for this module (and not broadcast)
        if (message.src_module == 0xFF) continue; // Skip evicted entries
        if (message.dst_module != dst_module and message.dst_module != 0xFF) continue;

        // Check if InTransit
        const msg_status = @as(types.MessageStatus, @enumFromInt(message.status));
        if (msg_status == types.MessageStatus.InTransit) {
            // Mark as Delivered
            message.status = @intFromEnum(types.MessageStatus.Delivered);
            return message.msg_id;
        }
    }

    return 0xFFFF; // No message found
}

/// Acknowledge a delivered message
export fn ack_message(msg_id: u16) u8 {
    if (!initialized) return 0;

    const state = getFederationStatePtr();
    const messages = getMessageQueue();

    // Find message by ID
    var idx: u8 = 0;
    while (idx < types.MAX_MESSAGES) : (idx += 1) {
        if (messages[idx].msg_id == msg_id) {
            const msg_status = @as(types.MessageStatus, @enumFromInt(messages[idx].status));
            if (msg_status == types.MessageStatus.Delivered) {
                messages[idx].status = @intFromEnum(types.MessageStatus.Acked);
                state.total_delivered += 1;
                return 1;
            }
            return 0; // Wrong status
        }
    }

    return 0; // Not found
}

/// Get message payload by ID
export fn get_message_payload(msg_id: u16) i64 {
    if (!initialized) return 0;

    const messages = getMessageQueue();
    var idx: u8 = 0;
    while (idx < types.MAX_MESSAGES) : (idx += 1) {
        if (messages[idx].msg_id == msg_id) {
            return messages[idx].payload;
        }
    }

    return 0; // Not found
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_total_sent() u64 {
    const state = getFederationStatePtr();
    return state.total_sent;
}

export fn get_total_delivered() u64 {
    const state = getFederationStatePtr();
    return state.total_delivered;
}

export fn get_total_expired() u64 {
    const state = getFederationStatePtr();
    return state.total_expired;
}

export fn get_total_broadcasts() u64 {
    const state = getFederationStatePtr();
    return state.total_broadcasts;
}

export fn get_queue_count() u8 {
    const state = getFederationStatePtr();
    return state.queue_count;
}

export fn get_registered_modules() u8 {
    const state = getFederationStatePtr();
    return state.registered_modules;
}

export fn get_escalation_triggered() u8 {
    const state = getFederationStatePtr();
    return state.escalation_triggered;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
