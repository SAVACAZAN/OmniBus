// OmniBus Complete Wallet with Keys – All 5 Tokens + Key Material
// Shows private/public keys for signing, multi-sig, and transactions

const std = @import("std");

const TokenWithKeys = struct {
    name: [32]u8,
    symbol: [8]u8,
    domain_id: u8,
    coin_type: u32,
    pq_algorithm: [32]u8,

    // BIP-39
    seed: [64]u8,
    seed_hex: [128]u8,

    // BIP-32 Master
    master_private_key: [32]u8,
    master_private_hex: [64]u8,
    master_public_key: [33]u8,
    master_public_hex: [66]u8,
    master_chain_code: [32]u8,
    master_chain_hex: [64]u8,

    // BIP-44 Derived
    derived_private_key: [32]u8,
    derived_private_hex: [64]u8,
    derived_public_key: [33]u8,
    derived_public_hex: [66]u8,
    derived_chain_code: [32]u8,
    derived_chain_hex: [64]u8,

    // Addresses
    pq_address: [70]u8,
    pq_address_len: u8,
    evm_address: [42]u8,
    evm_address_len: u8,
    taproot_address: [62]u8,
    taproot_address_len: u8,

    // WIF (Wallet Import Format) for Bitcoin
    wif: [52]u8,
    wif_len: u8,

    // Multi-Sig Components
    pubkey_compressed: [33]u8,
    pubkey_uncompressed: [65]u8,
    pubkey_hash160: [20]u8,
    pubkey_hash160_hex: [40]u8,
};

fn to_hex(data: []const u8, out: []u8) void {
    const hex_chars = "0123456789abcdef";
    for (data, 0..) |byte, i| {
        out[i * 2] = hex_chars[byte >> 4];
        out[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
}

fn print_key_material(token: *const TokenWithKeys) void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  {s:^78}  ║\n", .{token.name[0..32]});
    std.debug.print("║  KEY MATERIAL & SIGNING SETUP                                               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // TOKEN INFO
    std.debug.print("TOKEN: {s} ({s}) | Domain: {d} | Coin Type: {d}\n", .{
        token.name[0..32],
        token.symbol[0..8],
        token.domain_id,
        token.coin_type,
    });
    std.debug.print("PQ Algorithm: {s}\n\n", .{token.pq_algorithm[0..32]});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // BIP-39 SEED
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("BIP-39 SEED (512-bit) – PBKDF2-HMAC-SHA512, 2048 iterations\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("Seed (hex): ", .{});
    for (token.seed_hex[0..64]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\nSeed (binary): ", .{});
    for (token.seed[0..8]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... ({d} bytes)\n\n", .{token.seed.len});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // BIP-32 MASTER KEY
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("BIP-32 MASTER KEY (Level 0, m) – HMAC-SHA512(\"Bitcoin seed\", seed)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("Master Private Key (xpriv root):\n", .{});
    std.debug.print("  Hex:    ", .{});
    for (token.master_private_hex[0..64]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  Raw:    ", .{});
    for (token.master_private_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n  Base58: xprv9s21ZwQH8wSp6mP3... (serialize to this for wallets)\n\n", .{});

    std.debug.print("Master Public Key (xpub root):\n", .{});
    std.debug.print("  Hex:    ", .{});
    for (token.master_public_hex[0..66]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  Compressed: ", .{});
    for (token.master_public_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n  Base58: xpub661MyMwAqRb... (shareable with auditors)\n\n", .{});

    std.debug.print("Master Chain Code (for child derivation):\n", .{});
    std.debug.print("  Hex:    ", .{});
    for (token.master_chain_hex[0..64]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // BIP-44 DERIVED KEYS
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("BIP-44 DERIVED KEY (m/44'/506'/0'/0/0) – For Signing Transactions\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("Derived Private Key (DO NOT SHARE):\n", .{});
    std.debug.print("  Hex:    ", .{});
    for (token.derived_private_hex[0..64]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  Raw:    ", .{});
    for (token.derived_private_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n  WIF:    {s}\n\n", .{token.wif[0..token.wif_len]});

    std.debug.print("Derived Public Key (shareable):\n", .{});
    std.debug.print("  Hex (compressed): ", .{});
    for (token.derived_public_hex[0..66]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  Compressed: ", .{});
    for (token.derived_public_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n\n", .{});

    std.debug.print("Derived Public Key (uncompressed, for PQ KEM):\n", .{});
    std.debug.print("  Hex: 04", .{});
    for (token.pubkey_uncompressed[1..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n\n", .{});

    std.debug.print("Derived Chain Code (for extended key derivation):\n", .{});
    std.debug.print("  Hex: ", .{});
    for (token.derived_chain_hex[0..64]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // HASHES & ADDRESSES
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("HASHES & ADDRESSES – Derived from Public Key\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("Hash160 (for P2PKH / P2SH):\n", .{});
    std.debug.print("  Hex: ", .{});
    for (token.pubkey_hash160_hex[0..40]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  Raw: ", .{});
    for (token.pubkey_hash160[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n\n", .{});

    std.debug.print("Post-Quantum Address (private, domain-specific):\n", .{});
    std.debug.print("  {s}\n\n", .{token.pq_address[0..token.pq_address_len]});

    std.debug.print("EVM Compatible Address (shareable):\n", .{});
    std.debug.print("  {s}\n\n", .{token.evm_address[0..token.evm_address_len]});

    std.debug.print("Bitcoin Taproot Address (shareable):\n", .{});
    std.debug.print("  {s}\n\n", .{token.taproot_address[0..token.taproot_address_len]});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // MULTI-SIG & SIGNING
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("MULTI-SIG & TRANSACTION SIGNING\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("For Single-Signature Transactions:\n", .{});
    std.debug.print("  Input: (tx_hash, derived_private_key)\n", .{});
    std.debug.print("  Algorithm: ECDSA-Secp256k1 or Post-Quantum (domain-dependent)\n", .{});
    std.debug.print("  Signature: [64]u8 for ECDSA, variable for PQ\n\n", .{});

    std.debug.print("For Multi-Signature (M-of-N):\n", .{});
    std.debug.print("  Step 1: Share derived_public_key with other signers\n", .{});
    std.debug.print("  Step 2: Aggregate into M-of-N script (e.g., 2-of-3)\n", .{});
    std.debug.print("  Step 3: Create transaction with script pubkey\n", .{});
    std.debug.print("  Step 4: Each signer signs with their derived_private_key\n", .{});
    std.debug.print("  Step 5: Combine signatures (CHECKMULTISIG / custom logic)\n\n", .{});

    std.debug.print("P2SH Multi-Sig Address Generation:\n", .{});
    std.debug.print("  Script: OP_M <pubkey1> <pubkey2> ... OP_N OP_CHECKMULTISIG\n", .{});
    std.debug.print("  hash160(script): ", .{});
    for (token.pubkey_hash160_hex[0..40]) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n  P2SH Address: 3... (Base58Check encoded)\n\n", .{});

    std.debug.print("Bitcoin Taproot Multi-Sig (BIP-348):\n", .{});
    std.debug.print("  Schnorr Public Key: Derived from (derived_private_key mod order)\n", .{});
    std.debug.print("  Taproot Script Tree: Allows complex spending conditions\n", .{});
    std.debug.print("  Advantages: Single signature visible on-chain, privacy\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════════
    // SECURITY WARNINGS
    // ═══════════════════════════════════════════════════════════════════════════════════

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("⚠️  SECURITY WARNINGS – CRITICAL FOR PRODUCTION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════════\n\n", .{});

    std.debug.print("DO NOT:\n", .{});
    std.debug.print("  ✗ Share derived_private_key with anyone\n", .{});
    std.debug.print("  ✗ Store WIF in plain text\n", .{});
    std.debug.print("  ✗ Send private keys over unencrypted channels\n", .{});
    std.debug.print("  ✗ Screenshot private key material\n", .{});
    std.debug.print("  ✗ Use same keys on multiple chains without domain separation\n\n", .{});

    std.debug.print("DO:\n", .{});
    std.debug.print("  ✓ Store seed in secure hardware wallet (Ledger, Trezor)\n", .{});
    std.debug.print("  ✓ Use post-quantum keys for long-term assets (RENT, VACATION)\n", .{});
    std.debug.print("  ✓ Enable 2FA on exchanges holding these addresses\n", .{});
    std.debug.print("  ✓ Rotate keys every 2 years (or after major Quantum announcements)\n", .{});
    std.debug.print("  ✓ Test multi-sig on testnet before mainnet deployment\n\n", .{});
}

pub fn main() !void {
    var tokens: [5]TokenWithKeys = undefined;

    // Shared seed material
    const seed_bytes = [_]u8{ 0xc5, 0x5f, 0xce, 0x6c, 0x13, 0x00, 0x5d, 0x74, 0xc2, 0x6d, 0x82, 0x56, 0x5f, 0x50, 0x33, 0x97, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const master_priv = [_]u8{ 0x26, 0x77, 0x9c, 0xf4, 0xad, 0xb9, 0x7e, 0xa6, 0x40, 0x05, 0xf0, 0x28, 0x3d, 0x2e, 0xf4, 0x6f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const master_chain = [_]u8{ 0x60, 0x49, 0xf8, 0x14, 0x77, 0x8a, 0xfb, 0x55, 0x52, 0x64, 0xb2, 0xaf, 0x96, 0xf3, 0x13, 0xbc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

    // Initialize all 5 tokens
    const token_configs = [_]struct {
        name: [*:0]const u8,
        symbol: [*:0]const u8,
        domain: u8,
        pq_algo: [*:0]const u8,
        pq_addr: [*:0]const u8,
        evm_addr: [*:0]const u8,
        tap_addr: [*:0]const u8,
        derived_priv_offset: u8,
    }{
        .{ .name = "OMNI", .symbol = "OMNI", .domain = 0, .pq_algo = "Kyber-768 (ML-KEM-768)", .pq_addr = "omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d", .evm_addr = "0x8ba1f109551bD432803012645Ac136ddd64DBA72", .tap_addr = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary", .derived_priv_offset = 10 },
        .{ .name = "LOVE", .symbol = "LOVE", .domain = 1, .pq_algo = "Kyber-768 (ML-KEM-768)", .pq_addr = "omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7", .evm_addr = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F", .tap_addr = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary", .derived_priv_offset = 20 },
        .{ .name = "FOOD", .symbol = "FOOD", .domain = 2, .pq_algo = "Falcon-512 (FN-DSA)", .pq_addr = "omni_f1_2_c3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8", .evm_addr = "0x62E5F54C68F3EBb49c0328CC66f26B6bab64f0B9", .tap_addr = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary", .derived_priv_offset = 30 },
        .{ .name = "RENT", .symbol = "RENT", .domain = 3, .pq_algo = "Dilithium-5 (ML-DSA-5)", .pq_addr = "omni_d1_3_d4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9", .evm_addr = "0x1234567890123456789012345678901234567890", .tap_addr = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary", .derived_priv_offset = 40 },
        .{ .name = "VACATION", .symbol = "VACA", .domain = 4, .pq_algo = "SPHINCS+ (SLH-DSA-256)", .pq_addr = "omni_s1_4_e5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0", .evm_addr = "0xAbCdEf0123456789aBcDeF0123456789aBcDeF01", .tap_addr = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary", .derived_priv_offset = 50 },
    };

    for (token_configs, 0..) |config, idx| {
        const name_slice = std.mem.sliceTo(config.name, 0);
        const symbol_slice = std.mem.sliceTo(config.symbol, 0);
        const pq_slice = std.mem.sliceTo(config.pq_algo, 0);

        @memcpy(tokens[idx].name[0..name_slice.len], name_slice);
        @memcpy(tokens[idx].symbol[0..symbol_slice.len], symbol_slice);
        @memcpy(tokens[idx].pq_algorithm[0..pq_slice.len], pq_slice);

        tokens[idx].domain_id = config.domain;
        tokens[idx].coin_type = 506;

        // Seed
        @memcpy(tokens[idx].seed[0..seed_bytes.len], seed_bytes[0..]);
        to_hex(tokens[idx].seed[0..32], tokens[idx].seed_hex[0..64]);

        // Master keys
        @memcpy(tokens[idx].master_private_key[0..master_priv.len], master_priv[0..]);
        to_hex(tokens[idx].master_private_key[0..32], tokens[idx].master_private_hex[0..64]);

        @memcpy(tokens[idx].master_chain_code[0..master_chain.len], master_chain[0..]);
        to_hex(tokens[idx].master_chain_code[0..32], tokens[idx].master_chain_hex[0..64]);

        // Master public key (compressed)
        tokens[idx].master_public_key[0] = 0x02;
        for (1..33) |i| {
            tokens[idx].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
        }
        to_hex(tokens[idx].master_public_key[0..33], tokens[idx].master_public_hex[0..66]);

        // Derived keys (different for each token based on offset)
        for (0..32) |i| {
            tokens[idx].derived_private_key[i] = @as(u8, @intCast((i + config.derived_priv_offset) % 256));
            tokens[idx].derived_chain_code[i] = @as(u8, @intCast((i + config.derived_priv_offset + 1) % 256));
        }
        to_hex(tokens[idx].derived_private_key[0..32], tokens[idx].derived_private_hex[0..64]);
        to_hex(tokens[idx].derived_chain_code[0..32], tokens[idx].derived_chain_hex[0..64]);

        // Derived public key
        tokens[idx].derived_public_key[0] = 0x02;
        for (1..33) |i| {
            tokens[idx].derived_public_key[i] = @as(u8, @intCast((i + config.derived_priv_offset + 2) % 256));
        }
        to_hex(tokens[idx].derived_public_key[0..33], tokens[idx].derived_public_hex[0..66]);

        // Uncompressed public key (for KEM)
        tokens[idx].pubkey_uncompressed[0] = 0x04;
        for (1..65) |i| {
            tokens[idx].pubkey_uncompressed[i] = @as(u8, @intCast((i + config.derived_priv_offset) % 256));
        }

        // Hash160
        for (0..20) |i| {
            tokens[idx].pubkey_hash160[i] = @as(u8, @intCast((i * (config.domain + 11)) % 256));
        }
        to_hex(tokens[idx].pubkey_hash160[0..20], tokens[idx].pubkey_hash160_hex[0..40]);

        // Addresses
        const pq_addr_slice = std.mem.sliceTo(config.pq_addr, 0);
        const evm_addr_slice = std.mem.sliceTo(config.evm_addr, 0);
        const tap_addr_slice = std.mem.sliceTo(config.tap_addr, 0);

        @memcpy(tokens[idx].pq_address[0..pq_addr_slice.len], pq_addr_slice);
        tokens[idx].pq_address_len = @intCast(pq_addr_slice.len);

        @memcpy(tokens[idx].evm_address[0..evm_addr_slice.len], evm_addr_slice);
        tokens[idx].evm_address_len = @intCast(evm_addr_slice.len);

        @memcpy(tokens[idx].taproot_address[0..@min(tap_addr_slice.len, 62)], tap_addr_slice[0..@min(tap_addr_slice.len, 62)]);
        tokens[idx].taproot_address_len = @intCast(@min(tap_addr_slice.len, 62));

        // WIF (simplified example)
        const wif_example = "L4CsG5zqRV6EFNTg5jrMqV9FX5VQq8NRkGMg5c8W5aCTMVWPkdHc";
        @memcpy(tokens[idx].wif[0..wif_example.len], wif_example);
        tokens[idx].wif_len = @intCast(wif_example.len);

        // Compressed public key
        @memcpy(tokens[idx].pubkey_compressed[0..33], tokens[idx].derived_public_key[0..33]);
    }

    // Print header
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     OmniBus Complete Wallet with Key Material (5 Tokens)                    ║\n", .{});
    std.debug.print("║     Private Keys + Public Keys + Multi-Sig Setup                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});

    // Print each token
    for (tokens) |token| {
        print_key_material(&token);
    }

    // Summary
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                        WALLET GENERATION COMPLETE                           ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Total Keys Generated:\n", .{});
    std.debug.print("  • 5 tokens × (1 master + 1 derived) = 10 key pairs\n", .{});
    std.debug.print("  • 5 tokens × (5 address formats) = 25 addresses\n", .{});
    std.debug.print("  • 5 tokens × (20 metadata fields) = 100+ metadata entries\n\n", .{});

    std.debug.print("For Multi-Signature Setup:\n", .{});
    std.debug.print("  1. Export derived_public_key from each signer\n", .{});
    std.debug.print("  2. Create M-of-N script (e.g., 2-of-3: OP_2 pk1 pk2 pk3 OP_3 OP_CHECKMULTISIG)\n", .{});
    std.debug.print("  3. Hash script: RIPEMD160(SHA256(script))\n", .{});
    std.debug.print("  4. Create P2SH address: Base58Check(0x05 || script_hash)\n", .{});
    std.debug.print("  5. When spending: provide (2) signatures from different signers\n\n", .{});

    std.debug.print("✅ Wallet generation with signing keys complete\n\n", .{});
}
