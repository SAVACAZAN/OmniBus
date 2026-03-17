// usdc_erc20_onramp.zig – ERC20 USDC to OMNI Bridge On-Ramp
// Phase 70: Accept USDC from Ethereum, mint OMNI to agent wallet
// Memory-mapped @ 0x3C1000, polls Ethereum block for transfers to bridge address

const std = @import("std");
// const multi_token_bridge = @import("multi_token_bridge.zig");  // TODO: integrate with bridge in Phase 71

// ============================================================================
// CONSTANTS
// ============================================================================

pub const USDC_ONRAMP_BASE: usize = 0x3C1000;
pub const ETH_BRIDGE_ADDRESS: [42]u8 = "0x8ba1f109551bD432803012645Ac136ddd64DBA72".*;
pub const USDC_CONTRACT_ETH: [42]u8 = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48".*;  // Mainnet USDC
pub const USDC_DECIMALS: u8 = 6;

// Conversion rate: 1 USDC = 1 OMNI (1:1 peg during on-ramp)
pub const USDC_TO_OMNI_RATE: u128 = 1_000_000_000_000_000_000;  // 1e18 (OMNI has 18 decimals)

// ============================================================================
// STATE STRUCTURES
// ============================================================================

pub const USDCTransfer = struct {
    tx_hash: [32]u8,
    tx_hash_len: u8,
    from_address: [42]u8,
    from_len: u8,
    to_address: [42]u8,  // Should match ETH_BRIDGE_ADDRESS
    to_len: u8,
    amount_usdc: u128,   // Raw USDC units (USDC uses 6 decimals)
    block_number: u64,
    timestamp: u64,
    status: u8,          // 0=pending, 1=confirmed, 2=minted, 3=failed
    omni_minted: u128,   // Amount of OMNI minted from this transfer
};

pub const USDCOnRampState = struct {
    magic: u32 = 0x55534443,  // "USDC"
    version: u32 = 1,
    initialized: u8 = 0,

    // Bridge address and contract
    bridge_address: [42]u8 = ETH_BRIDGE_ADDRESS,
    usdc_contract: [42]u8 = USDC_CONTRACT_ETH,

    // Transfer history (circular buffer, last 32 transfers)
    transfers: [32]USDCTransfer = undefined,
    transfer_count: u8 = 0,
    transfer_head: u8 = 0,

    // Statistics
    total_usdc_received: u128 = 0,
    total_omni_minted: u128 = 0,
    pending_transfers: u8 = 0,
    failed_transfers: u8 = 0,
    successful_mints: u32 = 0,

    // Ethereum state
    eth_block_height: u64 = 0,
    last_polled_block: u64 = 0,
    eth_confirmation_depth: u8 = 12,  // Wait 12 blocks for finality

    // Agent wallet address (destination for minted OMNI)
    agent_address: [70]u8 = undefined,
    agent_address_len: u8 = 0,

    // Bridge manager reference (TODO: Phase 71)
    // bridge_manager: ?*multi_token_bridge.BridgeManager = null,

    last_poll_tsc: u64 = 0,
    poll_count: u32 = 0,

    _reserved: [256]u8 = [_]u8{0} ** 256,
};

var onramp_state: USDCOnRampState = undefined;
var initialized: bool = false;

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init_usdc_onramp(agent_addr: [70]u8, agent_addr_len: u8) void {
    if (initialized) return;

    var state = &onramp_state;
    state.magic = 0x55534443;  // "USDC"
    state.version = 1;
    state.initialized = 1;
    state.transfer_count = 0;
    state.transfer_head = 0;
    state.total_usdc_received = 0;
    state.total_omni_minted = 0;
    state.pending_transfers = 0;
    state.failed_transfers = 0;
    state.successful_mints = 0;

    // Store agent wallet address
    state.agent_address = agent_addr;
    state.agent_address_len = agent_addr_len;

    // Initialize bridge address
    @memcpy(state.bridge_address[0..42], ETH_BRIDGE_ADDRESS[0..42]);
    @memcpy(state.usdc_contract[0..42], USDC_CONTRACT_ETH[0..42]);

    initialized = true;
}

// ============================================================================
// USDC TRANSFER PROCESSING
// ============================================================================

pub fn record_usdc_transfer(
    tx_hash: [*]const u8,
    tx_hash_len: u8,
    from_addr: [*]const u8,
    from_len: u8,
    amount_usdc: u128,
    block_number: u64,
    timestamp: u64,
) void {
    if (!initialized) return;

    var state = &onramp_state;

    // Validate: to_address must match bridge address
    // (simplified - in production would verify full tx and state on Ethereum)

    // Circular buffer: add transfer
    const idx = state.transfer_head;
    var transfer = &state.transfers[idx];

    @memcpy(transfer.tx_hash[0..@min(tx_hash_len, 32)], tx_hash[0..@min(tx_hash_len, 32)]);
    transfer.tx_hash_len = tx_hash_len;

    @memcpy(transfer.from_address[0..@min(from_len, 42)], from_addr[0..@min(from_len, 42)]);
    transfer.from_len = from_len;

    @memcpy(transfer.to_address[0..42], ETH_BRIDGE_ADDRESS[0..42]);
    transfer.to_len = 42;

    transfer.amount_usdc = amount_usdc;
    transfer.block_number = block_number;
    transfer.timestamp = timestamp;
    transfer.status = 0;  // PENDING
    transfer.omni_minted = 0;

    // Update circular buffer head
    state.transfer_head = (state.transfer_head + 1) % 32;
    if (state.transfer_count < 32) {
        state.transfer_count += 1;
    }

    state.pending_transfers += 1;
    state.total_usdc_received +|= amount_usdc;
    state.last_poll_tsc = rdtsc();
    state.poll_count += 1;
}

// ============================================================================
// MINT OMNI FROM USDC
// ============================================================================

pub fn process_usdc_to_omni_mint(transfer_idx: u8) bool {
    if (!initialized or transfer_idx >= 32) return false;

    var state = &onramp_state;
    var transfer = &state.transfers[transfer_idx];

    // Only process pending transfers
    if (transfer.status != 0) return false;

    // Calculate OMNI to mint (1:1 conversion from USDC)
    // USDC = 6 decimals, OMNI = 18 decimals
    // 1 USDC (1_000_000 units) = 1 OMNI (1_000_000_000_000_000_000 units)
    const omni_amount: u128 = transfer.amount_usdc * 1_000_000_000_000;  // Scale 6→18 decimals

    // Mark transfer as confirmed (waiting for Ethereum finality)
    transfer.status = 1;  // CONFIRMED

    // Record the minting
    transfer.omni_minted = omni_amount;
    transfer.status = 2;  // MINTED

    state.total_omni_minted +|= omni_amount;
    state.successful_mints += 1;
    state.pending_transfers -|= 1;

    return true;
}

// ============================================================================
// POLLING FOR NEW TRANSFERS (DEV_MODE: Simulated)
// ============================================================================

pub fn poll_ethereum_for_usdc() void {
    if (!initialized) return;

    var state = &onramp_state;

    // DEV_MODE: Simulate Ethereum block polling
    // In production: fetch blocks from Ethereum RPC, decode ERC20 Transfer events
    // Filter for: event Transfer(indexed from, indexed to, uint256 value)
    // Where to = ETH_BRIDGE_ADDRESS and token = USDC_CONTRACT

    state.eth_block_height += 1;
    state.last_polled_block = state.eth_block_height;

    // Hardcoded test: every 64 cycles, record a test USDC transfer
    if ((state.poll_count & 0x3F) == 0 and state.poll_count > 0) {
        // Simulate incoming USDC transfer
        const test_tx_hash: [32]u8 = [_]u8{0xAA} ** 32;
        const test_from: [42]u8 = "0x1234567890123456789012345678901234567890".*;
        const test_amount: u128 = 1_000_000;  // 1 USDC

        record_usdc_transfer(&test_tx_hash, 32, &test_from, 42, test_amount, state.eth_block_height, rdtsc());

        // Immediately mint OMNI for test
        if (state.transfer_count > 0) {
            const transfer_idx: u8 = if (state.transfer_count > 0) state.transfer_count - 1 else 0;
            _ = process_usdc_to_omni_mint(transfer_idx);
        }
    }

    state.last_poll_tsc = rdtsc();
    state.poll_count +|= 1;
}

// ============================================================================
// DISPLAY ONRAMP STATUS
// ============================================================================

fn uart_write(c: u8) void {
    asm volatile ("outb %al, %dx" : : [v] "{al}" (c), [p] "{dx}" (@as(u16, 0x3F8)));
}

pub fn display_onramp_status() void {
    if (!initialized) return;

    const state = &onramp_state;

    // Header
    for ("\n") |c| uart_write(c);
    for ("===== USDC ERC20 ON-RAMP STATUS =====\n") |c| uart_write(c);

    for ("Bridge Address: ") |c| uart_write(c);
    for (state.bridge_address[0..42]) |c| uart_write(c);
    for ("\n") |c| uart_write(c);

    for ("USDC Contract: ") |c| uart_write(c);
    for (state.usdc_contract[0..42]) |c| uart_write(c);
    for ("\n\n") |c| uart_write(c);

    // Statistics
    for ("[TRANSFER STATISTICS]\n") |c| uart_write(c);
    for ("Total USDC Received: ") |c| uart_write(c);
    print_u128_uart(state.total_usdc_received);
    for (" (with 6 decimals)\n") |c| uart_write(c);

    for ("Total OMNI Minted: ") |c| uart_write(c);
    print_u128_uart(state.total_omni_minted);
    for (" (with 18 decimals)\n") |c| uart_write(c);

    for ("Successful Mints: ") |c| uart_write(c);
    print_u32_uart(state.successful_mints);
    for (" | Pending: ") |c| uart_write(c);
    print_u8_uart(state.pending_transfers);
    for (" | Failed: ") |c| uart_write(c);
    print_u8_uart(state.failed_transfers);
    for ("\n\n") |c| uart_write(c);

    // Ethereum status
    for ("[ETHEREUM STATUS]\n") |c| uart_write(c);
    for ("Current Block: ") |c| uart_write(c);
    print_u64_uart(state.eth_block_height);
    for (" | Last Polled: ") |c| uart_write(c);
    print_u64_uart(state.last_polled_block);
    for ("\n") |c| uart_write(c);

    for ("Polls Executed: ") |c| uart_write(c);
    print_u32_uart(state.poll_count);
    for ("\n\n") |c| uart_write(c);

    // Recent transfers
    for ("[RECENT TRANSFERS]\n") |c| uart_write(c);
    var i: u8 = 0;
    while (i < state.transfer_count and i < 5) : (i += 1) {
        const idx: u8 = (state.transfer_head + i) % 32;
        const transfer = &state.transfers[idx];

        if (transfer.status == 0) {
            for ("Transfer ") |c| uart_write(c);
            print_u8_uart(i);
            for (": ") |c| uart_write(c);
            print_u128_uart(transfer.amount_usdc);
            for (" USDC (PENDING)\n") |c| uart_write(c);
        } else if (transfer.status == 2) {
            for ("Transfer ") |c| uart_write(c);
            print_u8_uart(i);
            for (": ") |c| uart_write(c);
            print_u128_uart(transfer.omni_minted);
            for (" OMNI (MINTED)\n") |c| uart_write(c);
        }
    }

    for ("\n") |c| uart_write(c);
}

// ============================================================================
// UART OUTPUT HELPERS
// ============================================================================

fn print_u8_uart(val: u8) void {
    if (val == 0) {
        uart_write('0');
        return;
    }

    var divisor: u8 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }

    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u32_uart(val: u32) void {
    if (val == 0) {
        uart_write('0');
        return;
    }

    var divisor: u32 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }

    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u64_uart(val: u64) void {
    if (val == 0) {
        uart_write('0');
        return;
    }

    var divisor: u64 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }

    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

fn print_u128_uart(val: u128) void {
    if (val == 0) {
        uart_write('0');
        return;
    }

    var divisor: u128 = 1;
    var temp = val;
    while (temp >= 10) {
        divisor *= 10;
        temp /= 10;
    }

    temp = val;
    while (divisor > 0) {
        uart_write(@as(u8, @intCast((temp / divisor) % 10)) + '0');
        divisor /= 10;
    }
}

// ============================================================================
// RDTSC (Read Time Stamp Counter)
// ============================================================================

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// ============================================================================
// EXPORT FUNCTIONS
// ============================================================================

pub fn get_onramp_state() *const USDCOnRampState {
    if (!initialized) init_usdc_onramp([_]u8{0} ** 70, 0);
    return &onramp_state;
}

pub fn get_total_usdc_received() u128 {
    if (!initialized) return 0;
    return onramp_state.total_usdc_received;
}

pub fn get_total_omni_minted() u128 {
    if (!initialized) return 0;
    return onramp_state.total_omni_minted;
}

pub fn get_pending_transfer_count() u8 {
    if (!initialized) return 0;
    return onramp_state.pending_transfers;
}
