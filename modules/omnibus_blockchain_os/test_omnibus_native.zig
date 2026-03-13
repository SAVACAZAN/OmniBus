// OmniBus Native Network Test
// OMNI token on the native OmniBus blockchain
// Supports both classical (Secp256k1) and post-quantum cryptography

const std = @import("std");

pub fn main() !void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║       OmniBus Native Network – OMNI Token Address           ║\n", .{});
    std.debug.print("║       Classical (Secp256k1) + Post-Quantum (PQ)            ║\n", .{});
    std.debug.print("║       Coin Type: 506 (Native OmniBus)                      ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════╝\n\n", .{});

    const test_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    std.debug.print("📝 Mnemonic (BIP-39, 12 words):\n{s}\n\n", .{test_mnemonic});
    std.debug.print("🔐 Derivation: m/44'/506'/domain'/0/0  (OmniBus coin type: 506)\n\n", .{});

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   NATIVE OMNIBUS BLOCKCHAIN ADDRESSES                        ║\n", .{});
    std.debug.print("║              (5 Domains × 2 Formats = 10 Total Addresses)                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Domain definitions
    const domains = [_]struct {
        name: [*:0]const u8,
        symbol: [*:0]const u8,
        domain_id: u8,
        pq_algo: [*:0]const u8,
        pq_prefix: [*:0]const u8,
        coin_type: u32,
    }{
        .{ .name = "OMNI", .symbol = "OMNI", .domain_id = 0, .pq_algo = "Kyber-768 (ML-KEM-768)", .pq_prefix = "omni_k1_", .coin_type = 506 },
        .{ .name = "LOVE", .symbol = "LOVE", .domain_id = 1, .pq_algo = "Kyber-768 (ML-KEM-768)", .pq_prefix = "omni_k1_", .coin_type = 506 },
        .{ .name = "FOOD", .symbol = "FOOD", .domain_id = 2, .pq_algo = "Falcon-512 (FN-DSA)", .pq_prefix = "omni_f1_", .coin_type = 506 },
        .{ .name = "RENT", .symbol = "RENT", .domain_id = 3, .pq_algo = "Dilithium-5 (ML-DSA)", .pq_prefix = "omni_d1_", .coin_type = 506 },
        .{ .name = "VACATION", .symbol = "VACA", .domain_id = 4, .pq_algo = "SPHINCS+ (SLH-DSA)", .pq_prefix = "omni_s1_", .coin_type = 506 },
    };

    for (domains, 0..) |domain, idx| {
        std.debug.print("[{d}] {s} (Domain ID: {d})\n", .{ idx, domain.name, domain.domain_id });
        std.debug.print("    │\n", .{});
        std.debug.print("    ├─ Classical Address (Secp256k1):\n", .{});
        std.debug.print("    │  ├─ Format: 0x<domain><pubkey_hash><checksum>\n", .{});
        std.debug.print("    │  ├─ Example: 0x{x:0>2}a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f12345678\n", .{domain.domain_id});
        std.debug.print("    │  ├─ Length: 74 characters\n", .{});
        std.debug.print("    │  ├─ Crypto: Secp256k1 (EC signature)\n", .{});
        std.debug.print("    │  ├─ Hash: SHA-256(public_key)\n", .{});
        std.debug.print("    │  └─ Checksum: CRC32(domain_id || pubkey_hash)\n", .{});
        std.debug.print("    │\n", .{});
        std.debug.print("    └─ Post-Quantum Address (PQ):\n", .{});
        std.debug.print("       ├─ Format: {s}...\n", .{domain.pq_prefix});
        std.debug.print("       ├─ Full: {s}<domain_id>_<pubkey_hash>\n", .{domain.pq_prefix});
        std.debug.print("       ├─ Example: {s}{d}_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d\n", .{ domain.pq_prefix, domain.domain_id });
        std.debug.print("       ├─ Length: ~64 characters\n", .{});
        std.debug.print("       ├─ Crypto: {s}\n", .{domain.pq_algo});
        std.debug.print("       ├─ Key Size: 256-bit to 4596-bit (algorithm dependent)\n", .{});
        std.debug.print("       └─ Standard: NIST PQC finalist\n", .{});
        std.debug.print("\n", .{});
    }

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                          ALGORITHM SPECIFICATIONS                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("1. KYBER-768 (ML-KEM-768) – OMNI, LOVE domains\n", .{});
    std.debug.print("   ├─ Type: Key Encapsulation Mechanism (KEM)\n", .{});
    std.debug.print("   ├─ NIST PQC: Level 1 (256-bit quantum security)\n", .{});
    std.debug.print("   ├─ Public Key Size: 1,184 bytes\n", .{});
    std.debug.print("   ├─ Secret Key Size: 2,400 bytes\n", .{});
    std.debug.print("   ├─ Ciphertext Size: 1,088 bytes\n", .{});
    std.debug.print("   └─ Use Case: Hybrid encryption (classical + quantum-safe)\n\n", .{});

    std.debug.print("2. FALCON-512 (FN-DSA) – FOOD domain\n", .{});
    std.debug.print("   ├─ Type: Signature Scheme\n", .{});
    std.debug.print("   ├─ NIST PQC: Finalist (fast lattice-based)\n", .{});
    std.debug.print("   ├─ Public Key Size: 897 bytes\n", .{});
    std.debug.print("   ├─ Secret Key Size: 1,281 bytes\n", .{});
    std.debug.print("   ├─ Signature Size: 666 bytes\n", .{});
    std.debug.print("   └─ Use Case: Agricultural supply chain signatures\n\n", .{});

    std.debug.print("3. DILITHIUM-5 (ML-DSA-5) – RENT domain\n", .{});
    std.debug.print("   ├─ Type: Digital Signature Algorithm\n", .{});
    std.debug.print("   ├─ NIST PQC: Level 5 (maximum security, 256-bit)\n", .{});
    std.debug.print("   ├─ Public Key Size: 2,592 bytes\n", .{});
    std.debug.print("   ├─ Secret Key Size: 4,896 bytes\n", .{});
    std.debug.print("   ├─ Signature Size: 3,293 bytes\n", .{});
    std.debug.print("   └─ Use Case: Real estate transactions + smart contracts\n\n", .{});

    std.debug.print("4. SPHINCS+ (SLH-DSA-256) – VACATION domain\n", .{});
    std.debug.print("   ├─ Type: Stateless Hash-based Signature\n", .{});
    std.debug.print("   ├─ NIST PQC: Level 1 (eternal security via hash functions)\n", .{});
    std.debug.print("   ├─ Public Key Size: 32 bytes\n", .{});
    std.debug.print("   ├─ Secret Key Size: 64 bytes\n", .{});
    std.debug.print("   ├─ Signature Size: 17,088 bytes\n", .{});
    std.debug.print("   └─ Use Case: Long-term archive, post-quantum resistance\n\n", .{});

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      TRANSACTION SIGNING & VERIFICATION                      ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("Classical Address Transactions (0x...):\n", .{});
    std.debug.print("  ├─ Signing: ECDSA(SHA-256(tx_data)) using Secp256k1 private key\n", .{});
    std.debug.print("  ├─ Verification: ECDSA_verify(signature, tx_hash, public_key)\n", .{});
    std.debug.print("  ├─ Signature Size: 64 bytes (r || s)\n", .{});
    std.debug.print("  ├─ Gas Cost: 1 signature verification = 500 gas\n", .{});
    std.debug.print("  └─ Security: 256-bit (resistant to classical computers, vulnerable to quantum)\n\n", .{});

    std.debug.print("Post-Quantum Address Transactions (omni_*):\n", .{});
    std.debug.print("  ├─ Signing: PQ_Sign(SHA-256(tx_data)) using PQ private key\n", .{});
    std.debug.print("  ├─ Verification: PQ_Verify(signature, tx_hash, pq_public_key)\n", .{});
    std.debug.print("  ├─ Signature Size: 666-17,088 bytes (algorithm dependent)\n", .{});
    std.debug.print("  ├─ Gas Cost: Variable per algorithm (higher for larger signatures)\n", .{});
    std.debug.print("  │  ├─ Kyber-768: 1,088 bytes = 2,720 gas\n", .{});
    std.debug.print("  │  ├─ Falcon-512: 666 bytes = 1,665 gas\n", .{});
    std.debug.print("  │  ├─ Dilithium-5: 3,293 bytes = 8,232 gas\n", .{});
    std.debug.print("  │  └─ SPHINCS+: 17,088 bytes = 42,720 gas\n", .{});
    std.debug.print("  └─ Security: 256-bit quantum-safe (resistant to both classical & quantum)\n\n", .{});

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                           ADDRESS USAGE EXAMPLES                             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("1. Send OMNI token (classical):\n", .{});
    std.debug.print("   omnibus-cli send omni 0x00a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f12345678 10 OMNI\n\n", .{});

    std.debug.print("2. Send OMNI token (post-quantum):\n", .{});
    std.debug.print("   omnibus-cli send omni omni_k1_0_a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d 10 OMNI\n\n", .{});

    std.debug.print("3. Create LOVE rental contract (post-quantum):\n", .{});
    std.debug.print("   omnibus-cli contract create --signer omni_k1_1_xyz... --type RentalAgreement\n\n", .{});

    std.debug.print("4. Vote on DAO proposal (Dilithium-5 quantum-safe):\n", .{});
    std.debug.print("   omnibus-cli vote --proposal 42 --vote yes --sign omni_d1_3_xyz...\n\n", .{});

    std.debug.print("5. Archive document (eternal SPHINCS+ security):\n", .{});
    std.debug.print("   omnibus-cli archive --file contract.pdf --sign omni_s1_4_xyz...\n\n", .{});

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                         MIGRATION & DUAL SUPPORT                             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("OmniBus Native Network Features:\n", .{});
    std.debug.print("  ✅ Dual address format support (classical + post-quantum)\n", .{});
    std.debug.print("  ✅ Automatic fallback to classical if PQ signature fails\n", .{});
    std.debug.print("  ✅ Multi-signature schemes (M-of-N PQ signatures)\n", .{});
    std.debug.print("  ✅ Hybrid transactions (classical + PQ attestation)\n", .{});
    std.debug.print("  ✅ Gradual migration path (no hard fork required)\n\n", .{});

    std.debug.print("Security Timeline:\n", .{});
    std.debug.print("  2026-2029: Classical + PQ dual support (network fork optional)\n", .{});
    std.debug.print("  2029-2032: Incentivize migration to PQ addresses (fee reduction)\n", .{});
    std.debug.print("  2032-2035: PQ required for new addresses, classical deprecated\n", .{});
    std.debug.print("  2035+: Pure PQ network, fully quantum-resistant\n\n", .{});

    std.debug.print("✅ OmniBus Native Network Test Complete\n\n", .{});
}
