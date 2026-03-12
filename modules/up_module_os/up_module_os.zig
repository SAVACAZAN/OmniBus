// up_module_os.zig — OmniBus Universal Participant (UP) Module
// Phase 57: Merged mining + PoS bridging + contribution scoring

const types = @import("up_types.zig");

fn getUPStatePtr() *volatile types.UPState {
    return @as(*volatile types.UPState, @ptrFromInt(types.UP_BASE));
}

fn getParticipantPtr(index: u32) *volatile types.ExternalParticipant {
    if (index >= types.MAX_EXTERNAL_NODES) return undefined;
    const addr = types.PARTICIPANTS_BASE + @as(usize, index) * @sizeOf(types.ExternalParticipant);
    return @as(*volatile types.ExternalParticipant, @ptrFromInt(addr));
}

fn getMiningProofPtr(index: u32) *volatile types.MergedMiningProof {
    if (index >= types.MAX_PROOF_CACHE) return undefined;
    const addr = types.PROOFS_CACHE_BASE + @as(usize, index) * @sizeOf(types.MergedMiningProof);
    return @as(*volatile types.MergedMiningProof, @ptrFromInt(addr));
}

pub export fn init_plugin() void {
    const state = getUPStatePtr();
    state.magic = 0x5550504D;
    state.flags = 0;
    state.cycle_count = 0;
    state.participant_count = 0;
    state.active_participants = 0;
    state.total_proofs_received = 0;
    state.proofs_validated = 0;
    state.proofs_rejected = 0;
    state.epoch_number = 0;
    state.total_omni_distributed = 0;
    state.pending_rewards = 0;
    state.estimated_global_hashrate = 0;
    state.estimated_pos_stake = 0;
    state.primary_network = 0;
}

pub export fn run_up_cycle() void {
    const state = getUPStatePtr();
    state.cycle_count +|= 1;
}

/// Register external participant (miner or validator)
pub export fn up_register_participant(
    network_type: u8,
    participant_type: u8,
    address_hash: u64,
    omni_wallet: u64,
) u32 {
    const state = getUPStatePtr();

    if (state.participant_count >= types.MAX_EXTERNAL_NODES) return 0xFFFFFFFF;

    const idx = state.participant_count;
    const node = getParticipantPtr(idx);

    node.node_id = idx;
    node.network_type = network_type;
    node.participant_type = participant_type;
    node.is_active = 1;
    node.address_hash = address_hash;
    node.omni_wallet = omni_wallet;
    node.contribution_score = 1000;  // Start with base score
    node.last_proof_cycle = state.cycle_count;
    node.total_proofs_submitted = 0;
    node.proofs_accepted = 0;
    node.proofs_rejected = 0;

    state.participant_count +|= 1;
    state.active_participants +|= 1;

    return idx;
}

/// Submit merged mining proof from PoW participant
pub export fn up_submit_mining_proof(
    participant_id: u32,
    block_hash: [*]const u8,
    difficulty_bits: u32,
    cumulative_difficulty: u64,
) u8 {
    const state = getUPStatePtr();

    if (participant_id >= state.participant_count) return 0;

    const node = getParticipantPtr(participant_id);
    if (node.participant_type != @intFromEnum(types.ParticipantType.pow_miner)) return 0;

    // Find empty proof slot
    var proof_idx: u32 = 0;
    while (proof_idx < types.MAX_PROOF_CACHE) : (proof_idx += 1) {
        const proof = getMiningProofPtr(proof_idx);
        if (proof.submitter_id == 0) {
            // Store proof
            var i: u8 = 0;
            while (i < 32) : (i += 1) {
                proof.external_block_hash[i] = block_hash[i];
            }

            proof.difficulty_bits = difficulty_bits;
            proof.cumulative_difficulty = cumulative_difficulty;
            proof.timestamp = state.cycle_count;
            proof.submitter_id = participant_id;
            proof.is_valid = 1;

            // Update participant stats
            node.total_proofs_submitted +|= 1;
            node.proofs_accepted +|= 1;
            node.cumulative_hashrate +|= 1;
            node.last_proof_cycle = state.cycle_count;

            state.total_proofs_received +|= 1;
            state.proofs_validated +|= 1;

            return 1;
        }
    }

    return 0;  // No space in proof cache
}

/// Submit PoS validator proof from external chain
pub export fn up_submit_pos_proof(
    participant_id: u32,
    staked_amount: u64,
    blocks_validated: u32,
) u8 {
    const state = getUPStatePtr();

    if (participant_id >= state.participant_count) return 0;

    const node = getParticipantPtr(participant_id);
    if (node.participant_type != @intFromEnum(types.ParticipantType.pos_validator)) return 0;

    // Validate proof (stub)
    node.total_proofs_submitted +|= 1;
    node.proofs_accepted +|= 1;
    node.cumulative_stake +|= staked_amount;
    node.cumulative_blocks +|= blocks_validated;
    node.last_proof_cycle = state.cycle_count;

    state.total_proofs_received +|= 1;
    state.proofs_validated +|= 1;

    return 1;
}

/// Calculate contribution score for participant
pub export fn up_calculate_score(participant_id: u32) u32 {
    const state = getUPStatePtr();

    if (participant_id >= state.participant_count) return 0;

    const node = getParticipantPtr(participant_id);
    if (node.is_active == 0) return 0;

    var score: u32 = 1000;  // Base score

    // Add hashrate contribution (PoW)
    if (node.cumulative_hashrate > 0) {
        const hashrate_bonus = @as(u32, @intCast(@min(node.cumulative_hashrate, 10000)));
        score +|= hashrate_bonus;
    }

    // Add stake contribution (PoS)
    if (node.cumulative_stake > 0) {
        const stake_bonus = @as(u32, @intCast(@min(node.cumulative_stake >> 32, 10000)));
        score +|= stake_bonus;
    }

    // Add validation count
    const validation_bonus = @as(u32, @intCast(@min(node.cumulative_blocks, 5000)));
    score +|= validation_bonus;

    node.contribution_score = @min(score, 100000);

    return node.contribution_score;
}

/// Distribute epoch rewards to active participants
pub export fn up_distribute_rewards(epoch_omni_allocation: u64) u32 {
    const state = getUPStatePtr();

    if (state.participant_count == 0) return 0;

    var total_score: u64 = 0;
    var i: u32 = 0;

    // Calculate total score across all participants
    while (i < state.participant_count) : (i += 1) {
        const node = getParticipantPtr(i);
        if (node.is_active == 1) {
            total_score +|= up_calculate_score(i);
        }
    }

    if (total_score == 0) return 0;

    // Allocate rewards proportionally
    var distributed: u32 = 0;
    i = 0;
    while (i < state.participant_count) : (i += 1) {
        const node = getParticipantPtr(i);
        if (node.is_active == 1) {
            const participant_score = up_calculate_score(i);
            _ = (epoch_omni_allocation * participant_score) / total_score;  // Reward calculated (stub)
            node.cumulative_validations +|= 1;
            distributed +|= 1;
        }
    }

    state.total_omni_distributed +|= epoch_omni_allocation;
    state.epoch_number +|= 1;

    return distributed;
}

/// Get participant info
pub export fn up_get_participant_score(participant_id: u32) u32 {
    if (participant_id >= types.MAX_EXTERNAL_NODES) return 0;
    const node = getParticipantPtr(participant_id);
    return node.contribution_score;
}

/// Get total active participants
pub export fn up_get_active_count() u32 {
    return getUPStatePtr().active_participants;
}

/// Get estimated global hashrate
pub export fn up_get_estimated_hashrate() u64 {
    return getUPStatePtr().estimated_global_hashrate;
}

// ============================================================================
// IPC Dispatcher
// ============================================================================

pub export fn ipc_dispatch() u64 {
    const ipc_req = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    const state = getUPStatePtr();
    if (state.magic != 0x5550504D) {
        init_plugin();
    }

    const request = ipc_req.*;
    var result: u64 = 0;

    switch (request) {
        0x61 => {  // UP_REGISTER_PARTICIPANT
            const network_type = @as(u8, @intCast(ipc_result.* & 0xFF));
            const participant_type = @as(u8, @intCast((ipc_result.* >> 8) & 0xFF));
            const address_hash = ipc_result.* >> 16;
            result = up_register_participant(network_type, participant_type, address_hash, 0);
        },
        0x62 => {  // UP_SUBMIT_MINING_PROOF
            const participant_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            const difficulty = @as(u32, @intCast((ipc_result.* >> 32) & 0xFFFFFFFF));
            result = up_submit_mining_proof(participant_id, @as([*]const u8, @ptrFromInt(0x100160)), difficulty, 1000);
        },
        0x63 => {  // UP_SUBMIT_POS_PROOF
            const participant_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            const stake_amount = ipc_result.* >> 32;
            result = up_submit_pos_proof(participant_id, stake_amount, 1);
        },
        0x64 => {  // UP_CALCULATE_SCORE
            const participant_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            result = up_calculate_score(participant_id);
        },
        0x65 => {  // UP_DISTRIBUTE_REWARDS
            const allocation = ipc_result.*;
            result = up_distribute_rewards(allocation);
        },
        0x66 => {  // UP_GET_ACTIVE_COUNT
            result = up_get_active_count();
        },
        0x67 => {  // UP_GET_ESTIMATED_HASHRATE
            result = up_get_estimated_hashrate();
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
}
