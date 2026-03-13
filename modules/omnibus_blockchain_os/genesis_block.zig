// ============================================================================
// Genesis Block (Zig/Bare Metal)
// Initial blockchain state and OMNI distribution
// ============================================================================

const std = @import("std");

// Genesis configuration (hardcoded at blockchain creation)
pub const GenesisConfig = struct {
    // Network parameters
    network_id: u32 = 506,                    // OmniBus chain ID
    version: u32 = 2,                         // Blockchain version
    timestamp: u64 = 0,                       // Block timestamp

    // Initial supply allocation
    // Total: 21 million OMNI
    dao_treasury: u64 = 4_200_000 * 1e18,     // 20% → DAO (4.2M)
    foundation: u64 = 2_100_000 * 1e18,       // 10% → Foundation (2.1M)
    ecosystem: u64 = 4_200_000 * 1e18,        // 20% → Ecosystem (4.2M)
    community: u64 = 5_250_000 * 1e18,        // 25% → Community (5.25M)
    mining_rewards: u64 = 5_250_000 * 1e18,   // 25% → Block rewards (5.25M)

    // Reserve
    strategic_reserve: u64 = 0,                // Reserved for future
};

pub const GENESIS = GenesisConfig{
    .timestamp = 0x1234567890ABCDEF,
};

// Genesis addresses (hardcoded)
pub const GENESIS_ADDRESSES = struct {
    // Treasury multisig
    const DAO_TREASURY: u64 = 0x0000_0000_0000_0001;

    // Foundation addresses
    const FOUNDATION_1: u64 = 0x0000_0000_0000_0002;
    const FOUNDATION_2: u64 = 0x0000_0000_0000_0003;
    const FOUNDATION_3: u64 = 0x0000_0000_0000_0004;

    // Ecosystem grants
    const ECOSYSTEM_GRANTS: u64 = 0x0000_0000_0000_0005;

    // Community addresses
    const COMMUNITY_POOL: u64 = 0x0000_0000_0000_0006;
    const STAKING_REWARDS: u64 = 0x0000_0000_0000_0007;

    // Mining pool
    const MINING_POOL: u64 = 0x0000_0000_0000_0008;
};

/// Initialize blockchain with genesis distribution
pub fn init_genesis_block() void {
    // Genesis timestamp
    const genesis_time = GENESIS.timestamp;

    // Initialize OMNI token system
    // omni_token_os.init_genesis(genesis_time, 8);

    // Create genesis UTXOs for each allocation
    // This is called during blockchain initialization, before block 0

    // DAO Treasury: 20% (4.2M OMNI)
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.DAO_TREASURY, GENESIS.dao_treasury);

    // Foundation: 10% (2.1M OMNI)
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.FOUNDATION_1, GENESIS.foundation / 3);
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.FOUNDATION_2, GENESIS.foundation / 3);
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.FOUNDATION_3, GENESIS.foundation - (GENESIS.foundation / 3) * 2);

    // Ecosystem grants: 20% (4.2M OMNI)
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.ECOSYSTEM_GRANTS, GENESIS.ecosystem);

    // Community pool: 25% (5.25M OMNI)
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.COMMUNITY_POOL, GENESIS.community);

    // Mining rewards: 25% (5.25M OMNI) - will be distributed via block rewards
    // _ = omni_token_os.create_genesis_utxo(GENESIS_ADDRESSES.MINING_POOL, GENESIS.mining_rewards);
}

/// Get genesis distribution info
pub fn get_genesis_info() struct {
    dao: u64,
    foundation: u64,
    ecosystem: u64,
    community: u64,
    mining: u64,
    total: u64,
} {
    return .{
        .dao = GENESIS.dao_treasury,
        .foundation = GENESIS.foundation,
        .ecosystem = GENESIS.ecosystem,
        .community = GENESIS.community,
        .mining = GENESIS.mining_rewards,
        .total = GENESIS.dao_treasury + GENESIS.foundation + GENESIS.ecosystem + GENESIS.community + GENESIS.mining_rewards,
    };
}

/// Get allocation percentages
pub fn get_allocation_percentages() struct {
    dao: u8,
    foundation: u8,
    ecosystem: u8,
    community: u8,
    mining: u8,
} {
    return .{
        .dao = 20,
        .foundation = 10,
        .ecosystem = 20,
        .community = 25,
        .mining = 25,
    };
}

/// Format: Display genesis distribution
pub fn print_genesis_allocation() void {
    _ = "
    ═══════════════════════════════════════════════
    OMNIBUS GENESIS BLOCK - OMNI DISTRIBUTION
    ═══════════════════════════════════════════════

    Total Supply: 21 million OMNI (fixed)

    Allocation:
      DAO Treasury:     4.2M OMNI (20%)
        Address: 0x0000000000000001
        Purpose: Governance, treasury

      Foundation:       2.1M OMNI (10%)
        Addresses: 3x 0.7M (multisig)
        Purpose: Development, grants

      Ecosystem Grants: 4.2M OMNI (20%)
        Address: 0x0000000000000005
        Purpose: Partners, ecosystem growth

      Community Pool:   5.25M OMNI (25%)
        Address: 0x0000000000000006
        Purpose: Staking, farming, rewards

      Mining Rewards:   5.25M OMNI (25%)
        Address: 0x0000000000000008
        Released via block rewards (halving every 210k blocks)

    ═══════════════════════════════════════════════
    ";
}

// ============================================================================
// Block Structure (fits in transaction)
// ============================================================================

pub const BlockHeader = struct {
    // Block metadata (32 bytes)
    version: u32,                     // Protocol version
    previous_block_hash: [32]u8,     // SHA256 hash of previous block
    merkle_root: [32]u8,              // Merkle tree root of transactions
    timestamp: u64,                   // Block creation time
    block_height: u32,                // Block number (0 = genesis)
    target_difficulty: u32,           // Mining target

    // Mining (32 bytes)
    nonce: u32,                       // Mining nonce
    miner_address: u64,               // Miner reward address
    block_reward: u64,                // Reward for this block
    total_fees: u64,                  // Sum of transaction fees

    // Block state (16 bytes)
    transaction_count: u16,           // Number of transactions
    utxo_count: u32,                  // UTXOs created
    reserved: [6]u8,
};

pub const BlockFooter = struct {
    // Finalization
    merkle_proof: [32]u8,             // Merkle proof
    validator_signature: [64]u8,      // Validator signature
    consensus_data: [32]u8,           // Consensus algorithm data (PoW nonce)
};

/// Block contains:
/// 1. Header (80 bytes)
/// 2. Transactions (variable)
/// 3. OMNI state root (32 bytes SHA256)
/// 4. Footer (128 bytes)
pub const MAX_BLOCK_SIZE: usize = 65536; // 64KB max block

pub fn calculate_block_hash(header: *const BlockHeader) [32]u8 {
    // TODO: SHA256(header)
    _ = header;
    var result: [32]u8 = .{0} ** 32;
    return result;
}

pub fn verify_block_hash(header: *const BlockHeader, expected_hash: *const [32]u8) bool {
    const calculated = calculate_block_hash(header);
    for (0..32) |i| {
        if (calculated[i] != expected_hash[i]) {
            return false;
        }
    }
    return true;
}
