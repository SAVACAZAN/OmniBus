// blockchain_os.zig — BlockchainOS module for Solana flash loans + EGLD staking
// Memory: 0x250000–0x27FFFF (192KB)
// Exports: init_plugin(), request_flash_loan(), execute_atomic_swap()

const std = @import("std");

const types = @import("types.zig");
const solana = @import("solana.zig");
const raydium = @import("raydium.zig");
const flash_loan_executor = @import("flash_loan_executor.zig");

// ============================================================================
// Module State
// ============================================================================

var initialized: bool = false;
var cycle_count: u64 = 0;
var flash_loan_count: u32 = 0;
var swap_count: u32 = 0;

// ============================================================================
// BlockchainState Access
// ============================================================================

/// Get mutable pointer to blockchain state header (0x250000)
fn getBlockchainStatePtr() *volatile types.BlockchainState {
    return @as(*volatile types.BlockchainState, @ptrFromInt(types.BLOCKCHAIN_BASE));
}

/// Get mutable pointer to flash loan requests
fn getFlashLoanSlotPtr(slot_idx: u32) *volatile types.FlashLoanRequest {
    const base = types.BLOCKCHAIN_BASE + types.FLASH_LOAN_OFFSET;
    return @as(*volatile types.FlashLoanRequest, @ptrFromInt(base + @as(usize, slot_idx) * @sizeOf(types.FlashLoanRequest)));
}

// ============================================================================
// Module Lifecycle
// ============================================================================

/// Initialize BlockchainOS plugin
/// Called once by Ada Mother OS at boot
export fn init_plugin() void {
    if (initialized) return;

    // Zero-fill blockchain state
    const state = getBlockchainStatePtr();
    state.* = .{
        .magic = 0x424C4B4F, // "BLKO"
        .flags = 0x01,        // Mark as active
        .cycle_count = 0,
        .flash_loan_count = 0,
        .swap_count = 0,
        .tsc_last_update = 0,
        ._reserved = [_]u8{0} ** 44,
    };

    // Clear flash loan request slots
    var i: u32 = 0;
    while (i < types.MAX_FLASH_LOANS) : (i += 1) {
        const slot = getFlashLoanSlotPtr(i);
        slot.* = .{
            .status = 0,        // Idle
            .amount_lamports = 0,
            .input_mint = [_]u8{0} ** 32,
            .output_mint = [_]u8{0} ** 32,
            ._reserved = [_]u8{0} ** 96,
        };
    }

    initialized = true;
}

// ============================================================================
// Main Blockchain Cycle
// ============================================================================

/// Main blockchain processing cycle
/// Called repeatedly by Ada Mother OS scheduler
/// Week 5: Raydium flash loan integration + atomic swap execution
export fn run_blockchain_cycle() void {
    if (!initialized) return;

    // Check auth gate
    const auth = @as(*volatile u8, @ptrFromInt(types.KERNEL_AUTH)).*;
    if (auth != 0x70) return;

    const state = getBlockchainStatePtr();

    // === PHASE 11: AUTO-EXECUTE FLASH LOANS ON GRID PROFIT ===
    // Monitor Grid OS for profitable multi-exchange opportunities
    // Automatically request and execute flash loans with atomic swaps
    const monitor_result = flash_loan_executor.monitorAndExecute();
    if (monitor_result.executed) {
        flash_loan_count += monitor_result.loan_count;
    }

    // Process pending flash loans (max 8 per cycle for determinism)
    var processed: u32 = 0;
    const max_per_cycle: u32 = 8;

    var i: u32 = 0;
    while (i < types.MAX_FLASH_LOANS and processed < max_per_cycle) : (i += 1) {
        const slot = getFlashLoanSlotPtr(i);
        if (slot.status == 1) { // Request pending
            // Process flash loan with atomic swap
            processFlashLoanWithSwap(slot);
            slot.status = 2; // Mark as processing
            processed += 1;
            swap_count += 1;
        } else if (slot.status == 2) {
            // Pending execution — check if swap completed
            // In real system: RPC call to check transaction status
            slot.status = 3; // Mark as done (stub)
        }
    }

    // Update cycle counter
    cycle_count += 1;
    state.cycle_count = cycle_count;
    state.flash_loan_count = flash_loan_count;
    state.swap_count = swap_count;
    state.tsc_last_update = rdtsc();
}

// ============================================================================
// Flash Loan Processing (Week 5: Raydium Integration)
// ============================================================================

/// Process a single flash loan request with atomic swap execution
/// Week 5: Constructs Solana transaction with:
/// 1. Flash loan request (Raydium)
/// 2. Token swap (input_mint → output_mint)
/// 3. Loan repayment + fees
fn processFlashLoanWithSwap(slot: *volatile types.FlashLoanRequest) void {
    // Validate request parameters
    if (slot.amount_lamports == 0) return;
    if (isAllZerosVolatile(&slot.input_mint) or isAllZerosVolatile(&slot.output_mint)) return;

    // Construct atomic Solana transaction
    var tx = solana.create_transaction();

    // Step 1: Request flash loan from Raydium
    const flash_loan_instr = raydium.request_flash_loan(
        slot.amount_lamports,
        slot.input_mint,
        slot.output_mint
    );
    tx.instructions[tx.instruction_count] = flash_loan_instr;
    tx.instruction_count += 1;

    // Step 2: Execute token swap (input → output)
    // Calculate min_output based on slippage tolerance (1% = 0.99 * expected)
    const min_output = (slot.amount_lamports * 99) / 100; // 1% slippage

    const swap_instr = raydium.swap_tokens(
        slot.amount_lamports,
        min_output,
        slot.output_mint  // Use output_mint as pool identifier
    );
    tx.instructions[tx.instruction_count] = swap_instr;
    tx.instruction_count += 1;

    // Step 3: Repay flash loan with fee (0.05% = 0.0005)
    const repay_amount = slot.amount_lamports + (slot.amount_lamports / 2000);
    const repay_instr = raydium.repay_flash_loan(repay_amount);
    tx.instructions[tx.instruction_count] = repay_instr;
    tx.instruction_count += 1;

    // Step 4: Submit atomic transaction to Solana
    // In real system: would RPC call to submit_transaction()
    // For now: just count it
    _ = solana.submit_transaction(&tx);

    flash_loan_count += 1;
}

/// Check if a 32-byte mint address is all zeros
fn isAllZeros(mint: *const [32]u8) bool {
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        if (mint[i] != 0) return false;
    }
    return true;
}

/// Check if a volatile 32-byte mint address is all zeros
fn isAllZerosVolatile(mint: *volatile [32]u8) bool {
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        if (mint[i] != 0) return false;
    }
    return true;
}

/// Process a single flash loan request (legacy stub)
fn processFlashLoan(slot: *volatile types.FlashLoanRequest) void {
    // Legacy stub — now delegated to processFlashLoanWithSwap
    _ = slot;
    flash_loan_count += 1;
}

// ============================================================================
// Public Flash Loan API
// ============================================================================

/// Request a flash loan for atomic token swap
/// Week 5: Validates mint addresses and stores request for async processing
/// Returns: slot index (0-15) or 0xFFFFFFFF if no slots available
export fn request_flash_loan(
    amount_lamports: u64,
    input_mint_ptr: [*]const u8,
    output_mint_ptr: [*]const u8,
) u32 {
    // Validate input
    if (amount_lamports == 0) return 0xFFFFFFFF;

    // Find free slot
    var i: u32 = 0;
    while (i < types.MAX_FLASH_LOANS) : (i += 1) {
        const slot = getFlashLoanSlotPtr(i);
        if (slot.status == 0) { // Idle
            // Copy mint addresses (32 bytes each)
            @memcpy(slot.input_mint[0..32], input_mint_ptr[0..32]);
            @memcpy(slot.output_mint[0..32], output_mint_ptr[0..32]);
            slot.amount_lamports = amount_lamports;
            slot.status = 1; // Mark as pending
            return i;
        }
    }
    return 0xFFFFFFFF; // No free slots
}

/// Execute atomic token swap
/// Week 5: Can be called standalone (non-flash-loan swap) or as part of flash loan flow
export fn execute_atomic_swap(
    input_amount: u64,
    min_output: u64,
) bool {
    // Verify preconditions
    if (input_amount == 0 or min_output == 0) return false;
    if (min_output > input_amount) return false; // Sanity check

    // In real system: construct Solana transaction + submit to network
    // This executes a swap without flash loan (e.g., use existing tokens)
    swap_count += 1;
    return true;
}

/// Execute atomic swap given flash loan slot
/// Week 5: Used internally when processing flash loan requests
/// Returns: true if swap instruction was enqueued
export fn execute_swap_from_flash_loan(slot_idx: u32) bool {
    if (slot_idx >= types.MAX_FLASH_LOANS) return false;

    const slot = getFlashLoanSlotPtr(slot_idx);
    if (slot.status != 1 and slot.status != 2) return false; // Only from pending/processing

    // Verify amounts are valid
    if (slot.amount_lamports == 0) return false;

    // Queue swap for execution
    swap_count += 1;
    return true;
}

// ============================================================================
// Query Functions
// ============================================================================

/// Get current cycle count
export fn get_cycle_count() u64 {
    return cycle_count;
}

/// Get flash loan count
export fn get_flash_loan_count() u32 {
    return flash_loan_count;
}

/// Get swap count
export fn get_swap_count() u32 {
    return swap_count;
}

/// Get initialized state
export fn is_initialized() u8 {
    return if (initialized) 1 else 0;
}

/// Get count of pending flash loan requests (status == 1 or 2)
export fn get_pending_flash_loans() u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < types.MAX_FLASH_LOANS) : (i += 1) {
        const slot = getFlashLoanSlotPtr(i);
        if (slot.status == 1 or slot.status == 2) {
            count += 1;
        }
    }
    return count;
}

/// Get amount of a specific flash loan request (for monitoring)
export fn get_flash_loan_amount(slot_idx: u32) u64 {
    if (slot_idx >= types.MAX_FLASH_LOANS) return 0;
    const slot = getFlashLoanSlotPtr(slot_idx);
    return slot.amount_lamports;
}

// ============================================================================
// Debug & Testing Exports
// ============================================================================

/// Test: manually request a flash loan
export fn test_request_flash_loan(amount_lamports: u64) u32 {
    var input: [32]u8 = [_]u8{0} ** 32;
    var output: [32]u8 = [_]u8{0} ** 32;
    return request_flash_loan(amount_lamports, &input, &output);
}

/// Test: check flash loan status
export fn test_get_flash_loan_status(slot_idx: u32) u8 {
    if (slot_idx >= types.MAX_FLASH_LOANS) return 0;
    const slot = getFlashLoanSlotPtr(slot_idx);
    return slot.status;
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

// ============================================================================
// PHASE 10: IPC DISPATCHER (Kernel ↔ Module Communication)
// ============================================================================

/// IPC Control Block structure (shared with kernel @ 0x100110)
const IpcControlBlock = extern struct {
    request: u8,
    status: u8,
    module_id: u16,
    _pad: u32,
    cycle_count: u64,
    return_value: u64,
};

/// IPC Request Codes
const REQUEST_NONE = 0x00;
const REQUEST_BLOCKCHAIN_CYCLE = 0x01;

/// IPC Status Codes
const STATUS_IDLE = 0x00;
const STATUS_BUSY = 0x01;
const STATUS_DONE = 0x02;
const STATUS_ERROR = 0x03;

/// Get pointer to IPC control block (shared kernel memory)
fn getIpcBlockPtr() *volatile IpcControlBlock {
    return @as(*volatile IpcControlBlock, @ptrFromInt(0x100110));
}

/// IPC Dispatcher: Kernel calls this to invoke module functions
/// Returns 0 on success, non-zero on error
export fn ipc_dispatch() u64 {
    const ipc = getIpcBlockPtr();
    const req = ipc.request;

    // Initialize module on first call
    if (!initialized) {
        init_plugin();
    }

    // Route request to appropriate handler
    switch (req) {
        REQUEST_BLOCKCHAIN_CYCLE => {
            // Execute blockchain cycle
            run_blockchain_cycle();
            ipc.return_value = cycle_count;
            ipc.status = STATUS_DONE;
            return 0;  // Success
        },
        else => {
            // Unknown request
            ipc.return_value = 0;
            ipc.status = STATUS_ERROR;
            return 1;  // Error
        },
    }
}
