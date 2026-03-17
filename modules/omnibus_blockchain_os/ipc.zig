// ipc.zig – Ada Mother OS IPC Protocol (bare-metal shared memory)
// Memory layout matches startup_phase4.asm ipc_control_block at 0x100110
//
// Protocol (module-initiated):
//   1. Write payload to module's own buffer (e.g. 0x130000 for Execution OS)
//   2. Write IPC_REQUEST_* code to ipc_request
//   3. Write module ID to ipc_module_id
//   4. Set ipc_status = STATUS_BUSY
//   5. Set auth gate at 0x100050 = IPC_AUTH_REQUEST
//   6. Spin-wait for ipc_status == STATUS_DONE (max IPC_SPIN_MAX iterations)
//   7. Read ipc_return_value for result

// ============================================================================
// IPC Control Block (0x100110) — mirrors Ada ipc_control_block
// ============================================================================

const IPC_BLOCK_BASE:  usize = 0x100110;
const IPC_AUTH_GATE:   usize = 0x100050;
const IPC_SPIN_MAX:    u32   = 1024;      // Max spin iterations (bare-metal, no sleep)

// Byte offsets within IPC block
const OFF_REQUEST:     usize = 0;   // u8:  request code
const OFF_STATUS:      usize = 1;   // u8:  status code
const OFF_MODULE_ID:   usize = 2;   // u16: module ID
const OFF_RESERVED:    usize = 4;   // u32: padding
const OFF_CYCLE_COUNT: usize = 8;   // u64: kernel cycle when request was made
const OFF_RETURN_VAL:  usize = 16;  // u64: return value from Ada (or module report)

// ============================================================================
// Request Codes (must match Ada's REQUEST_* equates)
// ============================================================================
pub const IPC_REQUEST_NONE:              u8 = 0x00;
pub const IPC_REQUEST_BLOCKCHAIN_CYCLE:  u8 = 0x01;
pub const IPC_REQUEST_NEURO_CYCLE:       u8 = 0x02;
pub const IPC_REQUEST_GRID_METRICS:      u8 = 0x03;
pub const IPC_REQUEST_REPORT_BLOCK:      u8 = 0x10; // module→Ada: report new block height

// ============================================================================
// Status Codes (must match Ada's STATUS_* equates)
// ============================================================================
pub const IPC_STATUS_IDLE:   u8 = 0x00;
pub const IPC_STATUS_BUSY:   u8 = 0x01;
pub const IPC_STATUS_DONE:   u8 = 0x02;
pub const IPC_STATUS_ERROR:  u8 = 0x03;

// ============================================================================
// Module IDs (must match Ada's MODULE_* equates)
// ============================================================================
pub const MODULE_BLOCKCHAIN:       u16 = 0x04;
pub const MODULE_NEURO:            u16 = 0x05;
pub const MODULE_OMNI_BLOCKCHAIN:  u16 = 0x10; // OmniBus Blockchain OS (Phase 66)

// Auth gate value written by module to signal Ada
pub const IPC_AUTH_REQUEST: u8 = 0x01;

// ============================================================================
// Volatile accessors
// ============================================================================

inline fn ipc_request_ptr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(IPC_BLOCK_BASE + OFF_REQUEST));
}
inline fn ipc_status_ptr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(IPC_BLOCK_BASE + OFF_STATUS));
}
inline fn ipc_module_id_ptr() *volatile u16 {
    return @as(*volatile u16, @ptrFromInt(IPC_BLOCK_BASE + OFF_MODULE_ID));
}
inline fn ipc_return_val_ptr() *volatile u64 {
    return @as(*volatile u64, @ptrFromInt(IPC_BLOCK_BASE + OFF_RETURN_VAL));
}
inline fn ipc_auth_gate_ptr() *volatile u8 {
    return @as(*volatile u8, @ptrFromInt(IPC_AUTH_GATE));
}

// ============================================================================
// Public API
// ============================================================================

/// Write a u64 value to the IPC return slot so Ada can read it passively.
/// Non-blocking: no spin-wait, just writes and returns. Used for metrics reporting.
pub fn report_metric(module_id: u16, value: u64) void {
    ipc_module_id_ptr().* = module_id;
    ipc_return_val_ptr().* = value;
}

/// Issue a request to Ada and spin-wait for completion.
/// Returns the return value, or 0xFFFFFFFFFFFFFFFF on timeout.
pub fn request(module_id: u16, req_code: u8, payload: u64) u64 {
    // Write payload first
    ipc_return_val_ptr().* = payload;
    ipc_module_id_ptr().*  = module_id;
    ipc_request_ptr().*    = req_code;
    ipc_status_ptr().*     = IPC_STATUS_BUSY;

    // Signal Ada via auth gate
    ipc_auth_gate_ptr().* = IPC_AUTH_REQUEST;

    // Spin-wait for Ada to process (max IPC_SPIN_MAX iterations)
    var i: u32 = 0;
    while (i < IPC_SPIN_MAX) : (i += 1) {
        const status = ipc_status_ptr().*;
        if (status == IPC_STATUS_DONE or status == IPC_STATUS_ERROR) {
            const ret = ipc_return_val_ptr().*;
            ipc_status_ptr().* = IPC_STATUS_IDLE;
            ipc_request_ptr().* = IPC_REQUEST_NONE;
            return ret;
        }
        asm volatile ("pause");
    }

    // Timeout: reset and return sentinel
    ipc_status_ptr().* = IPC_STATUS_IDLE;
    ipc_request_ptr().* = IPC_REQUEST_NONE;
    return 0xFFFFFFFF_FFFFFFFF;
}

/// Read the current IPC status (non-blocking).
pub fn get_status() u8 {
    return ipc_status_ptr().*;
}

/// Read the return value written by Ada (non-blocking).
pub fn get_return_val() u64 {
    return ipc_return_val_ptr().*;
}
