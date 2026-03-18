// block_explorer_os.zig – Block Explorer (Real-time blockchain inspection)
// Phase 69: Display recent blocks, agent balance, chain statistics
// Memory-mapped @ 0x160000, read-only access to blockchain state

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const BLOCK_EXPLORER_BASE: usize = 0x160000;
pub const MAX_BLOCKS_DISPLAY: usize = 10;
pub const BLOCK_HASH_SIZE: usize = 32;

// ============================================================================
// STRUCTURES
// ============================================================================

pub const BlockInfo = struct {
    height: u64 = 0,
    hash: [BLOCK_HASH_SIZE]u8 = [_]u8{0} ** BLOCK_HASH_SIZE,
    hash_len: u8 = 0,
    timestamp: u64 = 0,
    tx_count: u32 = 0,
    miner: [48]u8 = [_]u8{0} ** 48,  // agent address
    miner_len: u8 = 0,
    status: [16]u8 = [_]u8{0} ** 16,  // "CONFIRMED", "PENDING", etc
    status_len: u8 = 0,
};

pub const BlockExplorerState = struct {
    magic: u32 = 0x424C4B45,  // "BLKE"
    version: u32 = 1,
    initialized: u8 = 0,

    // Recent blocks (circular buffer, last 10)
    blocks: [MAX_BLOCKS_DISPLAY]BlockInfo = [_]BlockInfo{BlockInfo{}} ** MAX_BLOCKS_DISPLAY,
    block_count: u8 = 0,
    current_height: u64 = 0,

    // Agent balance tracking
    agent_balance_omni: u64 = 1_000_000_000_000,  // in smallest units
    agent_balance_sat: u64 = 100_000_000_000,
    balance_locked: u64 = 0,
    balance_pending: u64 = 0,

    // Chain statistics
    total_blocks: u64 = 0,
    total_transactions: u64 = 0,
    total_difficulty: u64 = 256,
    consensus_state: [32]u8 = [_]u8{0} ** 32,
    consensus_len: u8 = 0,

    last_update_tsc: u64 = 0,
    update_count: u32 = 0,

    _reserved: [256]u8 = [_]u8{0} ** 256,
};

var explorer_state: BlockExplorerState = undefined;
var initialized: bool = false;

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init_block_explorer() void {
    if (initialized) return;

    var state = &explorer_state;
    state.magic = 0x424C4B45;
    state.version = 1;
    state.initialized = 1;
    state.block_count = 0;
    state.current_height = 0;
    state.total_blocks = 0;
    state.total_transactions = 0;
    state.update_count = 0;

    // Initialize consensus state
    var pos: u8 = 0;
    const consensus = "OK";
    for (consensus) |c| {
        if (pos < 32) {
            state.consensus_state[pos] = c;
            pos += 1;
        }
    }
    state.consensus_len = pos;

    initialized = true;
}

// ============================================================================
// UPDATE BLOCK EXPLORER WITH NEW BLOCK DATA
// ============================================================================

pub fn add_block(height: u64, hash: [*]const u8, tx_count: u32) void {
    if (!initialized) init_block_explorer();

    var state = &explorer_state;

    // Circular buffer: shift blocks and add new one at end
    if (state.block_count < MAX_BLOCKS_DISPLAY) {
        state.block_count += 1;
    } else {
        // Shift all blocks down
        for (0..MAX_BLOCKS_DISPLAY - 1) |i| {
            state.blocks[i] = state.blocks[i + 1];
        }
    }

    // Add new block at the end
    const idx = if (state.block_count > 0) state.block_count - 1 else 0;
    var block = &state.blocks[idx];

    block.height = height;
    block.timestamp = rdtsc();
    block.tx_count = tx_count;

    // Copy hash (first 32 bytes, display as hex later)
    @memcpy(block.hash[0..BLOCK_HASH_SIZE], hash[0..BLOCK_HASH_SIZE]);
    block.hash_len = BLOCK_HASH_SIZE;

    // Set miner to agent address
    var pos: u8 = 0;
    const miner_addr = "ob_omni_5d7k768kyber5dil_native";
    for (miner_addr) |c| {
        if (pos < 48) {
            block.miner[pos] = c;
            pos += 1;
        }
    }
    block.miner_len = pos;

    // Set status
    pos = 0;
    const status = "CONFIRMED";
    for (status) |c| {
        if (pos < 16) {
            block.status[pos] = c;
            pos += 1;
        }
    }
    block.status_len = pos;

    state.current_height = height;
    state.total_blocks = height;
    state.total_transactions += tx_count;
    state.last_update_tsc = rdtsc();
    state.update_count += 1;
}

// ============================================================================
// UPDATE AGENT BALANCE
// ============================================================================

pub fn update_balance(omni: u64, sat: u64, locked: u64) void {
    if (!initialized) init_block_explorer();

    var state = &explorer_state;
    state.agent_balance_omni = omni;
    state.agent_balance_sat = sat;
    state.balance_locked = locked;
}

// ============================================================================
// UART WRITE HELPER
// ============================================================================

fn uart_write(c: u8) void {
    asm volatile ("outb %al, %dx" : : [v] "{al}" (c), [p] "{dx}" (@as(u16, 0x3F8)));
}

// ============================================================================
// DISPLAY BLOCK EXPLORER TO UART
// ============================================================================

pub fn display_explorer() void {
    if (!initialized) init_block_explorer();

    const state = &explorer_state;

    // Header
    for ("\n") |c| uart_write(c);
    for ("===== OMNIBUS BLOCK EXPLORER =====\n") |c| uart_write(c);

    // Recent blocks
    for ("[RECENT BLOCKS]\n") |c| uart_write(c);
    for (0..state.block_count) |i| {
        const block = &state.blocks[i];

        for ("[Block #") |c| uart_write(c);
        print_u64_uart(block.height);
        for ("] Height: ") |c| uart_write(c);
        print_u64_uart(block.height);
        for (" | Tx: ") |c| uart_write(c);
        print_u32_uart(block.tx_count);
        for ("\n") |c| uart_write(c);

        for ("  Hash: ") |c| uart_write(c);
        // Print first 8 bytes of hash as hex
        for (0..8) |j| {
            const byte = block.hash[j];
            const hex = "0123456789ABCDEF";
            uart_write(hex[byte >> 4]);
            uart_write(hex[byte & 0x0F]);
        }
        for ("...\n") |c| uart_write(c);

        for ("  Status: ") |c| uart_write(c);
        for (block.status[0..block.status_len]) |c| uart_write(c);
        for ("\n\n") |c| uart_write(c);
    }

    // Agent balance
    for ("[AGENT BALANCE]\n") |c| uart_write(c);
    for ("  OMNI: ") |c| uart_write(c);
    print_u64_uart(state.agent_balance_omni / 1_000_000);
    for (".") |c| uart_write(c);
    print_u64_uart((state.agent_balance_omni % 1_000_000) / 100);
    for (" | SAT: ") |c| uart_write(c);
    print_u64_uart(state.agent_balance_sat);
    for ("\n") |c| uart_write(c);

    for ("  Locked: ") |c| uart_write(c);
    print_u64_uart(state.balance_locked);
    for (" | Pending: ") |c| uart_write(c);
    print_u64_uart(state.balance_pending);
    for ("\n\n") |c| uart_write(c);

    // Chain statistics
    for ("[CHAIN STATS]\n") |c| uart_write(c);
    for ("  Total Blocks: ") |c| uart_write(c);
    print_u64_uart(state.total_blocks);
    for (" | Total Tx: ") |c| uart_write(c);
    print_u64_uart(state.total_transactions);
    for ("\n") |c| uart_write(c);

    for ("  Difficulty: ") |c| uart_write(c);
    print_u64_uart(state.total_difficulty);
    for ("-bit | Consensus: ") |c| uart_write(c);
    for (state.consensus_state[0..state.consensus_len]) |c| uart_write(c);
    for ("\n\n") |c| uart_write(c);

    for ("═════════════════════════════════════════════════════════════\n") |c| uart_write(c);
    for ("✅ Block Explorer Active | Updates: ") |c| uart_write(c);
    print_u32_uart(state.update_count);
    for ("\n\n") |c| uart_write(c);
}

// ============================================================================
// UART OUTPUT HELPERS
// ============================================================================

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

pub fn get_explorer_state() *const BlockExplorerState {
    if (!initialized) init_block_explorer();
    return &explorer_state;
}

pub fn get_block_count() u8 {
    if (!initialized) init_block_explorer();
    return explorer_state.block_count;
}

pub fn get_current_height() u64 {
    if (!initialized) init_block_explorer();
    return explorer_state.current_height;
}

pub fn get_total_transactions() u64 {
    if (!initialized) init_block_explorer();
    return explorer_state.total_transactions;
}
