// Example: Generate wallets with different mnemonics and passphrases
// Shows how passphrase creates completely different wallets from same seed

const std = @import("std");
const WalletGenerator = @import("universal_wallet_generator.zig").WalletGenerator;

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
    const wallet1 = WalletGenerator.generate_from_mnemonic(mnemonic_12);
    std.debug.print("│ Bitcoin:    {s}\n", .{wallet1.chain_accounts[3].utxo_address[0..20]});
    std.debug.print("│ Ethereum:   {s}\n", .{wallet1.chain_accounts[4].evm_address[0..10]});
    std.debug.print("│ Solana:     {s}\n", .{wallet1.chain_accounts[5].evm_address[0..10]});
    std.debug.print("└─\n\n", .{});

    // Example 2: Same 12-word mnemonic WITH passphrase
    std.debug.print("┌─ Example 2: Same 12-Word Mnemonic + Passphrase\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_12});
    std.debug.print("│ Passphrase: \"MySecurePass123\"\n", .{});
    std.debug.print("│\n", .{});
    const wallet2 = WalletGenerator.generate_from_mnemonic_with_passphrase(mnemonic_12, "MySecurePass123");
    std.debug.print("│ Bitcoin:    {s}\n", .{wallet2.chain_accounts[3].utxo_address[0..20]});
    std.debug.print("│ Ethereum:   {s}\n", .{wallet2.chain_accounts[4].evm_address[0..10]});
    std.debug.print("│ Solana:     {s}\n", .{wallet2.chain_accounts[5].evm_address[0..10]});
    std.debug.print("│\n", .{});
    std.debug.print("│ ⚠️  COMPLETELY DIFFERENT from Example 1!\n", .{});
    std.debug.print("└─\n\n", .{});

    // Example 3: Different passphrase = different wallet
    std.debug.print("┌─ Example 3: Same Mnemonic + Different Passphrase\n", .{});
    std.debug.print("│\n", .{});
    std.debug.print("│ Mnemonic: {s}\n", .{mnemonic_12});
    std.debug.print("│ Passphrase: \"AnotherPass456\"\n", .{});
    std.debug.print("│\n", .{});
    const wallet3 = WalletGenerator.generate_from_mnemonic_with_passphrase(mnemonic_12, "AnotherPass456");
    std.debug.print("│ Bitcoin:    {s}\n", .{wallet3.chain_accounts[3].utxo_address[0..20]});
    std.debug.print("│ Ethereum:   {s}\n", .{wallet3.chain_accounts[4].evm_address[0..10]});
    std.debug.print("│ Solana:     {s}\n", .{wallet3.chain_accounts[5].evm_address[0..10]});
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
    const wallet4 = WalletGenerator.generate_from_mnemonic(mnemonic_24);
    std.debug.print("│ Bitcoin:    {s}\n", .{wallet4.chain_accounts[3].utxo_address[0..20]});
    std.debug.print("│ Ethereum:   {s}\n", .{wallet4.chain_accounts[4].evm_address[0..10]});
    std.debug.print("│ Solana:     {s}\n", .{wallet4.chain_accounts[5].evm_address[0..10]});
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
