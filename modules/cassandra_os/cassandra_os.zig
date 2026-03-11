// cassandra_os.zig — Multi-DC Event Sourcing (Phase 58B)
// Cassandra: 3-replica ring (Microsoft + Oracle + AWS)

const std = @import("std");
const types = @import("cassandra_types.zig");

fn getCassandraStatePtr() *volatile types.CassandraOsState {
    return @as(*volatile types.CassandraOsState, @ptrFromInt(types.CASSANDRA_BASE));
}

fn getNodePtr(index: usize) *volatile types.CassandraNode {
    if (index >= types.MAX_NODES) return undefined;
    const base = types.CASSANDRA_BASE + @sizeOf(types.CassandraOsState);
    return @as(*volatile types.CassandraNode, @ptrFromInt(base + index * @sizeOf(types.CassandraNode)));
}

fn getWriteIntentPtr(index: usize) *volatile types.WriteIntent {
    if (index >= types.MAX_PENDING_WRITES) return undefined;
    const base = types.CASSANDRA_BASE + @sizeOf(types.CassandraOsState) +
                 types.MAX_NODES * @sizeOf(types.CassandraNode);
    return @as(*volatile types.WriteIntent, @ptrFromInt(base + index * @sizeOf(types.WriteIntent)));
}

export fn init_plugin() void {
    const state = getCassandraStatePtr();
    state.magic = 0x43415353;  // 'CASS'
    state.flags = 0x01;
    state.cycle_count = 0;
    state.node_count = 0;
    state.ring_status = 0;  // INITIALIZING
    state.total_writes_queued = 0;
    state.total_writes_replicated = 0;
    state.total_write_failures = 0;
    state.ms_dc_nodes_up = 0;
    state.oracle_dc_nodes_up = 0;
    state.aws_dc_nodes_up = 0;

    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodePtr(i);
        node.node_id = 0;
        node.status = 0;
    }

    i = 0;
    while (i < types.MAX_PENDING_WRITES) : (i += 1) {
        const write = getWriteIntentPtr(i);
        write.transaction_id = 0;
        write.status = 0;
    }
}

export fn register_cassandra_node(node_id: u8, dc: u8, token: u64, host: [*]const u8, port: u16) bool {
    const state = getCassandraStatePtr();
    if (state.node_count >= types.MAX_NODES) return false;

    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodePtr(i);
        if (node.node_id == 0) {
            node.node_id = node_id;
            node.datacenter = dc;
            node.token = token;
            node.port = port;
            node.status = 1;  // UP
            node.last_heartbeat = state.cycle_count;

            var j: usize = 0;
            while (j < 128 and host[j] != 0) : (j += 1) {
                node.host[j] = host[j];
            }

            state.node_count +|= 1;

            switch (dc) {
                0 => state.ms_dc_nodes_up +|= 1,
                1 => state.oracle_dc_nodes_up +|= 1,
                2 => state.aws_dc_nodes_up +|= 1,
                else => {},
            }

            return true;
        }
    }
    return false;
}

export fn run_cassandra_cycle() void {
    const state = getCassandraStatePtr();
    state.cycle_count +|= 1;

    // Check node heartbeats (timeout: 262144 cycles = ~1 second)
    var ms_up: u8 = 0;
    var oracle_up: u8 = 0;
    var aws_up: u8 = 0;

    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodePtr(i);
        if (node.node_id == 0) continue;

        const cycles_since_heartbeat = state.cycle_count - node.last_heartbeat;
        if (cycles_since_heartbeat > 262144) {
            node.status = 0;  // DOWN
        } else if (node.status == 1) {
            switch (node.datacenter) {
                0 => ms_up +|= 1,
                1 => oracle_up +|= 1,
                2 => aws_up +|= 1,
                else => {},
            }
        }
    }

    state.ms_dc_nodes_up = ms_up;
    state.oracle_dc_nodes_up = oracle_up;
    state.aws_dc_nodes_up = aws_up;

    // Ring status update
    if (ms_up >= 1 and oracle_up >= 1 and aws_up >= 1) {
        state.ring_status = 2;  // STEADY (all DCs online)
    } else if (ms_up > 0 or oracle_up > 0 or aws_up > 0) {
        state.ring_status = 3;  // RECOVERING (partial)
    } else {
        state.ring_status = 0;  // INITIALIZING (all down)
    }

    // Process pending writes (QUORUM consistency)
    var writes_replicated: u32 = 0;
    i = 0;
    while (i < types.MAX_PENDING_WRITES) : (i += 1) {
        const write = getWriteIntentPtr(i);
        if (write.transaction_id == 0 or write.status == 1) continue;
        if (write.status != 0) continue;  // Only process PENDING

        if (write.consistency_level == 1) {  // QUORUM
            const acks_needed: u8 = 2;  // Need 2 of 3 DCs
            var acks_received: u8 = 0;

            if (ms_up > 0) acks_received +|= 1;
            if (oracle_up > 0) acks_received +|= 1;
            if (aws_up > 0) acks_received +|= 1;

            if (acks_received >= acks_needed) {
                write.status = 2;  // ACKNOWLEDGED
                write.replicas_acked = acks_received;
                writes_replicated +|= 1;
                state.total_writes_replicated +|= 1;
            }
        }
    }
}

export fn queue_write_intent(write: types.WriteIntent) bool {
    const state = getCassandraStatePtr();

    var i: usize = 0;
    while (i < types.MAX_PENDING_WRITES) : (i += 1) {
        const slot = getWriteIntentPtr(i);
        if (slot.transaction_id == 0) {
            slot.transaction_id = write.transaction_id;
            slot.trade_id = write.trade_id;
            slot.correlation_id = write.correlation_id;
            slot.consistency_level = write.consistency_level;
            slot.status = 0;  // PENDING
            slot.replicas_acked = 0;

            state.total_writes_queued +|= 1;
            return true;
        }
    }

    state.total_write_failures +|= 1;
    return false;
}

export fn get_node_count() u8 {
    return getCassandraStatePtr().node_count;
}

export fn get_ring_status() u8 {
    return getCassandraStatePtr().ring_status;
}

export fn get_writes_replicated() u32 {
    return getCassandraStatePtr().total_writes_replicated;
}

export fn heartbeat_node(node_id: u8) void {
    const state = getCassandraStatePtr();
    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodePtr(i);
        if (node.node_id == node_id) {
            node.last_heartbeat = state.cycle_count;
            node.status = 1;  // UP
            return;
        }
    }
}

export fn get_cycle_count() u64 {
    return getCassandraStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getCassandraStatePtr();
    return if (state.magic == 0x43415353) 1 else 0;
}
