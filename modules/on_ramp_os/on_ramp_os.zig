// ============================================================================
// On-Ramp OS (Zig/Bare Metal)
// USDC deposit listener and status token minter
// Monitors Ethereum & Base chains for deposits
// ============================================================================

const std = @import("std");

// Memory layout (0x570000 – 0x57FFFF, 64KB)
const ON_RAMP_BASE: usize = 0x570000;

// Deposit record (32 bytes each)
const DepositRecord = struct {
    tx_hash: u64,               // Source chain tx hash (first 8 bytes for ID)
    depositor: u64,             // Source chain address
    amount: u64,                // USDC amount (6 decimals)
    token_type: u8,             // Which token (LOVE=1, FOOD=2, RENT=3, VACA=4)
    source_chain: u8,           // 1=Ethereum, 2=Base
    status: u8,                 // 0=pending, 1=confirmed, 2=minted, 3=failed
    reserved: u8,               // Padding
};

// On-Ramp State Header (128 bytes @ 0x570000)
const OnRampState = struct {
    magic: u32 = 0x4F4E4152,   // "ONRA"
    version: u16 = 1,
    reserved: u16 = 0,

    // Configuration
    enabled: u8 = 1,            // Is on-ramp active?
    min_confirmations_eth: u8 = 12,
    min_confirmations_base: u8 = 3,
    reserved2: u8 = 0,

    // Tracking
    total_deposits: u32,        // Total deposits received
    total_minted: u32,          // Total tokens minted
    total_failed: u32,          // Failed deposits
    deposit_count: u32,         // Current pending deposits

    // Addresses (these come from bridge monitoring)
    eth_agent_address: u64,     // Agent address on Ethereum
    base_agent_address: u64,    // Agent address on Base
    omni_minter_address: u64,   // Minter address on OmniBus
    last_update: u64,           // Timestamp

    // Revenue tracking
    revenue_collected: u64,     // Total fees collected (in SAT)
};

// Deposit storage (256 records @ 0x570080)
const DEPOSIT_RECORDS_ADDR: usize = ON_RAMP_BASE + 128;
const MAX_DEPOSITS: usize = 256;

var on_ramp_state: OnRampState = .{
    .magic = 0x4F4E4152,
    .version = 1,
    .enabled = 1,
    .min_confirmations_eth = 12,
    .min_confirmations_base = 3,
    .total_deposits = 0,
    .total_minted = 0,
    .total_failed = 0,
    .deposit_count = 0,
    .eth_agent_address = 0, // Set by admin
    .base_agent_address = 0,
    .omni_minter_address = 0x1001, // Status token minter
    .last_update = 0,
    .revenue_collected = 0,
};

var deposits: [MAX_DEPOSITS]DepositRecord = undefined;

// ============================================================================
// PUBLIC API
// ============================================================================

pub fn init_plugin() void {
    // Clear deposit records
    for (0..MAX_DEPOSITS) |i| {
        deposits[i] = .{
            .tx_hash = 0,
            .depositor = 0,
            .amount = 0,
            .token_type = 0,
            .source_chain = 0,
            .status = 0,
            .reserved = 0,
        };
    }

    on_ramp_state.last_update = get_tsc();
}

/// Register a deposit from external chain
/// Returns: 0=success, 1=duplicate, 2=full, 3=invalid
pub fn register_deposit(
    tx_hash: u64,
    depositor: u64,
    amount: u64,
    token_type: u8,
    source_chain: u8,
) u8 {
    if (!on_ramp_state.enabled) {
        return 3; // On-ramp disabled
    }

    if (token_type < 1 or token_type > 4) {
        return 3; // Invalid token
    }

    if (source_chain < 1 or source_chain > 2) {
        return 3; // Invalid chain
    }

    // Check for duplicate
    for (0..MAX_DEPOSITS) |i| {
        if (deposits[i].tx_hash == tx_hash) {
            return 1; // Already registered
        }
    }

    // Find empty slot
    var slot: usize = undefined;
    var found = false;
    for (0..MAX_DEPOSITS) |i| {
        if (deposits[i].tx_hash == 0) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 2; // No space
    }

    // Store deposit
    deposits[slot] = .{
        .tx_hash = tx_hash,
        .depositor = depositor,
        .amount = amount,
        .token_type = token_type,
        .source_chain = source_chain,
        .status = 0, // Pending
        .reserved = 0,
    };

    on_ramp_state.total_deposits += 1;
    on_ramp_state.deposit_count += 1;
    on_ramp_state.last_update = get_tsc();

    return 0; // Success
}

/// Confirm a deposit and mint tokens
/// Called after sufficient confirmations verified by bridge service
pub fn confirm_and_mint(tx_hash: u64) u8 {
    // Find deposit
    var slot: usize = undefined;
    var found = false;
    for (0..MAX_DEPOSITS) |i| {
        if (deposits[i].tx_hash == tx_hash) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 1; // Deposit not found
    }

    const deposit = &deposits[slot];

    if (deposit.status != 0) {
        return 1; // Already processed
    }

    // Call status token minter via IPC
    const result = call_mint_token(deposit.token_type, deposit.depositor, deposit.amount);

    if (result == 0) {
        // Success
        deposit.status = 2; // Minted
        on_ramp_state.total_minted += 1;

        // Calculate revenue (assuming ~3 SAT in gas per token)
        const gas_cost: u64 = 3000;
        const profit: u64 = if (deposit.amount > gas_cost)
            deposit.amount - gas_cost
        else
            0;
        on_ramp_state.revenue_collected += profit;
    } else {
        // Failed
        deposit.status = 3;
        on_ramp_state.total_failed += 1;
    }

    on_ramp_state.deposit_count -= 1;
    on_ramp_state.last_update = get_tsc();

    return if (result == 0) 0 else 1;
}

/// Get deposit status
pub fn get_deposit_status(tx_hash: u64) u8 {
    for (0..MAX_DEPOSITS) |i| {
        if (deposits[i].tx_hash == tx_hash) {
            return deposits[i].status;
        }
    }

    return 0xFF; // Not found
}

/// Get total minted tokens
pub fn get_total_minted() u32 {
    return on_ramp_state.total_minted;
}

/// Get pending deposits count
pub fn get_pending_count() u32 {
    return on_ramp_state.deposit_count;
}

/// Set agent addresses (admin only)
pub fn set_agent_addresses(eth_agent: u64, base_agent: u64) void {
    on_ramp_state.eth_agent_address = eth_agent;
    on_ramp_state.base_agent_address = base_agent;
    on_ramp_state.last_update = get_tsc();
}

// ============================================================================
// IPC Interface (Opcodes 0x81–0x85)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0x81 => register_deposit_ipc(arg0, arg1),    // register_deposit(tx_hash)
        0x82 => confirm_and_mint_ipc(arg0, 0),       // confirm_and_mint(tx_hash)
        0x83 => get_deposit_status_ipc(arg0, 0),     // get_deposit_status(tx_hash)
        0x84 => get_total_minted_ipc(),              // get_total_minted()
        0x85 => run_onramp_cycle(),                  // run_onramp_cycle()
        else => 0xFFFFFFFF,
    };
}

fn register_deposit_ipc(tx_hash: u64, details: u64) u64 {
    // details packed: [token_type:8][source_chain:8][reserved:48]
    const token_type: u8 = @intCast((details >> 8) & 0xFF);
    const source_chain: u8 = @intCast(details & 0xFF);

    const result = register_deposit(tx_hash, 0, 0, token_type, source_chain);
    return if (result == 0) 1 else 0;
}

fn confirm_and_mint_ipc(tx_hash: u64, _unused: u64) u64 {
    _ = _unused;
    const result = confirm_and_mint(tx_hash);
    return if (result == 0) 1 else 0;
}

fn get_deposit_status_ipc(tx_hash: u64, _unused: u64) u64 {
    _ = _unused;
    return get_deposit_status(tx_hash);
}

fn get_total_minted_ipc() u64 {
    return get_total_minted();
}

fn run_onramp_cycle() u64 {
    // Periodic on-ramp maintenance
    // In production, this would:
    // 1. Check bridge service for new blocks
    // 2. Verify confirmations for pending deposits
    // 3. Trigger minting for confirmed deposits

    on_ramp_state.last_update = get_tsc();
    return 1; // Success
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn call_mint_token(token_type: u8, to_address: u64, amount: u64) u8 {
    // Call status token minter via IPC (opcode 0x71)
    const result = mother_os_ipc(0x71, token_type, to_address);
    _ = amount;
    return if (result > 0) 0 else 1;
}

fn mother_os_ipc(opcode: u8, arg0: u64, arg1: u64) u64 {
    _ = opcode;
    _ = arg0;
    _ = arg1;
    // TODO: Implement actual IPC to Mother OS
    // This would use the IPC gate defined in CLAUDE.md
    return 0;
}

fn get_tsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile (
        \\rdtsc
        : [low] "=a" (low),
          [high] "=d" (high),
    );

    return (@as(u64, high) << 32) | low;
}
