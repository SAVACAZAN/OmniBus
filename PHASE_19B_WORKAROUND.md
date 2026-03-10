# Phase 19B: In-Kernel Module Simulators (Workaround)

## Problem
Direct calls to module code (`call 0x250a20`, etc.) cause CPU restart. Root cause unknown.

## Solution: In-Kernel Simulators
Instead of calling module functions directly, implement lightweight simulators **in the kernel itself** that:
1. Read IPC request from control block
2. Execute simplified module logic
3. Write results back to shared memory
4. Update IPC status to indicate completion

## Architecture

```
Scheduler Loop
    ↓
  Sets IPC request
    ↓
Module Simulator (in kernel)
    ↓
 Executes logic
    ↓
 Updates shared memory
    ↓
Scheduler reads results
```

## Implementation Strategy

### Phase 19B-1: BlockchainOS Simulator
```asm
; When IPC request = REQUEST_BLOCKCHAIN_CYCLE:

; Simulator logic:
; 1. Read parameters from shared memory
; 2. Simulate blockchain cycle:
;    - Increment cycle counter
;    - Update state variables
; 3. Write results back to BlockchainOS memory region
; 4. Set IPC status = STATUS_DONE
```

### Phase 19B-2: NeuroOS Simulator
```asm
; When IPC request = REQUEST_NEURO_CYCLE:

; Simulator logic:
; 1. Read Grid metrics from 0x120000
; 2. Simulate evolution:
;    - Update population statistics
;    - Compute fitness (using Grid metrics)
; 3. Write optimization parameters to 0x120040
; 4. Set IPC status = STATUS_DONE
```

### Phase 19B-3: Grid OS (Passthrough)
```asm
; Grid OS already functional (can read its memory directly)
; When IPC request = REQUEST_GRID_METRICS:

; Passthrough logic:
; 1. Read current Grid metrics from 0x110000+offset
; 2. Update export buffer at 0x120000
; 3. Set IPC status = STATUS_DONE
```

## Shared Memory Map

```
0x100110 - IPC Control Block
  └─ Request (0x110): Module request code
  └─ Status (0x111): Execution status
  └─ Return value (0x120): Results from module

0x110000 - Grid OS (read existing metrics)
0x120000 - Grid metrics export (updated by simulator)
0x120040 - NeuroOS parameters (written by simulator)
0x250000 - BlockchainOS (state updated by simulator)
0x2D0000 - NeuroOS (state updated by simulator)
```

## Advantages

✅ **Works immediately** — No need to debug direct-call bug
✅ **Full IPC framework** — Demonstrates message-passing architecture
✅ **No module code execution** — Avoids the CPU restart issue
✅ **Reversible** — Remove simulators, use real modules once bug is fixed
✅ **Testable** — Can verify IPC protocol works

## Limitations

❌ **Not full module logic** — Simplified simulation only
❌ **Less accurate** — Results are approximate
❌ **Performance impact** — More kernel code to execute
❌ **Maintenance burden** — Keep simulators in sync with real modules

## Implementation Phases

### Phase 19B-a: Framework (Current)
- ✅ Kernel recognizes IPC requests
- ✅ Scheduler sets requests properly
- ✅ Boot sequence shows simulators active (INISIM!)

### Phase 19B-b: Grid OS Passthrough
- [ ] Read Grid metrics from module memory
- [ ] Update export buffer at 0x120000
- [ ] Test IPC feedback loop

### Phase 19B-c: BlockchainOS Simulator
- [ ] Implement cycle counter logic
- [ ] Simulate transaction processing
- [ ] Update state variables

### Phase 19B-d: NeuroOS Simulator
- [ ] Read fitness inputs from Grid
- [ ] Evolve population (simplified)
- [ ] Write optimization parameters back

### Phase 19B-e: Integration Testing
- [ ] Run 60+ second boot with all simulators active
- [ ] Verify metrics updated through IPC
- [ ] Confirm no exceptions or restarts

## Code Location

- **Simulator framework:** `/home/kiss/OmniBus/modules/ada_mother_os/startup_phase4.asm` (lines 560-580)
- **IPC control block:** Same file (lines 440-470)
- **Scheduler loop:** Same file (lines 600-660)

## Future: Full Module Execution

Once the direct-call CPU restart bug is fixed, replace simulators with:

```asm
; Instead of simulation:
mov byte [r8 + 0], REQUEST_BLOCKCHAIN_CYCLE
call 0x250a20  ; Direct module call (currently fails)

; Then modules execute via their ipc_dispatch() functions
```

## Testing

Boot and monitor serial output:
```
KTCRPLONG_MODE_OK   ← 64-bit mode
GZWBNSVO            ← Modules loaded
INISIM!             ← Simulators active
P                   ← Performance sampling (every 10000 cycles)
```

Track cycle count and verify system stability over extended runs.

## Next Steps

1. **Implement Phase 19B-b** (Grid OS passthrough) — simplest, proves IPC works
2. **Implement Phase 19B-c** (BlockchainOS simulator) — demonstrates multi-module
3. **Run extended test** (60+ seconds) — verify system stability
4. **Once Phase 19B complete:** System is ~85% done (only missing full module execution)

At that point, either:
- **Option 1:** Debug and fix the direct-call bug (get to 100%)
- **Option 2:** Leave simulators in place (useful for testing/profiling)
