const std = @import("std");
const types = @import("multi_node_federation_types.zig");

fn getMNFStatePtr() *volatile types.MNFState {
    return @as(*volatile types.MNFState, @ptrFromInt(types.MNF_BASE));
}

fn getNodeDescriptorPtr(index: usize) *volatile types.NodeDescriptor {
    if (index >= types.MAX_NODES) return undefined;
    const base = types.MNF_BASE + @sizeOf(types.MNFState);
    return @as(*volatile types.NodeDescriptor, @ptrFromInt(base + index * @sizeOf(types.NodeDescriptor)));
}

export fn init_plugin() void {
    const state = getMNFStatePtr();
    state.magic = 0x4D4E4644;
    state.flags = 0x01;
    state.cycle_count = 0;
    state.node_count = 0;
    state.active_nodes = 0;
    state.this_node_id = 1;
    state.total_messages = 0;
    state.total_heartbeats = 0;
    state.split_brain_detected = 0;
    state.last_quorum_cycle = 0;

    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodeDescriptorPtr(i);
        node.node_id = 0;
        node.status = 0;
        node.ip_packed = 0;
        node.port = 0;
        node.last_seen_cycle = 0;
        node.messages_sent = 0;
        node.messages_recv = 0;
    }
}

export fn run_federation_cycle() void {
    const state = getMNFStatePtr();
    state.cycle_count +|= 1;

    var active: u8 = 0;
    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodeDescriptorPtr(i);
        if (node.node_id == 0) continue;

        const cycles_since_heartbeat = state.cycle_count - node.last_seen_cycle;
        if (cycles_since_heartbeat > types.HEARTBEAT_TIMEOUT) {
            node.status = 0;
        } else if (node.status != 0) {
            active += 1;
        }
    }

    state.active_nodes = active;

    if (state.node_count > 0 and active < (state.node_count + 1) / 2) {
        state.split_brain_detected = 1;
    } else {
        state.split_brain_detected = 0;
        if (active > 0) {
            state.last_quorum_cycle = state.cycle_count;
        }
    }
}

export fn register_node(node_id: u8, ip: u32, port: u16) bool {
    const state = getMNFStatePtr();
    if (state.node_count >= types.MAX_NODES) return false;

    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodeDescriptorPtr(i);
        if (node.node_id == 0) {
            node.node_id = node_id;
            node.status = 1;
            node.ip_packed = ip;
            node.port = port;
            node.last_seen_cycle = state.cycle_count;
            state.node_count += 1;
            return true;
        }
    }
    return false;
}

export fn heartbeat_node(node_id: u8) bool {
    const state = getMNFStatePtr();
    var i: usize = 0;
    while (i < types.MAX_NODES) : (i += 1) {
        const node = getNodeDescriptorPtr(i);
        if (node.node_id == node_id) {
            node.last_seen_cycle = state.cycle_count;
            node.status = 1;
            state.total_heartbeats += 1;
            return true;
        }
    }
    return false;
}

export fn get_node_count() u8 {
    return getMNFStatePtr().node_count;
}

export fn get_active_nodes() u8 {
    return getMNFStatePtr().active_nodes;
}

export fn is_split_brain() u8 {
    return getMNFStatePtr().split_brain_detected;
}

export fn get_cycle_count() u64 {
    return getMNFStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getMNFStatePtr();
    return if (state.magic == 0x4D4E4644) 1 else 0;
}

// ============================================================================
// Cloud Federation Functions (Phase 56)
// ============================================================================

fn getCloudNodePtr(index: usize) *volatile types.CloudNodeDescriptor {
    if (index >= types.MAX_CLOUD_NODES) return undefined;
    const base = types.CLOUD_NODES_BASE;
    return @as(*volatile types.CloudNodeDescriptor, @ptrFromInt(base + index * @sizeOf(types.CloudNodeDescriptor)));
}

/// Register a cloud node (AWS/Azure/GCP/Oracle)
pub export fn cloud_register_node(
    provider: u8,
    region_hash: u64,
) u8 {
    const state = getMNFStatePtr();

    if (state.cloud_node_count >= types.MAX_CLOUD_NODES) return 0xFF;

    const idx = state.cloud_node_count;
    const node = getCloudNodePtr(idx);

    node.node_id = @as(u32, @intCast(idx));
    node.region_hash = region_hash;
    node.provider = provider;
    node.is_primary = if (idx == 0) 1 else 0;  // First node is primary
    node.latency_cycles = 0;
    node.last_heartbeat = 0;

    state.cloud_node_count += 1;

    // Set primary region if this is first node
    if (idx == 0) {
        state.primary_region_hash = region_hash;
    }

    return @as(u8, @intCast(idx));
}

/// Elect primary region based on lowest latency
pub export fn cloud_elect_primary() u64 {
    const state = getMNFStatePtr();

    if (state.cloud_node_count == 0) return 0;

    var min_latency: u64 = 0xFFFFFFFFFFFFFFFF;
    var best_hash: u64 = 0;
    var best_idx: u8 = 0;

    var i: u8 = 0;
    while (i < state.cloud_node_count) : (i += 1) {
        const node = getCloudNodePtr(i);
        if (node.latency_cycles < min_latency) {
            min_latency = node.latency_cycles;
            best_hash = node.region_hash;
            best_idx = i;
        }
    }

    // Update primary
    var j: u8 = 0;
    while (j < state.cloud_node_count) : (j += 1) {
        const node = getCloudNodePtr(j);
        node.is_primary = if (j == best_idx) 1 else 0;
    }

    state.primary_region_hash = best_hash;
    return best_hash;
}

/// Failover to secondary region
pub export fn cloud_failover() u8 {
    const state = getMNFStatePtr();

    if (state.cloud_node_count < 2) return 0;

    // Find secondary (non-primary) with lowest latency
    var min_latency: u64 = 0xFFFFFFFFFFFFFFFF;
    var secondary_idx: u8 = 0;

    var i: u8 = 0;
    while (i < state.cloud_node_count) : (i += 1) {
        const node = getCloudNodePtr(i);
        if (node.is_primary == 0 and node.latency_cycles < min_latency) {
            min_latency = node.latency_cycles;
            secondary_idx = i;
        }
    }

    // Promote secondary to primary
    var j: u8 = 0;
    while (j < state.cloud_node_count) : (j += 1) {
        const node = getCloudNodePtr(j);
        node.is_primary = if (j == secondary_idx) 1 else 0;
    }

    const new_primary = getCloudNodePtr(secondary_idx);
    state.primary_region_hash = new_primary.region_hash;
    state.failover_region_hash = new_primary.region_hash;

    return 1;
}

/// Broadcast DAO vote to all active cloud nodes
pub export fn cloud_broadcast_vote(
    _: u32,
    _: u8,
) u8 {
    const state = getMNFStatePtr();

    var active_count: u8 = 0;
    var i: u8 = 0;

    while (i < state.cloud_node_count) : (i += 1) {
        const node = getCloudNodePtr(i);
        if (node.last_heartbeat > 0) {  // Has heartbeat = alive
            active_count += 1;
        }
    }

    // Replicate vote to all active nodes via IPC
    // For now, return count of nodes that received vote
    return active_count;
}

/// Check geographic redundancy (3+ different providers)
pub export fn cloud_check_geo_redundancy() u8 {
    const state = getMNFStatePtr();

    if (state.cloud_node_count < 3) return 0;

    var providers_seen: u8 = 0;
    var provider_flags: u8 = 0;

    var i: u8 = 0;
    while (i < state.cloud_node_count) : (i += 1) {
        const node = getCloudNodePtr(i);
        const shift_amt = @as(u3, @intCast(node.provider & 0x07));
        const provider_bit = @as(u8, @intCast(1)) << shift_amt;
        if ((provider_flags & provider_bit) == 0) {
            provider_flags |= provider_bit;
            providers_seen += 1;
        }
    }

    // Return 1 if 3+ different providers are active
    return if (providers_seen >= 3) 1 else 0;
}

/// Get cloud node count
pub export fn cloud_get_node_count() u8 {
    return getMNFStatePtr().cloud_node_count;
}

/// Update cloud node latency
pub export fn cloud_update_latency(node_id: u32, latency: u64) u8 {
    if (node_id >= types.MAX_CLOUD_NODES) return 0;

    const node = getCloudNodePtr(node_id);
    node.latency_cycles = latency;
    node.last_heartbeat = latency;  // Use latency as timestamp stub

    return 1;
}

// ============================================================================
// IPC Dispatcher
// ============================================================================

pub export fn ipc_dispatch() u64 {
    const ipc_req = @as(*volatile u8, @ptrFromInt(0x100110));
    const ipc_status = @as(*volatile u8, @ptrFromInt(0x100111));
    const ipc_result = @as(*volatile u64, @ptrFromInt(0x100120));

    const state = getMNFStatePtr();
    if (state.magic != 0x4D4E4644) {
        init_plugin();
    }

    const request = ipc_req.*;
    var result: u64 = 0;

    switch (request) {
        0x51 => {  // CLOUD_REGISTER_NODE
            const provider = @as(u8, @intCast(ipc_result.* & 0xFF));
            const region_hash = ipc_result.* >> 8;
            result = cloud_register_node(provider, region_hash);
        },
        0x52 => {  // CLOUD_ELECT_PRIMARY
            result = cloud_elect_primary();
        },
        0x53 => {  // CLOUD_FAILOVER
            result = cloud_failover();
        },
        0x54 => {  // CLOUD_BROADCAST_VOTE
            const prop_id = @as(u32, @intCast(ipc_result.* & 0xFFFFFFFF));
            const vote_type = @as(u8, @intCast((ipc_result.* >> 32) & 0xFF));
            result = cloud_broadcast_vote(prop_id, vote_type);
        },
        0x55 => {  // CLOUD_GET_NODE_COUNT
            result = cloud_get_node_count();
        },
        0x56 => {  // CLOUD_CHECK_GEO_REDUNDANCY
            result = cloud_check_geo_redundancy();
        },
        else => {
            ipc_status.* = 0x03;  // Error
            return 1;
        },
    }

    ipc_status.* = 0x02;  // Done
    ipc_result.* = result;
    return 0;
}
