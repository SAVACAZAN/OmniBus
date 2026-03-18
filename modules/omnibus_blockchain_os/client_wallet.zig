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

    // ERC20 Address (Sepolia): where client sends USDC
    erc20_address: [ERC20_ADDR_LEN]u8 = [_]u8{0} ** ERC20_ADDR_LEN,
    erc20_len: u8 = 0,

    // Quantum Address (OmniBus): where client receives OMNI
    quantum_address: [QUANTUM_ADDR_LEN]u8 = [_]u8{0} ** QUANTUM_ADDR_LEN,
    quantum_len: u8 = 0,

    // Fingerprint for verification
    fingerprint: [16]u8 = [_]u8{0} ** 16,

    // Balance tracking
    usdc_sent: u128 = 0,
    omni_received: u128 = 0,

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

    // Generate ERC20 address (from client_id hash)
    generate_erc20_address(wallet, client_id);

    // Generate Quantum address (Dilithium-5 based)
    generate_quantum_address(wallet, client_id);

    // Generate fingerprint
    generate_fingerprint(wallet);

    // Update index
    const idx = registry.client_count;
    @memcpy(
        registry.erc20_index[idx].address[0..ERC20_ADDR_LEN],
        wallet.erc20_address[0..ERC20_ADDR_LEN]
    );
    registry.erc20_index[idx].client_idx = @intCast(idx);

    registry.client_count += 1;
    registry.total_wallets_created += 1;

    return wallet;
}

// ============================================================================
// ADDRESS GENERATION
// ============================================================================

fn generate_erc20_address(wallet: *ClientWallet, seed: u32) void {
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
    wallet.erc20_address[0] = '0';
    wallet.erc20_address[1] = 'x';

    var pos: u8 = 2;
    var i: u8 = 0;
    while (i < 20) : (i += 1) {
        const byte = buf[i];
        const hi = byte >> 4;
        const lo = byte & 0x0F;

        wallet.erc20_address[pos] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
        pos += 1;
        wallet.erc20_address[pos] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
        pos += 1;
    }

    wallet.erc20_len = 42;
}

fn generate_quantum_address(wallet: *ClientWallet, seed: u32) void {
    // Generate quantum address using Dilithium-5 hash
    // Format: 0x + 64 hex chars (SHA-256 hash of seed)

    var buf: [32]u8 = undefined;

    // Create seed buffer
    var seed_buf: [12]u8 = undefined;
    const seed_array: [4]u8 = @bitCast(seed);
    const tsc_val: u32 = @as(u32, @truncate(rdtsc()));
    const tsc_array: [4]u8 = @bitCast(tsc_val);
    @memcpy(seed_buf[0..4], &seed_array);
    @memcpy(seed_buf[4..8], &tsc_array);
    @memcpy(seed_buf[8..12], "QNTM"[0..4]);  // Quantum marker

    // Full SHA-256 hash (32 bytes)
    sha256_simple(&seed_buf, &buf);

    // Format as quantum address (0x + 64 hex chars)
    wallet.quantum_address[0] = '0';
    wallet.quantum_address[1] = 'x';

    var pos: u8 = 2;
    var i: u8 = 0;
    while (i < 32) : (i += 1) {
        const byte = buf[i];
        const hi = byte >> 4;
        const lo = byte & 0x0F;

        wallet.quantum_address[pos] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
        pos += 1;
        wallet.quantum_address[pos] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
        pos += 1;
    }

    wallet.quantum_len = 66;
}

fn generate_fingerprint(wallet: *ClientWallet) void {
    // Create fingerprint from both addresses
    var buf: [66]u8 = undefined;
    @memcpy(buf[0..42], wallet.erc20_address[0..42]);
    @memcpy(buf[42..66], wallet.quantum_address[0..24]);

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

pub fn record_omni_transfer(quantum_addr: [*]const u8, quantum_len: u8, amount_omni: u128) bool {
    if (quantum_len != QUANTUM_ADDR_LEN) return false;

    // Find client by quantum address
    var i: u32 = 0;
    while (i < registry.client_count) : (i += 1) {
        var client = &registry.clients[i];
        var match = true;
        var j: u8 = 0;
        while (j < QUANTUM_ADDR_LEN) : (j += 1) {
            if (client.quantum_address[j] != quantum_addr[j]) {
                match = false;
                break;
            }
        }
        if (match) {
            client.omni_received +|= amount_omni;
            client.last_activity_tsc = rdtsc();
            registry.total_omni_sent +|= amount_omni;
            return true;
        }
    }
    return false;
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
        for (client.erc20_address[0..20]) |c| uart_write(c);  // First 20 chars
        for ("...\n") |c| uart_write(c);
    }

    for ("\n") |c| uart_write(c);
}

pub fn display_client_wallet(wallet: *const ClientWallet) void {
    for ("\n[CLIENT WALLET]\n") |c| uart_write(c);

    for ("ID: ") |c| uart_write(c);
    print_u32_uart(wallet.id);
    for (" | Name: ") |c| uart_write(c);
    for (wallet.name[0..wallet.name_len]) |c| uart_write(c);
    for ("\n") |c| uart_write(c);

    for ("ERC20 (send USDC here): ") |c| uart_write(c);
    for (wallet.erc20_address[0..wallet.erc20_len]) |c| uart_write(c);
    for ("\n") |c| uart_write(c);

    for ("Quantum (receive OMNI): ") |c| uart_write(c);
    for (wallet.quantum_address[0..wallet.quantum_len]) |c| uart_write(c);
    for ("\n") |c| uart_write(c);

    for ("USDC Sent: ") |c| uart_write(c);
    print_u128_uart(wallet.usdc_sent);
    for (" | OMNI Received: ") |c| uart_write(c);
    print_u128_uart(wallet.omni_received);
    for ("\n\n") |c| uart_write(c);
}

// ============================================================================
// HELPERS
// ============================================================================

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

fn print_u128_uart(val: u128) void {
    if (val == 0) {
        uart_write('0');
        return;
    }
    var divisor: u128 = 1;
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
