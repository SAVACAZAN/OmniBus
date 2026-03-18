pub const QUANTUM_BASE: usize = 0x480000;

pub const QuantumKey = extern struct {
    key_id: u32,
    key_type: u8,
    algorithm: u8,
    strength_bits: u16,
    _pad: u32 = 0,
};

pub const QuantumResistantCryptoState = extern struct {
    magic: u32 = 0x514E5543,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    keys_generated: u32,
    signatures_verified: u32,
    hybrid_proofs: u32,
    post_quantum_ops: u32,
    _pad2: [72]u8 = [_]u8{0} ** 72,
};
