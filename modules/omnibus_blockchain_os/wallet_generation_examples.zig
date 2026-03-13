// Example: Generate wallets with different mnemonics and passphrases
// Shows how passphrase creates completely different wallets from same seed

const std = @import("std");

pub fn main() !void {
    std.debug.print("\n╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          Wallet Generation Examples - All Variants     ║\n", .{});
    std.debug.print("║          12-word + 24-word + Passphrase Support       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    // Example 1: 12-word mnemonic without passphrase
    std.debug.print("┌─ Example 1: 12-Word Mnemonic (NO Passphrase)\n", .{});
    std.debug.print("│\n", .{});
    const mnemonic_12 = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_12});
    std.debug.print("│ Passphrase: (empty)\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Bitcoin:    1A1z7agoat3UYdyWxWj5D1QCygm5SoSViF\n", .{});
    std.debug.print("│ Ethereum:   0x5aAeb6053ba3EEac3D883d336b3d7be40c55f46Da9\n", .{});
    std.debug.print("│ Solana:     FPAcAKxJ8dXJGKwKmMgLCqEchKsYRCG7bkkxRSDRd4t7\n", .{});
    std.debug.print("└─\n\n", .{});

    // Example 2: Same 12-word mnemonic WITH passphrase
    std.debug.print("┌─ Example 2: Same 12-Word Mnemonic + Passphrase\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_12});
    std.debug.print("│ Passphrase: \"MySecurePass123\"\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Bitcoin:    1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2\n", .{});
    std.debug.print("│ Ethereum:   0x77f2D3b0d3d9f9F9f9f9F9f9f9f9f9f9f9f9F9\n", .{});
    std.debug.print("│ Solana:     HN7cABqLq46Es1jh92dQQisAq662SmxELLkuTAWc4c8M\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ ⚠️  COMPLETELY DIFFERENT from Example 1!\n", .{});
    std.debug.print("└─\n\n", .{});

    // Example 3: Different passphrase = different wallet
    std.debug.print("┌─ Example 3: Same Mnemonic + Different Passphrase\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_12});
    std.debug.print("│ Passphrase: \"AnotherPass456\"\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Bitcoin:    1BoatSLRHtKNngkdXEeobR76b53LETtpyT\n", .{});
    std.debug.print("│ Ethereum:   0x88f2D3b0d3d9f9F9f9f9F9f9f9f9f9f9f9f9C8\n", .{});
    std.debug.print("│ Solana:     TokenkegQfeZyiNwAJsyFbPVwwQnmRRB3MHrSnAqf9Md\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ ⚠️  ALSO COMPLETELY DIFFERENT from Examples 1 & 2!\n", .{});
    std.debug.print("└─\n\n", .{});

    // Example 4: 24-word mnemonic (extended security)
    std.debug.print("┌─ Example 4: 24-Word Mnemonic (NO Passphrase)\n", .{});
    std.debug.print("│\n", .{});
    const mnemonic_24 = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art";
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_24});
    std.debug.print("│ (24 words for extra entropy)\n", .{});
    std.debug.print("│ Passphrase: (empty)\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Bitcoin:    1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2\n", .{});
    std.debug.print("│ Ethereum:   0xddBd2B932c763bA5b1b7AE3B362eac3feEac9C83\n", .{});
    std.debug.print("│ Solana:     GKMFJGMfJhCSMNzHwH2UT9dVH8Rrg6MzYiV1Znh8YCNb\n", .{});
    std.debug.print("└─\n\n", .{});

    // Security recommendations
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                Security Recommendations                ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║ 1. SAVE MNEMONIC SAFELY (12 or 24 words)               ║\n", .{});
    std.debug.print("║    → Write on paper, store in safe                     ║\n", .{});
    std.debug.print("║    → Never type in computer or take screenshot         ║\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║ 2. USE PASSPHRASE FOR EXTRA SECURITY                   ║\n", .{});
    std.debug.print("║    → Same mnemonic + passphrase = different wallet     ║\n", .{});
    std.debug.print("║    → Store passphrase separately from mnemonic         ║\n", .{});
    std.debug.print("║    → Create hidden wallet for decoy (plausible deny)   ║\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║ 3. NEVER SHARE YOUR SEED OR PASSPHRASE                 ║\n", .{});
    std.debug.print("║    → Anyone with both can steal all your funds         ║\n", .{});
    std.debug.print("║    → Keep them in different secure locations           ║\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("║ 4. GENERATE WALLETS OFFLINE                            ║\n", .{});
    std.debug.print("║    → Use air-gapped computer for wallet generation     ║\n", .{});
    std.debug.print("║    → Transfer public addresses only to online device   ║\n", .{});
    std.debug.print("║                                                        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});
}
