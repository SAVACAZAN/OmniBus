// p2p_node.zig – OmniBus P2P Node
// Leagă: node_identity + vid_shard_grid (BHG routing) + ws_collector (blocuri)
//        + omnibus_network_os/network_layer (UDP send/recv)
//
// Flux de date:
//   ws_collector.has_complete_block()
//     └→ p2p_node.broadcast_block()
//           └→ encode în UDPPacket (32B binary)
//                 └→ vid_shard_grid.gossip_route() → peer_idx
//                       └→ nic_send(peer_ip, payload)  [stub → NIC driver]
//
//   nic_recv() → p2p_node.receive_packet()
//     ├→ packet_validator: checksum + TTL
//     ├→ dedup: ignoră dacă deja văzut
//     ├→ procesează local (bloc/tranzacție/heartbeat)
//     └→ gossip_route() → forward la next hop
//
// Memorie: 0x603000 (P2P Node State, 4KB)

const identity  = @import("node_identity.zig");
const grid      = @import("vid_shard_grid.zig");
const collector = @import("ws_collector.zig");
const e1000     = @import("nic_e1000.zig");
// network_types importat inline (evităm path relativ cross-module)
// Tipurile necesare sunt redefinite local mai jos sau compatibile cu network_layer.zig

// ============================================================================
// Constante
// ============================================================================

pub const P2P_STATE_BASE: usize = 0x603000;
pub const OMNI_PORT     : u16   = 6626;
pub const DEDUP_SIZE    : usize = 512;   // Fereastră deduplicare (512 hash-uri recente)
pub const MAX_PEERS     : usize = 64;    // Peers cunoscuți (mai mult decât gossip)
pub const HEARTBEAT_INTERVAL_TSC: u64 = 900_000_000; // ~300ms @ 3GHz

// DEV_MODE: single-node testing (no seed peers, no network required)
// Set to false for production deployment with real validators
pub const DEV_MODE: bool = true;

// Packet types (aliniați cu network_types.zig)
pub const PKT_TRANSACTION  : u8 = 0x00;
pub const PKT_BLOCK_PROPOSAL: u8 = 0x03;
pub const PKT_BLOCK_COMMIT  : u8 = 0x04;
pub const PKT_PRICE_SNAPSHOT: u8 = 0x05;
pub const PKT_HEARTBEAT     : u8 = 0x06;
pub const PKT_GOSSIP_ROUTE  : u8 = 0x0B; // Cross-shard routing

// ============================================================================
// UDP Packet (compatibil cu network_layer.zig)
// ============================================================================

pub const PacketHeader = extern struct {
    magic        : u32 = 0x4F4D4E49,  // "OMNI"
    version      : u16 = 0x0001,
    packet_type  : u8,
    payload_count: u8,
    sequence     : u64,
    checksum_lo  : u64,  // Primii 8 bytes din BLAKE2 (bare-metal: XOR fold)
    checksum_hi  : u64,
    timestamp    : u32,
};  // 40 bytes

pub const P2PPacket = extern struct {
    header  : PacketHeader,
    shard_h : u16,     // Shard header: origin_shard (BHG routing)
    dest_h  : u16,     // Dest shard
    ttl     : u8,
    _pad    : [3]u8 = .{0} ** 3,
    payload : [1024]u8,
    pay_len : u16,
};

// ============================================================================
// Peer table
// ============================================================================

pub const PeerEntry = extern struct {
    shard_id   : u16,
    port       : u16,
    ip         : [4]u8,    // IPv4
    is_active  : bool,
    reputation : u8,       // 0–255
    _pad       : [2]u8 = .{0,0},
    last_seen  : u64,
    pkts_sent  : u32,
    pkts_recv  : u32,
};

// ============================================================================
// P2P Node State
// ============================================================================

pub const P2PNodeState = extern struct {
    magic         : u32 = 0x504E4F44,  // "PNOD"
    local_shard   : u16,
    local_port    : u16 = OMNI_PORT,
    is_running    : bool = false,
    _pad          : [3]u8 = .{0} ** 3,

    // Counters
    pkts_sent     : u64 = 0,
    pkts_recv     : u64 = 0,
    pkts_forward  : u64 = 0,
    pkts_drop     : u64 = 0,
    blocks_broad  : u64 = 0,

    // Sequence number (incrementat per pachet trimis)
    seq           : u64 = 0,

    // Deduplicare: ring buffer de sequence hashes
    dedup_ring    : [DEDUP_SIZE]u64,
    dedup_head    : u16 = 0,

    // Peer table
    peers         : [MAX_PEERS]PeerEntry,
    peer_count    : u8 = 0,

    // TSC la ultimul heartbeat
    last_heartbeat: u64 = 0,
};

fn getState() *volatile P2PNodeState {
    return @as(*volatile P2PNodeState, @ptrFromInt(P2P_STATE_BASE));
}

// ============================================================================
// Inițializare
// ============================================================================

pub fn init() void {
    const s = getState();
    s.magic          = 0x504E4F44;
    s.local_shard    = identity.shard_id();
    s.local_port     = OMNI_PORT;
    s.is_running     = true;
    s.pkts_sent      = 0;
    s.pkts_recv      = 0;
    s.pkts_forward   = 0;
    s.pkts_drop      = 0;
    s.blocks_broad   = 0;
    s.seq            = rdtsc();      // Seed cu TSC pentru unicitate
    s.dedup_head     = 0;
    s.peer_count     = 0;
    s.last_heartbeat = rdtsc();

    for (0..DEDUP_SIZE) |i| s.dedup_ring[i] = 0;
    for (0..MAX_PEERS)  |i| s.peers[i].is_active = false;

    // Înregistrează identitatea în grid (gossip local)
    grid.gossip_init(s.local_shard);
}

// ============================================================================
// Peer Management
// ============================================================================

pub fn add_peer(ip: [4]u8, port: u16, shard_id: u16) void {
    const s = getState();
    if (s.peer_count >= MAX_PEERS) return;

    // Verifică duplicate
    for (0..s.peer_count) |i| {
        if (s.peers[i].is_active and
            s.peers[i].ip[0] == ip[0] and s.peers[i].ip[1] == ip[1] and
            s.peers[i].ip[2] == ip[2] and s.peers[i].ip[3] == ip[3] and
            s.peers[i].port == port) return;
    }

    const idx = s.peer_count;
    s.peers[idx].ip         = ip;
    s.peers[idx].port       = port;
    s.peers[idx].shard_id   = shard_id;
    s.peers[idx].is_active  = true;
    s.peers[idx].reputation = 128;
    s.peers[idx].last_seen  = rdtsc();
    s.peers[idx].pkts_sent  = 0;
    s.peers[idx].pkts_recv  = 0;
    s.peer_count           += 1;

    // Înregistrează și în gossip routing table
    const ip_hash: u64 = @as(u64, ip[0]) << 24 | @as(u64, ip[1]) << 16 |
                         @as(u64, ip[2]) << 8  | @as(u64, ip[3]);
    grid.gossip_add_peer(shard_id, ip_hash);
}

/// Seed nodes hardcodate (de actualizat cu IP-uri reale la deploy)
pub fn connect_seed_nodes() void {
    // DEV_MODE: skip seed peers – single-node genesis, no network required
    if (DEV_MODE) return;

    // PRODUCTION: shard 0 → 2 bootstrap nodes (update IPs before deploy)
    add_peer(.{10,0,0,1}, OMNI_PORT, 0);
    add_peer(.{10,0,0,2}, OMNI_PORT, 1);
    add_peer(.{10,0,0,3}, OMNI_PORT, 2);
}

// ============================================================================
// Checksum (XOR fold, bare-metal, fără BLAKE2 dep)
// ============================================================================

fn compute_checksum(data: []const u8) u64 {
    var h: u64 = 0xCBF29CE484222325;  // FNV-1a offset basis
    for (data) |b| {
        h ^= b;
        h *%= 0x00000100000001B3;  // FNV prime
    }
    return h;
}

// ============================================================================
// Deduplicare
// ============================================================================

fn dedup_seen(seq: u64) bool {
    const s = getState();
    for (0..DEDUP_SIZE) |i| {
        if (s.dedup_ring[i] == seq) return true;
    }
    return false;
}

fn dedup_add(seq: u64) void {
    const s = getState();
    s.dedup_ring[s.dedup_head] = seq;
    s.dedup_head = @as(u16, @intCast((s.dedup_head + 1) % DEDUP_SIZE));
}

// ============================================================================
// Construcție pachet P2P
// ============================================================================

fn make_packet(pkt_type: u8, dest_shard: u16, ttl: u8, payload: []const u8) P2PPacket {
    const s    = getState();
    s.seq     +|= 1;

    var pkt: P2PPacket = undefined;
    pkt.header.magic         = 0x4F4D4E49;
    pkt.header.version       = 0x0001;
    pkt.header.packet_type   = pkt_type;
    pkt.header.payload_count = 1;
    pkt.header.sequence      = s.seq;
    pkt.header.timestamp     = @as(u32, @intCast(rdtsc() >> 22)); // ~ms resolution
    pkt.shard_h              = s.local_shard;
    pkt.dest_h               = dest_shard;
    pkt.ttl                  = ttl;
    pkt._pad                 = .{0, 0, 0};

    const copy_len = @min(payload.len, 1024);
    @memcpy(pkt.payload[0..copy_len], payload[0..copy_len]);
    @memset(pkt.payload[copy_len..], 0);
    pkt.pay_len = @as(u16, @intCast(copy_len));

    // Checksum
    const cs = compute_checksum(payload[0..copy_len]);
    pkt.header.checksum_lo = cs;
    pkt.header.checksum_hi = cs ^ s.seq;

    return pkt;
}

// ============================================================================
// NIC Send – E1000 driver real
// Serializăm P2PPacket şi îl trimitem prin E1000.
// Dacă E1000 nu e iniţializat (QEMU fără -nic e1000), fallback la stub.
// ============================================================================

fn nic_send(peer_idx: u8, pkt: *const P2PPacket) void {
    const s = getState();
    if (peer_idx >= s.peer_count) return;
    if (!s.peers[peer_idx].is_active) return;

    const pkt_bytes = @as([*]const u8, @ptrCast(pkt));
    const pkt_size  = @sizeOf(PacketHeader) + 8 + @as(usize, pkt.pay_len);
    const send_len  = if (pkt_size > 1024) @as(usize, 1024) else pkt_size;

    if (e1000.is_ready()) {
        // Calea normală: E1000 driver real
        _ = e1000.send(pkt_bytes[0..send_len]);
    } else {
        // Fallback: stub TX buffer (QEMU fără e1000, sau înainte de init)
        const tx_base = 0x140000 + (@as(usize, peer_idx) * 1120);
        const dst = @as([*]volatile u8, @ptrFromInt(tx_base));
        var i: usize = 0;
        while (i < send_len and i < 1120) : (i += 1) {
            dst[i] = pkt_bytes[i];
        }
        const tx_trigger = @as(*volatile u8, @ptrFromInt(0x13FFFF));
        tx_trigger.* = peer_idx;
    }

    s.peers[peer_idx].pkts_sent +|= 1;
    s.peers[peer_idx].last_seen  = rdtsc();
    s.pkts_sent +|= 1;
}

// ============================================================================
// Broadcast bloc complet (după quorum oracle)
// ============================================================================

pub fn broadcast_block() void {
    const s = getState();
    if (!collector.has_complete_block()) return;

    const mb = collector.get_latest_block();

    // Serializăm merkle_root + pq_sig în payload
    var payload: [64]u8 = undefined;
    @memcpy(payload[0..32], &mb.merkle_root);
    @memcpy(payload[32..64], mb.consensus_hash[0..32]);

    const dest_shard: u16 = 0xFFFF; // Broadcast la toate shard-urile
    var pkt = make_packet(PKT_BLOCK_COMMIT, dest_shard, 16, &payload);

    // Trimite la toți peers cunoscuți (gossip epidemic)
    for (0..s.peer_count) |i| {
        if (s.peers[i].is_active) {
            nic_send(@as(u8, @intCast(i)), &pkt);
        }
    }

    s.blocks_broad +|= 1;
    collector.consume_block();
}

// ============================================================================
// Rutare gossip cross-shard (BHG)
// ============================================================================

fn route_gossip(pkt: *P2PPacket) void {
    const s = getState();

    // Construiește GossipPacket pentru BHG routing
    var goss_pkt = grid.GossipPacket{
        .header  = grid.make_gossip_header(pkt.shard_h, pkt.dest_h, pkt.ttl, 0),
        .payload = undefined,
    };
    @memcpy(goss_pkt.payload[0..24], pkt.payload[0..24]);

    const peer_idx = grid.gossip_route(&goss_pkt);
    if (peer_idx == 0xFF) return;  // La destinație sau TTL expirat

    // Actualizăm header-ul pachetului cu noul TTL
    pkt.ttl = grid.gossip_get_ttl(goss_pkt.header);

    // Găsim peer-ul din gossip table în peer table P2P
    const goss_state_ptr = @as(*volatile grid.GossipState, @ptrFromInt(grid.GOSSIP_BASE));
    if (peer_idx < goss_state_ptr.peer_count) {
        // Mapăm gossip peer_idx → P2P peer_idx prin shard_id
        const target_shard = goss_state_ptr.peers[peer_idx].shard_id;
        for (0..s.peer_count) |i| {
            if (s.peers[i].is_active and s.peers[i].shard_id == target_shard) {
                nic_send(@as(u8, @intCast(i)), pkt);
                s.pkts_forward +|= 1;
                return;
            }
        }
    }

    s.pkts_drop +|= 1;
}

// ============================================================================
// Recepție pachet (apelat de NIC driver la interrupt)
// ============================================================================

pub fn receive_packet(raw: []const u8) void {
    const s = getState();
    if (raw.len < @sizeOf(PacketHeader)) return;

    const pkt = @as(*const P2PPacket, @ptrCast(raw.ptr));

    // Verifică magic
    if (pkt.header.magic != 0x4F4D4E49) { s.pkts_drop +|= 1; return; }

    // Verifică checksum
    const expected_cs = compute_checksum(pkt.payload[0..pkt.pay_len]);
    if (expected_cs != pkt.header.checksum_lo) { s.pkts_drop +|= 1; return; }

    // Deduplicare
    if (dedup_seen(pkt.header.sequence)) { s.pkts_drop +|= 1; return; }
    dedup_add(pkt.header.sequence);

    s.pkts_recv +|= 1;

    // Procesăm local dacă suntem destinația
    const dest = pkt.dest_h;
    const local = s.local_shard;

    if (dest == local or dest == 0xFFFF) {
        process_local(pkt);
    }

    // Rutăm mai departe dacă nu suntem destinația finală (TTL > 0)
    if (dest != local and pkt.ttl > 0) {
        var fwd = pkt.*;
        route_gossip(&fwd);
    }
}

// ============================================================================
// Procesare locală a pachetului
// ============================================================================

fn process_local(pkt: *const P2PPacket) void {
    switch (pkt.header.packet_type) {
        PKT_BLOCK_COMMIT => {
            // Un bloc nou a ajuns: verificăm merkle_root
            // În producție: validăm PQ semnătura + adăugăm la lanț
            // Acum: scriem merkle_root în stare (block_storage va persista)
            const block_root = @as(*volatile [32]u8, @ptrFromInt(0x5DB100));
            @memcpy(block_root, pkt.payload[0..32]);
        },
        PKT_PRICE_SNAPSHOT => {
            // Prețuri noi de la alt nod: injectăm în ws_collector
            // Payload: [token_id u8][exchange_id u8][price u64][bid u64][ask u64]
            if (pkt.pay_len >= 26) {
                const token_id    = pkt.payload[0];
                const exchange_id = pkt.payload[1];
                var price: u64 = 0;
                var bid  : u64 = 0;
                var ask  : u64 = 0;
                inline for (0..8) |i| price = (price << 8) | pkt.payload[2+i];
                inline for (0..8) |i| bid   = (bid   << 8) | pkt.payload[10+i];
                inline for (0..8) |i| ask   = (ask   << 8) | pkt.payload[18+i];
                collector.price_feed_push(token_id, exchange_id, price, bid, ask);
            }
        },
        PKT_HEARTBEAT => {
            // Actualizăm last_seen al peer-ului emițător
            const s = getState();
            for (0..s.peer_count) |i| {
                if (s.peers[i].shard_id == pkt.shard_h) {
                    s.peers[i].last_seen = rdtsc();
                    s.peers[i].pkts_recv +|= 1;
                    break;
                }
            }
        },
        else => {},
    }
}

// ============================================================================
// Heartbeat periodic (apelat din run_cycle)
// ============================================================================

pub fn heartbeat() void {
    const s   = getState();
    const now = rdtsc();
    if (now -% s.last_heartbeat < HEARTBEAT_INTERVAL_TSC) return;
    s.last_heartbeat = now;

    // Trimite heartbeat la toți peers
    const node_id_bytes = identity.node_id();
    var payload: [8]u8 = undefined;
    inline for (0..8) |i| {
        payload[i] = @as(u8, @intCast((node_id_bytes >> @as(u6, @intCast((7-i)*8))) & 0xFF));
    }

    var pkt = make_packet(PKT_HEARTBEAT, 0xFFFF, 1, &payload);
    for (0..s.peer_count) |i| {
        if (s.peers[i].is_active) nic_send(@as(u8, @intCast(i)), &pkt);
    }
}

// ============================================================================
// Main cycle (apelat din omnibus_blockchain_os.run_blockchain_cycle)
// ============================================================================

pub fn run_cycle() void {
    heartbeat();

    // Dacă avem un bloc complet, îl broadcaste
    if (collector.has_complete_block()) {
        broadcast_block();
    }
}

// ============================================================================
// Statistici
// ============================================================================

pub fn get_stats() struct {
    local_shard : u16,
    peers       : u8,
    pkts_sent   : u64,
    pkts_recv   : u64,
    pkts_forward: u64,
    pkts_drop   : u64,
    blocks_broad: u64,
} {
    const s = getState();
    return .{
        .local_shard  = s.local_shard,
        .peers        = s.peer_count,
        .pkts_sent    = s.pkts_sent,
        .pkts_recv    = s.pkts_recv,
        .pkts_forward = s.pkts_forward,
        .pkts_drop    = s.pkts_drop,
        .blocks_broad = s.blocks_broad,
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
