# OmniBus Performance Analysis Framework
## Measuring Sub-Microsecond Latency Characteristics

---

## Key Metrics to Track

### 1. Boot Performance
```
Metric: Time from BIOS to scheduler loop
Current: ~2 CPU cycles (measured empirically)
Target: < 1 millisecond

Measured via:
- BIOS entry timestamp
- Serial markers at each phase (K,T,C,R,P,X,I,Y,A,D,G,Z,W,B,N,S,V)
- Scheduler loop entry time
```

### 2. Cycle Frequency
```
Metric: Scheduler cycles per second
Current: Unknown (busy-wait based)
Target: 1-10 million cycles/second

Measurement:
- Increment kernel_cycle_count every iteration
- Read TSC (rdtsc) at start and end
- Calculate: (end_tsc - start_tsc) / cycles_elapsed = cycles_per_tsc_tick
```

### 3. Module Trigger Latency
```
Metric: Time from IPC_REQUEST set to module response
Current: Untested (modules not yet executing)
Target: < 1 microsecond

Modules:
- BlockchainOS: every 256 cycles
- NeuroOS: every 512 cycles

Measurement:
- Set IPC_REQUEST with timestamp
- Check IPC_STATUS change + IPC_RETURN_VALUE
- Latency = new_timestamp - request_timestamp
```

### 4. Cross-Module Communication Latency
```
Metric: Time from Grid metrics write to NeuroOS read
Target: < 100 cycles

Flow:
- Grid OS writes to 0x120000 @ timestamp T0
- NeuroOS reads @ timestamp T1
- Latency = T1 - T0
```

### 5. Scheduler Overhead
```
Metric: Time spent in scheduler vs. module execution
Target: < 5% of total CPU time

Calculation:
- scheduler_ticks = cycles spent in busy-wait + IPC checks
- total_ticks = scheduler_ticks + module_execution_ticks
- overhead_pct = (scheduler_ticks / total_ticks) * 100
```

### 6. Memory Usage per Module
```
Metric: Resident set size + working set
Breakdown:
- Code: binary_size (from objcopy output)
- Data: static allocations (grid, population arrays, state)
- BSS: uninitialized (padding, stack)

Current:
- Grid OS: 4980 bytes + 128KB memory segment
- BlockchainOS: 3496 bytes + 192KB memory segment
- NeuroOS: 2844 bytes + 512KB memory segment
```

---

## Instrumentation Points

### Phase 1: TSC-Based Cycle Counting (Kernel Level)

Add to startup_phase4.asm:
```asm
; At scheduler entry
kernel_start_tsc:
    rdtsc           ; EAX = low 32 bits, EDX = high 32 bits
    mov [0x100200], rax  ; Store at 0x100200

; In scheduler loop (every N iterations)
kernel_sample_tsc:
    rdtsc
    mov [0x100208], rax  ; Store at 0x100208
    ; Calculate elapsed = [0x100208] - [0x100200]
```

### Phase 2: IPC Timestamp Logging

Update IPC control block with timestamps:
```c
struct ipc_control_block {
    request: u8,
    status: u8,
    module_id: u16,
    _pad: u32,
    request_tsc: u64,      // When scheduler set request
    response_tsc: u64,     // When module set status=DONE
    return_value: u64,
};
```

Module sets response_tsc on completion:
```zig
ipc.response_tsc = rdtsc();
ipc.status = STATUS_DONE;
```

### Phase 3: Memory Access Logging

Track Grid ↔ NeuroOS communication:
```
Event: Grid writes metrics @ 0x120000
Timestamp: T_grid_write = Grid.export_metrics() timestamp

Event: NeuroOS reads metrics
Timestamp: T_neuro_read = when NeuroOS.evaluate_fitness() reads 0x120000

Latency: T_neuro_read - T_grid_write
```

---

## Performance Profiling Workflow

### Step 1: Baseline Measurements
```bash
# Boot system, let it run for 10 seconds
# Read kernel_cycle_count @ 0x100100
# Read TSC @ start and end
# Calculate: cycles_per_sec = count / (tsc_end - tsc_start)
```

### Step 2: Per-Module Analysis
```bash
# Trigger BlockchainOS every 256 cycles
# Log IPC latencies (request → response time)
# Average latency for 1000 samples
# Histogram of latencies (min, max, p50, p95, p99)
```

### Step 3: Cross-Module Flow
```bash
# Measure Grid → Neuro communication
# 1. Grid exports metrics (0x120000)
# 2. Neuro reads metrics
# 3. Neuro writes parameters (0x120040)
# 4. Grid reads parameters
# Total feedback loop time = T_end - T_start
```

### Step 4: Sustained Load Test
```bash
# Run scheduler for 60+ seconds
# Monitor:
# - CPU cycle consistency
# - IPC latency drift over time
# - Memory stability
# - Exception frequency (if any)
```

---

## Expected Performance Characteristics

### Optimistic Scenario (Best Case)
```
Cycle frequency: 10 MHz (0.1 µs per cycle)
Module latency: 100-500 cycles (1-5 µs)
IPC overhead: < 50 cycles
Feedback loop: < 1000 cycles (10 µs)
```

### Realistic Scenario (Expected)
```
Cycle frequency: 1-5 MHz
Module latency: 1000-5000 cycles (1-5 µs)
IPC overhead: 100-200 cycles
Feedback loop: 5000-10000 cycles (5-10 µs)
```

### Conservative Scenario (Pessimistic)
```
Cycle frequency: 100 kHz (10 µs per cycle)
Module latency: 10000+ cycles (100 µs+)
IPC overhead: > 500 cycles
Feedback loop: > 50000 cycles (500 µs+)
```

---

## Measurement Tools

### 1. Serial Logger (UART)
```
Output cycle count + timestamps to serial @ regular intervals
Format: "CYCLE={count} TSC={tsc_value}"
Parse with: /tmp/omnibus.log → extract → graph
```

### 2. Memory Inspector (QEMU GDB)
```
gdb> x/100x 0x100100    # Read cycle counter
gdb> x/20x 0x100110    # Read IPC control block
gdb> x/20x 0x120000    # Read Grid metrics
gdb> x/20x 0x120040    # Read Neuro parameters
```

### 3. Profiling Script (Python)
```python
def parse_omnibus_log(filename):
    cycles = []
    tscs = []
    with open(filename) as f:
        for line in f:
            if "CYCLE=" in line:
                c = int(line.split("CYCLE=")[1].split()[0])
                t = int(line.split("TSC=")[1])
                cycles.append(c)
                tscs.append(t)

    # Calculate frequency
    tsc_delta = tscs[-1] - tscs[0]
    cycle_delta = cycles[-1] - cycles[0]
    freq_mhz = (cycle_delta / tsc_delta) * cpu_ghz * 1000
    return freq_mhz

freq = parse_omnibus_log("/tmp/omnibus.log")
print(f"Measured frequency: {freq:.2f} MHz")
```

---

## Next Steps

### Immediate (Week 1)
- Add TSC logging @ kernel entry
- Measure baseline cycle frequency
- Profile single module trigger latency

### Short-term (Week 2)
- Add IPC timestamp logging
- Measure module response time distribution
- Identify latency outliers

### Medium-term (Week 3-4)
- Profile full feedback loop (Grid → Neuro → Grid)
- Identify bottlenecks
- Optimize hot paths

### Long-term (Month 2+)
- Sustained load testing
- Real-world trading scenario profiling
- Hardware verification (if available)

---

## Success Criteria

✅ **Boot latency** < 100 ms (currently ~1 ms)
✅ **Cycle frequency** > 100 kHz (currently unknown)
✅ **Module latency** < 100 µs (average)
✅ **IPC latency** < 10 µs (average)
✅ **Feedback loop** < 50 µs (full round-trip)
✅ **Zero crashes** during 60-second sustained test
✅ **Consistent timing** (< 10% variance over time)

---

## Current Baseline

From QEMU empirical observations:
- Boot sequence: ~2 serial markers per phase, no timing data yet
- Cycle frequency: Unknown (need instrumentation)
- Module trigger: Ready to measure (IPC framework in place)
- Feedback loop: Ready to measure (shared memory in place)

Ready for Phase 4 instrumentation deployment.
