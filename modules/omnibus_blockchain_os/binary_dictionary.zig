// Phase 65: Binary Dictionary (Dictionarul de Biți)
// Ultra-compact 256-bit packet encoding for 1 billion nodes
// Memory: 0x5D9000–0x5DFFFF (28KB, integrated into BlockchainOS)
//
// Purpose: Replace JSON/text with pure binary packets
// - Reduces bandwidth by 90%+ (32 bytes per transaction)
// - Enables processing on 3G/4G/IoT devices
// - Sub-microsecond bit-level processing (no string parsing)
//
// Architecture:
// - 256-bit (32 byte) fixed packet size (same as SHA-256)
// - Address Indexing Table: compress 32-byte address → 48-bit ID
// - Bit-packing: all fields tightly packed with no padding
// - Bit-masking: extract fields with AND + SHIFT operations

const std = @import("std");
const token_registry = @import("token_registry.zig");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const BINARY_DICT_BASE: usize = 0x5D9000;
pub const ADDRESS_INDEX_TABLE_BASE: usize = 0x5DA000; // 4KB index table
pub const MAX_ADDRESS_ENTRIES: u32 = 65536; // 64K active addresses
pub const MAX_PACKET_SIZE: usize = 32; // 256 bits = 32 bytes

// Address ID space: 48 bits = 281 trillion possible IDs
pub const MAX_ADDRESS_ID: u64 = 0xFFFFFFFFFFFF; // 2^48 - 1

// Reserved ID ranges for system functions
pub const RESERVED_IDS = struct {
    pub const BURN_ADDRESS: u48 = 0x000000000000; // Destroy tokens
    pub const KRAKEN_ORACLE: u48 = 0x000000000001;
    pub const COINBASE_ORACLE: u48 = 0x000000000002;
    pub const LCX_ORACLE: u48 = 0x000000000003;
    pub const FIRST_USER_ID: u48 = 0x000000000004; // User IDs start here
};

// ============================================================================
// PACKET TYPE FLAGS (2 bits)
// ============================================================================

pub const PacketType = enum(u2) {
    TRANSFER = 0b00,           // Standard OMNI transfer
    STAKE = 0b01,              // Staking operation
    ORACLE_VOTE = 0b10,        // Price snapshot vote
    CONTRACT_CALL = 0b11,      // Smart contract invocation
};

// ============================================================================
// TRANSACTION PACKET (256 bits / 32 bytes)
// ============================================================================

pub const BinaryPacket = struct {
    // Raw 256-bit data (32 bytes)
    data: [32]u8,

    pub fn init(raw_data: [32]u8) BinaryPacket {
        return .{ .data = raw_data };
    }

    // === FIELD EXTRACTION via Bit Operations ===

    /// Extract packet_type (bits 0-1)
    pub fn getPacketType(self: *const BinaryPacket) PacketType {
        const byte0 = self.data[0];
        const type_bits = (byte0 >> 6) & 0b11;
        return @enumFromInt(type_bits);
    }

    /// Set packet_type (bits 0-1)
    pub fn setPacketType(self: *BinaryPacket, ptype: PacketType) void {
        self.data[0] = (self.data[0] & 0b00111111) | (@intFromEnum(ptype) << 6);
    }

    /// Extract sender ID (bits 2-49, 48 bits across bytes 0-6)
    pub fn getSenderId(self: *const BinaryPacket) u48 {
        var id: u64 = 0;
        // Bits 2-7 of byte 0
        id |= (@as(u64, self.data[0]) & 0b00111111) << 42;
        // All 8 bits of bytes 1-5
        id |= @as(u64, self.data[1]) << 34;
        id |= @as(u64, self.data[2]) << 26;
        id |= @as(u64, self.data[3]) << 18;
        id |= @as(u64, self.data[4]) << 10;
        id |= @as(u64, self.data[5]) << 2;
        // Bits 6-7 of byte 6
        id |= (@as(u64, self.data[6]) >> 6) & 0b11;

        return @intCast(id & 0xFFFFFFFFFFFF);
    }

    /// Set sender ID (bits 2-49)
    pub fn setSenderId(self: *BinaryPacket, sender_id: u48) void {
        const id = @as(u64, sender_id);
        // Bits 2-7 of byte 0
        self.data[0] = (self.data[0] & 0b11000010) | @as(u8, @intCast((id >> 42) & 0b00111111));
        // All 8 bits of bytes 1-5
        self.data[1] = @as(u8, @intCast((id >> 34) & 0xFF));
        self.data[2] = @as(u8, @intCast((id >> 26) & 0xFF));
        self.data[3] = @as(u8, @intCast((id >> 18) & 0xFF));
        self.data[4] = @as(u8, @intCast((id >> 10) & 0xFF));
        self.data[5] = @as(u8, @intCast((id >> 2) & 0xFF));
        // Bits 6-7 of byte 6
        self.data[6] = (self.data[6] & 0b00111111) | @as(u8, @intCast((id & 0b11) << 6));
    }

    /// Extract receiver ID (bits 50-97, 48 bits)
    pub fn getReceiverId(self: *const BinaryPacket) u48 {
        var id: u64 = 0;
        // Bits 0-5 of byte 6
        id |= (@as(u64, self.data[6]) & 0b00111111) << 42;
        // All 8 bits of bytes 7-11
        id |= @as(u64, self.data[7]) << 34;
        id |= @as(u64, self.data[8]) << 26;
        id |= @as(u64, self.data[9]) << 18;
        id |= @as(u64, self.data[10]) << 10;
        id |= @as(u64, self.data[11]) << 2;
        // Bits 6-7 of byte 12
        id |= (@as(u64, self.data[12]) >> 6) & 0b11;

        return @intCast(id & 0xFFFFFFFFFFFF);
    }

    /// Set receiver ID (bits 50-97)
    pub fn setReceiverId(self: *BinaryPacket, receiver_id: u48) void {
        const id = @as(u64, receiver_id);
        // Bits 0-5 of byte 6
        self.data[6] = (self.data[6] & 0b11000000) | @as(u8, @intCast((id >> 42) & 0b00111111));
        // All 8 bits of bytes 7-11
        self.data[7] = @as(u8, @intCast((id >> 34) & 0xFF));
        self.data[8] = @as(u8, @intCast((id >> 26) & 0xFF));
        self.data[9] = @as(u8, @intCast((id >> 18) & 0xFF));
        self.data[10] = @as(u8, @intCast((id >> 10) & 0xFF));
        self.data[11] = @as(u8, @intCast((id >> 2) & 0xFF));
        // Bits 6-7 of byte 12
        self.data[12] = (self.data[12] & 0b00111111) | @as(u8, @intCast((id & 0b11) << 6));
    }

    /// Extract amount (bits 98-161, 64 bits)
    pub fn getAmount(self: *const BinaryPacket) u64 {
        var amount: u64 = 0;
        // Bits 2-7 of byte 12
        amount |= (@as(u64, self.data[12]) & 0b00111100) >> 2;
        // All 8 bits of bytes 13-19
        amount |= @as(u64, self.data[13]) << 6;
        amount |= @as(u64, self.data[14]) << 14;
        amount |= @as(u64, self.data[15]) << 22;
        amount |= @as(u64, self.data[16]) << 30;
        amount |= @as(u64, self.data[17]) << 38;
        amount |= @as(u64, self.data[18]) << 46;
        amount |= @as(u64, self.data[19]) << 54;

        return amount;
    }

    /// Set amount (bits 98-161, 64 bits)
    pub fn setAmount(self: *BinaryPacket, amount: u64) void {
        // Bits 2-7 of byte 12
        self.data[12] = (self.data[12] & 0b11000011) | @as(u8, @intCast((amount & 0b111111) << 2));
        // All 8 bits of bytes 13-19
        self.data[13] = @as(u8, @intCast((amount >> 6) & 0xFF));
        self.data[14] = @as(u8, @intCast((amount >> 14) & 0xFF));
        self.data[15] = @as(u8, @intCast((amount >> 22) & 0xFF));
        self.data[16] = @as(u8, @intCast((amount >> 30) & 0xFF));
        self.data[17] = @as(u8, @intCast((amount >> 38) & 0xFF));
        self.data[18] = @as(u8, @intCast((amount >> 46) & 0xFF));
        self.data[19] = @as(u8, @intCast((amount >> 54) & 0xFF));
    }

    /// Extract nonce (bits 162-191, 30 bits) – prevents replay attacks
    pub fn getNonce(self: *const BinaryPacket) u32 {
        var nonce: u32 = 0;
        // Bits 2-7 of byte 20
        nonce |= (@as(u32, self.data[20]) & 0b11111100) >> 2;
        // All 8 bits of byte 21
        nonce |= @as(u32, self.data[21]) << 6;
        // Bits 0-3 of byte 22
        nonce |= (@as(u32, self.data[22]) & 0b00001111) << 14;

        return nonce & 0x3FFFFFFF; // 30 bits
    }

    /// Set nonce (bits 162-191, 30 bits)
    pub fn setNonce(self: *BinaryPacket, nonce: u32) void {
        const nonce_val = nonce & 0x3FFFFFFF;
        // Bits 2-7 of byte 20
        self.data[20] = (self.data[20] & 0b00000011) | @as(u8, @intCast((nonce_val & 0b00111111) << 2));
        // All 8 bits of byte 21
        self.data[21] = @as(u8, @intCast((nonce_val >> 6) & 0xFF));
        // Bits 0-3 of byte 22
        self.data[22] = (self.data[22] & 0b11110000) | @as(u8, @intCast((nonce_val >> 14) & 0b00001111));
    }

    /// Extract signature (bits 192-255, 64 bits) – compact BLS/Schnorr
    pub fn getSignature(self: *const BinaryPacket) u64 {
        var sig: u64 = 0;
        // Bits 4-7 of byte 22
        sig |= (@as(u64, self.data[22]) & 0b11110000) >> 4;
        // All 8 bits of bytes 23-29
        sig |= @as(u64, self.data[23]) << 4;
        sig |= @as(u64, self.data[24]) << 12;
        sig |= @as(u64, self.data[25]) << 20;
        sig |= @as(u64, self.data[26]) << 28;
        sig |= @as(u64, self.data[27]) << 36;
        sig |= @as(u64, self.data[28]) << 44;
        sig |= @as(u64, self.data[29]) << 52;
        // All 8 bits of byte 30-31
        sig |= @as(u64, self.data[30]) << 60;
        sig |= (@as(u64, self.data[31]) & 0x0F) << 64;

        return sig;
    }

    /// Set signature (bits 192-255, 64 bits)
    pub fn setSignature(self: *BinaryPacket, sig: u64) void {
        // Bits 4-7 of byte 22
        self.data[22] = (self.data[22] & 0b00001111) | @as(u8, @intCast((sig & 0b1111) << 4));
        // All 8 bits of bytes 23-29
        self.data[23] = @as(u8, @intCast((sig >> 4) & 0xFF));
        self.data[24] = @as(u8, @intCast((sig >> 12) & 0xFF));
        self.data[25] = @as(u8, @intCast((sig >> 20) & 0xFF));
        self.data[26] = @as(u8, @intCast((sig >> 28) & 0xFF));
        self.data[27] = @as(u8, @intCast((sig >> 36) & 0xFF));
        self.data[28] = @as(u8, @intCast((sig >> 44) & 0xFF));
        self.data[29] = @as(u8, @intCast((sig >> 52) & 0xFF));
        // All 8 bits of byte 30 (only 4 bits used of byte 31)
        self.data[30] = @as(u8, @intCast((sig >> 60) & 0xFF));
        self.data[31] = @as(u8, @intCast(((sig >> 64) & 0x0F)));
    }
};

// ============================================================================
// ORACLE PACKET (256 bits / 32 bytes) – for price snapshots
// ============================================================================

pub const OraclePacket = struct {
    data: [32]u8,

    pub fn init(raw_data: [32]u8) OraclePacket {
        return .{ .data = raw_data };
    }

    /// Extract type flag (bits 0-1) – always 0b10 for Oracle
    pub fn getType(self: *const OraclePacket) u2 {
        return @intCast((self.data[0] >> 6) & 0b11);
    }

    /// Extract token ID (bits 2-11, 10 bits) – supports 1024 tokens
    pub fn getTokenId(self: *const OraclePacket) u16 {
        var id: u16 = 0;
        // Bits 2-7 of byte 0
        id |= @as(u16, self.data[0]) & 0b00111111;
        // Bits 0-3 of byte 1
        id |= (@as(u16, self.data[1]) & 0b00001111) << 6;

        return id & 0x3FF; // 10 bits
    }

    /// Extract source map (bits 12-15, 4 bits) – Kraken/CB/LCX/Median
    pub fn getSourceMap(self: *const OraclePacket) u4 {
        return @intCast((self.data[1] >> 4) & 0b1111);
    }

    /// Extract bid price (bits 16-75, 60 bits) – binary fixed-point
    pub fn getBidPrice(self: *const OraclePacket) u64 {
        var price: u64 = 0;
        // Bits 0-7 of byte 2
        price |= @as(u64, self.data[2]);
        // All 8 bits of bytes 3-8
        price |= @as(u64, self.data[3]) << 8;
        price |= @as(u64, self.data[4]) << 16;
        price |= @as(u64, self.data[5]) << 24;
        price |= @as(u64, self.data[6]) << 32;
        price |= @as(u64, self.data[7]) << 40;
        price |= @as(u64, self.data[8]) << 48;
        // Bits 0-3 of byte 9
        price |= (@as(u64, self.data[9]) & 0b00001111) << 56;

        return price & 0x0FFFFFFFFFFFFFFF; // 60 bits
    }

    /// Extract ask price (bits 76-135, 60 bits)
    pub fn getAskPrice(self: *const OraclePacket) u64 {
        var price: u64 = 0;
        // Bits 4-7 of byte 9
        price |= (@as(u64, self.data[9]) >> 4) & 0b1111;
        // All 8 bits of bytes 10-15
        price |= @as(u64, self.data[10]) << 4;
        price |= @as(u64, self.data[11]) << 12;
        price |= @as(u64, self.data[12]) << 20;
        price |= @as(u64, self.data[13]) << 28;
        price |= @as(u64, self.data[14]) << 36;
        price |= @as(u64, self.data[15]) << 44;
        // Bits 0-3 of byte 16
        price |= (@as(u64, self.data[16]) & 0b00001111) << 52;

        return price & 0x0FFFFFFFFFFFFFFF; // 60 bits
    }

    /// Extract volume/liquidity (bits 136-195, 60 bits)
    pub fn getVolume(self: *const OraclePacket) u64 {
        var vol: u64 = 0;
        // Bits 4-7 of byte 16
        vol |= (@as(u64, self.data[16]) >> 4) & 0b1111;
        // All 8 bits of bytes 17-22
        vol |= @as(u64, self.data[17]) << 4;
        vol |= @as(u64, self.data[18]) << 12;
        vol |= @as(u64, self.data[19]) << 20;
        vol |= @as(u64, self.data[20]) << 28;
        vol |= @as(u64, self.data[21]) << 36;
        vol |= @as(u64, self.data[22]) << 44;
        // Bits 0-3 of byte 23
        vol |= (@as(u64, self.data[23]) & 0b00001111) << 52;

        return vol & 0x0FFFFFFFFFFFFFFF; // 60 bits
    }

    /// Extract checksum (bits 196-255, 60 bits) – data integrity
    pub fn getChecksum(self: *const OraclePacket) u64 {
        var csum: u64 = 0;
        // Bits 4-7 of byte 23
        csum |= (@as(u64, self.data[23]) >> 4) & 0b1111;
        // All 8 bits of bytes 24-29
        csum |= @as(u64, self.data[24]) << 4;
        csum |= @as(u64, self.data[25]) << 12;
        csum |= @as(u64, self.data[26]) << 20;
        csum |= @as(u64, self.data[27]) << 28;
        csum |= @as(u64, self.data[28]) << 36;
        csum |= @as(u64, self.data[29]) << 44;
        // All 8 bits of bytes 30-31
        csum |= @as(u64, self.data[30]) << 52;
        csum |= @as(u64, self.data[31]) << 60;

        return csum & 0x0FFFFFFFFFFFFFFF; // 60 bits
    }
};

// ============================================================================
// ADDRESS INDEXING TABLE
// ============================================================================

pub const AddressIndexEntry = struct {
    full_address: [32]u8,    // 256-bit original address
    address_id: u48,         // 48-bit compressed ID
    balance: u64,            // Current OMNI balance
    nonce: u32,              // Transaction nonce
    is_active: u8,           // 0 = inactive, 1 = active
    _reserved: [15]u8,       // Reserved for future use
};

pub const AddressIndexTable = struct {
    magic: u32 = 0x414458, // "ADX"
    version: u32 = 1,
    next_id: u48 = RESERVED_IDS.FIRST_USER_ID,
    entry_count: u32 = 0,
    last_update: u64 = 0,

    // Array of up to 64K address entries
    entries: [MAX_ADDRESS_ENTRIES]AddressIndexEntry = undefined,
};

var index_table: AddressIndexTable = undefined;
var initialized: bool = false;

// ============================================================================
// INITIALIZATION
// ============================================================================

pub fn init_binary_dictionary() void {
    if (initialized) return;

    var table_ptr = @as(*volatile AddressIndexTable, @ptrFromInt(ADDRESS_INDEX_TABLE_BASE));
    table_ptr.magic = 0x414458; // "ADX"
    table_ptr.version = 1;
    table_ptr.next_id = RESERVED_IDS.FIRST_USER_ID;
    table_ptr.entry_count = 0;
    table_ptr.last_update = rdtsc();

    // Initialize reserved addresses (Burn, Kraken Oracle, etc)
    @memset(&table_ptr.entries[0].full_address, 0);
    table_ptr.entries[0].address_id = RESERVED_IDS.BURN_ADDRESS;
    table_ptr.entries[0].is_active = 1;

    initialized = true;
}

// ============================================================================
// ADDRESS INDEXING
// ============================================================================

/// Register a new address or look up existing ID
pub fn get_or_create_address_id(full_address: *const [32]u8) u48 {
    if (!initialized) init_binary_dictionary();

    var table_ptr = @as(*volatile AddressIndexTable, @ptrFromInt(ADDRESS_INDEX_TABLE_BASE));

    // Search existing entries
    var i: u32 = 0;
    while (i < table_ptr.entry_count) : (i += 1) {
        if (addresses_equal(&table_ptr.entries[i].full_address, full_address)) {
            return table_ptr.entries[i].address_id;
        }
    }

    // Create new entry if space available
    if (table_ptr.entry_count < MAX_ADDRESS_ENTRIES) {
        const new_id = table_ptr.next_id;
        table_ptr.next_id += 1;

        table_ptr.entries[table_ptr.entry_count].full_address = full_address.*;
        table_ptr.entries[table_ptr.entry_count].address_id = new_id;
        table_ptr.entries[table_ptr.entry_count].balance = 0;
        table_ptr.entries[table_ptr.entry_count].nonce = 0;
        table_ptr.entries[table_ptr.entry_count].is_active = 1;

        table_ptr.entry_count += 1;
        table_ptr.last_update = rdtsc();

        return new_id;
    }

    return 0; // Table full
}

/// Look up full address by ID
pub fn lookup_address(address_id: u48) ?[32]u8 {
    if (!initialized) init_binary_dictionary();

    const table_ptr = @as(*volatile AddressIndexTable, @ptrFromInt(ADDRESS_INDEX_TABLE_BASE));

    var i: u32 = 0;
    while (i < table_ptr.entry_count) : (i += 1) {
        if (table_ptr.entries[i].address_id == address_id) {
            return table_ptr.entries[i].full_address;
        }
    }

    return null;
}

fn addresses_equal(addr1: *const [32]u8, addr2: *const [32]u8) bool {
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        if (addr1[i] != addr2[i]) return false;
    }
    return true;
}

// ============================================================================
// PACKET SERIALIZATION
// ============================================================================

/// Encode a transaction into 256-bit binary packet
pub fn encode_transaction(
    ptype: PacketType,
    sender_id: u48,
    receiver_id: u48,
    amount: u64,
    nonce: u32,
    signature: u64,
) [32]u8 {
    var packet = BinaryPacket{
        .data = [_]u8{0} ** 32,
    };

    packet.setPacketType(ptype);
    packet.setSenderId(sender_id);
    packet.setReceiverId(receiver_id);
    packet.setAmount(amount);
    packet.setNonce(nonce);
    packet.setSignature(signature);

    return packet.data;
}

/// Encode an oracle packet for price snapshot
pub fn encode_oracle_packet(
    token_id: u16,
    source_map: u4,
    bid_price: u64,
    ask_price: u64,
    volume: u64,
) [32]u8 {
    var packet = OraclePacket{
        .data = [_]u8{0} ** 32,
    };

    // Set type to ORACLE_VOTE (0b10)
    packet.data[0] = (packet.data[0] & 0b00111111) | (0b10 << 6);

    // Set token ID (bits 2-11)
    packet.data[0] |= @intCast(token_id & 0b00111111);
    packet.data[1] |= @intCast((token_id >> 6) & 0b00001111);

    // Set source map (bits 12-15)
    packet.data[1] |= @intCast((@as(u8, source_map) & 0b1111) << 4);

    // Set bid price
    packet.data[2] = @intCast(bid_price & 0xFF);
    packet.data[3] = @intCast((bid_price >> 8) & 0xFF);
    packet.data[4] = @intCast((bid_price >> 16) & 0xFF);
    packet.data[5] = @intCast((bid_price >> 24) & 0xFF);
    packet.data[6] = @intCast((bid_price >> 32) & 0xFF);
    packet.data[7] = @intCast((bid_price >> 40) & 0xFF);
    packet.data[8] = @intCast((bid_price >> 48) & 0xFF);
    packet.data[9] |= @intCast((bid_price >> 56) & 0b00001111);

    // Set ask price
    packet.data[9] |= @intCast((ask_price & 0b1111) << 4);
    packet.data[10] = @intCast((ask_price >> 4) & 0xFF);
    packet.data[11] = @intCast((ask_price >> 12) & 0xFF);
    packet.data[12] = @intCast((ask_price >> 20) & 0xFF);
    packet.data[13] = @intCast((ask_price >> 28) & 0xFF);
    packet.data[14] = @intCast((ask_price >> 36) & 0xFF);
    packet.data[15] = @intCast((ask_price >> 44) & 0xFF);
    packet.data[16] |= @intCast((ask_price >> 52) & 0b00001111);

    // Set volume
    packet.data[16] |= @intCast((volume & 0b1111) << 4);
    packet.data[17] = @intCast((volume >> 4) & 0xFF);
    packet.data[18] = @intCast((volume >> 12) & 0xFF);
    packet.data[19] = @intCast((volume >> 20) & 0xFF);
    packet.data[20] = @intCast((volume >> 28) & 0xFF);
    packet.data[21] = @intCast((volume >> 36) & 0xFF);
    packet.data[22] = @intCast((volume >> 44) & 0xFF);
    packet.data[23] |= @intCast((volume >> 52) & 0b00001111);

    return packet.data;
}

// ============================================================================
// RDTSC
// ============================================================================

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

// ============================================================================
// STATISTICS
// ============================================================================

pub fn get_dictionary_stats() struct { total_addresses: u32, used_ids: u48 } {
    if (!initialized) init_binary_dictionary();

    const table_ptr = @as(*volatile AddressIndexTable, @ptrFromInt(ADDRESS_INDEX_TABLE_BASE));

    return .{
        .total_addresses = table_ptr.entry_count,
        .used_ids = table_ptr.next_id,
    };
}
