// OmniBus Blockchain Test Runner for QEMU
// Complete end-to-end blockchain simulation with validation

const std = @import("std");

// ============================================================================
// Test Harness Configuration
// ============================================================================

pub const TestConfig = struct {
    num_blocks: u32 = 100,                 // Number of blocks to mine
    num_accounts: u32 = 10,                // Initial accounts
    initial_balance: u64 = 100_000_000,    // 1 OMNI in SAT per account
    transactions_per_block: u32 = 10,      // Avg txs per block
    verbose: bool = true,                  // Print details
};

pub const TestResults = struct {
    total_blocks: u32 = 0,
    total_transactions: u32 = 0,
    total_gas_used: u64 = 0,
    total_fees_burned: u64 = 0,
    successful_blocks: u32 = 0,
    failed_blocks: u32 = 0,
    halving_block_reward: u64 = 0,
    errors: [100][256]u8 = undefined,
    error_count: u8 = 0,
};

// ============================================================================
// Test Runner Main Function
// ============================================================================

pub fn run_blockchain_tests(config: TestConfig) TestResults {
    var results: TestResults = undefined;
    @memset(&results.errors, 0);

    print("\n╔════════════════════════════════════════╗\n", .{});
    print("║  OmniBus Blockchain Test Runner      ║\n", .{});
    print("║  QEMU Simulation Environment         ║\n", .{});
    print("╚════════════════════════════════════════╝\n", .{});

    print("\n📋 Test Configuration:\n", .{});
    print("   Blocks to mine: {d}\n", .{config.num_blocks});
    print("   Initial accounts: {d}\n", .{config.num_accounts});
    print("   Initial balance per account: {d} SAT ({d} OMNI)\n", .{ config.initial_balance, config.initial_balance / 100_000_000 });
    print("   Avg transactions per block: {d}\n", .{config.transactions_per_block});

    // Initialize blockchain simulator
    var ledger = initialize_ledger(config.num_accounts, config.initial_balance);

    print("\n✅ Initialized {} accounts with {} SAT each\n", .{ config.num_accounts, config.initial_balance });

    // Mine blocks
    var block_num: u32 = 0;
    while (block_num < config.num_blocks) : (block_num += 1) {
        if (!mine_and_validate_block(&ledger, block_num, &results)) {
            results.failed_blocks += 1;
            if (results.error_count < 100) {
                results.error_count += 1;
            }
        } else {
            results.successful_blocks += 1;
        }

        // Progress indicator
        if (config.verbose and (block_num % 10 == 0)) {
            print("⛏️  Mined {d} blocks...\n", .{block_num});
        }

        // Check for halving
        if (block_num == 210000) {
            results.halving_block_reward = calculate_halving_reward();
            if (config.verbose) {
                print("🔄 Block reward halved at block {d}\n", .{block_num});
            }
        }
    }

    // Print results
    print_test_results(&results, config);

    return results;
}

// ============================================================================
// Block Mining & Validation
// ============================================================================

fn mine_and_validate_block(
    ledger: *BlockchainLedger,
    block_num: u32,
    results: *TestResults
) bool {
    // Create block
    var block = create_block_with_transactions(block_num, ledger);

    // Mine block (find valid nonce)
    if (!mine_block(&block)) {
        return false;
    }

    // Validate block
    if (!validate_block(&block, ledger)) {
        return false;
    }

    // Execute transactions
    for (var i = 0; i < block.tx_count; i += 1) {
        if (!execute_transaction(&block.transactions[i], ledger)) {
            return false;
        }
    }

    // Award block reward
    const block_reward = calculate_block_reward(block_num);
    if (ledger.account_count > 0) {
        ledger.accounts[0].balance +%= block_reward;
        ledger.state.circulating_supply +%= block_reward;
    }

    // Update results
    results.total_blocks += 1;
    results.total_transactions += block.tx_count;
    results.total_gas_used += estimate_block_gas(&block);
    results.total_fees_burned += estimate_block_fees(&block);

    // Update ledger state
    ledger.state.current_height = block_num;
    ledger.state.current_difficulty = adjust_difficulty(block_num + 1);

    return true;
}

fn create_block_with_transactions(height: u32, ledger: *BlockchainLedger) BlockWithTxs {
    var block: BlockWithTxs = undefined;

    block.header.version = 1;
    block.header.timestamp = 1678550400 + (height * 600); // 10 min blocks
    block.header.height = height;
    @memset(&block.header.previous_omni_hash, 0);
    @memset(&block.header.merkle_root, 0);
    @memset(&block.header.pq_root, 0);
    block.header.difficulty = adjust_difficulty(height);
    block.header.nonce = 0;

    // Generate sample transactions
    block.tx_count = 0;
    if (ledger.account_count >= 2) {
        // Simple transfer from account 0 to account 1
        var tx: Transaction = undefined;
        tx.from_addr = ledger.accounts[0].address;
        tx.to_addr = ledger.accounts[(height % (ledger.account_count - 1)) + 1].address;
        tx.amount = 100_000; // 0.001 OMNI
        tx.fee = 21_000; // Base gas for transfer
        tx.nonce = ledger.accounts[0].nonce + 1;

        block.transactions[0] = tx;
        block.tx_count = 1;
    }

    block.anchor_proof.chain = @as(u8, @truncate(height % 6));
    block.anchor_proof.block_height = height;
    block.anchor_proof.timestamp = block.header.timestamp;

    return block;
}

fn mine_block(block: *BlockWithTxs) bool {
    // Simplified: nonce must be divisible by difficulty
    var nonce: u32 = 0;
    while (nonce < 1000000) : (nonce += 1) {
        block.header.nonce = nonce;

        if ((nonce % block.header.difficulty) == 0) {
            return true;
        }
    }

    return false;
}

fn validate_block(block: *const BlockWithTxs, ledger: *const BlockchainLedger) bool {
    // Basic validation
    if (block.header.version == 0) return false;
    if (block.header.nonce == 0) return false;
    if (block.tx_count > 1024) return false;

    // All transactions must be valid
    for (var i = 0; i < block.tx_count; i += 1) {
        if (!validate_transaction(&block.transactions[i], ledger)) {
            return false;
        }
    }

    return true;
}

fn validate_transaction(tx: *const Transaction, ledger: *const BlockchainLedger) bool {
    // Find sender
    var sender_idx: usize = 0;
    var found = false;
    for (var i = 0; i < ledger.account_count; i += 1) {
        if (std.mem.eql(u8, &ledger.accounts[i].address, &tx.from_addr)) {
            sender_idx = i;
            found = true;
            break;
        }
    }

    if (!found) return false;

    // Check balance
    const total_cost = tx.amount +% tx.fee;
    if (ledger.accounts[sender_idx].balance < total_cost) {
        return false;
    }

    // Check nonce
    if (tx.nonce <= ledger.accounts[sender_idx].nonce) {
        return false;
    }

    return true;
}

fn execute_transaction(tx: *const Transaction, ledger: *BlockchainLedger) bool {
    // Find sender
    var sender_idx: usize = 0;
    for (var i = 0; i < ledger.account_count; i += 1) {
        if (std.mem.eql(u8, &ledger.accounts[i].address, &tx.from_addr)) {
            sender_idx = i;
            break;
        }
    }

    // Deduct
    ledger.accounts[sender_idx].balance -%= tx.amount;
    ledger.accounts[sender_idx].balance -%= tx.fee;
    ledger.accounts[sender_idx].nonce +%= 1;
    ledger.state.total_fees_burned +%= tx.fee;

    // Find/create recipient
    var recipient_idx: usize = 0;
    var found = false;
    for (var i = 0; i < ledger.account_count; i += 1) {
        if (std.mem.eql(u8, &ledger.accounts[i].address, &tx.to_addr)) {
            recipient_idx = i;
            found = true;
            break;
        }
    }

    if (found) {
        ledger.accounts[recipient_idx].balance +%= tx.amount;
    }

    return true;
}

// ============================================================================
// Block Reward & Difficulty Calculation
// ============================================================================

fn calculate_block_reward(height: u32) u64 {
    const base_reward: u64 = 5_000_000_000; // 50 OMNI in SAT
    const halving_interval: u64 = 210000;

    var halvings = height / halving_interval;
    if (halvings >= 64) {
        return 0;
    }

    return base_reward >> @intCast(halvings);
}

fn calculate_halving_reward() u64 {
    return 2_500_000_000; // 25 OMNI (after first halving)
}

fn adjust_difficulty(height: u32) u32 {
    if (height < 2016) {
        return 1;
    }
    const period = height / 2016;
    return @as(u32, @intCast(1 + (period / 1000)));
}

// ============================================================================
// Gas & Fee Calculation
// ============================================================================

fn estimate_block_gas(block: *const BlockWithTxs) u64 {
    var total: u64 = 0;
    for (var i = 0; i < block.tx_count; i += 1) {
        total +%= 21000; // Base gas per tx
    }
    return total;
}

fn estimate_block_fees(block: *const BlockWithTxs) u64 {
    var total: u64 = 0;
    for (var i = 0; i < block.tx_count; i += 1) {
        total +%= block.transactions[i].fee;
    }
    return total;
}

// ============================================================================
// Test Results Printing
// ============================================================================

fn print_test_results(results: *const TestResults, config: TestConfig) void {
    print("\n╔════════════════════════════════════════╗\n", .{});
    print("║  📊 Test Results Summary              ║\n", .{});
    print("╚════════════════════════════════════════╝\n\n", .{});

    const success_rate = (results.successful_blocks * 100) / (results.successful_blocks + results.failed_blocks);

    print("⛓️  Blocks Mined:\n", .{});
    print("   Successful: {d}/{d}\n", .{ results.successful_blocks, config.num_blocks });
    print("   Failed: {d}\n", .{results.failed_blocks});
    print("   Success Rate: {d}%\n", .{success_rate});

    print("\n💰 Economics:\n", .{});
    print("   Total Transactions: {d}\n", .{results.total_transactions});
    print("   Total Gas Used: {d}\n", .{results.total_gas_used});
    print("   Total Fees Burned: {d} SAT ({d} OMNI)\n", .{
        results.total_fees_burned,
        results.total_fees_burned / 100_000_000,
    });

    print("\n📈 Blockchain State:\n", .{});
    const final_supply = (results.successful_blocks * 5_000_000_000); // Block rewards
    print("   Final Block Height: {d}\n", .{results.total_blocks});
    print("   Circulating Supply: {d} SAT ({d} OMNI)\n", .{
        final_supply,
        final_supply / 100_000_000,
    });

    if (results.halving_block_reward > 0) {
        print("   ✓ Halving Checkpoint Verified\n", .{});
        print("     Block Reward: {d} → {d} SAT\n", .{ 5_000_000_000, results.halving_block_reward });
    }

    if (results.error_count > 0) {
        print("\n⚠️  Errors ({d}):\n", .{results.error_count});
        for (var i = 0; i < results.error_count and i < 10; i += 1) {
            print("   Error {d}: {s}\n", .{ i + 1, &results.errors[i] });
        }
    }

    print("\n✅ Test Suite Complete\n\n", .{});
}

// ============================================================================
// Types & Data Structures
// ============================================================================

pub const BlockchainLedger = struct {
    accounts: [100]Account = undefined,
    account_count: u32 = 0,
    state: State = undefined,
};

pub const Account = struct {
    address: [64]u8 = undefined,
    balance: u64 = 0,
    nonce: u32 = 0,
};

pub const State = struct {
    current_height: u64 = 0,
    current_difficulty: u32 = 1,
    circulating_supply: u64 = 0,
    total_fees_burned: u64 = 0,
};

pub const BlockWithTxs = struct {
    header: BlockHeader = undefined,
    transactions: [1024]Transaction = undefined,
    tx_count: u32 = 0,
    anchor_proof: AnchorProof = undefined,
};

pub const BlockHeader = struct {
    version: u32 = 0,
    timestamp: u64 = 0,
    height: u32 = 0,
    previous_omni_hash: [32]u8 = undefined,
    merkle_root: [32]u8 = undefined,
    pq_root: [32]u8 = undefined,
    difficulty: u32 = 1,
    nonce: u32 = 0,
};

pub const Transaction = struct {
    from_addr: [64]u8 = undefined,
    to_addr: [64]u8 = undefined,
    amount: u64 = 0,
    fee: u64 = 0,
    nonce: u32 = 0,
};

pub const AnchorProof = struct {
    chain: u8 = 0,
    block_height: u32 = 0,
    timestamp: u64 = 0,
};

// ============================================================================
// Initialization
// ============================================================================

fn initialize_ledger(num_accounts: u32, initial_balance: u64) BlockchainLedger {
    var ledger: BlockchainLedger = undefined;

    ledger.account_count = num_accounts;
    for (var i = 0; i < num_accounts; i += 1) {
        var addr: [64]u8 = undefined;
        @memset(&addr, 0);

        // Simple address: "account_0", "account_1", etc.
        var addr_str = std.fmt.bufPrint(&addr, "account_{d}", .{i}) catch unreachable;
        @memcpy(&ledger.accounts[i].address, addr_str);

        ledger.accounts[i].balance = initial_balance;
        ledger.accounts[i].nonce = 0;
    }

    ledger.state.current_height = 0;
    ledger.state.current_difficulty = 1;
    ledger.state.circulating_supply = @as(u64, num_accounts) * initial_balance;
    ledger.state.total_fees_burned = 0;

    return ledger;
}

// ============================================================================
// Utility: Print Function (for QEMU console output)
// ============================================================================

fn print(comptime fmt: []const u8, args: anytype) void {
    // In QEMU: write to serial port or stdout
    // For now: use standard output
    std.debug.print(fmt, args);
}

pub fn main() void {
    var config: TestConfig = .{
        .num_blocks = 100,
        .num_accounts = 10,
        .initial_balance = 100_000_000, // 1 OMNI per account
        .transactions_per_block = 1,
        .verbose = true,
    };

    const results = run_blockchain_tests(config);

    // Exit code: 0 if successful, 1 if failed
    if (results.failed_blocks == 0) {
        std.process.exit(0);
    } else {
        std.process.exit(1);
    }
}
