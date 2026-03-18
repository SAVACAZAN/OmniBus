// OMNI Token System – Primary + 4 Domain-Derived Tokens
// OMNI: Main token (fixed 21M supply)
// LOVE, FOOD, RENT, VACATION: Domain tokens (elastic, 1:1 pegged to OMNI)

const std = @import("std");

// ============================================================================
// TOKEN TYPES
// ============================================================================

pub const TokenType = enum(u8) {
    OMNI = 0,      // Primary: 21M fixed supply
    LOVE = 1,      // Domain token: Romance/social
    FOOD = 2,      // Domain token: Agriculture/supply chain
    RENT = 3,      // Domain token: Real estate
    VACATION = 4,  // Domain token: Travel/leisure
};

pub const TokenMetadata = struct {
    token_type: TokenType,
    name: [32]u8,
    name_len: u8,
    symbol: [16]u8,
    symbol_len: u8,
    decimals: u8,
    total_supply: u64,      // In smallest units (SAT = 10^-8)
    circulating_supply: u64,
    minting_enabled: u8,    // 1 = can mint more (domain tokens only)
    max_supply: u64,        // For domain tokens (can be 0 for unlimited)
};

pub const Balance = struct {
    owner: [64]u8,         // OmniBus address
    owner_len: u8,
    token_type: TokenType,
    free_balance: u64,     // Available to spend
    locked_balance: u64,   // Locked in contracts/stakes
    total_balance: u64,    // free + locked
};

pub const AllowanceEntry = struct {
    owner: [64]u8,
    owner_len: u8,
    spender: [64]u8,
    spender_len: u8,
    token_type: TokenType,
    allowance: u64,
};

// ============================================================================
// GLOBAL TOKEN STATE
// ============================================================================

pub const TokenState = struct {
    // Token metadata (5 tokens)
    tokens: [5]TokenMetadata = undefined,

    // Balances (max 65,536 accounts)
    balances: [65536]Balance = undefined,
    balance_count: u32 = 0,

    // Allowances (delegations)
    allowances: [16384]AllowanceEntry = undefined,
    allowance_count: u32 = 0,

    // Statistics
    total_accounts: u64 = 0,
    total_transactions: u64 = 0,
    total_mints: u64 = 0,
    total_burns: u64 = 0,
};

// ============================================================================
// TOKEN INITIALIZATION
// ============================================================================

pub fn init_tokens() TokenState {
    var state: TokenState = undefined;

    // Initialize OMNI (fixed supply)
    state.tokens[0] = .{
        .token_type = .OMNI,
        .name = "OmniBus" ++ " " ** 24,
        .name_len = 7,
        .symbol = "OMNI" ++ " " ** 12,
        .symbol_len = 4,
        .decimals = 8,
        .total_supply = 21_000_000 * 100_000_000, // 21M OMNI in SAT
        .circulating_supply = 0,
        .minting_enabled = 0, // OMNI cannot be minted
        .max_supply = 21_000_000 * 100_000_000,
    };

    // Initialize LOVE (elastic)
    state.tokens[1] = .{
        .token_type = .LOVE,
        .name = "OmniBus Love Token" ++ " " ** 14,
        .name_len = 18,
        .symbol = "ΩLOVE" ++ " " ** 11,
        .symbol_len = 5,
        .decimals = 8,
        .total_supply = 2_100_000 * 100_000_000, // Initial 2.1M
        .circulating_supply = 0,
        .minting_enabled = 1, // Can mint more
        .max_supply = 0, // Unlimited
    };

    // Initialize FOOD (elastic)
    state.tokens[2] = .{
        .token_type = .FOOD,
        .name = "OmniBus Food Token" ++ " " ** 14,
        .name_len = 18,
        .symbol = "ΩFOOD" ++ " " ** 11,
        .symbol_len = 5,
        .decimals = 8,
        .total_supply = 2_100_000 * 100_000_000,
        .circulating_supply = 0,
        .minting_enabled = 1,
        .max_supply = 0,
    };

    // Initialize RENT (elastic)
    state.tokens[3] = .{
        .token_type = .RENT,
        .name = "OmniBus Rent Token" ++ " " ** 14,
        .name_len = 18,
        .symbol = "ΩRENT" ++ " " ** 11,
        .symbol_len = 5,
        .decimals = 8,
        .total_supply = 2_100_000 * 100_000_000,
        .circulating_supply = 0,
        .minting_enabled = 1,
        .max_supply = 0,
    };

    // Initialize VACATION (elastic)
    state.tokens[4] = .{
        .token_type = .VACATION,
        .name = "OmniBus Vacation Token" ++ " " ** 10,
        .name_len = 22,
        .symbol = "ΩVACA" ++ " " ** 11,
        .symbol_len = 5,
        .decimals = 8,
        .total_supply = 2_100_000 * 100_000_000,
        .circulating_supply = 0,
        .minting_enabled = 1,
        .max_supply = 0,
    };

    return state;
}

// ============================================================================
// BALANCE MANAGEMENT
// ============================================================================

/// Create new token account (account creation fee: 100 SAT)
pub fn create_account(
    state: *TokenState,
    owner: [64]u8,
    owner_len: u8,
) u64 {
    if (state.balance_count >= 65536) return 0;
    if (owner_len == 0 or owner_len > 64) return 0;

    // Check if account already exists
    if (find_balance(state, owner, owner_len, .OMNI)) |_| {
        return 0; // Account already exists
    }

    state.balance_count += 1;
    state.total_accounts += 1;

    return state.total_accounts;
}

/// Transfer tokens between accounts
pub fn transfer(
    state: *TokenState,
    from: [64]u8,
    from_len: u8,
    to: [64]u8,
    to_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    if (amount == 0) return false;

    // Find sender balance
    const from_balance = find_balance_mut(state, from, from_len, token_type) orelse return false;

    // Check sufficient balance
    if (from_balance.free_balance < amount) return false;

    // Create recipient balance if not exists
    var to_balance = find_balance_mut(state, to, to_len, token_type);
    if (to_balance == null) {
        if (state.balance_count >= 65536) return false;
        state.balances[state.balance_count] = .{
            .owner = to,
            .owner_len = to_len,
            .token_type = token_type,
            .free_balance = 0,
            .locked_balance = 0,
            .total_balance = 0,
        };
        to_balance = &state.balances[state.balance_count];
        state.balance_count += 1;
    }

    // Execute transfer
    from_balance.free_balance -= amount;
    from_balance.total_balance -= amount;

    to_balance.?.free_balance += amount;
    to_balance.?.total_balance += amount;

    state.total_transactions += 1;
    return true;
}

/// Mint tokens (only for domain tokens with minting_enabled)
pub fn mint(
    state: *TokenState,
    to: [64]u8,
    to_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    if (amount == 0) return false;

    const token = &state.tokens[@intFromEnum(token_type)];

    // Check if minting is enabled
    if (token.minting_enabled == 0) return false;

    // Check max supply (0 = unlimited)
    if (token.max_supply > 0 and token.total_supply + amount > token.max_supply) {
        return false;
    }

    // Create recipient balance if not exists
    var to_balance = find_balance_mut(state, to, to_len, token_type);
    if (to_balance == null) {
        if (state.balance_count >= 65536) return false;
        state.balances[state.balance_count] = .{
            .owner = to,
            .owner_len = to_len,
            .token_type = token_type,
            .free_balance = 0,
            .locked_balance = 0,
            .total_balance = 0,
        };
        to_balance = &state.balances[state.balance_count];
        state.balance_count += 1;
    }

    // Mint tokens
    to_balance.?.free_balance += amount;
    to_balance.?.total_balance += amount;

    token.total_supply += amount;
    token.circulating_supply += amount;

    state.total_mints += 1;
    return true;
}

/// Burn tokens (remove from circulation)
pub fn burn(
    state: *TokenState,
    from: [64]u8,
    from_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    if (amount == 0) return false;

    const from_balance = find_balance_mut(state, from, from_len, token_type) orelse return false;

    // Check sufficient balance
    if (from_balance.free_balance < amount) return false;

    // Burn
    from_balance.free_balance -= amount;
    from_balance.total_balance -= amount;

    const token = &state.tokens[@intFromEnum(token_type)];
    token.total_supply -= amount;
    token.circulating_supply -= amount;

    state.total_burns += 1;
    return true;
}

// ============================================================================
// LOCKING (for staking, contracts, etc.)
// ============================================================================

pub fn lock_tokens(
    state: *TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    const balance = find_balance_mut(state, owner, owner_len, token_type) orelse return false;

    if (balance.free_balance < amount) return false;

    balance.free_balance -= amount;
    balance.locked_balance += amount;

    return true;
}

pub fn unlock_tokens(
    state: *TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    const balance = find_balance_mut(state, owner, owner_len, token_type) orelse return false;

    if (balance.locked_balance < amount) return false;

    balance.locked_balance -= amount;
    balance.free_balance += amount;

    return true;
}

// ============================================================================
// ALLOWANCES (Approvals for spending)
// ============================================================================

pub fn approve(
    state: *TokenState,
    owner: [64]u8,
    owner_len: u8,
    spender: [64]u8,
    spender_len: u8,
    token_type: TokenType,
    allowance: u64,
) bool {
    if (state.allowance_count >= 16384) return false;

    // Check if allowance already exists
    for (0..state.allowance_count) |i| {
        const entry = &state.allowances[i];
        if (entry.owner_len == owner_len and
            entry.spender_len == spender_len and
            entry.token_type == token_type and
            std.mem.eql(u8, &entry.owner[0..owner_len], &owner[0..owner_len]) and
            std.mem.eql(u8, &entry.spender[0..spender_len], &spender[0..spender_len])) {
            entry.allowance = allowance;
            return true;
        }
    }

    // Create new allowance
    state.allowances[state.allowance_count] = .{
        .owner = owner,
        .owner_len = owner_len,
        .spender = spender,
        .spender_len = spender_len,
        .token_type = token_type,
        .allowance = allowance,
    };

    state.allowance_count += 1;
    return true;
}

pub fn transfer_from(
    state: *TokenState,
    spender: [64]u8,
    spender_len: u8,
    from: [64]u8,
    from_len: u8,
    to: [64]u8,
    to_len: u8,
    token_type: TokenType,
    amount: u64,
) bool {
    // Check allowance
    var allowance: u64 = 0;
    for (0..state.allowance_count) |i| {
        const entry = &state.allowances[i];
        if (entry.owner_len == from_len and
            entry.spender_len == spender_len and
            entry.token_type == token_type and
            std.mem.eql(u8, &entry.owner[0..from_len], &from[0..from_len]) and
            std.mem.eql(u8, &entry.spender[0..spender_len], &spender[0..spender_len])) {
            allowance = entry.allowance;
            break;
        }
    }

    if (allowance < amount) return false;

    // Execute transfer
    if (!transfer(state, from, from_len, to, to_len, token_type, amount)) {
        return false;
    }

    // Decrease allowance
    for (0..state.allowance_count) |i| {
        const entry = &state.allowances[i];
        if (entry.owner_len == from_len and
            entry.spender_len == spender_len and
            entry.token_type == token_type and
            std.mem.eql(u8, &entry.owner[0..from_len], &from[0..from_len]) and
            std.mem.eql(u8, &entry.spender[0..spender_len], &spender[0..spender_len])) {
            entry.allowance -= amount;
            break;
        }
    }

    return true;
}

// ============================================================================
// ATOMIC SWAPS (1:1 cross-token)
// ============================================================================

pub fn atomic_swap(
    state: *TokenState,
    from: [64]u8,
    from_len: u8,
    to: [64]u8,
    to_len: u8,
    token_in: TokenType,
    amount_in: u64,
    token_out: TokenType,
    amount_out: u64,
) bool {
    if (amount_in != amount_out) return false; // 1:1 only

    // Transfer out
    if (!transfer(state, from, from_len, to, to_len, token_in, amount_in)) {
        return false;
    }

    // Transfer back
    if (!transfer(state, to, to_len, from, from_len, token_out, amount_out)) {
        return false;
    }

    return true;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_balance(
    state: *const TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
) ?*const Balance {
    for (0..state.balance_count) |i| {
        const bal = &state.balances[i];
        if (bal.owner_len == owner_len and
            bal.token_type == token_type and
            std.mem.eql(u8, &bal.owner[0..owner_len], &owner[0..owner_len])) {
            return bal;
        }
    }
    return null;
}

fn find_balance_mut(
    state: *TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
) ?*Balance {
    for (0..state.balance_count) |i| {
        const bal = &state.balances[i];
        if (bal.owner_len == owner_len and
            bal.token_type == token_type and
            std.mem.eql(u8, &bal.owner[0..owner_len], &owner[0..owner_len])) {
            return bal;
        }
    }
    return null;
}

pub fn get_balance(
    state: *const TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
) u64 {
    if (find_balance(state, owner, owner_len, token_type)) |bal| {
        return bal.total_balance;
    }
    return 0;
}

pub fn get_free_balance(
    state: *const TokenState,
    owner: [64]u8,
    owner_len: u8,
    token_type: TokenType,
) u64 {
    if (find_balance(state, owner, owner_len, token_type)) |bal| {
        return bal.free_balance;
    }
    return 0;
}

pub fn get_token_info(state: *const TokenState, token_type: TokenType) *const TokenMetadata {
    return &state.tokens[@intFromEnum(token_type)];
}

pub fn get_token_stats(state: *const TokenState) struct {
    total_accounts: u64,
    total_transactions: u64,
    total_mints: u64,
    total_burns: u64,
    omni_supply: u64,
    love_supply: u64,
    food_supply: u64,
    rent_supply: u64,
    vaca_supply: u64,
} {
    return .{
        .total_accounts = state.total_accounts,
        .total_transactions = state.total_transactions,
        .total_mints = state.total_mints,
        .total_burns = state.total_burns,
        .omni_supply = state.tokens[0].total_supply,
        .love_supply = state.tokens[1].total_supply,
        .food_supply = state.tokens[2].total_supply,
        .rent_supply = state.tokens[3].total_supply,
        .vaca_supply = state.tokens[4].total_supply,
    };
}

// ============================================================================
// EXAMPLES
// ============================================================================

pub fn example_token_operations(state: *TokenState) void {
    // User address
    const user1: [64]u8 = "user_1_address_64bytes_padding_with_zeros_______" ++ "______";
    const user2: [64]u8 = "user_2_address_64bytes_padding_with_zeros_______" ++ "______";

    // Create accounts
    _ = create_account(state, user1, 47);
    _ = create_account(state, user2, 47);

    // Mint OMNI airdrop (1000 OMNI = 100 billion SAT)
    _ = mint(state, user1, 47, .OMNI, 1_000 * 100_000_000);

    // Transfer 100 OMNI
    _ = transfer(state, user1, 47, user2, 47, .OMNI, 100 * 100_000_000);

    // User2 now has 100 OMNI
    const balance = get_balance(state, user2, 47, .OMNI);
    if (balance == 100 * 100_000_000) {
        // Success!
    }

    // Atomic swap: 50 OMNI ↔ 50 LOVE
    _ = mint(state, user2, 47, .LOVE, 50 * 100_000_000);
    _ = atomic_swap(state, user1, 47, user2, 47, .OMNI, 50 * 100_000_000, .LOVE, 50 * 100_000_000);

    // Now User1: 850 OMNI + 50 LOVE
    // User2: 150 OMNI + 0 LOVE
}
