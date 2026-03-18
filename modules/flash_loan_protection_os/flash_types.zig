pub const FLASH_BASE: usize = 0x460000;
pub const MAX_FLASH_LOANS: usize = 16;

pub const FlashLoan = extern struct {
    loan_id: u16,
    amount: u64,
    borrowed_cycle: u64,
    repaid_cycle: u64,
    status: u8,
    _pad: [7]u8 = [_]u8{0} ** 7,
};

pub const FlashLoanProtectionState = extern struct {
    magic: u32 = 0x464C4153,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    total_protected: u64,
    exploits_detected: u32,
    loans_tracked: u32,
    active_loans: u16,
    _pad2: [76]u8 = [_]u8{0} ** 76,
};
