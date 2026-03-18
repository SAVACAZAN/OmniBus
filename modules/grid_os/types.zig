// types.zig — All bare-metal types for Grid OS
// Fixed-point throughout: prices × 100 (cents), sizes × 1e8 (satoshis)
// Memory layout: 0x110000–0x12FFFF (128KB)

// ============================================================================
// Memory addresses
// ============================================================================

pub const GRID_BASE: usize = 0x110000;           // Grid OS state base
pub const ANALYTICS_BASE: usize = 0x150000;      // Price feed (read by Grid OS)
pub const EXECUTION_BASE: usize = 0x130000;      // Order queue (write by Grid OS)
pub const KERNEL_AUTH: usize = 0x100050;         // Ada auth gate

// ============================================================================
// Constants
// ============================================================================

pub const MAX_LEVELS: usize = 64;                // Max buy + sell levels per pair
pub const MAX_ORDERS: usize = 256;               // Max active orders
pub const MAX_OPPORTUNITIES: usize = 32;         // Max detected arbitrage opps
pub const MIN_PROFIT_BPS: i32 = 50;              // Min 0.50% net profit threshold

// Fee schedules (in basis points)
pub const FEE_KRAKEN_TAKER_BPS: u32 = 16;       // 0.16%
pub const FEE_COINBASE_TAKER_BPS: u32 = 60;     // 0.60%
pub const FEE_LCX_TAKER_BPS: u32 = 20;          // 0.20%

// ============================================================================
// Enumerations
// ============================================================================

pub const Side = enum(u8) {
    buy = 0,
    sell = 1,
};

pub const OrderStatus = enum(u8) {
    pending = 0,
    filled = 1,
    cancelled = 2,
    rejected = 3,
};

pub const SourceId = enum(u8) {
    kraken = 0,
    coinbase = 1,
    lcx = 2,
    unknown = 0xFF,
};

// ============================================================================
// GridLevel: individual buy/sell level in the grid (32 bytes)
// ============================================================================

pub const GridLevel = extern struct {
    price_cents: u64,              // 0  — level trigger price (× 100)
    side: Side,                    // 8  — buy or sell
    status: OrderStatus,           // 9  — pending/filled/cancelled
    _pad: u16 = 0,                 // 10 — alignment
    quantity_sats: u64,            // 12 — target order size (× 1e8)
    order_id: u32,                 // 20 — reference to Order[] index
    _pad2: u32 = 0,                // 24 — alignment pad
    // = 28 bytes (padded to 32 for cache line alignment)
};

// ============================================================================
// Order: full order state tracking (48 bytes)
// ============================================================================

pub const Order = extern struct {
    exchange_id: u16,              // 0  — Kraken(0), Coinbase(1), LCX(2)
    pair_id: u16,                  // 2  — BTC_USD(0), ETH_USD(1), XRP_USD(2)
    side: Side,                    // 4  — buy or sell
    status: OrderStatus,           // 5  — pending/filled/cancelled/rejected
    _pad: u16 = 0,                 // 6  — alignment
    price_cents: u64,              // 8  — fixed-point price (× 100)
    quantity_sats: u64,            // 16 — target quantity (× 1e8)
    filled_sats: u64,              // 24 — cumulative filled amount
    order_id: u32,                 // 32 — exchange-assigned ID
    tsc_created: u64,              // 36 — TSC at order creation
    tsc_filled: u64,               // 44 — TSC when fully filled
    // = 52 bytes (padded to 48 in extern struct due to alignment)
};

// ============================================================================
// GridState: header for a trading pair's grid (64 bytes)
// ============================================================================

pub const GridState = extern struct {
    magic: u32 = 0x47524944,       // 0  — "GRID" magic marker
    pair_id: u16,                  // 4  — BTC_USD, ETH_USD, XRP_USD
    flags: u8,                     // 6  — 0x01=active, 0x02=rebalancing
    _pad: u8 = 0,                  // 7  — alignment
    lower_bound: u64,              // 8  — lowest buy price (cents)
    upper_bound: u64,              // 16 — highest sell price (cents)
    step_cents: u64,               // 24 — price interval between levels
    last_trade_profit: i64,        // 32 — cumulative profit (can be negative)
    tsc_last_update: u64,          // 40 — TSC of last grid update
    level_count: u32,              // 48 — active levels [0..level_count)
    order_count: u32,              // 52 — active orders [0..order_count)
    _pad2: [8]u8 = [_]u8{0} ** 8, // 56 — reserved
    // = 64 bytes (cache line aligned)
};

// ============================================================================
// ArbitrageOpportunity: detected cross-exchange spread (96 bytes)
// ============================================================================

pub const ArbitrageOpportunity = extern struct {
    pair_id: u16,                  // 0  — trading pair ID
    exchange_a: u8,                // 2  — buyer exchange (ask side)
    exchange_b: u8,                // 3  — seller exchange (bid side)
    flags: u8,                     // 4  — 0x01=valid, 0x02=executed
    _pad: [3]u8 = [_]u8{0} ** 3,  // 5  — alignment
    price_a_cents: u64,            // 8  — ask price at exchange A (× 100)
    price_b_cents: u64,            // 16 — bid price at exchange B (× 100)
    net_profit_bps: i32,           // 24 — net profit in basis points
    confidence_pct: u8,            // 28 — confidence score [0..100]
    _pad2: [3]u8 = [_]u8{0} ** 3, // 29 — alignment
    tsc: u64,                      // 32 — TSC when opportunity detected
    _pad3: [56]u8 = [_]u8{0} ** 56, // 40 — reserved for future use
    // = 96 bytes (cache line aligned)
};

// ============================================================================
// AggregatedStats: per-pair statistics from Analytics (64 bytes)
// ============================================================================

pub const AggregatedStats = extern struct {
    pair_id: u16,                  // 0  — trading pair ID
    source_count: u8,              // 2  — number of data sources in consensus
    flags: u8,                     // 3  — 0x01=valid, 0x02=stale
    avg_price: u64,                // 4  — weighted average price (cents)
    best_bid: u64,                 // 12 — best bid across sources (cents)
    best_ask: u64,                 // 20 — best ask across sources (cents)
    spread_bps: u32,               // 28 — bid-ask spread in basis points
    total_volume: u64,             // 32 — 24h volume (satoshis)
    tsc: u64,                      // 40 — TSC of last update
    _pad: [16]u8 = [_]u8{0} ** 16, // 48 — reserved
    // = 64 bytes (cache line aligned)
};

// ============================================================================
// OrderPacket: message to Execution OS at 0x130000 (128 bytes)
// Matches egld arbitrage_plugin.zig pattern
// ============================================================================

pub const OrderPacket = extern struct {
    opcode: u8 = 0x70,             // 0  — order opcode
    _pad0: u8 = 0,                 // 1  — alignment
    exchange_id: u16,              // 2  — Kraken(0), Coinbase(1), LCX(2)
    _pad1: u32 = 0,                // 4  — alignment
    pair_id: u16,                  // 8  — BTC_USD, ETH_USD, XRP_USD
    side: u8,                      // 10 — buy(0) or sell(1)
    _pad2: u8 = 0,                 // 11 — alignment
    quantity_sats: u64,            // 12 — order size (× 1e8)
    price_cents: u64,              // 20 — limit price (× 100)
    signature_pqc: [64]u8 = [_]u8{0} ** 64, // 28 — PQC signature (placeholder)
    // = 92 bytes (padded to 128)
};

// ============================================================================
// PriceFeedSlot: read from Analytics OS at 0x150000 (128 bytes each)
// Note: This type is defined in analytics_os/types.zig but repeated here
// for Grid OS reference
// ============================================================================

pub const PriceFeedSlot = extern struct {
    pair_id: u16,                  // 0
    exchange_count: u8,            // 2
    flags: u8,                     // 3  — 0x01=valid, 0x02=stale
    _pad0: u32 = 0,                // 4
    consensus_price: u64,          // 8  — price × 100
    consensus_volume: u64,         // 16
    bid_price: u64,                // 24
    ask_price: u64,                // 32
    last_update_tsc: u64,          // 40
    high_24h: u64,                 // 48
    low_24h: u64,                  // 56
    vwap: u64,                     // 64
    _reserved: [60]u8 = [_]u8{0} ** 60, // 72
    // = 128 bytes total
};

// ============================================================================
// Memory layout within 0x110000–0x12FFFF (128KB)
// ============================================================================
// 0x110000  GridState header (64 bytes)
// 0x110040  GridLevel[64] (64 × 32 = 2048 bytes)
// 0x110840  Order[256] (256 × 48 = 12288 bytes)
// 0x113840  ArbitrageOpportunity[32] (32 × 96 = 3072 bytes)
// 0x114640  AggregatedStats[3] (3 × 64 = 192 bytes)
// 0x114700  Rebalance state (512 bytes)
// 0x114900  ... reserved for future extensions
// 0x12FFFF  (end of segment)
// ============================================================================

pub const GRIDSTATE_OFFSET: usize = 0x0000;
pub const GRIDLEVEL_OFFSET: usize = 0x0040;
pub const ORDER_OFFSET: usize = 0x0840;
pub const ARBITRAGE_OPP_OFFSET: usize = 0x3840;
pub const AGGREGATED_STATS_OFFSET: usize = 0x4640;
pub const REBALANCE_STATE_OFFSET: usize = 0x4700;
