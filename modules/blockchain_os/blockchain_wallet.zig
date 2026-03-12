// blockchain_wallet.zig — Wallet integration for BlockchainOS
// Memory: 0x250000–0x27FFFF (192KB) — shared with flash loans
// Exports: wallet_create_opcode(), wallet_derive_chain_opcode(), wallet_sign_tx_opcode()

const std = @import("std");
const WalletIntegration = @import("blockchain_wallet_integration.zig");

// ============================================================================
// Wallet Module State (within BlockchainOS memory segment)
// ============================================================================

const WALLET_STATE_BASE: usize = 0x260000; // Within blockchain segment (0x250000-0x27FFFF)
const MAX_WALLETS: u32 = 16;

pub const WalletSlot = struct {
    active: u8,              // 1 = in use, 0 = free
    mnemonic_hash: [32]u8,
    master_key: [32]u8,
    master_chain_code: [32]u8,
    derived_key: [32]u8,
    derived_address: [70]u8,
    address_len: u8,
    current_chain: u32,
    _reserved: [13]u8,
};

// ============================================================================
// Wallet State Access
// ============================================================================

fn getWalletSlotPtr(slot_idx: u32) *volatile WalletSlot {
    const base = WALLET_STATE_BASE;
    return @as(*volatile WalletSlot, @ptrFromInt(base + @as(usize, slot_idx) * @sizeOf(WalletSlot)));
}

fn findFreeWalletSlot() ?u32 {
    var i: u32 = 0;
    while (i < MAX_WALLETS) : (i += 1) {
        const slot = getWalletSlotPtr(i);
        if (slot.active == 0) {
            return i;
        }
    }
    return null;
}

// ============================================================================
// Wallet Opcode Handlers
// ============================================================================

/// WALLET_CREATE (0x01): Initialize wallet from mnemonic
/// Input: mnemonic (256 bytes), passphrase (128 bytes)
/// Output: wallet_slot_id (u32) or 0xFFFFFFFF if error
pub export fn wallet_create_opcode(
    mnemonic_ptr: [*]const u8,
    passphrase_ptr: [*]const u8,
) u32 {
    // Find free slot
    const slot_idx = findFreeWalletSlot() orelse return 0xFFFFFFFF;

    // Create wallet
    var mnemonic: [256]u8 = undefined;
    var passphrase: [128]u8 = undefined;

    @memcpy(&mnemonic, mnemonic_ptr[0..256]);
    @memcpy(&passphrase, passphrase_ptr[0..128]);

    const wallet = WalletIntegration.WalletOpcodes.wallet_create(mnemonic, passphrase) catch return 0xFFFFFFFF;

    // Store in slot
    const slot = getWalletSlotPtr(slot_idx);
    @memcpy(&slot.mnemonic_hash, &wallet);
    slot.active = 1;

    return slot_idx;
}

/// WALLET_DERIVE_CHAIN (0x02): Derive address for specific blockchain
/// Input: wallet_slot_id (u32), chain_id (u32)
/// Output: address (70 bytes, returned via pointer)
pub export fn wallet_derive_chain_opcode(
    slot_idx: u32,
    chain_id: u32,
    output_addr_ptr: [*]u8,
) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0; // Slot not in use

    // Derive address for chain
    const addr = WalletIntegration.WalletOpcodes.wallet_derive_chain(chain_id, 0);

    // Store in slot and copy to output
    @memcpy(&slot.derived_address, &addr);
    slot.current_chain = chain_id;
    @memcpy(output_addr_ptr[0..70], &addr);

    // Return address length (first non-zero index or 70)
    var len: u8 = 70;
    var i: u8 = 0;
    while (i < 70) : (i += 1) {
        if (addr[i] == 0) {
            len = i;
            break;
        }
    }

    return len;
}

/// WALLET_SIGN_TX (0x03): Sign transaction hash
/// Input: wallet_slot_id (u32), tx_hash (32 bytes), chain_id (u32)
/// Output: signature (64 bytes)
pub export fn wallet_sign_tx_opcode(
    slot_idx: u32,
    tx_hash_ptr: [*]const u8,
    chain_id: u32,
    signature_ptr: [*]u8,
) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0;

    var tx_hash: [32]u8 = undefined;
    @memcpy(&tx_hash, tx_hash_ptr[0..32]);

    const signature = WalletIntegration.WalletOpcodes.wallet_sign_tx(tx_hash, chain_id);
    @memcpy(signature_ptr[0..64], &signature);

    return 1; // Success
}

/// WALLET_EXPORT_ADDRESS (0x05): Get address in specific format
/// Input: wallet_slot_id (u32), format (0=native, 1=0x_evm, 2=ob_k1_pq)
/// Output: address (70 bytes)
pub export fn wallet_export_address_opcode(
    slot_idx: u32,
    format: u8,
    output_addr_ptr: [*]u8,
) u8 {
    _ = format;
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0;

    // For now, return the last derived address
    // In real implementation, would regenerate in requested format
    @memcpy(output_addr_ptr[0..70], &slot.derived_address);

    var len: u8 = 70;
    var i: u8 = 0;
    while (i < 70) : (i += 1) {
        if (slot.derived_address[i] == 0) {
            len = i;
            break;
        }
    }

    return len;
}

/// WALLET_VERIFY_SIGNATURE (0x04): Verify transaction signature
/// Input: message (32 bytes), signature (64 bytes), pubkey (65 bytes)
/// Output: 1 = valid, 0 = invalid
pub export fn wallet_verify_signature_opcode(
    message_ptr: [*]const u8,
    signature_ptr: [*]const u8,
    pubkey_ptr: [*]const u8,
) u8 {
    var message: [32]u8 = undefined;
    var signature: [64]u8 = undefined;
    var pubkey: [65]u8 = undefined;

    @memcpy(&message, message_ptr[0..32]);
    @memcpy(&signature, signature_ptr[0..64]);
    @memcpy(&pubkey, pubkey_ptr[0..65]);

    const result = WalletIntegration.WalletOpcodes.wallet_verify_signature(message, signature, pubkey);
    return result;
}

/// WALLET_GET_BALANCE (0x06): Query balance (stub for blockchain queries)
/// Input: wallet_slot_id (u32), address (70 bytes)
/// Output: balance (u128, returned via pointer)
pub export fn wallet_get_balance_opcode(
    slot_idx: u32,
    address_ptr: [*]const u8,
    balance_ptr: [*]u128,
) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0;

    var address: [70]u8 = undefined;
    @memcpy(&address, address_ptr[0..70]);

    const balance = WalletIntegration.WalletOpcodes.wallet_get_balance(address, slot.current_chain);
    balance_ptr[0] = balance;

    return 1;
}

/// WALLET_SEND_TX (0x07): Broadcast transaction
/// Input: wallet_slot_id (u32), to_address (70 bytes), amount (u128), chain_id (u32)
/// Output: tx_hash (32 bytes)
pub export fn wallet_send_tx_opcode(
    slot_idx: u32,
    to_address_ptr: [*]const u8,
    amount: u128,
    chain_id: u32,
    tx_hash_ptr: [*]u8,
) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0;

    var to_address: [70]u8 = undefined;
    @memcpy(&to_address, to_address_ptr[0..70]);

    const tx_hash = WalletIntegration.WalletOpcodes.wallet_send_tx(to_address, amount, chain_id);
    @memcpy(tx_hash_ptr[0..32], &tx_hash);

    return 1;
}

/// WALLET_DELETE (0x08): Delete wallet slot and zero memory
pub export fn wallet_delete_opcode(slot_idx: u32) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;

    const slot = getWalletSlotPtr(slot_idx);
    if (slot.active == 0) return 0;

    // Zero-fill slot
    @memset(@as([*]volatile u8, @ptrCast(slot))[0..@sizeOf(WalletSlot)], 0);

    return 1; // Success
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get count of active wallets
pub export fn get_active_wallet_count() u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < MAX_WALLETS) : (i += 1) {
        const slot = getWalletSlotPtr(i);
        if (slot.active == 1) {
            count += 1;
        }
    }
    return count;
}

/// Check if wallet slot is active
pub export fn is_wallet_active(slot_idx: u32) u8 {
    if (slot_idx >= MAX_WALLETS) return 0;
    const slot = getWalletSlotPtr(slot_idx);
    return slot.active;
}

// ============================================================================
// Module Initialization
// ============================================================================

/// Initialize wallet module (zero all slots on startup)
pub fn init_wallet_module() void {
    var i: u32 = 0;
    while (i < MAX_WALLETS) : (i += 1) {
        const slot = getWalletSlotPtr(i);
        @memset(@as([*]volatile u8, @ptrCast(slot))[0..@sizeOf(WalletSlot)], 0);
    }
}
