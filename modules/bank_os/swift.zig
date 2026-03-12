// swift.zig — SWIFT FIN 103 message formatting for international credit transfers
// Phase 12: Bank settlement - SWIFT integration
// Formats SWIFT messages for cross-border settlement to bank accounts

const types = @import("types.zig");

// ============================================================================
// SWIFT Message Formatting
// ============================================================================

/// Format SWIFT block 1 (Application Header) – not stored, just for reference
/// In real SWIFT system, this is handled by bank network infrastructure
pub fn formatSwiftHeader(
    sender_bic: [11]u8,
    receiver_bic: [11]u8,
    message_type: [6]u8,
) [29]u8 {
    _ = receiver_bic;
    _ = message_type;
    var header: [29]u8 = [_]u8{0} ** 29;

    // SWIFT block 1: {1:F01SENDER_BIC_NAMEYYYY0000000000}
    // Format: F (format) + 01 (version) + sender_bic + message_type
    var idx: usize = 0;

    header[idx] = 'F';
    idx += 1;
    header[idx] = '0';
    idx += 1;
    header[idx] = '1';
    idx += 1;

    for (sender_bic) |b| {
        if (b != 0) {
            header[idx] = b;
            idx += 1;
        }
    }

    return header;
}

/// Format SWIFT block 4 (Text Block) – fields 20-72 for credit transfer
pub fn formatSwiftTextBlock(
    reference: [16]u8,
    currency: [3]u8,
    amount_cents: u64,
    sender_account: [34]u8,
    receiver_account: [34]u8,
    receiver_name: [35]u8,
    purpose: [4]u8,
) types.SwiftMessage {
    _ = receiver_name;
    var msg = types.SwiftMessage{
        .status = 1, // Pending
        .sender_bic = [_]u8{0} ** 11,
        .receiver_bic = [_]u8{0} ** 11,
        .sender_account = sender_account,
        .receiver_account = receiver_account,
        .currency = currency,
        .amount_cents = amount_cents,
        .message_type = [_]u8{0} ** 6,
        .reference = reference,
        .tsc_created = rdtsc(),
        .tsc_sent = 0,
        .tsc_confirmed = 0,
        .purpose_code = purpose,
        .narrative = [_]u8{0} ** 140,
        .bank_reference = [_]u8{0} ** 16,
        .confirmation_code = 0,
        ._reserved = [_]u8{0} ** 132,
    };

    // Copy message type "103000"
    msg.message_type[0] = '1';
    msg.message_type[1] = '0';
    msg.message_type[2] = '3';
    msg.message_type[3] = '0';
    msg.message_type[4] = '0';
    msg.message_type[5] = '0';

    // Format field 32A (value date and currency/amount)
    // Format: YYMMDD + CURRENCY + AMOUNT
    var narrative_idx: usize = 0;

    // Field 32A: Value date (e.g., "261028EUR10000,00")
    const narrative = "TRADE SETTLEMENT";
    const narrative_len = 16;
    for (narrative[0..narrative_len]) |b| {
        if (narrative_idx < 140) {
            msg.narrative[narrative_idx] = b;
            narrative_idx += 1;
        }
    }

    return msg;
}

/// Create a SWIFT message for settlement from Grid OS profit
pub fn createSettlementMessage(
    profit_cents: i64,
    destination_account: [34]u8,
    destination_bank_bic: [11]u8,
) types.SwiftMessage {
    _ = destination_bank_bic;
    // Only process positive profit (no settlement for losses)
    if (profit_cents <= 0) {
        return types.SwiftMessage{
            .status = 0,
            .sender_bic = [_]u8{0} ** 11,
            .receiver_bic = [_]u8{0} ** 11,
            .sender_account = [_]u8{0} ** 34,
            .receiver_account = [_]u8{0} ** 34,
            .currency = [_]u8{0} ** 3,
            .amount_cents = 0,
            .message_type = [_]u8{0} ** 6,
            .reference = [_]u8{0} ** 16,
            .tsc_created = 0,
            .tsc_sent = 0,
            .tsc_confirmed = 0,
            .purpose_code = [_]u8{0} ** 4,
            .narrative = [_]u8{0} ** 140,
            .bank_reference = [_]u8{0} ** 16,
            .confirmation_code = 0,
            ._reserved = [_]u8{0} ** 132,
        };
    }

    // OmniBus bank details (placeholder - update with real account)
    var sender_account: [34]u8 = [_]u8{0} ** 34;
    var sender_bic: [11]u8 = [_]u8{0} ** 11;

    // Copy sender details (e.g., "DE89370400440532013000" - German IBAN format)
    const omnibus_iban = "DE89370400440532013000";
    for (omnibus_iban, 0..) |b, i| {
        if (i < 34) sender_account[i] = b;
    }

    const omnibus_bic = "COBADEMDEM";
    for (omnibus_bic, 0..) |b, i| {
        if (i < 11) sender_bic[i] = b;
    }

    // Currency defaults to EUR for international transfers
    var currency: [3]u8 = [_]u8{0} ** 3;
    currency[0] = 'E';
    currency[1] = 'U';
    currency[2] = 'R';

    // Purpose code: TRAD = Trade settlement
    var purpose: [4]u8 = [_]u8{0} ** 4;
    purpose[0] = 'T';
    purpose[1] = 'R';
    purpose[2] = 'A';
    purpose[3] = 'D';

    // Generate unique reference (based on TSC)
    var reference: [16]u8 = [_]u8{0} ** 16;
    const tsc = rdtsc();
    const hex_ref = tsc & 0xFFFFFFFFFFFF; // Use lower 48 bits
    formatHexString(&reference, hex_ref);

    return formatSwiftTextBlock(
        reference,
        currency,
        @intCast(profit_cents),
        sender_account,
        destination_account,
        [_]u8{0} ** 35, // receiver_name (populated elsewhere)
        purpose,
    );
}

/// Calculate SWIFT message fee (0.15% + fixed €5 minimum)
pub fn calculateSwiftFee(amount_cents: u64) u64 {
    const min_fee_cents: u64 = 500; // €5.00

    // Calculate 0.15% fee
    const percentage_fee = (amount_cents * 15) / 10000;

    // Return maximum of percentage fee and minimum fee
    return if (percentage_fee > min_fee_cents) percentage_fee else min_fee_cents;
}

/// Validate SWIFT message structure before sending
pub fn validateSwiftMessage(msg: *const types.SwiftMessage) bool {
    // Check status is valid
    if (msg.status > 3) return false;

    // Check amount is positive
    if (msg.amount_cents == 0) return false;

    // Check currency is 3 characters (not all zeros)
    var currency_count: u32 = 0;
    for (msg.currency) |b| {
        if (b != 0) currency_count += 1;
    }
    if (currency_count != 3) return false;

    // Check accounts are set
    var sender_set = false;
    var receiver_set = false;

    for (msg.sender_account) |b| {
        if (b != 0) {
            sender_set = true;
            break;
        }
    }

    for (msg.receiver_account) |b| {
        if (b != 0) {
            receiver_set = true;
            break;
        }
    }

    return sender_set and receiver_set;
}

/// Parse SWIFT confirmation message (stub for real SWIFT network response)
pub fn parseSwiftConfirmation(confirmation: [16]u8) bool {
    // Check for valid confirmation code pattern
    var valid_count: u32 = 0;
    for (confirmation) |b| {
        // Valid confirmation: alphanumeric characters
        if ((b >= '0' and b <= '9') or (b >= 'A' and b <= 'Z')) {
            valid_count += 1;
        }
    }

    // At least 8 valid characters suggests real confirmation
    return valid_count >= 8;
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Format a 48-bit value as 12-character hex string for SWIFT reference
fn formatHexString(buffer: *[16]u8, value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var idx: usize = 0;

    // Convert to hex, right-aligned in 12 characters
    const v = value;
    var shift: i32 = 44; // 48 bits = 12 hex chars, start at bit 44

    while (shift >= 0) : (shift -= 4) {
        const digit = (v >> @intCast(shift)) & 0xF;
        if (idx < 12) {
            buffer[idx] = hex_chars[digit];
            idx += 1;
        }
    }

    // Pad remaining with zeros
    while (idx < 16) : (idx += 1) {
        buffer[idx] = 0;
    }
}

/// Read current TSC (Time Stamp Counter)
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
