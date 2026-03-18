// stratum_v2_types.zig — Stratum V2 protocol gateway (work distribution, share aggregation)

pub const STRATUM_V2_BASE: usize = 0x5B0000;
pub const MAX_ACTIVE_CONNECTIONS: u32 = 4;
pub const MAX_PENDING_SHARES: u32 = 256;

pub const MessageType = enum(u8) {
    setup_connection = 0x00,
    setup_connection_success = 0x01,
    setup_connection_error = 0x02,

    open_mining_set = 0x10,
    open_mining_set_success = 0x11,
    open_mining_set_error = 0x12,

    mining_subscribe = 0x20,
    mining_subscribe_success = 0x21,
    mining_subscribe_error = 0x22,

    update_channel = 0x30,
    channel_reward_info = 0x31,

    new_mining_job = 0x40,
    submit_shares = 0x50,
    submit_shares_standard = 0x51,
    submit_shares_extended = 0x52,

    shares_accepted = 0x60,
    shares_rejected = 0x61,
};

pub const StratumV2State = extern struct {
    magic: u32 = 0x53563246,    // "SV2F" (Stratum V2)
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    active_connections: u32 = 0,

    // Protocol state
    setup_complete: u8 = 0,
    channel_id: u32 = 0,
    job_id: u32 = 0,

    // Work distribution
    current_difficulty: u32 = 0,
    nonce_min: u64 = 0,
    nonce_max: u64 = 0,

    // Network latency
    last_heartbeat: u64 = 0,
    last_job_received: u64 = 0,
    rtt_us: u32 = 0,                        // Round-trip time in microseconds

    // Share aggregation
    shares_submitted: u64 = 0,
    shares_accepted: u64 = 0,
    shares_rejected: u64 = 0,
    shares_stale: u64 = 0,

    // Statistics
    messages_sent: u32 = 0,
    messages_received: u32 = 0,
    errors_encountered: u32 = 0,

    // Subscription state
    subscription_id: [16]u8 = [_]u8{0} ** 16,
    coinbase_txn: [32]u8 = [_]u8{0} ** 32,

    _pad2: [32]u8 = [_]u8{0} ** 32,
};

pub const MiningJob = extern struct {
    job_id: u32 = 0,
    channel_id: u32 = 0,

    coinbase_tx_version: [4]u8 = [_]u8{0} ** 4,
    coinbase_tx_input_count: u8 = 0,
    coinbase_tx_input_sequence: [4]u8 = [_]u8{0} ** 4,
    coinbase_tx_output_count: u8 = 0,
    coinbase_tx_locktime: [4]u8 = [_]u8{0} ** 4,

    merkle_root: [32]u8 = [_]u8{0} ** 32,
    block_header_version: [4]u8 = [_]u8{0} ** 4,
    block_header_timestamp: [4]u8 = [_]u8{0} ** 4,
    block_header_bits: [4]u8 = [_]u8{0} ** 4,

    nonce_start: u64 = 0,
    nonce_end: u64 = 0,
    difficulty: u32 = 0,

    is_future_job: u8 = 0,
    job_validity_start: u64 = 0,           // Timestamp when job becomes valid

    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const MiningShare = extern struct {
    share_id: u64 = 0,
    job_id: u32 = 0,
    channel_id: u32 = 0,

    nonce: u64 = 0,
    nonce_2: u32 = 0,                     // Additional nonce for extended shares

    block_header: [80]u8 = [_]u8{0} ** 80,  // Complete block header
    coinbase_tx: [256]u8 = [_]u8{0} ** 256,

    timestamp_submitted: u64 = 0,
    is_accepted: u8 = 0,
    rejection_reason: u8 = 0,

    _pad: [16]u8 = [_]u8{0} ** 16,
};

pub const ConnectionState = extern struct {
    connection_id: u32 = 0,
    pool_address: [32]u8 = [_]u8{0} ** 32,  // ASCII IP:port
    pool_port: u16 = 0,

    connected: u8 = 0,
    authenticated: u8 = 0,
    mining_subscribed: u8 = 0,

    username_hash: u64 = 0,
    worker_name_hash: u64 = 0,

    last_received_cycle: u64 = 0,
    timeout_cycles: u32 = 1000,             // Timeout after 1000 cycles (~100ms)

    messages_sent: u32 = 0,
    messages_received: u32 = 0,

    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const STRATUM_V2_STATE_BASE: usize = STRATUM_V2_BASE;
pub const STRATUM_V2_JOBS_BASE: usize = STRATUM_V2_BASE + 0x100;
pub const STRATUM_V2_SHARES_BASE: usize = STRATUM_V2_BASE + 0x800;
pub const STRATUM_V2_CONNS_BASE: usize = STRATUM_V2_BASE + 0x2000;
