// replay_types.zig — Event-Driven Transaction Replay (Phase 60)
// Deterministic state reconstruction from event journal

pub const REPLAY_BASE: usize = 0x5E0000;
pub const MAX_REPLAY_EVENTS: usize = 512;
pub const MAX_COMPENSATION_QUEUE: usize = 64;

pub const ReplayMode = enum(u8) {
    idle = 0,
    forward_replay = 1,
    backward_replay = 2,
    compensation = 3,
};

pub const ReplayEvent = extern struct {
    event_id: u64,
    correlation_id: u64,
    trade_id: u64,
    event_type: u8,          // CREATED, MATCHED, EXECUTED, FILLED, FAILED
    timestamp: u64,
    data_offset: u32,        // Pointer into event data buffer
    data_size: u32,
    checksum: u32,
    status: u8,              // PENDING, REPLAYED, COMPENSATED
};

pub const SagaCompensation = extern struct {
    trade_id: u64,
    saga_step: u8,           // Which step to undo (0-3)
    compensation_action: u8,  // REFUND, UNWIND_ORDER, CANCEL_STAKE
    status: u8,              // PENDING, EXECUTED, FAILED
    attempts: u8,
    last_error: u32,
};

pub const ReplayOsState = extern struct {
    magic: u32,              // 'RPLY'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    mode: u8,                // ReplayMode enum
    last_replayed_event_id: u64,
    total_replays: u32,
    total_compensations: u32,
    replay_error_count: u32,
    last_error_code: u32,
    checkpoint_cycle: u64,
    _pad2: [36]u8,
};
