// Phase 66: Network Types – Shared data structures for all network modules
// ===========================================================================

pub const NetworkConstants = struct {
    pub const MAGIC_NUMBER: u32 = 0x4F4D4E49; // "OMNI"
    pub const PROTOCOL_VERSION: u16 = 0x0001;
    pub const MAX_PACKET_SIZE: usize = 1472; // MTU-safe
    pub const MAX_PEERS: u32 = 1000;
    pub const DEDUP_WINDOW_SIZE: u32 = 1024;
    pub const GOSSIP_FACTOR: u8 = 3;
    pub const PACKET_TTL_SECONDS: u32 = 60;
    pub const MAX_PAYLOAD_COUNT: u8 = 32;
    pub const SEED_NODE_COUNT: u8 = 5;
};

pub const PacketType = enum(u8) {
    TRANSACTION = 0x00,
    STAKING = 0x01,
    ORACLE_VOTE = 0x02,
    BLOCK_PROPOSAL = 0x03,
    BLOCK_COMMIT = 0x04,
    PRICE_SNAPSHOT = 0x05,
    VALIDATOR_HEARTBEAT = 0x06,
    ADDRESS_REGISTRATION = 0x07,
    CONFLICT_REPORT = 0x08,
    SLASHING_EVIDENCE = 0x09,
    MERKLE_PROOF = 0x0A,
};

pub const ReputationUpdate = enum(i8) {
    VALID_PACKET = 1,
    RELAY_SUCCESS = 1,
    INVALID_CHECKSUM = -10,
    DUPLICATE_PACKET = -5,
    TIMEOUT = -2,
    BAD_SIGNATURE = -20,
};

pub const PeerStatus = enum(u8) {
    UNKNOWN = 0,
    CONNECTING = 1,
    CONNECTED = 2,
    FAILED = 3,
    BANNED = 4,
};

pub const IPVersion = enum(u8) {
    IPv4 = 4,
    IPv6 = 6,
};

pub const NetworkMetrics = struct {
    packets_sent: u64,
    packets_received: u64,
    bytes_sent: u64,
    bytes_received: u64,
    peers_connected: u32,
    avg_latency_ms: u32,
    uptime_seconds: u64,
};

pub const BootstrapConfig = struct {
    seeds: [5][6]u8, // 5 seed nodes (IP:port pairs)
    seed_count: u8,
    timeout_ms: u32 = 5000,
    max_retries: u8 = 3,
};

pub const ValidationError = enum(u8) {
    NONE = 0,
    INVALID_MAGIC = 1,
    INVALID_VERSION = 2,
    BAD_CHECKSUM = 3,
    DUPLICATE_SEQ = 4,
    EXPIRED = 5,
    INVALID_PAYLOAD_COUNT = 6,
    BAD_SIGNATURE = 7,
    CORRUPT = 8,
};
