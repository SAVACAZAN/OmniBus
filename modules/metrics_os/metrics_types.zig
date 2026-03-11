// metrics_types.zig — Observability (Phase 59)
// Prometheus metrics + Elasticsearch indexing

pub const METRICS_BASE: usize = 0x5D0000;
pub const MAX_PROVIDERS: usize = 5;       // MS, Oracle, AWS, VMWare, GCP
pub const MAX_BUCKETS: usize = 16;        // Latency histogram buckets

pub const Provider = enum(u8) {
    microsoft = 0,
    oracle = 1,
    aws = 2,
    vmware = 3,
    gcp = 4,
};

pub const LatencyBucket = extern struct {
    le_us: u32,                 // Bucket boundary in microseconds
    count: u32,                 // Events in this bucket
};

pub const ProviderMetrics = extern struct {
    provider_id: u8,
    _pad1: [3]u8,
    timestamp: u64,              // Cycle when last updated
    trades_executed: u32,
    trades_failed: u32,
    orders_created: u32,
    orders_filled: u32,
    latency_p50_us: u32,
    latency_p95_us: u32,
    latency_p99_us: u32,
    availability_pct: u16,       // 0-10000 (0.00-100.00%)
    cpu_usage_pct: u8,
    memory_usage_pct: u8,
    heartbeat_ok: u8,
    _pad2: [7]u8,
};

pub const MetricsOsState = extern struct {
    magic: u32,                  // 'METR'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_cycles_measured: u32,
    total_metrics_published: u32,
    total_elasticsearch_docs: u32,
    last_prometheus_scrape: u64,
    last_elasticsearch_flush: u64,
    agg_trades_executed: u32,
    agg_trades_failed: u32,
    agg_latency_sum_us: u64,
    agg_latency_max_us: u32,
    _pad2: [36]u8,
};
