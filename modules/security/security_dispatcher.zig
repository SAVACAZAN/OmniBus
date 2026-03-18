// Security Dispatcher (Phase 52E): Coordinates all 7 security modules
// Purpose: Initialize and dispatch all modules in correct order
// Dispatch: Called every 262K cycles from main scheduler
// Safety: HAP Protocol activation, read-only access to Tier 1

const std = @import("std");

// Module entry points (these would be imported from respective modules in real build)
// For now, we define them as external symbols

extern fn savaos_init_plugin() void;
extern fn savaos_run_cycle() void;

extern fn cazanos_init_plugin() void;
extern fn cazanos_run_cycle() void;

extern fn savacazanos_init_plugin() void;
extern fn savacazanos_run_cycle() void;

extern fn vortex_init_plugin() void;
extern fn vortex_run_cycle() void;

extern fn triage_init_plugin() void;
extern fn triage_run_cycle() void;

extern fn consensus_init_plugin() void;
extern fn consensus_run_cycle() void;

extern fn zen_init_plugin() void;
extern fn zen_run_cycle() void;

const DISPATCHER_BASE: usize = 0x3C0000;  // After security segment

pub const DispatcherHeader = packed struct {
    magic: u32 = 0x44495350,            // "DISP"
    version: u32 = 2,
    cycle_count: u64 = 0,
    activation_complete: u32 = 0,       // 1 when all modules initialized
    security_status: u32 = 0,           // Bitmask of module health
    reserved: [44]u8 = [_]u8{0} ** 44,
};

pub fn init_security_layer() void {
    // Initialize all 7 modules in order
    // SAVAos → CAZANos → SAVACAZANos → Vortex → Triage → Consensus → Zen

    savaos_init_plugin();
    cazanos_init_plugin();
    savacazanos_init_plugin();
    vortex_init_plugin();
    triage_init_plugin();
    consensus_init_plugin();
    zen_init_plugin();

    // Mark initialization complete
    const header = @as(*DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));
    header.magic = 0x44495350;
    header.version = 2;
    header.activation_complete = 1;
}

pub fn run_security_cycle() void {
    // Called every 262K cycles from main scheduler
    // Dispatch in correct order (one-way flow)

    const header = @as(*DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));

    if (header.activation_complete == 0) {
        init_security_layer();
        return;
    }

    // Dispatch each module in sequence
    // L15: SAVAos - Identity validation (reads Tier 1)
    savaos_run_cycle();
    update_module_status(0);  // Module 0 healthy

    // L16: CAZANos - Subsystem verification (reads SAVAos)
    cazanos_run_cycle();
    update_module_status(1);  // Module 1 healthy

    // L17: SAVACAZANos - Unified permissions (reads SAVAos + CAZANos)
    savacazanos_run_cycle();
    update_module_status(2);  // Module 2 healthy

    // L18: Vortex Bridge - Message routing (async)
    vortex_run_cycle();
    update_module_status(3);  // Module 3 healthy

    // L19: Triage System - Alert priority queue
    triage_run_cycle();
    update_module_status(4);  // Module 4 healthy

    // L20: Consensus Core - Quorum voting (delayed decision)
    consensus_run_cycle();
    update_module_status(5);  // Module 5 healthy

    // L21: Zen.OS - State checkpoint (background persistence)
    zen_run_cycle();
    update_module_status(6);  // Module 6 healthy

    header.cycle_count += 1;
}

fn update_module_status(module_id: u32) void {
    const header = @as(*DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));
    // Set bit for module (module 0 = bit 0, etc.)
    header.security_status |= (1 << @intCast(u5, module_id));
}

// ============================================================================
// ENTRY POINTS FOR KERNEL
// ============================================================================

pub export fn init_security_dispatcher() void {
    init_security_layer();
}

pub export fn dispatch_security() void {
    run_security_cycle();
}

// ============================================================================
// STATUS REPORTING
// ============================================================================

pub fn get_security_status() u32 {
    const header = @as(*const DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));
    return header.security_status;
}

pub fn is_security_ready() bool {
    const header = @as(*const DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));
    // All 7 modules ready if bits 0-6 set = 0x7F
    return (header.security_status & 0x7F) == 0x7F;
}

pub fn get_dispatch_cycle_count() u64 {
    const header = @as(*const DispatcherHeader, @ptrFromInt(DISPATCHER_BASE));
    return header.cycle_count;
}
