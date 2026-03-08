// types.zig — All bare-metal types for Execution OS
// Fixed-point throughout: prices × 100 (cents), sizes × 1e8 (satoshis)
// Memory layout: 0x130000–0x14FFFF (128KB)

// ============================================================================
// Memory Addresses
// ============================================================================

pub const EXECUTION_BASE: usize = 0x130000;        // Execution OS segment base
pub const GRID_ORDER_ARRAY: usize = 0x110840;      // Grid OS Order array (writeback fills)
pub const GRID_ARB_BASE: usize = 0x113840;         // Grid OS ArbitrageOpportunity array
pub const KERNEL_AUTH: usize = 0x100050;           // Ada auth gate

// ============================================================================
// Internal Offsets
// ============================================================================

pub const STATE_OFFSET: usize = 0x0000;             // ExecutionState
pub const RING_HEADER_OFFSET: usize = 0x0040;      // OrderRingHeader
pub const ORDER_RING_OFFSET: usize = 0x0050;       // OrderPacket[256] input ring
pub const SIGNED_SLOT_OFFSET: usize = 0x8050;      // SignedOrderSlot[64] TX ring
pub const FILL_RESULT_OFFSET: usize = 0xE050;      // FillResult[256]
pub const API_KEY_OFFSET: usize = 0x12050;         // ApiKeySlot[3]

// ============================================================================
// Constants
// ============================================================================

pub const MAX_SIGNED_SLOTS: usize = 64;             // TX queue capacity
pub const MAX_FILL_RESULTS: usize = 256;            // Fill tracking capacity
pub const MAX_ORDER_RING: usize = 256;              // Input ring capacity
pub const MAX_PAYLOAD_SIZE: usize = 376;            // Max signed HTTP body size

// Exchange IDs (matching grid_os/types.zig)
pub const KRAKEN: u8 = 0;
pub const COINBASE: u8 = 1;
pub const LCX: u8 = 2;

// ============================================================================
// OrderPacket — Input from Grid OS (copied from grid_os/types.zig for independence)
// ============================================================================

pub const OrderPacket = extern struct {
    opcode: u8 = 0x70,                // Order opcode (0x70 = multi-route arbitrage)
    _pad0: u8 = 0,
    exchange_id: u16,                 // 0=Kraken, 1=Coinbase, 2=LCX
    _pad1: u32 = 0,
    pair_id: u16,                     // 0=BTC_USD, 1=ETH_USD, 2=XRP_USD
    side: u8,                         // 0=buy, 1=sell
    _pad2: u8 = 0,
    quantity_sats: u64,               // Order size (× 1e8)
    price_cents: u64,                 // Limit price (× 100)
    signature_pqc: [64]u8 = [_]u8{0} ** 64,  // PQC signature (filled by Ada)
    // = 92 bytes (padded to 128)
};

// ============================================================================
// OrderRingHeader — Head/Tail pointers for ring buffer
// ============================================================================

pub const OrderRingHeader = extern struct {
    head: u32 = 0,                    // Advanced by Execution OS (reader)
    tail: u32 = 0,                    // Advanced by Grid OS (writer)
    _pad: [8]u8 = [_]u8{0} ** 8,
    // = 16 bytes
};

// ============================================================================
// SignedOrderSlot — Output to C NIC Driver
// ============================================================================

pub const SignedOrderSlot = extern struct {
    exchange_id: u8,                  // Which exchange to send to
    pair_id: u8,                      // BTC_USD, ETH_USD, XRP_USD
    flags: u8,                        // 0x01=ready, 0x02=sent, 0x04=error
    _pad: u8 = 0,
    payload_len: u16,                 // Length of signed HTTP body
    _pad2: u16 = 0,
    payload: [376]u8 = [_]u8{0} ** 376,  // Signed HTTP body (URL-encoded or JSON)
    // = 384 bytes
};

// ============================================================================
// FillResult — Exchange Response Tracking
// ============================================================================

pub const FillResult = extern struct {
    order_id: u32,                    // Exchange-assigned order ID
    pair_id: u16,                     // Trading pair
    exchange_id: u8,                  // Which exchange filled
    status: u8,                       // 0=pending, 1=filled, 2=partial, 3=rejected
    filled_sats: u64,                 // Cumulative filled amount
    price_cents: u64,                 // Actual fill price (may differ from limit)
    tsc: u64,                         // TSC when filled
    _reserved: [36]u8 = [_]u8{0} ** 36,
    // = 64 bytes
};

// ============================================================================
// ApiKeySlot — Cryptographic Credentials (pre-loaded by Ada)
// ============================================================================

pub const ApiKeySlot = extern struct {
    exchange_id: u8,                  // 0=Kraken, 1=Coinbase, 2=LCX
    key_len: u8,                      // Length of API key
    secret_len: u8,                   // Length of API secret
    _pad: u8 = 0,
    key: [64]u8 = [_]u8{0} ** 64,    // API public key / key_id
    secret: [64]u8 = [_]u8{0} ** 64, // HMAC secret (Kraken/LCX) or placeholder
    ec_key: [32]u8 = [_]u8{0} ** 32, // Raw EC P-256 private key (Coinbase)
    _reserved: [380]u8 = [_]u8{0} ** 380,  // Future use
    // = 512 bytes
};

// ============================================================================
// ExecutionState — Module Header
// ============================================================================

pub const ExecutionState = extern struct {
    magic: u32 = 0x45584543,          // "EXEC" magic marker
    flags: u8,                        // 0x01=active
    _pad: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,                 // Number of cycles executed
    order_in_count: u32,              // Orders processed from Grid OS
    fill_out_count: u32,              // FillResults processed from exchanges
    tsc_last_cycle: u64,              // TSC of last cycle
    _reserved: [36]u8 = [_]u8{0} ** 36,
    // = 64 bytes
};

// ============================================================================
// Pair ID Enumeration
// ============================================================================

pub const PairId = enum(u16) {
    BTC_USD = 0,
    ETH_USD = 1,
    XRP_USD = 2,
    unknown = 0xFFFF,
};

// ============================================================================
// Side Enumeration
// ============================================================================

pub const Side = enum(u8) {
    buy = 0,
    sell = 1,
};
