// execution_os.zig — Root Execution OS module
// Reads OrderPackets from Grid OS, signs them per exchange, writes to TX queue
// Exports: init_plugin(), run_execution_cycle()

const std = @import("std");

const types = @import("types.zig");
const crypto = @import("crypto.zig");
const order_reader = @import("order_reader.zig");
const order_format = @import("order_format.zig");
const lcx_sign = @import("lcx_sign.zig");
const kraken_sign = @import("kraken_sign.zig");
const coinbase_sign = @import("coinbase_sign.zig");
const fill_tracker = @import("fill_tracker.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;
var order_processed_count: u32 = 0;
var fill_processed_count: u32 = 0;

// ============================================================================
// ExecutionState Access
// ============================================================================

/// Get mutable pointer to ExecutionState header (0x130000)
fn getExecutionStatePtr() *volatile types.ExecutionState {
    return @as(*volatile types.ExecutionState, @ptrFromInt(types.EXECUTION_BASE));
}

/// Get mutable pointer to API key slots (Kraken/Coinbase/LCX)
fn getApiKeyPtr(exchange_id: u8) *volatile types.ApiKeySlot {
    const base = types.EXECUTION_BASE + types.API_KEY_OFFSET;
    return @as(*volatile types.ApiKeySlot, @ptrFromInt(base + @as(usize, exchange_id) * @sizeOf(types.ApiKeySlot)));
}

/// Get mutable pointer to TX queue (SignedOrderSlot array)
fn getSignedOrderSlotPtr(slot_idx: u32) *volatile types.SignedOrderSlot {
    const base = types.EXECUTION_BASE + types.SIGNED_SLOT_OFFSET;
    return @as(*volatile types.SignedOrderSlot, @ptrFromInt(base + @as(usize, slot_idx) * @sizeOf(types.SignedOrderSlot)));
}

// ============================================================================
// Authorization Gate
// ============================================================================

/// Check if Ada has authorized execution (auth gate at 0x100050)
fn checkAuthGate() bool {
    const auth_byte = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH));
    return auth_byte.* == 0x70;
}

// ============================================================================
// Order Processing & Signing
// ============================================================================

/// Process a single OrderPacket: sign it and write to TX queue
fn processOrder(packet: *const types.OrderPacket, slot_idx: u32) void {
    if (slot_idx >= types.MAX_SIGNED_SLOTS) {
        return;
    }

    // Get API credentials for this exchange
    const api_key = getApiKeyPtr(@as(u8, @intCast(packet.exchange_id)));

    // Get TX queue slot
    const tx_slot = getSignedOrderSlotPtr(slot_idx);

    // Dispatch to exchange-specific signer
    // Cast away volatile for crypto operations (safe since we control access)
    const api_key_const = @as(*const types.ApiKeySlot, @volatileCast(api_key));

    switch (packet.exchange_id) {
        types.KRAKEN => {
            kraken_sign.signOrder(tx_slot, packet, api_key_const);
        },
        types.COINBASE => {
            coinbase_sign.signOrder(tx_slot, packet, api_key_const);
        },
        types.LCX => {
            lcx_sign.signOrder(tx_slot, packet, api_key_const);
        },
        else => {
            // Unknown exchange, mark as error
            tx_slot.flags = 0x04;  // Error flag
        },
    }
}

// ============================================================================
// Main Execution Loop
// ============================================================================

/// Main execution cycle
/// Called repeatedly by Ada Mother OS scheduler
export fn run_execution_cycle() void {
    if (!initialized) return;

    // Check auth gate
    if (!checkAuthGate()) return;

    const state = getExecutionStatePtr();

    // Bounded loop: process max 32 orders per cycle for determinism
    var processed: u32 = 0;
    const max_per_cycle: u32 = 32;

    // 1. Process input orders from Grid OS
    while (processed < max_per_cycle and order_reader.hasOrder()) : (processed += 1) {
        if (order_reader.readNext()) |packet| {
            // Find next free TX slot
            var slot_idx: u32 = 0;
            while (slot_idx < types.MAX_SIGNED_SLOTS) : (slot_idx += 1) {
                const tx_slot = getSignedOrderSlotPtr(slot_idx);
                if (tx_slot.flags == 0) {
                    // Empty slot found
                    processOrder(&packet, slot_idx);
                    order_processed_count += 1;
                    break;
                }
            }
        }
    }

    // 2. Process FillResults from exchanges
    const fills_processed = fill_tracker.processAllFills();
    fill_processed_count += fills_processed;

    // 3. Update cycle counter and TSC
    cycle_count += 1;
    state.cycle_count = cycle_count;
    state.order_in_count = order_processed_count;
    state.fill_out_count = fill_processed_count;
    state.tsc_last_cycle = rdtsc();
}

// ============================================================================
// Module Initialization
// ============================================================================

/// Initialize Execution OS plugin
/// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Zero-fill ExecutionState header
    const state = getExecutionStatePtr();
    state.* = .{
        .magic = 0x45584543,  // "EXEC"
        .flags = 0x01,        // Mark as active
        .cycle_count = 0,
        .order_in_count = 0,
        .fill_out_count = 0,
        .tsc_last_cycle = 0,
        ._reserved = [_]u8{0} ** 36,
    };

    // Zero-fill TX queue
    var i: u32 = 0;
    while (i < types.MAX_SIGNED_SLOTS) : (i += 1) {
        const slot = getSignedOrderSlotPtr(i);
        slot.exchange_id = 0;
        slot.pair_id = 0;
        slot.flags = 0;
        slot.payload_len = 0;
    }

    // Zero-fill FillResult array
    fill_tracker.clearAllFills();

    // Initialize order reader (ring header)
    order_reader.resetRing();

    initialized = true;
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get cycle count
export fn get_cycle_count() u64 {
    return cycle_count;
}

/// Get order processed count
export fn get_order_count() u32 {
    return order_processed_count;
}

/// Get fill processed count
export fn get_fill_count() u32 {
    return fill_processed_count;
}

/// Get initialized state
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

// ============================================================================
// Debug & Testing Exports
// ============================================================================

/// Force process a specific order slot (for testing)
export fn test_process_order(slot_idx: u32) void {
    if (slot_idx >= types.MAX_ORDER_RING) return;

    // Peek at next order without advancing
    if (order_reader.peekNext()) |packet| {
        if (slot_idx < types.MAX_SIGNED_SLOTS) {
            processOrder(&packet, slot_idx);
        }
    }
}

/// Manually inject a test OrderPacket and process it
export fn test_inject_and_sign(exchange_id: u16, pair_id: u16, side: u8, qty: u64, price: u64) void {
    var packet: types.OrderPacket = undefined;
    packet.opcode = 0x70;
    packet.exchange_id = exchange_id;
    packet.pair_id = pair_id;
    packet.side = side;
    packet.quantity_sats = qty;
    packet.price_cents = price;

    processOrder(&packet, 0);
}

/// Get current TX slot status (for debugging)
export fn test_get_tx_slot(slot_idx: u32) types.SignedOrderSlot {
    if (slot_idx >= types.MAX_SIGNED_SLOTS) {
        return .{
            .exchange_id = 0,
            .pair_id = 0,
            .flags = 0,
            ._pad = 0,
            .payload_len = 0,
            ._pad2 = 0,
            .payload = [_]u8{0} ** 376,
        };
    }

    const slot = getSignedOrderSlotPtr(slot_idx);
    return slot.*;
}

/// Get ExecutionState for inspection
export fn test_get_execution_state() types.ExecutionState {
    const state = getExecutionStatePtr();
    return state.*;
}

/// Process all pending fills (debug)
export fn test_process_all_fills() u32 {
    return fill_tracker.processAllFills();
}

// ============================================================================
// Utilities
// ============================================================================

/// Read current TSC (Time Stamp Counter)
fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}
