// api_auth_types.zig — API Gateway Authentication (Phase 63)
// JWT token validation, OAuth provider integration, rate limiting

pub const AUTH_BASE: usize = 0x640000;
pub const MAX_TOKENS: usize = 1024;
pub const MAX_OAUTH_PROVIDERS: usize = 8;
pub const TOKEN_EXPIRY_CYCLES: u64 = 262144000;  // ~1000 seconds

pub const TokenType = enum(u8) {
    jwt = 0,
    api_key = 1,
    oauth2 = 2,
    bearer = 3,
};

pub const TokenStatus = enum(u8) {
    valid = 0,
    expired = 1,
    revoked = 2,
    invalid = 3,
};

pub const Token = extern struct {
    token_id: u64,
    user_id: u64,
    token_type: u8,                   // TokenType enum
    status: u8,                       // TokenStatus enum
    _pad1: [2]u8,
    created_cycle: u64,
    expiry_cycle: u64,
    permissions: u64,                 // Bitmask: read=1, write=2, admin=4
    rate_limit_requests: u32,         // Per minute
    rate_limit_remaining: u32,
};

pub const OAuthProvider = extern struct {
    provider_id: u8,                  // 0=Google, 1=Microsoft, 2=GitHub, etc.
    name: [32]u8,
    client_id: [256]u8,
    client_secret: [256]u8,
    token_endpoint: [256]u8,
    user_endpoint: [256]u8,
    is_enabled: u8,
    _pad: [7]u8,
};

pub const RateLimitBucket = extern struct {
    user_id: u64,
    window_start_cycle: u64,
    request_count: u32,
    last_request_cycle: u64,
};

pub const ApiAuthOsState = extern struct {
    magic: u32,                       // 'AUTH'
    flags: u8,
    _pad1: [3]u8,
    cycle_count: u64,
    total_tokens_issued: u32,
    total_tokens_validated: u32,
    total_auth_failures: u32,
    total_rate_limit_hits: u32,
    active_tokens: u32,
    total_oauth_logins: u32,
    _pad2: [28]u8,
};
