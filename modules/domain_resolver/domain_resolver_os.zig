// domain_resolver_os.zig — Blockchain domain name resolution
// Phase 51: ENS (.eth), .anyone, ArNS support with cache
// Memory: 0x4E0000–0x4EFFFF (64KB)

const std = @import("std");
const types = @import("domain_resolver_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Memory Access Functions
// ============================================================================

/// Get mutable pointer to domain resolver state header (0x4E0000)
fn getDomainResolverStatePtr() *volatile types.DomainResolverState {
    return @as(*volatile types.DomainResolverState, @ptrFromInt(types.DOMAIN_RESOLVER_BASE));
}

/// Get mutable pointer to a cache entry by index
fn getCacheEntryPtr(index: usize) *volatile types.DomainCacheEntry {
    if (index >= types.MAX_DOMAIN_CACHE_ENTRIES) return undefined;
    const base = types.DOMAIN_RESOLVER_BASE + @sizeOf(types.DomainResolverState);
    return @as(*volatile types.DomainCacheEntry, @ptrFromInt(base + index * @sizeOf(types.DomainCacheEntry)));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Domain Resolver OS
/// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Zero-fill resolver state
    const state = getDomainResolverStatePtr();
    state.* = .{
        .magic = 0x444F4D52,  // "DOMR"
        .flags = 0x01,        // Active
        .cycle_count = 0,
        .cache_hits = 0,
        .cache_misses = 0,
        .resolutions_pending = 0,
        .resolutions_completed = 0,
        .resolutions_failed = 0,
        .cache_entries_used = 0,
        .cache_evictions = 0,
        .last_cleanup_cycle = 0,
        .eth_resolutions = 0,
        .solana_resolutions = 0,
        .arweave_resolutions = 0,
        .last_error_code = 0,
        ._pad2 = [_]u8{0} ** 63,
    };

    // Zero-fill cache entries
    var i: usize = 0;
    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);
        entry.* = .{
            .domain_hash = 0,
            .chain_id = 0,
            .domain_type = 0,
            .status = types.STATUS_EMPTY,
            ._pad1 = 0,
            .address = [_]u8{0} ** 32,
            .resolving_since = 0,
            .ttl_seconds = 3600,
            .resolver_endpoint = 0,
            ._pad2 = [_]u8{0} ** 7,
        };
    }

    initialized = true;
}

// ============================================================================
// Main Resolver Cycle
// ============================================================================

/// Main domain resolution cycle
/// Called by scheduler every cycle (deterministic)
export fn run_resolver_cycle() void {
    if (!initialized) return;

    // Check auth gate
    const auth = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH)).*;
    if (auth != 0x70) return;

    const state = getDomainResolverStatePtr();

    // === PHASE 51A: Cache Cleanup ===
    // Every 131072 cycles (0x1FFFF), clean up expired entries
    if ((cycle_count & 0x1FFFF) == 0) {
        cleanupExpiredEntries(state);
    }

    // === PHASE 51B: Cache Statistics ===
    // Update cycle count
    cycle_count +|= 1;
    state.cycle_count = cycle_count;
}

/// Clean up expired cache entries (TTL-based eviction)
fn cleanupExpiredEntries(state: *volatile types.DomainResolverState) void {
    // In real system: use kernel cycle counter for wall time
    // For now: simple eviction based on status
    var evicted: u32 = 0;
    var i: usize = 0;

    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);

        // Mark failed entries as expired after 1 hour (3600 seconds)
        // In real system: would use cycle_count / (CPU_FREQ_HZ) for actual time
        if (entry.status == types.STATUS_FAILED and
            cycle_count > (entry.resolving_since + (3600 * 1000000))) {
            // Evict
            entry.status = types.STATUS_EMPTY;
            entry.domain_hash = 0;
            evicted += 1;
        }
    }

    if (evicted > 0) {
        state.cache_evictions +|= evicted;
    }
}

// ============================================================================
// Domain Resolution API
// ============================================================================

/// Resolve a domain hash to an address (write to buffer)
/// Copies resolved address to output_buffer, returns true if found
export fn resolve_domain_address(domain_hash: u64, chain_id: u8, output_buffer: [*]u8) bool {
    const state = getDomainResolverStatePtr();

    // Search cache for matching entry
    var i: usize = 0;
    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);

        if (entry.domain_hash == domain_hash and entry.chain_id == chain_id) {
            if (entry.status == types.STATUS_CACHED) {
                // Cache hit
                state.cache_hits +|= 1;
                @memcpy(output_buffer[0..32], entry.address[0..32]);
                return true;
            } else if (entry.status == types.STATUS_PENDING) {
                // Pending resolution — write zeros
                state.cache_misses +|= 1;
                @memset(output_buffer[0..32], 0);
                return false;
            } else if (entry.status == types.STATUS_FAILED) {
                // Failed resolution — write zeros
                state.cache_misses +|= 1;
                @memset(output_buffer[0..32], 0);
                return false;
            }
        }
    }

    // Not in cache — cache miss
    state.cache_misses +|= 1;
    @memset(output_buffer[0..32], 0);
    return false;
}

/// Add or update a cache entry
/// Returns: true if added/updated, false if cache full
export fn add_cache_entry(
    domain_hash: u64,
    chain_id: u8,
    domain_type: u8,
    address: [*]const u8,
    ttl_seconds: u32,
) bool {
    const state = getDomainResolverStatePtr();

    // Search for existing entry or free slot
    var free_slot: usize = types.MAX_DOMAIN_CACHE_ENTRIES; // Not found initially
    var i: usize = 0;

    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);

        // Found existing entry — update it
        if (entry.domain_hash == domain_hash and entry.chain_id == chain_id) {
            @memcpy(entry.address[0..32], address[0..32]);
            entry.status = types.STATUS_CACHED;
            entry.ttl_seconds = ttl_seconds;
            entry.resolving_since = cycle_count;

            // Update chain-specific counters
            if (chain_id == types.CHAIN_ETHEREUM) {
                state.eth_resolutions +|= 1;
            } else if (chain_id == types.CHAIN_SOLANA) {
                state.solana_resolutions +|= 1;
            } else if (chain_id == types.CHAIN_ARWEAVE) {
                state.arweave_resolutions +|= 1;
            }

            state.resolutions_completed +|= 1;
            return true;
        }

        // Remember first free slot
        if (free_slot == types.MAX_DOMAIN_CACHE_ENTRIES and entry.status == types.STATUS_EMPTY) {
            free_slot = i;
        }
    }

    // No existing entry — use free slot if available
    if (free_slot < types.MAX_DOMAIN_CACHE_ENTRIES) {
        const entry = getCacheEntryPtr(free_slot);
        entry.domain_hash = domain_hash;
        entry.chain_id = chain_id;
        entry.domain_type = domain_type;
        @memcpy(entry.address[0..32], address[0..32]);
        entry.status = types.STATUS_CACHED;
        entry.ttl_seconds = ttl_seconds;
        entry.resolving_since = cycle_count;
        entry.resolver_endpoint = 1; // Infura (default feeder)

        state.cache_entries_used +|= 1;
        state.resolutions_completed +|= 1;

        // Update chain-specific counters
        if (chain_id == types.CHAIN_ETHEREUM) {
            state.eth_resolutions +|= 1;
        } else if (chain_id == types.CHAIN_SOLANA) {
            state.solana_resolutions +|= 1;
        } else if (chain_id == types.CHAIN_ARWEAVE) {
            state.arweave_resolutions +|= 1;
        }

        return true;
    }

    // Cache full
    state.resolutions_failed +|= 1;
    state.last_error_code = 1; // Cache full error
    return false;
}

/// Mark a domain as pending resolution (feeder will fill it)
export fn mark_resolution_pending(domain_hash: u64, chain_id: u8, domain_type: u8) bool {
    const state = getDomainResolverStatePtr();

    // Search for free slot
    var i: usize = 0;
    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);

        if (entry.status == types.STATUS_EMPTY) {
            entry.domain_hash = domain_hash;
            entry.chain_id = chain_id;
            entry.domain_type = domain_type;
            entry.status = types.STATUS_PENDING;
            entry.resolving_since = cycle_count;
            entry.ttl_seconds = 60; // 60-second timeout for resolution

            state.resolutions_pending +|= 1;
            return true;
        }
    }

    return false; // No free slots
}

/// Check if a domain is cached
export fn is_domain_cached(domain_hash: u64, chain_id: u8) bool {
    var i: usize = 0;
    while (i < types.MAX_DOMAIN_CACHE_ENTRIES) : (i += 1) {
        const entry = getCacheEntryPtr(i);

        if (entry.domain_hash == domain_hash and entry.chain_id == chain_id) {
            return entry.status == types.STATUS_CACHED;
        }
    }
    return false;
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get cache hit count
export fn get_cache_hits() u32 {
    const state = getDomainResolverStatePtr();
    return state.cache_hits;
}

/// Get cache miss count
export fn get_cache_misses() u32 {
    const state = getDomainResolverStatePtr();
    return state.cache_misses;
}

/// Get number of pending resolutions
export fn get_pending_resolutions() u32 {
    const state = getDomainResolverStatePtr();
    return state.resolutions_pending;
}

/// Get cycle count
export fn get_cycle_count() u64 {
    return cycle_count;
}

/// Check if initialized
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

/// Get total cache entries used
export fn get_cache_entries_used() u32 {
    const state = getDomainResolverStatePtr();
    return state.cache_entries_used;
}

/// Get cache eviction count
export fn get_cache_evictions() u32 {
    const state = getDomainResolverStatePtr();
    return state.cache_evictions;
}

/// Get Ethereum resolutions count
export fn get_eth_resolutions() u32 {
    const state = getDomainResolverStatePtr();
    return state.eth_resolutions;
}
