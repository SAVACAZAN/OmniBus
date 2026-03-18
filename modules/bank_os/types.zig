// types.zig — BankOS type definitions for SWIFT/ACH settlement
// Phase 12: Bank settlement integration (SWIFT FIN 103 + ACH NACHA)
// Memory: 0x280000–0x2AFFFF (192KB)

// ============================================================================
// Memory Layout
// ============================================================================

pub const BANK_OS_BASE: usize = 0x280000;
pub const BLOCKCHAIN_BASE: usize = 0x250000;
pub const GRID_OS_BASE: usize = 0x110000;
pub const KERNEL_AUTH: usize = 0x100050;

// Offsets within bank memory
pub const BANK_STATE_OFFSET: usize = 0;
pub const SWIFT_REQUEST_OFFSET: usize = 64;
pub const ACH_REQUEST_OFFSET: usize = 512;
pub const SETTLEMENT_QUEUE_OFFSET: usize = 1024;

// Capacity limits
pub const MAX_SWIFT_REQUESTS: u32 = 8;
pub const MAX_ACH_BATCHES: u32 = 16;
pub const MAX_SETTLEMENT_ITEMS: u32 = 256;

// ============================================================================
// BankState — Module Header (64 bytes)
// ============================================================================

pub const BankState = struct {
    magic: u32,                         // 0x424E4B4F = "BNKO"
    flags: u32,                         // Active flag + settings
    cycle_count: u64,                   // Cycles processed
    swift_count: u32,                   // Total SWIFT messages sent
    ach_batch_count: u32,               // Total ACH batches processed
    settlement_count: u64,              // Total settlements completed
    pending_amount_cents: u64,          // Outstanding settlement amount
    tsc_last_update: u64,               // Last TSC timestamp
    _reserved: [20]u8 = undefined,      // Padding to 64 bytes
};

// ============================================================================
// SWIFT Message Types (SWIFT FIN 103 for Credit Transfers)
// ============================================================================

/// SWIFT FIN 103 message for international credit transfer
pub const SwiftMessage = struct {
    status: u8,                         // 0=idle, 1=pending, 2=sent, 3=confirmed
    _pad0: u8 = 0,
    _pad1: u16 = 0,

    // Standard SWIFT blocks
    sender_bic: [11]u8,                 // Sender bank BIC code (e.g., "KRAUWDE33")
    receiver_bic: [11]u8,               // Receiver bank BIC code

    // Addresses (IBAN or account number)
    sender_account: [34]u8,             // Sender IBAN
    receiver_account: [34]u8,           // Receiver IBAN

    // Transfer details
    currency: [3]u8,                    // "EUR", "USD", etc.
    amount_cents: u64,                  // Amount in cents (fixed-point)

    // Message headers
    message_type: [6]u8,                // "103000" = FIN 103
    reference: [16]u8,                  // Unique transaction reference

    // Timestamps
    tsc_created: u64,                   // When message was created
    tsc_sent: u64,                      // When message was sent
    tsc_confirmed: u64,                 // When confirmation received

    // Purpose and details
    purpose_code: [4]u8,                // "TRAD" = Trade settlement
    narrative: [140]u8,                 // 70A narrative text field

    // Confirmation data
    bank_reference: [16]u8,             // Bank's transaction reference
    confirmation_code: u32,             // Swift confirmation code

    _reserved: [132]u8 = undefined,     // Padding
};

// ============================================================================
// ACH Batch (NACHA format for domestic ACH transfers)
// ============================================================================

/// ACH batch header (NACHA format)
pub const AchBatchHeader = struct {
    status: u8,                         // 0=idle, 1=pending, 2=sent, 3=confirmed
    _pad0: u8 = 0,
    _pad1: u16 = 0,

    // Originating company (sender)
    company_name: [16]u8,               // "OmniBus Trading "
    company_id: [10]u8,                 // DUNS number or IRS number

    // Originating bank
    originating_bank_routing: [9]u8,    // Bank routing number
    originating_bank_name: [23]u8,      // Bank name

    // Receiving bank
    receiving_bank_routing: [9]u8,      // Destination bank routing
    receiving_bank_name: [23]u8,        // Destination bank name

    // Batch details
    batch_number: u32,                  // Sequential batch number
    entry_count: u32,                   // Number of entries in batch
    total_debits_cents: u64,            // Sum of all debits (cents)
    total_credits_cents: u64,           // Sum of all credits (cents)

    // Control information
    effective_date: [6]u8,              // YYMMDD format
    settlement_date: [3]u8,             // Number of days forward

    // Timestamps
    tsc_created: u64,
    tsc_sent: u64,
    tsc_confirmed: u64,

    // Confirmation
    ach_trace_number: [15]u8,           // ACH trace number
    confirmation_code: u32,

    _reserved: [148]u8 = undefined,     // Padding
};

/// ACH entry detail (individual transaction within batch)
pub const AchEntryDetail = struct {
    status: u8,                         // 0=pending, 1=settled, 2=returned
    _pad0: u8 = 0,

    // Transaction routing
    transaction_code: u16,              // 22=debit checking, 32=credit checking

    // Account numbers (masked for security)
    receiver_routing: [9]u8,            // Receiver bank routing
    receiver_account: [17]u8,           // Receiver account number

    // Transaction amount
    amount_cents: u64,                  // In cents

    // Reference and tracking
    trace_number: [15]u8,               // Unique trace number
    individual_id: [15]u8,              // Individual/entity ID

    // Name and description
    individual_name: [22]u8,            // Receiving party name
    discretionary_data: [2]u8,          // Bank use

    // Identification & addenda
    addenda_record_indicator: u8,       // 0=no addenda, 1=has addenda
    _pad2: u8 = 0,
    entry_sequence_number: u32,         // Sequence in batch

    // Timestamps and status
    tsc_created: u64,
    tsc_settled: u64,

    _reserved: [78]u8 = undefined,      // Padding
};

// ============================================================================
// Settlement Request (unified interface for Grid OS → BankOS)
// ============================================================================

/// Settlement request from Grid OS (profit to be withdrawn)
pub const SettlementRequest = struct {
    status: u8,                         // 0=idle, 1=pending, 2=processing, 3=settled
    settlement_type: u8,                // 1=SWIFT, 2=ACH, 3=internal
    _pad0: u16 = 0,

    // Source (Grid OS profit)
    source_grid_profit_cents: i64,      // Signed: can be negative

    // Destination account
    destination_account: [34]u8,        // IBAN or account number
    destination_bank_routing: [9]u8,    // Bank routing
    destination_bank_name: [23]u8,      // Bank name

    // Settlement amount (may differ from profit due to fees)
    settlement_amount_cents: u64,       // Actual amount to settle
    currency: [3]u8,                    // "USD", "EUR", etc.

    // Purpose
    purpose_code: [4]u8,                // "TRAD" = Trade settlement
    reference: [16]u8,                  // Transaction reference

    // Timestamps
    tsc_requested: u64,                 // When request was made
    tsc_confirmed: u64,                 // When settlement confirmed

    // Confirmation data
    bank_confirmation: [16]u8,          // Bank's confirmation code
    settlement_fee_cents: u64,          // Fee deducted by bank
    net_received_cents: u64,            // Final amount received

    _reserved: [104]u8 = undefined,     // Padding
};

// ============================================================================
// ACH Addenda Record (for 94 character narratives)
// ============================================================================

pub const AchAddendaRecord = struct {
    addenda_type_code: u8,              // 05 = remittance information
    _pad: u8 = 0,

    payment_related_info: [80]u8,       // Remittance information
    sequence_number: u32,               // Addenda sequence
    entry_detail_sequence: u32,         // Points to entry detail

    _reserved: [80]u8 = undefined,
};

// ============================================================================
// Wire Transfer Request (for high-value international transfers)
// ============================================================================

pub const WireTransferRequest = struct {
    status: u8,                         // 0=idle, 1=pending, 2=sent, 3=confirmed
    _pad0: u8 = 0,
    priority: u8,                       // 0=normal, 1=urgent (SWIFT priority)
    _pad1: u8 = 0,

    sender_name: [35]u8,                // "OmniBus Trading"
    sender_account: [34]u8,             // IBAN
    sender_bank_bic: [11]u8,            // Bank BIC

    receiver_name: [35]u8,              // Receiving party name
    receiver_account: [34]u8,           // IBAN or account number
    receiver_bank_bic: [11]u8,          // Receiving bank BIC

    amount_cents: u64,                  // Transfer amount (cents)
    currency: [3]u8,                    // Currency code

    charge_code: u8,                    // 1=OUR (sender pays all fees)
    _pad2: u8 = 0,

    purpose_code: [4]u8,                // "TRAD"
    instructions: [100]u8,              // Special handling instructions

    reference: [16]u8,                  // Unique reference
    intermediate_bank: [11]u8,          // Intermediate bank BIC (if needed)

    tsc_created: u64,
    tsc_sent: u64,
    tsc_confirmed: u64,

    confirmation_code: u32,

    _reserved: [114]u8 = undefined,
};

// ============================================================================
// Memory Layout within 0x280000–0x2AFFFF (192KB)
// ============================================================================
// 0x280000  BankState (64 bytes)
// 0x280040  SwiftMessage[8] (8 × 456 = 3648 bytes)
// 0x281E40  AchBatchHeader[16] (16 × 440 = 7040 bytes)
// 0x283B40  AchEntryDetail[256] (256 × 256 = 65536 bytes)
// 0x293B40  SettlementRequest[32] (32 × 360 = 11520 bytes)
// 0x296940  WireTransferRequest[16] (16 × 400 = 6400 bytes)
// 0x297E40  ... reserved for future extensions
// 0x2AFFFF  (end of segment)
// ============================================================================

pub const BANKSTATE_OFFSET: usize = 0x0000;
pub const SWIFTMSG_OFFSET: usize = 0x0040;
pub const ACHBATCH_OFFSET: usize = 0x1E40;
pub const ACHENTRY_OFFSET: usize = 0x3B40;
pub const SETTLEMENT_OFFSET: usize = 0x3B40;
pub const WIRE_OFFSET: usize = 0x6940;
