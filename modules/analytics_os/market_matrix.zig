// market_matrix.zig — ExoGridChart-compatible market profile for OmniBus
// 2D Price × Time matrix for market visualization and OHLCV generation

const types = @import("types.zig");

pub const OHLCV = extern struct {
    open: u64,   
    high: u64,   
    low: u64,    
    close: u64,  
    volume: u64, 
};

pub const MarketMatrixState = extern struct {
    btc_grid: [32][30]u64,      
    eth_grid: [32][30]u64,      
    lcx_grid: [32][30]u64,      

    btc_ohlcv: [30]OHLCV,       
    eth_ohlcv: [30]OHLCV,
    lcx_ohlcv: [30]OHLCV,

    btc_ticks: u32,
    eth_ticks: u32,
    lcx_ticks: u32,

    btc_total_volume: u64,
    eth_total_volume: u64,
    lcx_total_volume: u64,

    current_time_bucket: u8,
    session_start_tsc: u64,
    cycle_count: u64,

    exchange_volume: [3][3]u64,
    exchange_ticks: [3][3]u32,
};

fn getMatrixStatePtr() *volatile MarketMatrixState {
    return @as(*volatile MarketMatrixState, @ptrFromInt(types.MATRIX_BASE));
}

pub fn init() void {
    const state = getMatrixStatePtr();

    var i: usize = 0;
    while (i < 32) : (i += 1) {
        var j: usize = 0;
        while (j < 30) : (j += 1) {
            state.btc_grid[i][j] = 0;
            state.eth_grid[i][j] = 0;
            state.lcx_grid[i][j] = 0;
        }
    }

    i = 0;
    while (i < 30) : (i += 1) {
        state.btc_ohlcv[i] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
        state.eth_ohlcv[i] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
        state.lcx_ohlcv[i] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
    }

    state.btc_ticks = 0;
    state.eth_ticks = 0;
    state.lcx_ticks = 0;

    state.btc_total_volume = 0;
    state.eth_total_volume = 0;
    state.lcx_total_volume = 0;

    state.current_time_bucket = 0;
    state.session_start_tsc = 0;
    state.cycle_count = 0;

    var ex: usize = 0;
    while (ex < 3) : (ex += 1) {
        var p: usize = 0;
        while (p < 3) : (p += 1) {
            state.exchange_volume[ex][p] = 0;
            state.exchange_ticks[ex][p] = 0;
        }
    }
}

pub fn ingestTick(pair_id: u16, exchange_id: u8, price_cents: u64, size_sats: u64) void {
    const state = getMatrixStatePtr();
    const price_level = quantizePrice(pair_id, price_cents);
    if (price_level >= 32) return;

    const time_bucket = state.current_time_bucket;
    if (time_bucket >= 30) return;

    switch (pair_id) {
        0 => { 
            state.btc_grid[price_level][time_bucket] +%= size_sats;
            state.btc_ticks +%= 1;
            state.btc_total_volume +%= size_sats;
            updateCandle(&state.btc_ohlcv[time_bucket], price_cents, size_sats);
        },
        1 => { 
            state.eth_grid[price_level][time_bucket] +%= size_sats;
            state.eth_ticks +%= 1;
            state.eth_total_volume +%= size_sats;
            updateCandle(&state.eth_ohlcv[time_bucket], price_cents, size_sats);
        },
        2 => { 
            state.lcx_grid[price_level][time_bucket] +%= size_sats;
            state.lcx_ticks +%= 1;
            state.lcx_total_volume +%= size_sats;
            updateCandle(&state.lcx_ohlcv[time_bucket], price_cents, size_sats);
        },
        else => return,
    }

    if (exchange_id < 3 and pair_id < 3) {
        state.exchange_volume[exchange_id][pair_id] +%= size_sats;
        state.exchange_ticks[exchange_id][pair_id] +%= 1;
    }
}

fn quantizePrice(pair_id: u16, price_cents: u64) u8 {
    const price_dollars = price_cents / 100;

    return switch (pair_id) {
        0 => {
            const base = 65000;
            const step = 310;
            if (price_dollars < base) return 0;
            const offset = (price_dollars - base) / step;
            return @intCast(@min(offset, 31));
        },
        1 => {
            const base = 1700;
            const step = 50;
            if (price_dollars < base) return 0;
            const offset = (price_dollars - base) / step;
            return @intCast(@min(offset, 31));
        },
        2 => {
            const base_microcents = 2000;
            const step_microcents = 200;
            const price_microcents = price_cents * 10000;
            if (price_microcents < base_microcents) return 0;
            const offset = (price_microcents - base_microcents) / step_microcents;
            return @intCast(@min(offset, 31));
        },
        else => 0,
    };
}

fn updateCandle(candle: *volatile OHLCV, price_cents: u64, size_sats: u64) void {
    if (candle.volume == 0) {
        candle.open = price_cents;
        candle.high = price_cents;
        candle.low = price_cents;
    } else {
        if (price_cents > candle.high) {
            candle.high = price_cents;
        }
        if (price_cents < candle.low) {
            candle.low = price_cents;
        }
    }
    candle.close = price_cents;
    candle.volume +%= size_sats;
}

pub fn advanceTimeBucket() void {
    const state = getMatrixStatePtr();
    state.current_time_bucket = (state.current_time_bucket + 1) % 30;

    if (state.current_time_bucket < 30) {
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            state.btc_grid[i][state.current_time_bucket] = 0;
            state.eth_grid[i][state.current_time_bucket] = 0;
            state.lcx_grid[i][state.current_time_bucket] = 0;
        }

        state.btc_ohlcv[state.current_time_bucket] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
        state.eth_ohlcv[state.current_time_bucket] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
        state.lcx_ohlcv[state.current_time_bucket] = .{.open = 0, .high = 0, .low = 0, .close = 0, .volume = 0};
    }
}

pub fn get_matrix_stats(pair_id: u16) u64 {
    const state = getMatrixStatePtr();
    return switch (pair_id) {
        0 => state.btc_total_volume,
        1 => state.eth_total_volume,
        2 => state.lcx_total_volume,
        else => 0,
    };
}

pub fn get_exchange_volume_internal(exchange_id: u8, pair_id: u16) u64 {
    if (exchange_id >= 3 or pair_id >= 3) return 0;
    const state = getMatrixStatePtr();
    return state.exchange_volume[exchange_id][pair_id];
}

pub fn get_exchange_volume(exchange_id: u8, pair_id: u16) u64 {
    return get_exchange_volume_internal(exchange_id, pair_id);
}

pub fn update(tick: types.Tick) void {
    const exchange_id: u8 = @intFromEnum(tick.source_id);
    ingestTick(tick.pair_id, exchange_id, tick.price_cents, tick.size_sats);
}
