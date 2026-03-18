pub const AIPC_BASE: usize = 0x500000;
pub const PRIORITY_HIGH: u8 = 0;
pub const PRIORITY_NORMAL: u8 = 1;
pub const PRIORITY_LOW: u8 = 2;
pub const QUEUE_DEPTH: usize = 8;

pub const EventStatus = enum(u8) {
    pending = 0,
    delivered = 1,
    expired = 2,
};

pub const AsyncEvent = extern struct {
    event_id: u16 = 0,
    src_module: u8 = 0,
    dst_module: u8 = 0,
    event_type: u8 = 0,
    priority: u8 = PRIORITY_NORMAL,
    status: u8 = 0,
    _pad: u8 = 0,
    payload: i64 = 0,
    deadline_cycle: u64 = 0,
    _pad2: [8]u8 = [_]u8{0} ** 8,
};

pub const AsyncIpcState = extern struct {
    magic: u32 = 0x41495043,
    flags: u8 = 0x01,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64 = 0,
    events_posted: u32 = 0,
    events_delivered: u32 = 0,
    events_expired: u32 = 0,
    events_dropped: u32 = 0,
    high_watermark: u8 = 0,
    pending_high: u8 = 0,
    pending_normal: u8 = 0,
    pending_low: u8 = 0,
    last_error: u8 = 0,
    _pad2: [82]u8 = [_]u8{0} ** 82,
};
