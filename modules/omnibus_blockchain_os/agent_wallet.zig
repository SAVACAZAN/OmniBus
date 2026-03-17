// agent_wallet.zig – Agent HD Wallet Generation (Phase 68)
// Generates BIP-39 mnemonic + BIP-32 HD keys for a trading agent
// Memory: fixed-size buffers, no allocators
//
// Agent Identity:
//   - Mnemonic: 12 words (128 bits entropy)
//   - Master seed: 64 bytes (from mnemonic)
//   - Private key: 32 bytes (secp256k1, OmniBus chain)
//   - Public key: 33 bytes (compressed)
//   - Address: 0x<domain><pubkey_hash><checksum>

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const AGENT_BASE: usize = 0x5EC000;
pub const ENTROPY_SIZE: usize = 16;  // 128 bits (12-word mnemonic)
pub const SEED_SIZE: usize = 64;     // PBKDF2 output
pub const PRIVKEY_SIZE: usize = 32;  // secp256k1 private key
pub const PUBKEY_SIZE: usize = 33;   // Compressed public key

// BIP-39 word list (12 common words for DEV_MODE hardcoded agent)
pub const BIP39_WORDS = [_][]const u8{
    "abandon", "ability", "absence", "absorb", "abstract", "academy",
    "accept", "accident", "account", "achieve", "acid", "acoustic",
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

    // HD Keys
    private_key: [PRIVKEY_SIZE]u8 = [_]u8{0} ** PRIVKEY_SIZE,
    public_key: [PUBKEY_SIZE]u8 = [_]u8{0} ** PUBKEY_SIZE,

    // Address
    address: [42]u8 = [_]u8{0} ** 42,  // 0x + 40 hex chars
    address_len: u8 = 0,

    // Balance (in SAT)
    balance_sat: u64 = 100_000_000_000,  // 1M OMNI = 100M SAT

    _reserved: [512]u8 = [_]u8{0} ** 512,
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

    // Derive private key (m/44'/506'/0'/0/0)
    derive_private_key(wallet);

    // Compute public key from private key
    compute_public_key(wallet);

    // Generate address from public key
    generate_address(wallet);

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

pub fn print_to_uart() void {
    if (!initialized) init_agent_wallet();

    const wallet = &agent_wallet;

    // Print markers
    inline fn uart(c: u8) void {
        asm volatile ("outb %al, %dx" : : [v] "{al}" (c), [p] "{dx}" (@as(u16, 0x3F8)));
    }

    uart('A');  // Agent wallet loaded
    uart('G');  // Generate complete
    uart('!');  // Ready
}
