// ach.zig — ACH (NACHA format) batch processing for domestic transfers
// Phase 12: Bank settlement - ACH integration
// Creates NACHA formatted ACH batches for US domestic settlement

const types = @import("types.zig");

// NACHA Record Type Codes
pub const RECORD_FILE_HEADER = '1';
pub const RECORD_BATCH_HEADER = '5';
pub const RECORD_ENTRY_DETAIL = '6';
pub const RECORD_ADDENDA = '7';
pub const RECORD_BATCH_CONTROL = '8';
pub const RECORD_FILE_CONTROL = '9';

// ACH Standard Entry Classes
pub const SEC_CODE_CCD = "CCD"; // Corporate Credit or Debit
pub const SEC_CODE_PPD = "PPD"; // Prearranged Payment and Deposit
pub const SEC_CODE_IAT = "IAT"; // International ACH Transaction

// Transaction Codes for Entry Detail Records
pub const TRANS_CODE_CREDIT_CHECKING = 22;
pub const TRANS_CODE_DEBIT_CHECKING = 27;
pub const TRANS_CODE_CREDIT_SAVINGS = 32;
pub const TRANS_CODE_DEBIT_SAVINGS = 37;

// ============================================================================
// NACHA File Header Construction
// ============================================================================

pub const NachaFileHeader = struct {
    priority_code: [2]u8,               // "01"
    immediate_dest: [10]u8,             // Destination routing number (right padded)
    immediate_origin: [10]u8,           // Origin routing number (right padded)
    file_creation_date: [6]u8,          // YYMMDD
    file_creation_time: [4]u8,          // HHMM
    file_id_modifier: u8,               // A-Z, 0-9
    record_size: [5]u8,                 // "094" (standard 94-char records)
    blocking_factor: [2]u8,             // "10" (10 records per block)
    format_code: u8,                    // "1" for ASCII
    destination_name: [23]u8,           // Destination bank name
    origin_name: [23]u8,                // Origin company name
    reference_code: [8]u8,              // Reference code
};

pub const NachaBatchHeader = struct {
    batch_number: [3]u8,                // "001" - "999"
    service_class: [3]u8,               // "200" = mixed debit/credit
    company_name: [16]u8,               // "OmniBus Trading "
    company_discretionary: [20]u8,      // Company discretionary data
    company_id: [10]u8,                 // DUNS or IRS number
    standard_entry_class: [3]u8,        // "CCD", "PPD", "IAT"
    company_entry_description: [10]u8,  // "TRADE SETTL"
    company_descriptive_date: [6]u8,    // YYMMDD
    effective_entry_date: [6]u8,        // YYMMDD
    settlement_date: [3]u8,             // "000" = same day, "001" = next day
    originator_status_code: u8,         // "0" = bank assigned
    originating_bank_routing: [8]u8,    // First 8 chars of routing
    batch_sequence_number: [7]u8,       // Right-justified
};

pub const NachaEntryDetail = struct {
    transaction_code: [2]u8,            // "22"=credit checking, "27"=debit
    receiving_bank_routing: [8]u8,      // First 8 of routing (check digit separate)
    receiving_bank_check_digit: u8,     // Last digit of routing
    receiver_account_number: [17]u8,    // Right-justified, left-padded with spaces
    amount: [10]u8,                     // Right-justified, zero-padded
    individual_id: [15]u8,              // Reference (left-justified, space-padded)
    individual_name: [22]u8,            // Receiver name
    discretionary_data: [2]u8,          // Bank use
    addenda_record_indicator: u8,       // "0" = no addenda, "1" = has addenda
    trace_number: [15]u8,               // Unique trace (RRRRRRRRXXXXXX)
};

// ============================================================================
// ACH Batch Creation
// ============================================================================

/// Create ACH batch header from profit data
pub fn createBatchHeader(
    profit_cents: u64,
    batch_number: u32,
    receiver_routing: [10]u8,
) types.AchBatchHeader {
    var header = types.AchBatchHeader{
        .status = 1, // Pending
        .company_name = [_]u8{0} ** 16,
        .company_id = [_]u8{0} ** 10,
        .originating_bank_routing = [_]u8{0} ** 9,
        .originating_bank_name = [_]u8{0} ** 23,
        .receiving_bank_routing = [_]u8{0} ** 9,
        .receiving_bank_name = [_]u8{0} ** 23,
        .batch_number = batch_number,
        .entry_count = 0,
        .total_debits_cents = 0,
        .total_credits_cents = profit_cents,
        .effective_date = [_]u8{0} ** 6,
        .settlement_date = [_]u8{0} ** 3,
        .tsc_created = rdtsc(),
        .tsc_sent = 0,
        .tsc_confirmed = 0,
        .ach_trace_number = [_]u8{0} ** 15,
        .confirmation_code = 0,
        ._reserved = [_]u8{0} ** 148,
    };

    // Set company name (OmniBus Trading)
    const name = "OmniBus Trading ";
    for (name, 0..) |b, i| {
        if (i < 16) header.company_name[i] = b;
    }

    // Set company ID (placeholder - should be real EIN)
    const eid = "1234567890";
    for (eid, 0..) |b, i| {
        if (i < 10) header.company_id[i] = b;
    }

    // Copy routing numbers
    for (receiver_routing, 0..) |b, i| {
        if (i < 9) header.receiving_bank_routing[i] = b;
    }

    // OmniBus originating bank (placeholder)
    const orig_bank = "012345678";
    for (orig_bank, 0..) |b, i| {
        if (i < 9) header.originating_bank_routing[i] = b;
    }

    // Set effective date (today, YYMMDD format)
    setDateYYMMDD(&header.effective_date, rdtsc());

    // Settlement date: "001" = next day
    header.settlement_date[0] = '0';
    header.settlement_date[1] = '0';
    header.settlement_date[2] = '1';

    return header;
}

/// Create entry detail for ACH batch
pub fn createEntryDetail(
    account_number: [17]u8,
    amount_cents: u64,
    name: [22]u8,
) types.AchEntryDetail {
    var entry = types.AchEntryDetail{
        .status = 0, // Pending
        .transaction_code = TRANS_CODE_CREDIT_CHECKING,
        .receiver_routing = [_]u8{0} ** 9,
        .receiver_account = account_number,
        .amount_cents = amount_cents,
        .trace_number = [_]u8{0} ** 15,
        .individual_id = [_]u8{0} ** 15,
        .individual_name = name,
        .discretionary_data = [_]u8{0} ** 2,
        .addenda_record_indicator = 0,
        .entry_sequence_number = 0,
        .tsc_created = rdtsc(),
        .tsc_settled = 0,
        ._reserved = [_]u8{0} ** 78,
    };

    // Generate trace number (RRRRRRRRXXXXXX format)
    // RRRRRRRR = 8-digit routing, XXXXXX = 6-digit sequence
    formatTraceNumber(&entry.trace_number);

    return entry;
}

/// Calculate ACH processing fee (typically $0.25 - $0.50 per transaction)
pub fn calculateAchFee(amount_cents: u64) u64 {
    // Standard ACH fee: $0.25 (25 cents)
    const standard_fee_cents: u64 = 25;

    // For large transfers, may add percentage (0.05%)
    if (amount_cents > 100_000_00) { // > $100,000
        const percentage_fee = (amount_cents * 5) / 100_000; // 0.05%
        return if (percentage_fee > standard_fee_cents) percentage_fee else standard_fee_cents;
    }

    return standard_fee_cents;
}

/// Validate ACH entry detail
pub fn validateEntry(entry: *const types.AchEntryDetail) bool {
    // Check amount is positive
    if (entry.amount_cents == 0) return false;

    // Check account number is set
    var account_set = false;
    for (entry.receiver_account) |b| {
        if (b != ' ' and b != 0) {
            account_set = true;
            break;
        }
    }

    // Check transaction code is valid
    const valid_codes = [_]u16{
        TRANS_CODE_CREDIT_CHECKING,
        TRANS_CODE_DEBIT_CHECKING,
        TRANS_CODE_CREDIT_SAVINGS,
        TRANS_CODE_DEBIT_SAVINGS,
    };

    var code_valid = false;
    for (valid_codes) |code| {
        if (entry.transaction_code == code) {
            code_valid = true;
            break;
        }
    }

    return account_set and code_valid;
}

/// Format ACH batch for transmission (NACHA format - 94 character records)
pub fn formatBatchRecord(header: *const types.AchBatchHeader) [94]u8 {
    var record: [94]u8 = [_]u8{' '} ** 94;

    var idx: usize = 0;

    // Record type "5" for batch header
    record[idx] = '5';
    idx += 1;

    // Service class code "200" (mixed debit/credit)
    record[idx] = '2';
    idx += 1;
    record[idx] = '0';
    idx += 1;
    record[idx] = '0';
    idx += 1;

    // Company name (16 chars)
    for (header.company_name, 0..) |b, i| {
        if (i < 16 and b != 0) {
            record[idx] = b;
        }
        idx += 1;
    }

    // Company ID (10 chars)
    for (header.company_id, 0..) |b, i| {
        if (i < 10 and b != 0) {
            record[idx] = b;
        }
        idx += 1;
    }

    // Entry count (6 digits, right-justified)
    formatRightJustified(&record, idx, 6, header.entry_count);
    idx += 6;

    // Receiving bank routing (8 digits)
    for (header.receiving_bank_routing[0..8], 0..) |b, i| {
        record[idx + i] = b;
    }
    idx += 8;

    // Effective date (6 chars YYMMDD)
    for (header.effective_date, 0..) |b, i| {
        if (i < 6) record[idx + i] = b;
    }
    idx += 6;

    // Total credits (12 digits, right-justified, zero-padded)
    formatAmountField(&record, idx, 12, header.total_credits_cents);
    idx += 12;

    return record;
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Format right-justified numeric field
fn formatRightJustified(buffer: *[94]u8, start: usize, width: usize, value: u32) void {
    var v = value;
    const idx: usize = start + width;

    if (idx > buffer.len) return;

    // Convert to string, right-justified
    var digits: [10]u8 = [_]u8{0} ** 10;
    var digit_count: usize = 0;

    if (v == 0) {
        digit_count = 1;
        digits[0] = '0';
    } else {
        while (v > 0 and digit_count < 10) : (digit_count += 1) {
            digits[digit_count] = @as(u8, @intCast(v % 10)) + '0';
            v /= 10;
        }
    }

    // Write in reverse order, right-justified
    var write_idx = start + width;
    for (0..digit_count) |i| {
        if (write_idx > 0) {
            write_idx -= 1;
            buffer[write_idx] = digits[digit_count - 1 - i];
        }
    }

    // Pad with zeros on the left
    for (start..write_idx) |i| {
        buffer[i] = '0';
    }
}

/// Format amount in cents as NACHA field (zero-padded, right-justified)
fn formatAmountField(buffer: *[94]u8, start: usize, width: usize, amount_cents: u64) void {
    formatRightJustified(buffer, start, width, @intCast(amount_cents % 1_000_000_000_000));
}

/// Generate unique trace number (RRRRRRRRXXXXXX format)
fn formatTraceNumber(trace: *[15]u8) void {
    const tsc = rdtsc();

    // First 8 chars: simulated routing (00012345)
    const routing = "00012345";
    for (routing, 0..) |b, i| {
        trace[i] = b;
    }

    // Last 6 chars: sequence number (000001-999999)
    const seq = (tsc % 999999) + 1;
    var idx: usize = 14;
    var s = seq;

    for (0..6) |_| {
        if (idx > 7) {
            trace[idx] = @as(u8, @intCast(s % 10)) + '0';
            s /= 10;
            idx -= 1;
        }
    }
}

/// Set YYMMDD date from TSC
fn setDateYYMMDD(date_buffer: *[6]u8, tsc: u64) void {
    _ = tsc;
    // Simplified: just use repeating pattern for now
    // In real system: convert TSC to actual date
    date_buffer[0] = '2';
    date_buffer[1] = '6';
    date_buffer[2] = '1';
    date_buffer[3] = '0';
    date_buffer[4] = '2';
    date_buffer[5] = '8';
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
