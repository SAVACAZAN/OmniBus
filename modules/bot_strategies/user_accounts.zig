// User Accounts – KYC, verification, account management
// Tracks user identity, verification status, and account security

const std = @import("std");
const wallet_state = @import("wallet_state.zig");

// ============================================================================
// ACCOUNT STATUS
// ============================================================================

pub const KycStatus = enum(u8) {
    UNVERIFIED = 0,      // No KYC
    PENDING_VERIFICATION = 1, // KYC in progress
    VERIFIED_LEVEL_1 = 2, // Basic identity verified (email + phone)
    VERIFIED_LEVEL_2 = 3, // Enhanced (passport/ID document)
    VERIFIED_LEVEL_3 = 4, // Maximum (source of funds, bank account)
    SUSPENDED = 5,        // Temporarily locked
    BANNED = 6,           // Permanently banned
};

pub const AccountStatus = enum(u8) {
    ACTIVE = 0,
    LOCKED = 1,
    SUSPENDED = 2,
    CLOSED = 3,
};

// ============================================================================
// USER PROFILE
// ============================================================================

pub const UserProfile = struct {
    user_id: u64,
    email: [64]u8,
    email_len: u8,

    phone: [20]u8,
    phone_len: u8,

    kyc_status: KycStatus = .UNVERIFIED,
    account_status: AccountStatus = .ACTIVE,

    // Identity verification
    full_name: [64]u8 = undefined,
    full_name_len: u8 = 0,
    id_document_hash: [32]u8 = undefined, // SHA256 of identity document
    id_verified: u8 = 0,                   // 0=no, 1=yes

    // Security
    two_factor_enabled: u8 = 0,
    withdrawal_whitelist_enabled: u8 = 0,
    daily_withdrawal_limit: i64 = 0,
    daily_withdrawal_used: i64 = 0,

    // Risk scoring
    risk_score: u8 = 0,  // 0-100 (0=low risk, 100=high risk)
    failed_login_attempts: u8 = 0,
    suspicious_activity_flag: u8 = 0,

    // Account timestamps
    created_at: u64,
    email_verified_at: u64 = 0,
    phone_verified_at: u64 = 0,
    kyc_submitted_at: u64 = 0,
    kyc_approved_at: u64 = 0,
    last_login: u64 = 0,
    last_activity: u64 = 0,

    // Compliance
    accepted_tos: u8 = 0,
    accepted_privacy: u8 = 0,
    accepted_risk_disclosure: u8 = 0,
};

pub const AccountsState = struct {
    // Max 65,536 user accounts
    accounts: [65536]UserProfile = undefined,
    account_count: u32 = 0,

    // Statistics
    total_accounts: u64 = 0,
    verified_users: u64 = 0,
    suspended_users: u64 = 0,
    banned_users: u64 = 0,
};

// ============================================================================
// ACCOUNT CREATION
// ============================================================================

/// Create new user account
pub fn create_account(
    state: *AccountsState,
    user_id: u64,
    email: [64]u8,
    email_len: u8,
    phone: [20]u8,
    phone_len: u8,
    timestamp: u64,
) u64 {
    if (state.account_count >= 65536) return 0;
    if (email_len == 0 or phone_len == 0) return 0;

    // Check email not already used
    if (find_account_by_email(state, email, email_len)) |_| {
        return 0; // Email already exists
    }

    state.accounts[state.account_count] = .{
        .user_id = user_id,
        .email = email,
        .email_len = email_len,
        .phone = phone,
        .phone_len = phone_len,
        .created_at = timestamp,
        .last_activity = timestamp,
    };

    state.account_count += 1;
    state.total_accounts += 1;

    return user_id;
}

// ============================================================================
// EMAIL / PHONE VERIFICATION
// ============================================================================

/// Verify email address
pub fn verify_email(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    account.email_verified_at = timestamp;
    account.last_activity = timestamp;
    return true;
}

/// Verify phone number
pub fn verify_phone(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    account.phone_verified_at = timestamp;
    account.last_activity = timestamp;
    return true;
}

// ============================================================================
// KYC VERIFICATION
// ============================================================================

/// Submit KYC documents
pub fn submit_kyc(
    state: *AccountsState,
    user_id: u64,
    full_name: [64]u8,
    full_name_len: u8,
    id_document_hash: [32]u8,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    // Email and phone must be verified first
    if (account.email_verified_at == 0 or account.phone_verified_at == 0) {
        return false;
    }

    account.full_name = full_name;
    account.full_name_len = full_name_len;
    account.id_document_hash = id_document_hash;
    account.kyc_status = .PENDING_VERIFICATION;
    account.kyc_submitted_at = timestamp;
    account.last_activity = timestamp;

    return true;
}

/// Approve KYC (manual review by compliance officer)
pub fn approve_kyc(
    state: *AccountsState,
    user_id: u64,
    level: KycStatus,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (account.kyc_status != .PENDING_VERIFICATION) {
        return false;
    }

    account.kyc_status = level;
    account.kyc_approved_at = timestamp;
    account.id_verified = 1;
    account.last_activity = timestamp;

    if (level != .SUSPENDED and level != .BANNED) {
        // Re-calculate risk score
        update_risk_score(account);
    }

    return true;
}

/// Reject KYC
pub fn reject_kyc(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (account.kyc_status != .PENDING_VERIFICATION) {
        return false;
    }

    account.kyc_status = .UNVERIFIED;
    account.id_verified = 0;
    account.last_activity = timestamp;

    return true;
}

// ============================================================================
// SECURITY SETTINGS
// ============================================================================

/// Enable two-factor authentication
pub fn enable_2fa(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    account.two_factor_enabled = 1;
    account.last_activity = timestamp;
    return true;
}

/// Set withdrawal whitelist
pub fn enable_whitelist(
    state: *AccountsState,
    user_id: u64,
    daily_limit: i64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (daily_limit <= 0) return false;

    account.withdrawal_whitelist_enabled = 1;
    account.daily_withdrawal_limit = daily_limit;
    account.daily_withdrawal_used = 0;
    account.last_activity = timestamp;
    return true;
}

/// Check withdrawal against daily limit
pub fn can_withdraw(
    state: *AccountsState,
    user_id: u64,
    amount: i64,
) bool {
    const account = find_account(state, user_id) orelse return false;

    if (account.withdrawal_whitelist_enabled == 0) {
        return true; // No limit
    }

    return (account.daily_withdrawal_used + amount) <= account.daily_withdrawal_limit;
}

/// Record withdrawal against daily limit
pub fn record_withdrawal(
    state: *AccountsState,
    user_id: u64,
    amount: i64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (!can_withdraw(state, user_id, amount)) {
        return false;
    }

    account.daily_withdrawal_used += amount;
    account.last_activity = timestamp;
    return true;
}

// ============================================================================
// ACCOUNT LOCK / SUSPEND / BAN
// ============================================================================

/// Suspend account due to suspicious activity
pub fn suspend_account(
    state: *AccountsState,
    user_id: u64,
    reason: u8, // 0=suspicious, 1=manual, 2=kyc_failed, 3=compliance
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    account.account_status = .SUSPENDED;
    account.suspicious_activity_flag = reason;
    account.last_activity = timestamp;

    state.suspended_users += 1;
    return true;
}

/// Ban account permanently
pub fn ban_account(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    account.account_status = .CLOSED;
    account.kyc_status = .BANNED;
    account.last_activity = timestamp;

    state.banned_users += 1;
    return true;
}

/// Unlock suspended account
pub fn unlock_account(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (account.account_status != .SUSPENDED) {
        return false;
    }

    account.account_status = .ACTIVE;
    account.suspicious_activity_flag = 0;
    account.failed_login_attempts = 0;
    account.last_activity = timestamp;

    state.suspended_users = if (state.suspended_users > 0) state.suspended_users - 1 else 0;
    return true;
}

// ============================================================================
// LOGIN / ACTIVITY
// ============================================================================

/// Record login
pub fn record_login(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;

    if (account.account_status != .ACTIVE) {
        // Increment failed attempts
        account.failed_login_attempts += 1;
        if (account.failed_login_attempts >= 5) {
            // Lock after 5 failed attempts
            _ = suspend_account(state, user_id, 1, timestamp);
        }
        return false;
    }

    account.last_login = timestamp;
    account.last_activity = timestamp;
    account.failed_login_attempts = 0;
    return true;
}

/// Record general activity
pub fn record_activity(
    state: *AccountsState,
    user_id: u64,
    timestamp: u64,
) bool {
    const account = find_account_mut(state, user_id) orelse return false;
    account.last_activity = timestamp;
    return true;
}

// ============================================================================
// RISK SCORING
// ============================================================================

fn update_risk_score(account: *UserProfile) void {
    var score: u8 = 0;

    // KYC status
    if (account.kyc_status == .UNVERIFIED) score += 30;
    if (account.kyc_status == .PENDING_VERIFICATION) score += 20;
    if (account.kyc_status == .VERIFIED_LEVEL_1) score += 10;
    if (account.kyc_status == .VERIFIED_LEVEL_2) score = 0;
    if (account.kyc_status == .VERIFIED_LEVEL_3) score = 0;

    // 2FA enabled
    if (account.two_factor_enabled == 0) score += 5;

    // Account age (0 if new)
    if (account.email_verified_at == 0) score += 10;
    if (account.phone_verified_at == 0) score += 10;

    // Failed logins
    if (account.failed_login_attempts >= 3) score += 20;

    // Cap at 100
    if (score > 100) score = 100;
    account.risk_score = score;
}

// ============================================================================
// QUERIES
// ============================================================================

fn find_account_mut(state: *AccountsState, user_id: u64) ?*UserProfile {
    for (0..state.account_count) |i| {
        if (state.accounts[i].user_id == user_id) {
            return &state.accounts[i];
        }
    }
    return null;
}

pub fn find_account(state: *const AccountsState, user_id: u64) ?*const UserProfile {
    for (0..state.account_count) |i| {
        if (state.accounts[i].user_id == user_id) {
            return &state.accounts[i];
        }
    }
    return null;
}

fn find_account_by_email(state: *AccountsState, email: [64]u8, email_len: u8) ?*UserProfile {
    for (0..state.account_count) |i| {
        if (state.accounts[i].email_len == email_len and
            std.mem.eql(u8, &state.accounts[i].email[0..email_len], &email[0..email_len])) {
            return &state.accounts[i];
        }
    }
    return null;
}

pub fn get_account_stats(account: *const UserProfile) struct {
    kyc_status: KycStatus,
    account_status: AccountStatus,
    risk_score: u8,
    two_factor_enabled: u8,
    created_at: u64,
    last_login: u64,
    last_activity: u64,
} {
    return .{
        .kyc_status = account.kyc_status,
        .account_status = account.account_status,
        .risk_score = account.risk_score,
        .two_factor_enabled = account.two_factor_enabled,
        .created_at = account.created_at,
        .last_login = account.last_login,
        .last_activity = account.last_activity,
    };
}

pub fn get_exchange_account_stats(state: *const AccountsState) struct {
    total_accounts: u64,
    verified_users: u64,
    suspended_users: u64,
    banned_users: u64,
} {
    return .{
        .total_accounts = state.total_accounts,
        .verified_users = state.verified_users,
        .suspended_users = state.suspended_users,
        .banned_users = state.banned_users,
    };
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

pub fn example_user_kyc_flow(
    accounts_state: *AccountsState,
    timestamp: u64,
) void {
    // Step 1: Create account
    const user_id = create_account(
        accounts_state,
        1,
        "user@example.com" ++ "\x00" ** 48,
        16,
        "+1234567890" ++ "\x00" ** 9,
        11,
        timestamp,
    );

    if (user_id > 0) {
        // Step 2: Verify email
        _ = verify_email(accounts_state, user_id, timestamp + 1);

        // Step 3: Verify phone
        _ = verify_phone(accounts_state, user_id, timestamp + 2);

        // Step 4: Submit KYC
        _ = submit_kyc(
            accounts_state,
            user_id,
            "John Doe" ++ "\x00" ** 56,
            8,
            "id_doc_hash_32bytes_padding" ++ "\x00" ** 4,
            timestamp + 3,
        );

        // Step 5: Approve KYC (manual review)
        _ = approve_kyc(accounts_state, user_id, .VERIFIED_LEVEL_2, timestamp + 3600);

        // Step 6: Enable 2FA
        _ = enable_2fa(accounts_state, user_id, timestamp + 3600);

        // Step 7: Set withdrawal limits
        _ = enable_whitelist(accounts_state, user_id, 100_000_000, timestamp + 3600);

        // Step 8: Login
        const account = find_account(accounts_state, user_id).?;
        if (account.account_status == .ACTIVE) {
            _ = record_login(accounts_state, user_id, timestamp + 7200);
        }
    }
}
