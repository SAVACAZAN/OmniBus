// report_os_types.zig — Report OS metric types
// Memory layout: 0x300000–0x33FFFF (256KB)

pub const REPORT_BASE: usize = 0x300000;

// Daily metrics snapshot (64 bytes)
pub const DailyMetrics = extern struct {
    timestamp: u64,                 // 0  — Unix timestamp (start of day)
    pnl_cents: i64,                 // 8  — Total PnL in cents
    pnl_bps: i32,                   // 16 — PnL in basis points (%)
    win_rate: u8,                   // 20 — Win rate [0-100]%
    trade_count: u32,               // 21 — Number of trades
    max_profit: i64,                // 25 — Max single trade profit
    max_loss: i64,                  // 33 — Max single trade loss
    sharpe_ratio: f64,              // 41 — Sharpe ratio (return/volatility)
    max_drawdown: f64,              // 49 — Max drawdown in %
    _pad: [7]u8 = [_]u8{0} ** 7,   // 57 — alignment
    // = 64 bytes
};

// Report state header (128 bytes)
pub const ReportState = extern struct {
    magic: u32 = 0x5245504F,        // 0  — "REPO" magic
    flags: u8,                       // 4  — 0x01=valid, 0x02=exporting
    _pad1: [3]u8 = [_]u8{0} ** 3,  // 5  — alignment
    cycle_count: u64,               // 8  — Total cycles executed
    daily_count: u32,               // 16 — Days tracked
    current_day: u32,               // 20 — Current day index

    // Current session metrics
    session_pnl: i64,               // 24 — Session PnL in cents
    session_trades: u32,            // 32 — Trades this session
    session_wins: u32,              // 36 — Winning trades
    session_losses: u32,            // 40 — Losing trades

    // Historical stats
    total_pnl: i64,                 // 44 — Cumulative PnL
    best_day_pnl: i64,              // 52 — Best day PnL
    worst_day_pnl: i64,             // 60 — Worst day PnL
    lifetime_sharpe: f64,           // 68 — Lifetime Sharpe
    lifetime_drawdown: f64,         // 76 — Lifetime max drawdown

    _pad2: [32]u8 = [_]u8{0} ** 32, // 84 — reserved
    // = 128 bytes
};

// Daily metrics array: 365 slots for yearly tracking
pub const DAILY_METRICS_OFFSET: usize = 0x0080;      // After ReportState
pub const DAILY_METRICS_COUNT: usize = 365;
pub const DAILY_METRICS_SIZE: usize = 64;            // Per entry
pub const DAILY_METRICS_TOTAL: usize = DAILY_METRICS_COUNT * DAILY_METRICS_SIZE; // 23KB

// Trade history: up to 10K trades (96 bytes each = ~1MB)
pub const TRADE_HISTORY_OFFSET: usize = 0x6000;      // After daily metrics

pub const Trade = extern struct {
    timestamp: u64,                 // 0  — Unix timestamp
    exchange: u8,                   // 8  — 0=Kraken, 1=Coinbase, 2=LCX
    pair: u8,                       // 9  — 0=BTC, 1=ETH, 2=XRP
    side: u8,                       // 10 — 0=buy, 1=sell
    status: u8,                     // 11 — 0=pending, 1=filled, 2=cancelled

    entry_price: u64,               // 12 — Entry price in cents
    exit_price: u64,                // 20 — Exit price in cents
    quantity_sats: u64,             // 28 — Quantity in satoshis
    pnl: i64,                       // 36 — Trade PnL

    _pad: [60]u8 = [_]u8{0} ** 60, // 44 — alignment/reserved
    // = 96 bytes (align to cache line)
};

pub const MAX_TRADES: usize = 10000;

// Export buffer (for CSV/JSON) - 64KB
pub const EXPORT_BUFFER_OFFSET: usize = 0x6000 + (MAX_TRADES * @sizeOf(Trade));
pub const EXPORT_BUFFER_SIZE: usize = 0x10000; // 64KB

// Summary: 0x300000 - 0x340000 (256KB total)
pub const TOTAL_SIZE: usize = 0x40000;
