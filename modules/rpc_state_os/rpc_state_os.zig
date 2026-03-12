// rpc_state_os.zig — RPC Client State Management (Phase 59)
// Recognizes, tracks, and manages RPC client sessions

const types = @import("rpc_state_types.zig");

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

fn getRpcStatePtr() *volatile types.RpcStateOS {
    return @as(*volatile types.RpcStateOS, @ptrFromInt(types.RPC_BASE));
}

fn getClientPtr(index: usize) *volatile types.RpcClient {
    if (index >= types.MAX_RPC_CLIENTS) return undefined;
    const base = types.RPC_BASE + @sizeOf(types.RpcStateOS);
    return @as(*volatile types.RpcClient, @ptrFromInt(base + index * @sizeOf(types.RpcClient)));
}

fn getSessionPtr(index: usize) *volatile types.RpcSession {
    if (index >= types.MAX_RPC_SESSIONS) return undefined;
    const base = types.RPC_BASE + @sizeOf(types.RpcStateOS) +
                 types.MAX_RPC_CLIENTS * @sizeOf(types.RpcClient);
    return @as(*volatile types.RpcSession, @ptrFromInt(base + index * @sizeOf(types.RpcSession)));
}

// ============================================================================
// INITIALIZATION
// ============================================================================

pub export fn init_plugin() void {
    const state = getRpcStatePtr();
    state.header.magic = 0x52504353;  // 'RPCS'
    state.header.version = 0x01000000;
    state.header.cycle_count = 0;
    state.header.timestamp = 0;  // TODO: initialize with actual timestamp

    state.header.total_clients_registered = 0;
    state.header.active_clients = 0;
    state.header.total_clients_banned = 0;

    state.header.total_sessions_created = 0;
    state.header.active_sessions = 0;
    state.header.total_sessions_expired = 0;

    state.header.total_rpc_calls = 0;
    state.header.total_rpc_errors = 0;
    state.header.total_rate_limit_hits = 0;
    state.header.total_authentication_failures = 0;

    state.header.total_bytes_sent = 0;
    state.header.total_bytes_received = 0;

    state.client_count = 0;
    state.session_count = 0;
    state.pending_call_count = 0;

    // Clear client slots
    var i: usize = 0;
    while (i < types.MAX_RPC_CLIENTS) : (i += 1) {
        const client = getClientPtr(i);
        client.client_id = 0;
        client.status = 0;  // unknown
        client.authentication_level = 0;
        client.created_cycle = 0;
        client.last_activity_cycle = 0;
    }

    // Clear session slots
    i = 0;
    while (i < types.MAX_RPC_SESSIONS) : (i += 1) {
        const session = getSessionPtr(i);
        session.session_id = 0;
        session.client_id = 0;
        session.is_active = 0;
        session.authenticated = 0;
    }
}

// ============================================================================
// CLIENT REGISTRATION & RECOGNITION
// ============================================================================

pub export fn register_rpc_client(
    ip_addr_ptr: [*]const u8,
    port: u16,
    client_type: u8,
) u32 {
    const state = getRpcStatePtr();

    // Find empty slot
    var i: usize = 0;
    while (i < types.MAX_RPC_CLIENTS) : (i += 1) {
        const slot = getClientPtr(i);
        if (slot.client_id == 0) {
            const client_id = state.header.total_clients_registered +| 1;
            slot.client_id = client_id;

            // Copy IP address
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                slot.ip_address[j] = ip_addr_ptr[j];
            }

            slot.port = port;
            slot.client_type = client_type;
            slot.status = 1;  // registered
            slot.authentication_level = 0;
            slot.created_cycle = state.header.cycle_count;
            slot.last_activity_cycle = state.header.cycle_count;
            slot.total_rpc_calls = 0;
            slot.total_errors = 0;
            slot.total_bytes_sent = 0;
            slot.total_bytes_received = 0;
            slot.rate_limit_requests_per_sec = 100;
            slot.current_request_count = 0;

            @memset(&slot.client_hash, 0);
            @memset(&slot.api_key_hash, 0);
            @memset(&slot.metadata, 0);
            slot.metadata_len = 0;

            state.header.total_clients_registered +|= 1;
            state.header.active_clients +|= 1;
            state.client_count = @intCast(@min(state.client_count + 1, types.MAX_RPC_CLIENTS));

            return client_id;
        }
    }

    state.header.total_authentication_failures +|= 1;
    return 0;  // Registration failed
}

pub export fn recognize_rpc_client(
    client_hash_ptr: [*]const u8,
    client_hash_len: u32,
) u32 {
    const state = getRpcStatePtr();

    // Find matching client by hash
    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id != 0) {
            // Check if hash matches
            if (client_hash_len == 32) {
                var hash_matches = true;
                var j: usize = 0;
                while (j < 32) : (j += 1) {
                    if (client.client_hash[j] != client_hash_ptr[j]) {
                        hash_matches = false;
                        break;
                    }
                }
                if (hash_matches) {
                    // Client recognized!
                    client.last_activity_cycle = state.header.cycle_count;
                    return client.client_id;
                }
            }
        }
    }

    return 0;  // Client not recognized
}

pub export fn set_client_authentication(
    client_id: u32,
    auth_level: u8,
    api_key_hash_ptr: [*]const u8,
) u8 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            client.authentication_level = auth_level;
            client.status = 2;  // authenticated

            // Copy API key hash if provided
            var j: usize = 0;
            while (j < 32) : (j += 1) {
                client.api_key_hash[j] = api_key_hash_ptr[j];
            }

            return 1;  // Success
        }
    }

    state.header.total_authentication_failures +|= 1;
    return 0;  // Client not found
}

// ============================================================================
// SESSION MANAGEMENT
// ============================================================================

pub export fn create_rpc_session(
    client_id: u32,
    session_timeout_cycles: u64,
) u64 {
    const state = getRpcStatePtr();

    // Find empty session slot
    var i: usize = 0;
    while (i < types.MAX_RPC_SESSIONS) : (i += 1) {
        const slot = getSessionPtr(i);
        if (slot.session_id == 0) {
            const session_id = state.header.total_sessions_created +| 1;

            slot.session_id = session_id;
            slot.client_id = client_id;
            slot.created_cycle = state.header.cycle_count;
            slot.last_activity_cycle = state.header.cycle_count;
            slot.session_timeout_cycles = session_timeout_cycles;
            slot.is_active = 1;
            slot.authenticated = 0;
            slot.permission_level = 0;
            slot.call_history_idx = 0;

            @memset(&slot.call_history, 0);

            state.header.total_sessions_created +|= 1;
            state.header.active_sessions +|= 1;
            state.session_count = @intCast(@min(state.session_count + 1, types.MAX_RPC_SESSIONS));

            return session_id;
        }
    }

    return 0;  // Session creation failed
}

pub export fn verify_rpc_session(session_id: u64) u8 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < state.session_count) : (i += 1) {
        const session = getSessionPtr(i);
        if (session.session_id == session_id and session.is_active == 1) {
            // Check timeout
            if ((state.header.cycle_count - session.created_cycle) > session.session_timeout_cycles) {
                session.is_active = 0;
                state.header.active_sessions = if (state.header.active_sessions > 0) state.header.active_sessions - 1 else 0;
                state.header.total_sessions_expired +|= 1;
                return 0;  // Session expired
            }

            session.last_activity_cycle = state.header.cycle_count;
            return 1;  // Valid session
        }
    }

    return 0;  // Session not found
}

// ============================================================================
// RATE LIMITING & TRAFFIC TRACKING
// ============================================================================

pub export fn check_client_rate_limit(
    client_id: u32,
    max_requests_per_sec: u32,
) u8 {
    const state = getRpcStatePtr();
    const window_duration = 2621440;  // ~1 second in CPU cycles

    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            // Check if we're in a new time window
            if ((state.header.cycle_count - client.last_request_time) > window_duration) {
                client.current_request_count = 1;
                client.last_request_time = state.header.cycle_count;
                return 1;  // Within limit
            }

            // Check limit in current window
            if (client.current_request_count >= max_requests_per_sec) {
                state.header.total_rate_limit_hits +|= 1;
                return 0;  // Rate limited
            }

            client.current_request_count +|= 1;
            return 1;  // Within limit
        }
    }

    return 0;  // Client not found
}

pub export fn track_client_traffic(
    client_id: u32,
    bytes_sent: u64,
    bytes_received: u64,
) u8 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            client.total_bytes_sent +|= bytes_sent;
            client.total_bytes_received +|= bytes_received;
            state.header.total_bytes_sent +|= bytes_sent;
            state.header.total_bytes_received +|= bytes_received;
            return 1;
        }
    }

    return 0;
}

// ============================================================================
// RPC CALL TRACKING
// ============================================================================

pub export fn record_rpc_call(
    client_id: u32,
    session_id: u64,
    method_hash: u32,
) u8 {
    const state = getRpcStatePtr();

    // Update client call count
    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            client.total_rpc_calls +|= 1;
            client.last_activity_cycle = state.header.cycle_count;
            break;
        }
    }

    // Update session call history
    i = 0;
    while (i < state.session_count) : (i += 1) {
        const session = getSessionPtr(i);
        if (session.session_id == session_id and session.is_active == 1) {
            session.call_history[session.call_history_idx] = method_hash;
            session.call_history_idx = (session.call_history_idx + 1) % 16;
            session.last_activity_cycle = state.header.cycle_count;
            break;
        }
    }

    state.header.total_rpc_calls +|= 1;
    return 1;
}

pub export fn record_rpc_error(client_id: u32) u8 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            client.total_errors +|= 1;
            break;
        }
    }

    state.header.total_rpc_errors +|= 1;
    return 1;
}

// ============================================================================
// CLIENT STATUS MANAGEMENT
// ============================================================================

pub export fn ban_rpc_client(client_id: u32) u8 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            client.status = 4;  // banned
            state.header.total_clients_banned +|= 1;

            if (state.header.active_clients > 0) {
                state.header.active_clients -= 1;
            }

            return 1;
        }
    }

    return 0;
}

pub export fn get_client_status(client_id: u32) u8 {
    var i: usize = 0;
    while (i < types.MAX_RPC_CLIENTS) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            return client.status;
        }
    }

    return 0;  // unknown
}

// ============================================================================
// CYCLE & MAINTENANCE
// ============================================================================

pub export fn run_rpc_cycle() void {
    const state = getRpcStatePtr();
    state.header.cycle_count +|= 1;

    // Clean up expired sessions
    var i: usize = 0;
    while (i < state.session_count) : (i += 1) {
        const session = getSessionPtr(i);
        if (session.session_id != 0 and session.is_active == 1) {
            if ((state.header.cycle_count - session.created_cycle) > session.session_timeout_cycles) {
                session.is_active = 0;
                if (state.header.active_sessions > 0) {
                    state.header.active_sessions -= 1;
                }
                state.header.total_sessions_expired +|= 1;
            }
        }
    }

    // Cleanup disconnected clients
    i = 0;
    while (i < state.client_count) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id != 0 and client.status != 0) {  // not unknown
            // Mark as disconnected if inactive for too long (100M cycles ~ 40ms)
            if ((state.header.cycle_count - client.last_activity_cycle) > 100_000_000) {
                if (client.status != 5) {  // not disconnected
                    client.status = 5;  // disconnected
                    if (state.header.active_clients > 0) {
                        state.header.active_clients -= 1;
                    }
                }
            }
        }
    }
}

// ============================================================================
// STATISTICS & QUERIES
// ============================================================================

pub export fn get_rpc_statistics() u64 {
    const state = getRpcStatePtr();
    state.stats.active_clients = state.header.active_clients;
    state.stats.active_sessions = state.header.active_sessions;
    state.stats.total_rpc_calls = state.header.total_rpc_calls;
    state.stats.total_errors = state.header.total_rpc_errors;
    state.stats.total_bytes_sent = state.header.total_bytes_sent;
    state.stats.total_bytes_received = state.header.total_bytes_received;
    state.stats.rate_limit_hits = state.header.total_rate_limit_hits;
    state.stats.auth_failures = state.header.total_authentication_failures;

    // Return pointer to stats in the state structure
    return @intFromPtr(&state.stats);
}

pub export fn get_client_info(client_id: u32) u64 {
    const state = getRpcStatePtr();

    var i: usize = 0;
    while (i < types.MAX_RPC_CLIENTS) : (i += 1) {
        const client = getClientPtr(i);
        if (client.client_id == client_id) {
            state.last_client_info.exists = 1;
            state.last_client_info.status = client.status;
            state.last_client_info.auth_level = client.authentication_level;
            state.last_client_info.total_calls = client.total_rpc_calls;
            state.last_client_info.total_errors = client.total_errors;
            state.last_client_info.bytes_sent = client.total_bytes_sent;
            state.last_client_info.bytes_received = client.total_bytes_received;

            return @intFromPtr(&state.last_client_info);
        }
    }

    state.last_client_info.exists = 0;
    state.last_client_info.status = 0;
    state.last_client_info.auth_level = 0;
    state.last_client_info.total_calls = 0;
    state.last_client_info.total_errors = 0;
    state.last_client_info.bytes_sent = 0;
    state.last_client_info.bytes_received = 0;

    return @intFromPtr(&state.last_client_info);
}

pub export fn is_initialized() u8 {
    const state = getRpcStatePtr();
    return if (state.header.magic == 0x52504353) 1 else 0;
}
