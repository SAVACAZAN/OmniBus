pub const RECOVERY_BASE: usize = 0x3F0000;

pub const RecoveryState = extern struct {
    magic: u32 = 0x52434F56,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    checkpoints_created: u32,
    recovery_attempts: u32,
    last_checkpoint_cycle: u64,
    checkpoint_interval: u32,
    enabled: u8,
    _pad2: [83]u8 = [_]u8{0} ** 83,
};
