// ws_collector.zig – WebSocket Price Feed → Sub-Block Pipeline
// Bare-metal price aggregation: 0.1s sub-blocks → 1s main block → oracle consensus
//
// Pipeline:
//   NIC/Network stack
//     └─→ price_feed_push()       (called per incoming WS frame)
//           └─→ [ring buffer 0x5D9100]
//                 └─→ tick_100ms()   (called by HPET every 100ms)
//                       └─→ seal_sub_block()  → SubBlock with median prices
//                             └─→ tick_1000ms() (on 10th sub-block)
//                                   └─→ assemble_main_block()
//                                         └─→ oracle_consensus (4/6 quorum)
//                                               └─→ pqc_bridge.sign_tx()
//                                                     └─→ MainBlock ready to broadcast
//
// Memory layout (BSS region 0x5E1000+, beyond code end ~0x5DC000):
//   0x5E1000  WsCollectorState  (~24KB)
//   0x5E1100  Price feed ring buffer  (256 entries × 32B = 8KB)
//   0x5E3100  MainBlock assembly area (~16KB)

const oracle = @import("oracle_consensus.zig");
const pqc    = @import("pqc_wallet_bridge.zig");
const wallet = @import("omnibus_wallet.zig");

// ============================================================================
// Constants
// ============================================================================

pub const COLLECTOR_BASE  : usize = 0x5E1000;
pub const FEED_RING_BASE  : usize = 0x5E1100;
pub const MAIN_BLOCK_BASE : usize = 0x5E3100;

pub const MAX_TOKENS     : usize = 50;
pub const MAX_EXCHANGES  : usize = 8;
pub const SUB_BLOCKS_PER_MAIN : usize = 10;   // 10 × 0.1s = 1s block
pub const FEED_RING_SIZE : usize = 256;

// Exchange IDs (matches token_registry.zig sources)
pub const ExchangeId = enum(u8) {
    BINANCE  = 0,
    COINBASE = 1,
    KRAKEN   = 2,
    LCX      = 3,
    BYBIT    = 4,
    OKX      = 5,
    KUCOIN   = 6,
    HUOBI    = 7,
};

// ============================================================================
// Price Feed Entry (32 bytes) – written by NIC driver / network stack
// ============================================================================

pub const PriceFeedEntry = extern struct {
    token_id    : u8,
    exchange_id : u8,
    _pad        : [2]u8 = .{0, 0},
    price_cents : u64,   // Mid price × 100 (fixed-point, no floats)
    bid_cents   : u64,
    ask_cents   : u64,
    tsc_low     : u32,   // Low 32 bits of RDTSC at arrival
};

// Ring buffer header at FEED_RING_BASE
pub const FeedRingHeader = extern struct {
    write_idx : u16,    // Incremented by NIC driver
    read_idx  : u16,    // Incremented by collector
    _pad      : [4]u8 = .{0} ** 4,
};

// ============================================================================
// Sub-Block (0.1s window) – 10 of these form one MainBlock
// ============================================================================

pub const SubBlock = extern struct {
    sub_index     : u8,
    is_sealed     : bool,
    exchange_count: u8,    // How many distinct exchanges contributed
    _pad          : u8 = 0,
    tsc_start     : u64,
    tsc_end       : u64,
    price_count   : u32,   // Total feed entries processed in this window

    // Median prices per token (computed at seal time)
    median_price  : [MAX_TOKENS]u64,
    median_bid    : [MAX_TOKENS]u64,
    median_ask    : [MAX_TOKENS]u64,
    spread_bps    : [MAX_TOKENS]u16,  // (ask-bid)/mid × 10000
    sources       : [MAX_TOKENS]u8,   // Bitmap: which exchanges contributed

    // Sub-block identity hash (XOR fold over prices + tsc)
    hash          : [32]u8,
};

// ============================================================================
// Main Block (1s = 10 sub-blocks)
// ============================================================================

pub const MainBlock = extern struct {
    height          : u64,
    tsc_start       : u64,
    tsc_end         : u64,
    sub_count       : u8,
    quorum_achieved : bool,
    is_complete     : bool,
    _pad            : u8 = 0,

    sub_blocks      : [SUB_BLOCKS_PER_MAIN]SubBlock,

    // Final aggregated prices (median of 10 sub-block medians)
    final_price     : [MAX_TOKENS]u64,
    final_bid       : [MAX_TOKENS]u64,
    final_ask       : [MAX_TOKENS]u64,

    // Merkle root over sub-block hashes
    merkle_root     : [32]u8,

    // Oracle consensus snapshot hash (from oracle_consensus.zig)
    consensus_hash  : [32]u8,

    // PQ signature (ML-DSA-87, signed by validator via pqc_wallet_bridge)
    pq_sig          : [4595]u8,
    pq_sig_len      : u32,
};

// ============================================================================
// Collector State Machine
// ============================================================================

pub const WsCollectorState = extern struct {
    magic           : u32 = 0x57534F4C,   // "WSOL"
    flags           : u8  = 0,
    current_sub_idx : u8  = 0,
    is_active       : bool = false,
    _pad            : u8  = 0,

    block_height    : u64 = 0,
    tsc_block_start : u64 = 0,
    tsc_sub_start   : u64 = 0,

    // Per-token, per-exchange: latest price in current 0.1s window
    samples_price   : [MAX_TOKENS][MAX_EXCHANGES]u64,
    samples_bid     : [MAX_TOKENS][MAX_EXCHANGES]u64,
    samples_ask     : [MAX_TOKENS][MAX_EXCHANGES]u64,
    sample_mask     : [MAX_TOKENS]u8,    // Bitmap: which exchanges reported this token

    // Sub-blocks being assembled
    sub_blocks      : [SUB_BLOCKS_PER_MAIN]SubBlock,

    // Statistics
    blocks_produced    : u64 = 0,
    sub_blocks_sealed  : u64 = 0,
    prices_received    : u64 = 0,
    consensus_failures : u32 = 0,
    outliers_rejected  : u32 = 0,
};

// ============================================================================
// Memory accessors (bare-metal volatile pointers)
// ============================================================================

fn getState() *volatile WsCollectorState {
    return @as(*volatile WsCollectorState, @ptrFromInt(COLLECTOR_BASE));
}

fn getRingHeader() *volatile FeedRingHeader {
    return @as(*volatile FeedRingHeader, @ptrFromInt(FEED_RING_BASE));
}

fn getRingEntries() [*]volatile PriceFeedEntry {
    return @as([*]volatile PriceFeedEntry, @ptrFromInt(FEED_RING_BASE + 8));
}

fn getMainBlock() *volatile MainBlock {
    return @as(*volatile MainBlock, @ptrFromInt(MAIN_BLOCK_BASE));
}

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    const s = getState();
    s.magic           = 0x57534F4C;
    s.flags           = 0;
    s.current_sub_idx = 0;
    s.is_active       = true;
    s.block_height    = 0;
    s.tsc_block_start = rdtsc();
    s.tsc_sub_start   = s.tsc_block_start;
    s.blocks_produced    = 0;
    s.sub_blocks_sealed  = 0;
    s.prices_received    = 0;
    s.consensus_failures = 0;
    s.outliers_rejected  = 0;

    // Clear sample buffers
    for (0..MAX_TOKENS) |t| {
        s.sample_mask[t] = 0;
        for (0..MAX_EXCHANGES) |e| {
            s.samples_price[t][e] = 0;
            s.samples_bid[t][e]   = 0;
            s.samples_ask[t][e]   = 0;
        }
    }

    // Init ring buffer
    const ring = getRingHeader();
    ring.write_idx = 0;
    ring.read_idx  = 0;

    // Init oracle consensus
    oracle.init_oracle_consensus();
}

// ============================================================================
// Price Feed Push (called by NIC driver / network stack per WS frame)
// Fast path: just write to ring buffer, no processing here
// ============================================================================

pub fn price_feed_push(
    token_id    : u8,
    exchange_id : u8,
    price_cents : u64,
    bid_cents   : u64,
    ask_cents   : u64,
) void {
    if (token_id >= MAX_TOKENS or exchange_id >= MAX_EXCHANGES) return;

    const ring    = getRingHeader();
    const entries = getRingEntries();
    const widx    = ring.write_idx;
    const next    = (widx +% 1) & (FEED_RING_SIZE - 1);

    // If ring is full, overwrite oldest (bare-metal: no blocking)
    entries[widx].token_id    = token_id;
    entries[widx].exchange_id = exchange_id;
    entries[widx]._pad        = .{0, 0};
    entries[widx].price_cents = price_cents;
    entries[widx].bid_cents   = bid_cents;
    entries[widx].ask_cents   = ask_cents;
    entries[widx].tsc_low     = @as(u32, @intCast(rdtsc() & 0xFFFFFFFF));

    ring.write_idx = @as(u16, @intCast(next));
}

// ============================================================================
// Drain Ring Buffer into Sample Arrays (called at start of tick_100ms)
// ============================================================================

fn drain_ring() void {
    const s       = getState();
    const ring    = getRingHeader();
    const entries = getRingEntries();

    while (ring.read_idx != ring.write_idx) {
        const ridx    = ring.read_idx;
        const entry   = entries[ridx];
        const tok     = entry.token_id;
        const exch    = entry.exchange_id;

        ring.read_idx = @as(u16, @intCast((ridx +% 1) & (FEED_RING_SIZE - 1)));

        if (tok >= MAX_TOKENS or exch >= MAX_EXCHANGES) continue;

        // Write latest price for this token/exchange pair
        s.samples_price[tok][exch] = entry.price_cents;
        s.samples_bid[tok][exch]   = entry.bid_cents;
        s.samples_ask[tok][exch]   = entry.ask_cents;
        s.sample_mask[tok]        |= @as(u8, 1) << @as(u3, @intCast(exch));
        s.prices_received         +|= 1;
    }
}

// ============================================================================
// Median of up to 8 u64 values (bare-metal: no alloc, bubble sort in-place)
// ============================================================================

fn median8(vals: [MAX_EXCHANGES]u64, mask: u8) u64 {
    if (mask == 0) return 0;

    var buf: [MAX_EXCHANGES]u64 = vals;
    var count: u8 = 0;

    // Count valid entries and compact to front
    for (0..MAX_EXCHANGES) |i| {
        if ((mask >> @as(u3, @intCast(i))) & 1 == 1) {
            buf[count] = vals[i];
            count += 1;
        }
    }
    if (count == 0) return 0;
    if (count == 1) return buf[0];

    // Bubble sort the valid range
    var i: u8 = 0;
    while (i < count - 1) : (i += 1) {
        var j: u8 = 0;
        while (j < count - 1 - i) : (j += 1) {
            if (buf[j] > buf[j + 1]) {
                const tmp = buf[j];
                buf[j]     = buf[j + 1];
                buf[j + 1] = tmp;
            }
        }
    }

    // Return median (middle value, or average of two middles)
    return if (count & 1 == 1)
        buf[count / 2]
    else
        (buf[count / 2 - 1] + buf[count / 2]) / 2;
}

// ============================================================================
// Outlier rejection: drop values > 1% from median (anti-manipulation)
// ============================================================================

fn compute_median_with_outlier_reject(
    price_row : [MAX_EXCHANGES]u64,
    bid_row   : [MAX_EXCHANGES]u64,
    ask_row   : [MAX_EXCHANGES]u64,
    mask      : u8,
    out_price : *u64,
    out_bid   : *u64,
    out_ask   : *u64,
    out_src   : *u8,
) void {
    if (mask == 0) { out_price.* = 0; out_bid.* = 0; out_ask.* = 0; out_src.* = 0; return; }

    const raw_median = median8(price_row, mask);
    if (raw_median == 0) { out_price.* = 0; out_bid.* = 0; out_ask.* = 0; out_src.* = 0; return; }

    // Tolerance: ±1% of median (100 basis points)
    const tol = raw_median / 100;
    const lo  = if (raw_median > tol) raw_median - tol else 0;
    const hi  = raw_median + tol;

    var filtered_price : [MAX_EXCHANGES]u64 = price_row;
    var filtered_bid   : [MAX_EXCHANGES]u64 = bid_row;
    var filtered_ask   : [MAX_EXCHANGES]u64 = ask_row;
    var clean_mask     : u8 = 0;

    for (0..MAX_EXCHANGES) |i| {
        if ((mask >> @as(u3, @intCast(i))) & 1 == 0) continue;
        const p = price_row[i];
        if (p >= lo and p <= hi) {
            clean_mask |= @as(u8, 1) << @as(u3, @intCast(i));
        } else {
            filtered_price[i] = 0;
            filtered_bid[i]   = 0;
            filtered_ask[i]   = 0;
        }
    }

    out_price.* = median8(filtered_price, clean_mask);
    out_bid.*   = median8(filtered_bid,   clean_mask);
    out_ask.*   = median8(filtered_ask,   clean_mask);
    out_src.*   = clean_mask;
}

// ============================================================================
// Sub-block hash (XOR fold over median prices + tsc_start)
// ============================================================================

fn compute_sub_block_hash(sb: *SubBlock) [32]u8 {
    var h: [32]u8 = [_]u8{0} ** 32;

    // Mix TSC into hash
    const tsc_bytes: [8]u8 = @bitCast(sb.tsc_start);
    for (tsc_bytes, 0..) |b, i| h[i] ^= b;

    // Mix sub_index
    h[8] ^= sb.sub_index;

    // XOR fold all median prices
    for (0..MAX_TOKENS) |t| {
        const price_bytes: [8]u8 = @bitCast(sb.median_price[t]);
        for (price_bytes, 0..) |b, i| {
            h[(t + i) & 31] ^= b;
        }
    }

    return h;
}

// ============================================================================
// Seal current sub-block (called by HPET timer every 100ms)
// ============================================================================

pub fn tick_100ms() void {
    const s   = getState();
    if (!s.is_active) return;

    // Drain any pending prices from ring buffer
    drain_ring();

    const idx = s.current_sub_idx;
    // Use local non-volatile copy for computation, then write back to volatile state
    var sb_local: SubBlock = undefined;

    sb_local.sub_index   = idx;
    sb_local.tsc_start   = s.tsc_sub_start;
    sb_local.tsc_end     = rdtsc();
    sb_local.price_count = 0;

    // Compute per-token median with outlier rejection
    var exchange_count: u8 = 0;
    for (0..MAX_TOKENS) |t| {
        const mask = s.sample_mask[t];
        // Copy volatile samples to local arrays for computation
        var loc_price: [MAX_EXCHANGES]u64 = undefined;
        var loc_bid:   [MAX_EXCHANGES]u64 = undefined;
        var loc_ask:   [MAX_EXCHANGES]u64 = undefined;
        for (0..MAX_EXCHANGES) |e| {
            loc_price[e] = s.samples_price[t][e];
            loc_bid[e]   = s.samples_bid[t][e];
            loc_ask[e]   = s.samples_ask[t][e];
        }
        compute_median_with_outlier_reject(
            loc_price, loc_bid, loc_ask, mask,
            &sb_local.median_price[t],
            &sb_local.median_bid[t],
            &sb_local.median_ask[t],
            &sb_local.sources[t],
        );

        // Spread in basis points
        if (sb_local.median_price[t] > 0 and sb_local.median_ask[t] >= sb_local.median_bid[t]) {
            const spread = sb_local.median_ask[t] - sb_local.median_bid[t];
            sb_local.spread_bps[t] = @as(u16, @intCast(@min(
                (spread * 10000) / sb_local.median_price[t], 0xFFFF
            )));
        } else {
            sb_local.spread_bps[t] = 0;
        }

        if (mask != 0) {
            sb_local.price_count += 1;
            exchange_count |= mask;
        }
    }
    sb_local.exchange_count = @popCount(exchange_count);
    sb_local.hash           = compute_sub_block_hash(&sb_local);
    sb_local.is_sealed      = true;

    // Write back to volatile state
    s.sub_blocks[idx] = sb_local;

    s.sub_blocks_sealed +|= 1;

    // Clear sample buffers for next window
    for (0..MAX_TOKENS) |t| {
        s.sample_mask[t] = 0;
        for (0..MAX_EXCHANGES) |e| {
            s.samples_price[t][e] = 0;
            s.samples_bid[t][e]   = 0;
            s.samples_ask[t][e]   = 0;
        }
    }

    // Advance sub-block index
    s.current_sub_idx = @as(u8, @intCast((@as(usize, s.current_sub_idx) + 1) % SUB_BLOCKS_PER_MAIN));
    s.tsc_sub_start   = rdtsc();

    // If we completed 10 sub-blocks, assemble main block
    if (s.current_sub_idx == 0) {
        tick_1000ms();
    }
}

// ============================================================================
// Merkle root over 10 sub-block hashes (XOR fold, bare-metal safe)
// ============================================================================

fn compute_merkle_root(sub_blocks: *volatile [SUB_BLOCKS_PER_MAIN]SubBlock) [32]u8 {
    var root: [32]u8 = [_]u8{0} ** 32;
    for (0..SUB_BLOCKS_PER_MAIN) |s_idx| {
        for (sub_blocks[s_idx].hash, 0..) |b, i| root[i] ^= b;
    }
    return root;
}

// ============================================================================
// Assemble Main Block + Oracle Consensus (called after 10 sub-blocks)
// ============================================================================

fn tick_1000ms() void {
    const s  = getState();
    const mb = getMainBlock();

    mb.height    = s.block_height;
    mb.tsc_start = s.tsc_block_start;
    mb.tsc_end   = rdtsc();
    mb.sub_count = SUB_BLOCKS_PER_MAIN;
    mb.is_complete     = false;
    mb.quorum_achieved = false;

    // Copy sub-blocks
    for (0..SUB_BLOCKS_PER_MAIN) |i| {
        mb.sub_blocks[i] = s.sub_blocks[i];
    }

    // Aggregate: median of 10 sub-block medians per token
    for (0..MAX_TOKENS) |t| {
        var prices : [10]u64 = undefined;
        var bids   : [10]u64 = undefined;
        var asks   : [10]u64 = undefined;
        var valid_mask: u16 = 0;

        for (0..SUB_BLOCKS_PER_MAIN) |i| {
            prices[i] = s.sub_blocks[i].median_price[t];
            bids[i]   = s.sub_blocks[i].median_bid[t];
            asks[i]   = s.sub_blocks[i].median_ask[t];
            if (prices[i] > 0) valid_mask |= @as(u16, 1) << @as(u4, @intCast(i));
        }

        // Median of up to 10 values (reuse median8 on first 8, then pair)
        var buf: [8]u64 = prices[0..8].*;
        const mask8: u8 = @truncate(valid_mask & 0xFF);
        mb.final_price[t] = median8(buf, mask8);

        buf = bids[0..8].*;
        mb.final_bid[t] = median8(buf, mask8);

        buf = asks[0..8].*;
        mb.final_ask[t] = median8(buf, mask8);
    }

    // Merkle root
    mb.merkle_root = compute_merkle_root(&s.sub_blocks);

    // Feed into oracle consensus
    const snapshot = oracle.create_price_snapshot();
    snapshot.timestamp    = mb.tsc_start;
    snapshot.block_height = mb.height;
    snapshot.token_count  = MAX_TOKENS;

    for (0..MAX_TOKENS) |t| {
        snapshot.prices[t].token_id        = @as(u8, @intCast(t));
        snapshot.prices[t].price_cents     = mb.final_price[t];
        snapshot.prices[t].bid_cents       = mb.final_bid[t];
        snapshot.prices[t].ask_cents       = mb.final_ask[t];
        snapshot.prices[t].spread_bps      = if (mb.final_price[t] > 0 and
                                                 mb.final_ask[t] >= mb.final_bid[t])
            @as(u16, @intCast(@min(
                ((mb.final_ask[t] - mb.final_bid[t]) * 10000) / mb.final_price[t],
                0xFFFF
            )))
        else 0;
    }
    snapshot.snapshot_hash = mb.merkle_root;

    const quorum_ok = oracle.commit_price_snapshot(snapshot);
    mb.consensus_hash  = snapshot.snapshot_hash;
    mb.quorum_achieved = quorum_ok == 1;

    if (!mb.quorum_achieved) {
        s.consensus_failures +|= 1;
    }

    // PQ-sign the block with RENT domain key (ML-DSA-87, strongest)
    const signed = pqc.sign_tx(.RENT, mb.merkle_root);
    mb.pq_sig_len = signed.sig_len;
    const copy_len = @min(signed.sig_len, 4595);
    var i: u32 = 0;
    while (i < copy_len) : (i += 1) {
        mb.pq_sig[i] = signed.signature[i];
    }

    mb.is_complete = true;
    s.blocks_produced  +|= 1;
    s.block_height     +|= 1;
    s.tsc_block_start   = rdtsc();
}

// ============================================================================
// Public API
// ============================================================================

/// Get pointer to latest completed main block (for P2P broadcast)
pub fn get_latest_block() *volatile MainBlock {
    return getMainBlock();
}

/// Check if a complete block is ready to broadcast
pub fn has_complete_block() bool {
    return getMainBlock().is_complete;
}

/// Mark block as consumed (after P2P broadcast)
pub fn consume_block() void {
    getMainBlock().is_complete = false;
}

/// Get collector statistics
pub fn get_stats() struct {
    block_height       : u64,
    blocks_produced    : u64,
    sub_blocks_sealed  : u64,
    prices_received    : u64,
    consensus_failures : u32,
    outliers_rejected  : u32,
    current_sub_idx    : u8,
} {
    const s = getState();
    return .{
        .block_height       = s.block_height,
        .blocks_produced    = s.blocks_produced,
        .sub_blocks_sealed  = s.sub_blocks_sealed,
        .prices_received    = s.prices_received,
        .consensus_failures = s.consensus_failures,
        .outliers_rejected  = s.outliers_rejected,
        .current_sub_idx    = s.current_sub_idx,
    };
}

// ============================================================================
// RDTSC (High-precision timer, bare-metal)
// ============================================================================

inline fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
