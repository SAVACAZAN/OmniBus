// api_auth_os.zig — API Gateway Authentication (Phase 63)
// JWT validation, OAuth integration, rate limiting per user

const std = @import("std");
const types = @import("api_auth_types.zig");

fn getAuthStatePtr() *volatile types.ApiAuthOsState {
    return @as(*volatile types.ApiAuthOsState, @ptrFromInt(types.AUTH_BASE));
}

fn getTokenPtr(index: usize) *volatile types.Token {
    if (index >= types.MAX_TOKENS) return undefined;
    const base = types.AUTH_BASE + @sizeOf(types.ApiAuthOsState);
    return @as(*volatile types.Token, @ptrFromInt(base + index * @sizeOf(types.Token)));
}

fn getOAuthProviderPtr(index: usize) *volatile types.OAuthProvider {
    if (index >= types.MAX_OAUTH_PROVIDERS) return undefined;
    const base = types.AUTH_BASE + @sizeOf(types.ApiAuthOsState) +
                 types.MAX_TOKENS * @sizeOf(types.Token);
    return @as(*volatile types.OAuthProvider, @ptrFromInt(base + index * @sizeOf(types.OAuthProvider)));
}

fn getRateLimitPtr(index: usize) *volatile types.RateLimitBucket {
    if (index >= types.MAX_TOKENS) return undefined;
    const base = types.AUTH_BASE + @sizeOf(types.ApiAuthOsState) +
                 types.MAX_TOKENS * @sizeOf(types.Token) +
                 types.MAX_OAUTH_PROVIDERS * @sizeOf(types.OAuthProvider);
    return @as(*volatile types.RateLimitBucket, @ptrFromInt(base + index * @sizeOf(types.RateLimitBucket)));
}

export fn init_plugin() void {
    const state = getAuthStatePtr();
    state.magic = 0x41555448;  // 'AUTH'
    state.flags = 0x01;
    state.cycle_count = 0;
    state.total_tokens_issued = 0;
    state.total_tokens_validated = 0;
    state.total_auth_failures = 0;
    state.total_rate_limit_hits = 0;
    state.active_tokens = 0;
    state.total_oauth_logins = 0;

    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const token = getTokenPtr(i);
        token.token_id = 0;
        token.user_id = 0;
        token.token_type = 0;
        token.status = @intFromEnum(types.TokenStatus.invalid);
        token.created_cycle = 0;
        token.expiry_cycle = 0;
        token.permissions = 0;
        token.rate_limit_requests = 100;  // Default: 100 req/min
    }

    i = 0;
    while (i < types.MAX_OAUTH_PROVIDERS) : (i += 1) {
        const provider = getOAuthProviderPtr(i);
        provider.provider_id = @intCast(i);
        provider.is_enabled = 0;
    }
}

export fn issue_jwt_token(user_id: u64, permissions: u64, ttl_cycles: u64) u64 {
    const state = getAuthStatePtr();

    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const slot = getTokenPtr(i);
        if (slot.token_id == 0) {
            slot.token_id = state.total_tokens_issued +| 1;
            slot.user_id = user_id;
            slot.token_type = @intFromEnum(types.TokenType.jwt);
            slot.status = @intFromEnum(types.TokenStatus.valid);
            slot.created_cycle = state.cycle_count;
            slot.expiry_cycle = state.cycle_count + ttl_cycles;
            slot.permissions = permissions;

            state.total_tokens_issued +|= 1;
            state.active_tokens +|= 1;
            return slot.token_id;
        }
    }

    state.total_auth_failures +|= 1;
    return 0;  // Token allocation failed
}

export fn validate_token(token_id: u64) u8 {
    const state = getAuthStatePtr();

    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const token = getTokenPtr(i);
        if (token.token_id == token_id) {
            // Check expiration
            if (state.cycle_count > token.expiry_cycle) {
                token.status = @intFromEnum(types.TokenStatus.expired);
                return 0;
            }

            // Check status
            if (token.status == @intFromEnum(types.TokenStatus.valid)) {
                state.total_tokens_validated +|= 1;
                return 1;  // Valid
            }

            return 0;  // Revoked or invalid
        }
    }

    state.total_auth_failures +|= 1;
    return 0;  // Not found
}

export fn check_rate_limit(user_id: u64, max_requests_per_minute: u32) u8 {
    const state = getAuthStatePtr();
    const window_duration = 262144;  // ~1 second (1 minute window)

    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const bucket = getRateLimitPtr(i);

        // Find or create bucket for user
        if (bucket.user_id == 0) {
            bucket.user_id = user_id;
            bucket.window_start_cycle = state.cycle_count;
            bucket.request_count = 1;
            bucket.last_request_cycle = state.cycle_count;
            return 1;  // Within limit
        }

        if (bucket.user_id == user_id) {
            // Check if window expired
            if ((state.cycle_count - bucket.window_start_cycle) > window_duration) {
                bucket.window_start_cycle = state.cycle_count;
                bucket.request_count = 1;
                bucket.last_request_cycle = state.cycle_count;
                return 1;
            }

            // Check limit
            if (bucket.request_count >= max_requests_per_minute) {
                state.total_rate_limit_hits +|= 1;
                return 0;  // Rate limit exceeded
            }

            bucket.request_count +|= 1;
            bucket.last_request_cycle = state.cycle_count;
            return 1;  // Within limit
        }
    }

    state.total_rate_limit_hits +|= 1;
    return 0;  // Bucket allocation failed
}

export fn revoke_token(token_id: u64) u8 {
    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const token = getTokenPtr(i);
        if (token.token_id == token_id) {
            token.status = @intFromEnum(types.TokenStatus.revoked);
            return 1;
        }
    }
    return 0;  // Token not found
}

export fn run_auth_cycle() void {
    const state = getAuthStatePtr();
    state.cycle_count +|= 1;

    // Cleanup expired tokens
    var i: usize = 0;
    while (i < types.MAX_TOKENS) : (i += 1) {
        const token = getTokenPtr(i);
        if (token.token_id != 0 and state.cycle_count > token.expiry_cycle) {
            if (token.status == @intFromEnum(types.TokenStatus.valid)) {
                token.status = @intFromEnum(types.TokenStatus.expired);
                state.active_tokens = if (state.active_tokens > 0) state.active_tokens - 1 else 0;
            }
        }
    }
}

export fn get_active_tokens() u32 {
    return getAuthStatePtr().active_tokens;
}

export fn get_cycle_count() u64 {
    return getAuthStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getAuthStatePtr();
    return if (state.magic == 0x41555448) 1 else 0;
}
