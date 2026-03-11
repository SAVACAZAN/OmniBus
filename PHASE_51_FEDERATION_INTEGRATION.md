# Phase 51B: Federation OS + Domain Resolver Integration

**Purpose**: Eliminate duplication by having Federation OS orchestrate domain resolution requests across all modules.

---

## Architecture: Unified Domain Resolution via Federation OS

```
GridOS              ExecutionOS            BlockchainOS
  │                   │                        │
  └─ needs address ────┼─────┬────────────────┘
                       │     │
                   Federation OS (L18)
                   Message Router @ 0x3A0000
                       │
                       ├─ Request ID: auto-increment
                       ├─ Type: ResolveDomain (new)
                       ├─ Payload: domain_hash (u64)
                       └─ Deadline: current_cycle + 100
                       │
                   Domain Resolver OS (L26)
                   Cache @ 0x4E0000
                       │
                       ├─ Cache hit → reply with address
                       ├─ Cache miss → mark PENDING
                       │              → escalate to feeder
                       └─ Forward reply back via Federation
                       │
                    ens_feeder.py
                    External Process
                       │
                       └─ Updates cache when done
```

---

## Implementation: Federation Message Types

### 1. Update federation_types.zig

Add new message type for domain resolution:

```zig
pub const MessageType = enum(u8) {
    QueryState = 0,
    UpdateParam = 1,
    TriggerAlert = 2,
    RequestOrder = 3,
    RequestVote = 4,
    BroadcastEvent = 5,
    AckMessage = 6,
    ErrorReply = 7,

    // Phase 51: Domain Resolution
    ResolveDomain = 8,         // Request domain resolution
    DomainResolved = 9,        // Reply with resolved address
};

// Payload type codes for domain messages
pub const PAYLOAD_DOMAIN_HASH = 0x10;      // u64 domain hash
pub const PAYLOAD_DOMAIN_CHAIN = 0x11;     // u8 chain_id
pub const PAYLOAD_DOMAIN_ADDRESS = 0x12;   // [32]u8 resolved address
```

### 2. Federation Module Registration

Each module registers with Federation OS to receive domain resolution:

```zig
// In BlockchainOS init
export fn register_with_federation() void {
    // Tell Federation: I'm module 5 (BlockchainOS)
    // I can handle domain resolutions
    federation_os.register_module(5, MessageType.ResolveDomain);
}
```

### 3. Domain Resolution Request Flow

**GridOS wants to resolve "vitalik.eth"**:

```zig
// GridOS (L1) → Federation OS (L18) → Domain Resolver (L26)

// Step 1: GridOS sends request via Federation
const domain_hash = domain_resolver.computeENSNameHash("vitalik.eth");
const msg_id = federation_os.send_message(
    .{
        .src_module = 1,                    // GridOS
        .dst_module = 26,                   // Domain Resolver
        .msg_type = MessageType.ResolveDomain,
        .payload_type = PAYLOAD_DOMAIN_HASH,
        .payload = @as(i64, @intCast(domain_hash)),
        .deadline_cycle = cycle_count + 100,
    }
);

// Step 2: GridOS waits for reply
// (can continue other work, check for message later)
```

**Domain Resolver processes request**:

```zig
// Domain Resolver cycle:
// 1. Check message queue from Federation
// 2. If message.msg_type == ResolveDomain:
//    a. Extract domain_hash from payload
//    b. Look up in cache
//    c. If cached: send reply immediately
//    d. If not cached: mark PENDING, escalate to feeder

export fn process_federation_request(msg: *const FederationMessage) void {
    if (msg.msg_type != MessageType.ResolveDomain) return;

    const domain_hash: u64 = @as(u64, @intCast(msg.payload));
    const chain_id: u8 = 1; // TODO: extract from extended payload

    // Resolve
    var address: [32]u8 = undefined;
    const found = resolve_domain_address(domain_hash, chain_id, &address);

    // Send reply via Federation
    if (found) {
        federation_os.send_message(.{
            .src_module = 26,               // Domain Resolver
            .dst_module = msg.src_module,   // Back to requester
            .msg_type = MessageType.DomainResolved,
            .payload_type = PAYLOAD_DOMAIN_ADDRESS,
            .payload = @as(i64, @ptrToInt(&address)),
        });
    } else {
        // Not found, feeder will update cache
        federation_os.send_message(.{
            .src_module = 26,
            .dst_module = msg.src_module,
            .msg_type = MessageType.ErrorReply,
            .payload = 1,  // PENDING: retry later
        });
    }
}
```

**GridOS receives reply**:

```zig
// GridOS next cycle:
// Check for DomainResolved message from Domain Resolver
if (federation_os.has_reply(msg_id)) {
    const reply = federation_os.get_message(msg_id);

    if (reply.msg_type == MessageType.DomainResolved) {
        // Extract address from reply payload
        const address = @as([*]const u8, @ptrFromInt(@as(usize, @intCast(reply.payload))))[0..32];
        // Use resolved address
        order.recipient = address;
    } else if (reply.msg_type == MessageType.ErrorReply) {
        // Not resolved yet, retry next cycle
        retry_domain_resolution(domain_hash);
    }
}
```

---

## Module Dependencies

### No Direct Calls

❌ **WRONG**: GridOS calling Domain Resolver directly
```zig
// WRONG - direct call, no coordination
const addr = domain_resolver.resolve_domain_address(hash, CHAIN_ETH);
```

✅ **CORRECT**: GridOS → Federation OS → Domain Resolver
```zig
// CORRECT - routed through Federation OS
federation_os.send_message(.{
    .src_module = 1,           // GridOS
    .dst_module = 26,          // Domain Resolver
    .msg_type = MessageType.ResolveDomain,
    .payload = hash,
});
```

### Why Federation OS?

1. **Single Authority**: One message hub for all domain requests
2. **Deduplication**: Multiple modules asking for same domain get one lookup
3. **Load Balancing**: Future multi-resolver setup via Federation
4. **Timeout Handling**: Automatic expiration if feeder doesn't respond
5. **Audit Trail**: All domain resolutions logged in Federation state
6. **Extensibility**: Add more resolvers without changing caller code

---

## Statistics & Monitoring

**Federation State** now tracks domain resolutions:
```zig
pub const FederationState = extern struct {
    // ... existing fields ...

    // Phase 51: Domain resolution stats
    domain_requests: u32,          // Total ResolveDomain messages
    domain_resolved: u32,          // Resolved successfully
    domain_timeouts: u32,          // Expired without resolution
    domain_cache_hits: u32,        // Resolved from cache
};
```

**Query via Federation API**:
```bash
# Check domain resolution statistics
curl http://localhost:8000/api/federation/stats

{
  "domain_requests": 143,
  "domain_resolved": 142,
  "domain_timeouts": 1,
  "domain_cache_hits": 98,
  "cache_hit_rate": 0.69
}
```

---

## Migration Path

### Phase 51 (Current)
- Domain Resolver OS exists as service
- Can be called directly by modules (simple case)
- Federation OS remains optional

### Phase 51B (Recommended)
- Update federation_types.zig with ResolveDomain message
- GridOS uses Federation OS for requests
- BlockchainOS processes replies
- Eliminates duplicate lookups

### Phase 52 (Advanced)
- Multiple Domain Resolvers (geographic distribution)
- Federation OS load-balances between them
- Cache coherence across resolvers

---

## Code Changes Required

### 1. federation_types.zig
```diff
+ ResolveDomain = 8,
+ DomainResolved = 9,
+
+ pub const PAYLOAD_DOMAIN_HASH = 0x10;
+ pub const PAYLOAD_DOMAIN_CHAIN = 0x11;
+ pub const PAYLOAD_DOMAIN_ADDRESS = 0x12;
+
+    domain_requests: u32 = 0,
+    domain_resolved: u32 = 0,
+    domain_timeouts: u32 = 0,
+    domain_cache_hits: u32 = 0,
```

### 2. grid_os.zig (Integration)
```zig
// Before: domain_resolver.resolve_domain_address()
// After:
if (needs_domain_resolution(order.recipient)) {
    const msg_id = federation_os.send_message(.{
        .src_module = 1,
        .dst_module = 26,
        .msg_type = MessageType.ResolveDomain,
        .payload = hashDomain(order.recipient),
    });
    order.awaiting_domain_resolution = msg_id;
    return;  // Skip execution, retry next cycle
}
```

### 3. domain_resolver_os.zig (Responder)
```zig
export fn process_federation_cycle() void {
    const fed_msg = federation_os.dequeue_message();
    if (fed_msg.dst_module == 26) {  // For me
        process_federation_request(fed_msg);
    }
}
```

---

## Benefits

| Aspect | Direct Call | Via Federation |
|--------|-------------|-----------------|
| **Deduplication** | ❌ Duplicate lookups | ✅ Single lookup |
| **Coordination** | ❌ No tracking | ✅ Full audit trail |
| **Scaling** | ❌ Hard to add resolvers | ✅ Easy load balance |
| **Error Handling** | ❌ Manual retries | ✅ Automatic timeouts |
| **Monitoring** | ❌ No visibility | ✅ Federation stats |

---

## Example: ENS Resolution via Federation

**Timeline**:
```
Cycle 1000:
  GridOS: "I need vitalik.eth on ETH"
  └─ sends ResolveDomain(0x1234...) to Federation

Cycle 1001:
  Federation: Routes to Domain Resolver
  Domain Resolver: Cache miss → marks PENDING
  └─ sends ErrorReply(1) back via Federation

Cycle 1002:
  GridOS: Receives ErrorReply, queues retry

[Meanwhile, ens_feeder.py updates cache]

Cycle 1005:
  GridOS: Retries ResolveDomain(0x1234...)
  Domain Resolver: Cache hit!
  └─ sends DomainResolved(0xd8dA6B...) back

Cycle 1006:
  GridOS: Receives address, uses it in order
```

---

## Summary

**Federation OS becomes the single coordination point for domain resolution**:
- No duplicate lookups
- Automatic load balancing
- Audit trail of all resolutions
- Ready for multi-resolver distribution

**Next step**: Implement Phase 51B to migrate all modules to Federation-routed domain requests.

