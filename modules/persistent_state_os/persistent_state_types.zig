pub const PSTS_BASE: usize = 0x510000;
pub const SNAPSHOT_OFFSET: usize = 0x80;
pub const SNAPSHOT_BASE: usize = PSTS_BASE + SNAPSHOT_OFFSET;
pub const MAX_SNAPSHOT_SIZE: usize = 65536 - 128;

pub const SnapshotEntry = extern struct {
    module_id: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    base_address: u64 = 0,
    size_bytes: u32 = 0,
    checksum: u32 = 0,
    _pad2: [12]u8 = [_]u8{0} ** 12,
};

pub const PersistentStateHeader = extern struct {
    magic: u32 = 0x50535453,
    flags: u8 = 0x01,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64 = 0,
    sequence_number: u64 = 0,
    crc32: u32 = 0,
    snapshot_size: u32 = 0,
    module_mask: u32 = 0,
    checkpoints_created: u32 = 0,
    restore_attempts: u32 = 0,
    last_checkpoint_cycle: u64 = 0,
    checkpoint_interval: u32 = 262144,
    last_error: u8 = 0,
    _pad2: [59]u8 = [_]u8{0} ** 59,
};
