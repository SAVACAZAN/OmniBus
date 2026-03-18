// cloud_federation_types.zig — Multi-Cloud Provider Integration (Phase 61)
// AWS/Azure/GCP/Oracle/VMware geographic redundancy + failover

pub const CLOUD_FEDERATION_BASE: usize = 0x5D0000;
pub const MAX_CLOUD_REGIONS: u32 = 16;
pub const MAX_AVAILABILITY_ZONES: u32 = 64;
pub const MAX_NODES_PER_REGION: u32 = 32;

pub const CloudProvider = enum(u8) {
    aws = 0,                         // Amazon Web Services
    azure = 1,                       // Microsoft Azure
    gcp = 2,                         // Google Cloud Platform
    oracle = 3,                      // Oracle Cloud Infrastructure
    vmware = 4,                      // VMware vCloud
    digitalocean = 5,                // DigitalOcean
    linode = 6,                      // Linode/Akamai
};

pub const RegionCode = enum(u8) {
    us_east = 0x01,                  // US East (N. Virginia)
    us_west = 0x02,                  // US West (Oregon)
    eu_west = 0x03,                  // EU West (Ireland)
    eu_central = 0x04,               // EU Central (Frankfurt)
    ap_northeast = 0x05,             // Asia Pacific (Tokyo)
    ap_southeast = 0x06,             // Asia Pacific (Singapore)
    ap_south = 0x07,                 // Asia Pacific (Mumbai)
    sa_east = 0x08,                  // South America (São Paulo)
    ca_central = 0x09,               // Canada (Central)
    me_south = 0x0A,                 // Middle East (Bahrain)
};

pub const NodeStatus = enum(u8) {
    initializing = 0,
    healthy = 1,
    degraded = 2,                    // High latency or packet loss
    unhealthy = 3,                   // Consensus divergence
    offline = 4,                     // Unreachable
};

pub const ConsensusRole = enum(u8) {
    follower = 0,
    candidate = 1,
    leader = 2,
    observer = 3,                    // Non-voting backup
};

pub const CloudNode = extern struct {
    node_id: u32 = 0,
    provider: u8 = @intFromEnum(CloudProvider.aws),
    region: u8 = @intFromEnum(RegionCode.us_east),
    availability_zone: u8 = 0,       // 0-7 per region

    hostname: [32]u8 = [_]u8{0} ** 32,  // DNS name
    ipv4_addr: [4]u8 = [_]u8{0} ** 4,
    ipv6_addr: [16]u8 = [_]u8{0} ** 16,

    port: u16 = 8000,
    status: u8 = @intFromEnum(NodeStatus.initializing),
    consensus_role: u8 = @intFromEnum(ConsensusRole.follower),

    // Health metrics
    latency_ms: u16 = 0,
    packet_loss_ppm: u32 = 0,        // Parts per million
    last_heartbeat: u64 = 0,
    consecutive_failures: u16 = 0,

    // Consensus metrics
    term: u64 = 0,                   // Raft term
    log_index: u64 = 0,              // Last applied log index
    voted_for: u32 = 0xFFFFFFFF,     // Voted for node_id

    blocks_synced: u64 = 0,
    sync_progress_ppm: u32 = 0,      // Synchronization progress (0-1000000)

    _pad: [16]u8 = [_]u8{0} ** 16,
};

pub const CloudRegion = extern struct {
    region_id: u32 = 0,
    provider: u8 = 0,
    region_code: u8 = 0,
    is_primary: u8 = 0,              // Primary region for failover
    is_active: u8 = 0,

    node_count: u8 = 0,
    healthy_nodes: u8 = 0,
    leader_node_id: u32 = 0xFFFFFFFF,

    avg_latency_ms: u16 = 0,
    consensus_state_hash: [32]u8 = [_]u8{0} ** 32,
    last_block_hash: [32]u8 = [_]u8{0} ** 32,
    last_block_number: u64 = 0,

    total_stake: u64 = 0,            // Combined stake of validators
    voting_power: u32 = 0,           // Weighted voting power

    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const GeographicRedundancy = extern struct {
    provider_count: u8 = 0,          // 1-5 providers active
    region_count: u8 = 0,            // 1-16 regions active
    min_providers_required: u8 = 3,  // Minimum for consensus (Byzantine)

    providers_active: u8 = 0,        // Bitmask: bit N = provider N active
    providers_healthy: u8 = 0,       // Bitmask: bit N = provider N healthy

    primary_region_id: u32 = 0,
    secondary_region_id: u32 = 0,
    failover_region_id: u32 = 0,

    cross_region_latency_ms: u16 = 0,
    max_region_divergence_ms: u16 = 0,  // Max time before failover

    last_failover_cycle: u64 = 0,
    failover_count: u32 = 0,

    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const CloudFederationState = extern struct {
    magic: u32 = 0x434C4F55,        // "CLOU" (Cloud)
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    region_count: u32 = 0,
    active_regions: u32 = 0,
    node_count: u32 = 0,
    healthy_nodes: u32 = 0,

    // Consensus state
    current_term: u64 = 0,
    leader_id: u32 = 0xFFFFFFFF,
    voted_for: u32 = 0xFFFFFFFF,
    commit_index: u64 = 0,

    // Federation state
    federation_status: u8 = 0,       // 0=forming, 1=established, 2=degraded, 3=recovering
    consensus_health: u8 = 0,        // 0-100 percentage
    network_health: u8 = 0,          // 0-100 percentage

    // Monitoring
    blocks_replicated: u64 = 0,
    failovers_triggered: u32 = 0,
    nodes_recovered: u32 = 0,
    consensus_divergences: u32 = 0,

    // Geographic redundancy
    geo_redundancy: GeographicRedundancy = .{},

    _pad2: [64]u8 = [_]u8{0} ** 64,
};

pub const CLOUD_STATE_BASE: usize = CLOUD_FEDERATION_BASE;
pub const CLOUD_REGIONS_BASE: usize = CLOUD_FEDERATION_BASE + 0x200;
pub const CLOUD_NODES_BASE: usize = CLOUD_FEDERATION_BASE + 0x2000;
pub const CLOUD_DATA_BASE: usize = CLOUD_FEDERATION_BASE + 0x8000;
