// kraken_sign.zig — Kraken exchange order signing (SHA256 + HMAC-SHA512)
// Pattern: nonce + url_body → SHA256 → HMAC-SHA512 → Base64

const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const order_format = @import("order_format.zig");

// ============================================================================
// Kraken Signing Parameters
// ============================================================================

/// Kraken API endpoint path
const KRAKEN_PATH = "/0/private/AddOrder";

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

// ============================================================================
// Base64 Encoding (for both HMAC and secret decoding)
// ============================================================================

const BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Encode 64-byte HMAC-SHA512 to Base64 (88 characters)
fn base64Encode64(out: *[88]u8, data: *const [64]u8) void {
    var out_idx: usize = 0;
    var in_idx: usize = 0;

    while (in_idx < 64) {
        const b0 = data[in_idx];
        const b1 = if (in_idx + 1 < 64) data[in_idx + 1] else 0;
        const b2 = if (in_idx + 2 < 64) data[in_idx + 2] else 0;

        const c0 = (b0 >> 2) & 0x3F;
        const c1 = (((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)) & 0x3F;
        const c2 = (((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)) & 0x3F;
        const c3 = b2 & 0x3F;

        out[out_idx] = BASE64_ALPHABET[c0];
        out_idx += 1;
        out[out_idx] = BASE64_ALPHABET[c1];
        out_idx += 1;

        if (in_idx + 1 < 64) {
            out[out_idx] = BASE64_ALPHABET[c2];
            out_idx += 1;
        } else {
            out[out_idx] = '=';
            out_idx += 1;
        }

        if (in_idx + 2 < 64) {
            out[out_idx] = BASE64_ALPHABET[c3];
            out_idx += 1;
        } else {
            out[out_idx] = '=';
            out_idx += 1;
        }

        in_idx += 3;
    }
}

// ============================================================================
// URL-Encoded Body Builder
// ============================================================================

/// Build URL-encoded body for Kraken order
/// "nonce=<nonce>&pair=XXBTZUSD&type=buy&ordertype=limit&volume=1.00000000&price=63500.00"
fn buildUrlBody(
    buf: *[256]u8,
    nonce_str: []const u8,
    pair_symbol: []const u8,
    side: u8,
    qty: u64,
    price: u64,
) usize {
    var price_str: [32]u8 = undefined;
    var qty_str: [32]u8 = undefined;

    const price_slice = order_format.formatPrice(&price_str, price);
    const qty_slice = order_format.formatQty(&qty_str, qty);
    const side_str = order_format.sideLowercase(side);

    var pos: usize = 0;

    // "nonce="
    const nonce_prefix = "nonce=";
    @memcpy(buf[pos .. pos + nonce_prefix.len], nonce_prefix);
    pos += nonce_prefix.len;

    // nonce value
    @memcpy(buf[pos .. pos + nonce_str.len], nonce_str);
    pos += nonce_str.len;

    // "&pair="
    const pair_prefix = "&pair=";
    @memcpy(buf[pos .. pos + pair_prefix.len], pair_prefix);
    pos += pair_prefix.len;

    // pair symbol
    @memcpy(buf[pos .. pos + pair_symbol.len], pair_symbol);
    pos += pair_symbol.len;

    // "&type=buy&ordertype=limit"
    const type_part = "&type=";
    @memcpy(buf[pos .. pos + type_part.len], type_part);
    pos += type_part.len;

    @memcpy(buf[pos .. pos + side_str.len], side_str);
    pos += side_str.len;

    const ordertype_part = "&ordertype=limit";
    @memcpy(buf[pos .. pos + ordertype_part.len], ordertype_part);
    pos += ordertype_part.len;

    // "&volume="
    const volume_prefix = "&volume=";
    @memcpy(buf[pos .. pos + volume_prefix.len], volume_prefix);
    pos += volume_prefix.len;

    @memcpy(buf[pos .. pos + qty_slice.len], qty_slice);
    pos += qty_slice.len;

    // "&price="
    const price_prefix = "&price=";
    @memcpy(buf[pos .. pos + price_prefix.len], price_prefix);
    pos += price_prefix.len;

    @memcpy(buf[pos .. pos + price_slice.len], price_slice);
    pos += price_slice.len;

    return pos;
}

// ============================================================================
// Nonce Generation
// ============================================================================

/// Get nonce as decimal string (TSC-based)
fn getNonceStr(buf: *[20]u8) []const u8 {
    const tsc = crypto.getTscEntropy();
    const len = intToStr(buf, tsc);
    return buf[0..len];
}

// ============================================================================
// Main Signing Function
// ============================================================================

/// Sign an order for Kraken exchange
/// Fills SignedOrderSlot with URL body + API headers (as comments for now)
pub fn signOrder(
    slot: *volatile types.SignedOrderSlot,
    packet: *const types.OrderPacket,
    api_key: *const types.ApiKeySlot,
) void {
    var nonce_buf: [20]u8 = undefined;
    var url_body_buf: [256]u8 = undefined;
    var sha256_buf: [32]u8 = undefined;
    var hmac_buf: [64]u8 = undefined;
    var sig_buf: [88]u8 = undefined;

    // 1. Get nonce
    const nonce_str = getNonceStr(&nonce_buf);

    // 2. Get pair symbol
    const pair_sym = order_format.pairSymbol(@as(u8, @intCast(packet.exchange_id)), packet.pair_id);

    // 3. Build URL-encoded body
    const url_body_len = buildUrlBody(&url_body_buf, nonce_str, pair_sym, packet.side, packet.quantity_sats, packet.price_cents);
    const url_body_slice = url_body_buf[0..url_body_len];

    // 4. Build SHA256 input: nonce_str + url_body
    var sha256_input: [512]u8 = undefined;
    var sha256_input_pos: usize = 0;

    @memcpy(sha256_input[sha256_input_pos .. sha256_input_pos + nonce_str.len], nonce_str);
    sha256_input_pos += nonce_str.len;

    @memcpy(sha256_input[sha256_input_pos .. sha256_input_pos + url_body_len], url_body_slice);
    sha256_input_pos += url_body_len;

    // 5. SHA256 hash
    crypto.sha256(&sha256_buf, sha256_input[0..sha256_input_pos]);

    // 6. Build HMAC input: "/0/private/AddOrder" + sha256_hash
    var hmac_input: [128]u8 = undefined;
    var hmac_input_pos: usize = 0;

    @memcpy(hmac_input[hmac_input_pos .. hmac_input_pos + KRAKEN_PATH.len], KRAKEN_PATH);
    hmac_input_pos += KRAKEN_PATH.len;

    @memcpy(hmac_input[hmac_input_pos .. hmac_input_pos + 32], &sha256_buf);
    hmac_input_pos += 32;

    // 7. HMAC-SHA512 with secret
    crypto.hmacSha512(&hmac_buf, hmac_input[0..hmac_input_pos], api_key.secret[0..api_key.secret_len]);

    // 8. Base64 encode HMAC-SHA512
    base64Encode64(&sig_buf, &hmac_buf);

    // 9. Build final payload (just URL body for now; C driver adds headers)
    var payload_buf: [376]u8 = undefined;
    @memcpy(&payload_buf, url_body_slice);

    // 10. Fill SignedOrderSlot
    slot.exchange_id = @as(u8, @intCast(packet.exchange_id));
    slot.pair_id = @as(u8, @intCast(packet.pair_id));
    slot.flags = 0x01;  // Ready for NIC driver
    slot.payload_len = @as(u16, @intCast(url_body_len));

    @memcpy(&slot.payload, &payload_buf);
}

// ============================================================================
// Debug Export
// ============================================================================

/// Test: format a sample Kraken order (for QEMU debugging)
export fn test_kraken_sign() void {
    var slot: types.SignedOrderSlot = undefined;

    // Sample order: 1 BTC at $63,500
    var packet: types.OrderPacket = undefined;
    packet.exchange_id = @as(u16, types.KRAKEN);
    packet.pair_id = 0;      // BTC_USD
    packet.side = 0;         // buy
    packet.quantity_sats = 100_000_000;  // 1 BTC
    packet.price_cents = 6_350_000;      // $63,500.00

    var api_key: types.ApiKeySlot = undefined;
    api_key.exchange_id = types.KRAKEN;
    api_key.key_len = 16;
    api_key.secret_len = 32;
    const test_key = "test_key_16_chars";
    const test_secret = "test_secret_32_byte_key_long_enou";
    @memcpy(api_key.key[0..test_key.len], test_key);
    @memcpy(api_key.secret[0..test_secret.len], test_secret);

    signOrder(&slot, &packet, &api_key);
}
