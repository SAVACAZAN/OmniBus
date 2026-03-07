// dma_ring.zig — Poll DMA ring buffer (written by C NIC driver)
// Head/tail pointers at 0x152000, slots at 0x152010 onward

const types = @import("types.zig");

// Const, ring capacity
const RING_CAPACITY: u32 = 256;
const RING_MASK: u32 = RING_CAPACITY - 1;

// Get pointer to DMA ring header
fn getRingHeader() *volatile types.DmaRingHeader {
    return @as(*volatile types.DmaRingHeader, @ptrFromInt(types.DMA_RING_BASE));
}

// Get pointer to slots array (starts at 0x152000 + 16 = 0x152010)
fn getSlotsBase() [*]volatile types.DmaRingSlot {
    return @as([*]volatile types.DmaRingSlot, @ptrFromInt(types.DMA_RING_BASE + 16));
}

// Check if ring has data available
pub fn hasSlot() bool {
    const header = getRingHeader();
    return header.head != header.tail;
}

// Read next slot from ring, advance head pointer
pub fn readNext() types.DmaRingSlot {
    const header = getRingHeader();
    const slots = getSlotsBase();

    // Read slot at current head
    const slot = slots[header.head & RING_MASK];

    // Advance head (with wraparound)
    header.head = (header.head + 1) & 0xFFFFFFFF;

    return slot;
}

// Get number of available slots
pub fn available() u32 {
    const header = getRingHeader();
    const h = header.head;
    const t = header.tail;

    if (t >= h) {
        return t - h;
    } else {
        return (RING_CAPACITY - h) + t;
    }
}

// Reset ring state (for init)
pub fn reset() void {
    const header = getRingHeader();
    header.head = 0;
    header.tail = 0;
}

// Peek at next slot without advancing head
pub fn peekNext() ?types.DmaRingSlot {
    if (!hasSlot()) return null;
    const slots = getSlotsBase();
    const header = getRingHeader();
    return slots[header.head & RING_MASK];
}
