// OmniBus liboqs FFI - Real C Library Bindings
// Links against liboqs.a (NIST Post-Quantum Cryptography Reference Implementation)

const std = @import("std");
const c = @cImport({
    @cInclude("oqs/oqs.h");
});

// ============================================================================
// FFI Status Code
// ============================================================================

pub const OQS_STATUS = enum(c_int) {
    OQS_SUCCESS = 0,
    OQS_ERROR = -1,
};

// ============================================================================
// KEM (Key Encapsulation Mechanism) - Kyber
// ============================================================================

pub const KyberFFI = struct {
    kem: ?*c.OQS_KEM,

    pub fn new() ?KyberFFI {
        var self: KyberFFI = undefined;
        self.kem = c.OQS_KEM_new("Kyber768");
        if (self.kem == null) {
            return null;
        }
        return self;
    }

    pub fn keypair(self: *KyberFFI) ?struct {
        public_key: [1184]u8,
        secret_key: [2400]u8,
    } {
        if (self.kem == null) return null;

        var public_key: [1184]u8 = undefined;
        var secret_key: [2400]u8 = undefined;

        const status = c.OQS_KEM_keypair(
            self.kem,
            @ptrCast(&public_key),
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .public_key = public_key,
            .secret_key = secret_key,
        };
    }

    pub fn encapsulate(self: *KyberFFI, public_key: [1184]u8) ?struct {
        ciphertext: [1088]u8,
        shared_secret: [32]u8,
    } {
        if (self.kem == null) return null;

        var ciphertext: [1088]u8 = undefined;
        var shared_secret: [32]u8 = undefined;

        const status = c.OQS_KEM_encaps(
            self.kem,
            @ptrCast(&ciphertext),
            @ptrCast(&shared_secret),
            @ptrCast(&public_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .ciphertext = ciphertext,
            .shared_secret = shared_secret,
        };
    }

    pub fn decapsulate(self: *KyberFFI, ciphertext: [1088]u8, secret_key: [2400]u8) ?[32]u8 {
        if (self.kem == null) return null;

        var shared_secret: [32]u8 = undefined;

        const status = c.OQS_KEM_decaps(
            self.kem,
            @ptrCast(&shared_secret),
            @ptrCast(&ciphertext),
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return shared_secret;
    }

    pub fn deinit(self: *KyberFFI) void {
        if (self.kem != null) {
            c.OQS_KEM_free(self.kem);
            self.kem = null;
        }
    }
};

// ============================================================================
// SIG (Digital Signature Algorithm) - Dilithium
// ============================================================================

pub const DilithiumFFI = struct {
    sig: ?*c.OQS_SIG,

    pub fn new() ?DilithiumFFI {
        var self: DilithiumFFI = undefined;
        self.sig = c.OQS_SIG_new("Dilithium5");
        if (self.sig == null) {
            return null;
        }
        return self;
    }

    pub fn keypair(self: *DilithiumFFI) ?struct {
        public_key: [2592]u8,
        secret_key: [4896]u8,
    } {
        if (self.sig == null) return null;

        var public_key: [2592]u8 = undefined;
        var secret_key: [4896]u8 = undefined;

        const status = c.OQS_SIG_keypair(
            self.sig,
            @ptrCast(&public_key),
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .public_key = public_key,
            .secret_key = secret_key,
        };
    }

    pub fn sign(self: *DilithiumFFI, message: []const u8, secret_key: [4896]u8) ?struct {
        signature: [2420]u8,
        sig_len: usize,
    } {
        if (self.sig == null) return null;

        var signature: [2420]u8 = undefined;
        var sig_len: usize = 0;

        const status = c.OQS_SIG_sign(
            self.sig,
            @ptrCast(&signature),
            &sig_len,
            message.ptr,
            message.len,
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .signature = signature,
            .sig_len = sig_len,
        };
    }

    pub fn verify(self: *DilithiumFFI, message: []const u8, signature: [2420]u8, sig_len: usize, public_key: [2592]u8) bool {
        if (self.sig == null) return false;

        const status = c.OQS_SIG_verify(
            self.sig,
            message.ptr,
            message.len,
            @ptrCast(&signature),
            sig_len,
            @ptrCast(&public_key)
        );

        return status == @intFromEnum(OQS_STATUS.OQS_SUCCESS);
    }

    pub fn deinit(self: *DilithiumFFI) void {
        if (self.sig != null) {
            c.OQS_SIG_free(self.sig);
            self.sig = null;
        }
    }
};

// ============================================================================
// SIG - Falcon (Lattice-based)
// ============================================================================

pub const FalconFFI = struct {
    sig: ?*c.OQS_SIG,

    pub fn new() ?FalconFFI {
        var self: FalconFFI = undefined;
        self.sig = c.OQS_SIG_new("Falcon-512");
        if (self.sig == null) {
            return null;
        }
        return self;
    }

    pub fn keypair(self: *FalconFFI) ?struct {
        public_key: [897]u8,
        secret_key: [1281]u8,
    } {
        if (self.sig == null) return null;

        var public_key: [897]u8 = undefined;
        var secret_key: [1281]u8 = undefined;

        const status = c.OQS_SIG_keypair(
            self.sig,
            @ptrCast(&public_key),
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .public_key = public_key,
            .secret_key = secret_key,
        };
    }

    pub fn sign(self: *FalconFFI, message: []const u8, secret_key: [1281]u8) ?struct {
        signature: [666]u8,
        sig_len: usize,
    } {
        if (self.sig == null) return null;

        var signature: [666]u8 = undefined;
        var sig_len: usize = 0;

        const status = c.OQS_SIG_sign(
            self.sig,
            @ptrCast(&signature),
            &sig_len,
            message.ptr,
            message.len,
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .signature = signature,
            .sig_len = sig_len,
        };
    }

    pub fn deinit(self: *FalconFFI) void {
        if (self.sig != null) {
            c.OQS_SIG_free(self.sig);
            self.sig = null;
        }
    }
};

// ============================================================================
// SIG - SPHINCS+ (Hash-based, Stateless)
// ============================================================================

pub const SphincsFFI = struct {
    sig: ?*c.OQS_SIG,

    pub fn new() ?SphincsFFI {
        var self: SphincsFFI = undefined;
        self.sig = c.OQS_SIG_new("SPHINCS+-SHA256-128f");
        if (self.sig == null) {
            return null;
        }
        return self;
    }

    pub fn keypair(self: *SphincsFFI) ?struct {
        public_key: [32]u8,
        secret_key: [64]u8,
    } {
        if (self.sig == null) return null;

        var public_key: [32]u8 = undefined;
        var secret_key: [64]u8 = undefined;

        const status = c.OQS_SIG_keypair(
            self.sig,
            @ptrCast(&public_key),
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .public_key = public_key,
            .secret_key = secret_key,
        };
    }

    pub fn sign(self: *SphincsFFI, message: []const u8, secret_key: [64]u8) ?struct {
        signature: [4096]u8,
        sig_len: usize,
    } {
        if (self.sig == null) return null;

        var signature: [4096]u8 = undefined;
        var sig_len: usize = 0;

        const status = c.OQS_SIG_sign(
            self.sig,
            @ptrCast(&signature),
            &sig_len,
            message.ptr,
            message.len,
            @ptrCast(&secret_key)
        );

        if (status != @intFromEnum(OQS_STATUS.OQS_SUCCESS)) {
            return null;
        }

        return .{
            .signature = signature,
            .sig_len = sig_len,
        };
    }

    pub fn deinit(self: *SphincsFFI) void {
        if (self.sig != null) {
            c.OQS_SIG_free(self.sig);
            self.sig = null;
        }
    }
};

// ============================================================================
// Convenience Functions - Get by Domain
// ============================================================================

pub fn create_kem_for_domain(domain: u8) ?KyberFFI {
    return switch (domain) {
        0 => KyberFFI.new(), // omnibus.love
        else => null,
    };
}

pub fn create_sig_for_domain(domain: u8) ?anytype {
    return switch (domain) {
        1 => FalconFFI.new(), // omnibus.food
        2 => DilithiumFFI.new(), // omnibus.rent
        3 => SphincsFFI.new(), // omnibus.vacation
        else => null,
    };
}

pub fn main() void {}
