// up_types.zig — OmniBus Universal Participant Module
// Phase 57: External miner/validator integration for OMNI rewards

pub const UP_BASE: usize = 0x530000;
pub const MAX_EXTERNAL_NODES: usize = 256;
pub const MAX_PROOF_CACHE: usize = 64;

pub const NetworkType = enum(u8) {
    bitcoin = 0,
    ethereum = 1,
    solana = 2,
    litecoin = 3,
    dogecoin = 4,
    cardano = 5,
    polkadot = 6,
    arbitrum = 7,
    optimism = 8,
};

pub const ParticipantType = enum(u8) {
    pow_miner = 0,      // PoW: Bitcoin, Litecoin, Dogecoin
    pos_validator = 1,  // PoS: Ethereum, Cardano, Polkadot
    solo_node = 2,      // Full node contribution
};

/// External participant identity + proof history
pub const ExternalParticipant = extern struct {
    node_id: u32 = 0,
    network_type: u8 = 0,           // NetworkType enum
    participant_type: u8 = 0,       // ParticipantType enum
    is_active: u8 = 0,
    _pad1: u8 = 0,

    address_hash: u64 = 0,          // FNV hash of participant address
    omni_wallet: u64 = 0,           // OmniBus wallet for rewards

    contribution_score: u32 = 0,    // 0-100000 (scaled)
    last_proof_cycle: u64 = 0,      // When last proof was accepted
    total_proofs_submitted: u32 = 0,
    proofs_accepted: u32 = 0,
    proofs_rejected: u32 = 0,

    cumulative_hashrate: u64 = 0,   // For PoW: hashrate estimate
    cumulative_stake: u64 = 0,      // For PoS: staked amount
    cumulative_blocks: u32 = 0,     // For both: blocks validated
    cumulative_validations: u32 = 0,

    _pad2: [32]u8 = [_]u8{0} ** 32,
};

/// Merged mining proof from external PoW participant
pub const MergedMiningProof = extern struct {
    external_block_header: [80]u8 = [_]u8{0} ** 80,  // Bitcoin-style header
    external_block_hash: [32]u8 = [_]u8{0} ** 32,
    omnibus_nonce: u32 = 0,                           // Nonce in merged block
    difficulty_bits: u32 = 0,
    timestamp: u64 = 0,
    cumulative_difficulty: u64 = 0,
    submitter_id: u32 = 0,
    is_valid: u8 = 0,
    _pad: [3]u8 = [_]u8{0} ** 3,
};

/// Proof-of-Stake evidence from external validator
pub const PoSProof = extern struct {
    validator_pubkey: [64]u8 = [_]u8{0} ** 64,       // Ed25519 or secp256k1
    staked_amount: u64 = 0,                           // Actual staked balance
    blocks_validated: u32 = 0,
    validation_signature: [96]u8 = [_]u8{0} ** 96,   // Signature of stake proof
    timestamp: u64 = 0,
    network_type: u8 = 0,
    is_slash_risk: u8 = 0,                            // 1 if slashing detected
    _pad: [2]u8 = [_]u8{0} ** 2,
};

/// UP Module state header
pub const UPState = extern struct {
    magic: u32 = 0x5550504D,        // "UPPM" (UP Module)
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    participant_count: u32 = 0,     // Total external participants
    active_participants: u32 = 0,

    total_proofs_received: u64 = 0,
    proofs_validated: u64 = 0,
    proofs_rejected: u64 = 0,

    // Reward tracking
    epoch_number: u32 = 0,
    total_omni_distributed: u64 = 0,
    pending_rewards: u64 = 0,

    // Network statistics
    estimated_global_hashrate: u64 = 0,
    estimated_pos_stake: u64 = 0,
    primary_network: u8 = 0,        // Most represented network

    _pad2: [7]u8 = [_]u8{0} ** 7,
    _pad3: [64]u8 = [_]u8{0} ** 64,
};

pub const PARTICIPANTS_BASE: usize = UP_BASE + 0x100;
pub const PROOFS_CACHE_BASE: usize = UP_BASE + 0x8000;
