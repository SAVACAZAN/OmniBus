// ============================================================================
// Status Token OS (Zig/Bare Metal)
// Non-transferable tokens: LOVE, FOOD, RENT, VACATION
// Native to OmniBus blockchain
// ============================================================================

const std = @import("std");
const builtin = @import("builtin");

// Memory layout (0x560000 – 0x56FFFF, 64KB)
const STATUS_TOKEN_BASE: usize = 0x560000;

// Token types (domain-based PQ algorithms)
const TokenType = enum(u8) {
    OMNI = 0,      // Native (Kyber-768)
    LOVE = 1,      // Kyber-768 (ML-KEM)
    FOOD = 2,      // Falcon-512 (FN-DSA)
    RENT = 3,      // Dilithium-5 (ML-DSA)
    VACATION = 4,  // SPHINCS+ (SLH-DSA)
};

// Token balance entry (16 bytes each)
const BalanceEntry = struct {
    address: u64,           // OmniBus address
    amount: u64,            // Token amount (u64, 18 decimals implicit)
    locked: u8,             // Non-transferable: always locked
    reserved: [7]u8,        // Padding
};

// Status Token State Header (128 bytes @ 0x560000)
const StatusTokenState = struct {
    magic: u32 = 0x53544F4B,  // "STOK"
    version: u16 = 1,
    reserved: u16 = 0,

    // Token configuration
    token_type: u8,            // Which token (LOVE/FOOD/RENT/VACATION)
    pq_algorithm: u8,          // 1=Kyber, 2=Falcon, 3=Dilithium, 4=SPHINCS+
    transfers_enabled: u8 = 0, // Always 0 (non-transferable)
    reserved2: u8 = 0,

    // Supply tracking
    total_supply: u64,         // Total minted
    total_burned: u64,         // Total burned
    balance_count: u32,        // Number of holders
    reserved3: u32 = 0,

    // Metadata
    owner_address: u64,        // Owner/admin
    minter_address: u64,       // Only address allowed to mint
    last_update: u64,          // Timestamp of last operation
    reserved4: u64 = 0,
};

// ============================================================================
// Module State (4 instances: LOVE, FOOD, RENT, VACATION)
// ============================================================================

var love_state: StatusTokenState = undefined;
var food_state: StatusTokenState = undefined;
var rent_state: StatusTokenState = undefined;
var vaca_state: StatusTokenState = undefined;

// Balance storage (simple linear array, indexed by address hash)
var love_balances: [256]BalanceEntry = undefined;
var food_balances: [256]BalanceEntry = undefined;
var rent_balances: [256]BalanceEntry = undefined;
var vaca_balances: [256]BalanceEntry = undefined;

// ============================================================================
// PUBLIC API
// ============================================================================

/// Initialize status token module
pub fn init_plugin() void {
    // Initialize LOVE token
    love_state = .{
        .magic = 0x53544F4B,
        .version = 1,
        .token_type = @intFromEnum(TokenType.LOVE),
        .pq_algorithm = 1, // Kyber-768
        .transfers_enabled = 0,
        .total_supply = 0,
        .total_burned = 0,
        .balance_count = 0,
        .owner_address = 0x1000, // TODO: Set by governance
        .minter_address = 0x1001, // On-ramp address
        .last_update = 0,
    };

    // Initialize FOOD token
    food_state = .{
        .magic = 0x53544F4B,
        .version = 1,
        .token_type = @intFromEnum(TokenType.FOOD),
        .pq_algorithm = 2, // Falcon-512
        .transfers_enabled = 0,
        .total_supply = 0,
        .total_burned = 0,
        .balance_count = 0,
        .owner_address = 0x1000,
        .minter_address = 0x1001,
        .last_update = 0,
    };

    // Initialize RENT token
    rent_state = .{
        .magic = 0x53544F4B,
        .version = 1,
        .token_type = @intFromEnum(TokenType.RENT),
        .pq_algorithm = 3, // Dilithium-5
        .transfers_enabled = 0,
        .total_supply = 0,
        .total_burned = 0,
        .balance_count = 0,
        .owner_address = 0x1000,
        .minter_address = 0x1001,
        .last_update = 0,
    };

    // Initialize VACATION token
    vaca_state = .{
        .magic = 0x53544F4B,
        .version = 1,
        .token_type = @intFromEnum(TokenType.VACATION),
        .pq_algorithm = 4, // SPHINCS+
        .transfers_enabled = 0,
        .total_supply = 0,
        .total_burned = 0,
        .balance_count = 0,
        .owner_address = 0x1000,
        .minter_address = 0x1001,
        .last_update = 0,
    };

    // Clear balance arrays
    for (0..256) |i| {
        love_balances[i] = .{ .address = 0, .amount = 0, .locked = 1, .reserved = .{0} ** 7 };
        food_balances[i] = .{ .address = 0, .amount = 0, .locked = 1, .reserved = .{0} ** 7 };
        rent_balances[i] = .{ .address = 0, .amount = 0, .locked = 1, .reserved = .{0} ** 7 };
        vaca_balances[i] = .{ .address = 0, .amount = 0, .locked = 1, .reserved = .{0} ** 7 };
    }
}

/// Mint status tokens to address
pub fn mint_token(token_type: u8, to_address: u64, amount: u64) u8 {
    // Only minter can call
    const caller = 0x1001; // TODO: Get from IPC caller context
    if (caller != 0x1001) {
        return 1; // Error: unauthorized
    }

    const state = get_state_mut(token_type) orelse return 2; // Error: invalid token
    const balances = get_balances_mut(token_type) orelse return 2;

    // Find or create balance entry
    const slot = find_balance_slot(balances, to_address);
    if (slot >= 256) {
        return 3; // Error: balance array full
    }

    if (balances[slot].address == 0) {
        // New holder
        balances[slot].address = to_address;
        balances[slot].amount = amount;
        balances[slot].locked = 1;
        state.balance_count += 1;
    } else {
        // Existing holder
        balances[slot].amount +|= amount; // Saturating add
    }

    state.total_supply +|= amount;
    state.last_update = get_tsc();

    return 0; // Success
}

/// Burn status tokens from address
pub fn burn_token(token_type: u8, from_address: u64, amount: u64) u8 {
    const state = get_state_mut(token_type) orelse return 2;
    const balances = get_balances_mut(token_type) orelse return 2;

    // Find balance entry
    const slot = find_balance_slot(balances, from_address);
    if (slot >= 256 or balances[slot].address != from_address) {
        return 3; // Error: address not found
    }

    const balance = &balances[slot];
    if (balance.amount < amount) {
        return 4; // Error: insufficient balance
    }

    balance.amount -= amount;
    state.total_supply -|= amount; // Saturating sub
    state.last_update = get_tsc();

    // Clear slot if empty
    if (balance.amount == 0) {
        balance.address = 0;
        state.balance_count -|= 1;
    }

    return 0; // Success
}

/// Get token balance
pub fn get_balance(token_type: u8, address: u64) u64 {
    const balances = get_balances(token_type) orelse return 0;
    const slot = find_balance_slot(balances, address);

    if (slot < 256 and balances[slot].address == address) {
        return balances[slot].amount;
    }

    return 0;
}

/// Get total supply
pub fn get_total_supply(token_type: u8) u64 {
    const state = get_state(token_type) orelse return 0;
    return state.total_supply;
}

/// Transfer is always rejected (non-transferable)
pub fn transfer(token_type: u8, _from: u64, _to: u64, _amount: u64) u8 {
    _ = token_type;
    _ = _from;
    _ = _to;
    _ = _amount;
    return 1; // Always rejected
}

/// Approve is always rejected
pub fn approve(_token_type: u8, _spender: u64, _amount: u64) u8 {
    _ = _token_type;
    _ = _spender;
    _ = _amount;
    return 1; // Always rejected
}

// ============================================================================
// IPC Interface (Opcodes 0x71–0x77)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0x71 => mint_ipc(arg0, arg1),           // mint(token_type, to_address), amount in arg1
        0x72 => burn_ipc(arg0, arg1),           // burn(token_type, from_address), amount in arg1
        0x73 => get_balance_ipc(arg0, arg1),    // get_balance(token_type, address)
        0x74 => get_supply_ipc(arg0, 0),        // get_total_supply(token_type)
        0x75 => transfer_ipc(arg0, arg1),       // transfer (always fails)
        0x76 => get_state_info_ipc(arg0, 0),    // get_state_info(token_type)
        0x77 => run_st_cycle(),                 // run_st_cycle()
        else => 0xFFFFFFFF, // Unknown opcode
    };
}

fn mint_ipc(token_type: u64, to_address: u64) u64 {
    const result = mint_token(@intCast(token_type & 0xFF), to_address, 1e18);
    return if (result == 0) 1 else 0;
}

fn burn_ipc(token_type: u64, from_address: u64) u64 {
    const result = burn_token(@intCast(token_type & 0xFF), from_address, 1e18);
    return if (result == 0) 1 else 0;
}

fn get_balance_ipc(token_type: u64, address: u64) u64 {
    return get_balance(@intCast(token_type & 0xFF), address);
}

fn get_supply_ipc(token_type: u64, _unused: u64) u64 {
    _ = _unused;
    return get_total_supply(@intCast(token_type & 0xFF));
}

fn transfer_ipc(token_type: u64, _unused: u64) u64 {
    _ = token_type;
    _ = _unused;
    return 0; // Always fails
}

fn get_state_info_ipc(token_type: u64, _unused: u64) u64 {
    _ = _unused;
    const state = get_state(@intCast(token_type & 0xFF)) orelse return 0;
    return state.total_supply;
}

fn run_st_cycle() u64 {
    // Periodic maintenance (called by kernel scheduler)
    const tsc = get_tsc();

    // Update last cycle time (could trigger cleanup, rebalancing, etc.)
    love_state.last_update = tsc;
    food_state.last_update = tsc;
    rent_state.last_update = tsc;
    vaca_state.last_update = tsc;

    return 1; // Success
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn get_state(token_type: u8) ?*const StatusTokenState {
    return switch (token_type) {
        1 => &love_state,
        2 => &food_state,
        3 => &rent_state,
        4 => &vaca_state,
        else => null,
    };
}

fn get_state_mut(token_type: u8) ?*StatusTokenState {
    return switch (token_type) {
        1 => &love_state,
        2 => &food_state,
        3 => &rent_state,
        4 => &vaca_state,
        else => null,
    };
}

fn get_balances(token_type: u8) ?*const [256]BalanceEntry {
    return switch (token_type) {
        1 => &love_balances,
        2 => &food_balances,
        3 => &rent_balances,
        4 => &vaca_balances,
        else => null,
    };
}

fn get_balances_mut(token_type: u8) ?*[256]BalanceEntry {
    return switch (token_type) {
        1 => &love_balances,
        2 => &food_balances,
        3 => &rent_balances,
        4 => &vaca_balances,
        else => null,
    };
}

fn find_balance_slot(balances: *const [256]BalanceEntry, address: u64) usize {
    const hash = address % 256;

    // Linear probing
    for (0..256) |i| {
        const idx = (hash + i) % 256;
        if (balances[idx].address == 0 or balances[idx].address == address) {
            return idx;
        }
    }

    return 256; // Not found
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
