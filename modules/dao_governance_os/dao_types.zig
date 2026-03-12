// dao_types.zig — DAO Governance with Emergency Council + Treasury Wallets
pub const DAO_BASE: usize = 0x3D0000;
pub const MAX_PROPOSALS: usize = 32;
pub const MAX_COUNCIL: usize = 5;

pub const PROPOSAL_BASE: usize = 0x3D0100;
pub const COUNCIL_BASE: usize = 0x3D2000;
pub const TREASURY_BASE: usize = 0x3D3000;

pub const ProposalStatus = enum(u8) {
    Pending = 0,
    Voting = 1,
    Vetoed = 2,
    Timelocked = 3,
    Failed = 4,
    Executed = 5,
    Expired = 6,
};

pub const ProposalType = enum(u8) {
    ParameterChange = 0,
    SmartContract = 1,
    ProtocolUpgrade = 2,
    Treasury = 3,
    ValidatorElection = 4,
    Emergency = 5,
};

pub const VoteType = enum(u8) {
    For = 0,
    Against = 1,
    Abstain = 2,
};

// Compact Proposal struct (256 bytes each, 32 proposals = 8KB)
pub const Proposal = extern struct {
    proposal_id: u32,
    proposer_addr: u64,           // First 8 bytes of address (simplified)
    proposal_type: u8,
    status: u8,
    title_hash: u64,              // Hash of title
    description_hash: u64,        // Hash of description

    created_ms: u64,
    voting_start_ms: u64,
    voting_end_ms: u64,
    veto_deadline_ms: u64,
    timelock_end_ms: u64,

    votes_for: u64,
    votes_against: u64,
    votes_abstain: u64,

    veto_count: u8,
    quorum_reached: u8,
    _pad1: [46]u8 = [_]u8{0} ** 46,
};

// Council Member: 128 bytes each, 5 members = 640 bytes
pub const CouncilMember = extern struct {
    address_hash: u64,
    name_hash: u64,
    elected_at_ms: u64,
    term_end_ms: u64,
    veto_count: u32,
    is_active: u8,
    _pad: [27]u8 = [_]u8{0} ** 27,
};

// Treasury State: 256 bytes
pub const TreasuryState = extern struct {
    wallet_slot: u32,
    current_chain: u32,
    balance_low: u64,
    balance_high: u64,
    total_sent_low: u64,
    total_sent_high: u64,
    total_received_low: u64,
    total_received_high: u64,
    pending_tx_hash: [32]u8,
    address_hash: u64,
    address_len: u8,
    _pad: [23]u8 = [_]u8{0} ** 23,
};

// DAO State Header: 128 bytes at DAO_BASE (0x3D0000)
pub const DaoState = extern struct {
    magic: u32 = 0x44414F21,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64,
    proposals_created: u32,
    proposals_passed: u32,
    proposals_failed: u32,
    proposals_vetoed: u32,

    quorum_percent: u8,
    voting_period_ms: u32,
    veto_window_ms: u32,
    timelock_ms: u32,

    council_count: u8,
    proposal_count: u8,

    total_omni_supply_low: u64,
    total_omni_supply_high: u64,

    _pad2: [8]u8 = [_]u8{0} ** 8,
};

// Helper: convert u128 to/from two u64s
pub fn pack_u128(value: u128) struct { low: u64, high: u64 } {
    return .{
        .low = @as(u64, @intCast(value & 0xFFFFFFFFFFFFFFFF)),
        .high = @as(u64, @intCast((value >> 64) & 0xFFFFFFFFFFFFFFFF)),
    };
}

pub fn unpack_u128(low: u64, high: u64) u128 {
    return @as(u128, low) | (@as(u128, high) << 64);
}

pub fn hash_bytes(data: [*]const u8, len: usize) u64 {
    var h: u64 = 14695981039346656037;
    var i: usize = 0;
    const prime = 1099511628211;
    while (i < len) : (i += 1) {
        h ^= data[i];
        h = h * prime;
    }
    return h;
}

const std = @import("std");
