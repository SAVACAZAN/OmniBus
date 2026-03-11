// Consensus Core (Phase 52D): 5/7 Quorum Voting
// Location: 0x3AD000–0x3B2FFF (36KB segment)
// Purpose: Voting on security decisions (async, delayed, advisory only)
// Safety: Advisory only - no enforcement, no blocking of trading

const std = @import("std");

const CONSENSUS_BASE: usize = 0x3AD000;
const MAGIC_CONSENSUS: u32 = 0x434F4E53; // "CONS"
const VERSION_CONSENSUS: u32 = 2;
const MAX_ISSUES: usize = 256;
const REQUIRED_VOTES: usize = 5;  // 5 out of 7
const TOTAL_VOTERS: usize = 7;

pub const VoteRecord = packed struct {
    issue_id: u32,
    voter_count: u32,
    votes: [7]u8,                      // 0=abstain, 1=approve, 2=deny
    quorum_reached: u8,
    decision: u8,                      // 0=pending, 1=approved, 2=denied
    reserved: [7]u8 = [_]u8{0} ** 7,
};

pub const ConsensusHeader = packed struct {
    magic: u32 = MAGIC_CONSENSUS,
    version: u32 = VERSION_CONSENSUS,
    total_votes_cast: u64 = 0,
    decisions_made: u32 = 0,
    quorum_failures: u32 = 0,
};

pub fn init_consensus() void {
    const header = @as(*ConsensusHeader, @ptrFromInt(CONSENSUS_BASE));
    header.magic = MAGIC_CONSENSUS;
    header.version = VERSION_CONSENSUS;
    header.total_votes_cast = 0;
    header.decisions_made = 0;
}

pub fn cast_vote(issue_id: u32, voter_id: u32, vote: u8) void {
    const header = @as(*ConsensusHeader, @ptrFromInt(CONSENSUS_BASE));
    header.total_votes_cast += 1;

    // Find or create vote record
    if (find_vote_record(issue_id)) |record| {
        if (voter_id < TOTAL_VOTERS) {
            record.votes[voter_id] = vote;
            record.voter_count += 1;

            // Check if quorum (5/7) reached
            if (record.voter_count >= REQUIRED_VOTES) {
                record.quorum_reached = 1;
                count_votes_and_decide(record);
                header.decisions_made += 1;
            }
        }
    }
}

fn find_vote_record(issue_id: u32) ?*VoteRecord {
    const records = @as([*]VoteRecord, @ptrFromInt(CONSENSUS_BASE + 64));

    var i: usize = 0;
    while (i < MAX_ISSUES) : (i += 1) {
        if (records[i].issue_id == issue_id) {
            return &records[i];
        }
    }

    // Create new record if not found
    i = 0;
    while (i < MAX_ISSUES) : (i += 1) {
        if (records[i].issue_id == 0) {
            records[i].issue_id = issue_id;
            records[i].voter_count = 0;
            records[i].quorum_reached = 0;
            records[i].decision = 0;
            return &records[i];
        }
    }

    return null;  // No space for new record
}

fn count_votes_and_decide(record: *VoteRecord) void {
    var approve_count: u32 = 0;
    var deny_count: u32 = 0;
    var total: u32 = 0;

    var i: usize = 0;
    while (i < TOTAL_VOTERS) : (i += 1) {
        if (record.votes[i] == 1) {
            approve_count += 1;
            total += 1;
        } else if (record.votes[i] == 2) {
            deny_count += 1;
            total += 1;
        }
    }

    // Decide based on majority
    if (approve_count >= REQUIRED_VOTES) {
        record.decision = 1;  // Approved
    } else if (deny_count >= REQUIRED_VOTES) {
        record.decision = 2;  // Denied
    }
}

pub fn get_decision(issue_id: u32) u8 {
    if (find_vote_record(issue_id)) |record| {
        return record.decision;
    }
    return 0;  // Pending
}

pub fn run_consensus_cycle() void {
    // Called every 131K cycles (after main trading cycle)
    // Just maintains vote state, doesn't enforce anything
    // Tally votes if quorum reached
}

pub export fn init_plugin() void {
    init_consensus();
}

pub export fn run_cycle() void {
    run_consensus_cycle();
}
