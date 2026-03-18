// token_registry.zig — Phase 63: Asset Registry & Oracle Mapping
// Maps 50 tokens across Kraken, Coinbase, LCX to fixed memory slots in State Trie
// Memory layout: Each token gets a fixed 64-byte slot at 0x250000 + (ID * 64)

const std = @import("std");

// ============================================================================
// TOKEN REGISTRY (50 Major Assets)
// ============================================================================

pub const TokenId = enum(u8) {
    OMNI = 0x01,      // Native token
    BTC = 0x02,
    ETH = 0x03,
    USDT = 0x04,
    USDC = 0x05,
    DOT = 0x06,
    LINK = 0x07,
    ADA = 0x08,
    MATIC = 0x09,
    SOL = 0x0A,
    AVAX = 0x0B,
    ARB = 0x0C,
    OP = 0x0D,
    FTM = 0x0E,
    NEAR = 0x0F,
    ATOM = 0x10,
    XRP = 0x11,
    LTC = 0x12,
    BCH = 0x13,
    ETC = 0x14,
    DOGE = 0x15,
    APE = 0x16,
    GALA = 0x17,
    SAND = 0x18,
    MANA = 0x19,
    ENJ = 0x1A,
    ALGO = 0x1B,
    KSM = 0x1C,
    FLOW = 0x1D,
    HBAR = 0x1E,
    XTZ = 0x1F,
    ZEC = 0x20,
    DASH = 0x21,
    XMR = 0x22,
    AAVE = 0x23,
    SNX = 0x24,
    SUSHI = 0x25,
    UNI = 0x26,
    CRV = 0x27,
    YEARN = 0x28,
    CONVEX = 0x29,
    CURVE = 0x2A,
    SHIB = 0x2B,
    PEPE = 0x2C,
    FLOKI = 0x2D,
    WIF = 0x2E,
    BONK = 0x2F,
    RENDER = 0x30,
    IMMUTABLE = 0x31,
    _RESERVED = 0xFF,
};

/// Token mapping structure (per-asset configuration)
pub const TokenMap = struct {
    id: TokenId,
    symbol: [8]u8,           // Standard symbol (OMNI, BTC, etc.)
    kraken_pair: [16]u8,     // Kraken symbol (e.g., XBT for BTC)
    coinbase_pair: [16]u8,   // Coinbase symbol
    lcx_pair: [16]u8,        // LCX symbol
    decimals: u8,            // Price decimals (usually 2 for USD)
    state_trie_slot: u64,    // Fixed address in State Trie (0x250000 + offset)
    flags: u32,              // 0x01=Stablecoin, 0x02=Layer2, 0x04=Derivs
};

/// Genesis Token Registry (50 assets mapped to State Trie slots)
pub const GENESIS_REGISTRY: [50]TokenMap = .{
    // Slot 0: OMNI (native)
    .{
        .id = TokenId.OMNI,
        .symbol = "OMNI\x00\x00\x00\x00".*,
        .kraken_pair = "OMNI/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "OMNI-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "OMNI/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250040,  // 0x250000 + 64
        .flags = 0x00,
    },
    // Slot 1: BTC (Kraken uses XBT, others use BTC)
    .{
        .id = TokenId.BTC,
        .symbol = "BTC\x00\x00\x00\x00\x00".*,
        .kraken_pair = "XBT/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "BTC-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "BTC/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250080,  // 0x250000 + 128
        .flags = 0x00,
    },
    // Slot 2: ETH
    .{
        .id = TokenId.ETH,
        .symbol = "ETH\x00\x00\x00\x00\x00".*,
        .kraken_pair = "ETH/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "ETH-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "ETH/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x2500C0,  // 0x250000 + 192
        .flags = 0x00,
    },
    // Slot 3: USDT (stablecoin)
    .{
        .id = TokenId.USDT,
        .symbol = "USDT\x00\x00\x00\x00".*,
        .kraken_pair = "USDT/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "USDT-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "USDT/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250100,  // 0x250000 + 256
        .flags = 0x01,  // Stablecoin
    },
    // Slot 4: USDC (stablecoin)
    .{
        .id = TokenId.USDC,
        .symbol = "USDC\x00\x00\x00\x00".*,
        .kraken_pair = "USDC/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "USDC-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "USDC/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250140,
        .flags = 0x01,  // Stablecoin
    },
    // Slots 5-49: Additional assets (abbreviated for brevity)
    .{
        .id = TokenId.DOT,
        .symbol = "DOT\x00\x00\x00\x00\x00".*,
        .kraken_pair = "DOT/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "DOT-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "DOT/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250180,
        .flags = 0x00,
    },
    .{
        .id = TokenId.LINK,
        .symbol = "LINK\x00\x00\x00\x00".*,
        .kraken_pair = "LINK/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "LINK-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "LINK/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x2501C0,
        .flags = 0x00,
    },
    // ... remaining 42 tokens follow same pattern
    // For brevity, filling with placeholder structure
    .{
        .id = TokenId.ADA,
        .symbol = "ADA\x00\x00\x00\x00\x00".*,
        .kraken_pair = "ADA/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .coinbase_pair = "ADA-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .lcx_pair = "ADA/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .decimals = 2,
        .state_trie_slot = 0x250200,
        .flags = 0x00,
    },
    .{ .id = TokenId.MATIC, .symbol = "MATIC\x00\x00\x00".*,
       .kraken_pair = "MATIC/USD\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "MATIC-USD\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "MATIC/EUR\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250240, .flags = 0x02 },
    .{ .id = TokenId.SOL, .symbol = "SOL\x00\x00\x00\x00\x00".*,
       .kraken_pair = "SOL/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "SOL-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "SOL/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250280, .flags = 0x00 },
    .{ .id = TokenId.AVAX, .symbol = "AVAX\x00\x00\x00\x00".*,
       .kraken_pair = "AVAX/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "AVAX-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "AVAX/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2502C0, .flags = 0x02 },
    .{ .id = TokenId.ARB, .symbol = "ARB\x00\x00\x00\x00\x00".*,
       .kraken_pair = "ARB/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ARB-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ARB/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250300, .flags = 0x02 },
    .{ .id = TokenId.OP, .symbol = "OP\x00\x00\x00\x00\x00\x00".*,
       .kraken_pair = "OP/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "OP-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "OP/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250340, .flags = 0x02 },
    .{ .id = TokenId.FTM, .symbol = "FTM\x00\x00\x00\x00\x00".*,
       .kraken_pair = "FTM/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "FTM-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "FTM/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250380, .flags = 0x02 },
    .{ .id = TokenId.NEAR, .symbol = "NEAR\x00\x00\x00\x00".*,
       .kraken_pair = "NEAR/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "NEAR-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "NEAR/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2503C0, .flags = 0x00 },
    .{ .id = TokenId.ATOM, .symbol = "ATOM\x00\x00\x00\x00".*,
       .kraken_pair = "ATOM/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ATOM-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ATOM/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250400, .flags = 0x00 },
    .{ .id = TokenId.XRP, .symbol = "XRP\x00\x00\x00\x00\x00".*,
       .kraken_pair = "XRP/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "XRP-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "XRP/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250440, .flags = 0x00 },
    .{ .id = TokenId.LTC, .symbol = "LTC\x00\x00\x00\x00\x00".*,
       .kraken_pair = "LTC/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "LTC-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "LTC/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250480, .flags = 0x00 },
    .{ .id = TokenId.BCH, .symbol = "BCH\x00\x00\x00\x00\x00".*,
       .kraken_pair = "BCH/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "BCH-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "BCH/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2504C0, .flags = 0x00 },
    .{ .id = TokenId.ETC, .symbol = "ETC\x00\x00\x00\x00\x00".*,
       .kraken_pair = "ETC/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ETC-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ETC/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250500, .flags = 0x00 },
    // Continue with remaining 30 tokens (abbreviated for space)
    .{ .id = TokenId.DOGE, .symbol = "DOGE\x00\x00\x00\x00".*,
       .kraken_pair = "DOGE/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "DOGE-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "DOGE/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250540, .flags = 0x00 },
    .{ .id = TokenId.APE, .symbol = "APE\x00\x00\x00\x00\x00".*,
       .kraken_pair = "APE/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "APE-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "APE/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250580, .flags = 0x00 },
    .{ .id = TokenId.GALA, .symbol = "GALA\x00\x00\x00\x00".*,
       .kraken_pair = "GALA/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "GALA-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "GALA/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2505C0, .flags = 0x00 },
    .{ .id = TokenId.SAND, .symbol = "SAND\x00\x00\x00\x00".*,
       .kraken_pair = "SAND/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "SAND-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "SAND/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250600, .flags = 0x00 },
    .{ .id = TokenId.MANA, .symbol = "MANA\x00\x00\x00\x00".*,
       .kraken_pair = "MANA/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "MANA-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "MANA/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250640, .flags = 0x00 },
    .{ .id = TokenId.ENJ, .symbol = "ENJ\x00\x00\x00\x00\x00".*,
       .kraken_pair = "ENJ/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ENJ-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ENJ/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250680, .flags = 0x00 },
    .{ .id = TokenId.ALGO, .symbol = "ALGO\x00\x00\x00\x00".*,
       .kraken_pair = "ALGO/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ALGO-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ALGO/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2506C0, .flags = 0x00 },
    .{ .id = TokenId.KSM, .symbol = "KSM\x00\x00\x00\x00\x00".*,
       .kraken_pair = "KSM/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "KSM-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "KSM/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250700, .flags = 0x00 },
    .{ .id = TokenId.FLOW, .symbol = "FLOW\x00\x00\x00\x00".*,
       .kraken_pair = "FLOW/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "FLOW-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "FLOW/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250740, .flags = 0x00 },
    .{ .id = TokenId.HBAR, .symbol = "HBAR\x00\x00\x00\x00".*,
       .kraken_pair = "HBAR/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "HBAR-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "HBAR/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250780, .flags = 0x00 },
    .{ .id = TokenId.XTZ, .symbol = "XTZ\x00\x00\x00\x00\x00".*,
       .kraken_pair = "XTZ/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "XTZ-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "XTZ/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2507C0, .flags = 0x00 },
    .{ .id = TokenId.ZEC, .symbol = "ZEC\x00\x00\x00\x00\x00".*,
       .kraken_pair = "ZEC/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "ZEC-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "ZEC/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250800, .flags = 0x00 },
    .{ .id = TokenId.DASH, .symbol = "DASH\x00\x00\x00\x00".*,
       .kraken_pair = "DASH/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "DASH-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "DASH/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250840, .flags = 0x00 },
    .{ .id = TokenId.XMR, .symbol = "XMR\x00\x00\x00\x00\x00".*,
       .kraken_pair = "XMR/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "XMR-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "XMR/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250880, .flags = 0x00 },
    .{ .id = TokenId.AAVE, .symbol = "AAVE\x00\x00\x00\x00".*,
       .kraken_pair = "AAVE/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "AAVE-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "AAVE/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2508C0, .flags = 0x00 },
    .{ .id = TokenId.SNX, .symbol = "SNX\x00\x00\x00\x00\x00".*,
       .kraken_pair = "SNX/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "SNX-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "SNX/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250900, .flags = 0x00 },
    .{ .id = TokenId.SUSHI, .symbol = "SUSHI\x00\x00\x00".*,
       .kraken_pair = "SUSHI/USD\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "SUSHI-USD\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "SUSHI/EUR\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250940, .flags = 0x00 },
    .{ .id = TokenId.UNI, .symbol = "UNI\x00\x00\x00\x00\x00".*,
       .kraken_pair = "UNI/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "UNI-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "UNI/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250980, .flags = 0x00 },
    .{ .id = TokenId.CRV, .symbol = "CRV\x00\x00\x00\x00\x00".*,
       .kraken_pair = "CRV/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "CRV-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "CRV/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x2509C0, .flags = 0x00 },
    .{ .id = TokenId.YEARN, .symbol = "YFI\x00\x00\x00\x00\x00".*,
       .kraken_pair = "YFI/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "YFI-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "YFI/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250A00, .flags = 0x00 },
    .{ .id = TokenId.CONVEX, .symbol = "CVX\x00\x00\x00\x00\x00".*,
       .kraken_pair = "CVX/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "CVX-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "CVX/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250A40, .flags = 0x00 },
    .{ .id = TokenId.CURVE, .symbol = "CRV\x00\x00\x00\x00\x00".*,
       .kraken_pair = "CRV/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "CRV-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "CRV/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250A80, .flags = 0x00 },
    .{ .id = TokenId.SHIB, .symbol = "SHIB\x00\x00\x00\x00".*,
       .kraken_pair = "SHIB/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "SHIB-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "SHIB/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250AC0, .flags = 0x00 },
    .{ .id = TokenId.PEPE, .symbol = "PEPE\x00\x00\x00\x00".*,
       .kraken_pair = "PEPE/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "PEPE-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "PEPE/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250B00, .flags = 0x00 },
    .{ .id = TokenId.FLOKI, .symbol = "FLOKI\x00\x00\x00".*,
       .kraken_pair = "FLOKI/USD\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "FLOKI-USD\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "FLOKI/EUR\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250B40, .flags = 0x00 },
    .{ .id = TokenId.WIF, .symbol = "WIF\x00\x00\x00\x00\x00".*,
       .kraken_pair = "WIF/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "WIF-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "WIF/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250B80, .flags = 0x00 },
    .{ .id = TokenId.BONK, .symbol = "BONK\x00\x00\x00\x00".*,
       .kraken_pair = "BONK/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "BONK-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "BONK/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250BC0, .flags = 0x00 },
    .{ .id = TokenId.RENDER, .symbol = "RNDR\x00\x00\x00\x00".*,
       .kraken_pair = "RNDR/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "RNDR-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "RNDR/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250C00, .flags = 0x00 },
    .{ .id = TokenId.IMMUTABLE, .symbol = "IMX\x00\x00\x00\x00\x00".*,
       .kraken_pair = "IMX/USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "IMX-USD\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "IMX/EUR\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250C40, .flags = 0x00 },
    // 50th token: Reserved for future use
    .{ .id = TokenId._RESERVED, .symbol = "XXXX\x00\x00\x00\x00".*,
       .kraken_pair = "XXXX/USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .coinbase_pair = "XXXX-USD\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .lcx_pair = "XXXX/EUR\x00\x00\x00\x00\x00\x00\x00\x00".*,
       .decimals = 2, .state_trie_slot = 0x250C80, .flags = 0x00 },
};

/// Lookup function: find token by symbol
pub fn lookupBySymbol(symbol: []const u8) ?TokenMap {
    for (GENESIS_REGISTRY) |token| {
        if (std.mem.eql(u8, symbol, std.mem.sliceTo(&token.symbol, 0))) {
            return token;
        }
    }
    return null;
}

/// Lookup function: find token by Kraken pair
pub fn lookupByKrakenPair(kraken_pair: []const u8) ?TokenMap {
    for (GENESIS_REGISTRY) |token| {
        if (std.mem.eql(u8, kraken_pair, std.mem.sliceTo(&token.kraken_pair, 0))) {
            return token;
        }
    }
    return null;
}

/// Lookup function: find token by Coinbase pair
pub fn lookupByCoinbasePair(cb_pair: []const u8) ?TokenMap {
    for (GENESIS_REGISTRY) |token| {
        if (std.mem.eql(u8, cb_pair, std.mem.sliceTo(&token.coinbase_pair, 0))) {
            return token;
        }
    }
    return null;
}

/// Lookup function: find token by LCX pair
pub fn lookupByLCXPair(lcx_pair: []const u8) ?TokenMap {
    for (GENESIS_REGISTRY) |token| {
        if (std.mem.eql(u8, lcx_pair, std.mem.sliceTo(&token.lcx_pair, 0))) {
            return token;
        }
    }
    return null;
}
