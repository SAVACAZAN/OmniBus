// stratum_v2_gateway.zig — Stratum V2 protocol gateway (work distribution, share aggregation, pool sync)

const types = @import("stratum_v2_types.zig");

fn getStratumV2StatePtr() *volatile types.StratumV2State {
    return @as(*volatile types.StratumV2State, @ptrFromInt(types.STRATUM_V2_STATE_BASE));
}

fn getJobPtr(index: u32) *volatile types.MiningJob {
    if (index >= 256) return undefined;
    const addr = types.STRATUM_V2_JOBS_BASE + @as(usize, index) * @sizeOf(types.MiningJob);
    return @as(*volatile types.MiningJob, @ptrFromInt(addr));
}

fn getSharePtr(index: u32) *volatile types.MiningShare {
    if (index >= types.MAX_PENDING_SHARES) return undefined;
    const addr = types.STRATUM_V2_SHARES_BASE + @as(usize, index) * @sizeOf(types.MiningShare);
    return @as(*volatile types.MiningShare, @ptrFromInt(addr));
}

fn getConnectionPtr(index: u32) *volatile types.ConnectionState {
    if (index >= types.MAX_ACTIVE_CONNECTIONS) return undefined;
    const addr = types.STRATUM_V2_CONNS_BASE + @as(usize, index) * @sizeOf(types.ConnectionState);
    return @as(*volatile types.ConnectionState, @ptrFromInt(addr));
}

/// Setup connection to Stratum V2 pool
fn setup_connection(pool_address: [*]const u8, pool_port: u16, username_hash: u64) u32 {
    _ = pool_address;  // Pool address handled by network layer

    const state = getStratumV2StatePtr();

    if (state.active_connections >= types.MAX_ACTIVE_CONNECTIONS) return 0xFFFFFFFF;

    const conn_id = state.active_connections;
    const conn = getConnectionPtr(conn_id);

    conn.connection_id = conn_id;
    conn.pool_port = pool_port;
    conn.username_hash = username_hash;
    conn.connected = 1;  // Assume connection established
    conn.authenticated = 0;
    conn.mining_subscribed = 0;

    state.active_connections += 1;
    state.setup_complete = 1;

    return conn_id;
}

/// Send mining.subscribe request
fn send_subscribe_request(conn_id: u32) u8 {
    const state = getStratumV2StatePtr();

    if (conn_id >= state.active_connections) return 0;

    const conn = getConnectionPtr(conn_id);
    conn.mining_subscribed = 1;
    state.messages_sent += 1;

    return 1;
}

/// Receive and process new mining job from pool
fn receive_mining_job(conn_id: u32, job_id: u32, difficulty: u32, nonce_start: u64, nonce_end: u64) u8 {
    const state = getStratumV2StatePtr();

    if (conn_id >= state.active_connections) return 0;

    const job = getJobPtr(job_id & 0xFF);
    job.job_id = job_id;
    job.channel_id = conn_id;
    job.difficulty = difficulty;
    job.nonce_start = nonce_start;
    job.nonce_end = nonce_end;
    job.job_validity_start = state.cycle_count;

    state.current_difficulty = difficulty;
    state.nonce_min = nonce_start;
    state.nonce_max = nonce_end;
    state.last_job_received = state.cycle_count;
    state.messages_received += 1;

    const conn = getConnectionPtr(conn_id);
    conn.last_received_cycle = state.cycle_count;

    return 1;
}

/// Submit a mining share to pool
fn submit_share(conn_id: u32, job_id: u32, nonce: u64, block_header: [*]const u8) u8 {
    const state = getStratumV2StatePtr();

    if (state.shares_submitted >= 0xFFFFFFFFFFFFFFFF) {
        state.shares_submitted = 0;  // Wraparound
    }

    const share_idx = @as(u32, @intCast(state.shares_submitted % types.MAX_PENDING_SHARES));
    const share = getSharePtr(share_idx);

    share.share_id = state.shares_submitted;
    share.job_id = job_id;
    share.channel_id = conn_id;
    share.nonce = nonce;
    share.timestamp_submitted = state.cycle_count;
    share.is_accepted = 0;

    // Copy block header (80 bytes)
    var i: u32 = 0;
    while (i < 80) : (i += 1) {
        share.block_header[i] = block_header[i];
    }

    state.shares_submitted += 1;
    state.messages_sent += 1;

    return 1;
}

/// Process share acceptance/rejection from pool
fn process_share_response(share_id: u64, accepted: u8) u8 {
    const state = getStratumV2StatePtr();
    const share_idx = @as(u32, @intCast(share_id % types.MAX_PENDING_SHARES));
    const share = getSharePtr(share_idx);

    if (accepted == 1) {
        share.is_accepted = 1;
        state.shares_accepted += 1;
    } else {
        share.rejection_reason = 1;  // Generic rejection
        state.shares_rejected += 1;
    }

    state.messages_received += 1;
    return 1;
}

/// Check for stale shares (job validity expired)
fn detect_stale_shares() u32 {
    const state = getStratumV2StatePtr();
    var stale_count: u32 = 0;

    var i: u32 = 0;
    while (i < types.MAX_PENDING_SHARES) : (i += 1) {
        const share = getSharePtr(i);

        if (share.share_id > 0 and share.is_accepted == 0) {
            const job = getJobPtr(share.job_id & 0xFF);
            const age = state.cycle_count - job.job_validity_start;

            // Job is stale after 1000 cycles (~100ms)
            if (age > 1000) {
                share.rejection_reason = 2;  // Stale
                state.shares_stale += 1;
                stale_count += 1;
            }
        }
    }

    return stale_count;
}

/// Calculate network latency (ping/pong)
fn measure_latency(rtt_us: u32) void {
    const state = getStratumV2StatePtr();
    state.rtt_us = rtt_us;
}

/// Check connection health (heartbeat timeout)
fn check_connection_health(conn_id: u32) u8 {
    const state = getStratumV2StatePtr();

    if (conn_id >= state.active_connections) return 0;

    const conn = getConnectionPtr(conn_id);
    const age = state.cycle_count - conn.last_received_cycle;

    if (age > conn.timeout_cycles) {
        conn.connected = 0;
        state.errors_encountered += 1;
        return 0;  // Connection dead
    }

    return 1;  // Connection healthy
}

/// Aggregate statistics from all connections
fn aggregate_statistics() u64 {
    const state = getStratumV2StatePtr();

    const total_shares: u64 = state.shares_accepted + state.shares_rejected + state.shares_stale;

    // Calculate effective share rate
    if (state.cycle_count > 0) {
        return (total_shares * 1000) / state.cycle_count;  // Shares per 1000 cycles
    }

    return 0;
}

pub export fn init_plugin() void {
    const state = getStratumV2StatePtr();
    state.magic = 0x53563246;
    state.flags = 0;
    state.cycle_count = 0;
    state.active_connections = 0;
    state.setup_complete = 0;
    state.channel_id = 0;
    state.job_id = 0;
}

pub export fn sv2_setup_connection(pool_address: u64, pool_port: u16, username_hash: u64) u32 {
    // pool_address is pointer to ASCII address string
    return setup_connection(@as([*]const u8, @ptrFromInt(pool_address)), pool_port, username_hash);
}

pub export fn sv2_send_subscribe(conn_id: u32) u8 {
    return send_subscribe_request(conn_id);
}

pub export fn sv2_receive_job(conn_id: u32, job_id: u32, difficulty: u32, nonce_start: u64, nonce_end: u64) u8 {
    return receive_mining_job(conn_id, job_id, difficulty, nonce_start, nonce_end);
}

pub export fn sv2_submit_share(conn_id: u32, job_id: u32, nonce: u64, block_header: u64) u8 {
    return submit_share(conn_id, job_id, nonce, @as([*]const u8, @ptrFromInt(block_header)));
}

pub export fn sv2_process_share_response(share_id: u64, accepted: u8) u8 {
    return process_share_response(share_id, accepted);
}

pub export fn sv2_detect_stale_shares() u32 {
    return detect_stale_shares();
}

pub export fn sv2_measure_latency(rtt_us: u32) void {
    measure_latency(rtt_us);
}

pub export fn sv2_check_connection(conn_id: u32) u8 {
    return check_connection_health(conn_id);
}

pub export fn sv2_get_statistics() u64 {
    return aggregate_statistics();
}

pub export fn sv2_get_share_rate() u64 {
    const state = getStratumV2StatePtr();
    return state.shares_accepted;
}

pub export fn sv2_get_active_connections() u32 {
    const state = getStratumV2StatePtr();
    return state.active_connections;
}

pub export fn run_sv2_cycle() void {
    const state = getStratumV2StatePtr();
    state.cycle_count += 1;

    // Health check all connections
    var i: u32 = 0;
    while (i < state.active_connections) : (i += 1) {
        _ = check_connection_health(i);
    }

    // Detect stale shares
    _ = detect_stale_shares();

    // Update heartbeat
    state.last_heartbeat = state.cycle_count;
}

pub export fn ipc_dispatch() u64 {
    const ipc_req = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    const state = getStratumV2StatePtr();
    if (state.magic != 0x53563246) {
        init_plugin();
    }

    const request = ipc_req.*;
    var result: u64 = 0;

    switch (request) {
        0xB1 => {  // SV2_SETUP_CONNECTION
            const pool_addr = ipc_result.*;
            const pool_port = @as(u16, @intCast((ipc_result.* >> 32) & 0xFFFF));
            const username = @as(u64, @intCast((ipc_result.* >> 48) & 0xFFFF));
            result = sv2_setup_connection(pool_addr, pool_port, username);
        },
        0xB2 => {  // SV2_SEND_SUBSCRIBE
            const conn_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            result = sv2_send_subscribe(conn_id);
        },
        0xB3 => {  // SV2_RECEIVE_JOB
            const conn_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            const job_id = @as(u32, @intCast((ipc_result.* >> 32) & 0xFFFFFFFF));
            result = sv2_receive_job(conn_id, job_id, 0, 0, 0);
        },
        0xB4 => {  // SV2_SUBMIT_SHARE
            const conn_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            const job_id = @as(u32, @intCast((ipc_result.* >> 32) & 0xFFFFFFFF));
            result = sv2_submit_share(conn_id, job_id, 0, 0);
        },
        0xB5 => {  // SV2_GET_STATISTICS
            result = sv2_get_statistics();
        },
        0xB6 => {  // SV2_GET_CONNECTION_COUNT
            result = sv2_get_active_connections();
        },
        else => {
            ipc_status.* = 0x03;
            return 1;
        },
    }

    ipc_status.* = 0x02;
    ipc_result.* = result;
    return 0;
}

pub fn main() void {
    init_plugin();
    run_sv2_cycle();
}
