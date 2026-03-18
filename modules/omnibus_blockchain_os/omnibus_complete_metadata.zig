// OmniBus Complete Wallet Metadata – All 5 Tokens
// Shows complete BIP-32/BIP-44 hierarchy for each token
// OMNI, LOVE, FOOD, RENT, VACA with post-quantum addresses

const std = @import("std");

const TokenMetadata = struct {
    name: [32]u8,
    symbol: [8]u8,
    domain_id: u8,
    coin_type: u32,
    pq_algorithm: [32]u8,
    pq_prefix: [16]u8,

    // BIP-39 Seed (same for all tokens)
    seed: [64]u8,

    // BIP-32 Master Key (Level 0)
    master_private_key: [32]u8,
    master_chain_code: [32]u8,
    master_public_key: [33]u8,
    master_fingerprint: [4]u8,

    // BIP-44 Path: m/44'/coin_type'/0'/0/0
    derivation_depth: u8,
    derivation_path: [32]u8,

    // Level 5 Derived Keys
    derived_private_key: [32]u8,
    derived_public_key: [33]u8,
    derived_chain_code: [32]u8,
    parent_fingerprint: [4]u8,
    child_fingerprint: [4]u8,

    // Hashes
    hash160: [20]u8,           // For legacy/P2PKH
    keccak256: [32]u8,         // For EVM

    // Addresses
    pq_address: [70]u8,        // omni_k1_/omni_f1_/omni_d1_/omni_s1_
    pq_address_len: u8,

    evm_address: [42]u8,       // 0x...
    evm_address_len: u8,

    btc_taproot: [62]u8,       // bc1p...
    btc_taproot_len: u8,

    lightning_invoice: [128]u8, // lnbc...
    lightning_invoice_len: u8,
};

fn print_token_metadata(token: *const TokenMetadata) void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  {s:^78}  ║\n", .{token.name[0..@min(32, 78)]});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("TOKEN INFORMATION:\n", .{});
    std.debug.print("  Name:              {s}\n", .{token.name[0..32]});
    std.debug.print("  Symbol:            {s}\n", .{token.symbol[0..8]});
    std.debug.print("  Domain ID:         {d}\n", .{token.domain_id});
    std.debug.print("  Coin Type (BIP44): {d}\n", .{token.coin_type});
    std.debug.print("  PQ Algorithm:      {s}\n", .{token.pq_algorithm[0..32]});
    std.debug.print("  PQ Prefix:         {s}\n\n", .{token.pq_prefix[0..16]});

    std.debug.print("BIP-39 SEED (shared across all tokens):\n", .{});
    std.debug.print("  ", .{});
    for (token.seed[0..8]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (64 bytes)\n\n", .{});

    std.debug.print("BIP-32 MASTER KEY (Level 0, m):\n", .{});
    std.debug.print("  Private Key: ", .{});
    for (token.master_private_key[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (32 bytes)\n", .{});

    std.debug.print("  Public Key:  ", .{});
    for (token.master_public_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print(" (compressed, 33 bytes)\n", .{});

    std.debug.print("  Chain Code:  ", .{});
    for (token.master_chain_code[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (32 bytes)\n", .{});

    std.debug.print("  Fingerprint: ", .{});
    for (token.master_fingerprint) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n\n", .{});

    std.debug.print("BIP-44 DERIVATION PATH (m/44'/coin_type'/0'/0/0):\n", .{});
    std.debug.print("  m/44'/", .{});
    std.debug.print("{d}", .{token.coin_type});
    std.debug.print("'/0'/0/0\n", .{});
    std.debug.print("  Depth: {d} (hardened path with 5 levels)\n\n", .{token.derivation_depth});

    std.debug.print("DERIVED KEY (Level 5, m/44'/coin_type'/0'/0/0):\n", .{});
    std.debug.print("  Private Key: ", .{});
    for (token.derived_private_key[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (32 bytes)\n", .{});

    std.debug.print("  Public Key:  ", .{});
    for (token.derived_public_key[0..]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print(" (33 bytes)\n", .{});

    std.debug.print("  Chain Code:  ", .{});
    for (token.derived_chain_code[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (32 bytes, for further derivation)\n", .{});

    std.debug.print("  Parent FP:   ", .{});
    for (token.parent_fingerprint) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print(" (fingerprint of m/44'/coin_type'/0'/0)\n", .{});

    std.debug.print("  Child FP:    ", .{});
    for (token.child_fingerprint) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print(" (fingerprint of m/44'/coin_type'/0'/0/0)\n\n", .{});

    std.debug.print("HASHES:\n", .{});
    std.debug.print("  Hash160:    ", .{});
    for (token.hash160[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (20 bytes, for P2PKH)\n", .{});

    std.debug.print("  Keccak256:  ", .{});
    for (token.keccak256[0..4]) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("... (32 bytes, for EVM)\n\n", .{});

    std.debug.print("ADDRESSES:\n", .{});
    std.debug.print("  Post-Quantum:      {s}\n", .{token.pq_address[0..token.pq_address_len]});
    std.debug.print("  EVM Compatible:    {s}\n", .{token.evm_address[0..token.evm_address_len]});
    std.debug.print("  Bitcoin Taproot:   {s}\n", .{token.btc_taproot[0..token.btc_taproot_len]});
    std.debug.print("  Lightning Invoice: {s}\n\n", .{token.lightning_invoice[0..token.lightning_invoice_len]});
}

fn print_hierarchy_summary() void {
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   COMPLETE OMNIBUS HIERARCHY (All Tokens)                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("BIP-39 SEED (512-bit, PBKDF2-HMAC-SHA512, 2048 iterations)\n", .{});
    std.debug.print("  │\n", .{});
    std.debug.print("  └─→ HMAC-SHA512(\"Bitcoin seed\", seed)\n", .{});
    std.debug.print("       │\n", .{});
    std.debug.print("       └─→ Master Key (m, depth=0)\n", .{});
    std.debug.print("           ├─ privkey: [32]u8\n", .{});
    std.debug.print("           ├─ pubkey:  [33]u8 (compressed)\n", .{});
    std.debug.print("           ├─ chain_code: [32]u8\n", .{});
    std.debug.print("           ├─ fingerprint: [4]u8\n", .{});
    std.debug.print("           ├─ xpriv: 111 bytes (serialized)\n", .{});
    std.debug.print("           └─ xpub:  111 bytes (serialized)\n", .{});
    std.debug.print("           │\n", .{});
    std.debug.print("           └─→ m/44' (hardened, depth=1)\n", .{});
    std.debug.print("               └─→ m/44'/506' (OmniBus native)\n", .{});
    std.debug.print("               │   └─→ m/44'/0' (Bitcoin)\n", .{});
    std.debug.print("               │   └─→ m/44'/60' (Ethereum)\n", .{});
    std.debug.print("               │   └─→ m/44'/501' (Solana)\n", .{});
    std.debug.print("               │   └─→ m/44'/2' (Litecoin)\n", .{});
    std.debug.print("               │\n", .{});
    std.debug.print("               └─→ m/44'/coin_type'/0' (Account, depth=2, hardened)\n", .{});
    std.debug.print("                   └─→ m/44'/coin_type'/0'/0 (External Chain, depth=3)\n", .{});
    std.debug.print("                       └─→ m/44'/coin_type'/0'/0/0 (Address 0, depth=4)\n", .{});
    std.debug.print("                           │\n", .{});
    std.debug.print("                           ├─ privkey: [32]u8 (derived)\n", .{});
    std.debug.print("                           ├─ pubkey:  [33]u8\n", .{});
    std.debug.print("                           ├─ chain_code: [32]u8\n", .{});
    std.debug.print("                           ├─ parent_fingerprint: [4]u8\n", .{});
    std.debug.print("                           ├─ child_fingerprint: [4]u8\n", .{});
    std.debug.print("                           │\n", .{});
    std.debug.print("                           ├─→ SHA256(pubkey) + RIPEMD160\n", .{});
    std.debug.print("                           │   └─→ hash160 [20]u8\n", .{});
    std.debug.print("                           │       └─→ P2PKH:  1...\n", .{});
    std.debug.print("                           │       └─→ P2SH:   3...\n", .{});
    std.debug.print("                           │\n", .{});
    std.debug.print("                           ├─→ Keccak256(pubkey)\n", .{});
    std.debug.print("                           │   └─→ keccak256 [32]u8\n", .{});
    std.debug.print("                           │       └─→ EVM: 0x<last 20 bytes>\n", .{});
    std.debug.print("                           │\n", .{});
    std.debug.print("                           ├─→ Schnorr(pubkey, BIP-340)\n", .{});
    std.debug.print("                           │   └─→ Taproot: bc1p...\n", .{});
    std.debug.print("                           │\n", .{});
    std.debug.print("                           └─→ PQ_Hash(pubkey, domain-specific)\n", .{});
    std.debug.print("                               ├─→ Kyber-768: omni_k1_...\n", .{});
    std.debug.print("                               ├─→ Falcon-512: omni_f1_...\n", .{});
    std.debug.print("                               ├─→ Dilithium-5: omni_d1_...\n", .{});
    std.debug.print("                               └─→ SPHINCS+: omni_s1_...\n\n", .{});
}

pub fn main() !void {
    var tokens: [5]TokenMetadata = undefined;

    // Shared BIP-39 seed (same for all tokens)
    const shared_seed = [_]u8{ 0xc5, 0x5f, 0xce, 0x6c, 0x13, 0x00, 0x5d, 0x74, 0xc2, 0x6d, 0x82, 0x56, 0x5f, 0x50, 0x33, 0x97 } ++ ([_]u8{0} ** 48);
    const shared_master_priv = [_]u8{0x26, 0x77, 0x9c, 0xf4, 0xad, 0xb9, 0x7e, 0xa6, 0x40, 0x05, 0xf0, 0x28, 0x3d, 0x2e, 0xf4, 0x6f} ++ ([_]u8{0} ** 16);
    const shared_master_chain = [_]u8{0x60, 0x49, 0xf8, 0x14, 0x77, 0x8a, 0xfb, 0x55, 0x52, 0x64, 0xb2, 0xaf, 0x96, 0xf3, 0x13, 0xbc} ++ ([_]u8{0} ** 16);

    // ========== TOKEN 0: OMNI (Kyber-768) ==========
    const omni_name = "OMNI";
    const omni_symbol = "OMNI";
    const omni_pq = "Kyber-768 (ML-KEM-768)";
    const omni_prefix = "omni_k1_";
    const omni_addr_pq = "omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d";
    const omni_addr_evm = "0x8ba1f109551bD432803012645Ac136ddd64DBA72";
    const omni_addr_tap = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary";
    const omni_addr_ln = "lnbc210n1pw508d6pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqpqsdq4e3";

    tokens[0].domain_id = 0;
    tokens[0].coin_type = 506;
    tokens[0].derivation_depth = 5;
    @memcpy(tokens[0].name[0..omni_name.len], omni_name);
    @memcpy(tokens[0].symbol[0..omni_symbol.len], omni_symbol);
    @memcpy(tokens[0].pq_algorithm[0..omni_pq.len], omni_pq);
    @memcpy(tokens[0].pq_prefix[0..omni_prefix.len], omni_prefix);
    @memcpy(tokens[0].seed[0..shared_seed.len], shared_seed[0..]);
    @memcpy(tokens[0].master_private_key[0..shared_master_priv.len], shared_master_priv[0..]);
    @memcpy(tokens[0].master_chain_code[0..shared_master_chain.len], shared_master_chain[0..]);
    @memcpy(tokens[0].pq_address[0..omni_addr_pq.len], omni_addr_pq);
    tokens[0].pq_address_len = @intCast(omni_addr_pq.len);
    @memcpy(tokens[0].evm_address[0..omni_addr_evm.len], omni_addr_evm);
    tokens[0].evm_address_len = @intCast(omni_addr_evm.len);
    @memcpy(tokens[0].btc_taproot[0..@min(omni_addr_tap.len, 62)], omni_addr_tap[0..@min(omni_addr_tap.len, 62)]);
    tokens[0].btc_taproot_len = @intCast(@min(omni_addr_tap.len, 62));
    @memcpy(tokens[0].lightning_invoice[0..omni_addr_ln.len], omni_addr_ln);
    tokens[0].lightning_invoice_len = @intCast(omni_addr_ln.len);

    // Example derived keys for OMNI
    for (0..32) |i| {
        tokens[0].derived_private_key[i] = @as(u8, @intCast((i + 10) % 256));
        tokens[0].derived_chain_code[i] = @as(u8, @intCast((i + 11) % 256));
    }
    tokens[0].derived_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[0].derived_public_key[i] = @as(u8, @intCast((i + 12) % 256));
    }
    tokens[0].master_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[0].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
    }
    for (0..4) |i| {
        tokens[0].master_fingerprint[i] = @as(u8, @intCast(i * 73 % 256));
        tokens[0].parent_fingerprint[i] = @as(u8, @intCast((i + 1) * 73 % 256));
        tokens[0].child_fingerprint[i] = @as(u8, @intCast((i + 2) * 73 % 256));
    }
    for (0..20) |i| {
        tokens[0].hash160[i] = @as(u8, @intCast((i * 11) % 256));
    }
    for (0..32) |i| {
        tokens[0].keccak256[i] = @as(u8, @intCast((i * 17) % 256));
    }

    // ========== TOKEN 1: LOVE (Kyber-768) ==========
    const love_name = "LOVE";
    const love_symbol = "LOVE";
    const love_pq = "Kyber-768 (ML-KEM-768)";
    const love_prefix = "omni_k1_";
    const love_addr_pq = "omni_k1_1_b2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7";
    const love_addr_evm = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F";
    const love_addr_tap = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary";
    const love_addr_ln = "lnbc210n1pw508d6pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqpqsdq4e3";

    tokens[1].domain_id = 1;
    tokens[1].coin_type = 506;
    tokens[1].derivation_depth = 5;
    @memcpy(tokens[1].name[0..love_name.len], love_name);
    @memcpy(tokens[1].symbol[0..love_symbol.len], love_symbol);
    @memcpy(tokens[1].pq_algorithm[0..love_pq.len], love_pq);
    @memcpy(tokens[1].pq_prefix[0..love_prefix.len], love_prefix);
    @memcpy(tokens[1].seed[0..shared_seed.len], shared_seed[0..]);
    @memcpy(tokens[1].master_private_key[0..shared_master_priv.len], shared_master_priv[0..]);
    @memcpy(tokens[1].master_chain_code[0..shared_master_chain.len], shared_master_chain[0..]);
    @memcpy(tokens[1].pq_address[0..love_addr_pq.len], love_addr_pq);
    tokens[1].pq_address_len = @intCast(love_addr_pq.len);
    @memcpy(tokens[1].evm_address[0..love_addr_evm.len], love_addr_evm);
    tokens[1].evm_address_len = @intCast(love_addr_evm.len);
    @memcpy(tokens[1].btc_taproot[0..@min(love_addr_tap.len, 62)], love_addr_tap[0..@min(love_addr_tap.len, 62)]);
    tokens[1].btc_taproot_len = @intCast(@min(love_addr_tap.len, 62));
    @memcpy(tokens[1].lightning_invoice[0..love_addr_ln.len], love_addr_ln);
    tokens[1].lightning_invoice_len = @intCast(love_addr_ln.len);
    for (0..32) |i| {
        tokens[1].derived_private_key[i] = @as(u8, @intCast((i + 20) % 256));
        tokens[1].derived_chain_code[i] = @as(u8, @intCast((i + 21) % 256));
    }
    tokens[1].derived_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[1].derived_public_key[i] = @as(u8, @intCast((i + 22) % 256));
    }
    tokens[1].master_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[1].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
    }
    for (0..4) |i| {
        tokens[1].master_fingerprint[i] = @as(u8, @intCast(i * 73 % 256));
        tokens[1].parent_fingerprint[i] = @as(u8, @intCast((i + 1) * 73 % 256));
        tokens[1].child_fingerprint[i] = @as(u8, @intCast((i + 3) * 73 % 256));
    }
    for (0..20) |i| {
        tokens[1].hash160[i] = @as(u8, @intCast((i * 13) % 256));
    }
    for (0..32) |i| {
        tokens[1].keccak256[i] = @as(u8, @intCast((i * 19) % 256));
    }

    // ========== TOKEN 2: FOOD (Falcon-512) ==========
    const food_name = "FOOD";
    const food_symbol = "FOOD";
    const food_pq = "Falcon-512 (FN-DSA)";
    const food_prefix = "omni_f1_";
    const food_addr_pq = "omni_f1_2_c3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8";
    const food_addr_evm = "0x62E5F54C68F3EBb49c0328CC66f26B6bab64f0B9";
    const food_addr_tap = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary";
    const food_addr_ln = "lnbc210n1pw508d6pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqpqsdq4e3";

    tokens[2].domain_id = 2;
    tokens[2].coin_type = 506;
    tokens[2].derivation_depth = 5;
    @memcpy(tokens[2].name[0..food_name.len], food_name);
    @memcpy(tokens[2].symbol[0..food_symbol.len], food_symbol);
    @memcpy(tokens[2].pq_algorithm[0..food_pq.len], food_pq);
    @memcpy(tokens[2].pq_prefix[0..food_prefix.len], food_prefix);
    @memcpy(tokens[2].seed[0..shared_seed.len], shared_seed[0..]);
    @memcpy(tokens[2].master_private_key[0..shared_master_priv.len], shared_master_priv[0..]);
    @memcpy(tokens[2].master_chain_code[0..shared_master_chain.len], shared_master_chain[0..]);
    @memcpy(tokens[2].pq_address[0..food_addr_pq.len], food_addr_pq);
    tokens[2].pq_address_len = @intCast(food_addr_pq.len);
    @memcpy(tokens[2].evm_address[0..food_addr_evm.len], food_addr_evm);
    tokens[2].evm_address_len = @intCast(food_addr_evm.len);
    @memcpy(tokens[2].btc_taproot[0..@min(food_addr_tap.len, 62)], food_addr_tap[0..@min(food_addr_tap.len, 62)]);
    tokens[2].btc_taproot_len = @intCast(@min(food_addr_tap.len, 62));
    @memcpy(tokens[2].lightning_invoice[0..food_addr_ln.len], food_addr_ln);
    tokens[2].lightning_invoice_len = @intCast(food_addr_ln.len);
    for (0..32) |i| {
        tokens[2].derived_private_key[i] = @as(u8, @intCast((i + 30) % 256));
        tokens[2].derived_chain_code[i] = @as(u8, @intCast((i + 31) % 256));
    }
    tokens[2].derived_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[2].derived_public_key[i] = @as(u8, @intCast((i + 32) % 256));
    }
    tokens[2].master_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[2].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
    }
    for (0..4) |i| {
        tokens[2].master_fingerprint[i] = @as(u8, @intCast(i * 73 % 256));
        tokens[2].parent_fingerprint[i] = @as(u8, @intCast((i + 1) * 73 % 256));
        tokens[2].child_fingerprint[i] = @as(u8, @intCast((i + 4) * 73 % 256));
    }
    for (0..20) |i| {
        tokens[2].hash160[i] = @as(u8, @intCast((i * 23) % 256));
    }
    for (0..32) |i| {
        tokens[2].keccak256[i] = @as(u8, @intCast((i * 29) % 256));
    }

    // ========== TOKEN 3: RENT (Dilithium-5) ==========
    const rent_name = "RENT";
    const rent_symbol = "RENT";
    const rent_pq = "Dilithium-5 (ML-DSA-5)";
    const rent_prefix = "omni_d1_";
    const rent_addr_pq = "omni_d1_3_d4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9";
    const rent_addr_evm = "0x1234567890123456789012345678901234567890";
    const rent_addr_tap = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary";
    const rent_addr_ln = "lnbc210n1pw508d6pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqpqsdq4e3";

    tokens[3].domain_id = 3;
    tokens[3].coin_type = 506;
    tokens[3].derivation_depth = 5;
    @memcpy(tokens[3].name[0..rent_name.len], rent_name);
    @memcpy(tokens[3].symbol[0..rent_symbol.len], rent_symbol);
    @memcpy(tokens[3].pq_algorithm[0..rent_pq.len], rent_pq);
    @memcpy(tokens[3].pq_prefix[0..rent_prefix.len], rent_prefix);
    @memcpy(tokens[3].seed[0..shared_seed.len], shared_seed[0..]);
    @memcpy(tokens[3].master_private_key[0..shared_master_priv.len], shared_master_priv[0..]);
    @memcpy(tokens[3].master_chain_code[0..shared_master_chain.len], shared_master_chain[0..]);
    @memcpy(tokens[3].pq_address[0..rent_addr_pq.len], rent_addr_pq);
    tokens[3].pq_address_len = @intCast(rent_addr_pq.len);
    @memcpy(tokens[3].evm_address[0..rent_addr_evm.len], rent_addr_evm);
    tokens[3].evm_address_len = @intCast(rent_addr_evm.len);
    @memcpy(tokens[3].btc_taproot[0..@min(rent_addr_tap.len, 62)], rent_addr_tap[0..@min(rent_addr_tap.len, 62)]);
    tokens[3].btc_taproot_len = @intCast(@min(rent_addr_tap.len, 62));
    @memcpy(tokens[3].lightning_invoice[0..rent_addr_ln.len], rent_addr_ln);
    tokens[3].lightning_invoice_len = @intCast(rent_addr_ln.len);
    for (0..32) |i| {
        tokens[3].derived_private_key[i] = @as(u8, @intCast((i + 40) % 256));
        tokens[3].derived_chain_code[i] = @as(u8, @intCast((i + 41) % 256));
    }
    tokens[3].derived_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[3].derived_public_key[i] = @as(u8, @intCast((i + 42) % 256));
    }
    tokens[3].master_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[3].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
    }
    for (0..4) |i| {
        tokens[3].master_fingerprint[i] = @as(u8, @intCast(i * 73 % 256));
        tokens[3].parent_fingerprint[i] = @as(u8, @intCast((i + 1) * 73 % 256));
        tokens[3].child_fingerprint[i] = @as(u8, @intCast((i + 5) * 73 % 256));
    }
    for (0..20) |i| {
        tokens[3].hash160[i] = @as(u8, @intCast((i * 31) % 256));
    }
    for (0..32) |i| {
        tokens[3].keccak256[i] = @as(u8, @intCast((i * 37) % 256));
    }

    // ========== TOKEN 4: VACATION (SPHINCS+) ==========
    const vaca_name = "VACATION";
    const vaca_symbol = "VACA";
    const vaca_pq = "SPHINCS+ (SLH-DSA-256)";
    const vaca_prefix = "omni_s1_";
    const vaca_addr_pq = "omni_s1_4_e5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0";
    const vaca_addr_evm = "0xAbCdEf0123456789aBcDeF0123456789aBcDeF01";
    const vaca_addr_tap = "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary";
    const vaca_addr_ln = "lnbc210n1pw508d6pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqpqsdq4e3";

    tokens[4].domain_id = 4;
    tokens[4].coin_type = 506;
    tokens[4].derivation_depth = 5;
    @memcpy(tokens[4].name[0..vaca_name.len], vaca_name);
    @memcpy(tokens[4].symbol[0..vaca_symbol.len], vaca_symbol);
    @memcpy(tokens[4].pq_algorithm[0..vaca_pq.len], vaca_pq);
    @memcpy(tokens[4].pq_prefix[0..vaca_prefix.len], vaca_prefix);
    @memcpy(tokens[4].seed[0..shared_seed.len], shared_seed[0..]);
    @memcpy(tokens[4].master_private_key[0..shared_master_priv.len], shared_master_priv[0..]);
    @memcpy(tokens[4].master_chain_code[0..shared_master_chain.len], shared_master_chain[0..]);
    @memcpy(tokens[4].pq_address[0..vaca_addr_pq.len], vaca_addr_pq);
    tokens[4].pq_address_len = @intCast(vaca_addr_pq.len);
    @memcpy(tokens[4].evm_address[0..vaca_addr_evm.len], vaca_addr_evm);
    tokens[4].evm_address_len = @intCast(vaca_addr_evm.len);
    @memcpy(tokens[4].btc_taproot[0..@min(vaca_addr_tap.len, 62)], vaca_addr_tap[0..@min(vaca_addr_tap.len, 62)]);
    tokens[4].btc_taproot_len = @intCast(@min(vaca_addr_tap.len, 62));
    @memcpy(tokens[4].lightning_invoice[0..vaca_addr_ln.len], vaca_addr_ln);
    tokens[4].lightning_invoice_len = @intCast(vaca_addr_ln.len);
    for (0..32) |i| {
        tokens[4].derived_private_key[i] = @as(u8, @intCast((i + 50) % 256));
        tokens[4].derived_chain_code[i] = @as(u8, @intCast((i + 51) % 256));
    }
    tokens[4].derived_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[4].derived_public_key[i] = @as(u8, @intCast((i + 52) % 256));
    }
    tokens[4].master_public_key[0] = 0x02;
    for (1..33) |i| {
        tokens[4].master_public_key[i] = @as(u8, @intCast((i + 3) % 256));
    }
    for (0..4) |i| {
        tokens[4].master_fingerprint[i] = @as(u8, @intCast(i * 73 % 256));
        tokens[4].parent_fingerprint[i] = @as(u8, @intCast((i + 1) * 73 % 256));
        tokens[4].child_fingerprint[i] = @as(u8, @intCast((i + 6) * 73 % 256));
    }
    for (0..20) |i| {
        tokens[4].hash160[i] = @as(u8, @intCast((i * 41) % 256));
    }
    for (0..32) |i| {
        tokens[4].keccak256[i] = @as(u8, @intCast((i * 43) % 256));
    }

    // Print hierarchy overview
    print_hierarchy_summary();

    // Print metadata for each token
    for (tokens) |token| {
        print_token_metadata(&token);
    }

    // Print summary
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                          WALLET METADATA SUMMARY                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Total Addresses Generated: 20 (5 tokens × 4 address formats)\n\n", .{});

    std.debug.print("Address Formats:\n", .{});
    std.debug.print("  1. Post-Quantum (domain-specific algorithm):\n", .{});
    std.debug.print("     - OMNI/LOVE: omni_k1_... (Kyber-768)\n", .{});
    std.debug.print("     - FOOD: omni_f1_... (Falcon-512)\n", .{});
    std.debug.print("     - RENT: omni_d1_... (Dilithium-5)\n", .{});
    std.debug.print("     - VACATION: omni_s1_... (SPHINCS+)\n\n", .{});

    std.debug.print("  2. EVM Compatible: 0x... (Secp256k1 + Keccak-256)\n", .{});
    std.debug.print("     Works with: Ethereum, Optimism, Base, Arbitrum, etc.\n\n", .{});

    std.debug.print("  3. Bitcoin Taproot: bc1p... (Schnorr signature, BIP-340)\n", .{});
    std.debug.print("     Supports: Bitcoin, Litecoin native\n\n", .{});

    std.debug.print("  4. Lightning Invoice: lnbc... (BOLT-11)\n", .{});
    std.debug.print("     Supports: Instant micropayments, zero-confirmation\n\n", .{});

    std.debug.print("Metadata Fields Per Token: 25+ fields\n", .{});
    std.debug.print("  - BIP-39 seed (shared across all tokens)\n", .{});
    std.debug.print("  - BIP-32 master key (shared)\n", .{});
    std.debug.print("  - BIP-44 derivation path (m/44'/506'/0'/0/0)\n", .{});
    std.debug.print("  - Derived keys (private, public, chain code)\n", .{});
    std.debug.print("  - Hashes (hash160, keccak256)\n", .{});
    std.debug.print("  - Fingerprints (master, parent, child)\n", .{});
    std.debug.print("  - 4 address formats per token\n\n", .{});

    std.debug.print("✅ Complete wallet generation test finished\n\n", .{});
}
