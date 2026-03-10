// parameter_tuning_types.zig — Dynamic trading parameter management
// L15: Real-time parameter tuning for Grid OS and other modules
// Memory: 0x360000–0x36FFFF (64KB)

pub const PARAM_TUNING_BASE: usize = 0x360000;

/// Parameter validation status codes
pub const ParamStatus = enum(u8) {
    Ok = 0x00,
    OutOfRange = 0x01,
    InvalidCombination = 0x02,
    RiskLimitExceeded = 0x03,
    ConflictingParams = 0x04,
};

/// Grid trading parameters
pub const GridParams = extern struct {
    // Grid structure
    grid_step: u32,           // Grid step as basis points (e.g., 100 = 1.00%)
    grid_levels: u8,          // Number of levels above/below midpoint (1-10)
    _pad1: [3]u8 = [_]u8{0} ** 3,
    min_price: u64,           // Minimum price (fixed-point: price * 100000)
    max_price: u64,           // Maximum price (fixed-point: price * 100000)

    // Trading bounds
    min_spread_bps: u32,      // Minimum spread in basis points (10 = 0.1%)
    max_position_size: u32,   // Max position in satoshis/wei
    risk_percent: u8,         // Risk per trade as % of account (1-5%)
    _pad2: [3]u8 = [_]u8{0} ** 3,

    // Order management
    order_timeout_ms: u32,    // Order timeout in milliseconds
    slippage_bps: u16,        // Max slippage in basis points
    _pad3: [2]u8 = [_]u8{0} ** 2,

    // Rebalance
    rebalance_interval_cycles: u32,  // How often to rebalance (in kernel cycles)
    rebalance_threshold_bps: u16,    // Rebalance if drift > this many basis points
    _pad4: [2]u8 = [_]u8{0} ** 2,

    // Active trading flags
    trading_enabled: u8,      // 0x01 = enabled, 0x00 = disabled
    auto_rebalance: u8,       // 0x01 = auto rebalance enabled
    _pad5: [6]u8 = [_]u8{0} ** 6,

    // Validation state
    last_validation_status: u8,
    validation_error_code: u8,
    _pad6: [6]u8 = [_]u8{0} ** 6,
};

/// Parameter tuning state machine (256 bytes @ 0x360000)
pub const ParameterTuningState = extern struct {
    magic: u32 = 0x50414241,              // 0  — "PABA" magic (4 bytes)
    flags: u8,                            // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,        // 5  — alignment
    cycle_count: u64,                     // 8  — Total cycles executed

    // Current parameter set
    grid_params: GridParams,              // 16 — Grid parameters (76 bytes)
    // = 92 bytes so far

    // Previous parameter set (for rollback)
    prev_grid_params: GridParams,         // 92 — Previous grid parameters (76 bytes)
    // = 168 bytes so far

    // Parameter change tracking
    param_change_count: u32,              // 168 — Total parameter changes applied
    last_change_cycle: u64,               // 172 — When last change was applied
    last_change_field: u8,                // 180 — Which field was changed
    _pad2: [3]u8 = [_]u8{0} ** 3,       // 181 — alignment

    // Validation
    pending_update: u8,                   // 184 — 0x01 = pending parameter update
    pending_validation_status: u8,        // 185 — Status of pending params
    _pad3: [2]u8 = [_]u8{0} ** 2,       // 186 — alignment

    // Safety limits
    max_grid_step: u32,                   // 188 — Max allowed grid step (100 = 1%)
    min_grid_step: u32,                   // 192 — Min allowed grid step (5 = 0.05%)
    max_levels: u8,                       // 196 — Max grid levels allowed
    min_levels: u8,                       // 197 — Min grid levels allowed
    _pad4: [2]u8 = [_]u8{0} ** 2,       // 198 — alignment

    // Statistics
    total_updates_applied: u32,           // 200 — Successful updates
    total_updates_rejected: u32,          // 204 — Rejected updates
    last_rejection_reason: u32,           // 208 — Code of last rejection
    escalation_triggered: u8,             // 212 — 0x01 = safety limits exceeded
    _pad5: [3]u8 = [_]u8{0} ** 3,       // 213 — alignment

    _pad6: [40]u8 = [_]u8{0} ** 40,     // 216 — reserved
    // = 256 bytes
};

/// Default safe parameters
pub fn getDefaultGridParams() GridParams {
    return .{
        .grid_step = 50,                  // 0.5% steps
        .grid_levels = 5,                 // 5 levels up/down
        .min_price = 100000 * 100000,     // $100,000
        .max_price = 1000000 * 100000,    // $10,000,000
        .min_spread_bps = 20,             // 0.2% minimum spread
        .max_position_size = 1_000_000_000, // 10 BTC equivalent
        .risk_percent = 1,                // 1% risk per trade
        .order_timeout_ms = 5000,         // 5 second timeout
        .slippage_bps = 50,               // 0.5% max slippage
        .rebalance_interval_cycles = 1024,
        .rebalance_threshold_bps = 100,   // Rebalance if > 1% drift
        .trading_enabled = 1,
        .auto_rebalance = 1,
        .last_validation_status = 0,
        .validation_error_code = 0,
    };
}
