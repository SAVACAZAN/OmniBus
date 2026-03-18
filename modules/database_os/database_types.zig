// database_types.zig — Distributed Database (Phase 58)
// Cassandra adapter for trade journal persistence

pub const DB_BASE: usize = 0x5B0000;
pub const MAX_TRADES: usize = 512;
pub const REPLICATION_FACTOR: u8 = 3;

pub const TradeStatus = enum(u8) {
    pending = 0,
    executed = 1,
    failed = 2,
    compensated = 3,
};

pub const TradeRecord = extern struct {
    trade_id: u64,
    timestamp: u64,
    symbol: [8]u8,
    quantity: u64,
    price: i64,
    status: u8,                        // TradeStatus enum
    provider_mask: u8,                 // Bitmask: bit0=MS, bit1=Oracle, bit2=AWS, bit3=VMWare, bit4=GCP
    consensus_reached: u8,             // 1 = quorum agreement
    _pad: u8,
    correlation_id: u64,               // Link to LoggingOS
};

pub const DatabaseOsState = extern struct {
    magic: u32,                        // 'DBTS'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_trades_persisted: u32,
    total_trades_failed: u32,
    total_replication_sends: u32,
    total_replication_acks: u32,
    primary_dc: u8,                    // 0=MS, 1=Oracle, 2=AWS
    secondary_dc1: u8,
    secondary_dc2: u8,
    consistency_level: u8,             // 0=ONE, 1=QUORUM, 2=ALL
    last_persisted_trade_id: u64,
    _pad2: [58]u8,
};
