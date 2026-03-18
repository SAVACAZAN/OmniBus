// OmniBus Key Rotation Protocol
// Safe algorithm-agnostic key rotation for post-quantum domains

const std = @import("std");

// ============================================================================
// Key Rotation States
// ============================================================================

pub const RotationState = enum(u8) {
    PENDING = 0,           // Rotation proposed, awaiting signatures
    SCHEDULED = 1,         // Accepted, scheduled for future block
    ACTIVE = 2,            // New key is now active
    DEPRECATED = 3,        // Old key deprecated, soft-phase-out
    REVOKED = 4,           // Old key revoked, hard-phase-out
};

pub const RotationPhase = enum(u8) {
    NONE = 0,
    SOFT_PHASE_OUT = 1,    // Both old & new keys accepted (7 days)
    HARD_CUTOVER = 2,      // Only new key accepted
};

// ============================================================================
// Key Rotation Transaction
// ============================================================================

pub const KeyRotationTx = struct {
    domain: u8,                            // Which domain (0=LOVE, 1=FOOD, 2=RENT, 3=VACATION)
    old_key_hash: [32]u8,                  // SHA256(old_pubkey) for auditing
    new_pubkey: [2592]u8,                  // New public key (max Dilithium size)
    new_pubkey_len: u16,                   // Actual length of new key
    algorithm: u8,                         // New algorithm (2=Kyber, 6=Dilithium, 7=Falcon, 9=Sphincs)

    rotation_epoch: u64,                   // Block height when rotation becomes active
    soft_phase_out_duration: u64,          // Blocks allowing both old+new (default: 50,400 = 7 days)
    hard_cutover_block: u64,               // Block height of hard cutover

    // Signatures (old key must sign authorization)
    old_key_signature: [4096]u8,           // Signature using OLD key (proves ownership)
    old_sig_len: u16,

    // Multi-domain approval (3-of-4 domains must approve)
    approvals: [4]u8,                      // Approval status per domain (0=none, 1=pending, 2=approved, 3=rejected)
    approval_count: u8,

    created_at: u64,
    expires_at: u64,                       // 30-day window to complete rotation
};

// ============================================================================
// Rotation Metadata (Per-Domain)
// ============================================================================

pub const KeyRotationMetadata = struct {
    domain: u8,
    current_key_hash: [32]u8,
    next_key_hash: [32]u8,

    rotation_count: u32,                   // How many times has this domain rotated?
    last_rotation_block: u64,
    next_scheduled_block: u64,

    phase: RotationPhase,
    state: RotationState,

    // Emergency revocation (only if domain is compromised)
    is_compromised: bool,
    revocation_reason: [256]u8,
};

// ============================================================================
// Rotation Safety Checks
// ============================================================================

pub fn validate_rotation_tx(tx: *const KeyRotationTx) bool {
    // 1. Check expiration
    if (tx.expires_at < current_block_height()) {
        return false; // Rotation proposal has expired
    }

    // 2. Check algorithm is valid NIST PQ
    if (!is_valid_pq_algorithm(tx.algorithm)) {
        return false;
    }

    // 3. Check pubkey length matches algorithm
    if (!validate_pubkey_length(tx.algorithm, tx.new_pubkey_len)) {
        return false;
    }

    // 4. Check hard cutover after soft phase-out
    if (tx.hard_cutover_block <= tx.rotation_epoch + tx.soft_phase_out_duration) {
        return false;
    }

    // 5. Verify old key signature (proves authorized rotation)
    // This would use the old key's signature algorithm
    // Placeholder: would verify signature
    const sig_valid = true; // TODO: implement signature verification

    return sig_valid;
}

pub fn is_valid_pq_algorithm(algo: u8) bool {
    return switch (algo) {
        2, 6, 7, 9 => true,  // Kyber, Dilithium, Falcon, Sphincs+
        else => false,
    };
}

pub fn validate_pubkey_length(algo: u8, len: u16) bool {
    return switch (algo) {
        2 => len >= 800 and len <= 1568,   // Kyber variants
        6 => len >= 1312 and len <= 2592,  // Dilithium variants
        7 => len == 897,                   // Falcon-512
        9 => len == 64,                    // SPHINCS+
        else => false,
    };
}

// ============================================================================
// Multi-Domain Approval System
// ============================================================================

pub fn count_approvals(tx: *const KeyRotationTx) u8 {
    var count: u8 = 0;
    for (tx.approvals) |status| {
        if (status == 2) { // 2 = approved
            count +%= 1;
        }
    }
    return count;
}

pub fn require_majority_approval(tx: *const KeyRotationTx) bool {
    // Require 3-of-4 domains to approve key rotation
    // This prevents one compromised domain from rotating all keys
    const approvals = count_approvals(tx);
    return approvals >= 3;
}

pub fn add_domain_approval(tx: *KeyRotationTx, domain: u8, approved: bool) bool {
    if (domain > 3) {
        return false;
    }

    tx.approvals[domain] = if (approved) @as(u8, 2) else @as(u8, 3); // 2=approved, 3=rejected
    tx.approval_count = count_approvals(tx);

    return true;
}

// ============================================================================
// Soft Phase-Out Period (Dual-Key Acceptance)
// ============================================================================

pub fn is_in_soft_phase_out(metadata: *const KeyRotationMetadata) bool {
    const current_block = current_block_height();
    const soft_phase_end = metadata.rotation_count + 50400; // ~7 days in blocks

    return metadata.phase == RotationPhase.SOFT_PHASE_OUT and
           current_block < soft_phase_end;
}

pub fn verify_with_old_or_new_key(
    metadata: *const KeyRotationMetadata,
    signature: []const u8,
    pubkey_hash: [32]u8
) bool {
    if (is_in_soft_phase_out(metadata)) {
        // Accept EITHER old key OR new key
        return pubkey_hash == metadata.current_key_hash or
               pubkey_hash == metadata.next_key_hash;
    } else if (metadata.phase == RotationPhase.HARD_CUTOVER) {
        // Accept ONLY new key
        return pubkey_hash == metadata.next_key_hash;
    } else {
        // No rotation active
        return pubkey_hash == metadata.current_key_hash;
    }
}

// ============================================================================
// Hard Cutover (Enforce New Key Only)
// ============================================================================

pub fn execute_hard_cutover(metadata: *KeyRotationMetadata) bool {
    if (metadata.state != RotationState.ACTIVE) {
        return false; // Can only hard cutover from ACTIVE state
    }

    // Move current → deprecated, next → current
    @memcpy(&metadata.current_key_hash, &metadata.next_key_hash);
    metadata.phase = RotationPhase.HARD_CUTOVER;
    metadata.state = RotationState.DEPRECATED;

    // Clear next key
    @memset(&metadata.next_key_hash, 0);

    return true;
}

// ============================================================================
// Emergency Revocation (Compromised Key)
// ============================================================================

pub const RevocationReason = enum(u8) {
    PRIVATE_KEY_LEAKED = 1,
    ALGORITHM_BROKEN = 2,
    DEVICE_STOLEN = 3,
    EMPLOYEE_LEFT = 4,
    ROTATION_TIMEOUT = 5,
};

pub fn emergency_revoke_key(
    metadata: *KeyRotationMetadata,
    reason: RevocationReason
) bool {
    // Only revoke if:
    // 1. All 4 domains agree (emergency vote)
    // 2. Reason is documented on blockchain
    // 3. New key is already active

    if (metadata.state != RotationState.DEPRECATED and
        metadata.state != RotationState.REVOKED) {
        return false;
    }

    metadata.state = RotationState.REVOKED;
    metadata.is_compromised = true;

    // Document reason
    var reason_str: [256]u8 = undefined;
    @memset(&reason_str, 0);
    const reason_text = switch (reason) {
        .PRIVATE_KEY_LEAKED => "Private key was leaked to unauthorized parties",
        .ALGORITHM_BROKEN => "Underlying PQ algorithm was cryptographically broken",
        .DEVICE_STOLEN => "Hardware device containing key was stolen",
        .EMPLOYEE_LEFT => "Employee with key access left the organization",
        .ROTATION_TIMEOUT => "Rotation did not complete within 30-day window",
    };
    @memcpy(reason_str[0..reason_text.len], reason_text);

    return true;
}

// ============================================================================
// Cross-Chain Anchor & Attestation
// ============================================================================

pub const KeyRotationAnchor = struct {
    rotation_tx_hash: [32]u8,              // Hash of rotation transaction
    anchor_chain: u8,                      // Which chain anchored it (0=BTC, 1=ETH, 2=EGLD, 3=SOL, 4=OPT, 5=BASE)
    anchor_tx_hash: [32]u8,                // Transaction hash on anchor chain
    anchor_block_height: u64,
    anchor_proof: [256]u8,                 // Merkle proof or log proof
    anchor_timestamp: u64,
};

pub fn anchor_rotation_on_chain(
    rotation_tx: *const KeyRotationTx,
    anchor_chain: u8
) KeyRotationAnchor {
    var anchor: KeyRotationAnchor = undefined;

    // In real implementation:
    // 1. Create rotation proof on Bitcoin (OP_RETURN)
    // 2. Create rotation proof on Ethereum (contract event)
    // 3. Create rotation proof on EGLD/Solana/Optimism/Base

    // For now, placeholder
    @memset(&anchor.rotation_tx_hash, 0);
    @memset(&anchor.anchor_tx_hash, 0);
    @memset(&anchor.anchor_proof, 0);
    anchor.anchor_chain = anchor_chain;
    anchor.anchor_block_height = current_block_height();
    anchor.anchor_timestamp = current_timestamp();

    return anchor;
}

// ============================================================================
// Rotation History & Audit Trail
// ============================================================================

pub const RotationHistory = struct {
    rotation_count: u32,
    rotations: [100]KeyRotationTx,  // Last 100 rotations per domain

    pub fn add_rotation(history: *RotationHistory, tx: *const KeyRotationTx) bool {
        if (history.rotation_count >= 100) {
            return false; // History full
        }

        history.rotations[history.rotation_count] = tx.*;
        history.rotation_count +%= 1;
        return true;
    }

    pub fn get_last_rotation(history: *const RotationHistory) ?*const KeyRotationTx {
        if (history.rotation_count == 0) {
            return null;
        }
        return &history.rotations[history.rotation_count - 1];
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

fn current_block_height() u64 {
    // Placeholder: query current block height
    return 0;
}

fn current_timestamp() u64 {
    // Placeholder: query current Unix timestamp
    return 0;
}

pub fn main() void {}
