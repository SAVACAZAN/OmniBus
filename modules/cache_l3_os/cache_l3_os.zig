// cache_l3_os.zig — High-Performance L3 Cache (256KB, 8-way set-associative, <5ns access)

const types = @import("cache_types.zig");

fn getCacheStatePtr() *volatile types.L3CacheState {
    return @as(*volatile types.L3CacheState, @ptrFromInt(types.CACHE_STATE_BASE));
}

fn getCacheSetPtr(set_index: u32) *volatile types.CacheSet {
    if (set_index >= types.CACHE_SETS) return undefined;
    const addr = types.CACHE_DATA_BASE + @as(usize, set_index) * @sizeOf(types.CacheSet);
    return @as(*volatile types.CacheSet, @ptrFromInt(addr));
}

/// Calculate cache set index from address
fn get_set_index(address: u64) u32 {
    // Set bits [11:6] of address (512 sets × 64B lines = bits 11:0 = 4KB)
    return @as(u32, @intCast((address >> 6) & 0x1FF));
}

/// Calculate cache tag from address
fn get_tag(address: u64) u64 {
    // Tag = address >> 12 (ignore line offset and set index)
    return address >> 12;
}

/// Find cache line by tag in a set
fn find_line_in_set(set: *volatile types.CacheSet, tag: u64) ?u8 {
    var i: u8 = 0;
    while (i < types.CACHE_WAYS) : (i += 1) {
        const line = &set.lines[i];
        if (line.valid == 1 and line.tag == tag) {
            return i;
        }
    }
    return null;
}

/// Find empty or LRU slot in set
fn find_eviction_slot(set: *volatile types.CacheSet, state: *volatile types.L3CacheState) u8 {
    // First, look for empty slot
    var i: u8 = 0;
    while (i < types.CACHE_WAYS) : (i += 1) {
        if (set.lines[i].valid == 0) {
            return i;
        }
    }

    // No empty slot - use LRU policy
    if (state.eviction_policy == @intFromEnum(types.EvictionPolicy.lru)) {
        return set.lru_order[0];  // Least recently used
    } else if (state.eviction_policy == @intFromEnum(types.EvictionPolicy.lfu)) {
        // Least frequently used
        var min_freq: u32 = 0xFFFFFFFF;
        var min_idx: u8 = 0;
        i = 0;
        while (i < types.CACHE_WAYS) : (i += 1) {
            if (set.lines[i].frequency < min_freq) {
                min_freq = set.lines[i].frequency;
                min_idx = i;
            }
        }
        return min_idx;
    } else {
        // FIFO: evict oldest (slot 0 is oldest)
        return 0;
    }
}

/// Load cache line from main memory (simulated)
fn load_cache_line(address: u64, data: [*]const u8) void {
    const state = getCacheStatePtr();
    const set_idx = get_set_index(address);
    const tag = get_tag(address);
    const set = getCacheSetPtr(set_idx);

    // Check if already in cache
    if (find_line_in_set(set, tag)) |idx| {
        // Hit - update LRU
        set.lines[idx].timestamp = state.cycle_count;
        set.lines[idx].frequency +|= 1;
        set.lines[idx].accessed = 1;
        state.hits +|= 1;
        return;
    }

    // Miss - evict and load
    state.misses +|= 1;
    const evict_idx = find_eviction_slot(set, state);
    const line = &set.lines[evict_idx];

    // Writeback if dirty
    if (line.valid == 1 and line.dirty == 1) {
        state.writebacks +|= 1;
        state.lines_dirty -|= 1;
    }

    // Load new line
    line.tag = tag;
    line.valid = 1;
    line.dirty = 0;
    line.accessed = 1;
    line.timestamp = state.cycle_count;
    line.frequency = 1;
    line.state = @intFromEnum(types.CacheLineState.exclusive);

    // Copy data
    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        line.data[i] = data[i];
    }

    state.lines_occupied +|= 1;
    state.evictions +|= 1;
}

/// Store to cache line (with write-through or write-back)
fn store_cache_line(address: u64, data: [*]const u8, write_back: u1) void {
    const state = getCacheStatePtr();
    const set_idx = get_set_index(address);
    const tag = get_tag(address);
    const set = getCacheSetPtr(set_idx);

    if (find_line_in_set(set, tag)) |idx| {
        const line = &set.lines[idx];
        // Hit - update data and mark dirty if write-back
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            line.data[i] = data[i];
        }
        if (write_back == 1) {
            line.dirty = 1;
            if (line.state == @intFromEnum(types.CacheLineState.exclusive) or
                line.state == @intFromEnum(types.CacheLineState.modified)) {
                line.state = @intFromEnum(types.CacheLineState.modified);
                state.lines_dirty +|= 1;
            }
        } else {
            // Write-through: immediately writeback
            state.writebacks +|= 1;
        }
        state.hits +|= 1;
        return;
    }

    // Miss on write - allocate line
    state.misses +|= 1;
    load_cache_line(address, data);

    // Mark as modified
    const line = &getCacheSetPtr(set_idx).lines[find_eviction_slot(getCacheSetPtr(set_idx), state)];
    if (write_back == 1) {
        line.dirty = 1;
        line.state = @intFromEnum(types.CacheLineState.modified);
        state.lines_dirty +|= 1;
    }
}

/// Flush dirty cache lines (writeback)
fn flush_dirty_lines() u32 {
    const state = getCacheStatePtr();
    var flushed: u32 = 0;

    var set_idx: u32 = 0;
    while (set_idx < types.CACHE_SETS) : (set_idx += 1) {
        const set = getCacheSetPtr(set_idx);
        var i: u8 = 0;
        while (i < types.CACHE_WAYS) : (i += 1) {
            if (set.lines[i].valid == 1 and set.lines[i].dirty == 1) {
                set.lines[i].dirty = 0;
                flushed +|= 1;
                state.lines_dirty -|= 1;
                state.writebacks +|= 1;
            }
        }
    }

    return flushed;
}

/// Calculate cache hit ratio
fn get_hit_ratio() u32 {
    const state = getCacheStatePtr();
    const total = state.hits + state.misses;
    if (total == 0) return 0;
    return @as(u32, @intCast((state.hits * 100) / total));
}

/// Calculate cache pressure (occupancy percentage)
fn update_cache_pressure() void {
    const state = getCacheStatePtr();
    const max_lines = types.CACHE_SETS * types.CACHE_WAYS;
    state.cache_pressure = @as(u8, @intCast((state.lines_occupied * 100) / max_lines));
}

pub export fn init_plugin() void {
    const state = getCacheStatePtr();
    state.magic = 0x4C334341;
    state.flags = 0;
    state.cycle_count = 0;
    state.eviction_policy = @intFromEnum(types.EvictionPolicy.lru);
    state.hits = 0;
    state.misses = 0;
    state.evictions = 0;
    state.writebacks = 0;
    state.lines_occupied = 0;
    state.lines_dirty = 0;
    state.cache_pressure = 0;
}

pub export fn cache_load(address: u64, data: u64) void {
    load_cache_line(address, @as([*]const u8, @ptrFromInt(data)));
}

pub export fn cache_store(address: u64, data: u64, write_back: u8) void {
    store_cache_line(address, @as([*]const u8, @ptrFromInt(data)), @as(u1, @intCast(write_back & 1)));
}

pub export fn cache_flush() u32 {
    return flush_dirty_lines();
}

pub export fn cache_get_hits() u64 {
    return getCacheStatePtr().hits;
}

pub export fn cache_get_misses() u64 {
    return getCacheStatePtr().misses;
}

pub export fn cache_get_hit_ratio() u32 {
    return get_hit_ratio();
}

pub export fn cache_get_occupancy() u32 {
    const state = getCacheStatePtr();
    return state.lines_occupied;
}

pub export fn cache_set_eviction_policy(policy: u8) u8 {
    const state = getCacheStatePtr();
    if (policy > 3) return 0;
    state.eviction_policy = policy;
    return 1;
}

pub export fn cache_get_cache_pressure() u8 {
    return getCacheStatePtr().cache_pressure;
}

pub export fn cache_get_dirty_lines() u32 {
    return getCacheStatePtr().lines_dirty;
}

pub export fn run_cache_cycle() void {
    const state = getCacheStatePtr();
    state.cycle_count +|= 1;

    // Update cache pressure every 10 cycles
    if (state.cycle_count % 10 == 0) {
        update_cache_pressure();
    }

    // Auto-flush if cache pressure > 90%
    if (state.cache_pressure > 90) {
        _ = flush_dirty_lines();
    }

    // Calculate average access time
    // Hit: ~11 cycles (L3), Miss: ~200 cycles (memory)
    const total_accesses = state.hits + state.misses;
    if (total_accesses > 0) {
        const hit_cost = state.hits * 11;
        const miss_cost = state.misses * 200;
        state.avg_access_time_cycles = @as(u32, @intCast((hit_cost + miss_cost) / total_accesses));
    }
}

pub export fn ipc_dispatch() u64 {
    const ipc_req = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    const state = getCacheStatePtr();
    if (state.magic != 0x4C334341) {
        init_plugin();
    }

    const request = ipc_req.*;
    var result: u64 = 0;

    switch (request) {
        0xE1 => {  // CACHE_LOAD
            const addr = ipc_result.*;
            const data = @as(u64, @intCast((ipc_result.* >> 32)));
            cache_load(addr, data);
            result = 1;
        },
        0xE2 => {  // CACHE_STORE
            const addr = ipc_result.* & 0xFFFFFFFF;
            const data = (ipc_result.* >> 32) & 0xFFFFFFFF;
            const wb = @as(u8, @intCast((ipc_result.* >> 63) & 0x01));
            cache_store(addr, data, wb);
            result = 1;
        },
        0xE3 => {  // CACHE_FLUSH
            result = cache_flush();
        },
        0xE4 => {  // CACHE_GET_HIT_RATIO
            result = cache_get_hit_ratio();
        },
        0xE5 => {  // CACHE_GET_OCCUPANCY
            result = cache_get_occupancy();
        },
        0xE6 => {  // CACHE_SET_POLICY
            const policy = @as(u8, @intCast(ipc_result.* & 0xFF));
            result = cache_set_eviction_policy(policy);
        },
        else => {
            ipc_status.* = 0x03;
            return 1;
        },
    }

    ipc_status.* = 0x02;
    ipc_result.* = result;
    return 0;
}

pub fn main() void {
    init_plugin();
    run_cache_cycle();
}
