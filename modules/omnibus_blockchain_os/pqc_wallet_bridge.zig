// pqc_wallet_bridge.zig – OmniBus PQC-Wallet Integration Bridge
// Connects omnibus_wallet.zig (HD key management) ↔ pqc_gate_os (NIST PQ signing)
//
// IPC memory layout (shared with pqc_gate_os / Mother OS):
//   0x100110  IPC request  (u8)  – opcode sent to PQC gate
//   0x100111  IPC status   (u8)  – 0x00=idle, 0x01=busy, 0x02=done, 0x03=error
//   0x100120  IPC result   (u64) – input param / output result
//   0x100200  Signature buffer   – PQC gate writes signature here (up to 8KB)
//   0x100300  Pubkey buffer      – PQC gate writes public key here (up to 4KB)
//   0x100400  TX hash input      – bridge writes 32-byte hash here before sign
//   0x100440  Verify input       – bridge writes [hash|sig|pubkey] for verify

const wallet = @import("omnibus_wallet.zig");

// ============================================================================
// IPC Opcodes (must match pqc_gate_os.zig ipc_dispatch switch)
// ============================================================================

const IPC_PQC_SIGN_TX   : u8 = 0x41;
const IPC_PQC_VERIFY_TX : u8 = 0x42;
const IPC_PQC_KEYGEN    : u8 = 0x43;
const IPC_PQC_ALGO_INFO : u8 = 0x44;

const IPC_STATUS_IDLE  : u8 = 0x00;
const IPC_STATUS_DONE  : u8 = 0x02;
const IPC_STATUS_ERROR : u8 = 0x03;

// ============================================================================
// PQC Algorithm IDs (must match pqc_types.zig PQC_ALGO)
// ============================================================================

pub const PqAlgo = enum(u8) {
    ML_DSA_44           = 0,   // Dilithium standard     – 2420 byte sig
    ML_DSA_65           = 1,   // Dilithium high-sec     – 3293 byte sig  ← OMNI/LOVE
    ML_DSA_87           = 2,   // Dilithium paranoid     – 4595 byte sig  ← RENT
    SLH_DSA_SHA2_128S   = 3,   // SPHINCS+ compact       – 7856 byte sig  ← VACATION
    SLH_DSA_SHA2_256F   = 4,   // SPHINCS+ fast
    FN_DSA_512          = 5,   // Falcon compact         –  897 byte sig  ← FOOD
    FN_DSA_1024         = 6,   // Falcon full            – 1793 byte sig
};

// Native address prefixes (must match pq_dual_address_generator.zig)
const PREFIX_DILITHIUM : []const u8 = "ob_d5_";
const PREFIX_FALCON    : []const u8 = "ob_f5_";
const PREFIX_SPHINCS   : []const u8 = "ob_s3_";
const PREFIX_KYBER     : []const u8 = "ob_k1_";   // OMNI/LOVE use ML-KEM prefix

// Max sizes
pub const MAX_SIG_SIZE    : u32 = 8192;
pub const MAX_PUBKEY_SIZE : u32 = 4096;

// ============================================================================
// Data structures
// ============================================================================

/// A PQ-signed transaction blob (stored in mempool / block)
pub const PqSignedTx = extern struct {
    tx_hash   : [32]u8,
    domain    : u8,              // DomainType ordinal
    algo      : u8,              // PqAlgo ordinal
    _pad      : [2]u8 = .{0,0},
    sig_len   : u32,
    signature : [MAX_SIG_SIZE]u8,
    pubkey_hash : [32]u8,        // SHA-256(pubkey) – used as address fingerprint
};

/// Per-domain PQ wallet slot (fixed memory, bare-metal safe)
pub const PqWalletSlot = extern struct {
    is_initialized : bool,
    domain         : u8,
    algo           : u8,
    _pad           : u8 = 0,
    pubkey_len     : u32,
    pubkey         : [MAX_PUBKEY_SIZE]u8,
    address_native : [72]u8,   // "ob_d5_<16 hex chars>\0"
    address_evm    : [42]u8,   // "0x<40 hex chars>"
};

/// Wallet with PQ slots for all 5 domains  (stored at fixed bare-metal address)
pub const PqWallet = extern struct {
    magic  : u32 = 0x4F4D4E49,  // "OMNI"
    slots  : [5]PqWalletSlot,    // one per DomainType
    cycle  : u64 = 0,
};

// ============================================================================
// Domain → Algorithm mapping
//   OMNI/LOVE  → ML_DSA_65  (Dilithium, high-sec, ob_d5_ prefix for signing)
//   FOOD       → FN_DSA_512  (Falcon compact, ob_f5_)
//   RENT       → ML_DSA_87   (Dilithium paranoid, ob_d5_)
//   VACATION   → SLH_DSA_SHA2_128S (SPHINCS+ compact, ob_s3_)
// Note: ob_k1_ prefix (Kyber) is used for address display only (KEM ≠ sign)
// ============================================================================

pub fn algo_for_domain(domain: wallet.DomainType) u8 {
    return switch (domain) {
        .OMNI     => @intFromEnum(PqAlgo.ML_DSA_65),
        .LOVE     => @intFromEnum(PqAlgo.ML_DSA_65),
        .FOOD     => @intFromEnum(PqAlgo.FN_DSA_512),
        .RENT     => @intFromEnum(PqAlgo.ML_DSA_87),
        .VACATION => @intFromEnum(PqAlgo.SLH_DSA_SHA2_128S),
    };
}

fn prefix_for_domain(domain: wallet.DomainType) []const u8 {
    return switch (domain) {
        .OMNI, .LOVE => PREFIX_KYBER,     // display prefix (KEM identity)
        .FOOD        => PREFIX_FALCON,
        .RENT        => PREFIX_DILITHIUM,
        .VACATION    => PREFIX_SPHINCS,
    };
}

// ============================================================================
// IPC: send request to pqc_gate_os, spin-wait for response
// ============================================================================

fn ipc_call(opcode: u8, param: u64) u64 {
    const ipc_req    = @as(*volatile u8,  @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8,  @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    ipc_status.* = IPC_STATUS_IDLE;
    ipc_result.* = param;
    ipc_req.*    = opcode;              // trigger pqc_gate_os.ipc_dispatch()

    // Bare-metal spin-wait – no sleep, no OS, max 1M cycles
    var tries: u32 = 0;
    while (ipc_status.* != IPC_STATUS_DONE and
           ipc_status.* != IPC_STATUS_ERROR and
           tries < 1_000_000) : (tries += 1)
    {
        asm volatile ("pause");
    }

    return if (ipc_status.* == IPC_STATUS_DONE) ipc_result.* else 0;
}

// ============================================================================
// Key Generation
// ============================================================================

/// Generate PQ keypair for one domain, fill slot.
/// Returns pubkey length (0 = failure).
pub fn keygen_for_domain(slot: *PqWalletSlot, domain: wallet.DomainType) u32 {
    slot.domain = @intFromEnum(domain);
    slot.algo   = algo_for_domain(domain);

    // IPC 0x43: pqc_keygen(algo) → writes pubkey to 0x100300, returns len
    const pubkey_len = @as(u32, @intCast(ipc_call(IPC_PQC_KEYGEN, slot.algo)));
    if (pubkey_len == 0) return 0;

    // Copy pubkey from PQC gate output buffer
    const src = @as([*]const u8, @ptrFromInt(0x100300));
    const copy_len = @min(pubkey_len, MAX_PUBKEY_SIZE);
    var i: u32 = 0;
    while (i < copy_len) : (i += 1) {
        slot.pubkey[i] = src[i];
    }
    slot.pubkey_len     = copy_len;
    slot.is_initialized = true;

    // Build native address: prefix + 16 hex chars from pubkey head
    const pfx = prefix_for_domain(domain);
    @memset(&slot.address_native, 0);
    @memcpy(slot.address_native[0..pfx.len], pfx);

    const hex = "0123456789abcdef";
    i = 0;
    while (i < 8 and i < copy_len) : (i += 1) {
        const b = slot.pubkey[i];
        slot.address_native[pfx.len + i * 2]     = hex[b >> 4];
        slot.address_native[pfx.len + i * 2 + 1] = hex[b & 0xF];
    }

    // EVM address: "0x" + 20 bytes from pubkey (deterministic, no Keccak yet)
    slot.address_evm[0] = '0';
    slot.address_evm[1] = 'x';
    i = 0;
    while (i < 20 and i < copy_len) : (i += 1) {
        const b = slot.pubkey[i];
        slot.address_evm[2 + i * 2]     = hex[b >> 4];
        slot.address_evm[2 + i * 2 + 1] = hex[b & 0xF];
    }

    return copy_len;
}

/// Generate keypairs for ALL 5 domains into a PqWallet struct.
pub fn keygen_all_domains(pw: *PqWallet) void {
    pw.magic = 0x4F4D4E49;  // "OMNI"
    const domains = [5]wallet.DomainType{ .OMNI, .LOVE, .FOOD, .RENT, .VACATION };
    for (domains, 0..) |domain, idx| {
        _ = keygen_for_domain(&pw.slots[idx], domain);
    }
}

// ============================================================================
// Signing
// ============================================================================

/// Sign a 32-byte tx_hash for a given domain using its PQ algorithm.
/// Returns PqSignedTx with signature populated.
pub fn sign_tx(domain: wallet.DomainType, tx_hash: [32]u8) PqSignedTx {
    var result: PqSignedTx = undefined;
    result.tx_hash = tx_hash;
    result.domain  = @intFromEnum(domain);
    result.algo    = algo_for_domain(domain);
    @memset(&result.signature, 0);
    @memset(&result.pubkey_hash, 0);

    // Write tx hash to input buffer at 0x100400
    const hash_buf = @as([*]volatile u8, @ptrFromInt(0x100400));
    for (tx_hash, 0..) |byte, i| hash_buf[i] = byte;

    // IPC 0x41: pqc_sign_treasury_tx(tx_hash_ptr=0x100400, algo)
    // ipc_result format: (algo << 32) | tx_hash_ptr
    const param: u64 = 0x100400 | (@as(u64, result.algo) << 32);
    const sig_len = @as(u32, @intCast(ipc_call(IPC_PQC_SIGN_TX, param)));
    if (sig_len == 0) {
        result.sig_len = 0;
        return result;
    }

    // Copy signature from PQC gate output buffer (0x100200)
    const sig_src  = @as([*]const u8, @ptrFromInt(0x100200));
    const copy_len = @min(sig_len, MAX_SIG_SIZE);
    var i: u32 = 0;
    while (i < copy_len) : (i += 1) result.signature[i] = sig_src[i];
    result.sig_len = copy_len;

    // Compute pubkey_hash: XOR-fold signature as bare-metal hash stub
    // Production: replace with sha3_256 from pqc_gate_os
    var h: [32]u8 = tx_hash;  // seed with tx_hash
    i = 0;
    while (i < copy_len) : (i += 1) {
        h[i & 31] ^= result.signature[i];
    }
    result.pubkey_hash = h;

    return result;
}

// ============================================================================
// Verification
// ============================================================================

/// Verify a PQ-signed transaction.
/// Layout written at 0x100440: [tx_hash(32) | sig(sig_len) | pubkey_hash(32)]
/// Returns true if pqc_gate_os confirms the signature.
pub fn verify_tx(signed_tx: *const PqSignedTx) bool {
    const base: usize = 0x100440;
    const hash_buf = @as([*]volatile u8, @ptrFromInt(base));
    const sig_buf  = @as([*]volatile u8, @ptrFromInt(base + 32));
    const pub_buf  = @as([*]volatile u8, @ptrFromInt(base + 32 + MAX_SIG_SIZE));

    // Write tx_hash
    for (signed_tx.tx_hash, 0..) |b, i| hash_buf[i] = b;

    // Write signature
    const copy_len = @min(signed_tx.sig_len, MAX_SIG_SIZE);
    var i: u32 = 0;
    while (i < copy_len) : (i += 1) sig_buf[i] = signed_tx.signature[i];

    // Write pubkey_hash as pubkey stub
    for (signed_tx.pubkey_hash, 0..) |b, idx| pub_buf[idx] = b;

    // IPC 0x42: pqc_verify_tx(base)
    const result = ipc_call(IPC_PQC_VERIFY_TX, base);
    return result == 1;
}

// ============================================================================
// Opcode integration (called by omnibus_opcodes.zig)
//   OP_SIGN_TX   0x22  → sign_tx(domain, hash)
//   OP_VERIFY_SIG 0x23 → verify_tx(signed_tx)
//   OP_DERIVE_KEY 0x20 → keygen_for_domain(slot, domain)
// ============================================================================

/// Dispatch opcode from omnibus_opcodes execution engine.
/// Returns 0 on success, 1 on error.
pub fn opcode_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {

        0x20 => {  // OP_DERIVE_KEY: arg0=slot_ptr, arg1=domain
            const slot = @as(*PqWalletSlot, @ptrFromInt(arg0));
            const domain: wallet.DomainType = @enumFromInt(@as(u8, @intCast(arg1 & 0xFF)));
            const len = keygen_for_domain(slot, domain);
            if (len == 0) return 1;
            return 0;
        },

        0x22 => {  // OP_SIGN_TX: arg0=tx_hash_ptr(32B), arg1=result_ptr(PqSignedTx)
            const hash_ptr = @as([*]const u8, @ptrFromInt(arg0));
            var hash: [32]u8 = undefined;
            @memcpy(&hash, hash_ptr[0..32]);
            // domain encoded in byte 32 of the hash buffer
            const domain: wallet.DomainType = @enumFromInt(hash_ptr[32]);
            const signed_tx = sign_tx(domain, hash);
            const out = @as(*PqSignedTx, @ptrFromInt(arg1));
            out.* = signed_tx;
            return if (signed_tx.sig_len > 0) 0 else 1;
        },

        0x23 => {  // OP_VERIFY_SIG: arg0=signed_tx_ptr
            const signed_tx = @as(*const PqSignedTx, @ptrFromInt(arg0));
            return if (verify_tx(signed_tx)) 0 else 1;
        },

        else => 1,  // Unknown opcode
    };
}

// ============================================================================
// Diagnostics (UART debug output stub – replace with uart_write in kernel)
// ============================================================================

/// Return algo name as comptime slice for logging
pub fn algo_name(algo: u8) []const u8 {
    return switch (algo) {
        @intFromEnum(PqAlgo.ML_DSA_44)         => "ML-DSA-44 (Dilithium std)",
        @intFromEnum(PqAlgo.ML_DSA_65)         => "ML-DSA-65 (Dilithium high)",
        @intFromEnum(PqAlgo.ML_DSA_87)         => "ML-DSA-87 (Dilithium paranoid)",
        @intFromEnum(PqAlgo.SLH_DSA_SHA2_128S) => "SLH-DSA-128S (SPHINCS+ compact)",
        @intFromEnum(PqAlgo.SLH_DSA_SHA2_256F) => "SLH-DSA-256F (SPHINCS+ fast)",
        @intFromEnum(PqAlgo.FN_DSA_512)        => "FN-DSA-512 (Falcon compact)",
        @intFromEnum(PqAlgo.FN_DSA_1024)       => "FN-DSA-1024 (Falcon full)",
        else => "UNKNOWN",
    };
}

/// Return expected signature size for algo (bytes)
pub fn sig_size_for_algo(algo: u8) u32 {
    return switch (algo) {
        @intFromEnum(PqAlgo.ML_DSA_44)         => 2420,
        @intFromEnum(PqAlgo.ML_DSA_65)         => 3293,
        @intFromEnum(PqAlgo.ML_DSA_87)         => 4595,
        @intFromEnum(PqAlgo.SLH_DSA_SHA2_128S) => 7856,
        @intFromEnum(PqAlgo.SLH_DSA_SHA2_256F) => 17088,
        @intFromEnum(PqAlgo.FN_DSA_512)        =>  897,
        @intFromEnum(PqAlgo.FN_DSA_1024)       => 1793,
        else => 0,
    };
}
