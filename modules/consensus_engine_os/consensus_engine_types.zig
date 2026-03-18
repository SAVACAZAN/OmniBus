// consensus_engine_types.zig — Byzantine fault-tolerant voting system
// L19: Multi-module consensus for critical decisions
// Memory: 0x390000–0x39FFFF (64KB)

pub const CONSENSUS_BASE: usize = 0x390000;
pub const MAX_PROPOSALS: usize = 16;
pub const MAX_MODULE_COUNT: usize = 7;
pub const SUPERMAJORITY: usize = 5; // 5 of 7 required

/// Proposal type enumeration
pub const ProposalType = enum(u8) {
    SetGridStep = 0,
    SetMinSpread = 1,
    EnableTrading = 2,
    SetRiskLevel = 3,
    EmergencyHalt = 4,
    EnableModule = 5,
    DisableModule = 6,
    SetAlertThreshold = 7,
};

/// Proposal status enumeration
pub const ProposalStatus = enum(u8) {
    Pending = 0,
    Accepted = 1,
    Rejected = 2,
    Expired = 3,
};

/// Single consensus proposal (32 bytes)
pub const ConsensusProposal = extern struct {
    proposal_id: u16,           // 0  — Unique proposal identifier
    proposal_type: u8,          // 2  — ProposalType enum
    status: u8,                 // 3  — ProposalStatus enum
    value: i32,                 // 4  — Parameter value (if applicable)
    proposer_module: u8,        // 8  — Module ID that submitted proposal (0-6)
    yes_votes: u8,              // 9  — Number of Yes votes
    no_votes: u8,               // 10 — Number of No votes
    abstain_votes: u8,          // 11 — Number of Abstain votes
    deadline_cycles: u64,       // 12 — Expiration cycle (absolute)
    votes_cast: u8,             // 20 — Bitmask: bit N = module N voted
    _pad: [11]u8 = [_]u8{0} ** 11, // 21 → 32 bytes
};

/// Consensus engine state (128 bytes @ 0x390000)
pub const ConsensusState = extern struct {
    magic: u32 = 0x434F4E53,            // 0  — "CONS" magic
    flags: u8,                          // 4  — 0x01=enabled
    _pad1: [3]u8 = [_]u8{0} ** 3,     // 5  — alignment
    cycle_count: u64,                   // 8  — Total cycles executed

    // Proposal ring buffer management
    proposal_head: u8,                  // 16 — Next write index (0-15)
    proposal_count: u8,                 // 17 — Active proposals (0-16)
    _pad2: [6]u8 = [_]u8{0} ** 6,     // 18 — alignment

    // Statistics
    total_proposals: u64,               // 24 — All-time proposals submitted
    total_accepted: u64,                // 32 — Proposals reaching supermajority
    total_rejected: u64,                // 40 — Proposals rejected (>50% No)
    total_expired: u64,                 // 48 — Proposals expired without consensus

    // Byzantine fault tracking
    byzantine_flags: u8,                // 56 — Bitmask: bit N = module N faulty
    quorum_achieved: u8,                // 57 — Flag: supermajority reached last cycle
    last_proposal_id: u16,              // 58 — Auto-increment counter
    last_accepted_type: u8,             // 60 — ProposalType of last accepted proposal
    last_accepted_value: i32,           // 61 — Value of last accepted proposal
    _pad3: u8 = 0,                      // 65 — alignment

    escalation_triggered: u8,           // 66 — Flag: byzantine activity escalated
    escalation_reason: u8,              // 67 — Error code for escalation
    _pad4: [60]u8 = [_]u8{0} ** 60,   // 68 → 128 bytes
};

/// Get default proposal timeout (1000 cycles)
pub fn getDefaultProposalTimeout() u32 {
    return 1000;
}
