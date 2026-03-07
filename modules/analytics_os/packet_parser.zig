// packet_parser.zig — Parse DMA ring slot to Tick + validate

const types = @import("types.zig");
const ticker_map = @import("ticker_map.zig");

// Read TSC (Time Stamp Counter) via RDTSC instruction
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// Parse a DMA ring slot into a Tick
// Returns null if validation fails
pub fn parse(slot: types.DmaRingSlot) ?types.Tick {
    // Validate source_id (0,1,2 are valid)
    if (slot.source_id > 2) return null;
    const source: types.SourceId = @enumFromInt(@as(u8, @intCast(slot.source_id)));

    // Validate pair_id bounds
    if (slot.pair_id >= 64) return null;

    // Validate price (must be non-zero)
    if (slot.price == 0) return null;

    // Validate size (for trade msg_type, size must be non-zero)
    if (slot.msg_type == 0 and slot.size == 0) return null;

    // Validate side
    const side: types.Side = if (slot.msg_type == 0)
        @enumFromInt(slot.side)
    else
        .na;

    // Validate message type
    const msg_type: types.MsgType = @enumFromInt(slot.msg_type);

    // Convert DmaRingSlot to Tick
    const tick: types.Tick = .{
        .source_id = source,
        .pair_id = slot.pair_id,
        .msg_type = msg_type,
        .side = side,
        .price_cents = slot.price,
        .size_sats = slot.size,
        .tsc = if (slot.tsc == 0) rdtsc() else slot.tsc,
        .bid_cents = 0,
        .ask_cents = 0,
    };

    return tick;
}

// Optional: parse with current TSC (in case driver didn't set it)
pub fn parseWithCurrentTsc(slot: types.DmaRingSlot) ?types.Tick {
    var tick = parse(slot) orelse return null;
    if (tick.tsc == 0) {
        tick.tsc = rdtsc();
    }
    return tick;
}

// Minimal JSON/binary field extraction (if needed for raw payload parsing)
// This is a fallback if the C driver provides raw frame bytes instead of parsed fields
pub fn parseRawPayload(payload: [*]const u8, payload_len: usize) ?[2]u64 {
    // Placeholder: parse raw bytes into price/size
    // Real implementation would parse JSON or binary wire format
    // For now, assume C driver has already parsed
    _ = payload;
    _ = payload_len;
    return null;
}
