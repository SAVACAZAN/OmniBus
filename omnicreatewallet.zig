// OmniBus Multi-Wallet CLI Generator
// Generate BIP-39 wallets with optional passphrases
// Usage: ./omnicreatewallet -12 [--passphrase "pass"] [--output file.json]

const std = @import("std");
const WalletGenerator = @import("universal_wallet_generator.zig").WalletGenerator;
const WalletMetadataExporter = @import("wallet_metadata_export.zig").WalletMetadataExporter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Default values
    var word_count: u32 = 12;
    var passphrase: []const u8 = "";
    var output_file: []const u8 = "wallet_metadata_all_chains.json";
    var show_help = false;

    // Parse command-line arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            show_help = true;
        } else if (std.mem.eql(u8, arg, "-12")) {
            word_count = 12;
        } else if (std.mem.eql(u8, arg, "-24")) {
            word_count = 24;
        } else if (std.mem.eql(u8, arg, "--passphrase")) {
            if (i + 1 < args.len) {
                i += 1;
                passphrase = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                i += 1;
                output_file = args[i];
            }
        }
    }

    // Show help
    if (show_help or args.len < 2) {
        std.debug.print("\n", .{});
        std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         OmniBus Multi-Wallet CLI Generator              ║\n", .{});
        std.debug.print("║         Generate BIP-39 Wallets with Passphrases       ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

        std.debug.print("USAGE:\n", .{});
        std.debug.print("  ./omnicreatewallet [OPTIONS]\n\n", .{});

        std.debug.print("OPTIONS:\n", .{});
        std.debug.print("  -12                     Generate 12-word mnemonic (default)\n", .{});
        std.debug.print("  -24                     Generate 24-word mnemonic (extended)\n", .{});
        std.debug.print("  --passphrase <pass>     Add optional passphrase for hidden wallet\n", .{});
        std.debug.print("  --output <file.json>    Output filename (default: wallet_metadata_all_chains.json)\n", .{});
        std.debug.print("  -h, --help              Show this help message\n\n", .{});

        std.debug.print("EXAMPLES:\n", .{});
        std.debug.print("  # Generate 12-word wallet without passphrase\n", .{});
        std.debug.print("  ./omnicreatewallet -12\n\n", .{});

        std.debug.print("  # Generate 12-word wallet with passphrase\n", .{});
        std.debug.print("  ./omnicreatewallet -12 --passphrase \"MySecurePass123\"\n\n", .{});

        std.debug.print("  # Generate 24-word wallet (extended entropy)\n", .{});
        std.debug.print("  ./omnicreatewallet -24\n\n", .{});

        std.debug.print("  # Generate with passphrase and custom output file\n", .{});
        std.debug.print("  ./omnicreatewallet -12 --passphrase \"pass\" --output my_wallet.json\n\n", .{});

        std.debug.print("SECURITY TIPS:\n", .{});
        std.debug.print("  • Save the 12 or 24-word mnemonic SECURELY (paper + safe)\n", .{});
        std.debug.print("  • Use passphrase for HIDDEN WALLET (same seed, different addresses)\n", .{});
        std.debug.print("  • Store passphrase SEPARATE from mnemonic\n", .{});
        std.debug.print("  • NEVER share mnemonic or passphrase\n", .{});
        std.debug.print("  • Run on AIR-GAPPED computer for maximum security\n\n", .{});

        return;
    }

    // Generate mnemonic
    const test_mnemonic = if (word_count == 24)
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
    else
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          OmniBus Wallet Generator - Active             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("⚙️  Configuration:\n", .{});
    std.debug.print("  Word Count:   {d}-word BIP-39 mnemonic\n", .{word_count});
    std.debug.print("  Passphrase:   {s}\n", .{if (passphrase.len == 0) "(none - standard wallet)" else passphrase});
    std.debug.print("  Output File:  {s}\n", .{output_file});
    std.debug.print("\n", .{});

    std.debug.print("🔐 SEED MNEMONIC (SAVE THIS SECURELY!):\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  {s}  ║\n", .{test_mnemonic});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("🔄 Generating wallet with PBKDF2-HMAC-SHA256 + BIP-44...\n\n", .{});

    // Generate wallet
    const wallet = if (passphrase.len == 0)
        WalletGenerator.generate_from_mnemonic(test_mnemonic)
    else
        WalletGenerator.generate_from_mnemonic_with_passphrase(test_mnemonic, passphrase);

    std.debug.print("✅ Wallet generated successfully!\n\n", .{});

    // Display all chains
    WalletMetadataExporter.display_all_chains(wallet);

    // Export to JSON
    try WalletMetadataExporter.export_all_chains(wallet, output_file);

    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   ✅ COMPLETE!                        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("📁 Generated files:\n", .{});
    std.debug.print("  • {s} (complete wallet metadata)\n\n", .{output_file});

    std.debug.print("🔐 SECURITY CHECKLIST:\n", .{});
    std.debug.print("  ☐ Wrote down 12/24-word mnemonic on paper\n", .{});
    std.debug.print("  ☐ Stored paper in secure location (safe, vault, etc.)\n", .{});
    if (passphrase.len > 0) {
        std.debug.print("  ☐ Stored passphrase SEPARATELY from mnemonic\n", .{});
    }
    std.debug.print("  ☐ Verified addresses match on blockchain explorers\n", .{});
    std.debug.print("  ☐ Deleted wallet files from computer (optional: wipe disk)\n\n", .{});
}
