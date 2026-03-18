// types.zig — All bare-metal types for Analytics OS
// Fixed-point throughout: prices × 100 (cents), sizes × 1e8 (satoshis)

pub const ANALYTICS_BASE: usize = 0x150000;
pub const DMA_RING_BASE: usize = 0x152000;
pub const WORKING_BASE: usize = 0x15A000;
pub const MATRIX_BASE: usize = 0x169000;
pub const KERNEL_AUTH: usize = 0x100050;

pub const PairId = enum(u16) {
    BTC_USD = 0,
    ETH_USD = 1,
    XRP_USD = 2,
    unknown = 0xFFFF,
};

pub const SourceId = enum(u8) {
    kraken = 0,
    coinbase = 1,
    lcx = 2,
    unknown = 0xFF,
};

pub const MsgType = enum(u8) {
    trade = 0,
    ticker = 1,
    orderbook_snap = 2,
    orderbook_delta = 3,
};

pub const Side = enum(u8) {
    buy = 0,
    sell = 1,
    na = 0xFF,
};

// Core market data type: price in cents, size in satoshis
// All fields fixed-point: no floating point in bare metal
pub const Tick = extern struct {
    source_id: SourceId, // 2B
    pair_id: u16, // 2B
    msg_type: MsgType, // 1B
    side: Side, // 1B
    _pad: u16 = 0, // 2B alignment
    price_cents: u64, // 8B — price × 100
    size_sats: u64, // 8B — size × 1e8
    tsc: u64, // 8B — TSC cycle count
    bid_cents: u64, // 8B — best bid (ticker messages only)
    ask_cents: u64, // 8B — best ask (ticker messages only)
    // = 48 bytes total (fits in cache line)
};

// Output slot written by Analytics OS, read by Grid OS at 0x150000
pub const PriceFeedSlot = extern struct {
    pair_id: u16, // 0
    exchange_count: u8, // 2
    flags: u8, // 3 — 0x01=valid, 0x02=stale
    _pad0: u32 = 0, // 4
    consensus_price: u64, // 8 — price × 100
    consensus_volume: u64, // 16
    bid_price: u64, // 24
    ask_price: u64, // 32
    last_update_tsc: u64, // 40
    high_24h: u64, // 48
    low_24h: u64, // 56
    vwap: u64, // 64
    _reserved: [60]u8 = [_]u8{0} ** 60, // 72
    // = 128 bytes total
};

// Input slot from DMA ring (written by C NIC driver, read by Analytics OS)
pub const DmaRingSlot = extern struct {
    source_id: u16, // 0 — exchange ID
    pair_id: u16, // 2
    msg_type: u8, // 4
    side: u8, // 5
    _pad0: u16 = 0, // 6
    price: u64, // 8 — fixed-point × 100
    size: u64, // 16 — fixed-point × 1e8
    tsc: u64, // 24
    _reserved: [96]u8 = [_]u8{0} ** 96, // 32
    // = 128 bytes total
};

// Market matrix cell: OHLCV for a price level in a time bucket
pub const MatrixCell = extern struct {
    open: u64,
    high: u64,
    low: u64,
    close: u64,
    volume: u64,
    // = 40 bytes total
};

// Consensus window: 10-slot sorted buffer for 71% median
pub const ConsensusWindow = extern struct {
    prices: [10]u64, // Sorted ascending, fixed-point
    sources: [10]u8, // Source exchange ID for each slot
    count: u8, // Number of active slots (0–10)
    _pad: [7]u8 = [_]u8{0} ** 7,
    // = 128 bytes total (cache line aligned)
};

// Result from consensus.compute() — validated or stale
pub const ConsensusResult = struct {
    valid: bool,
    price: u64,
};

// DMA ring buffer head/tail at 0x152000
pub const DmaRingHeader = extern struct {
    head: u32 = 0, // Advanced by Analytics OS
    tail: u32 = 0, // Advanced by NIC driver
    _pad: [8]u8 = [_]u8{0} ** 8,
};

// Market matrix array: 3 pairs × 32 levels × 30 time bins
pub const MarketMatrix = extern struct {
    cells: [3][32][30]MatrixCell,
};

// ============================================================================
// ORDERBOOK TYPES (for MEV protection and spread analysis)
// ============================================================================

pub const OrderbookLevel = extern struct {
    price_cents: u64,    // Price × 100
    size_sats: u64,      // Size × 1e8
};

pub const OrderbookSlice = extern struct {
    exchange_id: u8,      // Source: Kraken=0, Coinbase=1, LCX=2
    pair_id: u16,         // BTC_USD=0, ETH_USD=1, etc.
    bid_count: u8,        // Number of active bids (0-20)
    ask_count: u8,        // Number of active asks (0-20)
    best_bid: u64,        // Top bid price (cents) or 0
    best_ask: u64,        // Top ask price (cents) or 0
    spread_bps: u16,      // Spread in basis points (1/10000)
    update_tsc: u64,      // TSC when orderbook was updated
    bids: [20]OrderbookLevel,  // Top 20 bids
    asks: [20]OrderbookLevel,  // Top 20 asks
};

// Orderbook state for 3 pairs × 3 exchanges
pub const OrderbookState = extern struct {
    slices: [3][3]OrderbookSlice,  // 3 pairs × 3 exchanges
    cycle_count: u64,               // Total cycles processed
    updates_received: u32,          // Total orderbook updates
    stale_count: u32,               // Updates older than 5 seconds
};

pub const ORDERBOOK_BASE: usize = WORKING_BASE + 0x100;  // Offset in Analytics memory
