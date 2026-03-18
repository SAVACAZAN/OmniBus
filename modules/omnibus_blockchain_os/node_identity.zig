// node_identity.zig – OmniBus Node Identity
// Fiecare nod bare-metal are o identitate permanentă derivată din cheia PQ.
//
// Shard ID = primii 16 biți din XOR-hash(pq_pubkey)
// Node ID  = primii 48 biți (Short ID în rețea)
//
// Fișierul identity.omni (stocat pe sectorul 0 al partiției OmniBus):
//   [magic u32][version u16][shard_id u16]
//   [pq_algo u8][pubkey_len u32][pubkey 2592B]
//   [created_tsc u64][flags u8]
//   [checksum u32]  ← CRC32 al tuturor câmpurilor de mai sus
//
// Memorie: 0x602000 (4KB, în afara segmentului blockchain_os)

const pqc    = @import("pqc_wallet_bridge.zig");
const wallet = @import("omnibus_wallet.zig");
const grid   = @import("vid_shard_grid.zig");

// ============================================================================
// Constante
// ============================================================================

pub const IDENTITY_BASE   : usize = 0x602000;
pub const IDENTITY_SECTOR : u64   = 0;        // Sectorul 0 al partiției Omni
pub const IDENTITY_MAGIC  : u32   = 0x4F4D4E49; // "OMNI"
pub const IDENTITY_VERSION: u16   = 1;

pub const NODE_FLAG_VALIDATOR : u8 = 0x01;
pub const NODE_FLAG_LIGHT     : u8 = 0x02;
pub const NODE_FLAG_MINER     : u8 = 0x04;
pub const NODE_FLAG_ORACLE    : u8 = 0x08;

// ============================================================================
// Structura identității
// ============================================================================

pub const NodeIdentity = extern struct {
    magic      : u32 = IDENTITY_MAGIC,
    version    : u16 = IDENTITY_VERSION,
    shard_id   : u16,          // 0–65535 – unde ești pe Grid
    node_id    : u64,          // Short ID (48 biți activi) – identitate în rețea
    pq_algo    : u8,           // PqAlgo ordinal (din pqc_wallet_bridge)
    flags      : u8,           // NODE_FLAG_*
    _pad       : [2]u8 = .{0,0},
    pubkey_len : u32,
    pubkey     : [2592]u8,     // Cheia publică PQ (max Dilithium-5)
    created_tsc: u64,
    last_seen  : u64,
    checksum   : u32,          // CRC32 simplu al primilor (20 + pubkey_len) bytes
};

// ============================================================================
// Accessor volatile (bare-metal)
// ============================================================================

fn getIdentity() *volatile NodeIdentity {
    return @as(*volatile NodeIdentity, @ptrFromInt(IDENTITY_BASE));
}

// ============================================================================
// CRC32 simplu (fără tabelă lookup, bare-metal safe)
// ============================================================================

fn crc32_update(crc: u32, data: []const u8) u32 {
    var c = crc ^ 0xFFFFFFFF;
    for (data) |byte| {
        c ^= byte;
        var i: u4 = 0;
        while (i < 8) : (i += 1) {
            if (c & 1 == 1) {
                c = (c >> 1) ^ 0xEDB88320;
            } else {
                c >>= 1;
            }
        }
    }
    return c ^ 0xFFFFFFFF;
}

fn compute_checksum(id: *const NodeIdentity) u32 {
    // Checksum pe header + pubkey (fără câmpul checksum însuși)
    var crc: u32 = 0;
    const header_bytes = @as([*]const u8, @ptrCast(id));
    // Primii 12 bytes: magic, version, shard_id, node_id, pq_algo, flags, pad, pubkey_len
    crc = crc32_update(crc, header_bytes[0..28]);
    // Pubkey
    crc = crc32_update(crc, id.pubkey[0..@min(id.pubkey_len, 2592)]);
    return crc;
}

// ============================================================================
// Derivarea Shard ID din cheia publică PQ
// XOR fold pe 64 biți, luăm primii 16 biți
// ============================================================================

fn derive_shard_id(pubkey: []const u8) u16 {
    var h: u64 = 0x6A09E667F3BCC908; // Seed (prima constantă SHA-512)
    for (pubkey) |b| {
        h ^= @as(u64, b) *% 0x9E3779B97F4A7C15; // Fibonacci hashing
        h = (h << 13) | (h >> 51);                // rotate
    }
    return @as(u16, @intCast(h & 0xFFFF));
}

fn derive_node_id(pubkey: []const u8, sh: u16) u64 {
    var h: u64 = @as(u64, sh) << 48;
    for (pubkey) |b| {
        h ^= @as(u64, b);
        h = (h *% 6364136223846793005) +% 1442695040888963407; // LCG
    }
    return h & 0x0000FFFFFFFFFFFF; // 48 biți
}

// ============================================================================
// Generare identitate nouă (prima pornire)
// ============================================================================

pub fn generate_identity(flags: u8) *volatile NodeIdentity {
    const id = getIdentity();

    // Generăm keypair PQ via pqc_bridge (RENT domain = ML-DSA-87, cel mai puternic)
    var slot: pqc.PqWalletSlot = undefined;
    const pubkey_len = pqc.keygen_for_domain(&slot, .RENT);

    id.magic       = IDENTITY_MAGIC;
    id.version     = IDENTITY_VERSION;
    id.pq_algo     = slot.algo;
    id.flags       = flags;
    id._pad        = .{0, 0};
    id.created_tsc = rdtsc();
    id.last_seen   = id.created_tsc;

    // Copiem cheia publică
    const copy_len = @min(pubkey_len, 2592);
    id.pubkey_len  = copy_len;
    var i: u32 = 0;
    while (i < copy_len) : (i += 1) id.pubkey[i] = slot.pubkey[i];
    while (i < 2592) : (i += 1) id.pubkey[i] = 0;

    // Derivăm shard_id și node_id din pubkey
    id.shard_id = derive_shard_id(slot.pubkey[0..copy_len]);
    id.node_id  = derive_node_id(slot.pubkey[0..copy_len], @as(u16, id.shard_id));

    // Inițializăm Grid cu shard-ul local
    grid.grid_init(id.shard_id);

    // Calculăm checksum
    id.checksum = compute_checksum(@as(*const NodeIdentity, @volatileCast(id)));

    return id;
}

// ============================================================================
// Încărcare identitate din disc (după reboot)
// ============================================================================

pub fn load_identity_from_sector(sector_data: *const NodeIdentity) bool {
    if (sector_data.magic != IDENTITY_MAGIC) return false;
    if (sector_data.version != IDENTITY_VERSION) return false;

    const expected_crc = compute_checksum(sector_data);
    if (sector_data.checksum != expected_crc) return false;

    // Copiem în memorie volatile
    const id = getIdentity();
    id.magic       = sector_data.magic;
    id.version     = sector_data.version;
    id.shard_id    = sector_data.shard_id;
    id.node_id     = sector_data.node_id;
    id.pq_algo     = sector_data.pq_algo;
    id.flags       = sector_data.flags;
    id.pubkey_len  = sector_data.pubkey_len;
    id.created_tsc = sector_data.created_tsc;
    id.last_seen   = rdtsc();
    id.checksum    = sector_data.checksum;

    var i: u32 = 0;
    while (i < 2592) : (i += 1) id.pubkey[i] = sector_data.pubkey[i];

    // Inițializăm Grid cu shard-ul restaurat
    grid.grid_init(id.shard_id);

    return true;
}

// ============================================================================
// Initializare nod (boot sequence)
// ============================================================================

/// Întoarce pointerul la identitate.
/// Dacă sector_data != null și valid → restaurează din disc.
/// Altfel → generează identitate nouă ca validator full.
pub fn init(sector_data: ?*const NodeIdentity) *volatile NodeIdentity {
    if (sector_data) |sd| {
        if (load_identity_from_sector(sd)) {
            return getIdentity();
        }
    }
    return generate_identity(NODE_FLAG_VALIDATOR);
}

// ============================================================================
// Queries
// ============================================================================

pub fn get() *volatile NodeIdentity { return getIdentity(); }

pub fn shard_id() u16 { return getIdentity().shard_id; }
pub fn node_id()  u64 { return getIdentity().node_id; }
pub fn is_validator() bool { return getIdentity().flags & NODE_FLAG_VALIDATOR != 0; }
pub fn is_light()     bool { return getIdentity().flags & NODE_FLAG_LIGHT != 0; }

/// Returnează adresa nativă OmniBus a nodului: ob_d5_<16 hex>
pub fn native_address() [20]u8 {
    const id  = getIdentity();
    var buf   : [20]u8 = undefined;
    const hex = "0123456789abcdef";
    const pfx = "ob_d5_";
    @memcpy(buf[0..6], pfx);
    var i: u8 = 0;
    while (i < 7 and i < id.pubkey_len) : (i += 1) {
        buf[6 + i * 2]     = hex[id.pubkey[i] >> 4];
        buf[6 + i * 2 + 1] = hex[id.pubkey[i] & 0xF];
    }
    return buf;
}

/// Returnează scurtul IP-hash (pentru Gossip peer registration)
pub fn ip_hash_from_node_id() u64 {
    const id = getIdentity();
    return id.node_id ^ (@as(u64, id.shard_id) << 48);
}

// ============================================================================
// RDTSC
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
