// cache_types.zig — High-Performance L3 Cache (256KB, <5ns latency)

pub const CACHE_L3_BASE: usize = 0x5E0000;
pub const CACHE_SIZE: usize = 256 * 1024;  // 256KB shared L3
pub const CACHE_LINE_SIZE: usize = 64;    // Standard x86-64 cache line
pub const CACHE_WAYS: u32 = 8;            // 8-way set-associative
pub const CACHE_SETS: u32 = 512;          // 512 sets = 256KB / 8 ways / 64B lines

pub const CacheLineState = enum(u8) {
    invalid = 0,           // Not in cache
    shared = 1,            // Read-only, may exist in other caches
    exclusive = 2,         // Only in this cache, unmodified
    modified = 3,          // Modified, must write back on evict
};

pub const EvictionPolicy = enum(u8) {
    lru = 0,               // Least Recently Used (standard)
    lfu = 1,               // Least Frequently Used (better for hotspots)
    fifo = 2,              // First In First Out (minimal overhead)
    arc = 3,               // Adaptive Replacement Cache (ARC)
};

pub const CacheLine = extern struct {
    tag: u64 = 0,                         // High bits of address
    state: u8 = @intFromEnum(CacheLineState.invalid),
    valid: u8 = 0,                        // 0 or 1
    dirty: u8 = 0,                        // Modified flag
    accessed: u8 = 0,                     // LRU tracking
    _pad1: [3]u8 = [_]u8{0} ** 3,

    timestamp: u64 = 0,                   // For LRU/LFU
    frequency: u32 = 0,                   // Access count (LFU)
    data: [64]u8 = [_]u8{0} ** 64,       // 64B cache line

    _pad2: [32]u8 = [_]u8{0} ** 32,
};

pub const CacheSet = extern struct {
    lines: [8]CacheLine = [_]CacheLine{.{}} ** 8,  // 8-way associative
    lru_order: [8]u8 = [_]u8{0} ** 8,    // LRU replacement order
    _pad: [32]u8 = [_]u8{0} ** 32,
};

pub const L3CacheState = extern struct {
    magic: u32 = 0x4C334341,              // "L3CA"
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    eviction_policy: u8 = @intFromEnum(EvictionPolicy.lru),
    _pad2: [7]u8 = [_]u8{0} ** 7,

    // Hit/Miss statistics
    hits: u64 = 0,
    misses: u64 = 0,
    evictions: u64 = 0,
    writebacks: u64 = 0,

    // Occupancy tracking
    lines_occupied: u32 = 0,              // Current lines in use
    lines_dirty: u32 = 0,                 // Dirty lines needing writeback

    // Performance metrics
    avg_access_time_cycles: u32 = 0,      // Weighted average (L3 ~11 cycles, memory ~200)
    cache_pressure: u8 = 0,               // 0-100% occupancy

    // Coherency tracking
    coherency_misses: u32 = 0,            // Cache line conflicts
    invalidations: u32 = 0,               // Remote invalidations

    _pad3: [64]u8 = [_]u8{0} ** 64,
};

pub const CACHE_STATE_BASE: usize = CACHE_L3_BASE;
pub const CACHE_DATA_BASE: usize = CACHE_L3_BASE + 0x2000;

// Total layout:
// 0x5E0000: L3CacheState (256B)
// 0x5E0100: CacheSet[512] = 512 * 1KB = 512KB (only 256KB used for data)
