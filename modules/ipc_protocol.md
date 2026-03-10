# OmniBus Module IPC Protocol
## Inter-Process Communication for Kernel ↔ Module Communication

---

## Memory Layout

```
0x100050  Auth Gate (Ada Mother OS)
0x100100  Kernel Cycle Counter
0x100110  IPC Control Block (64 bytes)
  0x100110  IPC_REQUEST (1 byte)  - Request code
  0x100111  IPC_STATUS (1 byte)   - Status (0=idle, 1=busy, 2=done, 3=error)
  0x100112  IPC_MODULE_ID (2 bytes) - Target module ID
  0x100114  IPC_CYCLE_COUNT (8 bytes) - Cycle counter at request
  0x10011C  IPC_RETURN_VALUE (8 bytes) - Return value from module
```

## Request Codes

```
REQUEST_NONE      = 0x00
REQUEST_BLOCKCHAIN_CYCLE = 0x01
REQUEST_NEURO_CYCLE = 0x02
REQUEST_GRID_METRICS = 0x03
REQUEST_MODULE_INIT = 0x04
```

## Status Codes

```
STATUS_IDLE = 0x00
STATUS_BUSY = 0x01
STATUS_DONE = 0x02
STATUS_ERROR = 0x03
```

## Module IDs

```
MODULE_GRID = 0x01
MODULE_EXECUTION = 0x02
MODULE_ANALYTICS = 0x03
MODULE_BLOCKCHAIN = 0x04
MODULE_NEURO = 0x05
```

---

## Call Sequence

### Kernel initiates module call:
1. Write REQUEST code to IPC_REQUEST
2. Write MODULE_ID to IPC_MODULE_ID
3. Set IPC_STATUS = STATUS_BUSY
4. Wait for IPC_STATUS = STATUS_DONE or STATUS_ERROR
5. Read IPC_RETURN_VALUE

### Module execution:
1. Check IPC_REQUEST (polling or interrupt-driven)
2. Execute requested function
3. Write result to IPC_RETURN_VALUE
4. Set IPC_STATUS = STATUS_DONE
5. Loop back to waiting for next request

---

## Implementation Strategy

For Phase 9:
- Scheduler checks IPC_REQUEST every N cycles
- Writes REQUEST code + MODULE_ID to control block
- Each module has a wrapper that polls for requests
- Wrapper executes Zig function and returns result

This avoids:
- Direct Zig function calls (no relocation issues)
- Stack corruption (module has isolated context)
- Cross-module state collisions
