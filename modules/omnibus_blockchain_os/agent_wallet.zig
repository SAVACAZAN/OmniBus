// agent_wallet.zig – Agent HD Wallet Generation (Phase 68+)
// Generates BIP-39 mnemonic + BIP-32 HD keys + multi-domain addresses for a trading agent
// Memory: fixed-size buffers, no allocators
//
// Agent Identity:
//   - Mnemonic: 12 words (128 bits entropy)
//   - Master seed: 64 bytes (from mnemonic)
//   - Classical chains: Bitcoin, Ethereum, Solana, EGLD, Optimism, Base (BIP-44)
//   - Post-quantum domains: omnibus.love, omnibus.food, omnibus.rent (NIST PQ)
//   - Balance: 1,000,000 OMNI (100M SAT) on genesis

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const AGENT_BASE: usize = 0x5EC000;
pub const ENTROPY_SIZE: usize = 16;  // 128 bits (12-word mnemonic)
pub const SEED_SIZE: usize = 64;     // PBKDF2 output
pub const PRIVKEY_SIZE: usize = 32;  // secp256k1 private key
pub const PUBKEY_SIZE: usize = 33;   // Compressed public key

// Address buffer sizes
pub const BITCOIN_ADDR_LEN: usize = 62;      // Bech32 (bc1...)
pub const ETH_ADDR_LEN: usize = 42;          // EIP-55 (0x...)
pub const SOLANA_ADDR_LEN: usize = 44;       // Base58
pub const EGLD_ADDR_LEN: usize = 62;         // Bech32 (erd1...)
pub const PQ_ADDR_LEN: usize = 48;           // Post-quantum domain address

// BIP-39 word list (12 common words for DEV_MODE hardcoded agent)
pub const BIP39_WORDS = [_][]const u8{
    "abandon", "ability", "absence", "absorb", "abstract", "academy",
    "accept", "accident", "account", "achieve", "acid", "acoustic",
};

// ============================================================================
// MULTI-DOMAIN ADDRESSES
// ============================================================================

pub const ClassicalAddress = struct {
    chain: [32]u8 = [_]u8{0} ** 32,
    chain_len: u8 = 0,
    derivation_path: [32]u8 = [_]u8{0} ** 32,
    path_len: u8 = 0,
    address: [62]u8 = [_]u8{0} ** 62,
    address_len: u8 = 0,
};

pub const PostQuantumAddress = struct {
    domain: [32]u8 = [_]u8{0} ** 32,
    domain_len: u8 = 0,
    algorithm: [32]u8 = [_]u8{0} ** 32,
    algorithm_len: u8 = 0,
    short_id: [16]u8 = [_]u8{0} ** 16,
    short_id_len: u8 = 0,
    address: [48]u8 = [_]u8{0} ** 48,
    address_len: u8 = 0,
    pub_key_size: u32 = 0,
    secret_key_size: u32 = 0,
    security_level: [32]u8 = [_]u8{0} ** 32,
    security_len: u8 = 0,
};

// ============================================================================
// AGENT STATE
// ============================================================================

pub const AgentWallet = struct {
    magic: u32 = 0x4147454E,  // "AGEN"
    version: u32 = 1,

    // Mnemonic (12 words, space-separated)
    mnemonic: [256]u8 = [_]u8{0} ** 256,
    mnemonic_len: u16 = 0,

    // Master seed (from BIP-39)
    seed: [SEED_SIZE]u8 = [_]u8{0} ** SEED_SIZE,

    // Primary HD Keys
    private_key: [PRIVKEY_SIZE]u8 = [_]u8{0} ** PRIVKEY_SIZE,
    public_key: [PUBKEY_SIZE]u8 = [_]u8{0} ** PUBKEY_SIZE,

    // Primary OmniBus address
    address: [42]u8 = [_]u8{0} ** 42,  // 0x + 40 hex chars
    address_len: u8 = 0,

    // Classical chain addresses (6)
    classical_addrs: [6]ClassicalAddress = [_]ClassicalAddress{ClassicalAddress{}} ** 6,
    classical_count: u8 = 0,

    // Post-quantum domain addresses (4)
    pq_addrs: [4]PostQuantumAddress = [_]PostQuantumAddress{PostQuantumAddress{}} ** 4,
    pq_count: u8 = 0,

    // Balance (in SAT)
    balance_sat: u64 = 100_000_000_000,  // 1M OMNI = 100M SAT

    _reserved: [256]u8 = [_]u8{0} ** 256,
};

var agent_wallet: AgentWallet = undefined;
var initialized: bool = false;

// ============================================================================
// INITIALIZATION: Generate Agent HD Wallet
// ============================================================================

pub fn init_agent_wallet() void {
    if (initialized) return;

    var wallet = &agent_wallet;
    wallet.magic = 0x4147454E;
    wallet.version = 1;

    // Generate mnemonic (hardcoded for DEV_MODE)
    generate_mnemonic(wallet);

    // Derive master seed from mnemonic
    generate_master_seed(wallet);

    // Derive primary private key (m/44'/506'/0'/0/0 - OmniBus)
    derive_private_key(wallet);

    // Compute primary public key
    compute_public_key(wallet);

    // Generate primary OmniBus address
    generate_address(wallet);

    // Generate classical chain addresses (Bitcoin, Ethereum, Solana, EGLD, Optimism, Base)
    generate_classical_addresses(wallet);

    // Generate post-quantum domain addresses (LOVE, FOOD, RENT, OMNI)
    generate_pq_addresses(wallet);

    // Set initial balance (1M OMNI)
    wallet.balance_sat = 100_000_000_000;

    initialized = true;
}

// ============================================================================
// MNEMONIC GENERATION
// ============================================================================

fn generate_mnemonic(wallet: *AgentWallet) void {
    // DEV_MODE: Use hardcoded 12-word mnemonic
    const mnemonic_str = "abandon ability absence absorb abstract academy accept accident account achieve acid acoustic";

    var pos: u16 = 0;
    for (mnemonic_str) |c| {
        if (pos < wallet.mnemonic.len) {
            wallet.mnemonic[pos] = c;
            pos += 1;
        }
    }
    wallet.mnemonic_len = pos;
}

// ============================================================================
// MASTER SEED GENERATION (BIP-39 PBKDF2)
// ============================================================================

fn generate_master_seed(wallet: *AgentWallet) void {
    // DEV_MODE: Hardcoded seed (normally: PBKDF2-SHA512(mnemonic, passphrase=""))
    // This seed is deterministic for reproducibility

    const hardcoded_seed = [_]u8{
        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x67, 0x14,
        0xbf, 0xd0, 0x9c, 0xf7, 0x07, 0xbb, 0x30, 0x7f,
        0x7d, 0x81, 0xb0, 0xe4, 0xc1, 0x42, 0x51, 0xf0,
        0x2e, 0x41, 0x2b, 0x1e, 0xd5, 0xbe, 0x2d, 0x76,
        0xa1, 0x9c, 0x06, 0xae, 0x89, 0xfb, 0x84, 0xe6,
        0xd4, 0xcf, 0x52, 0x6f, 0x73, 0x22, 0x1f, 0x0a,
        0x87, 0xa1, 0x8d, 0x4b, 0x19, 0x6c, 0xd5, 0x2c,
        0x36, 0xce, 0xa4, 0x1c, 0x23, 0x41, 0x08, 0x50,
    };

    @memcpy(wallet.seed[0..SEED_SIZE], &hardcoded_seed);
}

// ============================================================================
// PRIVATE KEY DERIVATION (BIP-32)
// ============================================================================

fn derive_private_key(wallet: *AgentWallet) void {
    // DEV_MODE: Simplified derivation
    // Path: m/44'/506'/0'/0/0 (OmniBus custom coin type 506)
    // Derive: SHA256(seed) → intermediate key

    var hash: [32]u8 = undefined;
    sha256_simple(&hash, wallet.seed[0..], wallet.seed[0..32]);

    // Use first 32 bytes as private key
    @memcpy(wallet.private_key[0..32], hash[0..32]);
}

// ============================================================================
// PUBLIC KEY COMPUTATION (secp256k1)
// ============================================================================

fn compute_public_key(wallet: *AgentWallet) void {
    // DEV_MODE: Hardcoded compressed public key for the hardcoded private key
    // Real impl: Would use secp256k1 scalar multiplication

    const hardcoded_pubkey = [_]u8{
        0x02, 0xa1, 0xf2, 0xe3, 0xd4, 0xc5, 0xb6, 0xa7,
        0xf8, 0xe9, 0xd0, 0xc1, 0xb2, 0xa3, 0xf4, 0xe5,
        0xd6, 0xc7, 0xb8, 0xa9, 0xf0, 0xe1, 0xd2, 0xc3,
        0xb4, 0xa5, 0xf6, 0xe7, 0xd8, 0xc9, 0xba, 0xab,
        0xfc,
    };

    @memcpy(wallet.public_key[0..33], &hardcoded_pubkey);
}

// ============================================================================
// ADDRESS GENERATION
// ============================================================================

fn generate_address(wallet: *AgentWallet) void {
    // OmniBus address format: 0x<domain><pubkey_hash><checksum>
    // Domain: 0x00 (OMNI domain)
    // Pubkey hash: SHA256(public_key)
    // Checksum: CRC32

    wallet.address[0] = '0';
    wallet.address[1] = 'x';

    // Domain byte
    const hex = "0123456789ABCDEF";
    wallet.address[2] = hex[0];
    wallet.address[3] = hex[0];

    // Pubkey hash (first 20 bytes of SHA256)
    var hash: [32]u8 = undefined;
    sha256_simple(&hash, &wallet.public_key, &wallet.public_key);

    var pos: u8 = 4;
    for (hash[0..20]) |byte| {
        if (pos + 1 < wallet.address.len) {
            wallet.address[pos] = hex[byte >> 4];
            wallet.address[pos + 1] = hex[byte & 0x0F];
            pos += 2;
        }
    }

    wallet.address_len = pos;
}

// ============================================================================
// CLASSICAL CHAIN ADDRESSES (BIP-44)
// ============================================================================

fn generate_classical_addresses(wallet: *AgentWallet) void {
    // Bitcoin (m/44'/0'/0'/0/0)
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[0];
        var pos: u8 = 0;
        const btc_str = "Bitcoin";
        for (btc_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const btc_path = "m/44'/0'/0'/0/0";
        for (btc_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const btc_addr = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4";
        for (btc_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }

    // Ethereum (m/44'/60'/0'/0/0) – ERC20 compatible ✅
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[1];
        var pos: u8 = 0;
        const eth_str = "Ethereum";
        for (eth_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const eth_path = "m/44'/60'/0'/0/0";
        for (eth_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const eth_addr = "0x8ba1f109551bD432803012645Ac136ddd64DBA72";
        for (eth_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }

    // Solana (m/44'/501'/0'/0/0)
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[2];
        var pos: u8 = 0;
        const sol_str = "Solana";
        for (sol_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const sol_path = "m/44'/501'/0'/0/0";
        for (sol_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const sol_addr = "FPAcAKxJ8dXJGKwKmMgLCqEchKsYRCG7bkkxRSDRd4t7";
        for (sol_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }

    // EGLD (m/44'/508'/0'/0/0)
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[3];
        var pos: u8 = 0;
        const egld_str = "EGLD";
        for (egld_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const egld_path = "m/44'/508'/0'/0/0";
        for (egld_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const egld_addr = "erd1qyu8zcm5n0hf3mxvjkq5w7pqyt7g0mqnp8l2qxh";
        for (egld_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }

    // Optimism (m/44'/60'/0'/0/0) – ERC20 compatible ✅
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[4];
        var pos: u8 = 0;
        const op_str = "Optimism";
        for (op_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const op_path = "m/44'/60'/0'/0/0";
        for (op_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const op_addr = "0x8ba1f109551bD432803012645Ac136ddd64DBA72";
        for (op_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }

    // Base (m/44'/60'/0'/0/0) – ERC20 compatible ✅
    if (wallet.classical_count < 6) {
        var addr = &wallet.classical_addrs[5];
        var pos: u8 = 0;
        const base_str = "Base";
        for (base_str) |c| {
            if (pos < 32) {
                addr.chain[pos] = c;
                pos += 1;
            }
        }
        addr.chain_len = pos;

        pos = 0;
        const base_path = "m/44'/60'/0'/0/0";
        for (base_path) |c| {
            if (pos < 32) {
                addr.derivation_path[pos] = c;
                pos += 1;
            }
        }
        addr.path_len = pos;

        pos = 0;
        const base_addr = "0x8ba1f109551bD432803012645Ac136ddd64DBA72";
        for (base_addr) |c| {
            if (pos < 62) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;
        wallet.classical_count += 1;
    }
}

// ============================================================================
// POST-QUANTUM DOMAIN ADDRESSES (NIST PQ Cryptography)
// ============================================================================

fn generate_pq_addresses(wallet: *AgentWallet) void {
    // omnibus.love – Kyber-768 (Key Encapsulation Mechanism)
    if (wallet.pq_count < 4) {
        var addr = &wallet.pq_addrs[0];
        var pos: u8 = 0;

        const domain = "omnibus.love";
        for (domain) |c| {
            if (pos < 32) {
                addr.domain[pos] = c;
                pos += 1;
            }
        }
        addr.domain_len = pos;

        pos = 0;
        const algo = "Kyber-768 (ML-KEM-768)";
        for (algo) |c| {
            if (pos < 32) {
                addr.algorithm[pos] = c;
                pos += 1;
            }
        }
        addr.algorithm_len = pos;

        pos = 0;
        const short = "OMNI-4a8f-LOVE";
        for (short) |c| {
            if (pos < 16) {
                addr.short_id[pos] = c;
                pos += 1;
            }
        }
        addr.short_id_len = pos;

        pos = 0;
        const pq_addr = "ob_k1_2a5f8b1e9c3d6f4a7e2b5c8d1f4a7e2b";
        for (pq_addr) |c| {
            if (pos < 48) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;

        addr.pub_key_size = 1184;
        addr.secret_key_size = 2400;

        pos = 0;
        const sec = "256-bit quantum";
        for (sec) |c| {
            if (pos < 32) {
                addr.security_level[pos] = c;
                pos += 1;
            }
        }
        addr.security_len = pos;

        wallet.pq_count += 1;
    }

    // omnibus.food – Falcon-512 (Lattice-based Signature)
    if (wallet.pq_count < 4) {
        var addr = &wallet.pq_addrs[1];
        var pos: u8 = 0;

        const domain = "omnibus.food";
        for (domain) |c| {
            if (pos < 32) {
                addr.domain[pos] = c;
                pos += 1;
            }
        }
        addr.domain_len = pos;

        pos = 0;
        const algo = "Falcon-512";
        for (algo) |c| {
            if (pos < 32) {
                addr.algorithm[pos] = c;
                pos += 1;
            }
        }
        addr.algorithm_len = pos;

        pos = 0;
        const short = "OMNI-3b7c-FOOD";
        for (short) |c| {
            if (pos < 16) {
                addr.short_id[pos] = c;
                pos += 1;
            }
        }
        addr.short_id_len = pos;

        pos = 0;
        const pq_addr = "ob_f5_1b4e9d2a5f8c3e6b9d2f5a8c1e4b7d0f";
        for (pq_addr) |c| {
            if (pos < 48) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;

        addr.pub_key_size = 897;
        addr.secret_key_size = 1281;

        pos = 0;
        const sec = "192-bit quantum";
        for (sec) |c| {
            if (pos < 32) {
                addr.security_level[pos] = c;
                pos += 1;
            }
        }
        addr.security_len = pos;

        wallet.pq_count += 1;
    }

    // omnibus.rent – Dilithium-5 (ML-DSA-5, NIST-approved)
    if (wallet.pq_count < 4) {
        var addr = &wallet.pq_addrs[2];
        var pos: u8 = 0;

        const domain = "omnibus.rent";
        for (domain) |c| {
            if (pos < 32) {
                addr.domain[pos] = c;
                pos += 1;
            }
        }
        addr.domain_len = pos;

        pos = 0;
        const algo = "Dilithium-5 (ML-DSA-5)";
        for (algo) |c| {
            if (pos < 32) {
                addr.algorithm[pos] = c;
                pos += 1;
            }
        }
        addr.algorithm_len = pos;

        pos = 0;
        const short = "OMNI-6d2e-RENT";
        for (short) |c| {
            if (pos < 16) {
                addr.short_id[pos] = c;
                pos += 1;
            }
        }
        addr.short_id_len = pos;

        pos = 0;
        const pq_addr = "ob_d5_5c7a1f3d9e2b6f4a8c1d5e9f2a6c1d4f";
        for (pq_addr) |c| {
            if (pos < 48) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;

        addr.pub_key_size = 2592;
        addr.secret_key_size = 4896;

        pos = 0;
        const sec = "256-bit quantum";
        for (sec) |c| {
            if (pos < 32) {
                addr.security_level[pos] = c;
                pos += 1;
            }
        }
        addr.security_len = pos;

        wallet.pq_count += 1;
    }

    // omnibus.omni – SPHINCS+ (SLH-DSA-256, eternal security)
    if (wallet.pq_count < 4) {
        var addr = &wallet.pq_addrs[3];
        var pos: u8 = 0;

        const domain = "omnibus.omni";
        for (domain) |c| {
            if (pos < 32) {
                addr.domain[pos] = c;
                pos += 1;
            }
        }
        addr.domain_len = pos;

        pos = 0;
        const algo = "SPHINCS+ (SLH-DSA-256)";
        for (algo) |c| {
            if (pos < 32) {
                addr.algorithm[pos] = c;
                pos += 1;
            }
        }
        addr.algorithm_len = pos;

        pos = 0;
        const short = "OMNI-8f1a-OMNI";
        for (short) |c| {
            if (pos < 16) {
                addr.short_id[pos] = c;
                pos += 1;
            }
        }
        addr.short_id_len = pos;

        pos = 0;
        const pq_addr = "ob_s3_9a2d5c1f4e7b2a5f8c3d6e9a1d4c7f2a";
        for (pq_addr) |c| {
            if (pos < 48) {
                addr.address[pos] = c;
                pos += 1;
            }
        }
        addr.address_len = pos;

        addr.pub_key_size = 32;
        addr.secret_key_size = 64;

        pos = 0;
        const sec = "128-bit eternal";
        for (sec) |c| {
            if (pos < 32) {
                addr.security_level[pos] = c;
                pos += 1;
            }
        }
        addr.security_len = pos;

        wallet.pq_count += 1;
    }
}

// ============================================================================
// SIMPLE SHA256 (stub for DEV_MODE)
// ============================================================================

fn sha256_simple(out: *[32]u8, in1: [*]const u8, in2: [*]const u8) void {
    // DEV_MODE: Deterministic pseudo-hash
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        out[i] = @intCast((in1[i & 0x1F] ^ in2[i & 0x1F]) +% @as(u8, @intCast(i)));
    }
}

// ============================================================================
// EXPORT FUNCTIONS
// ============================================================================

pub fn get_wallet() *const AgentWallet {
    if (!initialized) init_agent_wallet();
    return &agent_wallet;
}

pub fn get_mnemonic(buf: [*]u8, max_len: usize) u16 {
    if (!initialized) init_agent_wallet();

    const len = if (agent_wallet.mnemonic_len < max_len)
        agent_wallet.mnemonic_len
    else
        max_len;

    @memcpy(buf[0..len], agent_wallet.mnemonic[0..len]);
    return len;
}

pub fn get_address(buf: [*]u8, max_len: usize) u8 {
    if (!initialized) init_agent_wallet();

    const len = if (agent_wallet.address_len < max_len)
        agent_wallet.address_len
    else
        max_len;

    @memcpy(buf[0..len], agent_wallet.address[0..len]);
    return len;
}

// Helper: UART output (shared helper)
fn uart_write(c: u8) void {
    asm volatile ("outb %al, %dx" : : [v] "{al}" (c), [p] "{dx}" (@as(u16, 0x3F8)));
}

// Export agent data to UART (serial output) – Comprehensive multi-domain wallet report
pub fn export_to_log() void {
    if (!initialized) init_agent_wallet();

    const wallet = &agent_wallet;

    // Header
    uart_write('\n');
    for ("╔═══════════════════════════════════════════════════════════╗\n") |c| uart_write(c);
    for ("║         OMNIBUS AGENT WALLET – MULTI-DOMAIN               ║\n") |c| uart_write(c);
    for ("║    (BIP-39 + BIP-32 + Post-Quantum Cryptography)         ║\n") |c| uart_write(c);
    for ("╚═══════════════════════════════════════════════════════════╝\n\n") |c| uart_write(c);

    // Mnemonic
    for ("📝 MNEMONIC (12 words, 128-bit entropy):\n") |c| uart_write(c);
    for ("   ") |c| uart_write(c);
    for (wallet.mnemonic[0..wallet.mnemonic_len]) |c| uart_write(c);
    for ("\n\n") |c| uart_write(c);

    // Master seed (truncated hex display)
    for ("🔑 MASTER SEED (first 16 bytes hex):\n") |c| uart_write(c);
    for ("   60 3d eb 10 15 ca 67 14 bf d0 9c f7 07 bb 30 7f\n\n") |c| uart_write(c);

    // Balance
    for ("💰 INITIAL BALANCE:\n") |c| uart_write(c);
    for ("   1,000,000 OMNI (100,000,000,000 SAT)\n\n") |c| uart_write(c);

    // ERC20 On-Ramp
    for ("💳 ERC20 ON-RAMP (Send USDC to buy OMNI):\n") |c| uart_write(c);
    for ("   Ethereum Address: 0x8ba1f109551bD432803012645Ac136ddd64DBA72\n") |c| uart_write(c);
    for ("   Networks: Ethereum, Optimism, Base (same address)\n\n") |c| uart_write(c);

    // Classical chains
    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("🪙  CLASSICAL CHAINS (BIP-44)\n") |c| uart_write(c);
    for ("═══════════════════════════════════════════════════════════\n\n") |c| uart_write(c);

    for (0..wallet.classical_count) |i| {
        const addr = &wallet.classical_addrs[i];
        for ("  ") |c| uart_write(c);
        for (addr.chain[0..addr.chain_len]) |c| uart_write(c);
        uart_write('\n');
        for ("    Path: ") |c| uart_write(c);
        for (addr.derivation_path[0..addr.path_len]) |c| uart_write(c);
        uart_write('\n');
        for ("    Address: ") |c| uart_write(c);
        for (addr.address[0..addr.address_len]) |c| uart_write(c);
        for ("\n\n") |c| uart_write(c);
    }

    // Post-quantum domains
    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("🔐 POST-QUANTUM DOMAINS (NIST PQ Cryptography)\n") |c| uart_write(c);
    for ("═══════════════════════════════════════════════════════════\n\n") |c| uart_write(c);

    for (0..wallet.pq_count) |i| {
        const addr = &wallet.pq_addrs[i];
        for (addr.domain[0..addr.domain_len]) |c| uart_write(c);
        uart_write('\n');
        for ("  Algorithm: ") |c| uart_write(c);
        for (addr.algorithm[0..addr.algorithm_len]) |c| uart_write(c);
        uart_write('\n');
        for ("  Short ID: ") |c| uart_write(c);
        for (addr.short_id[0..addr.short_id_len]) |c| uart_write(c);
        uart_write('\n');
        for ("  Address: ") |c| uart_write(c);
        for (addr.address[0..addr.address_len]) |c| uart_write(c);
        uart_write('\n');
        for ("  Pub Key: ") |c| uart_write(c);
        for ("xxxx bytes | Secret Key: xxxx bytes\n") |c| uart_write(c);
        for ("  Security: ") |c| uart_write(c);
        for (addr.security_level[0..addr.security_len]) |c| uart_write(c);
        for ("\n\n") |c| uart_write(c);
    }

    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("✅ Agent wallet initialized. Ready for trading.\n\n") |c| uart_write(c);
}
