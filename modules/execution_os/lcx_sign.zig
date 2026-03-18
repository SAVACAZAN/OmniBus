// lcx_sign.zig — LCX exchange order signing (HMAC-SHA256 + JSON body)
// LCX is the simplest: just HMAC-SHA256 and JSON formatting
// Pattern: ts + body_json → HMAC-SHA256 → Base64

const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const order_format = @import("order_format.zig");

// ============================================================================
// LCX Signing Parameters
// ============================================================================

/// LCX API endpoint path
const LCX_PATH = "/api/orders";

// ============================================================================
// JSON Body Builder (fixed-size scratch buffer)
// ============================================================================

/// Build JSON body for LCX order
/// {"symbol":"BTC/EUR","type":"limit","side":"buy","amount":1.0,"price":63500.0}
fn buildJsonBody(
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

    const side_str = order_format.sideLowercase(side);

    // Build JSON manually to avoid allocator
    var pos: usize = 0;

    // Opening brace
    buf[pos] = '{';
    pos += 1;

    // "symbol":"BTC/EUR"
    const symbol_template = "\"symbol\":\"";
    @memcpy(buf[pos .. pos + symbol_template.len], symbol_template);
    pos += symbol_template.len;
    @memcpy(buf[pos .. pos + pair_symbol.len], pair_symbol);
    pos += pair_symbol.len;
    buf[pos] = '"';
    pos += 1;
    buf[pos] = ',';
    pos += 1;

    // "type":"limit"
    const type_template = "\"type\":\"limit\",";
    @memcpy(buf[pos .. pos + type_template.len], type_template);
    pos += type_template.len;

    // "side":"buy"/"sell"
    const side_template = "\"side\":\"";
    @memcpy(buf[pos .. pos + side_template.len], side_template);
    pos += side_template.len;
    @memcpy(buf[pos .. pos + side_str.len], side_str);
    pos += side_str.len;
    buf[pos] = '"';
    pos += 1;
    buf[pos] = ',';
    pos += 1;

    // "amount":1.00000000
    const amount_template = "\"amount\":";
    @memcpy(buf[pos .. pos + amount_template.len], amount_template);
    pos += amount_template.len;
    @memcpy(buf[pos .. pos + qty_slice.len], qty_slice);
    pos += qty_slice.len;
    buf[pos] = ',';
    pos += 1;

    // "price":63500.00
    const price_template = "\"price\":";
    @memcpy(buf[pos .. pos + price_template.len], price_template);
    pos += price_template.len;
    @memcpy(buf[pos .. pos + price_slice.len], price_slice);
    pos += price_slice.len;

    // Closing brace
    buf[pos] = '}';
    pos += 1;

    return pos;
}

// ============================================================================
// Base64 Encoding (for HMAC signature)
// ============================================================================

const BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Encode 32-byte HMAC to Base64 (44 characters + padding)
fn base64Encode(out: *[44]u8, data: *const [32]u8) void {
    var out_idx: usize = 0;
    var in_idx: usize = 0;

    while (in_idx < 32) {
        const b0 = data[in_idx];
        const b1 = if (in_idx + 1 < 32) data[in_idx + 1] else 0;
        const b2 = if (in_idx + 2 < 32) data[in_idx + 2] else 0;

        const c0 = (b0 >> 2) & 0x3F;
        const c1 = (((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)) & 0x3F;
        const c2 = (((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)) & 0x3F;
        const c3 = b2 & 0x3F;

        out[out_idx] = BASE64_ALPHABET[c0];
        out_idx += 1;
        out[out_idx] = BASE64_ALPHABET[c1];
        out_idx += 1;

        if (in_idx + 1 < 32) {
            out[out_idx] = BASE64_ALPHABET[c2];
            out_idx += 1;
        } else {
            out[out_idx] = '=';
            out_idx += 1;
        }

        if (in_idx + 2 < 32) {
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
// Timestamp Generation
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

/// Get current timestamp as decimal string (TSC-based proxy)
fn getTimestampStr(buf: *[20]u8) []const u8 {
    const tsc = crypto.getTscEntropy();
    const len = intToStr(buf, tsc);
    return buf[0..len];
}

// ============================================================================
// Main Signing Function
// ============================================================================

/// Sign an order for LCX exchange
/// Fills SignedOrderSlot with JSON body + HMAC-SHA256 signature
pub fn signOrder(
    slot: *volatile types.SignedOrderSlot,
    packet: *const types.OrderPacket,
    api_key: *const types.ApiKeySlot,
) void {
    var json_buf: [256]u8 = undefined;
    var ts_buf: [20]u8 = undefined;
    var hmac_buf: [32]u8 = undefined;
    var sig_buf: [44]u8 = undefined;

    // 1. Get pair symbol
    const pair_sym = order_format.pairSymbol(@as(u8, @intCast(packet.exchange_id)), packet.pair_id);

    // 2. Build JSON body
    const json_len = buildJsonBody(&json_buf, pair_sym, packet.side, packet.quantity_sats, packet.price_cents);
    const json_slice = json_buf[0..json_len];

    // 3. Get timestamp (for headers; can be omitted in body for now)
    _ = getTimestampStr(&ts_buf);

    // 4. Build request string: "POST" + "/api/orders" + body_json
    var req_buf: [512]u8 = undefined;
    var req_pos: usize = 0;

    const method = "POST";
    @memcpy(req_buf[req_pos .. req_pos + method.len], method);
    req_pos += method.len;

    @memcpy(req_buf[req_pos .. req_pos + LCX_PATH.len], LCX_PATH);
    req_pos += LCX_PATH.len;

    @memcpy(req_buf[req_pos .. req_pos + json_len], json_slice);
    req_pos += json_len;

    const req_slice = req_buf[0..req_pos];

    // 5. HMAC-SHA256 over request string with API secret
    crypto.hmacSha256(&hmac_buf, req_slice, api_key.secret[0..api_key.secret_len]);

    // 6. Base64 encode HMAC
    base64Encode(&sig_buf, &hmac_buf);

    // 7. Build final payload: JSON + headers as comments (or prepare for C driver)
    //    For now, just put the JSON in payload; C driver adds headers
    var payload_buf: [376]u8 = undefined;
    var payload_pos: usize = 0;

    // Write JSON body
    @memcpy(payload_buf[payload_pos .. payload_pos + json_len], json_slice);
    payload_pos += json_len;

    // 8. Fill SignedOrderSlot
    slot.exchange_id = @as(u8, @intCast(packet.exchange_id));
    slot.pair_id = @as(u8, @intCast(packet.pair_id));
    slot.flags = 0x01;  // Ready for NIC driver
    slot.payload_len = @as(u16, @intCast(payload_pos));

    @memcpy(&slot.payload, &payload_buf);
}

// ============================================================================
// Debug Export
// ============================================================================

/// Test: format a sample LCX order (for QEMU debugging)
export fn test_lcx_sign() void {
    var slot: types.SignedOrderSlot = undefined;

    // Sample order: 1 BTC at $63,500
    var packet: types.OrderPacket = undefined;
    packet.exchange_id = @as(u16, types.LCX);
    packet.pair_id = 0;      // BTC_USD
    packet.side = 0;         // buy
    packet.quantity_sats = 100_000_000;  // 1 BTC
    packet.price_cents = 6_350_000;      // $63,500.00

    var api_key: types.ApiKeySlot = undefined;
    api_key.exchange_id = types.LCX;
    api_key.key_len = 16;
    api_key.secret_len = 32;
    const test_key = "test_key_16_chars";
    const test_secret = "test_secret_32_byte_key_long_enou";
    @memcpy(api_key.key[0..test_key.len], test_key);
    @memcpy(api_key.secret[0..test_secret.len], test_secret);

    signOrder(&slot, &packet, &api_key);
}
