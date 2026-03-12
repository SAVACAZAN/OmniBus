// Universal Wallet Generator Integration Test
// Real cryptographic derivation for all 20+ blockchains + post-quantum domains
const std = @import("std");

const WalletGenerator = @import("universal_wallet_generator.zig").WalletGenerator;
const SUPPORTED_CHAINS = @import("universal_wallet_generator.zig").SUPPORTED_CHAINS;
const WalletMetadataExporter = @import("wallet_metadata_export.zig").WalletMetadataExporter;


pub fn main() !void {
    std.debug.print(
        \\
        \\╔════════════════════════════════════════════════════════════╗
        \\║  OmniBus Wallet - Complete Multi-Chain Metadata Generator ║
        \\║  All 20+ Blockchains + Post-Quantum Domains               ║
        \\║  Real PBKDF2-HMAC-SHA256 Cryptography                    ║
        \\╚════════════════════════════════════════════════════════════╝
        \\
        , .{});

    // Test Mnemonic (12 words BIP-39)
    const test_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    std.debug.print("📝 Mnemonic (BIP-39):\n{s}\n\n", .{test_mnemonic});
    std.debug.print("🔐 Generating wallet with PBKDF2-HMAC-SHA256 + HMAC-SHA256...\n\n", .{});

    const wallet = WalletGenerator.generate_from_mnemonic(test_mnemonic);

    std.debug.print("✅ Wallet generated successfully!\n\n", .{});

    // Display mnemonic seed (save this!)
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║            🔐 SAVE THIS SEED SAFELY 🔐                 ║\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║  {s}  ║\n", .{test_mnemonic});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║  This 12-word mnemonic generates ALL your private keys ║\n", .{});
    std.debug.print("║  for Bitcoin, Ethereum, Solana, and 17+ blockchains.   ║\n", .{});
    std.debug.print("║  Keep it safe. Never share it. Never enter it online.  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    // Display all chains metadata to console
    WalletMetadataExporter.display_all_chains(wallet);

    // Export complete metadata to JSON file
    try WalletMetadataExporter.export_all_chains(wallet, "wallet_metadata_all_chains.json");

    std.debug.print("✅ Test Suite Complete\n\n", .{});
}
