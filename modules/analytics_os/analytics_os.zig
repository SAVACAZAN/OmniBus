// analytics_os.zig — Root Analytics OS module for OmniBus
// Exports: init_plugin(), run_analytics_cycle(), register_pair()

const types = @import("types.zig");
const uart = @import("uart.zig");
const dma_ring = @import("dma_ring.zig");
const packet_parser = @import("packet_parser.zig");
const market_matrix = @import("market_matrix.zig");
const consensus = @import("consensus.zig");
const price_feed = @import("price_feed.zig");
const exchange_reader = @import("exchange_reader.zig");
const orderbook = @import("orderbook.zig");

// Module state
var initialized: bool = false;
var pair_count: u32 = 0;
var cycle_count: u64 = 0;

// Initialize the Analytics OS module
// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Zero-fill all output segments
    price_feed.init();
    market_matrix.init();
    consensus.init();
    dma_ring.reset();
    orderbook.init();

    initialized = true;

    // Debug output
    uart.debugMsg("ANALYTICS", "init OK");
}

// Main analytics cycle
// Called repeatedly by Ada Mother OS scheduler
// Process up to 64 DMA slots per call to keep latency deterministic
export fn run_analytics_cycle() void {
    // Auth gate: check if Ada's auth byte is set to 0x70
    const auth = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH)).*;
    if (auth != 0x70) return;

    // === PHASE 22-b: Read real exchange data ===
    // Check if external feeder is populating the exchange buffer @ 0x140000
    if (exchange_reader.isBufferActive()) {
        exchange_reader.readAndInjectPrices();
    }

    // Process pending DMA slots (bounded loop for determinism)
    var processed: u32 = 0;
    const max_per_cycle: u32 = 64;

    while (processed < max_per_cycle and dma_ring.hasSlot()) : (processed += 1) {
        // Read next slot
        const slot = dma_ring.readNext();

        // Parse to Tick
        const tick = packet_parser.parse(slot) orelse {
            // Invalid slot, skip
            continue;
        };

        // Update market matrix
        market_matrix.update(tick);

        // Submit price to consensus
        const source_byte: u8 = @intFromEnum(tick.source_id);
        consensus.submit(tick.pair_id, source_byte, tick.price_cents);

        // Compute and write consensus result
        const result = consensus.compute(tick.pair_id);
        if (result.valid) {
            price_feed.write(tick.pair_id, result, tick);
        } else {
            // Mark as stale if insufficient consensus
            price_feed.markStale(tick.pair_id);
        }
    }

    cycle_count += 1;
}

// Register a trading pair for this Analytics OS
// Called by modules to enable specific pair tracking
export fn register_pair(pair_id: u16, exchange_mask: u8) void {
    if (pair_id < 64) {
        // exchange_mask: 0x01=Kraken, 0x02=Coinbase, 0x04=LCX
        // Can be used to route subscriptions in a future network layer
        pair_count += 1;

        // Debug: UART output
        uart.writeByte('[');
        uart.writeStr("PAIR");
        uart.writeByte(']');
        uart.writeByte(' ');
        uart.writeHex32(pair_id);
        uart.writeByte(' ');
        uart.writeHex32(exchange_mask);
        uart.nl();
    }
}

// Optional: Get current cycle count (for testing)
export fn get_cycle_count() u64 {
    return cycle_count;
}

// Optional: Get initialized state
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

// Optional: Manually trigger test (for QEMU debugging)
export fn test_inject_dma_slot(source_id: u16, pair_id: u16, price: u64) void {
    // For testing: manually inject a DMA slot
    // In real operation, C NIC driver would fill this
    const slot: types.DmaRingSlot = .{
        .source_id = source_id,
        .pair_id = pair_id,
        .msg_type = 0, // trade
        .side = 0, // buy
        ._pad0 = 0,
        .price = price,
        .size = 100_000_000, // 1 BTC
        .tsc = 0,
        ._reserved = [_]u8{0} ** 96,
    };

    // Simulate writing to ring (normally done by NIC driver)
    // This is for QEMU GDB testing only
    const ring_header = @as(*volatile types.DmaRingHeader, @ptrFromInt(types.DMA_RING_BASE));
    const slots = @as([*]volatile types.DmaRingSlot, @ptrFromInt(types.DMA_RING_BASE + 16));

    const idx = ring_header.tail & 0xFF;
    slots[idx] = slot;
    ring_header.tail = (ring_header.tail + 1) & 0xFFFFFFFF;
}

// ============================================================================
// ORDERBOOK EXPORTS (for MEV protection and spread analysis)
// ============================================================================

/// Get best bid price for a pair across all exchanges (in cents)
export fn get_best_bid(pair_id: u16) u64 {
    return orderbook.getBestBid(pair_id);
}

/// Get best ask price for a pair across all exchanges (in cents)
export fn get_best_ask(pair_id: u16) u64 {
    return orderbook.getBestAsk(pair_id);
}

/// Get spread between best bid/ask in basis points
export fn get_spread_bps(pair_id: u16) u16 {
    return orderbook.getSpread(pair_id);
}

/// Check if an exchange's orderbook is fresh (within 5 seconds)
export fn is_orderbook_fresh(pair_id: u16, exchange_id: u8, current_tsc: u64) u8 {
    return if (orderbook.isFresh(pair_id, exchange_id, current_tsc)) 1 else 0;
}

/// Get orderbook slice for specific pair/exchange (returns pointer at ORDERBOOK_BASE + offset if valid)
export fn get_orderbook(pair_id: u16, exchange_id: u8) u64 {
    if (orderbook.getOrderbookSlice(pair_id, exchange_id)) |slice| {
        return @intFromPtr(slice);
    }
    return 0;
}

/// Manually update orderbook (called by feeder or external module)
export fn update_orderbook_snapshot(
    pair_id: u16,
    exchange_id: u8,
    bids_ptr: [*]const types.OrderbookLevel,
    bid_count: u8,
    asks_ptr: [*]const types.OrderbookLevel,
    ask_count: u8,
    tsc: u64,
) void {
    orderbook.updateOrderbook(pair_id, exchange_id, bids_ptr, bid_count, asks_ptr, ask_count, tsc);
}

/// Get total orderbook updates received
export fn get_orderbook_updates() u32 {
    const state = @as(*volatile types.OrderbookState, @ptrFromInt(types.ORDERBOOK_BASE));
    return state.updates_received;
}

// ============================================================================
// EXCHANGE READER EXPORTS (fetch prices, volumes, ticker data)
// ============================================================================

/// Fetch BTC price in cents from primary exchange buffer
export fn fetch_btc_price() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.btc_price_cents;
}

/// Fetch ETH price in cents from primary exchange buffer
export fn fetch_eth_price() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.eth_price_cents;
}

/// Fetch LCX price in cents from primary exchange buffer
export fn fetch_lcx_price() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.lcx_price_cents;
}

/// Fetch BTC volume in satoshis from primary exchange buffer
export fn fetch_btc_volume() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.btc_volume_sats;
}

/// Fetch ETH volume in satoshis from primary exchange buffer
export fn fetch_eth_volume() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.eth_volume_sats;
}

/// Fetch LCX volume in satoshis from primary exchange buffer
export fn fetch_lcx_volume() u64 {
    if (!exchange_reader.isBufferActive()) return 0;
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.lcx_volume_sats;
}

/// Get exchange flags from primary buffer (0x01=Kraken, 0x02=Coinbase, 0x04=LCX)
export fn fetch_exchange_flags() u32 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.exchange_flags;
}

/// Get last update timestamp from primary buffer
export fn fetch_timestamp() u64 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x140000));
    return buf.timestamp;
}

/// Get Coinbase BTC price from secondary buffer @ 0x141000
export fn fetch_coinbase_btc() u64 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x141000));
    if ((buf.exchange_flags & 0x02) == 0) return 0;
    return buf.btc_price_cents;
}

/// Get Coinbase ETH price from secondary buffer @ 0x141000
export fn fetch_coinbase_eth() u64 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x141000));
    if ((buf.exchange_flags & 0x02) == 0) return 0;
    return buf.eth_price_cents;
}

/// Get LCX Exchange BTC price from tertiary buffer @ 0x142000
export fn fetch_lcx_exchange_btc() u64 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x142000));
    if ((buf.exchange_flags & 0x04) == 0) return 0;
    return buf.btc_price_cents;
}

/// Get LCX Exchange ETH price from tertiary buffer @ 0x142000
export fn fetch_lcx_exchange_eth() u64 {
    const buf = @as(*volatile exchange_reader.ExchangeBuffer, @ptrFromInt(0x142000));
    if ((buf.exchange_flags & 0x04) == 0) return 0;
    return buf.eth_price_cents;
}

/// Get PriceFeedSlot (ticker) for a pair
export fn fetch_ticker(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.consensus_price;
}

/// Get best bid from ticker (PriceFeedSlot)
export fn fetch_ticker_bid(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.bid_price;
}

/// Get best ask from ticker (PriceFeedSlot)
export fn fetch_ticker_ask(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.ask_price;
}

/// Get 24h high for a pair
export fn fetch_ticker_high_24h(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.high_24h;
}

/// Get 24h low for a pair
export fn fetch_ticker_low_24h(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.low_24h;
}

/// Get VWAP (volume-weighted average price) for a pair
export fn fetch_ticker_vwap(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.vwap;
}

/// Get trading volume for a pair
export fn fetch_ticker_volume(pair_id: u16) u64 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.consensus_volume;
}

/// Check if ticker is valid (0x01) or stale (0x02)
export fn fetch_ticker_flags(pair_id: u16) u8 {
    if (pair_id >= 3) return 0;
    const slot = @as(*volatile types.PriceFeedSlot, @ptrFromInt(types.WORKING_BASE + pair_id * 128));
    return slot.flags;
}


// ============================================================================
// MARKET MATRIX / OHLCV EXPORTS (ExoGridChart compatibility)
// ============================================================================

/// Get per-pair market volume
export fn get_market_volume(pair_id: u16) u64 {
    return market_matrix.get_matrix_stats(pair_id);
}

/// Get per-exchange volume (for analytics dashboard)
export fn get_exchange_volume(exchange_id: u8, pair_id: u16) u64 {
    return market_matrix.get_exchange_volume(exchange_id, pair_id);
}

/// Signal to advance to next time bucket (called every 60 seconds)
export fn advance_time_bucket() void {
    market_matrix.advanceTimeBucket();
}
