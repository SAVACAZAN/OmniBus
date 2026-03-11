// cassandra_types.zig — Multi-DC Event Sourcing (Phase 58B)
// Cassandra ring topology: Microsoft DC + Oracle DC + AWS DC

pub const CASSANDRA_BASE: usize = 0x5C0000;
pub const MAX_NODES: usize = 9;           // 3 DCs × 3 nodes each
pub const MAX_PENDING_WRITES: usize = 256;

pub const DataCenter = enum(u8) {
    microsoft = 0,
    oracle = 1,
    aws = 2,
};

pub const ConsistencyLevel = enum(u8) {
    one = 0,
    quorum = 1,
    all = 2,
};

pub const CassandraNode = extern struct {
    node_id: u8,                   // 0-8
    datacenter: u8,                // DataCenter enum
    token: u64,                    // Ring token (hash of IP:port)
    host: [128]u8,                 // "cassandra-1.ms.omnibus.ai"
    port: u16,                     // 9042
    status: u8,                    // 0=DOWN, 1=UP, 2=STARTING, 3=LEAVING
    last_heartbeat: u64,           // Cycle when last seen
};

pub const WriteIntent = extern struct {
    transaction_id: u64,
    trade_id: u64,
    correlation_id: u64,
    keyspace: [64]u8,              // "omnibus_trades"
    table: [64]u8,                 // "trade_events"
    partition_key: [128]u8,        // JSON: {trade_id: "TRD-001"}
    data: [512]u8,                 // JSON: {event_type, timestamp, ...}
    consistency_level: u8,         // ConsistencyLevel enum
    status: u8,                    // 0=PENDING, 1=REPLICATED, 2=ACKNOWLEDGED, 3=FAILED
    replicas_acked: u8,            // Count of DCs that acked
};

pub const CassandraOsState = extern struct {
    magic: u32,                    // 'CASS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    node_count: u8,
    ring_status: u8,               // 0=INITIALIZING, 1=JOINED, 2=STEADY, 3=RECOVERING
    total_writes_queued: u32,
    total_writes_replicated: u32,
    total_write_failures: u32,
    ms_dc_nodes_up: u8,            // Microsoft DC online nodes (0-3)
    oracle_dc_nodes_up: u8,        // Oracle DC online nodes (0-3)
    aws_dc_nodes_up: u8,           // AWS DC online nodes (0-3)
    last_consistency_check: u64,
    _pad2: [59]u8,
};
