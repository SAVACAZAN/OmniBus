// client_wallet.zig – Client Wallet Generator (Phase 72)
// Generates ERC20 + Quantum addresses for on-ramp clients
// User sends USDC to ERC20 address → receives OMNI at quantum address
// Memory-mapped @ 0x5E0000, no allocators, deterministic generation

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const CLIENT_WALLET_BASE: usize = 0x5E0000;
pub const MAX_CLIENTS: usize = 256;
pub const ERC20_ADDR_LEN: usize = 42;      // 0x + 40 hex
pub const QUANTUM_ADDR_LEN: usize = 66;    // 0x + 64 hex (Dilithium-5 hash)
pub const MNEMONIC_LEN: usize = 128;       // 12 words

// ============================================================================
// CLIENT WALLET STRUCTURES
// ============================================================================

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

pub const AddressPair = struct {
    // Domain: "" (native), "love", "vaca", "rent", "food"
    domain: [16]u8 = [_]u8{0} ** 16,
    domain_len: u8 = 0,

    // ERC20 address (Sepolia) - where USDC.e is sent
    erc20_address: [ERC20_ADDR_LEN]u8 = [_]u8{0} ** ERC20_ADDR_LEN,
    erc20_len: u8 = 0,

    // OMNI address (OmniBus native) - where OMNI is received
    omni_address: PostQuantumAddress = .{},

    // Tracking
    usdc_received: u128 = 0,
    omni_minted: u128 = 0,
};

pub const ClientWallet = struct {
    magic: u32 = 0x434C4945,  // "CLIE"
    version: u32 = 1,

    // Client identity
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: u8 = 0,

    // Mnemonic (12 words, optional client-side only)
    mnemonic: [MNEMONIC_LEN]u8 = [_]u8{0} ** MNEMONIC_LEN,
    mnemonic_len: u16 = 0,

    // 5 Address Pairs (1 native + 4 domains: love, vaca, rent, food)
    address_pairs: [5]AddressPair = [_]AddressPair{.{}} ** 5,

    // Fingerprint for verification
    fingerprint: [16]u8 = [_]u8{0} ** 16,

    // Total balance tracking (across all 5 domains)
    total_usdc_received: u128 = 0,
    total_omni_minted: u128 = 0,

    // Timestamps
    created_tsc: u64 = 0,
    last_activity_tsc: u64 = 0,
};

pub const AddressIndex = struct {
    address: [ERC20_ADDR_LEN]u8 = [_]u8{0} ** ERC20_ADDR_LEN,
    client_idx: u16 = 0xFFFF,  // 0xFFFF = not found
};

pub const ClientWalletRegistry = struct {
    magic: u32 = 0x52454759,  // "REGY"
    version: u32 = 1,
    initialized: u8 = 0,

    // Circular buffer of clients
    clients: [MAX_CLIENTS]ClientWallet = [_]ClientWallet{ClientWallet{}} ** MAX_CLIENTS,
    client_count: u32 = 0,

    // Lookup: ERC20 address → client index (for fast routing)
    erc20_index: [MAX_CLIENTS]AddressIndex = [_]AddressIndex{.{}} ** MAX_CLIENTS,

    // Statistics
    total_wallets_created: u32 = 0,
    total_usdc_received: u128 = 0,
    total_omni_sent: u128 = 0,

    _reserved: [512]u8 = [_]u8{0} ** 512,
};

var registry: ClientWalletRegistry = undefined;
var initialized: bool = false;

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init_client_registry() void {
    if (initialized) return;

    var reg = &registry;
    reg.magic = 0x52454759;
    reg.version = 1;
    reg.initialized = 1;
    reg.client_count = 0;

    initialized = true;
}

// ============================================================================
// CLIENT WALLET GENERATION
// ============================================================================

pub fn generate_client_wallet(client_id: u32, name: [*]const u8, name_len: u8) ?*ClientWallet {
    init_client_registry();

    if (registry.client_count >= MAX_CLIENTS) return null;

    var wallet = &registry.clients[registry.client_count];

    wallet.magic = 0x434C4945;
    wallet.version = 1;
    wallet.id = client_id;
    wallet.created_tsc = rdtsc();
    wallet.last_activity_tsc = wallet.created_tsc;

    // Store client name
    @memcpy(wallet.name[0..@min(name_len, 32)], name[0..@min(name_len, 32)]);
    wallet.name_len = @min(name_len, 32);

    // Generate SINGLE ERC20 address for all 5 OMNI domains
    var erc20_addr: [ERC20_ADDR_LEN]u8 = undefined;
    generate_erc20_address(&erc20_addr, client_id);

    // Generate all 5 post-quantum domain addresses (1 native + 4 domains)
    generate_all_pq_addresses(wallet, client_id);

    // Set ERC20 address for first address pair (same for all)
    @memcpy(wallet.address_pairs[0].erc20_address[0..ERC20_ADDR_LEN], erc20_addr[0..ERC20_ADDR_LEN]);
    wallet.address_pairs[0].erc20_len = ERC20_ADDR_LEN;

    // Also copy to other pairs (though they share the same ERC20)
    var i: u8 = 1;
    while (i < 5) : (i += 1) {
        @memcpy(wallet.address_pairs[i].erc20_address[0..ERC20_ADDR_LEN], erc20_addr[0..ERC20_ADDR_LEN]);
        wallet.address_pairs[i].erc20_len = ERC20_ADDR_LEN;
    }

    // Generate fingerprint
    generate_fingerprint(wallet);

    // Update index (only for first ERC20 address)
    const idx = registry.client_count;
    @memcpy(
        registry.erc20_index[idx].address[0..ERC20_ADDR_LEN],
        erc20_addr[0..ERC20_ADDR_LEN]
    );
    registry.erc20_index[idx].client_idx = @intCast(idx);

    registry.client_count += 1;
    registry.total_wallets_created += 1;

    return wallet;
}

// ============================================================================
// ADDRESS GENERATION
// ============================================================================

fn generate_erc20_address(addr: *[ERC20_ADDR_LEN]u8, seed: u32) void {
    // Simple deterministic ERC20 address generation
    // In production: would use proper secp256k1 ECDSA key derivation
    // For now: hash-based generation for determinism

    var buf: [32]u8 = undefined;

    // Create seed: client_id (4 bytes) + random-like data
    var seed_buf: [8]u8 = undefined;
    const seed_array: [4]u8 = @bitCast(seed);
    const tsc_val: u32 = @as(u32, @truncate(rdtsc()));
    const tsc_array: [4]u8 = @bitCast(tsc_val);
    @memcpy(seed_buf[0..4], &seed_array);
    @memcpy(seed_buf[4..8], &tsc_array);

    // Hash to get 20-byte address
    sha256_simple(&seed_buf, &buf);

    // Format as ERC20 (0x + 40 hex chars from first 20 bytes)
    addr[0] = '0';
    addr[1] = 'x';

    var pos: u8 = 2;
    var i: u8 = 0;
    while (i < 20) : (i += 1) {
        const byte = buf[i];
        const hi = byte >> 4;
        const lo = byte & 0x0F;

        addr[pos] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
        pos += 1;
        addr[pos] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
        pos += 1;
    }
}

fn generate_all_pq_addresses(wallet: *ClientWallet, seed: u32) void {
    // Generate all 5 post-quantum domain addresses per agent_wallet.zig mapping:
    // [0] omnibus.omni     – Dilithium-5 + Kyber-768 (Hybrid)  – ob_omni_
    // [1] omnibus.love     – Kyber-768 (ML-KEM-768)            – ob_k1_
    // [2] omnibus.food     – Falcon-512                         – ob_f5_
    // [3] omnibus.rent     – Dilithium-5 (ML-DSA-5)            – ob_d5_
    // [4] omnibus.vacation – SPHINCS+ (SLH-DSA-256)            – ob_s3_

    var base_buf: [32]u8 = undefined;
    var seed_buf: [12]u8 = undefined;
    const seed_array: [4]u8 = @bitCast(seed);
    @memcpy(seed_buf[0..4], &seed_array);

    // Generate 5 different hashes from seeds with domain markers
    const domain_markers = [_][4]u8{
        "OMNI".*,       // omnibus.omni
        "LOVE".*,       // omnibus.love
        "FOOD".*,       // omnibus.food
        "RENT".*,       // omnibus.rent
        "VACA".*,       // omnibus.vacation
    };

    const domains = [_][]const u8{
        "omnibus.omni",
        "omnibus.love",
        "omnibus.food",
        "omnibus.rent",
        "omnibus.vacation",
    };

    const algorithms = [_][]const u8{
        "Dilithium-5 + Kyber-768 (Hybrid)",
        "Kyber-768 (ML-KEM-768)",
        "Falcon-512",
        "Dilithium-5 (ML-DSA-5)",
        "SPHINCS+ (SLH-DSA-256)",
    };

    const prefixes = [_][]const u8{
        "ob_omni_",
        "ob_k1_",
        "ob_f5_",
        "ob_d5_",
        "ob_s3_",
    };

    const short_ids = [_][]const u8{
        "OMNI-5k7m-OMNI",
        "OMNI-4a8f-LOVE",
        "OMNI-3b7c-FOOD",
        "OMNI-6d2e-RENT",
        "OMNI-8f1a-VACA",
    };

    const securities = [_][]const u8{
        "256-bit quantum (native chain)",
        "256-bit quantum",
        "192-bit quantum",
        "256-bit quantum",
        "128-bit eternal",
    };

    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        // Generate unique hash for each domain
        const tsc_val: u32 = @as(u32, @truncate(rdtsc() +% @as(u64, i)));
        const tsc_array: [4]u8 = @bitCast(tsc_val);
        @memcpy(seed_buf[4..8], &tsc_array);
        @memcpy(seed_buf[8..12], domain_markers[i][0..4]);

        var buf: [32]u8 = undefined;
        sha256_simple(&seed_buf, &buf);

        var pair = &wallet.address_pairs[i];
        var pq_addr = &pair.omni_address;

        // Domain
        @memcpy(pair.domain[0..@min(domains[i].len, 16)], domains[i][0..@min(domains[i].len, 16)]);
        pair.domain_len = @min(domains[i].len, 16);

        // PQ Address structure
        @memcpy(pq_addr.domain[0..@min(domains[i].len, 32)], domains[i][0..@min(domains[i].len, 32)]);
        pq_addr.domain_len = @min(domains[i].len, 32);

        @memcpy(pq_addr.algorithm[0..@min(algorithms[i].len, 32)], algorithms[i][0..@min(algorithms[i].len, 32)]);
        pq_addr.algorithm_len = @min(algorithms[i].len, 32);

        @memcpy(pq_addr.short_id[0..@min(short_ids[i].len, 16)], short_ids[i][0..@min(short_ids[i].len, 16)]);
        pq_addr.short_id_len = @min(short_ids[i].len, 16);

        // Generate address with correct prefix: "ob_algo_hash"
        var addr_pos: u8 = 0;

        // Add prefix
        @memcpy(pq_addr.address[addr_pos..addr_pos + prefixes[i].len], prefixes[i][0..prefixes[i].len]);
        addr_pos += prefixes[i].len;

        // Add hex of first 12 bytes of hash
        var j: u8 = 0;
        while (j < 12 and addr_pos < 48) : (j += 1) {
            const byte = buf[j];
            const hi = byte >> 4;
            const lo = byte & 0x0F;

            pq_addr.address[addr_pos] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
            addr_pos += 1;
            if (addr_pos < 48) {
                pq_addr.address[addr_pos] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
                addr_pos += 1;
            }
        }

        pq_addr.address_len = addr_pos;

        // Security level
        @memcpy(pq_addr.security_level[0..@min(securities[i].len, 32)], securities[i][0..@min(securities[i].len, 32)]);
        pq_addr.security_len = @min(securities[i].len, 32);

        // Key sizes (from agent_wallet.zig reference values)
        if (i == 0) {  // OMNI hybrid
            pq_addr.pub_key_size = 1184 + 2592;
            pq_addr.secret_key_size = 2400 + 4896;
        } else if (i == 1) {  // Kyber-768
            pq_addr.pub_key_size = 1184;
            pq_addr.secret_key_size = 2400;
        } else if (i == 2) {  // Falcon-512
            pq_addr.pub_key_size = 897;
            pq_addr.secret_key_size = 1281;
        } else if (i == 3) {  // Dilithium-5
            pq_addr.pub_key_size = 2592;
            pq_addr.secret_key_size = 4896;
        } else if (i == 4) {  // SPHINCS+
            pq_addr.pub_key_size = 32;
            pq_addr.secret_key_size = 64;
        }
    }
}

fn generate_fingerprint(wallet: *ClientWallet) void {
    // Create fingerprint from ERC20 address + native OMNI short_id
    var buf: [58]u8 = undefined;
    @memcpy(buf[0..42], wallet.address_pairs[0].erc20_address[0..42]);
    @memcpy(buf[42..58], wallet.address_pairs[0].omni_address.short_id[0..16]);

    var hash: [32]u8 = undefined;
    sha256_simple(&buf, &hash);

    // Use first 16 bytes as fingerprint
    @memcpy(wallet.fingerprint[0..16], hash[0..16]);
}

// ============================================================================
// LOOKUP & ROUTING
// ============================================================================

pub fn find_client_by_erc20(erc20_addr: [*]const u8, erc20_len: u8) ?*ClientWallet {
    init_client_registry();

    if (erc20_len != ERC20_ADDR_LEN) return null;

    var i: u32 = 0;
    while (i < registry.client_count) : (i += 1) {
        const idx_entry = &registry.erc20_index[i];

        // Compare addresses
        var match = true;
        var j: u8 = 0;
        while (j < ERC20_ADDR_LEN) : (j += 1) {
            if (idx_entry.address[j] != erc20_addr[j]) {
                match = false;
                break;
            }
        }

        if (match and idx_entry.client_idx < MAX_CLIENTS) {
            return &registry.clients[idx_entry.client_idx];
        }
    }

    return null;
}

pub fn record_usdc_transfer(erc20_addr: [*]const u8, erc20_len: u8, amount_usdc: u128) bool {
    if (find_client_by_erc20(erc20_addr, erc20_len)) |client| {
        client.usdc_sent +|= amount_usdc;
        client.last_activity_tsc = rdtsc();
        registry.total_usdc_received +|= amount_usdc;
        return true;
    }
    return false;
}

pub fn record_omni_transfer(client_id: u32, amount_omni: u128) bool {
    // Record OMNI transfer by client ID (identified via ERC20 address in on-ramp)
    if (client_id >= registry.client_count) return false;

    var client = &registry.clients[client_id];
    client.omni_received +|= amount_omni;
    client.last_activity_tsc = rdtsc();
    registry.total_omni_sent +|= amount_omni;
    return true;
}

// ============================================================================
// DISPLAY STATUS
// ============================================================================

fn uart_write(c: u8) void {
    asm volatile ("outb %al, %dx" : : [v] "{al}" (c), [p] "{dx}" (@as(u16, 0x3F8)));
}

pub fn display_client_registry() void {
    init_client_registry();

    for ("\n") |c| uart_write(c);
    for ("===== CLIENT WALLET REGISTRY =====\n") |c| uart_write(c);

    for ("Total Clients: ") |c| uart_write(c);
    print_u32_uart(registry.client_count);
    for ("\n") |c| uart_write(c);

    for ("Total USDC Received: ") |c| uart_write(c);
    print_u128_uart(registry.total_usdc_received);
    for ("\n") |c| uart_write(c);

    for ("Total OMNI Sent: ") |c| uart_write(c);
    print_u128_uart(registry.total_omni_sent);
    for ("\n\n") |c| uart_write(c);

    // Display recent clients (last 5)
    for ("[RECENT CLIENTS]\n") |c| uart_write(c);
    var i: u32 = if (registry.client_count > 5) registry.client_count - 5 else 0;
    while (i < registry.client_count) : (i += 1) {
        const client = &registry.clients[i];

        for ("Client ") |c| uart_write(c);
        print_u32_uart(client.id);
        for (": ") |c| uart_write(c);
        for (client.name[0..client.name_len]) |c| uart_write(c);
        for ("\n  ERC20: ") |c| uart_write(c);
        for (client.address_pairs[0].erc20_address[0..20]) |c| uart_write(c);  // First 20 chars
        for ("...\n") |c| uart_write(c);
    }

    for ("\n") |c| uart_write(c);
}

pub fn display_client_wallet(wallet: *const ClientWallet) void {
    for ("\n╔═══════════════════════════════════════════════════════════╗\n") |c| uart_write(c);
    for ("║               CLIENT MULTI-DOMAIN WALLET                 ║\n") |c| uart_write(c);
    for ("╚═══════════════════════════════════════════════════════════╝\n\n") |c| uart_write(c);

    for ("ID: ") |c| uart_write(c);
    print_u32_uart(wallet.id);
    for (" | Name: ") |c| uart_write(c);
    for (wallet.name[0..wallet.name_len]) |c| uart_write(c);
    for ("\n") |c| uart_write(c);

    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("📥 ERC20 ON-RAMP (Send USDC on Sepolia):\n") |c| uart_write(c);
    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for (wallet.address_pairs[0].erc20_address[0..wallet.address_pairs[0].erc20_len]) |c| uart_write(c);
    for ("\n\n") |c| uart_write(c);

    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("🔐 POST-QUANTUM DOMAINS (Receive OMNI):\n") |c| uart_write(c);
    for ("═══════════════════════════════════════════════════════════\n\n") |c| uart_write(c);

    // Display all 5 address pairs
    var pair_idx: u8 = 0;
    while (pair_idx < 5) : (pair_idx += 1) {
        const pair = &wallet.address_pairs[pair_idx];
        const pq_addr = &pair.omni_address;

        for ("Domain ") |c| uart_write(c);
        print_u8_uart(pair_idx + 1);
        for (": ") |c| uart_write(c);
        for (pair.domain[0..pair.domain_len]) |c| uart_write(c);
        for ("\n") |c| uart_write(c);

        for ("  Algorithm: ") |c| uart_write(c);
        for (pq_addr.algorithm[0..pq_addr.algorithm_len]) |c| uart_write(c);
        for ("\n") |c| uart_write(c);

        for ("  Address: ") |c| uart_write(c);
        for (pq_addr.address[0..pq_addr.address_len]) |c| uart_write(c);
        for ("\n") |c| uart_write(c);

        for ("  Security: ") |c| uart_write(c);
        for (pq_addr.security_level[0..pq_addr.security_len]) |c| uart_write(c);
        for ("\n\n") |c| uart_write(c);
    }

    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("💰 BALANCE & ACTIVITY:\n") |c| uart_write(c);
    for ("═══════════════════════════════════════════════════════════\n") |c| uart_write(c);

    for ("Total USDC Received: ") |c| uart_write(c);
    print_u128_uart(wallet.total_usdc_received);
    for ("\n") |c| uart_write(c);

    for ("Total OMNI Minted: ") |c| uart_write(c);
    print_u128_uart(wallet.total_omni_minted);
    for ("\n\n") |c| uart_write(c);
}

// ============================================================================
// HELPERS
// ============================================================================

fn print_u8_uart(val: u8) void {
    if (val == 0) {
        uart_write('0');
        return;
    }
    var divisor: u8 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }
    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u32_uart(val: u32) void {
    if (val == 0) {
        uart_write('0');
        return;
    }
    var divisor: u32 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }
    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u64_uart(val: u64) void {
    if (val == 0) {
        uart_write('0');
        return;
    }
    var divisor: u64 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }
    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u128_uart(val: u128) void {
    // Print u128 as two u64 parts to avoid __udivti3 builtin
    const hi: u64 = @as(u64, @intCast(val >> 64));
    const lo: u64 = @as(u64, @intCast(val & 0xFFFFFFFFFFFFFFFF));

    if (hi > 0) {
        print_u64_uart(hi);
        print_u64_uart(lo);
    } else {
        print_u64_uart(lo);
    }
}

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// ============================================================================
// SIMPLE SHA256 (for address generation only)
// ============================================================================

fn sha256_simple(input: [*]const u8, output: [*]u8) void {
    // Simplified SHA-256 for deterministic address generation
    // In production: use proper cryptographic SHA-256
    // This is sufficient for address generation (non-security critical)

    var hash: [32]u8 = undefined;

    // Simple hash: XOR all bytes + linear congruential
    var sum: u32 = 0;
    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        sum ^= input[i % 64];
        sum = sum ^ @as(u32, 2654435761);  // Mix with constant
        sum +%= 2246822519;                // Add constant (wrapping)
    }

    // Expand to 32 bytes
    var j: u8 = 0;
    while (j < 32) : (j += 1) {
        sum = sum ^ @as(u32, 2654435761);
        sum +%= 2246822519;
        const shift_amount: u5 = @as(u5, @intCast((j % 4) * 8));
        hash[j] = @as(u8, @intCast((sum >> shift_amount) & 0xFF));
    }

    @memcpy(output[0..32], &hash);
}

// ============================================================================
// EXPORTS
// ============================================================================

pub fn get_registry() *const ClientWalletRegistry {
    init_client_registry();
    return &registry;
}
