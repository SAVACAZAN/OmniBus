const types = @import("flash_types.zig");

fn getFlashStatePtr() *volatile types.FlashLoanProtectionState {
    return @as(*volatile types.FlashLoanProtectionState, @ptrFromInt(types.FLASH_BASE));
}

pub fn init_plugin() void {
    const state = getFlashStatePtr();
    state.magic = 0x464C4153;
    state.flags = 0;
    state.cycle_count = 0;
    state.total_protected = 0;
    state.exploits_detected = 0;
    state.loans_tracked = 0;
    state.active_loans = 0;
}

pub fn track_flash_loan(amount: u64) void {
    const state = getFlashStatePtr();
    state.loans_tracked +|= 1;
    state.total_protected +|= amount;
    state.active_loans +|= 1;
}

pub fn detect_exploit() void {
    const state = getFlashStatePtr();
    state.exploits_detected +|= 1;
}

pub fn run_flash_cycle() void {
    const state = getFlashStatePtr();
    state.cycle_count +|= 1;
}
