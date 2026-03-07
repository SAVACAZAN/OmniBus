// market_matrix.zig — 32×30 compact OHLCV grid
// 3 pairs × 32 price levels × 30 time bins (1-second each)

const types = @import("types.zig");

// TSC cycles per second (3 GHz estimate)
const TSC_PER_SECOND: u64 = 3_000_000_000;

// Price range and step size per pair (hardcoded, can be made configurable)
const PairRange = struct {
    min_price: u64, // In cents
    max_price: u64,
    step_cents: u64,
};

// Price ranges for BTC, ETH, XRP
const PAIR_RANGES = [_]PairRange{
    // BTC: $10k–$80k, $1,562.50 per level
    .{ .min_price = 1_000_000, .max_price = 8_000_000, .step_cents = 156_250 },
    // ETH: $1k–$5k, $125 per level
    .{ .min_price = 100_000, .max_price = 500_000, .step_cents = 12_500 },
    // XRP: $0.50–$2.50, $0.0625 per level
    .{ .min_price = 50, .max_price = 250, .step_cents = 6_25 },
};

// Matrix state
var matrix: types.MarketMatrix = undefined;
var init_tsc: u64 = 0;
var current_bucket: u32 = 0;

// Initialize matrix to zeros
pub fn init() void {
    // Zero-fill entire matrix
    var pair: usize = 0;
    while (pair < 3) : (pair += 1) {
        var level: usize = 0;
        while (level < 32) : (level += 1) {
            var bucket: usize = 0;
            while (bucket < 30) : (bucket += 1) {
                matrix.cells[pair][level][bucket] = .{
                    .open = 0,
                    .high = 0,
                    .low = 0,
                    .close = 0,
                    .volume = 0,
                };
            }
        }
    }
    init_tsc = getTsc();
    current_bucket = 0;
}

// Get current TSC
fn getTsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// Map price to level index (0–31) with clamping
fn getPriceLevel(pair_id: u16, price_cents: u64) u32 {
    if (pair_id >= 3) return 0;

    const range = PAIR_RANGES[pair_id];
    if (price_cents < range.min_price) return 0;
    if (price_cents > range.max_price) return 31;

    const offset = price_cents - range.min_price;
    const level = offset / range.step_cents;

    if (level > 31) return 31;
    return @as(u32, @intCast(level));
}

// Get current time bucket (0–29) based on elapsed TSC
fn getTimeBucket() u32 {
    const elapsed = getTsc() - init_tsc;
    const bucket_tsc = elapsed / TSC_PER_SECOND;
    return @as(u32, @intCast(bucket_tsc % 30));
}

// Update matrix with a new tick
pub fn update(tick: types.Tick) void {
    if (tick.pair_id >= 3) return;

    const pair = tick.pair_id;
    const level = getPriceLevel(pair, tick.price_cents);
    const bucket = getTimeBucket();

    // Advance bucket if needed
    if (bucket != current_bucket) {
        // Zero-fill the new bucket
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            matrix.cells[pair][i][bucket] = .{
                .open = 0,
                .high = 0,
                .low = 0,
                .close = 0,
                .volume = 0,
            };
        }
        current_bucket = bucket;
    }

    var cell = &matrix.cells[pair][level][bucket];

    // First tick in bucket: set open
    if (cell.open == 0) {
        cell.open = tick.price_cents;
        cell.high = tick.price_cents;
        cell.low = tick.price_cents;
    }

    // Update high/low
    if (tick.price_cents > cell.high) cell.high = tick.price_cents;
    if (tick.price_cents < cell.low) cell.low = tick.price_cents;

    // Always update close
    cell.close = tick.price_cents;

    // Accumulate volume
    cell.volume += tick.size_sats;
}

// Get cell at specific bucket (for consensus/feed reading)
pub fn getCell(pair_id: u16, level: u32, bucket: u32) types.MatrixCell {
    if (pair_id >= 3 or level >= 32 or bucket >= 30) {
        return .{ .open = 0, .high = 0, .low = 0, .close = 0, .volume = 0 };
    }
    return matrix.cells[pair_id][level][bucket];
}

// Get current matrix pointer for direct access (if needed)
pub fn getMatrixPtr() *types.MarketMatrix {
    return &matrix;
}
