// types.zig — BlockchainOS type definitions

// ============================================================================
// Memory Layout
// ============================================================================

pub const BLOCKCHAIN_BASE: usize = 0x250000;
pub const KERNEL_AUTH: usize = 0x100050;

// Offsets within blockchain memory
pub const BLOCKCHAIN_STATE_OFFSET: usize = 0;
pub const FLASH_LOAN_OFFSET: usize = 64;

// Capacity limits
pub const MAX_FLASH_LOANS: u32 = 16;
pub const MAX_SWAP_ROUTES: u32 = 64;

// ============================================================================
// BlockchainState — Module Header
// ============================================================================

pub const BlockchainState = struct {
    magic: u32,                    // 0x424C4B4F = "BLKO"
    flags: u32,                    // Active flag + settings
    cycle_count: u64,              // Cycles processed
    flash_loan_count: u32,         // Total flash loans issued
    swap_count: u32,               // Total swaps executed
    tsc_last_update: u64,          // Last TSC timestamp
    _reserved: [44]u8 = undefined, // Padding to 128 bytes
};

// ============================================================================
// FlashLoanRequest — Raydium Flash Loan Specification
// ============================================================================

pub const FlashLoanRequest = struct {
    status: u8,                        // 0=idle, 1=pending, 2=processing, 3=done
    _pad: u8 = 0,
    _pad2: u16 = 0,
    amount_lamports: u64,              // Loan amount in lamports
    input_mint: [32]u8,                // Input token mint address
    output_mint: [32]u8,               // Output token mint address
    _reserved: [96]u8 = undefined,     // Padding to 160 bytes
};

// ============================================================================
// SolanaTransaction — Transaction structure for Solana RPC
// ============================================================================

pub const SolanaTransaction = struct {
    version: u32,                      // Transaction version
    recent_blockhash: [32]u8,          // Blockhash for transaction
    instruction_count: u32,            // Number of instructions
    instructions: [16]SolanaInstruction, // Max 16 instructions per tx
    signatures: [64]u8,                // Transaction signatures
};

pub const SolanaInstruction = struct {
    program_id: [32]u8,                // Program ID (e.g., Raydium)
    account_count: u32,                // Number of accounts referenced
    data_len: u32,                     // Length of instruction data
    data: [256]u8,                     // Instruction data payload
};

// ============================================================================
// SwapRoute — Settlement path for atomic swaps
// ============================================================================

pub const SwapRoute = struct {
    route_id: u32,
    hop_count: u32,                    // Number of hops (DEX swaps)
    input_mint: [32]u8,
    output_mint: [32]u8,
    input_amount: u64,
    expected_output: u64,
    min_output: u64,                   // Slippage protection
};

// ============================================================================
// EGLDStakingOrder — EGLD staking settlement
// ============================================================================

pub const EGLDStakingOrder = struct {
    stake_id: u32,
    amount_egld: u64,
    validator_address: [32]u8,
    apy_percentage: u16,               // APY as fixed-point 16.16
    lock_duration: u32,                // Seconds
};
