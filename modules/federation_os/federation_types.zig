// federation_types.zig — IPC message hub for inter-kernel communication
// L18: Multi-kernel federation and message routing
// Memory: 0x3A0000–0x3AFFFF (64KB)

pub const FEDERATION_BASE: usize = 0x3A0000;
pub const MAX_MESSAGES: usize = 16;
pub const MAX_MODULES: usize = 20;

/// Message type enumeration
pub const MessageType = enum(u8) {
    QueryState = 0,
    UpdateParam = 1,
    TriggerAlert = 2,
    RequestOrder = 3,
    RequestVote = 4,
    BroadcastEvent = 5,
    AckMessage = 6,
    ErrorReply = 7,
};

/// Message status enumeration
pub const MessageStatus = enum(u8) {
    Queued = 0,
    InTransit = 1,
    Delivered = 2,
    Acked = 3,
    Expired = 4,
};

/// Single IPC message (32 bytes)
pub const FederationMessage = extern struct {
    msg_id: u16,              // 0  — Unique message identifier
    src_module: u8,           // 2  — Sender module index (0-19)
    dst_module: u8,           // 3  — Destination module (0xFF = broadcast)
    msg_type: u8,             // 4  — MessageType enum
    status: u8,               // 5  — MessageStatus enum
    payload_type: u8,         // 6  — Application-defined payload tag
    _pad: u8 = 0,             // 7  — alignment
    payload: i64,             // 8  — 64-bit payload (integer value or pointer)
    created_cycle: u64,       // 16 — Cycle when enqueued
    deadline_cycle: u64,      // 24 — Expiration cycle (0 = no expiry)
    // = 32 bytes
};

/// Federation hub state (128 bytes @ 0x3A0000)
pub const FederationState = extern struct {
    magic: u32 = 0x46454445,            // 0  — "FEDE" magic
    flags: u8,                          // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,     // 5  — alignment
    cycle_count: u64,                   // 8  — Total cycles executed

    // Message queue management
    queue_head: u8,                     // 16 — Next write index
    queue_tail: u8,                     // 17 — Next read index
    queue_count: u8,                    // 18 — Active messages
    _pad2: [5]u8 = [_]u8{0} ** 5,     // 19 — alignment

    // Statistics
    total_sent: u64,                    // 24 — Messages enqueued
    total_delivered: u64,               // 32 — Messages fully delivered
    total_expired: u64,                 // 40 — Expired messages
    total_broadcasts: u64,              // 48 — Broadcast messages sent

    // Routing
    registered_modules: u8,             // 56 — Number of registered modules
    last_msg_id: u16,                   // 57 — Auto-increment counter
    _pad3: u8 = 0,                      // 59 — alignment

    // Escalation
    escalation_triggered: u8,           // 60 — Flag: communication failure
    escalation_reason: u8,              // 61 — Error code
    _pad4: [66]u8 = [_]u8{0} ** 66,   // 62 → 128 bytes
};

/// Get default message timeout (1000 cycles)
pub fn getDefaultMessageTimeout() u32 {
    return 1000;
}
