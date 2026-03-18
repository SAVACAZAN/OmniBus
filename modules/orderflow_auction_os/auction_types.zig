pub const AUCTION_BASE: usize = 0x440000;
pub const MAX_BUNDLES: usize = 32;

pub const EncryptedBundle = extern struct {
    bundle_id: u16,
    encrypted_payload: u64,
    bid_amount: u64,
    auction_cycle: u64,
    status: u8,
    _pad: [7]u8 = [_]u8{0} ** 7,
};

pub const OrderflowAuctionState = extern struct {
    magic: u32 = 0x4F524441,
    flags: u8,
    _pad1: [3]u8 = [_]u8{0} ** 3,
    cycle_count: u64,
    bundles_auctioned: u32,
    mev_captured: u64,
    total_revenue: u64,
    active_bundles: u8,
    _pad2: [79]u8 = [_]u8{0} ** 79,
};
