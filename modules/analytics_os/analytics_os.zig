// analytics_os.zig — Root Analytics OS module for OmniBus
// Exports: init_plugin(), run_analytics_cycle(), register_pair()

const types = @import("types.zig");
const uart = @import("uart.zig");
const dma_ring = @import("dma_ring.zig");
const packet_parser = @import("packet_parser.zig");
const market_matrix = @import("market_matrix.zig");
const consensus = @import("consensus.zig");
const price_feed = @import("price_feed.zig");

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
