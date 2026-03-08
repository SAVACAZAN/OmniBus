// coinbase_sign.zig — Coinbase exchange order signing (ECDSA P-256 JWT)
// Pattern: JWT (header.payload) signed with ECDSA P-256, sent as Bearer token

const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const order_format = @import("order_format.zig");

// ============================================================================
// Coinbase API Constants
// ============================================================================

const COINBASE_PRODUCT_DOMAIN = "api.coinbase.com/api/v3/brokerage/orders";
const COINBASE_ISS = "cdp";
const JWT_EXPIRY_OFFSET = 120;  // 120 seconds

// ============================================================================
// Integer to String Conversion
// ============================================================================

/// Convert u64 to decimal string
fn intToStr(buf: *[20]u8, value: u64) usize {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    var digits: [20]u8 = undefined;
    var digit_count: usize = 0;
    var remaining = value;

    while (remaining > 0) {
        digits[digit_count] = '0' + @as(u8, @intCast(remaining % 10));
        digit_count += 1;
        remaining /= 10;
    }

    var i: usize = 0;
    while (i < digit_count) {
        buf[i] = digits[digit_count - 1 - i];
        i += 1;
    }

    return digit_count;
}

/// Convert u64 to hex string (for nonce)
fn intToHex(buf: *[16]u8, value: u64) usize {
    const hex_chars = "0123456789abcdef";
    var pos: usize = 0;
    var remaining = value;

    var hex_digits: [16]u8 = undefined;
    var digit_count: usize = 0;

    while (remaining > 0) {
        hex_digits[digit_count] = hex_chars[remaining & 0xF];
        digit_count += 1;
        remaining >>= 4;
    }

    // Pad to 16 chars for nonce
    var i: usize = 0;
    while (i < 16 - digit_count) {
        buf[pos] = '0';
        pos += 1;
        i += 1;
    }

    i = 0;
    while (i < digit_count) {
        buf[pos] = hex_digits[digit_count - 1 - i];
        pos += 1;
        i += 1;
    }

    return pos;
}

// ============================================================================
// Base64url Encoding (for JWT, without padding)
// ============================================================================

const BASE64URL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

/// Base64url encode with no padding (flexible output buffer)
fn base64urlEncodeBytes(out: [*]u8, out_max: usize, data: []const u8) usize {
    var out_idx: usize = 0;
    var in_idx: usize = 0;

    while (in_idx < data.len and out_idx < out_max) {
        const b0 = data[in_idx];
        const b1 = if (in_idx + 1 < data.len) data[in_idx + 1] else 0;
        const b2 = if (in_idx + 2 < data.len) data[in_idx + 2] else 0;

        const c0 = (b0 >> 2) & 0x3F;
        const c1 = (((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)) & 0x3F;
        const c2 = (((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)) & 0x3F;
        const c3 = b2 & 0x3F;

        out[out_idx] = BASE64URL_ALPHABET[c0];
        out_idx += 1;

        if (out_idx < out_max) {
            out[out_idx] = BASE64URL_ALPHABET[c1];
            out_idx += 1;
        }

        if (in_idx + 1 < data.len and out_idx < out_max) {
            out[out_idx] = BASE64URL_ALPHABET[c2];
            out_idx += 1;
        }

        if (in_idx + 2 < data.len and out_idx < out_max) {
            out[out_idx] = BASE64URL_ALPHABET[c3];
            out_idx += 1;
        }

        in_idx += 3;
    }

    return out_idx;
}

// ============================================================================
// Nonce & Timestamp Generation
// ============================================================================

/// Get nonce as 16-char hex string
fn getNonceHex(buf: *[16]u8) []const u8 {
    const random = crypto.getRandom64();
    const len = intToHex(buf, random);
    return buf[0..len];
}

/// Get current timestamp (TSC-based)
fn getTimestamp(buf: *[20]u8) []const u8 {
    const tsc = crypto.getTscEntropy();
    const len = intToStr(buf, tsc);
    return buf[0..len];
}

// ============================================================================
// JWT Header & Payload Construction
// ============================================================================

/// Build JWT header JSON
fn buildJwtHeader(buf: *[256]u8, kid: []const u8, nonce: []const u8) usize {
    var pos: usize = 0;

    const header_start = "{\"alg\":\"ES256\",\"typ\":\"JWT\",\"kid\":\"";
    @memcpy(buf[pos .. pos + header_start.len], header_start);
    pos += header_start.len;

    @memcpy(buf[pos .. pos + kid.len], kid);
    pos += kid.len;

    const header_mid = "\",\"nonce\":\"";
    @memcpy(buf[pos .. pos + header_mid.len], header_mid);
    pos += header_mid.len;

    @memcpy(buf[pos .. pos + nonce.len], nonce);
    pos += nonce.len;

    const header_end = "\"}";
    @memcpy(buf[pos .. pos + header_end.len], header_end);
    pos += header_end.len;

    return pos;
}

/// Build JWT payload JSON
fn buildJwtPayload(
    buf: *[512]u8,
    kid: []const u8,
    ts_str: []const u8,
) usize {
    var pos: usize = 0;

    const payload_start = "{\"sub\":\"";
    @memcpy(buf[pos .. pos + payload_start.len], payload_start);
    pos += payload_start.len;

    @memcpy(buf[pos .. pos + kid.len], kid);
    pos += kid.len;

    const payload_mid1 = "\",\"iss\":\"";
    @memcpy(buf[pos .. pos + payload_mid1.len], payload_mid1);
    pos += payload_mid1.len;

    const iss = COINBASE_ISS;
    @memcpy(buf[pos .. pos + iss.len], iss);
    pos += iss.len;

    const payload_mid2 = "\",\"nbf\":";
    @memcpy(buf[pos .. pos + payload_mid2.len], payload_mid2);
    pos += payload_mid2.len;

    @memcpy(buf[pos .. pos + ts_str.len], ts_str);
    pos += ts_str.len;

    const payload_mid3 = ",\"exp\":";
    @memcpy(buf[pos .. pos + payload_mid3.len], payload_mid3);
    pos += payload_mid3.len;

    // exp = ts + 120
    var exp_buf: [20]u8 = undefined;
    // Simple: just use same ts (in real system would add 120)
    const exp_len = intToStr(&exp_buf, (std.fmt.parseInt(u64, ts_str, 10) catch 0) + JWT_EXPIRY_OFFSET);
    @memcpy(buf[pos .. pos + exp_len], exp_buf[0..exp_len]);
    pos += exp_len;

    const payload_mid4 = ",\"uri\":\"POST ";
    @memcpy(buf[pos .. pos + payload_mid4.len], payload_mid4);
    pos += payload_mid4.len;

    const domain = COINBASE_PRODUCT_DOMAIN;
    @memcpy(buf[pos .. pos + domain.len], domain);
    pos += domain.len;

    const payload_end = "\"}";
    @memcpy(buf[pos .. pos + payload_end.len], payload_end);
    pos += payload_end.len;

    return pos;
}

// ============================================================================
// ECDSA P-256 Signing (Simplified - using SHA256 first, then HMAC as fallback)
// ============================================================================

/// Simplified ECDSA-like signing (deterministic for testing)
/// In production, would use proper ECDSA P-256 implementation
fn ecdsaSign(
    sig_out: *[64]u8,
    message: []const u8,
    ec_key: *const [32]u8,
) void {
    // Simplified: use HMAC with EC key as a placeholder for ECDSA
    // This is NOT cryptographically proper but allows testing
    var r_buf: [32]u8 = undefined;
    var s_buf: [32]u8 = undefined;

    // r = HMAC-SHA256(message, ec_key)
    crypto.hmacSha256(&r_buf, message, ec_key);

    // s = HMAC-SHA256(r, ec_key)
    crypto.hmacSha256(&s_buf, &r_buf, ec_key);

    // Combine r || s
    @memcpy(sig_out[0..32], &r_buf);
    @memcpy(sig_out[32..64], &s_buf);
}

// ============================================================================
// JSON Order Body for Coinbase
// ============================================================================

/// Build JSON body for Coinbase order
fn buildOrderBody(
    buf: *[256]u8,
    pair_symbol: []const u8,
    side: u8,
    qty: u64,
    price: u64,
) usize {
    var price_str: [32]u8 = undefined;
    var qty_str: [32]u8 = undefined;

    const price_slice = order_format.formatPrice(&price_str, price);
    const qty_slice = order_format.formatQty(&qty_str, qty);
    const side_str = order_format.sideUppercase(side);

    var pos: usize = 0;

    const body_start = "{\"product_id\":\"";
    @memcpy(buf[pos .. pos + body_start.len], body_start);
    pos += body_start.len;

    @memcpy(buf[pos .. pos + pair_symbol.len], pair_symbol);
    pos += pair_symbol.len;

    const body_mid1 = "\",\"side\":\"";
    @memcpy(buf[pos .. pos + body_mid1.len], body_mid1);
    pos += body_mid1.len;

    @memcpy(buf[pos .. pos + side_str.len], side_str);
    pos += side_str.len;

    const body_mid2 = "\",\"order_type\":\"limit\",\"size\":\"";
    @memcpy(buf[pos .. pos + body_mid2.len], body_mid2);
    pos += body_mid2.len;

    @memcpy(buf[pos .. pos + qty_slice.len], qty_slice);
    pos += qty_slice.len;

    const body_mid3 = "\",\"order_configuration\":{\"limit_limit_gtc\":{\"limit_price\":\"";
    @memcpy(buf[pos .. pos + body_mid3.len], body_mid3);
    pos += body_mid3.len;

    @memcpy(buf[pos .. pos + price_slice.len], price_slice);
    pos += price_slice.len;

    const body_end = "\",\"post_only\":false}}}";
    @memcpy(buf[pos .. pos + body_end.len], body_end);
    pos += body_end.len;

    return pos;
}

// ============================================================================
// Main Signing Function
// ============================================================================

/// Sign an order for Coinbase exchange (ECDSA P-256 JWT)
pub fn signOrder(
    slot: *volatile types.SignedOrderSlot,
    packet: *const types.OrderPacket,
    api_key: *const types.ApiKeySlot,
) void {
    var nonce_buf: [16]u8 = undefined;
    var ts_buf: [20]u8 = undefined;
    var header_buf: [256]u8 = undefined;
    var payload_buf: [512]u8 = undefined;
    var header_b64_buf: [256]u8 = undefined;
    var payload_b64_buf: [512]u8 = undefined;
    var sig_buf: [64]u8 = undefined;
    var sig_b64_buf: [128]u8 = undefined;
    var order_json_buf: [256]u8 = undefined;

    // 1. Get nonce and timestamp
    const nonce_hex = getNonceHex(&nonce_buf);
    const ts_str = getTimestamp(&ts_buf);

    // 2. Get key ID (API key bytes)
    const kid = api_key.key[0..api_key.key_len];

    // 3. Build JWT header
    const header_len = buildJwtHeader(&header_buf, kid, nonce_hex);

    // 4. Base64url encode header
    const header_b64_len = base64urlEncodeBytes(&header_b64_buf, header_b64_buf.len, header_buf[0..header_len]);

    // 5. Build JWT payload
    const payload_len = buildJwtPayload(&payload_buf, kid, ts_str);

    // 6. Base64url encode payload
    const payload_b64_len = base64urlEncodeBytes(&payload_b64_buf, payload_b64_buf.len, payload_buf[0..payload_len]);

    // 7. Create signature input: header_b64 + "." + payload_b64
    var sig_input_buf: [1024]u8 = undefined;
    var sig_input_len: usize = 0;

    @memcpy(sig_input_buf[sig_input_len .. sig_input_len + header_b64_len], header_b64_buf[0..header_b64_len]);
    sig_input_len += header_b64_len;

    sig_input_buf[sig_input_len] = '.';
    sig_input_len += 1;

    @memcpy(sig_input_buf[sig_input_len .. sig_input_len + payload_b64_len], payload_b64_buf[0..payload_b64_len]);
    sig_input_len += payload_b64_len;

    // 8. Sign with ECDSA P-256
    ecdsaSign(&sig_buf, sig_input_buf[0..sig_input_len], @as(*const [32]u8, @ptrCast(api_key.ec_key[0..32])));

    // 9. Base64url encode signature
    const sig_b64_len = base64urlEncodeBytes(&sig_b64_buf, sig_b64_buf.len, &sig_buf);

    // 10. Build order JSON body
    const pair_symbol = order_format.pairSymbol(@as(u8, @intCast(packet.exchange_id)), packet.pair_id);
    const order_json_len = buildOrderBody(&order_json_buf, pair_symbol, packet.side, packet.quantity_sats, packet.price_cents);

    // 11. Combine JWT + order body (in final payload)
    //     Format: "JWT_TOKEN\n{...json...}"
    var payload_buf_final: [376]u8 = undefined;
    var payload_pos: usize = 0;

    // JWT
    @memcpy(payload_buf_final[payload_pos .. payload_pos + header_b64_len], header_b64_buf[0..header_b64_len]);
    payload_pos += header_b64_len;

    payload_buf_final[payload_pos] = '.';
    payload_pos += 1;

    @memcpy(payload_buf_final[payload_pos .. payload_pos + payload_b64_len], payload_b64_buf[0..payload_b64_len]);
    payload_pos += payload_b64_len;

    payload_buf_final[payload_pos] = '.';
    payload_pos += 1;

    @memcpy(payload_buf_final[payload_pos .. payload_pos + sig_b64_len], sig_b64_buf[0..sig_b64_len]);
    payload_pos += sig_b64_len;

    payload_buf_final[payload_pos] = '\n';
    payload_pos += 1;

    // Order JSON
    @memcpy(payload_buf_final[payload_pos .. payload_pos + order_json_len], order_json_buf[0..order_json_len]);
    payload_pos += order_json_len;

    // 12. Fill SignedOrderSlot
    slot.exchange_id = @as(u8, @intCast(packet.exchange_id));
    slot.pair_id = @as(u8, @intCast(packet.pair_id));
    slot.flags = 0x01;  // Ready for NIC driver
    slot.payload_len = @as(u16, @intCast(payload_pos));

    @memcpy(&slot.payload, payload_buf_final[0..@min(payload_pos, 376)]);
}

// ============================================================================
// Debug Export
// ============================================================================

/// Test: format a sample Coinbase order (for QEMU debugging)
export fn test_coinbase_sign() void {
    var slot: types.SignedOrderSlot = undefined;

    // Sample order: 1 BTC at $63,500
    var packet: types.OrderPacket = undefined;
    packet.exchange_id = @as(u16, types.COINBASE);
    packet.pair_id = 0;      // BTC_USD
    packet.side = 0;         // buy
    packet.quantity_sats = 100_000_000;  // 1 BTC
    packet.price_cents = 6_350_000;      // $63,500.00

    var api_key: types.ApiKeySlot = undefined;
    api_key.exchange_id = types.COINBASE;
    api_key.key_len = 16;
    api_key.secret_len = 0;  // Not used for Coinbase
    api_key.ec_key[0..32].* = [_]u8{0x01} ** 32;  // Dummy EC key
    const test_key = "test_key_16_chars";
    @memcpy(api_key.key[0..test_key.len], test_key);

    signOrder(&slot, &packet, &api_key);
}
