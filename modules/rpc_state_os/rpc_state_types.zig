// rpc_state_types.zig — RPC Client State Management (Phase 59)
// Tracks RPC client connections, sessions, and recognition

const std = @import("std");

pub const RPC_BASE: usize = 0x650000;
pub const RPC_SIZE: usize = 0x10000; // 64KB segment

pub const MAX_RPC_CLIENTS = 256;
pub const MAX_RPC_SESSIONS = 1024;
pub const MAX_PENDING_CALLS = 512;

pub const RpcClientStatus = enum(u8) {
    unknown = 0,      // Client not recognized
    registered = 1,   // Client registered
    authenticated = 2, // Client authenticated
    rate_limited = 3, // Client rate limited
    banned = 4,       // Client IP banned
    disconnected = 5, // Connection closed
};

pub const RpcClientType = enum(u8) {
    unknown = 0,
    browser = 1,      // Browser WebSocket
    sdk = 2,          // Official SDK
    external = 3,     // External API client
    internal = 4,     // Internal tool
    bot = 5,          // Automated trader
    validator = 6,    // Validator node
};

pub const RpcClient = struct {
    client_id: u32,               // Unique client ID
    client_hash: [32]u8,          // SHA256 of client identifier
    client_type: u8,              // RpcClientType value

    ip_address: [4]u8,            // IPv4 address
    port: u16,

    status: u8,                   // RpcClientStatus value
    authentication_level: u8,     // 0=none, 1=basic, 2=token, 3=mTLS

    created_cycle: u64,           // When client first connected
    last_activity_cycle: u64,     // Last RPC call timestamp

    total_rpc_calls: u64,         // Lifetime call count
    total_errors: u32,            // Failed calls
    total_bytes_sent: u64,        // Bytes returned to client
    total_bytes_received: u64,    // Bytes received from client

    rate_limit_requests_per_sec: u32,  // Configured limit
    current_request_count: u32,        // Requests in current window
    last_request_time: u64,

    api_key_hash: [32]u8,         // Optional API key verification

    metadata: [128]u8,            // Client metadata (user agent, etc)
    metadata_len: u8,
};

pub const RpcSession = struct {
    session_id: u64,
    client_id: u32,

    created_cycle: u64,
    last_activity_cycle: u64,

    session_timeout_cycles: u64,  // When session expires
    is_active: u8,

    authenticated: u8,
    permission_level: u32,        // Bitmask of allowed operations

    call_history: [16]u32,        // Last 16 RPC calls (opcode)
    call_history_idx: u8,
};

pub const RpcPendingCall = struct {
    call_id: u64,
    client_id: u32,
    session_id: u64,

    method_hash: u32,             // FNV hash of RPC method name
    params_ptr: u64,              // Pointer to parameters
    params_len: u32,

    submitted_cycle: u64,
    timeout_cycle: u64,

    is_pending: u8,
    priority: u8,                 // 0=normal, 1=high, 2=critical
};

pub const RpcStateHeader = struct {
    magic: u32 = 0x52504353,      // 'RPCS'
    version: u32 = 0x01000000,    // v1.0.0

    cycle_count: u64 = 0,
    timestamp: u64 = 0,

    // Client tracking
    total_clients_registered: u32 = 0,
    active_clients: u32 = 0,
    total_clients_banned: u32 = 0,

    // Session tracking
    total_sessions_created: u64 = 0,
    active_sessions: u32 = 0,
    total_sessions_expired: u64 = 0,

    // RPC statistics
    total_rpc_calls: u64 = 0,
    total_rpc_errors: u64 = 0,
    total_rate_limit_hits: u32 = 0,
    total_authentication_failures: u32 = 0,

    // Traffic statistics
    total_bytes_sent: u64 = 0,
    total_bytes_received: u64 = 0,

    // Reserved
    _reserved: [200]u8 = [_]u8{0} ** 200,
};

pub const RpcStats = struct {
    active_clients: u32 = 0,
    active_sessions: u32 = 0,
    total_rpc_calls: u64 = 0,
    total_errors: u64 = 0,
    total_bytes_sent: u64 = 0,
    total_bytes_received: u64 = 0,
    rate_limit_hits: u32 = 0,
    auth_failures: u32 = 0,
};

pub const RpcClientInfo = struct {
    exists: u8 = 0,
    status: u8 = 0,
    auth_level: u8 = 0,
    total_calls: u64 = 0,
    total_errors: u32 = 0,
    bytes_sent: u64 = 0,
    bytes_received: u64 = 0,
};

pub const RpcStateOS = struct {
    header: RpcStateHeader = RpcStateHeader{},

    clients: [MAX_RPC_CLIENTS]RpcClient = undefined,
    client_count: u32 = 0,

    sessions: [MAX_RPC_SESSIONS]RpcSession = undefined,
    session_count: u32 = 0,

    pending_calls: [MAX_PENDING_CALLS]RpcPendingCall = undefined,
    pending_call_count: u32 = 0,

    // Statistics cache (updated each cycle)
    stats: RpcStats = RpcStats{},

    // Last client info queried
    last_client_info: RpcClientInfo = RpcClientInfo{},
};
