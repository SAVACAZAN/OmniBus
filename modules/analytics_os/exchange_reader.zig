// exchange_reader.zig — Phase 22: Real exchange data integration
// Reads BTC/ETH prices from shared buffer @ 0x140000 (populated by external feeder)
// Injects into consensus engine for Grid OS to trade on real market data

const types = @import("types.zig");
const consensus = @import("consensus.zig");

/// Exchange data buffer layout (shared with external feeder)
pub const ExchangeBuffer = struct {
    timestamp: u64,           // 0x140000: Last update time
    btc_price_cents: u64,     // 0x140008: BTC_USD in cents
    btc_volume_sats: u64,     // 0x140010: BTC volume in satoshis
    eth_price_cents: u64,     // 0x140018: ETH_USD in cents
    eth_volume_sats: u64,     // 0x140020: ETH volume in satoshis
    exchange_flags: u32,      // 0x140028: Kraken(0), Coinbase(1), LCX(2)
    _reserved: u32,           // 0x14002C
    last_tsc: u64,            // 0x140030: TSC of last read
};

const EXCHANGE_BUFFER_ADDR: usize = 0x140000;
const KRAKEN_VALID = 0x01;
const COINBASE_VALID = 0x02;
const LCX_VALID = 0x04;

/// Get pointer to exchange buffer
fn getExchangeBuffer() *volatile ExchangeBuffer {
    return @as(*volatile ExchangeBuffer, @ptrFromInt(EXCHANGE_BUFFER_ADDR));
}

/// Read real price from exchange buffer and inject into consensus
/// Called once per analytics cycle
pub fn readAndInjectPrices() void {
    const buf = getExchangeBuffer();

    // === Phase 22-b: Read from external feeder ===
    const timestamp = buf.timestamp;
    const btc_price = buf.btc_price_cents;
    const btc_volume = buf.btc_volume_sats;
    const eth_price = buf.eth_price_cents;
    const eth_volume = buf.eth_volume_sats;
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
    if ((flags & KRAKEN_VALID) != 0) {
        const btc_tick = types.Tick{
            .exchange_id = 0, // Kraken
            .pair_id = 0,     // BTC_USD
            .price_cents = btc_price,
            .bid_cents = btc_price - 50,   // Simplified bid/ask
            .ask_cents = btc_price + 50,
            .size_sats = btc_volume,
            .timestamp = timestamp,
        };
        consensus.addTick(0, btc_tick); // Pair 0 = BTC
    }

    // === Inject ETH price into consensus (pair 1) ===
    if ((flags & KRAKEN_VALID) != 0) {
        const eth_tick = types.Tick{
            .exchange_id = 0,  // Kraken
            .pair_id = 1,      // ETH_USD
            .price_cents = eth_price,
            .bid_cents = eth_price - 10,   // Tighter spread for ETH
            .ask_cents = eth_price + 10,
            .size_sats = eth_volume,
            .timestamp = timestamp,
        };
        consensus.addTick(1, eth_tick); // Pair 1 = ETH
    }

    // === Coinbase fallback (pair 0 & 1) ===
    if ((flags & COINBASE_VALID) != 0 and (flags & KRAKEN_VALID) == 0) {
        // Use Coinbase data if Kraken unavailable
        const btc_tick = types.Tick{
            .exchange_id = 1,
            .pair_id = 0,
            .price_cents = btc_price,
            .bid_cents = btc_price - 50,
            .ask_cents = btc_price + 50,
            .size_sats = btc_volume,
            .timestamp = timestamp,
        };
        consensus.addTick(0, btc_tick);
    }

    // === LCX integration (for future staking data) ===
    if ((flags & LCX_VALID) != 0) {
        // LCX typically has EGLD data; reserve for Phase 25
        _ = eth_price; // Use ETH as proxy for now
    }
}

/// Check if exchange buffer is active
pub fn isBufferActive() bool {
    const buf = getExchangeBuffer();
    return (buf.exchange_flags & (KRAKEN_VALID | COINBASE_VALID | LCX_VALID)) != 0;
}
