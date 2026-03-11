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
