// vid_shard_grid.zig – Variable-Length ID + Grid Sharding + Binary Hyper-Gossip
// Phase 68: Omnibus "Infinity" – Scalare la 1.46 Octilioane de adrese
//
// Arhitectura:
//   Short ID  (prefix 00, 48 biți)  → 281 Trilioane  – utilizatori activi (RAM)
//   Full ID   (prefix 01, 160 biți) → 1.46 Octilioane – stocare profundă (Disk/SMT)
//   Extended  (prefix 10, 96 biți)  → 79 Septilioane  – nivel intermediar
//   System ID (prefix 11, 16 biți)  → 65.536          – oracle/validatori/protocol
//
// Grid Address Layout (Full ID 160 biți):
//   Biții 0-1:   Prefix V-ID  (01)
//   Biții 2-17:  Shard ID     (16 biți = 65.536 shard-uri)
//   Biții 18-81: Sector       (64 biți = poziție în shard)
//   Biții 82-161: Local Addr  (80 biți = adresă exactă în sector)
//
// Sparse Merkle Grid:
//   Level 0 – Shard Bitmap (8KB RAM): 1 bit per shard, care sharduri au activitate
//   Level 1 – Hot Cache    (RAM): max 64 shard-uri active cu câte 256 sectoare
//   Level 2 – Cold Storage (Disk): restul octilioanelor
//
// Binary Hyper-Gossip (BHG):
//   16 hop-uri logaritmice (2^0, 2^1 ... 2^15) acoperă toate 65.536 shard-uri
//   Header 64 biți: [2b route_flag][16b origin][16b dest][6b TTL][24b payload_hash]
//
// Memorie:
//   0x5E0000 – ShardGridState  (4KB)
//   0x5E1000 – Shard Bitmap    (8KB = 65.536 biți)
//   0x5E3000 – Hot Shard Cache (64 shard-uri × 4KB = 256KB)
//   0x5F3000 – Gossip State    (4KB)

// ============================================================================
// Constante
// ============================================================================

pub const GRID_STATE_BASE  : usize = 0x5E0000;
pub const SHARD_BITMAP_BASE: usize = 0x5E1000;
pub const HOT_CACHE_BASE   : usize = 0x5E3000;
pub const GOSSIP_BASE      : usize = 0x5F3000;

pub const SHARD_COUNT      : usize = 65_536;      // 2^16 shard-uri
pub const HOT_SHARD_SLOTS  : usize = 64;          // shard-uri ținute în RAM
pub const SECTOR_SLOTS     : usize = 256;         // sectoare per shard în cache
pub const MAX_GOSSIP_PEERS : usize = 32;

// ============================================================================
// V-ID Prefix (2 biți)
// ============================================================================

pub const VidPrefix = enum(u2) {
    SHORT    = 0b00,   // 48 biți  → 281 Trilioane
    FULL     = 0b01,   // 160 biți → 1.46 Octilioane
    EXTENDED = 0b10,   // 96 biți  → 79 Septilioane
    SYSTEM   = 0b11,   // 16 biți  → 65.536
};

// ============================================================================
// V-ID tipuri (tagged union în stil bare-metal)
// ============================================================================

pub const Vid = extern struct {
    prefix : u8,            // VidPrefix ca u8
    // raw bytes pentru adresa (max 20 bytes = 160 biți)
    bytes  : [20]u8,
    len    : u8,            // lungimea efectivă în bytes
};

/// Construiește un Short ID (48 biți) din valoarea u64
pub fn make_short_id(val: u64) Vid {
    var v: Vid = undefined;
    v.prefix = @intFromEnum(VidPrefix.SHORT);
    v.len    = 6;
    v.bytes[0] = @as(u8, @intCast((val >> 40) & 0xFF));
    v.bytes[1] = @as(u8, @intCast((val >> 32) & 0xFF));
    v.bytes[2] = @as(u8, @intCast((val >> 24) & 0xFF));
    v.bytes[3] = @as(u8, @intCast((val >> 16) & 0xFF));
    v.bytes[4] = @as(u8, @intCast((val >>  8) & 0xFF));
    v.bytes[5] = @as(u8, @intCast((val       ) & 0xFF));
    @memset(v.bytes[6..], 0);
    return v;
}

/// Construiește un Full ID (160 biți) din shard + sector + local
pub fn make_full_id(shard: u16, sector: u64, local: u64) Vid {
    // Encodare: [16b shard][64b sector][80b local → truncat la 64b + 16b zero]
    var v: Vid = undefined;
    v.prefix   = @intFromEnum(VidPrefix.FULL);
    v.len      = 20;
    // Bytes 0-1: shard_id
    v.bytes[0] = @as(u8, @intCast((shard >> 8) & 0xFF));
    v.bytes[1] = @as(u8, @intCast(shard & 0xFF));
    // Bytes 2-9: sector (64 biți)
    inline for (0..8) |i| {
        v.bytes[2 + i] = @as(u8, @intCast((sector >> @as(u6, @intCast((7 - i) * 8))) & 0xFF));
    }
    // Bytes 10-17: local addr (64 biți din 80)
    inline for (0..8) |i| {
        v.bytes[10 + i] = @as(u8, @intCast((local >> @as(u6, @intCast((7 - i) * 8))) & 0xFF));
    }
    // Bytes 18-19: upper 16 biți ai local addr (lăsăm 0 pentru simplitate)
    v.bytes[18] = 0;
    v.bytes[19] = 0;
    return v;
}

/// Construiește un System ID (16 biți)
pub fn make_system_id(val: u16) Vid {
    var v: Vid = undefined;
    v.prefix   = @intFromEnum(VidPrefix.SYSTEM);
    v.len      = 2;
    v.bytes[0] = @as(u8, @intCast((val >> 8) & 0xFF));
    v.bytes[1] = @as(u8, @intCast(val & 0xFF));
    @memset(v.bytes[2..], 0);
    return v;
}

/// Extrage Shard ID dintr-un Full ID
pub fn shard_of(v: *const Vid) u16 {
    if (v.prefix != @intFromEnum(VidPrefix.FULL)) return 0;
    return (@as(u16, v.bytes[0]) << 8) | v.bytes[1];
}

/// Extrage Sector dintr-un Full ID
pub fn sector_of(v: *const Vid) u64 {
    if (v.prefix != @intFromEnum(VidPrefix.FULL)) return 0;
    var s: u64 = 0;
    inline for (0..8) |i| {
        s = (s << 8) | v.bytes[2 + i];
    }
    return s;
}

// ============================================================================
// Sparse Merkle Grid – Shard Bitmap
// Level 0: 1 bit per shard → ce shard-uri au activitate
// ============================================================================

/// Marchează un shard ca activ în bitmap (bara-metal direct)
pub fn shard_bitmap_set(shard_id: u16) void {
    const bitmap = @as([*]volatile u8, @ptrFromInt(SHARD_BITMAP_BASE));
    const byte_idx = shard_id / 8;
    const bit_idx  = @as(u3, @intCast(shard_id & 7));
    bitmap[byte_idx] |= @as(u8, 1) << bit_idx;
}

/// Verifică dacă un shard este activ
pub fn shard_bitmap_test(shard_id: u16) bool {
    const bitmap = @as([*]const volatile u8, @ptrFromInt(SHARD_BITMAP_BASE));
    const byte_idx = shard_id / 8;
    const bit_idx  = @as(u3, @intCast(shard_id & 7));
    return (bitmap[byte_idx] >> bit_idx) & 1 == 1;
}

/// Numără shard-urile active (popcount pe 8KB)
pub fn active_shard_count() u32 {
    const bitmap = @as([*]const volatile u8, @ptrFromInt(SHARD_BITMAP_BASE));
    var count: u32 = 0;
    var i: usize = 0;
    while (i < SHARD_COUNT / 8) : (i += 1) {
        count += @popCount(bitmap[i]);
    }
    return count;
}

// ============================================================================
// Hot Shard Cache – Level 1
// Ține în RAM max 64 shard-uri active cu câte 256 sectoare
// ============================================================================

pub const HotSectorEntry = extern struct {
    sector     : u64,
    balance    : u64,     // soldul total al sectorului
    short_id   : u64,     // Short ID mapare (0 = nealocat)
    is_active  : bool,
    _pad       : [7]u8 = .{0} ** 7,
};

pub const HotShardSlot = extern struct {
    shard_id   : u16,
    is_valid   : bool,
    lru_tick   : u8,      // pentru evicție LRU (0-255)
    sector_count: u32,
    sectors    : [SECTOR_SLOTS]HotSectorEntry,
};

fn getHotCache() *volatile [HOT_SHARD_SLOTS]HotShardSlot {
    return @as(*volatile [HOT_SHARD_SLOTS]HotShardSlot, @ptrFromInt(HOT_CACHE_BASE));
}

/// Găsește slotul cache pentru un shard (sau -1 dacă nu e în cache)
fn find_hot_slot(shard_id: u16) i8 {
    const cache = getHotCache();
    for (0..HOT_SHARD_SLOTS) |i| {
        if (cache[i].is_valid and cache[i].shard_id == shard_id) {
            return @as(i8, @intCast(i));
        }
    }
    return -1;
}

/// Evictă cel mai vechi slot (LRU cu counter 0-255)
fn evict_lru_slot() u8 {
    const cache = getHotCache();
    var min_tick: u8 = 255;
    var evict_idx: u8 = 0;
    for (0..HOT_SHARD_SLOTS) |i| {
        if (!cache[i].is_valid) return @as(u8, @intCast(i));
        if (cache[i].lru_tick < min_tick) {
            min_tick  = cache[i].lru_tick;
            evict_idx = @as(u8, @intCast(i));
        }
    }
    return evict_idx;
}

/// Urcă un shard din stocare în cache RAM (promote to hot)
pub fn promote_shard(shard_id: u16) u8 {
    const cache = getHotCache();

    // Verifică dacă e deja în cache
    const existing = find_hot_slot(shard_id);
    if (existing >= 0) {
        cache[@as(usize, @intCast(existing))].lru_tick +|= 1;
        return @as(u8, @intCast(existing));
    }

    // Găsește slot liber sau evictează LRU
    const slot = evict_lru_slot();
    cache[slot].shard_id     = shard_id;
    cache[slot].is_valid     = true;
    cache[slot].lru_tick     = 128;  // Start la mijlocul scalei
    cache[slot].sector_count = 0;

    // Inițializează sectoarele goale
    for (0..SECTOR_SLOTS) |i| {
        cache[slot].sectors[i].is_active = false;
        cache[slot].sectors[i].sector    = 0;
        cache[slot].sectors[i].balance   = 0;
        cache[slot].sectors[i].short_id  = 0;
    }

    // Marchează shards bitmap ca activ
    shard_bitmap_set(shard_id);

    return slot;
}

/// Înregistrează o adresă Full ID în cache și returnează Short ID nou alocat
/// (pentru "urcarea" din stocare în RAM)
pub fn register_full_id_in_cache(v: *const Vid, dict_next_short_id: u64) u64 {
    if (v.prefix != @intFromEnum(VidPrefix.FULL)) return 0;

    const shard  = shard_of(v);
    const sector = sector_of(v);

    const slot_idx = promote_shard(shard);
    const cache    = getHotCache();
    var slot       = &cache[slot_idx];

    // Caută sectorul sau adaugă
    for (0..SECTOR_SLOTS) |i| {
        if (slot.sectors[i].is_active and slot.sectors[i].sector == sector) {
            return slot.sectors[i].short_id;  // Deja înregistrat
        }
    }

    // Adaugă sector nou
    if (slot.sector_count < SECTOR_SLOTS) {
        const idx = slot.sector_count;
        slot.sectors[idx].sector    = sector;
        slot.sectors[idx].short_id  = dict_next_short_id;
        slot.sectors[idx].balance   = 0;
        slot.sectors[idx].is_active = true;
        slot.sector_count          += 1;
        return dict_next_short_id;
    }

    return 0;  // Cache sector plin
}

// ============================================================================
// Sparse Merkle Tree – Hash de shard (Level 0 Merkle Root)
// Fiecare shard are un hash = XOR fold al tuturor sectorelor active
// Root = XOR fold al hash-urilor de shard activ
// ============================================================================

pub fn compute_shard_hash(shard_id: u16) u64 {
    const slot_idx = find_hot_slot(shard_id);
    if (slot_idx < 0) return 0;  // Sharding cold: hash = 0 (zero branch în SMT)

    const cache = getHotCache();
    const slot  = &cache[@as(usize, @intCast(slot_idx))];
    var h: u64  = @as(u64, shard_id) << 48;

    for (0..slot.sector_count) |i| {
        if (slot.sectors[i].is_active) {
            h ^= slot.sectors[i].sector;
            h ^= slot.sectors[i].balance;
            h ^= slot.sectors[i].short_id << 32;
        }
    }
    return h;
}

/// Sparse Merkle Root: XOR fold al hash-urilor shard-urilor active
/// Zero branch optimization: shard-urile inactive nu contribuie (XOR cu 0)
pub fn compute_sparse_merkle_root() u64 {
    const bitmap = @as([*]const volatile u8, @ptrFromInt(SHARD_BITMAP_BASE));
    var root: u64 = 0;

    // Parcurgem doar shard-urile marcate ca active în bitmap
    var byte_idx: usize = 0;
    while (byte_idx < SHARD_COUNT / 8) : (byte_idx += 1) {
        var bits = bitmap[byte_idx];
        if (bits == 0) continue;  // Sari peste 8 shard-uri inactive instant

        var bit_pos: u3 = 0;
        while (bits != 0) : (bit_pos +%= 1) {
            if (bits & 1 == 1) {
                const shard_id = @as(u16, @intCast(byte_idx * 8)) + bit_pos;
                root ^= compute_shard_hash(shard_id);
            }
            bits >>= 1;
            if (bit_pos == 7) break;
        }
    }
    return root;
}

// ============================================================================
// Multi-Slot Packet (512 biți = 2 × 256 biți)
// Folosit când sender SAU receiver are Full ID (160 biți)
// ============================================================================

// Layout Slot 0 (256 biți):
//   [2b: MULTI=0b10][2b: type][2b: id_mode][2b: reserved]  → byte 0
//   [16b: origin shard][16b: dest shard]                    → bytes 1-4
//   [160b: sender Full ID]                                  → bytes 5-24
//   [24b: reserved/nonce_hi]                                → bytes 25-27 (partial)
//   ... continuare în slot 1

// Layout Slot 1 (256 biți):
//   [160b: receiver Full ID]                                → bytes 0-19
//   [64b: amount]                                           → bytes 20-27
//   [16b: nonce_lo]                                         → bytes 28-29
//   [16b: sig_short (first 16 biți din PQ sig hash)]        → bytes 30-31

pub const MultiSlotPacket = extern struct {
    slot0 : [32]u8,
    slot1 : [32]u8,
};

pub const IdMode = enum(u2) {
    BOTH_SHORT = 0b00,   // ambele adrese sunt Short ID → pachet single-slot
    SENDER_FULL = 0b01,  // sender are Full ID → multi-slot
    RECV_FULL   = 0b10,  // receiver are Full ID → multi-slot
    BOTH_FULL   = 0b11,  // amândoi Full ID → multi-slot
};

pub fn encode_multi_slot(
    sender   : *const Vid,
    receiver : *const Vid,
    amount   : u64,
    nonce    : u16,
    sig_hash : u16,   // primii 16 biți din hash-ul semnăturii PQ
) MultiSlotPacket {
    var pkt: MultiSlotPacket = undefined;
    @memset(&pkt.slot0, 0);
    @memset(&pkt.slot1, 0);

    // Slot 0: header
    // byte 0: [2b MULTI=0b10][2b type=TRANSFER][2b id_mode][2b reserved]
    const id_mode: u8 = switch (@as(VidPrefix, @enumFromInt(sender.prefix))) {
        .FULL => if (@as(VidPrefix, @enumFromInt(receiver.prefix)) == .FULL) 0b11 else 0b01,
        else  => if (@as(VidPrefix, @enumFromInt(receiver.prefix)) == .FULL) 0b10 else 0b00,
    };
    pkt.slot0[0] = (0b10 << 6) | (0b00 << 4) | (id_mode << 2);

    // bytes 1-2: origin shard (từ sender Full ID)
    const origin_shard = if (sender.prefix == @intFromEnum(VidPrefix.FULL)) shard_of(sender) else 0;
    const dest_shard   = if (receiver.prefix == @intFromEnum(VidPrefix.FULL)) shard_of(receiver) else 0;
    pkt.slot0[1] = @as(u8, @intCast((origin_shard >> 8) & 0xFF));
    pkt.slot0[2] = @as(u8, @intCast(origin_shard & 0xFF));
    pkt.slot0[3] = @as(u8, @intCast((dest_shard >> 8) & 0xFF));
    pkt.slot0[4] = @as(u8, @intCast(dest_shard & 0xFF));

    // bytes 5-24: sender Full ID (20 bytes)
    const sender_len = @min(sender.len, 20);
    @memcpy(pkt.slot0[5..5+sender_len], sender.bytes[0..sender_len]);

    // bytes 25-27: nonce high
    pkt.slot0[25] = @as(u8, @intCast((nonce >> 8) & 0xFF));
    pkt.slot0[26] = @as(u8, @intCast(nonce & 0xFF));

    // Slot 1: receiver + amount + nonce_lo + sig_hash
    const recv_len = @min(receiver.len, 20);
    @memcpy(pkt.slot1[0..recv_len], receiver.bytes[0..recv_len]);

    // bytes 20-27: amount (64 biți, big-endian)
    inline for (0..8) |i| {
        pkt.slot1[20 + i] = @as(u8, @intCast((amount >> @as(u6, @intCast((7 - i) * 8))) & 0xFF));
    }

    // bytes 28-29: nonce_lo (low 16 biți ai nonce-ului de 32b)
    pkt.slot1[28] = @as(u8, @intCast((nonce >> 8) & 0xFF));
    pkt.slot1[29] = @as(u8, @intCast(nonce & 0xFF));

    // bytes 30-31: sig_hash (primii 16 biți din hash-ul semnăturii)
    pkt.slot1[30] = @as(u8, @intCast((sig_hash >> 8) & 0xFF));
    pkt.slot1[31] = @as(u8, @intCast(sig_hash & 0xFF));

    return pkt;
}

pub fn decode_multi_slot_amount(pkt: *const MultiSlotPacket) u64 {
    var amount: u64 = 0;
    inline for (0..8) |i| {
        amount = (amount << 8) | pkt.slot1[20 + i];
    }
    return amount;
}

pub fn decode_multi_slot_dest_shard(pkt: *const MultiSlotPacket) u16 {
    return (@as(u16, pkt.slot0[3]) << 8) | pkt.slot0[4];
}

// ============================================================================
// Binary Hyper-Gossip (BHG) – Protocol de rutare logaritmică
// 16 hop-uri acoperă toate 65.536 shard-uri: 2^0, 2^1, ..., 2^15
// ============================================================================

pub const MAX_TTL: u8 = 16;  // log2(65536) = 16 hop-uri maxim

pub const GossipHeader = packed struct {
    route_flag   : u2,   // 0b11 = CrossShard Gossip
    origin_shard : u16,
    dest_shard   : u16,
    ttl          : u6,   // max 64, suficient pentru 16 hop-uri
    payload_hash : u24,  // amprenta tranzacției (primii 24 biți din Merkle hash)
};  // Total: 2+16+16+6+24 = 64 biți

pub const GossipPacket = extern struct {
    header    : u64,        // GossipHeader encodat ca u64
    payload   : [24]u8,     // tranzacția compresată (192 biți)
};

/// Construiește un GossipHeader encodat ca u64
pub fn make_gossip_header(
    origin     : u16,
    dest       : u16,
    ttl        : u6,
    pay_hash   : u24,
) u64 {
    var h: u64 = 0;
    h |= @as(u64, 0b11) << 62;                          // route_flag
    h |= @as(u64, origin) << 46;                         // origin_shard
    h |= @as(u64, dest) << 30;                           // dest_shard
    h |= @as(u64, ttl) << 24;                            // TTL
    h |= @as(u64, pay_hash);                             // payload_hash
    return h;
}

pub fn gossip_get_route_flag(h: u64) u2   { return @as(u2,  @intCast((h >> 62) & 0b11)); }
pub fn gossip_get_origin(h: u64)    u16   { return @as(u16, @intCast((h >> 46) & 0xFFFF)); }
pub fn gossip_get_dest(h: u64)      u16   { return @as(u16, @intCast((h >> 30) & 0xFFFF)); }
pub fn gossip_get_ttl(h: u64)       u8    { return @as(u8,  @intCast((h >> 24) & 0x3F)); }
pub fn gossip_get_payload_hash(h: u64) u32 { return @as(u32, @intCast(h & 0xFFFFFF)); }

/// Calculează hop-ul următor în ruta logaritmică
/// Folosind Binary Lifting: dest XOR origin → bit cel mai semnificativ activ
pub fn gossip_next_hop(origin: u16, dest: u16) u16 {
    const diff = origin ^ dest;
    if (diff == 0) return dest;  // Suntem la destinație

    // Găsim cel mai semnificativ bit diferit
    var msb: u16 = 0x8000;
    while (msb > 0) : (msb >>= 1) {
        if (diff & msb != 0) break;
    }

    // Hop la adresa care rezolvă acel bit
    return origin ^ msb;
}

/// Decrementează TTL și verifică validitatea pachetului
pub fn gossip_decrement_ttl(header: u64) struct { valid: bool, new_header: u64 } {
    const ttl = gossip_get_ttl(header);
    if (ttl == 0) return .{ .valid = false, .new_header = header };

    const new_ttl: u6 = @as(u6, @intCast(ttl - 1));
    const new_h   = (header & ~(@as(u64, 0x3F) << 24)) | (@as(u64, new_ttl) << 24);
    return .{ .valid = true, .new_header = new_h };
}

// ============================================================================
// Gossip Routing Table (max 32 peers)
// ============================================================================

pub const GossipPeer = extern struct {
    shard_id   : u16,
    is_active  : bool,
    hop_count  : u8,         // Câte hop-uri până la el
    _pad       : [4]u8 = .{0} ** 4,
    ip_hash    : u64,        // Hash al IP-ului (pentru bare-metal, nu stocăm IP direct)
    last_seen  : u64,        // TSC timestamp
    packets_fwd: u64,        // Pachete rutate prin el
};

pub const GossipState = extern struct {
    magic        : u32 = 0x47535350,  // "GSSP"
    local_shard  : u16,
    peer_count   : u8,
    _pad         : u8 = 0,
    packets_sent : u64,
    packets_recv : u64,
    packets_drop : u64,
    peers        : [MAX_GOSSIP_PEERS]GossipPeer,
};

fn getGossipState() *volatile GossipState {
    return @as(*volatile GossipState, @ptrFromInt(GOSSIP_BASE));
}

pub fn gossip_init(local_shard: u16) void {
    const gs = getGossipState();
    gs.magic        = 0x47535350;
    gs.local_shard  = local_shard;
    gs.peer_count   = 0;
    gs.packets_sent = 0;
    gs.packets_recv = 0;
    gs.packets_drop = 0;
    for (0..MAX_GOSSIP_PEERS) |i| gs.peers[i].is_active = false;
}

pub fn gossip_add_peer(shard_id: u16, ip_hash: u64) void {
    const gs = getGossipState();
    if (gs.peer_count >= MAX_GOSSIP_PEERS) return;

    const idx = gs.peer_count;
    gs.peers[idx].shard_id  = shard_id;
    gs.peers[idx].is_active = true;
    gs.peers[idx].ip_hash   = ip_hash;
    gs.peers[idx].hop_count = 1;
    gs.peers[idx].last_seen = rdtsc();
    gs.peers[idx].packets_fwd = 0;
    gs.peer_count += 1;
}

/// Rutează un GossipPacket: returnează peer_idx de trimis sau 0xFF dacă suntem la destinație
pub fn gossip_route(pkt: *GossipPacket) u8 {
    const gs   = getGossipState();
    const dest = gossip_get_dest(pkt.header);

    // Suntem la destinație?
    if (dest == gs.local_shard) return 0xFF;

    // Decrementează TTL
    const ttl_result = gossip_decrement_ttl(pkt.header);
    if (!ttl_result.valid) {
        gs.packets_drop +|= 1;
        return 0xFF;
    }
    pkt.header = ttl_result.new_header;

    // Calculează hop-ul următor
    const next_shard = gossip_next_hop(gs.local_shard, dest);

    // Găsește peer-ul care se ocupă de next_shard
    for (0..gs.peer_count) |i| {
        if (gs.peers[i].is_active and gs.peers[i].shard_id == next_shard) {
            gs.peers[i].packets_fwd +|= 1;
            gs.packets_sent +|= 1;
            return @as(u8, @intCast(i));
        }
    }

    // Nu găsim peer direct: trimite la cel mai apropiat din perspectiva XOR
    var best_idx: u8 = 0xFF;
    var best_dist: u16 = 0xFFFF;
    for (0..gs.peer_count) |i| {
        if (!gs.peers[i].is_active) continue;
        const dist = gs.peers[i].shard_id ^ next_shard;
        if (dist < best_dist) {
            best_dist = dist;
            best_idx  = @as(u8, @intCast(i));
        }
    }

    if (best_idx != 0xFF) gs.packets_sent +|= 1;
    return best_idx;
}

// ============================================================================
// ShardGrid State – Master State Machine
// ============================================================================

pub const ShardGridState = extern struct {
    magic         : u32 = 0x47524944,  // "GRID"
    version       : u16 = 1,
    local_shard   : u16,
    total_addrs   : u64,   // total adrese înregistrate (Short + Full)
    short_addrs   : u64,
    full_addrs    : u64,
    promoted_addrs: u64,   // adrese urcate din disk în RAM
    merkle_root   : u64,   // Sparse Merkle Root curent
    last_root_update: u64,
};

fn getGridState() *volatile ShardGridState {
    return @as(*volatile ShardGridState, @ptrFromInt(GRID_STATE_BASE));
}

pub fn grid_init(local_shard: u16) void {
    // Inițializare stare principală
    const gs = getGridState();
    gs.magic          = 0x47524944;
    gs.version        = 1;
    gs.local_shard    = local_shard;
    gs.total_addrs    = 0;
    gs.short_addrs    = 0;
    gs.full_addrs     = 0;
    gs.promoted_addrs = 0;
    gs.merkle_root    = 0;
    gs.last_root_update = rdtsc();

    // Curăță bitmap-ul de shard-uri
    const bitmap = @as([*]volatile u8, @ptrFromInt(SHARD_BITMAP_BASE));
    var i: usize = 0;
    while (i < SHARD_COUNT / 8) : (i += 1) bitmap[i] = 0;

    // Activează shards-ul local
    shard_bitmap_set(local_shard);
    _ = promote_shard(local_shard);

    // Inițializare Gossip
    gossip_init(local_shard);
}

/// Înregistrează o adresă V-ID, returnează Short ID alocat (pentru Full ID: face promote)
pub fn grid_register_address(v: *const Vid, next_short_id: u64) u64 {
    const gs = getGridState();

    switch (@as(VidPrefix, @enumFromInt(v.prefix))) {
        .SHORT => {
            gs.short_addrs  +|= 1;
            gs.total_addrs  +|= 1;
            return @as(u64, v.bytes[0]) << 40 |
                   @as(u64, v.bytes[1]) << 32 |
                   @as(u64, v.bytes[2]) << 24 |
                   @as(u64, v.bytes[3]) << 16 |
                   @as(u64, v.bytes[4]) <<  8 |
                   @as(u64, v.bytes[5]);
        },
        .FULL => {
            const short_id = register_full_id_in_cache(v, next_short_id);
            if (short_id > 0) {
                gs.full_addrs     +|= 1;
                gs.promoted_addrs +|= 1;
                gs.total_addrs    +|= 1;
            }
            return short_id;
        },
        .SYSTEM => {
            gs.total_addrs +|= 1;
            return (@as(u64, v.bytes[0]) << 8) | v.bytes[1];
        },
        .EXTENDED => {
            gs.total_addrs +|= 1;
            return next_short_id;
        },
    }
}

/// Actualizează Sparse Merkle Root (apelat după fiecare bloc)
pub fn grid_update_merkle_root() void {
    const gs = getGridState();
    gs.merkle_root      = compute_sparse_merkle_root();
    gs.last_root_update = rdtsc();
}

// ============================================================================
// Statistici
// ============================================================================

pub fn get_grid_stats() struct {
    local_shard   : u16,
    active_shards : u32,
    total_addrs   : u64,
    short_addrs   : u64,
    full_addrs    : u64,
    promoted      : u64,
    merkle_root   : u64,
    gossip_peers  : u8,
} {
    const gs   = getGridState();
    const goss = getGossipState();
    return .{
        .local_shard   = gs.local_shard,
        .active_shards = active_shard_count(),
        .total_addrs   = gs.total_addrs,
        .short_addrs   = gs.short_addrs,
        .full_addrs    = gs.full_addrs,
        .promoted      = gs.promoted_addrs,
        .merkle_root   = gs.merkle_root,
        .gossip_peers  = goss.peer_count,
    };
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
