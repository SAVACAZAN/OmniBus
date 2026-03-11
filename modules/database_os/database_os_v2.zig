// database_os_v2.zig — Phase 62A: Enhanced Database with Idempotency
// Exactly-once semantics via idempotency keys + QUORUM consistency

const std = @import("std");
const types = @import("database_types_v2.zig");

fn getDatabaseStatePtr() *volatile types.DatabaseOsState {
    return @as(*volatile types.DatabaseOsState, @ptrFromInt(types.DB_BASE));
}

fn getTradePtr(index: usize) *volatile types.TradeRecord {
    if (index >= types.MAX_TRADES) return undefined;
    const base = types.DB_BASE + @sizeOf(types.DatabaseOsState);
    return @as(*volatile types.TradeRecord, @ptrFromInt(base + index * @sizeOf(types.TradeRecord)));
}

fn getIdempotencyPtr(index: usize) *volatile types.IdempotencyCheck {
    if (index >= types.MAX_TRADES) return undefined;
    const base = types.DB_BASE + @sizeOf(types.DatabaseOsState) +
                 types.MAX_TRADES * @sizeOf(types.TradeRecord);
    return @as(*volatile types.IdempotencyCheck, @ptrFromInt(base + index * @sizeOf(types.IdempotencyCheck)));
}

export fn init_plugin() void {
    const state = getDatabaseStatePtr();
    state.magic = 0x4442545335;  // 'DBTS' (v2)
    state.flags = 0x01;
    state.cycle_count = 0;
    state.total_trades_persisted = 0;
    state.total_trades_failed = 0;
    state.total_replication_sends = 0;
    state.total_replication_acks = 0;
    state.total_duplicates_detected = 0;
    state.primary_dc = 0;  // Microsoft Azure
    state.secondary_dc1 = 1;  // Oracle Cloud
    state.secondary_dc2 = 2;  // AWS
    state.consistency_level = 1;  // QUORUM
    state.last_persisted_trade_id = 0;

    var i: usize = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const trade = getTradePtr(i);
        trade.trade_id = 0;
        trade.idempotency_key = 0;
        trade.timestamp = 0;
        trade.status = 0;
        trade.consensus_reached = 0;
    }

    i = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const idempotency = getIdempotencyPtr(i);
        idempotency.idempotency_key = 0;
        idempotency.trade_id = 0;
        idempotency.last_write_cycle = 0;
        idempotency.status = 0;
    }
}

// Check if idempotency key already processed (prevent duplicate writes)
fn check_idempotency(idempotency_key: u64) u8 {
    var i: usize = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const idempotency = getIdempotencyPtr(i);
        if (idempotency.idempotency_key == idempotency_key) {
            if (idempotency.status == 1) {
                return 1;  // Already acknowledged
            }
        }
    }
    return 0;  // Not found (new key)
}

export fn persist_trade_idempotent(trade: types.TradeRecord) bool {
    const state = getDatabaseStatePtr();

    // Step 1: Check if this idempotency key was already processed
    if (check_idempotency(trade.idempotency_key) == 1) {
        state.total_duplicates_detected +|= 1;
        return false;  // Duplicate, reject
    }

    // Step 2: Find empty slot for new trade
    var i: usize = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const slot = getTradePtr(i);
        if (slot.trade_id == 0) {
            // Step 3: Write trade to database
            slot.trade_id = trade.trade_id;
            slot.idempotency_key = trade.idempotency_key;
            slot.timestamp = trade.timestamp;
            slot.symbol = trade.symbol;
            slot.quantity = trade.quantity;
            slot.price = trade.price;
            slot.status = @intFromEnum(types.TradeStatus.pending);
            slot.provider_mask = trade.provider_mask;
            slot.consensus_reached = 0;
            slot.correlation_id = trade.correlation_id;

            // Step 4: Record idempotency key with QUORUM in-flight
            const idempotency = getIdempotencyPtr(i);
            idempotency.idempotency_key = trade.idempotency_key;
            idempotency.trade_id = trade.trade_id;
            idempotency.last_write_cycle = state.cycle_count;
            idempotency.status = 0;  // PENDING

            state.total_trades_persisted +|= 1;
            state.last_persisted_trade_id = trade.trade_id;
            return true;
        }
    }

    state.total_trades_failed +|= 1;
    return false;  // No slot available
}

export fn mark_idempotency_acknowledged(idempotency_key: u64) void {
    const state = getDatabaseStatePtr();
    var i: usize = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const idempotency = getIdempotencyPtr(i);
        if (idempotency.idempotency_key == idempotency_key) {
            idempotency.status = 1;  // ACKNOWLEDGED (QUORUM confirmed)
            state.total_replication_acks +|= 1;
            return;
        }
    }
}

export fn run_database_cycle() void {
    const state = getDatabaseStatePtr();
    state.cycle_count +|= 1;

    // Process pending replications (QUORUM consistency)
    // In real system, this would send to Cassandra nodes via CassandraOS
    var pending_count: u32 = 0;
    var i: usize = 0;
    while (i < types.MAX_TRADES) : (i += 1) {
        const idempotency = getIdempotencyPtr(i);
        if (idempotency.idempotency_key != 0 and idempotency.status == 0) {
            pending_count +|= 1;
            // Simulate QUORUM send (actual: CassandraOS handles 3-replica consensus)
            if (state.cycle_count % 256 == 0) {
                state.total_replication_sends +|= 1;
            }
        }
    }
}

export fn get_persisted_trades() u32 {
    return getDatabaseStatePtr().total_trades_persisted;
}

export fn get_duplicates_prevented() u32 {
    return getDatabaseStatePtr().total_duplicates_detected;
}

export fn get_cycle_count() u64 {
    return getDatabaseStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getDatabaseStatePtr();
    return if (state.magic == 0x4442545335) 1 else 0;
}
