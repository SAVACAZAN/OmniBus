// omniup_connect.zig — OmniBus UP-Connect CLI
// Easy installation tool for miners and validators to join OmniBus network
// Phase 57: "Plug & Mine" installer for external participants

const std = @import("std");

const ParticipantConfig = struct {
    network_name: [64]u8 = [_]u8{0} ** 64,
    network_type: u8 = 0,
    participant_type: u8 = 0,  // 0=miner, 1=validator
    address: [128]u8 = [_]u8{0} ** 128,
    omni_wallet: [64]u8 = [_]u8{0} ** 64,
    rpc_endpoint: [256]u8 = [_]u8{0} ** 256,
    api_key: [64]u8 = [_]u8{0} ** 64,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("\n", .{});
    try stdout.print("╔════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║     OmniBus Universal Participant (UP) Module             ║\n", .{});
    try stdout.print("║              v1.0.0 — Plug & Mine Connect                 ║\n", .{});
    try stdout.print("╚════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    try stdout.print("Welcome! This tool will configure your mining/validator rig to\n", .{});
    try stdout.print("participate in OmniBus and earn OMNI rewards.\n\n", .{});

    try stdout.print("Select your network:\n", .{});
    try stdout.print("  [1] Bitcoin (PoW merged mining)\n", .{});
    try stdout.print("  [2] Ethereum (PoS validator bridging)\n", .{});
    try stdout.print("  [3] Solana (PoS validator)\n", .{});
    try stdout.print("  [4] Litecoin (PoW merged mining)\n", .{});
    try stdout.print("  [5] Dogecoin (PoW merged mining)\n", .{});
    try stdout.print("  [6] Other\n", .{});
    try stdout.print("\nEnter choice (1-6): ", .{});

    var buffer: [256]u8 = undefined;
    const bytes_read = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    const network_choice = std.mem.trim(u8, buffer[0..bytes_read], " \t\r\n");

    var network_type: u8 = 0;
    var network_name: [64]u8 = [_]u8{0} ** 64;

    if (std.mem.eql(u8, network_choice, "1")) {
        network_type = 0;  // Bitcoin
        _ = std.mem.copy(u8, &network_name, "Bitcoin");
    } else if (std.mem.eql(u8, network_choice, "2")) {
        network_type = 1;  // Ethereum
        _ = std.mem.copy(u8, &network_name, "Ethereum");
    } else if (std.mem.eql(u8, network_choice, "3")) {
        network_type = 2;  // Solana
        _ = std.mem.copy(u8, &network_name, "Solana");
    } else if (std.mem.eql(u8, network_choice, "4")) {
        network_type = 3;  // Litecoin
        _ = std.mem.copy(u8, &network_name, "Litecoin");
    } else if (std.mem.eql(u8, network_choice, "5")) {
        network_type = 4;  // Dogecoin
        _ = std.mem.copy(u8, &network_name, "Dogecoin");
    } else {
        try stdout.print("Invalid choice. Exiting.\n", .{});
        return;
    }

    try stdout.print("✓ Selected: {s}\n\n", .{network_name[0..std.mem.indexOfScalar(u8, &network_name, 0).?]});

    // Determine participant type
    var participant_type: u8 = 0;
    try stdout.print("Participant type:\n", .{});

    if (network_type <= 4) {  // PoW networks
        try stdout.print("  [1] Miner (submit proofs of work)\n", .{});
        try stdout.print("\nEnter choice (1): ", .{});
        _ = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        participant_type = 0;  // PoW miner
    } else {  // PoS networks
        try stdout.print("  [1] Validator (stake + sign blocks)\n", .{});
        try stdout.print("\nEnter choice (1): ", .{});
        _ = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        participant_type = 1;  // PoS validator
    }

    try stdout.print("\n[Step 1/3] Network Configuration\n", .{});
    try stdout.print("═════════════════════════════════\n\n", .{});

    try stdout.print("Enter your {s} address: ", .{network_name[0..std.mem.indexOfScalar(u8, &network_name, 0).?]});
    const address_len = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    const address = std.mem.trim(u8, buffer[0..address_len], " \t\r\n");

    try stdout.print("Enter your {s} RPC endpoint\n", .{network_name[0..std.mem.indexOfScalar(u8, &network_name, 0).?]});
    try stdout.print("(e.g., http://localhost:8332 for Bitcoin): ", .{});
    const rpc_len = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    const rpc_endpoint = std.mem.trim(u8, buffer[0..rpc_len], " \t\r\n");

    if (address.len > 127) {
        try stdout.print("Error: Address too long (max 127 chars)\n", .{});
        return;
    }

    try stdout.print("\n[Step 2/3] OmniBus Configuration\n", .{});
    try stdout.print("═════════════════════════════════\n\n", .{});

    try stdout.print("Enter your OmniBus wallet address\n", .{});
    try stdout.print("(where OMNI rewards will be sent): ", .{});
    const wallet_len = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    const omni_wallet = std.mem.trim(u8, buffer[0..wallet_len], " \t\r\n");

    if (omni_wallet.len < 20) {
        try stdout.print("Error: Invalid wallet address\n", .{});
        return;
    }

    try stdout.print("\n[Step 3/3] Security\n", .{});
    try stdout.print("═════════════════════════════════\n\n", .{});

    try stdout.print("Enter optional API key for secure communication\n", .{});
    try stdout.print("(or press Enter to skip): ", .{});
    const api_key_len = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    const api_key = std.mem.trim(u8, buffer[0..api_key_len], " \t\r\n");

    // Generate configuration
    try stdout.print("\n", .{});
    try stdout.print("╔════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    Configuration Summary                  ║\n", .{});
    try stdout.print("╚════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    try stdout.print("Network:          {s}\n", .{network_name[0..std.mem.indexOfScalar(u8, &network_name, 0).?]});
    try stdout.print("Address:          {s}\n", .{address});
    try stdout.print("RPC Endpoint:     {s}\n", .{rpc_endpoint});
    try stdout.print("OMNI Wallet:      {s}\n", .{omni_wallet});
    try stdout.print("Participant Type: {s}\n", .{if (participant_type == 0) "Miner (PoW)" else "Validator (PoS)"});

    try stdout.print("\n", .{});
    try stdout.print("Configuration saved! Next steps:\n", .{});
    try stdout.print("  1. Copy .omnibus-up-config to ~/.omnibus/config/\n", .{});
    try stdout.print("  2. Run: omnibus-up-daemon start\n", .{});
    try stdout.print("  3. Monitor: omnibus-up-monitor\n", .{});
    try stdout.print("\nFor help: omnibus-up-connect --help\n", .{});
    try stdout.print("\n", .{});

    // Write configuration file
    var config_file = try std.fs.cwd().createFile(".omnibus-up-config", .{});
    defer config_file.close();

    try config_file.writer().print("# OmniBus UP Module Configuration\n", .{});
    try config_file.writer().print("# Auto-generated by omniup_connect v1.0.0\n\n", .{});
    try config_file.writer().print("network_type = {d}\n", .{network_type});
    try config_file.writer().print("participant_type = {d}\n", .{participant_type});
    try config_file.writer().print("address = \"{s}\"\n", .{address});
    try config_file.writer().print("rpc_endpoint = \"{s}\"\n", .{rpc_endpoint});
    try config_file.writer().print("omni_wallet = \"{s}\"\n", .{omni_wallet});
    try config_file.writer().print("api_key = \"{s}\"\n", .{api_key});

    try stdout.print("Configuration written to: .omnibus-up-config\n", .{});
}
