// multi_node_federation_types.zig — Multi-Node Federation Coordination
// Phase 52: Cluster heartbeat, quorum detection, split-brain prevention

pub const MNF_BASE: usize = 0x4F0000;
pub const MAX_NODES: usize = 8;
pub const HEARTBEAT_TIMEOUT: u64 = 65536;

pub const NodeStatus = enum(u8) {
    offline = 0,
    active = 1,
    degraded = 2,
};

pub const NodeDescriptor = extern struct {
    node_id: u8 = 0,
    status: u8 = 0,
    ip_packed: u32 = 0,
    port: u16 = 0,
    _pad1: u16 = 0,
    last_seen_cycle: u64 = 0,
    messages_sent: u32 = 0,
    messages_recv: u32 = 0,
    _pad2: [6]u8 = [_]u8{0} ** 6,
};

pub const CloudProvider = enum(u8) {
    aws = 0,
    azure = 1,
    gcp = 2,
    oracle = 3,
    onprem = 4,
};

pub const CloudNodeDescriptor = extern struct {
    node_id: u32 = 0,
    region_hash: u64 = 0,           // FNV hash of region name (e.g. "us-east-1")
    provider: u8 = 0,               // CloudProvider enum
    is_primary: u8 = 0,             // 1 if primary region
    latency_cycles: u64 = 0,        // Measured round-trip TSC delta
    last_heartbeat: u64 = 0,        // TSC timestamp
    _pad: [6]u8 = [_]u8{0} ** 6,
};

pub const MNFState = extern struct {
    magic: u32 = 0x4D4E4644,
    flags: u8 = 0x01,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64 = 0,
    node_count: u8 = 0,
    active_nodes: u8 = 0,
    this_node_id: u8 = 1,
    _pad2: u8 = 0,
    heartbeat_interval: u32 = 32768,
    total_messages: u32 = 0,
    total_heartbeats: u32 = 0,
    split_brain_detected: u8 = 0,
    _pad3: [3]u8 = [_]u8{0} ** 3,
    last_quorum_cycle: u64 = 0,

    // Cloud federation state
    cloud_node_count: u8 = 0,
    geo_redundancy_enabled: u8 = 0,
    _pad4: [2]u8 = [_]u8{0} ** 2,
    primary_region_hash: u64 = 0,
    failover_region_hash: u64 = 0,
    _pad5: [32]u8 = [_]u8{0} ** 32,
};

pub const CLOUD_NODES_BASE: usize = MNF_BASE + 0x200;
pub const MAX_CLOUD_NODES: usize = 8;
