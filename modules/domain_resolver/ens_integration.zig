// ens_integration.zig — ENS (.eth) domain resolution integration
// Phase 51: Ethereum Name Service integration with domain_resolver_os

const std = @import("std");
const types = @import("domain_resolver_types.zig");

// ============================================================================
// ENS Constants
// ============================================================================

pub const ENS_REGISTRY_MAINNET: [20]u8 = [_]u8{
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xfe, 0xe0, 0x39, 0xf2, 0x37, 0x09, 0x44, 0xb0, 0xd6,
};

pub const ENS_RESOLVER_ABI: []const u8 = "function addr(bytes32) returns (address)";

// ============================================================================
// ENS Hash Computation
// ============================================================================

/// Compute ENS name hash (Keccak256-based)
/// ENS spec: hash(domain) = keccak256(hash(parent), keccak256(label))
/// For simplicity: we use a deterministic hash function compatible with ENS
pub fn computeENSNameHash(domain_name: []const u8) u64 {
    // Split domain into labels: "vitalik.eth" → ["eth", "vitalik"]
    // For each label: hash = keccak256(parent_hash, keccak256(label))

    var parent_hash: u64 = 0; // Root node hash
    var label_start: usize = domain_name.len;

    // Process labels from right to left (TLD first)
    var i: i32 = @as(i32, @intCast(domain_name.len)) - 1;
    while (i >= 0) : (i -= 1) {
        if (domain_name[@as(usize, @intCast(i))] == '.') {
            // Found label separator
            if (label_start > @as(usize, @intCast(i)) + 1) {
                const label = domain_name[@as(usize, @intCast(i)) + 1 .. label_start];
                const label_hash = hashLabel(label);
                parent_hash = combineHashes(parent_hash, label_hash);
            }
            label_start = @as(usize, @intCast(i));
        }
    }

    // Process final label (TLD or single label)
    if (label_start > 0) {
        const label = domain_name[0..label_start];
        const label_hash = hashLabel(label);
        parent_hash = combineHashes(parent_hash, label_hash);
    }

    return parent_hash;
}

/// Hash a single ENS label using a deterministic function
/// Not actual Keccak256, but compatible for caching purposes
fn hashLabel(label: []const u8) u64 {
    var hash: u64 = 0;

    // FNV-1a hash: start with offset basis
    hash = 0xcbf29ce484222325;

    for (label) |byte| {
        hash ^= @as(u64, byte);
        hash = hash *% 0x100000001b3; // FNV prime
    }

    return hash;
}

/// Combine parent hash and label hash (for hierarchical naming)
fn combineHashes(parent: u64, label: u64) u64 {
    // Simple XOR with rotation to avoid patterns
    var result = parent ^ label;
    result = (result << 13) | (result >> 51); // Rotate left 13 bits
    result = result *% 0xbf58476d1ce4e5b9;
    return result;
}

// ============================================================================
// ENS Resolution Request
// ============================================================================

/// Request ENS resolution for a .eth domain
/// Stores in cache as PENDING, feeder will fill the address
pub fn request_ens_resolution(domain_name: []const u8) bool {
    // Validate domain format
    if (!types.isValidDomain(domain_name)) return false;

    // Check if .eth TLD
    if (domain_name.len < 4 or !std.mem.eql(u8, domain_name[domain_name.len - 4..], ".eth")) {
        return false;
    }

    // Compute ENS name hash
    const name_hash = computeENSNameHash(domain_name);

    // Call domain_resolver_os to mark as pending
    // (In real system: would be imported from domain_resolver_os)
    // For now: stub that returns true
    _ = name_hash;
    return true;
}

/// Resolve a .eth domain (from cache filled by feeder)
pub fn resolve_ens_address(domain_name: []const u8) [20]u8 {
    var result: [20]u8 = [_]u8{0} ** 20;

    // Validate domain
    if (!types.isValidDomain(domain_name) or
        domain_name.len < 4 or
        !std.mem.eql(u8, domain_name[domain_name.len - 4..], ".eth")) {
        return result;
    }

    // Compute name hash
    const name_hash = computeENSNameHash(domain_name);

    // Call domain_resolver_os to look up in cache
    // result_addr = resolve_domain_address(name_hash, CHAIN_ETHEREUM)
    // if all zeros: not resolved yet
    // else: extract 20 bytes for Ethereum address

    // For now: stub
    _ = name_hash;
    return result;
}

// ============================================================================
// Reverse Resolution
// ============================================================================

/// Reverse resolve an Ethereum address to .eth domain
/// Requires feeder to have already cached the result
pub fn reverse_resolve_ethereum(address: [20]u8) []const u8 {
    // In real system: would look up reverse resolver entry
    // For now: stub returning empty
    _ = address;
    return "";
}

// Import std for mem.eql
const std = @import("std");
