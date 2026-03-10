// dao_types.zig — Decentralized governance proposals & voting
pub const DAO_BASE: usize = 0x3D0000;
pub const MAX_PROPOSALS: usize = 32;

pub const ProposalStatus = enum(u8) {
    Pending = 0, Voting = 1, Approved = 2, Rejected = 3, Executed = 4,
};

pub const Proposal = extern struct {
    prop_id: u16,
    status: u8,
    proposal_type: u8,
    yes_votes: u16,
    no_votes: u16,
    abstain_votes: u16,
    _pad: u16 = 0,
};

pub const DaoState = extern struct {
    magic: u32 = 0x44414F21,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    proposals_created: u32,
    proposals_passed: u32,
    proposals_failed: u32,
    quorum_percent: u8,
    voting_period_cycles: u32,
    proposal_count: u8,
    _pad2: [74]u8 = [_]u8{0} ** 74,
};
