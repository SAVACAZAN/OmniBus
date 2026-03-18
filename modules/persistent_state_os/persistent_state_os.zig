const std = @import("std");
const types = @import("persistent_state_types.zig");

fn getPersistentStatePtr() *volatile types.PersistentStateHeader {
    return @as(*volatile types.PersistentStateHeader, @ptrFromInt(types.PSTS_BASE));
}

fn computeChecksum(data: [*]const u8, size: usize) u32 {
    var sum: u32 = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        sum +%= data[i];
    }
    return sum;
}

export fn init_plugin() void {
    const state = getPersistentStatePtr();
    state.magic = 0x50535453;
    state.flags = 0x01;
    state.cycle_count = 0;
    state.sequence_number = 0;
    state.crc32 = 0;
    state.snapshot_size = 0;
    state.module_mask = 0;
    state.checkpoints_created = 0;
    state.restore_attempts = 0;
    state.last_checkpoint_cycle = 0;
    state.checkpoint_interval = 262144;
    state.last_error = 0;
}

export fn run_checkpoint_cycle() void {
    const state = getPersistentStatePtr();
    state.cycle_count +|= 1;

    if (state.cycle_count >= state.last_checkpoint_cycle +| state.checkpoint_interval) {
        _ = save_checkpoint();
    }
}

export fn save_checkpoint() bool {
    const state = getPersistentStatePtr();

    const snapshot_ptr = @as([*]volatile u8, @ptrFromInt(types.SNAPSHOT_BASE));
    var offset: usize = 0;

    // Grid OS @ 0x110000 (256B)
    const src = @as([*]const u8, @ptrFromInt(0x110000));
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 256;

    // Execution OS @ 0x130000 (256B)
    src = @as([*]const u8, @ptrFromInt(0x130000));
    i = 0;
    while (i < 256) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 256;

    // Analytics OS @ 0x150000 (256B)
    src = @as([*]const u8, @ptrFromInt(0x150000));
    i = 0;
    while (i < 256) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 256;

    // BlockchainOS @ 0x250000 (256B)
    src = @as([*]const u8, @ptrFromInt(0x250000));
    i = 0;
    while (i < 256) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 256;

    // Federation OS @ 0x3A0000 (128B)
    src = @as([*]const u8, @ptrFromInt(0x3A0000));
    i = 0;
    while (i < 128) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 128;

    // Convergence Test @ 0x4D0000 (128B)
    src = @as([*]const u8, @ptrFromInt(0x4D0000));
    i = 0;
    while (i < 128) : (i += 1) {
        snapshot_ptr[offset + i] = src[i];
    }
    offset += 128;

    state.snapshot_size = @as(u32, @intCast(offset));
    state.crc32 = computeChecksum(@as([*]const u8, @ptrFromInt(types.SNAPSHOT_BASE)), offset);
    state.sequence_number +|= 1;
    state.checkpoints_created +|= 1;
    state.last_checkpoint_cycle = state.cycle_count;
    state.module_mask = 0x3F;

    return true;
}

export fn restore_checkpoint() bool {
    const state = getPersistentStatePtr();

    const snapshot_ptr = @as([*]const u8, @ptrFromInt(types.SNAPSHOT_BASE));
    const checksum = computeChecksum(snapshot_ptr, state.snapshot_size);
    if (checksum != state.crc32) {
        state.last_error = 1;
        return false;
    }

    var offset: usize = 0;

    // Grid OS @ 0x110000 (256B)
    const dst = @as([*]volatile u8, @ptrFromInt(0x110000));
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }
    offset += 256;

    // Execution OS @ 0x130000 (256B)
    dst = @as([*]volatile u8, @ptrFromInt(0x130000));
    i = 0;
    while (i < 256) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }
    offset += 256;

    // Analytics OS @ 0x150000 (256B)
    dst = @as([*]volatile u8, @ptrFromInt(0x150000));
    i = 0;
    while (i < 256) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }
    offset += 256;

    // BlockchainOS @ 0x250000 (256B)
    dst = @as([*]volatile u8, @ptrFromInt(0x250000));
    i = 0;
    while (i < 256) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }
    offset += 256;

    // Federation OS @ 0x3A0000 (128B)
    dst = @as([*]volatile u8, @ptrFromInt(0x3A0000));
    i = 0;
    while (i < 128) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }
    offset += 128;

    // Convergence Test @ 0x4D0000 (128B)
    dst = @as([*]volatile u8, @ptrFromInt(0x4D0000));
    i = 0;
    while (i < 128) : (i += 1) {
        dst[i] = snapshot_ptr[offset + i];
    }

    state.restore_attempts +|= 1;
    return true;
}

export fn get_sequence_number() u64 {
    return getPersistentStatePtr().sequence_number;
}

export fn verify_crc() u8 {
    const state = getPersistentStatePtr();
    const snapshot_ptr = @as([*]const u8, @ptrFromInt(types.SNAPSHOT_BASE));
    const checksum = computeChecksum(snapshot_ptr, state.snapshot_size);
    return if (checksum == state.crc32) 1 else 0;
}

export fn get_checkpoints_created() u32 {
    return getPersistentStatePtr().checkpoints_created;
}

export fn get_cycle_count() u64 {
    return getPersistentStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getPersistentStatePtr();
    return if (state.magic == 0x50535453) 1 else 0;
}
