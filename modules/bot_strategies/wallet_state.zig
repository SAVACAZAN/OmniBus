// Wallet State – User balance tracking for local exchange
// Tracks all user assets across multiple tokens/chains
// No dynamic allocation – fixed-size arrays for determinism

const std = @import("std");

// ============================================================================
// TOKEN DEFINITIONS
// ============================================================================

pub const TokenId = enum(u8) {
    OMNI = 0,      // OmniBus native token
    USDC = 1,      // USD Coin (Polygon, Solana, Base)
    USDT = 2,      // Tether
    BTC = 3,       // Bitcoin (wrapped)
    ETH = 4,       // Ethereum
    SOL = 5,       // Solana
    MATIC = 6,     // Polygon
    BASE = 7,      // Base token
};

pub const ChainId = enum(u8) {
    POLYGON = 0,   // Polygon (137)
    SOLANA = 1,    // Solana
    BASE = 2,      // Base (8453)
    ETHEREUM = 3,  // Ethereum mainnet
};

pub const TokenInfo = struct {
    token_id: TokenId,
    name: [16]u8,        // "OMNI", "USDC", etc.
    decimals: u8,        // 6 for USDC, 8 for BTC, 18 for ETH
    total_supply: i64,   // Fixed-point
    min_trade_size: i64, // Minimum order size
};

// ============================================================================
// BALANCE TRACKING
// ============================================================================

pub const UserBalance = struct {
    token_id: TokenId,
    chain_id: ChainId,
    available: i64,      // Can withdraw or use for orders
    locked: i64,         // Locked in open orders
    total: i64,          // available + locked
    last_updated: u64,   // Timestamp
};

pub const UserWallet = struct {
    user_id: u64,
    address: [32]u8,     // User address/public key
    address_len: u8,

    // Balance ledger (max 1024 different token/chain combinations)
    balances: [1024]UserBalance = undefined,
    balance_count: u32 = 0,

    // Statistics
    total_deposits: i64 = 0,   // Total amount deposited
    total_withdrawals: i64 = 0, // Total amount withdrawn
    total_volume_traded: i64 = 0,

    created_at: u64,
    last_activity: u64,
};

pub const WalletState = struct {
    // Max 65,536 users on local exchange
    wallets: [65536]UserWallet = undefined,
    wallet_count: u32 = 0,

    // Token registry
    tokens: [16]TokenInfo = undefined,
    token_count: u8 = 0,

    // Exchange statistics
    total_users: u64 = 0,
    total_deposits: i64 = 0,
    total_withdrawals: i64 = 0,
    total_locked_in_orders: i64 = 0,
};

// ============================================================================
// USER ACCOUNT CREATION
// ============================================================================

/// Create new user wallet
pub fn create_user_wallet(
    state: *WalletState,
    user_id: u64,
    address: [32]u8,
    address_len: u8,
    timestamp: u64,
) u64 {
    if (state.wallet_count >= 65536) return 0;

    state.wallets[state.wallet_count] = .{
        .user_id = user_id,
        .address = address,
        .address_len = address_len,
        .created_at = timestamp,
        .last_activity = timestamp,
    };

    state.wallet_count += 1;
    state.total_users += 1;

    return user_id;
}

// ============================================================================
// DEPOSIT / WITHDRAWAL
// ============================================================================

/// Deposit tokens into user wallet
pub fn deposit(
    state: *WalletState,
    user_id: u64,
    token_id: TokenId,
    chain_id: ChainId,
    amount: i64,
    timestamp: u64,
) bool {
    const wallet = find_wallet_mut(state, user_id) orelse return false;
    if (amount <= 0) return false;

    // Find or create balance entry
    var balance_idx: ?usize = null;
    for (0..wallet.balance_count) |i| {
        if (wallet.balances[i].token_id == token_id and
            wallet.balances[i].chain_id == chain_id) {
            balance_idx = i;
            break;
        }
    }

    if (balance_idx == null) {
        if (wallet.balance_count >= 1024) return false;
        balance_idx = wallet.balance_count;
        wallet.balance_count += 1;
    }

    const idx = balance_idx.?;
    wallet.balances[idx] = .{
        .token_id = token_id,
        .chain_id = chain_id,
        .available = wallet.balances[idx].available + amount,
        .locked = wallet.balances[idx].locked,
        .total = wallet.balances[idx].total + amount,
        .last_updated = timestamp,
    };

    wallet.total_deposits += amount;
    state.total_deposits += amount;
    wallet.last_activity = timestamp;

    return true;
}

/// Withdraw tokens from user wallet
pub fn withdraw(
    state: *WalletState,
    user_id: u64,
    token_id: TokenId,
    chain_id: ChainId,
    amount: i64,
    timestamp: u64,
) bool {
    const wallet = find_wallet_mut(state, user_id) orelse return false;
    if (amount <= 0) return false;

    // Find balance
    const balance = find_balance_mut(wallet, token_id, chain_id) orelse return false;

    // Check sufficient available balance
    if (balance.available < amount) return false;

    balance.available -= amount;
    balance.total -= amount;
    balance.last_updated = timestamp;

    wallet.total_withdrawals += amount;
    state.total_withdrawals += amount;
    wallet.last_activity = timestamp;

    return true;
}

// ============================================================================
// LOCK / UNLOCK (for pending orders)
// ============================================================================

/// Lock tokens when order is created (prevents double-spending)
pub fn lock_for_order(
    state: *WalletState,
    user_id: u64,
    token_id: TokenId,
    chain_id: ChainId,
    amount: i64,
    timestamp: u64,
) bool {
    const wallet = find_wallet_mut(state, user_id) orelse return false;
    if (amount <= 0) return false;

    const balance = find_balance_mut(wallet, token_id, chain_id) orelse return false;

    // Check sufficient available balance
    if (balance.available < amount) return false;

    balance.available -= amount;
    balance.locked += amount;
    balance.last_updated = timestamp;

    state.total_locked_in_orders += amount;
    wallet.last_activity = timestamp;

    return true;
}

/// Unlock tokens when order is cancelled
pub fn unlock_from_order(
    state: *WalletState,
    user_id: u64,
    token_id: TokenId,
    chain_id: ChainId,
    amount: i64,
    timestamp: u64,
) bool {
    const wallet = find_wallet_mut(state, user_id) orelse return false;
    if (amount <= 0) return false;

    const balance = find_balance_mut(wallet, token_id, chain_id) orelse return false;

    // Check sufficient locked balance
    if (balance.locked < amount) return false;

    balance.available += amount;
    balance.locked -= amount;
    balance.last_updated = timestamp;

    state.total_locked_in_orders -= amount;
    wallet.last_activity = timestamp;

    return true;
}

/// Complete order: move from locked to opposite token
pub fn complete_order(
    state: *WalletState,
    user_id: u64,
    pay_token: TokenId,
    pay_chain: ChainId,
    pay_amount: i64,
    receive_token: TokenId,
    receive_chain: ChainId,
    receive_amount: i64,
    timestamp: u64,
) bool {
    const wallet = find_wallet_mut(state, user_id) orelse return false;

    // Unlock paid token
    const pay_balance = find_balance_mut(wallet, pay_token, pay_chain) orelse return false;
    if (pay_balance.locked < pay_amount) return false;

    pay_balance.locked -= pay_amount;
    state.total_locked_in_orders -= pay_amount;

    // Add received token
    var receive_balance = find_balance_mut(wallet, receive_token, receive_chain);
    if (receive_balance == null) {
        if (wallet.balance_count >= 1024) return false;
        wallet.balances[wallet.balance_count] = .{
            .token_id = receive_token,
            .chain_id = receive_chain,
            .available = 0,
            .locked = 0,
            .total = 0,
            .last_updated = timestamp,
        };
        receive_balance = &wallet.balances[wallet.balance_count];
        wallet.balance_count += 1;
    }

    receive_balance.?.available += receive_amount;
    receive_balance.?.total += receive_amount;
    receive_balance.?.last_updated = timestamp;

    wallet.total_volume_traded += pay_amount;
    wallet.last_activity = timestamp;

    return true;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_wallet_mut(state: *WalletState, user_id: u64) ?*UserWallet {
    for (0..state.wallet_count) |i| {
        if (state.wallets[i].user_id == user_id) {
            return &state.wallets[i];
        }
    }
    return null;
}

pub fn get_wallet(state: *const WalletState, user_id: u64) ?*const UserWallet {
    for (0..state.wallet_count) |i| {
        if (state.wallets[i].user_id == user_id) {
            return &state.wallets[i];
        }
    }
    return null;
}

fn find_balance_mut(wallet: *UserWallet, token_id: TokenId, chain_id: ChainId) ?*UserBalance {
    for (0..wallet.balance_count) |i| {
        if (wallet.balances[i].token_id == token_id and
            wallet.balances[i].chain_id == chain_id) {
            return &wallet.balances[i];
        }
    }
    return null;
}

pub fn get_balance(wallet: *const UserWallet, token_id: TokenId, chain_id: ChainId) ?*const UserBalance {
    for (0..wallet.balance_count) |i| {
        if (wallet.balances[i].token_id == token_id and
            wallet.balances[i].chain_id == chain_id) {
            return &wallet.balances[i];
        }
    }
    return null;
}

/// Get total balance (available + locked)
pub fn get_total_balance(wallet: *const UserWallet, token_id: TokenId, chain_id: ChainId) i64 {
    if (get_balance(wallet, token_id, chain_id)) |bal| {
        return bal.total;
    }
    return 0;
}

/// Get available balance
pub fn get_available_balance(wallet: *const UserWallet, token_id: TokenId, chain_id: ChainId) i64 {
    if (get_balance(wallet, token_id, chain_id)) |bal| {
        return bal.available;
    }
    return 0;
}

/// Get locked balance
pub fn get_locked_balance(wallet: *const UserWallet, token_id: TokenId, chain_id: ChainId) i64 {
    if (get_balance(wallet, token_id, chain_id)) |bal| {
        return bal.locked;
    }
    return 0;
}

pub fn get_wallet_stats(wallet: *const UserWallet) struct {
    balance_count: u32,
    total_deposits: i64,
    total_withdrawals: i64,
    total_volume_traded: i64,
    created_at: u64,
    last_activity: u64,
} {
    return .{
        .balance_count = wallet.balance_count,
        .total_deposits = wallet.total_deposits,
        .total_withdrawals = wallet.total_withdrawals,
        .total_volume_traded = wallet.total_volume_traded,
        .created_at = wallet.created_at,
        .last_activity = wallet.last_activity,
    };
}

pub fn get_exchange_stats(state: *const WalletState) struct {
    total_users: u64,
    total_deposits: i64,
    total_withdrawals: i64,
    total_locked_in_orders: i64,
} {
    return .{
        .total_users = state.total_users,
        .total_deposits = state.total_deposits,
        .total_withdrawals = state.total_withdrawals,
        .total_locked_in_orders = state.total_locked_in_orders,
    };
}

// ============================================================================
// TOKEN MANAGEMENT
// ============================================================================

/// Register new token
pub fn register_token(
    state: *WalletState,
    token_id: TokenId,
    name: [16]u8,
    decimals: u8,
    total_supply: i64,
    min_trade_size: i64,
) bool {
    if (state.token_count >= 16) return false;

    state.tokens[state.token_count] = .{
        .token_id = token_id,
        .name = name,
        .decimals = decimals,
        .total_supply = total_supply,
        .min_trade_size = min_trade_size,
    };

    state.token_count += 1;
    return true;
}

pub fn get_token_info(state: *const WalletState, token_id: TokenId) ?*const TokenInfo {
    for (0..state.token_count) |i| {
        if (state.tokens[i].token_id == token_id) {
            return &state.tokens[i];
        }
    }
    return null;
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

pub fn example_user_deposit_and_balance(
    state: *WalletState,
    timestamp: u64,
) void {
    // Create user wallet
    const user_id = create_user_wallet(
        state,
        1,
        "user1_address_32bytes_padding" ++ "\x00" ** 2,
        30,
        timestamp,
    );

    if (user_id > 0) {
        // Deposit USDC on Polygon
        _ = deposit(
            state,
            user_id,
            .USDC,
            .POLYGON,
            1000_000_000, // 1,000 USDC (6 decimals)
            timestamp,
        );

        // Deposit OMNI on Solana
        _ = deposit(
            state,
            user_id,
            .OMNI,
            .SOLANA,
            50_000_000_000, // 50 OMNI (8 decimals)
            timestamp,
        );

        // Query balances
        const wallet = get_wallet(state, user_id).?;
        const usdc_avail = get_available_balance(wallet, .USDC, .POLYGON);
        const omni_avail = get_available_balance(wallet, .OMNI, .SOLANA);

        // Both should be positive
        if (usdc_avail > 0 and omni_avail > 0) {
            // Lock USDC for order
            _ = lock_for_order(
                state,
                user_id,
                .USDC,
                .POLYGON,
                500_000_000, // Lock 500 USDC for pending order
                timestamp + 1,
            );

            // Now available is 500, locked is 500
            _ = get_available_balance(wallet, .USDC, .POLYGON);
            _ = get_locked_balance(wallet, .USDC, .POLYGON);

            // If order fills: swap USDC for OMNI
            _ = complete_order(
                state,
                user_id,
                .USDC,
                .POLYGON,
                500_000_000,
                .OMNI,
                .SOLANA,
                25_000_000_000, // 25 OMNI received
                timestamp + 2,
            );

            // Now: USDC avail=500, OMNI avail=75
        }
    }
}
