// cloud_types.zig — Multi-Cloud Provider Integration (Phase 61)
// Microsoft Azure, Oracle Cloud, AWS, VMWare, Google Cloud Platform

pub const MICROSOFT_OS_BASE: usize = 0x5F0000;
pub const ORACLE_OS_BASE: usize = 0x600000;
pub const AWS_OS_BASE: usize = 0x610000;
pub const VMWARE_OS_BASE: usize = 0x620000;
pub const GCP_OS_BASE: usize = 0x630000;

pub const MAX_PROVIDER_INSTANCES: usize = 128;   // 100+ instances per provider
pub const MAX_PROVIDER_REGIONS: usize = 16;       // Multi-region deployment

pub const CloudProvider = enum(u8) {
    microsoft_azure = 0,
    oracle_cloud = 1,
    amazon_aws = 2,
    vmware_cloud = 3,
    google_cloud = 4,
};

pub const InstanceStatus = enum(u8) {
    offline = 0,
    online = 1,
    degraded = 2,
    maintenance = 3,
};

pub const ProviderRegion = extern struct {
    region_id: u8,
    region_code: u8,                   // US_EAST=0, US_WEST=1, EU=2, ASIA=3, etc.
    instance_count: u8,                // Active instances in this region
    available_capacity: u32,           // Available compute capacity (vCPU × 1000)
    latency_us: u32,                   // Round-trip latency to this region
    active_trades: u32,                // Trades executing in this region
};

pub const CloudInstance = extern struct {
    instance_id: u64,
    provider: u8,                      // CloudProvider enum
    region_id: u8,
    _pad1: [2]u8,
    status: u8,                        // InstanceStatus enum
    _pad2: [3]u8,
    last_heartbeat: u64,
    assigned_trades: u32,              // Number of trades assigned to this instance
    cpu_usage_pct: u8,
    memory_usage_pct: u8,
    network_latency_us: u32,
    total_trades_processed: u64,
};

pub const ProviderState = extern struct {
    magic: u32,                        // Provider-specific magic
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    provider: u8,                      // CloudProvider enum
    _pad2: [7]u8,
    total_instances: u8,
    online_instances: u8,
    total_regions: u8,
    active_regions: u8,
    total_heartbeats_received: u32,
    total_heartbeats_missed: u32,
    total_trades_assigned: u32,
    total_capacity_mhz: u32,
    load_balancing_mode: u8,           // 0=round-robin, 1=latency-aware, 2=capacity-aware
    rebalance_required: u8,
    _pad3: [6]u8,
};

// Per-provider state structures (48 bytes each, fits in 64KB segment)
pub const MicrosoftOsState = extern struct {
    magic: u32,                        // 0x4D534F53 'MSOS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_instances: u8,
    online_instances: u8,
    active_subscriptions: u8,
    _pad2: [1]u8,
    total_trades_assigned: u32,
    azure_api_calls: u32,
    last_error: u32,
    _pad3: [20]u8,
};

pub const OracleOsState = extern struct {
    magic: u32,                        // 0x4F524153 'ORAS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_instances: u8,
    online_instances: u8,
    active_compartments: u8,
    _pad2: [1]u8,
    total_trades_assigned: u32,
    oci_api_calls: u32,
    last_error: u32,
    _pad3: [20]u8,
};

pub const AwsOsState = extern struct {
    magic: u32,                        // 0x41574F53 'AWOS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_instances: u8,
    online_instances: u8,
    active_regions: u8,
    _pad2: [1]u8,
    total_trades_assigned: u32,
    aws_api_calls: u32,
    last_error: u32,
    _pad3: [20]u8,
};

pub const VmwareOsState = extern struct {
    magic: u32,                        // 0x564D4F53 'VMOS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_instances: u8,
    online_instances: u8,
    active_clusters: u8,
    _pad2: [1]u8,
    total_trades_assigned: u32,
    vsphere_api_calls: u32,
    last_error: u32,
    _pad3: [20]u8,
};

pub const GcpOsState = extern struct {
    magic: u32,                        // 0x4743504F 'GCPO'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_instances: u8,
    online_instances: u8,
    active_projects: u8,
    _pad2: [1]u8,
    total_trades_assigned: u32,
    gcp_api_calls: u32,
    last_error: u32,
    _pad3: [20]u8,
};
