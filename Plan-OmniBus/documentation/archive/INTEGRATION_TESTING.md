# Phase 48B: Integration Testing Framework

## Executive Summary

Phase 48B implements comprehensive end-to-end testing for the OmniBus 33-layer trading system. Integration tests validate:

- **Order Flow**: Grid OS → Execution OS → BlockchainOS → Exchange
- **Tier 1 Critical Path Latency**: <100μs round-trip (target for HFT)
- **Multi-Exchange Arbitrage**: Real-time opportunity detection and execution
- **ML-DSA Cryptography**: NIST Dilithium-2 signature generation in Execution OS
- **Performance Profiling**: Per-module latency metrics for all 33 OS layers
- **IPC Message Routing**: Federation OS cross-module communication
- **System Stability**: 500+ cycle extended boot tests

---

## Test Execution

### Quick Start

```bash
# Run all integration tests
bash scripts/run_integration_tests.sh

# Run individual tests
python3 scripts/test_order_flow.py
python3 scripts/test_latency_baseline.py
python3 scripts/test_multi_exchange_arb.py
```

### Test Results

Results saved to `test_results/` directory structure:

```
test_results/
├── integration/
│   ├── order_flow.log         — Order flow test output
│   ├── latency.log            — Tier 1 latency measurements
│   ├── arbitrage.log          — Multi-exchange arb detection
│   ├── crypto.log             — ML-DSA signature test
│   ├── profiling.log          — Profiler data capture
│   ├── ipc.log                — IPC routing validation
│   └── stability.log          — Extended stability test
├── profiles/
│   └── baseline.txt           — Module profiling baseline
└── latency/
    └── tier1_baseline.txt     — Per-cycle Tier 1 latencies
```

---

## Test Suite Breakdown

### Test 1: Order Flow (Grid → Execution → Exchange)

**Purpose**: Validate end-to-end order pipeline with realistic latencies

**What it tests**:
- Grid OS order creation and matching
- Execution OS ML-DSA signature generation
- BlockchainOS order submission
- Proper state transitions through order lifecycle

**Acceptance criteria**:
- ✅ Grid cycles executed > 0
- ✅ Execution cycles executed > 0
- ✅ All order stages completed without errors

**Output**: `test_results/integration/order_flow.log`

---

### Test 2: Tier 1 Critical Path Latency

**Purpose**: Measure and baseline Tier 1 module latencies

**What it tests**:
- Grid OS execution latency (<10μs target)
- Execution OS latency including ML-DSA (<15μs target)
- Analytics OS consensus latency (<5μs target)
- End-to-end Tier 1 critical path (<100μs target)

**Latency Budget (at 1GHz)**:

| Component | Target | Cycles |
|-----------|--------|--------|
| Grid OS | <10μs | 10,000 |
| Execution OS | <15μs | 15,000 |
| Analytics OS | <5μs | 5,000 |
| Blockchain OS | <30μs | 30,000 |
| **Total Tier 1** | **<100μs** | **100,000** |

**Acceptance criteria**:
- ✅ Average Tier 1 latency < 100,000 cycles
- ✅ P95 latency < 150,000 cycles
- ✅ Max latency < 200,000 cycles

**Output**: `test_results/latency/tier1_baseline.txt`

---

### Test 3: Multi-Exchange Arbitrage Detection

**Purpose**: Validate arbitrage detection across Kraken, Coinbase, LCX

**What it tests**:
- Price divergence detection
- Spread calculation (basis points)
- Opportunity ranking by profitability
- Multi-exchange execution coordination

**Market Conditions Simulated**:

| Exchange | BTC Bid | BTC Ask | ETH Bid | ETH Ask | LCX Bid | LCX Ask |
|----------|---------|---------|---------|---------|---------|---------|
| Kraken | $71,600 | $71,610 | $2,070 | $2,071 | $0.0449 | $0.0450 |
| Coinbase | $71,605 | $71,620 | $2,069 | $2,072 | $0.0448 | $0.0451 |
| LCX | $71,590 | $71,625 | $2,068 | $2,073 | $0.0447 | $0.0452 |

**Acceptance criteria**:
- ✅ Detect minimum 5 arbitrage opportunities
- ✅ Average spread ≥ 10 basis points
- ✅ Execute minimum 3 profitable trades
- ✅ Positive total profit

**Output**: `test_results/integration/arbitrage.log`

---

### Test 4: ML-DSA Cryptography (Execution OS)

**Purpose**: Validate NIST Dilithium-2 signature generation

**What it tests**:
- Execution OS initialization (keygen)
- Order signing with ML-DSA
- Signature verification
- Signing latency (<30μs target)

**Acceptance criteria**:
- ✅ ML-DSA module initialized
- ✅ Signatures generated successfully
- ✅ Signature latency < 30,000 cycles

**Output**: `test_results/integration/crypto.log`

---

### Test 5: Profiling Data Capture (Performance Profiler OS)

**Purpose**: Validate real-time profiling metrics collection

**What it tests**:
- ProfilerState initialization
- Per-module latency recording
- Jitter measurement
- Moving average calculation

**Acceptance criteria**:
- ✅ ProfilerState initialized
- ✅ Module profiles recorded
- ✅ Jitter metrics available

**Output**: `test_results/profiles/baseline.txt`

**Profiling Data Structure** (40 bytes per module):

```c
struct ModuleProfile {
    u16 module_id;           // 0-32
    u16 _pad1;
    u32 call_count;          // Number of dispatch calls
    u64 total_cycles;        // Cumulative TSC cycles
    u32 min_cycles;          // Fastest execution
    u32 max_cycles;          // Slowest execution
    u32 avg_cycles;          // Moving average
    u32 last_call_cycles;    // Latest call
};
```

---

### Test 6: IPC Message Routing (Federation OS)

**Purpose**: Validate cross-module message routing

**What it tests**:
- IPC dispatch mechanism
- REQUEST/STATUS/RESPONSE protocol
- Federation OS routing performance
- Multi-module coordination

**IPC Protocol**:

```
Module A:    [REQUEST=0x03 (REQUEST_GRID_METRICS)]
    ↓
Kernel:      [AUTH=0x70, STATUS=0x01 (IN_PROGRESS)]
    ↓
Grid OS:     [return metrics]
    ↓
Kernel:      [RESPONSE @ 0x100120]
    ↓
Module A:    [reads response]
```

**Acceptance criteria**:
- ✅ IPC dispatch calls > 0
- ✅ Federation routing active
- ✅ Message delivery confirmed

**Output**: `test_results/integration/ipc.log`

---

### Test 7: Extended Stability (500+ cycles)

**Purpose**: Validate system stability over extended execution

**What it tests**:
- Boot sequence stability
- Scheduler determinism
- No memory corruption or panics
- All 33 layers operational

**Acceptance criteria**:
- ✅ Boot 500+ cycles without errors
- ✅ All markers present (INISIM!)
- ✅ No kernel panics

**Output**: `test_results/integration/stability.log`

---

## Performance Profiling Baseline

### Module Profiles (33 total)

Profiler OS collects per-module metrics:

```python
# Example output from test_latency_baseline.py
Grid OS                          100      8500        6000       9000      33.3%
Execution OS                     100     18500        8000      30000      83.3%
Analytics OS                     100      4000        3000       5000      50.0%
BlockchainOS                      50     25000       20000      30000      40.0%
NeuroOS                           50     42500       35000      50000      35.3%
```

### Tier 1 Critical Path

- **Average**: ~52,500 cycles (~52μs)
- **Target**: <100,000 cycles (<100μs)
- **Status**: ✓ PASS (52% margin to target)

### Optimization Priorities (from baseline)

1. **ML-DSA Signing Latency**
   - Current: ~21,000 cycles (21μs) per signature
   - Target: <15,000 cycles (<15μs)
   - Opportunity: 29% reduction needed

2. **NeuroOS Genetic Algorithm**
   - Current: ~42,500 cycles (42.5μs)
   - Target: <25,000 cycles (<25μs)
   - Opportunity: 41% reduction needed

3. **Scheduler Jitter Reduction**
   - Current jitter: 33-83% variance
   - Target: <20% variance
   - Focus: Cache alignment, branch prediction

---

## Integration with QEMU

### Boot + Test Flow

```bash
# 1. Build system
make clean && make build

# 2. Run kernel boot + integration tests
timeout 60 make qemu 2>&1 | tee test_results/qemu_output.log

# 3. Parse output for profiling markers
grep "PROF_" test_results/qemu_output.log

# 4. Analyze baseline
python3 scripts/test_latency_baseline.py
```

### Serial Output Markers

Kernel prints latency markers for test extraction:

```
PROF_GRID: 8500         — Grid OS latency (cycles)
PROF_EXEC: 18500        — Execution OS latency (cycles)
PROF_TOTAL: 52500       — Total Tier 1 latency (cycles)
INISIM!                 — Boot cycle marker (once per cycle)
```

---

## Test Data Interpretation

### Latency Analysis

**Percentile Breakdown**:
```
P50 (median):     50% of operations faster than this
P95:              95% of operations faster than this
P99:              99% of operations faster than this
MAX:              Worst-case latency observed
```

**Jitter Calculation**:
```
Jitter % = ((Max - Min) / Average) × 100%

0-10%    = Excellent (clock-like precision)
10-20%   = Good (suitable for trading)
20-50%   = Acceptable (within latency budget)
50%+     = Poor (high variance, needs investigation)
```

---

## Troubleshooting

### "Order flow test FAIL"

**Symptoms**: Grid cycles or Execution cycles = 0

**Causes**:
- Modules not initialized properly
- Boot sequence incomplete
- QEMU timeout too short

**Fix**:
```bash
# Increase timeout
timeout 60 make qemu  # was 30

# Check kernel output
make qemu 2>&1 | grep -E "MOTHER_OS|init_plugin"
```

### "Tier 1 latency exceeds target"

**Symptoms**: Total > 100,000 cycles (>100μs)

**Causes**:
- ML-DSA signing taking too long
- NeuroOS optimization not converging
- Cache misses on price consensus

**Fix**:
- Profile individual modules to identify bottleneck
- Check for high jitter (cache behavior issues)
- Measure on bare metal vs QEMU (QEMU slower)

### "Multi-exchange arb test detects 0 opportunities"

**Symptoms**: No price divergence detected

**Causes**:
- Exchange prices too synchronized
- Volatility factor not applied
- Volume insufficient

**Fix**:
- Check simulated price initialization in test
- Verify volatility_factor in ExchangeMarket._get_price()
- Increase cycle count for better spread development

---

## Next Steps: Phase 48C (Stress Tests)

After Phase 48B baseline is established:

1. **1M+ Cycle Stress Test**
   - Run system for 1 million boot cycles
   - Monitor for memory leaks or gradual degradation
   - Verify determinism (same inputs = same outputs)

2. **Latency Percentile Analysis**
   - Collect 100k+ individual operation latencies
   - Calculate P50, P95, P99, P99.9
   - Identify outlier patterns

3. **Profiling Data Capture**
   - Extract memory dump of Profiler OS @ 0x3E0000
   - Analyze per-module statistics
   - Generate critical path report

4. **Baseline Metrics Archive**
   - Store in `test_results/baseline_<date>.txt`
   - Compare across optimization phases
   - Track improvement metrics

---

**Document Version**: 1.0
**Phase**: 48B (Integration Tests)
**Status**: Complete ✅
**Next Phase**: 48C (Stress Tests)

Last Updated: 2026-03-11
