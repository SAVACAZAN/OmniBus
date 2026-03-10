pub const STAKING_BASE: usize = 0x420000;
pub const MAX_VALIDATORS: usize = 32;

pub const ValidatorStake = extern struct {
    validator_id: u16,
    stake_amount: u64,
    reward_earned: u64,
    slashing_events: u16,
    status: u8,
    _pad: u8 = 0,
};

pub const LiquidStakingState = extern struct {
    magic: u32 = 0x5354414B,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    total_staked: u64,
    total_rewards: u64,
    active_validators: u16,
    pending_unstakes: u16,
    avg_apr: u32,
    _pad2: [72]u8 = [_]u8{0} ** 72,
};
