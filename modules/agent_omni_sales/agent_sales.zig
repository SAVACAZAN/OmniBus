// ============================================================================
// Agent OMNI Sales (Zig/Bare Metal)
// Agent sells 1M OMNI from genesis pool on all integrated chains
// Revenue → Liquidity Pool + Treasury Distribution
// ============================================================================

const std = @import("std");

// Memory layout (0x5B0000 – 0x5BFFFF, 64KB)
const AGENT_SALES_BASE: usize = 0x5B0000;

// Sale record (32 bytes each)
const SaleRecord = struct {
    chain_id: u8,                    // 1=ETH, 2=Base, 3=Bitcoin, 4=Solana, etc.
    sale_time: u64,                  // Timestamp (TSC)
    buyer_address: u64,              // Who bought
    omni_sold: u64,                  // How much OMNI sold
    price_per_omni: u64,             // Sale price (in USD or stablecoin)
    total_revenue: u64,              // omni_sold × price_per_omni
    status: u8,                      // 0=pending, 1=complete, 2=failed
    reserved: [7]u8,
};

// Agent Sales State (128 bytes @ 0x5B0000)
const AgentSalesState = struct {
    magic: u32 = 0x4147454E,        // "AGEN"
    version: u16 = 1,
    reserved: u16 = 0,

    // Inventory
    total_omni_pool: u64 = 1_000_000 * 1e18,     // 1 million OMNI
    omni_remaining: u64 = 1_000_000 * 1e18,     // Available for sale
    omni_sold: u64 = 0,                         // Total sold

    // Sales tracking
    total_sales: u32,                           // Number of sales
    total_revenue: u64,                         // USD revenue collected
    avg_price_per_omni: u64,                    // Average sale price

    // Chain presence (enabled/disabled)
    ethereum_enabled: u8 = 1,
    base_enabled: u8 = 1,
    bitcoin_enabled: u8 = 1,
    solana_enabled: u8 = 1,

    // Revenue distribution (% of revenue)
    liquidity_pool_pct: u8 = 40,               // 40% to liquidity
    treasury_pct: u8 = 30,                     // 30% to treasury
    dao_pct: u8 = 20,                          // 20% to DAO
    operations_pct: u8 = 10,                   // 10% to operations

    // Accounting
    revenue_liquidity: u64 = 0,
    revenue_treasury: u64 = 0,
    revenue_dao: u64 = 0,
    revenue_operations: u64 = 0,

    last_sale_time: u64 = 0,
};

// Sales storage (256 records @ 0x5B0080)
var sale_records: [256]SaleRecord = undefined;
var agent_state: AgentSalesState = .{
    .magic = 0x4147454E,
    .version = 1,
    .total_omni_pool = 1_000_000 * 1e18,
    .omni_remaining = 1_000_000 * 1e18,
    .omni_sold = 0,
    .total_sales = 0,
    .total_revenue = 0,
    .avg_price_per_omni = 0,
    .ethereum_enabled = 1,
    .base_enabled = 1,
    .bitcoin_enabled = 1,
    .solana_enabled = 1,
    .liquidity_pool_pct = 40,
    .treasury_pct = 30,
    .dao_pct = 20,
    .operations_pct = 10,
    .revenue_liquidity = 0,
    .revenue_treasury = 0,
    .revenue_dao = 0,
    .revenue_operations = 0,
    .last_sale_time = 0,
};

// ============================================================================
// PUBLIC API
// ============================================================================

pub fn init_plugin() void {
    // Clear sale records
    for (0..256) |i| {
        sale_records[i] = .{
            .chain_id = 0,
            .sale_time = 0,
            .buyer_address = 0,
            .omni_sold = 0,
            .price_per_omni = 0,
            .total_revenue = 0,
            .status = 0,
            .reserved = .{0} ** 7,
        };
    }
}

/// Agent sells OMNI on specified chain
/// Returns: 0=success, 1=insufficient_pool, 2=chain_disabled, 3=record_full
pub fn sell_omni(
    chain_id: u8,
    buyer_address: u64,
    omni_amount: u64,
    price_per_omni: u64,
) u8 {
    // Check if chain is enabled
    const enabled = switch (chain_id) {
        1 => agent_state.ethereum_enabled,  // ETH
        2 => agent_state.base_enabled,       // Base
        3 => agent_state.bitcoin_enabled,    // Bitcoin
        4 => agent_state.solana_enabled,     // Solana
        else => 0,
    };

    if (enabled == 0) {
        return 2; // Chain disabled
    }

    // Check if enough OMNI available
    if (agent_state.omni_remaining < omni_amount) {
        return 1; // Insufficient pool
    }

    // Find empty slot for sale record
    var slot: usize = undefined;
    var found = false;
    for (0..256) |i| {
        if (sale_records[i].chain_id == 0) {
            slot = i;
            found = true;
            break;
        }
    }

    if (!found) {
        return 3; // Record array full
    }

    // Calculate revenue
    const total_revenue = (omni_amount / 1e18) * price_per_omni;

    // Create sale record
    sale_records[slot] = .{
        .chain_id = chain_id,
        .sale_time = get_tsc(),
        .buyer_address = buyer_address,
        .omni_sold = omni_amount,
        .price_per_omni = price_per_omni,
        .total_revenue = total_revenue,
        .status = 1, // Complete
        .reserved = .{0} ** 7,
    };

    // Update inventory
    agent_state.omni_remaining -|= omni_amount;
    agent_state.omni_sold +|= omni_amount;
    agent_state.total_sales +|= 1;
    agent_state.total_revenue +|= total_revenue;
    agent_state.last_sale_time = get_tsc();

    // Update average price
    if (agent_state.total_sales > 0) {
        agent_state.avg_price_per_omni = agent_state.total_revenue / agent_state.omni_sold;
    }

    // Distribute revenue
    distribute_revenue(total_revenue);

    return 0; // Success
}

/// Get remaining OMNI available for sale
pub fn get_omni_remaining() u64 {
    return agent_state.omni_remaining;
}

/// Get total OMNI sold
pub fn get_omni_sold() u64 {
    return agent_state.omni_sold;
}

/// Get total revenue collected
pub fn get_total_revenue() u64 {
    return agent_state.total_revenue;
}

/// Get revenue breakdown
pub fn get_revenue_breakdown() struct {
    total: u64,
    liquidity: u64,
    treasury: u64,
    dao: u64,
    operations: u64,
} {
    return .{
        .total = agent_state.total_revenue,
        .liquidity = agent_state.revenue_liquidity,
        .treasury = agent_state.revenue_treasury,
        .dao = agent_state.revenue_dao,
        .operations = agent_state.revenue_operations,
    };
}

/// Get average price per OMNI
pub fn get_avg_price() u64 {
    return agent_state.avg_price_per_omni;
}

/// Get number of sales
pub fn get_total_sales_count() u32 {
    return agent_state.total_sales;
}

/// Enable/disable sales on a chain
pub fn set_chain_enabled(chain_id: u8, enabled: u8) void {
    switch (chain_id) {
        1 => agent_state.ethereum_enabled = enabled,
        2 => agent_state.base_enabled = enabled,
        3 => agent_state.bitcoin_enabled = enabled,
        4 => agent_state.solana_enabled = enabled,
        else => {},
    }
}

// ============================================================================
// IPC Interface (Opcodes 0xC1–0xC8)
// ============================================================================

pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0xC1 => sell_omni_ipc(arg0, arg1),          // sell_omni(chain, buyer, amount, price)
        0xC2 => get_remaining_ipc(),                // get_omni_remaining()
        0xC3 => get_sold_ipc(),                     // get_omni_sold()
        0xC4 => get_revenue_ipc(),                  // get_total_revenue()
        0xC5 => get_avg_price_ipc(),                // get_avg_price()
        0xC6 => get_sales_count_ipc(),              // get_total_sales_count()
        0xC7 => set_chain_ipc(arg0, arg1),          // set_chain_enabled(chain, enabled)
        0xC8 => run_sales_cycle(),                  // run_sales_cycle()
        else => 0xFFFFFFFF,
    };
}

fn sell_omni_ipc(params1: u64, params2: u64) u64 {
    // params1: [chain_id:8][buyer_addr:56]
    // params2: [omni_amount:64]
    // price_per_omni would need separate call or packed differently
    const chain_id: u8 = @intCast((params1 >> 56) & 0xFF);
    const buyer_address: u64 = params1 & 0x00FFFFFFFFFFFFFF;

    const result = sell_omni(chain_id, buyer_address, params2, 100); // Default price $100
    return if (result == 0) 1 else 0;
}

fn get_remaining_ipc() u64 {
    return get_omni_remaining();
}

fn get_sold_ipc() u64 {
    return get_omni_sold();
}

fn get_revenue_ipc() u64 {
    return get_total_revenue();
}

fn get_avg_price_ipc() u64 {
    return get_avg_price();
}

fn get_sales_count_ipc() u64 {
    return get_total_sales_count();
}

fn set_chain_ipc(chain_id: u64, enabled: u64) u64 {
    set_chain_enabled(@intCast(chain_id), @intCast(enabled));
    return 1;
}

fn run_sales_cycle() u64 {
    // Periodic sales maintenance
    agent_state.last_sale_time = get_tsc();
    return 1;
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

fn distribute_revenue(revenue: u64) void {
    // Distribute revenue according to percentages
    const liquidity = (revenue * agent_state.liquidity_pool_pct) / 100;
    const treasury = (revenue * agent_state.treasury_pct) / 100;
    const dao = (revenue * agent_state.dao_pct) / 100;
    const operations = (revenue * agent_state.operations_pct) / 100;

    agent_state.revenue_liquidity +|= liquidity;
    agent_state.revenue_treasury +|= treasury;
    agent_state.revenue_dao +|= dao;
    agent_state.revenue_operations +|= operations;
}

fn get_tsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile (
        \\rdtsc
        : [low] "=a" (low),
          [high] "=d" (high),
    );

    return (@as(u64, high) << 32) | low;
}
