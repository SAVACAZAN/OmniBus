// vault_storage.zig – Bare-Metal Wallet + Block Persistence
// Scrie direct pe sectoare NVMe/SATA fără filesystem.
//
// Layout pe disc (sectoare de 512B):
//   Sector 0:   NodeIdentity (identity.omni)    – 2592B = 6 sectoare
//   Sector 6:   VaultHeader  (indice sloturi)   – 1 sector
//   Sector 7:   WalletSlot 0 (PqWalletSlot)     – 8 sectoare fiecare
//   Sector 15:  WalletSlot 1
//   ...
//   Sector 7 + N*8: WalletSlot N (max 16 sloturi = 128 sectoare)
//   Sector 135: BlockRing header                – 1 sector
//   Sector 136: BlockRing data (256 blocuri × 32 sectoare fiecare)
//
// AHCI/ATA stub: în producție înlocuit cu driver AHCI real.
// Acum: scrie în RAM la adresa 0x700000+ (disk emulat pentru QEMU).
//
// Memorie RAM-mapped disc: 0x700000 (8MB disk image în RAM)

const identity_mod = @import("node_identity.zig");
const pqc          = @import("pqc_wallet_bridge.zig");

// ============================================================================
// Constante
// ============================================================================

pub const SECTOR_SIZE   : usize = 512;
pub const DISK_RAM_BASE : usize = 0x700000;   // Disc emulat în RAM (QEMU)
pub const DISK_RAM_SIZE : usize = 0x800000;   // 8MB

// Sectorii fizici
pub const SECTOR_IDENTITY  : u64 = 0;
pub const SECTOR_VAULT_HDR : u64 = 6;
pub const SECTOR_WALLET_0  : u64 = 7;
pub const SECTORS_PER_WALLET: u64 = 8;   // 8 × 512 = 4096B per slot
pub const MAX_WALLET_SLOTS : usize = 16;
pub const SECTOR_BLOCK_HDR : u64 = 135;
pub const SECTOR_BLOCK_DATA: u64 = 136;
pub const SECTORS_PER_BLOCK: u64 = 32;  // 32 × 512 = 16KB per bloc
pub const MAX_BLOCK_RING   : usize = 256;

// ============================================================================
// Vault Header (1 sector = 512B)
// ============================================================================

pub const VaultHeader = extern struct {
    magic        : u32 = 0x564C5441,   // "VLTA"
    version      : u16 = 1,
    slot_count   : u8  = 0,
    _pad         : u8  = 0,
    active_slots : u16,                // Bitmap 16 biți: care sloturi sunt ocupate
    _pad2        : [2]u8 = .{0,0},
    wallet_flags : [MAX_WALLET_SLOTS]u8, // Flags per slot (algo, domain, etc.)
    checksum     : u32,
    _fill        : [512 - 32 - MAX_WALLET_SLOTS]u8 = .{0} ** (512 - 32 - MAX_WALLET_SLOTS),
};

// ============================================================================
// Block Ring Header (1 sector)
// ============================================================================

pub const BlockRingHeader = extern struct {
    magic      : u32 = 0x424C4B52,  // "BLKR"
    ring_size  : u32 = MAX_BLOCK_RING,
    write_head : u32 = 0,           // Indexul următorului slot de scris
    total_written: u64 = 0,
    last_height: u64 = 0,
    checksum   : u32 = 0,
    _fill      : [512 - 28]u8 = .{0} ** (512 - 28),
};

// ============================================================================
// AHCI / Disk I/O Stub
// În producție: înlocuit cu apeluri AHCI DMA
// Acum: citire/scriere în RAM @ DISK_RAM_BASE + sector * SECTOR_SIZE
// ============================================================================

fn sector_ptr(sector: u64) [*]volatile u8 {
    const offset = @as(usize, @intCast(sector)) * SECTOR_SIZE;
    if (offset + SECTOR_SIZE > DISK_RAM_SIZE) {
        // Overflow: întoarce adresa de start (failsafe)
        return @as([*]volatile u8, @ptrFromInt(DISK_RAM_BASE));
    }
    return @as([*]volatile u8, @ptrFromInt(DISK_RAM_BASE + offset));
}

fn disk_write(sector: u64, data: []const u8) void {
    const dst     = sector_ptr(sector);
    const sectors = (data.len + SECTOR_SIZE - 1) / SECTOR_SIZE;
    var   written : usize = 0;
    var   sec_idx : usize = 0;
    while (sec_idx < sectors and written < data.len) : (sec_idx += 1) {
        const ptr = sector_ptr(sector + sec_idx);
        var s: usize = 0;
        while (s < SECTOR_SIZE and written < data.len) : (s += 1) {
            ptr[s] = data[written];
            written += 1;
        }
        // Pad restul sectorului cu 0
        while (s < SECTOR_SIZE) : (s += 1) ptr[s] = 0;
    }
    _ = dst;
}

fn disk_read(sector: u64, dst: []u8) void {
    var read: usize = 0;
    var sec_idx: usize = 0;
    while (read < dst.len) : (sec_idx += 1) {
        const ptr = sector_ptr(sector + sec_idx);
        var s: usize = 0;
        while (s < SECTOR_SIZE and read < dst.len) : (s += 1) {
            dst[read] = ptr[s];
            read += 1;
        }
    }
}

// ============================================================================
// NodeIdentity – save/load
// ============================================================================

pub fn save_identity(id: *const identity_mod.NodeIdentity) void {
    const data = @as([*]const u8, @ptrCast(id));
    disk_write(SECTOR_IDENTITY, data[0..@sizeOf(identity_mod.NodeIdentity)]);
}

pub fn load_identity(out: *identity_mod.NodeIdentity) bool {
    var buf: [@sizeOf(identity_mod.NodeIdentity)]u8 = undefined;
    disk_read(SECTOR_IDENTITY, &buf);
    const loaded = @as(*const identity_mod.NodeIdentity, @ptrCast(@alignCast(&buf)));
    if (loaded.magic != identity_mod.IDENTITY_MAGIC) return false;
    out.* = loaded.*;
    return true;
}

// ============================================================================
// Vault Header – read/write
// ============================================================================

fn save_vault_header(hdr: *const VaultHeader) void {
    const data = @as([*]const u8, @ptrCast(hdr));
    disk_write(SECTOR_VAULT_HDR, data[0..SECTOR_SIZE]);
}

fn load_vault_header(out: *VaultHeader) bool {
    var buf: [SECTOR_SIZE]u8 = undefined;
    disk_read(SECTOR_VAULT_HDR, &buf);
    const loaded = @as(*const VaultHeader, @ptrCast(&buf));
    if (loaded.magic != 0x564C5441) return false;
    out.* = loaded.*;
    return true;
}

// ============================================================================
// Wallet Slot – save/load (PqWalletSlot)
// ============================================================================

pub fn save_wallet_slot(slot_idx: u8, slot: *const pqc.PqWalletSlot) bool {
    if (slot_idx >= MAX_WALLET_SLOTS) return false;

    const sector = SECTOR_WALLET_0 + @as(u64, slot_idx) * SECTORS_PER_WALLET;
    const data   = @as([*]const u8, @ptrCast(slot));
    const size   = @sizeOf(pqc.PqWalletSlot);
    disk_write(sector, data[0..size]);

    // Actualizează vault header
    var hdr: VaultHeader = undefined;
    _ = load_vault_header(&hdr);
    hdr.magic = 0x564C5441;
    if (slot_idx < 16) {
        hdr.active_slots |= @as(u16, 1) << @as(u4, @intCast(slot_idx));
        hdr.wallet_flags[slot_idx] = slot.algo;
        hdr.slot_count = @popCount(hdr.active_slots);
    }
    save_vault_header(&hdr);

    return true;
}

pub fn load_wallet_slot(slot_idx: u8, out: *pqc.PqWalletSlot) bool {
    if (slot_idx >= MAX_WALLET_SLOTS) return false;

    var hdr: VaultHeader = undefined;
    if (!load_vault_header(&hdr)) return false;
    if (hdr.active_slots & (@as(u16, 1) << @as(u4, @intCast(slot_idx))) == 0) return false;

    const sector = SECTOR_WALLET_0 + @as(u64, slot_idx) * SECTORS_PER_WALLET;
    var buf: [@sizeOf(pqc.PqWalletSlot)]u8 = undefined;
    disk_read(sector, &buf);

    const loaded = @as(*const pqc.PqWalletSlot, @ptrCast(&buf));
    if (!loaded.is_initialized) return false;
    out.* = loaded.*;
    return true;
}

/// Salvează toți 5 sloturi din PqWallet
pub fn save_pq_wallet(pw: *const pqc.PqWallet) void {
    if (pw.magic != 0x4F4D4E49) return;
    for (0..5) |i| {
        if (pw.slots[i].is_initialized) {
            _ = save_wallet_slot(@as(u8, @intCast(i)), &pw.slots[i]);
        }
    }
}

/// Restaurează PqWallet din disc
pub fn load_pq_wallet(pw: *pqc.PqWallet) u8 {
    pw.magic = 0x4F4D4E49;
    pw.cycle = 0;
    var loaded: u8 = 0;
    for (0..5) |i| {
        if (load_wallet_slot(@as(u8, @intCast(i)), &pw.slots[i])) {
            loaded += 1;
        } else {
            pw.slots[i].is_initialized = false;
        }
    }
    return loaded;
}

// ============================================================================
// Block Ring – salvare circulară a blocurilor (ultimele 256)
// ============================================================================

fn get_block_ring_header(out: *BlockRingHeader) bool {
    var buf: [SECTOR_SIZE]u8 = undefined;
    disk_read(SECTOR_BLOCK_HDR, &buf);
    const loaded = @as(*const BlockRingHeader, @ptrCast(@alignCast(&buf)));
    if (loaded.magic != 0x424C4B52) return false;
    out.* = loaded.*;
    return true;
}

fn save_block_ring_header(hdr: *const BlockRingHeader) void {
    const data = @as([*]const u8, @ptrCast(hdr));
    disk_write(SECTOR_BLOCK_HDR, data[0..SECTOR_SIZE]);
}

/// Scrie un bloc (merkle_root + consensus_hash + height) în ring
pub fn save_block(height: u64, merkle_root: *const [32]u8, consensus_hash: *const [32]u8) void {
    var hdr: BlockRingHeader = undefined;
    const ok = get_block_ring_header(&hdr);
    if (!ok) {
        hdr.magic       = 0x424C4B52;
        hdr.ring_size   = MAX_BLOCK_RING;
        hdr.write_head  = 0;
        hdr.total_written = 0;
        hdr.last_height = 0;
        hdr.checksum    = 0;
    }

    // Calculăm sectorul din ring
    const ring_idx = hdr.write_head % MAX_BLOCK_RING;
    const sector   = SECTOR_BLOCK_DATA + @as(u64, ring_idx) * SECTORS_PER_BLOCK;

    // Format bloc pe disc: [height u64][merkle_root 32B][consensus_hash 32B][tsc u64]
    var block_buf: [80]u8 = undefined;
    inline for (0..8) |i| block_buf[i] = @as(u8, @intCast((height >> @as(u6, @intCast((7-i)*8))) & 0xFF));
    @memcpy(block_buf[8..40],  merkle_root);
    @memcpy(block_buf[40..72], consensus_hash);
    const tsc = rdtsc();
    inline for (0..8) |i| block_buf[72+i] = @as(u8, @intCast((tsc >> @as(u6, @intCast((7-i)*8))) & 0xFF));

    disk_write(sector, &block_buf);

    // Actualizează ring header
    hdr.write_head    = @as(u32, @intCast((ring_idx + 1) % MAX_BLOCK_RING));
    hdr.total_written +|= 1;
    hdr.last_height    = height;
    save_block_ring_header(&hdr);
}

/// Citește ultimul bloc salvat
pub fn load_last_block(out_height: *u64, out_merkle: *[32]u8, out_consensus: *[32]u8) bool {
    var hdr: BlockRingHeader = undefined;
    if (!get_block_ring_header(&hdr)) return false;
    if (hdr.total_written == 0) return false;

    const last_idx = (hdr.write_head + MAX_BLOCK_RING - 1) % MAX_BLOCK_RING;
    const sector   = SECTOR_BLOCK_DATA + @as(u64, last_idx) * SECTORS_PER_BLOCK;

    var buf: [80]u8 = undefined;
    disk_read(sector, &buf);

    var height: u64 = 0;
    inline for (0..8) |i| height = (height << 8) | buf[i];
    out_height.* = height;
    @memcpy(out_merkle,    buf[8..40]);
    @memcpy(out_consensus, buf[40..72]);
    return true;
}

// ============================================================================
// Statistici
// ============================================================================

pub fn get_vault_stats() struct {
    wallet_slots : u8,
    active_slots : u16,
    blocks_stored: u64,
    last_height  : u64,
} {
    var hdr: VaultHeader     = undefined;
    var bhr: BlockRingHeader = undefined;
    _ = load_vault_header(&hdr);
    _ = get_block_ring_header(&bhr);

    return .{
        .wallet_slots  = if (hdr.magic == 0x564C5441) hdr.slot_count else 0,
        .active_slots  = if (hdr.magic == 0x564C5441) hdr.active_slots else 0,
        .blocks_stored = if (bhr.magic == 0x424C4B52) bhr.total_written else 0,
        .last_height   = if (bhr.magic == 0x424C4B52) bhr.last_height else 0,
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
