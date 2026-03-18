pub const ROLLUP_BASE: usize = 0x470000;

pub const RollupTransaction = extern struct {
    tx_id: u32,
    amount: u64,
    proof_type: u8,
    status: u8,
    _pad: [6]u8 = [_]u8{0} ** 6,
};

pub const L2RollupBridgeState = extern struct {
    magic: u32 = 0x524F4C4C,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    transactions_bridged: u32,
    total_volume: u64,
    optimistic_proofs: u32,
    zk_proofs: u32,
    pending_finality: u32,
    _pad2: [72]u8 = [_]u8{0} ** 72,
};
