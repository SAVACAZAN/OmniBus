// multiprocessor_types.zig — Multi-Processor SMP Coordination Types
pub const MP_BASE: usize = 0x520000;
pub const MAX_CORES: u32 = 8;
pub const MAX_TASKS: u32 = 8;

pub const CoreState = enum(u8) {
    Idle = 0,
    Busy = 1,
    Done = 2,
};

pub const TaskType = enum(u8) {
    DaoVoteBatch = 0,
    WalletDerive = 1,
    TxSign = 2,
    Undefined = 255,
};

pub const CoreTask = extern struct {
    task_id: u32,
    core_id: u8,
    task_type: u8,
    status: u8,        // 0=pending, 1=running, 2=completed, 3=error
    _pad1: u8 = 0,
    arg0: u64,
    arg1: u64,
    result: u64,
    _pad2: [24]u8 = [_]u8{0} ** 24,
};
comptime {
    if (@sizeOf(CoreTask) != 64) {
        @compileError("CoreTask must be exactly 64 bytes");
    }
}

pub const MultiprocessorState = extern struct {
    magic: u32 = 0x4D504F53,  // "MPOS"
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    active_cores: u8,
    _pad2: [7]u8 = [_]u8{0} ** 7,

    core_state: [MAX_CORES]u8 = [_]u8{@intFromEnum(CoreState.Idle)} ** MAX_CORES,
    core_cycles: [MAX_CORES]u64 = [_]u64{0} ** MAX_CORES,

    total_tasks_dispatched: u64,
    total_tasks_completed: u64,

    _pad3: [24]u8 = [_]u8{0} ** 24,
};
comptime {
    if (@sizeOf(MultiprocessorState) > 256) {
        @compileError("MultiprocessorState must fit in 256 bytes");
    }
}

pub const CORE_TASKS_BASE: usize = MP_BASE + 0x100;
pub const CORE_STATE_BASE: usize = MP_BASE + 0x400;

pub fn get_core_task_addr(task_idx: u32) usize {
    return CORE_TASKS_BASE + task_idx * @sizeOf(CoreTask);
}

pub fn get_core_state_addr(core_idx: u32) usize {
    return CORE_STATE_BASE + core_idx * 8;
}
