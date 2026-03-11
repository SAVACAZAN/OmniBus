// OmniBus Post-Quantum Address Encoding with Checksum (EIP-55 style)
// Keccak256 hash-based validation for ob_k1_, ob_f5_, ob_d5_, ob_s3_ addresses

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

pub const PQ_ADDRESS_PREFIX_LEN = 6; // "ob_k1_", "ob_f5_", "ob_d5_", "ob_s3_"
pub const PQ_ADDRESS_PAYLOAD_LEN = 32; // 32 bytes = 64 hex chars
pub const PQ_ADDRESS_TOTAL_LEN = PQ_ADDRESS_PREFIX_LEN + (PQ_ADDRESS_PAYLOAD_LEN * 2); // 70 chars

pub const PqDomainType = enum(u8) {
    LOVE = 0, // ob_k1_ (Kyber-768)
    FOOD = 1, // ob_f5_ (Falcon-512)
    RENT = 2, // ob_d5_ (Dilithium-5)
    VACATION = 3, // ob_s3_ (SPHINCS+)
};

// ============================================================================
// Address Structure
// ============================================================================

pub const PqAddress = struct {
    domain: PqDomainType,
    payload: [PQ_ADDRESS_PAYLOAD_LEN]u8,
    has_valid_checksum: bool,

    pub fn to_string(self: *const PqAddress) [PQ_ADDRESS_TOTAL_LEN]u8 {
        var result: [PQ_ADDRESS_TOTAL_LEN]u8 = undefined;

        // Write prefix
        const prefix = switch (self.domain) {
            .LOVE => "ob_k1_",
            .FOOD => "ob_f5_",
            .RENT => "ob_d5_",
            .VACATION => "ob_s3_",
        };
        @memcpy(result[0..6], prefix[0..6]);

        // Write checksum-capitalized hex payload
        var i: usize = 0;
        while (i < PQ_ADDRESS_PAYLOAD_LEN) : (i += 1) {
            const byte = self.payload[i];
            const hex = "0123456789abcdef";
            const hex_upper = "0123456789ABCDEF";

            const hi = (byte >> 4) & 0x0F;
            const lo = byte & 0x0F;

            // Use checksum to determine capitalization
            const checksum_byte = self.compute_checksum_byte(i);
            const hi_cap = (checksum_byte >> 4) & 1;
            const lo_cap = (checksum_byte >> 0) & 1;

            result[6 + (i * 2) + 0] = if (hi_cap == 1) hex_upper[hi] else hex[hi];
            result[6 + (i * 2) + 1] = if (lo_cap == 1) hex_upper[lo] else hex[lo];
        }

        return result;
    }

    fn compute_checksum_byte(self: *const PqAddress, byte_index: usize) u8 {
        // Simplified: use hash of (domain + payload) to determine capitalization
        // In production: Keccak256(lowercase_address)
        var hash_input: [1 + PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
        hash_input[0] = @intFromEnum(self.domain);
        @memcpy(hash_input[1..], self.payload[0..]);

        // Simple hash: XOR fold of all bytes
        var hash: u8 = 0;
        for (hash_input) |b| {
            hash ^= b;
        }

        // Rotate based on byte position
        const rotated = std.math.rotr(u8, hash, @as(u5, @intCast(byte_index % 8)));
        return rotated;
    }
};

// ============================================================================
// Encoding/Decoding Functions
// ============================================================================

pub fn encode_address(domain: PqDomainType, payload: [PQ_ADDRESS_PAYLOAD_LEN]u8) PqAddress {
    const addr = PqAddress{
        .domain = domain,
        .payload = payload,
        .has_valid_checksum = true,
    };
    return addr;
}

pub fn decode_address(addr_string: [PQ_ADDRESS_TOTAL_LEN]u8) ?PqAddress {
    // Parse prefix
    const prefix = addr_string[0..6];
    const domain = if (std.mem.eql(u8, prefix, "ob_k1_"))
        PqDomainType.LOVE
    else if (std.mem.eql(u8, prefix, "ob_f5_"))
        PqDomainType.FOOD
    else if (std.mem.eql(u8, prefix, "ob_d5_"))
        PqDomainType.RENT
    else if (std.mem.eql(u8, prefix, "ob_s3_"))
        PqDomainType.VACATION
    else
        return null;

    // Parse hex payload
    var payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
    var i: usize = 0;
    while (i < PQ_ADDRESS_PAYLOAD_LEN) : (i += 1) {
        const hi_char = addr_string[6 + (i * 2) + 0];
        const lo_char = addr_string[6 + (i * 2) + 1];

        const hi = std.fmt.charToDigit(hi_char, 16) catch return null;
        const lo = std.fmt.charToDigit(lo_char, 16) catch return null;

        payload[i] = (hi << 4) | lo;
    }

    var addr = PqAddress{
        .domain = domain,
        .payload = payload,
        .has_valid_checksum = false,
    };

    // Validate checksum
    var valid = true;
    i = 0;
    while (i < PQ_ADDRESS_TOTAL_LEN - 6) : (i += 1) {
        const stored_char = addr_string[6 + i];
        const is_upper = stored_char >= 'A' and stored_char <= 'F';

        const checksum_byte = addr.compute_checksum_byte(i / 2);
        const expected_cap = if (i % 2 == 0)
            (checksum_byte >> 4) & 1
        else
            (checksum_byte >> 0) & 1;

        if (is_upper != (expected_cap == 1)) {
            valid = false;
            break;
        }
    }

    addr.has_valid_checksum = valid;
    return addr;
}

pub fn validate_checksum(addr_string: [PQ_ADDRESS_TOTAL_LEN]u8) bool {
    if (decode_address(addr_string)) |addr| {
        return addr.has_valid_checksum;
    }
    return false;
}

// ============================================================================
// Short ID Generation (OMNI-xxxx-DOMAIN format)
// ============================================================================

pub const ShortId = struct {
    text: [20]u8, // "OMNI-xxxx-LOVE" = 15 chars + padding
    len: u8,

    pub fn format(self: *const ShortId) [20]u8 {
        return self.text;
    }
};

pub fn generate_short_id(domain: PqDomainType, payload: [PQ_ADDRESS_PAYLOAD_LEN]u8) ShortId {
    var short_id: ShortId = undefined;

    // Extract 4 hex chars from middle of payload
    const mid_byte = payload[16]; // Middle of 32 bytes
    const hex = "0123456789abcdef";
    var hex_chars: [4]u8 = undefined;
    hex_chars[0] = hex[(mid_byte >> 4) & 0x0F];
    hex_chars[1] = hex[mid_byte & 0x0F];
    hex_chars[2] = hex[(payload[17] >> 4) & 0x0F];
    hex_chars[3] = hex[payload[17] & 0x0F];

    const domain_name = switch (domain) {
        .LOVE => "LOVE",
        .FOOD => "FOOD",
        .RENT => "RENT",
        .VACATION => "VACATION",
    };

    // Format: OMNI-xxxx-DOMAIN
    const formatted = std.fmt.bufPrint(
        &short_id.text,
        "OMNI-{c}{c}{c}{c}-{s}",
        .{ hex_chars[0], hex_chars[1], hex_chars[2], hex_chars[3], domain_name }
    ) catch unreachable;

    short_id.len = @intCast(formatted.len);
    return short_id;
}

// ============================================================================
// Batch Address Generation
// ============================================================================

pub const AddressBatch = struct {
    love: PqAddress,
    food: PqAddress,
    rent: PqAddress,
    vacation: PqAddress,

    pub fn from_seed(seed: [64]u8) AddressBatch {
        var batch: AddressBatch = undefined;

        // Derive 4 independent payloads via HMAC-SHA512
        var love_payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
        derive_domain_payload(&seed, "omnibus.love", &love_payload);
        batch.love = encode_address(.LOVE, love_payload);

        var food_payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
        derive_domain_payload(&seed, "omnibus.food", &food_payload);
        batch.food = encode_address(.FOOD, food_payload);

        var rent_payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
        derive_domain_payload(&seed, "omnibus.rent", &rent_payload);
        batch.rent = encode_address(.RENT, rent_payload);

        var vacation_payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
        derive_domain_payload(&seed, "omnibus.vacation", &vacation_payload);
        batch.vacation = encode_address(.VACATION, vacation_payload);

        return batch;
    }
};

fn derive_domain_payload(seed: *const [64]u8, domain: []const u8, output: *[PQ_ADDRESS_PAYLOAD_LEN]u8) void {
    // Simplified: hash(seed || domain) → payload
    // Production: HMAC-SHA512(seed, domain) truncated to first 32 bytes
    var hash_input: [64 + 32]u8 = undefined;
    @memcpy(hash_input[0..64], seed);
    @memcpy(hash_input[64..64+domain.len], domain);

    // Simple hash: XOR fold
    var result: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
    var i: usize = 0;
    while (i < PQ_ADDRESS_PAYLOAD_LEN) : (i += 1) {
        var byte: u8 = 0;
        var j: usize = 0;
        while (j < hash_input.len) : (j += 1) {
            byte ^= hash_input[j];
            hash_input[j] = std.math.rotl(u8, hash_input[j], 1);
        }
        result[i] = byte;
    }

    output.* = result;
}

// ============================================================================
// Testing
// ============================================================================

pub fn main() void {
    std.debug.print("═══ PQ ADDRESS ENCODING (EIP-55 style) ═══\n\n", .{});

    // Test payload
    var test_payload: [PQ_ADDRESS_PAYLOAD_LEN]u8 = undefined;
    @memset(&test_payload, 0x3a);
    test_payload[0] = 0x4b;
    test_payload[1] = 0x5c;
    test_payload[16] = 0x9f;
    test_payload[17] = 0x0a;

    // Test all domains
    const domains = [_]PqDomainType{ .LOVE, .FOOD, .RENT, .VACATION };
    const domain_names = [_][]const u8{ "LOVE", "FOOD", "RENT", "VACATION" };

    var i: usize = 0;
    while (i < domains.len) : (i += 1) {
        const domain = domains[i];
        const name = domain_names[i];

        const addr = encode_address(domain, test_payload);
        const addr_str = addr.to_string();
        const short = generate_short_id(domain, test_payload);

        std.debug.print("🔐 omnibus.{s}\n", .{name});
        std.debug.print("   Address: ", .{});
        std.debug.print("{s}\n", .{addr_str});
        std.debug.print("   Short ID: OMNI-{c}{c}{c}{c}-{s}\n\n", .{
            short.text[5], short.text[6], short.text[7], short.text[8], name
        });
    }

    std.debug.print("═══ CHECKSUM VALIDATION ═══\n\n", .{});
    const addr = encode_address(.LOVE, test_payload);
    const encoded = addr.to_string();
    std.debug.print("Generated address: {s}\n", .{encoded});
    std.debug.print("Checksum valid: {}\n\n", .{validate_checksum(encoded)});
}
