// Wallet Metadata Export Module
// Reusable across OmniBus modules for complete wallet metadata generation
// Supports all 20+ blockchains + 4 post-quantum domains

const std = @import("std");
const WalletAccount = @import("universal_wallet_generator.zig").WalletAccount;
const SUPPORTED_CHAINS = @import("universal_wallet_generator.zig").SUPPORTED_CHAINS;

pub const WalletMetadataExporter = struct {
    pub fn format_hex(bytes: []const u8, buf: []u8) []u8 {
        const hex_chars = "0123456789abcdef";
        var i: usize = 0;
        for (bytes) |b| {
            if (i + 1 >= buf.len) break;
            buf[i] = hex_chars[b >> 4];
            buf[i + 1] = hex_chars[b & 0xf];
            i += 2;
        }
        return buf[0..i];
    }

    /// Export all chains metadata to JSON file
    /// Usage: try WalletMetadataExporter.export_all_chains(wallet, "output.json");
    pub fn export_all_chains(wallet: WalletAccount, filename: []const u8) !void {
        var json_buffer: [65536]u8 = undefined;
        var json_offset: usize = 0;

        // JSON header
        const json_header = "{\n  \"mnemonic\": \"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about\",\n  \"total_chains\": ";
        @memcpy(json_buffer[json_offset..][0..json_header.len], json_header);
        json_offset += json_header.len;

        // Count
        var count_str: [10]u8 = undefined;
        const count_fmt = std.fmt.bufPrint(&count_str, "{d}", .{SUPPORTED_CHAINS.len}) catch "";
        @memcpy(json_buffer[json_offset..][0..count_fmt.len], count_fmt);
        json_offset += count_fmt.len;

        const chains_header = ",\n  \"chains\": [\n";
        @memcpy(json_buffer[json_offset..][0..chains_header.len], chains_header);
        json_offset += chains_header.len;

        // Loop through all chains
        for (wallet.chain_accounts, 0..) |account, idx| {
            const chain = SUPPORTED_CHAINS[idx];

            var hex_buf: [256]u8 = undefined;
            const priv_hex = format_hex(account.evm_private_key[0..], &hex_buf);
            var pub_hex: [256]u8 = undefined;
            const pub_hex_str = format_hex(account.evm_public_key[0..], &pub_hex);

            const pq_len = std.mem.indexOfScalar(u8, &account.pq_address, 0) orelse account.pq_address.len;

            // Select native address based on chain type
            var native_addr: []const u8 = "";
            if (chain.address_format == .UTXO) {
                const utxo_len = std.mem.indexOfScalar(u8, &account.utxo_address, 0) orelse account.utxo_address.len;
                native_addr = account.utxo_address[0..utxo_len];
            } else {
                const evm_len = std.mem.indexOfScalar(u8, &account.evm_address, 0) orelse account.evm_address.len;
                native_addr = account.evm_address[0..evm_len];
            }

            const comma = if (idx < SUPPORTED_CHAINS.len - 1) ",\n" else "\n";

            const entry = std.fmt.bufPrint(json_buffer[json_offset..],
                "    {{\n      \"index\": {d},\n      \"chain\": \"{s}\",\n      \"chain_id\": {d},\n      \"coin_type\": {d},\n      \"address\": \"{s}\",\n      \"address_pq\": \"{s}\",\n      \"private_key_hex\": \"{s}\",\n      \"public_key_hex\": \"{s}\",\n      \"derivation_path\": \"m/44'/{d}'/0'/0/0\",\n      \"encoding\": \"{s}\",\n      \"network\": \"{s}\",\n      \"crypto\": \"PBKDF2-HMAC-SHA256\"\n    }}{s}",
                .{idx, chain.name, chain.chain_id, chain.coin_type,
                  native_addr,
                  account.pq_address[0..pq_len],
                  priv_hex, pub_hex_str, chain.coin_type,
                  if (chain.address_format == .EVM) "EVM" else if (chain.address_format == .UTXO) "UTXO" else "ACCOUNT",
                  if (chain.network == .MAINNET) "mainnet" else "testnet",
                  comma}) catch "";
            json_offset += entry.len;
        }

        const json_footer = "  ]\n}\n";
        @memcpy(json_buffer[json_offset..][0..json_footer.len], json_footer);
        json_offset += json_footer.len;

        // Write to file
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll(json_buffer[0..json_offset]);

        std.debug.print("✅ Complete wallet metadata exported to {s} ({} chains, {} bytes)\n\n", .{filename, SUPPORTED_CHAINS.len, json_offset});
    }

    /// Display all chains metadata to console
    pub fn display_all_chains(wallet: WalletAccount) void {
        std.debug.print("\n╔════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║  OmniBus Wallet - Complete Metadata (ALL {} CHAINS)   ║\n", .{SUPPORTED_CHAINS.len});
        std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

        for (wallet.chain_accounts, 0..) |account, idx| {
            const chain = SUPPORTED_CHAINS[idx];

            var hex_buf: [256]u8 = undefined;
            const priv_hex = format_hex(account.evm_private_key[0..], &hex_buf);

            const pq_len = std.mem.indexOfScalar(u8, &account.pq_address, 0) orelse account.pq_address.len;

            std.debug.print("[{d:02}] 🪙 {s} (Chain ID: {})\n", .{idx, chain.name, chain.chain_id});

            // Show native address based on format
            if (chain.address_format == .UTXO) {
                const utxo_len = std.mem.indexOfScalar(u8, &account.utxo_address, 0) orelse account.utxo_address.len;
                std.debug.print("     Address (UTXO):   {s}\n", .{account.utxo_address[0..utxo_len]});
            } else if (chain.address_format == .EVM) {
                const evm_len = std.mem.indexOfScalar(u8, &account.evm_address, 0) orelse account.evm_address.len;
                std.debug.print("     Address (EVM):    {s}\n", .{account.evm_address[0..evm_len]});
            } else {
                const evm_len = std.mem.indexOfScalar(u8, &account.evm_address, 0) orelse account.evm_address.len;
                std.debug.print("     Address:          {s}\n", .{account.evm_address[0..evm_len]});
            }

            std.debug.print("     PQ Address:       {s}\n", .{account.pq_address[0..pq_len]});
            std.debug.print("     Private Key:      {s}\n", .{priv_hex});
            std.debug.print("     Path:             m/44'/{d}'/0'/0/0\n", .{chain.coin_type});
            std.debug.print("     Format:           {s}\n", .{if (chain.address_format == .EVM) "EVM" else if (chain.address_format == .UTXO) "UTXO" else "ACCOUNT"});
            std.debug.print("     Network:          {s}\n\n", .{if (chain.network == .MAINNET) "mainnet" else "testnet"});
        }

        std.debug.print("✅ Total Chains: {}\n", .{SUPPORTED_CHAINS.len});
    }
};
