// consensus_engine_os.zig — Byzantine fault-tolerant voting layer
// L19: Consensus mechanism for cross-module decisions
// Memory: 0x390000–0x39FFFF (64KB)

const std = @import("std");
const types = @import("consensus_engine_types.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;

// ============================================================================
// Helper Functions
// ============================================================================

fn getConsensusStatePtr() *volatile types.ConsensusState {
    return @as(*volatile types.ConsensusState, @ptrFromInt(types.CONSENSUS_BASE));
}

fn getProposalBuffer() [*]volatile types.ConsensusProposal {
    // Proposals start at offset 128 (after state struct)
    return @as([*]volatile types.ConsensusProposal, @ptrFromInt(types.CONSENSUS_BASE + 128));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize Consensus Engine OS
export fn init_plugin() void {
    if (initialized) return;

    const state = getConsensusStatePtr();

    // Initialize state
    state.magic = 0x434F4E53; // "CONS"
    state.flags = 0x01;
    state.cycle_count = 0;
    state.proposal_head = 0;
    state.proposal_count = 0;
    state.total_proposals = 0;
    state.total_accepted = 0;
    state.total_rejected = 0;
    state.total_expired = 0;
    state.byzantine_flags = 0;
    state.quorum_achieved = 0;
    state.last_proposal_id = 0;
    state.last_accepted_type = 0;
    state.last_accepted_value = 0;
    state.escalation_triggered = 0;
    state.escalation_reason = 0;

    // Zero-init proposal buffer
    const proposals = getProposalBuffer();
    var i: usize = 0;
    while (i < types.MAX_PROPOSALS) : (i += 1) {
        proposals[i].proposal_id = 0;
        proposals[i].proposal_type = 0;
        proposals[i].status = 0;
        proposals[i].value = 0;
        proposals[i].proposer_module = 0xFF;
        proposals[i].yes_votes = 0;
        proposals[i].no_votes = 0;
        proposals[i].abstain_votes = 0;
        proposals[i].deadline_cycles = 0;
        proposals[i].votes_cast = 0;
    }

    initialized = true;
}

// ============================================================================
// Main Cycle: Evaluate proposals and detect consensus
// ============================================================================

/// Run Consensus cycle - finalize votes and detect byzantine faults
export fn run_consensus_cycle() void {
    if (!initialized) return;

    const state = getConsensusStatePtr();
    cycle_count += 1;
    state.cycle_count = cycle_count;

    state.quorum_achieved = 0; // Reset each cycle

    // Scan all proposals
    const proposals = getProposalBuffer();
    var prop_idx: u16 = 0;
    while (prop_idx < state.proposal_count) : (prop_idx += 1) {
        const proposal = &proposals[prop_idx];

        // Skip if already finalized
        if (proposal.status != @intFromEnum(types.ProposalStatus.Pending)) continue;

        // Check deadline
        if (cycle_count > proposal.deadline_cycles) {
            proposal.status = @intFromEnum(types.ProposalStatus.Expired);
            state.total_expired += 1;
            continue;
        }

        // Check for supermajority YES
        if (proposal.yes_votes >= types.SUPERMAJORITY) {
            proposal.status = @intFromEnum(types.ProposalStatus.Accepted);
            state.total_accepted += 1;
            state.quorum_achieved = 1;
            state.last_accepted_type = proposal.proposal_type;
            state.last_accepted_value = proposal.value;
            continue;
        }

        // Check for majority NO (more than can be overcome)
        if (proposal.no_votes > (types.SUPERMAJORITY - 1)) {
            // Even if all remaining vote yes, we can't reach supermajority
            proposal.status = @intFromEnum(types.ProposalStatus.Rejected);
            state.total_rejected += 1;
            continue;
        }
    }
}

/// Submit a new proposal to the voting queue
export fn submit_proposal(ptype: u8, value: i32, proposer: u8, deadline_offset: u32) u16 {
    if (!initialized) return 0xFFFF;
    if (proposer >= types.MAX_MODULE_COUNT) return 0xFFFF;

    const state = getConsensusStatePtr();

    // Check if queue is full
    if (state.proposal_count >= types.MAX_PROPOSALS) {
        state.escalation_triggered = 1;
        state.escalation_reason = 1; // Proposal queue full
        return 0xFFFF;
    }

    const proposals = getProposalBuffer();
    const idx = state.proposal_head % types.MAX_PROPOSALS;

    // Assign proposal ID
    state.last_proposal_id +%= 1;
    const proposal_id = state.last_proposal_id;

    // Create proposal
    proposals[idx].proposal_id = proposal_id;
    proposals[idx].proposal_type = ptype;
    proposals[idx].status = @intFromEnum(types.ProposalStatus.Pending);
    proposals[idx].value = value;
    proposals[idx].proposer_module = proposer;
    proposals[idx].yes_votes = 0;
    proposals[idx].no_votes = 0;
    proposals[idx].abstain_votes = 0;
    proposals[idx].deadline_cycles = cycle_count + deadline_offset;
    proposals[idx].votes_cast = 0;

    state.proposal_head = (state.proposal_head + 1) % @as(u8, @intCast(types.MAX_PROPOSALS));
    state.proposal_count += 1;
    state.total_proposals += 1;

    return proposal_id;
}

/// Cast a vote on an active proposal
export fn cast_vote(proposal_id: u16, module_id: u8, vote: u8) u8 {
    if (!initialized) return 0;
    if (module_id >= types.MAX_MODULE_COUNT) return 0;
    if (vote > 2) return 0; // 0=No, 1=Yes, 2=Abstain

    const proposals = getProposalBuffer();

    // Find proposal
    const found = false;
    var prop_idx: u16 = 0;
    while (prop_idx < types.MAX_PROPOSALS) : (prop_idx += 1) {
        if (proposals[prop_idx].proposal_id == proposal_id) {
            found = true;

            const proposal = &proposals[prop_idx];

            // Check if module already voted
            const vote_bit = @as(u8, 1) << @as(u3, @intCast(module_id));
            if ((proposal.votes_cast & vote_bit) != 0) {
                return 0; // Already voted
            }

            // Record vote
            proposal.votes_cast |= vote_bit;

            if (vote == 1) {
                proposal.yes_votes += 1;
            } else if (vote == 0) {
                proposal.no_votes += 1;
            } else {
                proposal.abstain_votes += 1;
            }

            // Detect byzantine behavior: if module votes No on 5+ proposals, mark faulty
            if (vote == 0) {
                const state = getConsensusStatePtr();
                // Simple heuristic: track in a separate counter (would need per-module history)
                // For now, escalate if any module has voted No on current proposal
                if (proposal.no_votes >= 3) {
                    // Consensus is unlikely - possible byzantine module
                    state.escalation_triggered = 1;
                    state.escalation_reason = 2; // Byzantine activity detected
                }
            }

            return 1;
        }
    }

    return 0; // Proposal not found
}

/// Get status of a proposal
export fn get_proposal_status(proposal_id: u16) u8 {
    if (!initialized) return 0;

    const proposals = getProposalBuffer();
    var prop_idx: u16 = 0;
    while (prop_idx < types.MAX_PROPOSALS) : (prop_idx += 1) {
        if (proposals[prop_idx].proposal_id == proposal_id) {
            return proposals[prop_idx].status;
        }
    }

    return 0xFF; // Not found
}

// ============================================================================
// Accessors (for dashboard/monitoring)
// ============================================================================

export fn get_cycle_count() u64 {
    return cycle_count;
}

export fn get_total_proposals() u64 {
    const state = getConsensusStatePtr();
    return state.total_proposals;
}

export fn get_total_accepted() u64 {
    const state = getConsensusStatePtr();
    return state.total_accepted;
}

export fn get_total_rejected() u64 {
    const state = getConsensusStatePtr();
    return state.total_rejected;
}

export fn get_total_expired() u64 {
    const state = getConsensusStatePtr();
    return state.total_expired;
}

export fn get_byzantine_flags() u8 {
    const state = getConsensusStatePtr();
    return state.byzantine_flags;
}

export fn get_quorum_achieved() u8 {
    const state = getConsensusStatePtr();
    return state.quorum_achieved;
}

export fn get_last_accepted_type() u8 {
    const state = getConsensusStatePtr();
    return state.last_accepted_type;
}

export fn get_last_accepted_value() i32 {
    const state = getConsensusStatePtr();
    return state.last_accepted_value;
}

export fn get_escalation_triggered() u8 {
    const state = getConsensusStatePtr();
    return state.escalation_triggered;
}

export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}
