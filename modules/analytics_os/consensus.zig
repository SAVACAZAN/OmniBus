// consensus.zig — 71% median consensus over 10-slot sorted buffer
// Fixed-size insertion sort, 5% outlier rejection

const types = @import("types.zig");

const MAX_SAMPLES: usize = 10;
const OUTLIER_THRESHOLD_BPS: u64 = 500; // 5.00% in basis points

// Global consensus windows: one per pair
var consensus_windows: [64]types.ConsensusWindow = undefined;

// Initialize all consensus windows
pub fn init() void {
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        consensus_windows[i] = .{
            .prices = [_]u64{0} ** 10,
            .sources = [_]u8{0} ** 10,
            .count = 0,
            ._pad = [_]u8{0} ** 7,
        };
    }
}

// Compute median from sorted price array
fn computeMedian(prices: [*]const u64, count: usize) u64 {
    if (count == 0) return 0;
    if (count == 1) return prices[0];

    // Median: with odd count, middle element; with even, average of two middle
    const mid = count / 2;
    if (count % 2 == 1) {
        return prices[mid];
    } else {
        // Average of two middle elements
        return (prices[mid - 1] + prices[mid]) / 2;
    }
}

// Check if price is an outlier (> 5% from current median)
fn isOutlier(current_median: u64, new_price: u64) bool {
    if (current_median == 0) return false;

    const diff = if (new_price > current_median)
        new_price - current_median
    else
        current_median - new_price;

    const threshold = (current_median * OUTLIER_THRESHOLD_BPS) / 10000;
    return diff > threshold;
}

// Find index of sample from given source (or return 10 if not found)
fn findSource(window: *types.ConsensusWindow, source: u8) u32 {
    var i: u32 = 0;
    while (i < window.count) : (i += 1) {
        if (window.sources[i] == source) return i;
    }
    return 10;
}

// Insert or replace a price sample in sorted order
fn insertSorted(window: *types.ConsensusWindow, price: u64, source: u8) void {
    // Check if source already exists
    const existing_idx = findSource(window, source);

    if (existing_idx < MAX_SAMPLES) {
        // Replace existing sample with same source
        window.prices[existing_idx] = price;
        // Re-sort if price changed significantly (simple bubble-up/down)
        // For simplicity, we'll just shift and re-insert
        const i = existing_idx;
        while (i > 0 and window.prices[i] < window.prices[i - 1]) : (i -= 1) {
            const tmp_price = window.prices[i - 1];
            const tmp_source = window.sources[i - 1];
            window.prices[i - 1] = window.prices[i];
            window.sources[i - 1] = window.sources[i];
            window.prices[i] = tmp_price;
            window.sources[i] = tmp_source;
        }
        while (i < window.count - 1 and window.prices[i] > window.prices[i + 1]) : (i += 1) {
            const tmp_price = window.prices[i + 1];
            const tmp_source = window.sources[i + 1];
            window.prices[i + 1] = window.prices[i];
            window.sources[i + 1] = window.sources[i];
            window.prices[i] = tmp_price;
            window.sources[i] = tmp_source;
        }
    } else if (window.count < MAX_SAMPLES) {
        // Add new sample
        window.prices[window.count] = price;
        window.sources[window.count] = source;
        window.count += 1;

        // Insertion sort
        const i = window.count - 1;
        while (i > 0 and window.prices[i] < window.prices[i - 1]) : (i -= 1) {
            const tmp_price = window.prices[i - 1];
            const tmp_source = window.sources[i - 1];
            window.prices[i - 1] = window.prices[i];
            window.sources[i - 1] = window.sources[i];
            window.prices[i] = tmp_price;
            window.sources[i] = tmp_source;
        }
    } else {
        // Buffer full: evict oldest (first slot)
        var i: usize = 0;
        while (i < MAX_SAMPLES - 1) : (i += 1) {
            window.prices[i] = window.prices[i + 1];
            window.sources[i] = window.sources[i + 1];
        }
        window.prices[MAX_SAMPLES - 1] = price;
        window.sources[MAX_SAMPLES - 1] = source;

        // Re-sort the last element
        const j = MAX_SAMPLES - 1;
        while (j > 0 and window.prices[j] < window.prices[j - 1]) : (j -= 1) {
            const tmp_price = window.prices[j - 1];
            const tmp_source = window.sources[j - 1];
            window.prices[j - 1] = window.prices[j];
            window.sources[j - 1] = window.sources[j];
            window.prices[j] = tmp_price;
            window.sources[j] = tmp_source;
        }
    }
}

// Submit a new price sample
pub fn submit(pair_id: u16, source_id: u8, price_cents: u64) void {
    if (pair_id >= 64) return;

    const window = &consensus_windows[pair_id];

    // Outlier check
    if (window.count > 0) {
        const median = computeMedian(@as([*]const u64, &window.prices), window.count);
        if (isOutlier(median, price_cents)) {
            return; // Reject outlier
        }
    }

    // Insert into sorted buffer
    insertSorted(window, price_cents, source_id);
}

// Compute consensus result for a pair
pub fn compute(pair_id: u16) types.ConsensusResult {
    if (pair_id >= 64) return .{ .valid = false, .price = 0 };

    const window = &consensus_windows[pair_id];

    // 71% consensus: need at least 7 samples out of 10
    if (window.count < 7) {
        return .{ .valid = false, .price = 0 };
    }

    const median = computeMedian(@as([*]const u64, &window.prices), window.count);
    return .{ .valid = true, .price = median };
}

// Get current count for a pair
pub fn getCount(pair_id: u16) u8 {
    if (pair_id >= 64) return 0;
    return consensus_windows[pair_id].count;
}

// Reset consensus window for a pair
pub fn reset(pair_id: u16) void {
    if (pair_id >= 64) return;

    const window = &consensus_windows[pair_id];
    var i: usize = 0;
    while (i < MAX_SAMPLES) : (i += 1) {
        window.prices[i] = 0;
        window.sources[i] = 0;
    }
    window.count = 0;
}

// Reset all windows
pub fn resetAll() void {
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        reset(@as(u16, @intCast(i)));
    }
}
