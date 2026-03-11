// domain_resolver_types.zig — Blockchain domain name resolution (ENS, .anyone, ArNS)
// Phase 51: Multi-chain domain resolution with caching
// Memory: 0x4E0000–0x4EFFFF (64KB)
// Supported: ENS (.eth), .anyone (Arweave), ArNS (Arweave Name Service)

pub const DOMAIN_RESOLVER_BASE: usize = 0x4E0000;
pub const KERNEL_AUTH: usize = 0x100050;

// Cache capacity
pub const MAX_DOMAIN_CACHE_ENTRIES: usize = 256;
pub const DOMAIN_CACHE_SIZE: usize = MAX_DOMAIN_CACHE_ENTRIES * @sizeOf(DomainCacheEntry);

// Chain IDs for multi-chain resolution
pub const CHAIN_ETHEREUM: u8 = 1;
pub const CHAIN_SOLANA: u8 = 2;
pub const CHAIN_ARWEAVE: u8 = 3;

// Domain status codes
pub const STATUS_EMPTY: u8 = 0;
pub const STATUS_CACHED: u8 = 1;
pub const STATUS_PENDING: u8 = 2;
pub const STATUS_FAILED: u8 = 3;
pub const STATUS_EXPIRED: u8 = 4;

// Domain type codes
pub const TYPE_ENS: u8 = 1;      // .eth domains (Ethereum)
pub const TYPE_ANYONE: u8 = 2;   // .anyone domains (Arweave)
pub const TYPE_ARNS: u8 = 3;     // ArNS domains (Arweave Name Service)

// ============================================================================
// DomainCacheEntry — Single domain name resolution cache entry
// ============================================================================
pub const DomainCacheEntry = extern struct {
    domain_hash: u64 = 0,          // 0-7:   Keccak256(domain) for ENS, ArNS nameHash for others
    chain_id: u8 = 0,              // 8:     CHAIN_ETHEREUM (1), CHAIN_SOLANA (2), CHAIN_ARWEAVE (3)
    domain_type: u8 = 0,           // 9:     TYPE_ENS, TYPE_ANYONE, TYPE_ARNS
    status: u8 = STATUS_EMPTY,     // 10:    CACHED, PENDING, FAILED, EXPIRED
    _pad1: u8 = 0,                 // 11

    // Resolved address (chain-specific)
    // Ethereum: 20-byte address (padded to 32)
    // Solana: 32-byte public key
    // Arweave: 43-char base64 address (stored as hash in 32B)
    address: [32]u8 = [_]u8{0} ** 32,  // 12-43: Resolved address

    // Metadata
    resolving_since: u64 = 0,      // 44-51: Timestamp when resolution started (for retry)
    ttl_seconds: u32 = 3600,       // 52-55: Time-to-live in seconds (1 hour default)
    resolver_endpoint: u8 = 0,     // 56:    Which resolver provided this (0=local, 1=Infura, 2=Alchemy, 3=custom)
    _pad2: [7]u8 = [_]u8{0} ** 7,  // 57-63: Padding to 64 bytes

    // = 64 bytes per entry
};

// ============================================================================
// DomainResolverState — Module header
// ============================================================================
pub const DomainResolverState = extern struct {
    magic: u32 = 0x444F4D52,                  // "DOMR" at 0x4E0000
    flags: u8 = 0,                            // Active flag
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,                     // 8-15: Total cycles processed

    // Statistics
    cache_hits: u32 = 0,                      // 16-19: Successful cache lookups
    cache_misses: u32 = 0,                    // 20-23: Cache lookups that failed
    resolutions_pending: u32 = 0,             // 24-27: Number of pending resolutions
    resolutions_completed: u32 = 0,           // 28-31: Completed resolutions
    resolutions_failed: u32 = 0,              // 32-35: Failed resolution attempts

    // Cache management
    cache_entries_used: u32 = 0,              // 36-39: Number of non-empty cache entries
    cache_evictions: u32 = 0,                 // 40-43: Number of entries evicted due to TTL
    last_cleanup_cycle: u64 = 0,              // 44-51: Last time we cleaned up expired entries

    // Multi-chain support
    eth_resolutions: u32 = 0,                 // 52-55: Ethereum domain resolutions
    solana_resolutions: u32 = 0,              // 56-59: Solana domain resolutions
    arweave_resolutions: u32 = 0,             // 60-63: Arweave domain resolutions

    // Error tracking
    last_error_code: u8 = 0,                  // 64: Last error (0=none, 1=timeout, 2=invalid_domain, 3=network_error)
    _pad2: [63]u8 = [_]u8{0} ** 63,           // 65-127: Padding to 128 bytes

    // = 128 bytes total
};

// ============================================================================
// ResolutionRequest — Request to resolve a domain
// ============================================================================
pub const ResolutionRequest = extern struct {
    domain_hash: u64,                         // Keccak256 hash of domain name
    domain_type: u8,                          // TYPE_ENS, TYPE_ANYONE, TYPE_ARNS
    chain_id: u8,                             // CHAIN_ETHEREUM, CHAIN_SOLANA, CHAIN_ARWEAVE
    requested_at_cycle: u64,                  // Which cycle was this requested
    timeout_cycles: u32,                      // How long to wait before timing out
    _pad: [6]u8 = [_]u8{0} ** 6,

    // = 32 bytes
};

// ============================================================================
// ENS Resolution Data
// ============================================================================
pub const ENSResolver = extern struct {
    registry_address: [20]u8,                 // Ethereum ENS Registry address
    reverse_registry_address: [20]u8,         // Reverse resolver address
    resolver_interface_id: u32,               // EIP-165 interface ID for resolver
    _pad: [4]u8 = [_]u8{0} ** 4,
};

// ============================================================================
// ArNS Resolution Data (Arweave Name Service)
// ============================================================================
pub const ArNSResolver = extern struct {
    registry_contract: [32]u8,                // Arweave SmartWeave contract ID
    network_info_tx: [32]u8,                  // Transaction ID containing network info
    _pad: [32]u8 = [_]u8{0} ** 32,
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Compute simple hash of domain name (for .anyone domains)
/// Not cryptographically secure, but deterministic for caching
pub fn hashDomain(domain_name: []const u8) u64 {
    var hash: u64 = 0x9e3779b97f4a7c15; // FNV offset basis
    for (domain_name) |byte| {
        hash ^= @as(u64, byte);
        hash = (hash << 13) | (hash >> 51); // Rotate left 13 bits
        hash = hash *% 0xbf58476d1ce4e5b9;   // FNV prime
    }
    return hash;
}

/// Check if a domain name is valid format
pub fn isValidDomain(domain_name: []const u8) bool {
    if (domain_name.len == 0 or domain_name.len > 255) return false;

    // Must contain at least one dot
    var has_dot = false;
    for (domain_name) |byte| {
        if (byte == '.') has_dot = true;
        // Allow alphanumeric, dots, hyphens
        if (!((byte >= 'a' and byte <= 'z') or
              (byte >= '0' and byte <= '9') or
              byte == '.' or byte == '-')) {
            return false;
        }
    }
    return has_dot;
}

/// Identify domain type from TLD
pub fn getDomainType(domain_name: []const u8) u8 {
    if (domain_name.len < 4) return 0;

    const tld_start = domain_name.len - 4;

    // Check for .eth
    if (domain_name.len >= 4 and std.mem.eql(u8, domain_name[tld_start..], ".eth")) {
        return TYPE_ENS;
    }

    // Check for .anyone
    if (domain_name.len >= 7 and std.mem.eql(u8, domain_name[domain_name.len - 7..], ".anyone")) {
        return TYPE_ANYONE;
    }

    // Check for .ar (ArNS uses .ar TLD)
    if (domain_name.len >= 3 and std.mem.eql(u8, domain_name[domain_name.len - 3..], ".ar")) {
        return TYPE_ARNS;
    }

    return 0; // Unknown type
}

// Import std for mem.eql
const std = @import("std");
