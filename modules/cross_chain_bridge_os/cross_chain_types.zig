// cross_chain_types.zig — Multi-blockchain settlement & atomic swaps
// L21: Cross-chain bridge coordination
// Memory: 0x3C0000–0x3CFFFF (64KB)

pub const CROSS_CHAIN_BASE: usize = 0x3C0000;
pub const MAX_SWAP_ORDERS: usize = 16;

pub const BlockchainType = enum(u8) {
    Ethereum = 0,
    Solana = 1,
    Bitcoin = 2,
    Polygon = 3,
    Arbitrum = 4,
};

pub const SwapStatus = enum(u8) {
    Pending = 0,
    Initiated = 1,
    LockProven = 2,
    Executed = 3,
    Settled = 4,
    Failed = 5,
};

pub const AtomicSwapOrder = extern struct {
    swap_id: u16,           // 0
    chain_src: u8,          // 2
    chain_dst: u8,          // 3
    status: u8,             // 4
    _pad1: u8 = 0,          // 5
    amount: u64,            // 6  — satoshis/wei
    target_rate: u32,       // 14 — exchange rate (fixed-point)
    lock_hash: u64,         // 18 — HTLC lock hash
    timeout_cycle: u64,     // 26 — expiration
    // = 32 bytes
};

pub const CrossChainState = extern struct {
    magic: u32 = 0x43524F53,        // "CROS"
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,

    swaps_initiated: u32,
    swaps_settled: u32,
    swaps_failed: u32,
    total_volume: u64,

    active_chains: u8,
    swap_head: u8,
    swap_count: u8,
    _pad2: [5]u8 = [_]u8{0} ** 5,

    escalation_triggered: u8,
    escalation_reason: u8,
    _pad5: [72]u8 = [_]u8{0} ** 72,
};
