// order_reader.zig — Read OrderPackets from input ring buffer
// Pattern copied from analytics_os/dma_ring.zig
// Grid OS writes to tail, Execution OS reads from head

const types = @import("types.zig");

// ============================================================================
// Ring Header Access
// ============================================================================

/// Get mutable pointer to ring header (head/tail pointers)
fn getRingHeaderPtr() *volatile types.OrderRingHeader {
    return @as(*volatile types.OrderRingHeader, @ptrFromInt(types.EXECUTION_BASE + types.RING_HEADER_OFFSET));
}

/// Get array pointer to order ring (base address of 256 slots)
fn getRingBase() [*]volatile types.OrderPacket {
    return @as([*]volatile types.OrderPacket, @ptrFromInt(types.EXECUTION_BASE + types.ORDER_RING_OFFSET));
}

// ============================================================================
// Ring Buffer Operations
// ============================================================================

/// Check if there are unread orders in the ring
/// Returns true if head != tail
pub fn hasOrder() bool {
    const ring_header = getRingHeaderPtr();
    return ring_header.head != ring_header.tail;
}

/// Read next order from ring and advance head pointer
/// Returns OrderPacket if available, null if ring is empty
pub fn readNext() ?types.OrderPacket {
    const ring_header = getRingHeaderPtr();

    // Check if ring is empty
    if (ring_header.head == ring_header.tail) {
        return null;
    }

    // Read from current head position
    const ring = getRingBase();
    const idx = ring_header.head & 0xFF;  // Mask to 256-slot size
    const packet = ring[idx];

    // Advance head pointer
    ring_header.head = (ring_header.head + 1) & 0xFFFFFFFF;

    return packet;
}

/// Peek at next order without advancing head
/// Returns OrderPacket if available, null if ring is empty
pub fn peekNext() ?types.OrderPacket {
    const ring_header = getRingHeaderPtr();

    // Check if ring is empty
    if (ring_header.head == ring_header.tail) {
        return null;
    }

    // Read from current head position (no advance)
    const ring = getRingBase();
    const idx = ring_header.head & 0xFF;
    return ring[idx];
}

/// Get current head pointer value
pub fn getHead() u32 {
    const ring_header = getRingHeaderPtr();
    return ring_header.head;
}

/// Get current tail pointer value (Grid OS write position)
pub fn getTail() u32 {
    const ring_header = getRingHeaderPtr();
    return ring_header.tail;
}

/// Count pending orders in ring
pub fn countPending() u32 {
    const ring_header = getRingHeaderPtr();
    const head = ring_header.head;
    const tail = ring_header.tail;

    if (tail >= head) {
        return tail - head;
    } else {
        // Wraparound case
        return (0x100000000 - head) + tail;  // Adjust for 32-bit arithmetic
    }
}

/// Manually reset head pointer (for debugging/restart)
pub fn resetHead() void {
    const ring_header = getRingHeaderPtr();
    ring_header.head = 0;
}

/// Manually reset both head and tail (for full ring reset)
pub fn resetRing() void {
    const ring_header = getRingHeaderPtr();
    ring_header.head = 0;
    ring_header.tail = 0;
}
