// exchange_reader.zig — Phase 22: Real exchange data integration
// Reads BTC/ETH prices from shared buffer @ 0x140000 (populated by external feeder)
// Injects into consensus engine for Grid OS to trade on real market data

const types = @import("types.zig");
const consensus = @import("consensus.zig");

/// Exchange data buffer layout (shared with external feeder)
/// Extended Phase 22-d: Added LCX support (72 bytes total)
pub const ExchangeBuffer = struct {
    timestamp: u64,           // 0x140000: Last update time
    btc_price_cents: u64,     // 0x140008: BTC_USD in cents
    btc_volume_sats: u64,     // 0x140010: BTC volume in satoshis
    eth_price_cents: u64,     // 0x140018: ETH_USD in cents
    eth_volume_sats: u64,     // 0x140020: ETH volume in satoshis
    exchange_flags: u32,      // 0x140028: Kraken(0x01), Coinbase(0x02), LCX(0x04)
    _reserved: u32,           // 0x14002C
    last_tsc: u64,            // 0x140030: TSC of last read
    lcx_price_cents: u64,     // 0x140038: LCX_USD in cents (Phase 22-d)
    lcx_volume_sats: u64,     // 0x140040: LCX volume in satoshis
};

// Phase 16: Multi-source SHM buffers
// Kraken feeder    → 0x140000 (flags=0x01)
// Coinbase feeder  → 0x141000 (flags=0x02)
// LCX Exch feeder  → 0x142000 (flags=0x04)
const EXCHANGE_BUFFER_ADDR: usize = 0x140000;
const COINBASE_BUFFER_ADDR: usize = 0x141000;
const LCX_BUFFER_ADDR: usize      = 0x142000;
const KRAKEN_VALID = 0x01;
const COINBASE_VALID = 0x02;
const LCX_VALID = 0x04;

/// Get pointer to Kraken exchange buffer (primary)
fn getExchangeBuffer() *volatile ExchangeBuffer {
    return @as(*volatile ExchangeBuffer, @ptrFromInt(EXCHANGE_BUFFER_ADDR));
}

/// Get pointer to Coinbase exchange buffer (Phase 16)
fn getCoinbaseBuffer() *volatile ExchangeBuffer {
    return @as(*volatile ExchangeBuffer, @ptrFromInt(COINBASE_BUFFER_ADDR));
}

/// Get pointer to LCX Exchange buffer (Phase 16)
fn getLCXBuffer() *volatile ExchangeBuffer {
    return @as(*volatile ExchangeBuffer, @ptrFromInt(LCX_BUFFER_ADDR));
}

/// Read real price from exchange buffer and inject into consensus
/// Called once per analytics cycle
pub fn readAndInjectPrices() void {
    const buf = getExchangeBuffer();

    // === Phase 22-b: Read from external feeder ===
    const timestamp = buf.timestamp;
    const btc_price = buf.btc_price_cents;
    const eth_price = buf.eth_price_cents;
    const flags = buf.exchange_flags;

    // Validate that buffer has recent data
    if (timestamp == 0) return; // No data yet
    if (btc_price == 0 or eth_price == 0) return; // Invalid prices

    // Check if data is stale (more than 1 second old based on update pattern)
    // In real system would compare with TSC
    // For now, inject if any exchange flag is set
    if ((flags & (KRAKEN_VALID | COINBASE_VALID | LCX_VALID)) == 0) {
        return; // No valid exchange data
    }

    // === Inject BTC price into consensus (pair 0) ===
    if ((flags & KRAKEN_VALID) != 0 and btc_price > 0) {
        consensus.submit(0, @intFromEnum(types.SourceId.kraken), btc_price);
    }

    // === Inject ETH price into consensus (pair 1) ===
    if ((flags & KRAKEN_VALID) != 0 and eth_price > 0) {
        consensus.submit(1, @intFromEnum(types.SourceId.kraken), eth_price);
    }

    // === Coinbase fallback from Kraken buffer (old single-source mode) ===
    if ((flags & COINBASE_VALID) != 0 and (flags & KRAKEN_VALID) == 0) {
        if (btc_price > 0) {
            consensus.submit(0, @intFromEnum(types.SourceId.coinbase), btc_price);
        }
    }

    // === LCX from Kraken buffer (old single-source mode, Phase 22-d) ===
    if ((flags & LCX_VALID) != 0) {
        const lcx_price = buf.lcx_price_cents;
        if (lcx_price > 0) {
            consensus.submit(2, @intFromEnum(types.SourceId.lcx), lcx_price);
        }
    }

    // === Phase 16: Read Coinbase from dedicated buffer @ 0x141000 ===
    const cb_buf = getCoinbaseBuffer();
    const cb_flags = cb_buf.exchange_flags;
    if ((cb_flags & COINBASE_VALID) != 0 and cb_buf.timestamp > 0) {
        if (cb_buf.btc_price_cents > 0) {
            consensus.submit(0, @intFromEnum(types.SourceId.coinbase), cb_buf.btc_price_cents);
        }
        if (cb_buf.eth_price_cents > 0) {
            consensus.submit(1, @intFromEnum(types.SourceId.coinbase), cb_buf.eth_price_cents);
        }
        if (cb_buf.lcx_price_cents > 0) {
            consensus.submit(2, @intFromEnum(types.SourceId.coinbase), cb_buf.lcx_price_cents);
        }
    }

    // === Phase 16: Read LCX Exchange from dedicated buffer @ 0x142000 ===
    const lcx_buf = getLCXBuffer();
    const lcx_ex_flags = lcx_buf.exchange_flags;
    if ((lcx_ex_flags & LCX_VALID) != 0 and lcx_buf.timestamp > 0) {
        if (lcx_buf.btc_price_cents > 0) {
            consensus.submit(0, @intFromEnum(types.SourceId.lcx), lcx_buf.btc_price_cents);
        }
        if (lcx_buf.eth_price_cents > 0) {
            consensus.submit(1, @intFromEnum(types.SourceId.lcx), lcx_buf.eth_price_cents);
        }
        if (lcx_buf.lcx_price_cents > 0) {
            consensus.submit(2, @intFromEnum(types.SourceId.lcx), lcx_buf.lcx_price_cents);
        }
    }
}

/// Check if any exchange buffer is active (Kraken primary + Coinbase/LCX secondary)
pub fn isBufferActive() bool {
    const buf = getExchangeBuffer();
    if ((buf.exchange_flags & (KRAKEN_VALID | COINBASE_VALID | LCX_VALID)) != 0) return true;
    const cb_buf = getCoinbaseBuffer();
    if ((cb_buf.exchange_flags & COINBASE_VALID) != 0) return true;
    const lcx_buf = getLCXBuffer();
    return (lcx_buf.exchange_flags & LCX_VALID) != 0;
}
