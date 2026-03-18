// types.zig — Stealth OS type definitions for MEV protection
// Phase 13: MEV protection - prevents sandwich attacks via obfuscation + confidential routing
// Memory: 0x2C0000–0x2DFFFF (128KB)

// ============================================================================
// Memory Layout
// ============================================================================

pub const STEALTH_BASE: usize = 0x2C0000;
pub const GRID_OS_BASE: usize = 0x110000;
pub const EXECUTION_BASE: usize = 0x130000;
pub const KERNEL_AUTH: usize = 0x100050;

// Offsets within stealth memory
pub const STEALTH_STATE_OFFSET: usize = 0;
pub const OBFUSCATION_KEY_OFFSET: usize = 64;
pub const ORDER_BUNDLE_OFFSET: usize = 128;
pub const TIMING_LOCK_OFFSET: usize = 512;

// Capacity limits
pub const MAX_ORDERS_IN_BUNDLE: u32 = 32;
pub const MAX_CONCURRENT_ROUTES: u32 = 16;
pub const OBFUSCATION_ROUNDS: u32 = 8;

// ============================================================================
// StealthState — Module Header (64 bytes)
// ============================================================================

pub const StealthState = struct {
    magic: u32,                         // 0x5354524C = "STRL"
    flags: u32,                         // Active flag + settings
    cycle_count: u64,                   // Cycles processed
    orders_obfuscated: u32,             // Total orders hidden
    sandwich_prevented: u32,            // Sandwich attacks blocked
    mempool_scans: u64,                 // Mempool monitoring count
    tsc_last_update: u64,               // Last TSC timestamp
    _reserved: [20]u8 = undefined,      // Padding to 64 bytes
};

// ============================================================================
// ObfuscationKey — Cryptographic key for order hiding (64 bytes)
// ============================================================================

pub const ObfuscationKey = struct {
    key_id: u32,                        // Key identifier
    _pad0: u32 = 0,
    key_material: [32]u8,               // AES-256 key (or ChaCha20)
    nonce: [16]u8,                      // IV/nonce for encryption
    _pad1: [12]u8 = [_]u8{0} ** 12,    // Padding to 64 bytes
};

// ============================================================================
// OrderBundle — Group of orders for confidential execution (512 bytes)
// ============================================================================

pub const OrderBundle = struct {
    bundle_id: u64,                     // Unique bundle identifier
    status: u8,                         // 0=idle, 1=preparing, 2=encrypted, 3=submitted, 4=executed
    encryption_enabled: u8,             // 0=plaintext, 1=encrypted
    batch_route_mode: u8,               // 0=direct, 1=private pool, 2=colocated builder, 3=MEV-Burn
    _pad0: u8 = 0,

    order_count: u32,                   // Number of orders in bundle
    total_value_usd: u64,               // Total value in cents

    // Encryption metadata
    key_id: u32,                        // Which ObfuscationKey was used
    _pad1: u32 = 0,
    iv_nonce: [16]u8,                   // IV for this bundle

    // Timing control
    reveal_block: u64,                  // Block height to reveal plaintext
    execution_deadline_ms: u64,         // Deadline for execution (milliseconds)

    // Obfuscation technique
    obfuscation_method: u8,             // 0=order splitting, 1=timing delay, 2=dummy orders, 3=hybrid
    _pad2: [7]u8 = [_]u8{0} ** 7,

    // Encrypted order data (placeholder for actual encrypted orders)
    encrypted_orders: [256]u8,          // Encrypted order packet

    // Execution tracking
    tsc_created: u64,
    tsc_encrypted: u64,
    tsc_submitted: u64,
    tsc_executed: u64,

    // Gas optimization
    batch_gas_estimate: u64,            // Estimated gas for bundle
    _reserved: [52]u8 = undefined,      // Padding to 512 bytes
};

// ============================================================================
// RoutingPath — Private order routing destination (96 bytes)
// ============================================================================

pub const RoutingPath = struct {
    route_id: u32,                      // Route identifier
    route_type: u8,                     // 0=direct RPC, 1=Flashbots Relay, 2=MEV-Burn, 3=private pool
    _pad0: [3]u8 = [_]u8{0} ** 3,

    endpoint_url: [64]u8,               // HTTPS endpoint (e.g., "https://relay.flashbots.net")
    endpoint_key: [16]u8,               // Auth key or signature

    is_active: u8,                      // 0=inactive, 1=active
    privacy_level: u8,                  // 0=public, 1=semi-private, 2=fully private
    latency_ms: u16,                    // Estimated latency to endpoint

    success_rate_pct: u8,               // Success rate [0-100]
    fee_bps: u16,                       // Fee in basis points
    _pad1: u8 = 0,

    _reserved: [24]u8 = undefined,      // Padding to 96 bytes
};

// ============================================================================
// TimingLock — Prevent block-stuffing and transaction ordering attacks (64 bytes)
// ============================================================================

pub const TimingLock = struct {
    lock_id: u32,                       // Lock identifier
    _pad0: u32 = 0,

    locked_until_block: u64,            // Block height when lock expires
    locked_until_tsc: u64,              // TSC when lock expires

    blocking_order: [32]u8,             // Hash of blocking order (if any)

    lock_type: u8,                      // 0=block-delay, 1=entropy-based, 2=threshold encryption
    _pad1: [7]u8 = [_]u8{0} ** 7,

    // For threshold encryption mode
    threshold_shares_required: u8,      // M of N shares required
    threshold_shares_total: u8,         // Total N shares
    _pad2: [6]u8 = [_]u8{0} ** 6,

    _reserved: [12]u8 = undefined,      // Padding to 64 bytes
};

// ============================================================================
// SandwichDetector — Monitor for sandwich attack patterns (96 bytes)
// ============================================================================

pub const SandwichDetector = struct {
    detector_id: u32,                   // Detector identifier
    _pad0: u32 = 0,

    // Attack signature detection
    suspicious_transfers_count: u32,    // Count of suspicious transfers
    price_impact_threshold_bps: u32,    // Report if > N basis points

    // Mempool analysis
    pending_txs_count: u32,             // Pending transactions in mempool
    high_gas_price_count: u32,          // Txs with gas > median
    flash_loan_patterns: u32,           // Detected flash loan signatures

    // Historical tracking
    last_sandwich_tsc: u64,             // TSC of last detected sandwich
    sandwich_count_24h: u32,            // Sandwiches blocked in 24h
    false_positive_count: u32,          // False positives (for tuning)

    tsc_created: u64,

    _reserved: [32]u8 = undefined,      // Padding to 96 bytes
};

// ============================================================================
// Memory Layout within 0x2C0000–0x2DFFFF (128KB)
// ============================================================================
// 0x2C0000  StealthState (64 bytes)
// 0x2C0040  ObfuscationKey[8] (8 × 64 = 512 bytes)
// 0x2C0240  OrderBundle[32] (32 × 512 = 16384 bytes)
// 0x2C4240  RoutingPath[16] (16 × 96 = 1536 bytes)
// 0x2C4840  TimingLock[8] (8 × 64 = 512 bytes)
// 0x2C4A40  SandwichDetector (96 bytes)
// 0x2C4AA0  ... reserved for future extensions
// 0x2DFFFF  (end of segment)
// ============================================================================

pub const STEALTHSTATE_OFFSET: usize = 0x0000;
pub const OBFUSCATION_KEY_ARRAY_OFFSET: usize = 0x0040;
pub const ORDER_BUNDLE_ARRAY_OFFSET: usize = 0x0240;
pub const ROUTING_PATH_ARRAY_OFFSET: usize = 0x4240;
pub const TIMING_LOCK_ARRAY_OFFSET: usize = 0x4840;
pub const SANDWICH_DETECTOR_OFFSET: usize = 0x4A40;
