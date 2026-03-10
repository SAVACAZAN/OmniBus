// PQC-GATE: Post-Quantum Cryptography Gateway (L1 + distributed)
// NIST Standards: ML-DSA (Dilithium), SLH-DSA (SPHINCS+), FN-DSA (Falcon)

pub const PQC_VAULT_BASE: usize = 0x100800;
pub const PQC_STATE_BASE: usize = 0x490000;

// Algorithm IDs (NIST official)
pub const PQC_ALGO = enum(u8) {
    ML_DSA_44 = 0,        // CRYSTALS-Dilithium (standard)
    ML_DSA_65 = 1,        // Dilithium (high security)
    ML_DSA_87 = 2,        // Dilithium (paranoid)
    SLH_DSA_SHA2_128S = 3,  // SPHINCS+ compact
    SLH_DSA_SHA2_256F = 4,  // SPHINCS+ fast
    FN_DSA_512 = 5,       // Falcon compact
    FN_DSA_1024 = 6,      // Falcon full
};

pub const PublicKeyVault = extern struct {
    module_id: u16,
    algo: u8,
    key_size: u8,
    key_hash: u64,
    created_cycle: u64,
    _pad: [8]u8 = [_]u8{0} ** 8,
};

pub const PQCGateState = extern struct {
    magic: u32 = 0x50514343,           // "PQCC"
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,

    // Signature verification stats
    dilithium_verifies: u32,
    falcon_verifies: u32,
    sphincs_verifies: u32,
    verification_failures: u32,

    // Module authentication
    modules_authenticated: u16,
    modules_rejected: u16,

    // Key management
    keys_stored: u16,
    key_rotation_cycle: u64,

    _pad2: [56]u8 = [_]u8{0} ** 56,
};

// Signature structures (compact)
pub const Signature = extern struct {
    algo: u8,
    _pad: [3]u8 = [_]u8{0} ** 3,
    sig_bytes: u32,
    sig_data: [2400]u8,  // Max sig size (SPHINCS+ ~8KB, but we store hash)
};
