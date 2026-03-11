# 📡 InfoScanOmniBus v1.0

**Comprehensive OmniBus System Diagnostic & Monitoring Toolkit**

A complete scanning, health monitoring, and auto-repair system for the OmniBus bare-metal trading OS with 47+ modules across 5 tiers.

---

## 🎯 Purpose

After deploying OmniBus v2.0.0 with dual-kernel formal verification, you need **real-time visibility** into:

- ✅ **State of all 47 OS modules** (memory, status, cycles)
- ✅ **Inter-module connectivity** (who talks to whom, circular deps)
- ✅ **Memory isolation** (no overlaps, boundary violations)
- ✅ **IPC safety** (unauthorized access attempts, signature validation)
- ✅ **Performance** (latency profiles, bottlenecks)
- ✅ **Health status** (errors, degradation, repairs)
- ✅ **Auto-repair** (trigger AutoRepair OS when issues detected)

This toolkit scans all layers **simultaneously** and generates actionable reports.

---

## 📦 Components

### 1. **`scan_omnibus.sh`** (Master Coordinator)
Main entry point - orchestrates all scans and provides CLI interface.

```bash
./scan_omnibus.sh              # Full diagnostic
./scan_omnibus.sh --health     # Health status only
./scan_omnibus.sh --watch      # Real-time monitoring (5s refresh)
./scan_omnibus.sh --connectivity  # Interconnectivity matrix
./scan_omnibus.sh --security   # Security audit
./scan_omnibus.sh --auto-repair  # Detect + fix issues
./scan_omnibus.sh --json       # Export as JSON
```

### 2. **`omnibus_kernel_scanner.py`** (Kernel Memory Scanner)
Reads `/dev/mem` and scans all 47 modules:

```bash
python3 omnibus_kernel_scanner.py          # Full scan
python3 omnibus_kernel_scanner.py --json   # JSON output
python3 omnibus_kernel_scanner.py --watch  # Real-time (Ctrl+C to exit)
```

**Scans:**
- Module headers @ base address
- State codes (uninitialized/ready/running/error)
- Execution counters & cycle tracking
- Error flags (memory access, unauthorized IPC, checksum failures)
- Memory validity checks

### 3. **`connectivity_mapper.py`** (Dependency Graph Analyzer)
Maps module interconnections and detects issues:

```bash
python3 connectivity_mapper.py        # Full report
python3 connectivity_mapper.py --json # JSON export
```

**Detects:**
- ✓ Circular dependencies (FATAL if found)
- ✓ Critical path depth (longest chain)
- ✓ Fan-in analysis (bottleneck modules - many depend on them)
- ✓ Fan-out analysis (complexity - depend on many modules)
- ✓ Execution order optimization

**Example Output:**
```
TIER 1: Real-Time Trading (Critical)
  L01 Grid OS ← L03(Analytics OS)
  L02 Execution OS ← L01(Grid OS) + L03(Analytics OS)
  L03 Analytics OS [SOURCE]
  L04 BlockchainOS ← L02(Execution OS)
```

### 4. **`security_validator.py`** (Memory & IPC Security)
Validates isolation and cryptographic integrity:

```bash
python3 security_validator.py        # Full audit
python3 security_validator.py --json # JSON export
```

**Validates:**
- ✓ Memory segment overlaps (CRITICAL if found)
- ✓ Tier isolation (Tier 1 ≠ Tier 5)
- ✓ Boundary violations (reads/writes outside allocated segment)
- ✓ IPC message safety (only authorized modules can request)
- ✓ Cryptographic signatures (are critical modules signed?)
- ✓ Formal verification coverage (T1-T4 theorem completion % )

**Example Output:**
```
MEMORY SEGMENT ISOLATION
  ✓ All memory segments properly isolated (no overlaps)
  - Grid OS:      0x110000-0x12FFFF (128KB)
  - Execution OS: 0x130000-0x14FFFF (128KB)
  - Analytics OS: 0x150000-0x1FFFFF (512KB)
  [No overlaps detected]

CRYPTOGRAPHIC SIGNING
  ✓ Grid OS
  ✓ Execution OS
  ✓ BlockchainOS
  ✓ seL4 Microkernel
  ✓ Ada Mother OS
  [All critical modules signed]

FORMAL VERIFICATION COVERAGE (Theorems T1-T4)
  T1 - Memory Isolation     ████████████████░░ 95%
  T2 - Information Flow     ██████████████░░░░ 88%
  T3 - Determinism          ██████████████████ 92%
  T4 - Crash Safety         ████████████░░░░░░ 85%
```

### 5. **`health_reporter.py`** (System Health & Latency)
Comprehensive health status with error logs:

```bash
python3 health_reporter.py        # Full report
python3 health_reporter.py --json # JSON export
```

**Reports:**
- 🟢 Healthy modules
- 🟡 Degraded modules (still running, but with issues)
- 🔴 Error modules (halted or in error state)
- Latency percentiles (P50/P95/P99/max)
- Memory profile by tier
- Error history & recovery status
- Actionable recommendations

**Example Output:**
```
OVERALL SYSTEM STATUS
  🟢 HEALTHY:  36 modules
  🟡 DEGRADED: 1 module (AutoRepair OS - 3 repairs done)
  🔴 ERROR:    0 modules
  📊 TOTAL:    47 modules

  ⚠️  SYSTEM STATUS: DEGRADED (1 module)

LATENCY ANALYSIS
  Min:         3.20μs
  P50:        10.45μs (median)
  P95:        22.10μs (95th percentile)
  P99:        28.30μs (99th percentile)
  Max:        28.30μs
  Avg:        12.34μs

MEMORY PROFILE
  Total allocated: 6.28MB
    Tier 1:        2.50MB (Trading - critical path)
    Tier 2:        1.10MB (System services)
    Tier 3:        0.32MB (Notification)
    Tier 4:        1.50MB (Protection)
    Tier 5:        0.86MB (Formal verification)
```

---

## 🚀 Quick Start

### Installation

```bash
cd /home/kiss/OmniBus
git add InfoScanOmniBus/
git commit -m "Add InfoScanOmniBus diagnostic toolkit"
```

### First Run (Full Diagnostic)

```bash
./InfoScanOmniBus/scan_omnibus.sh
```

This generates:
1. Text report → `logs/omnibus_diagnostic_YYYY-MM-DD_HH-MM-SS.txt`
2. Printed output with color-coded status

### Real-Time Monitoring

```bash
./InfoScanOmnibus/scan_omnibus.sh --watch
```

Press `Ctrl+C` to exit. Updates every 5 seconds.

### Auto-Repair Issues

```bash
./InfoScanOmnibus/scan_omnibus.sh --auto-repair
```

Automatically:
1. Scans for degraded modules
2. Triggers AutoRepair OS (L10 @ 0x320000)
3. Monitors recovery
4. Reports results

### Export for Analysis

```bash
./InfoScanOmnibus/scan_omnibus.sh --json > omnibus_state.json
```

Perfect for:
- CI/CD pipelines (parse JSON, check status)
- Dashboards (feed to Prometheus/Elasticsearch)
- Historical tracking (git commit diagnostic snapshots)

---

## 📊 What Gets Scanned?

### **All 47 Modules** (5 Tiers)

| Tier | Modules | Examples | Status |
|------|---------|----------|--------|
| **1 (Trading)** | 7 | Grid, Execution, Analytics, Blockchain, Neuro, Bank, Stealth | 🟢 |
| **2 (System)** | 7 | Report, Checksum, AutoRepair, Zorin, Audit, ParamTune, HistAnalytics | 🟢 |
| **3 (Notify)** | 4 | Alert, Consensus, Federation, MEVGuard | 🟢 |
| **4 (Protect)** | 11 | CrossChain, DAO, Recovery, Compliance, Staking, etc. | 🟢 |
| **5 (Verify)** | 9 | seL4, CrossValidator, FormalProofs, DomainResolver, etc. | 🟢 |

### **Memory Checks**

- Segment isolation (no overlaps)
- Boundary validation (stays within assigned region)
- Alignment (cache-line aligned)
- Usage (allocated vs. actual)

### **IPC Safety**

- Request origin validation (authenticated sender?)
- Authorization checks (module allowed to request?)
- Message integrity (checksum valid?)
- Response verification (signed reply?)

### **Performance**

- Execution latency per module
- Dispatch frequency (Tier 1 every cycle, Tier 5 every 500K+ cycles)
- Cycle counter tracking
- Bottleneck identification

### **Formal Verification**

- T1: Memory Isolation - Can modules cross memory boundaries?
- T2: Information Flow - Can sensitive data leak?
- T3: Determinism - Same inputs → Same outputs?
- T4: Crash Safety - Can single failure cascade?

---

## 🔍 Usage Examples

### Example 1: Full System Audit Before Trading

```bash
./InfoScanOmnibus/scan_omnibus.sh > pre_trading_audit.txt
cat pre_trading_audit.txt | grep -A 5 "SYSTEM STATUS"
```

Expected output:
```
✅ SYSTEM STATUS: FULLY OPERATIONAL
```

### Example 2: Track Latency Over Time

```bash
# Snapshot 1
./InfoScanOmnibus/scan_omnibus.sh --json > latency_t1.json

# ... do trading for 1 hour ...

# Snapshot 2
./InfoScanOmnibus/scan_omnibus.sh --json > latency_t2.json

# Compare
python3 -c "
import json
t1 = json.load(open('latency_t1.json'))
t2 = json.load(open('latency_t2.json'))
print('P95 latency change:',
      (t2['diagnostics']['health']['latency_percentiles']['p95'] -
       t1['diagnostics']['health']['latency_percentiles']['p95']) / 1000, 'μs')
"
```

### Example 3: Detect Circular Dependencies

```bash
./InfoScanOmnibus/scan_omnibus.sh --connectivity | grep -i "circular"
```

Expected: `✓ NO CIRCULAR DEPENDENCIES (System is acyclic)`

### Example 4: Security Compliance Report

```bash
./InfoScanOmnibus/scan_omnibus.sh --security | grep -A 10 "CRYPTOGRAPHIC SIGNING"
```

Confirms all critical modules are signed.

### Example 5: Watch for Errors in Real-Time

```bash
./InfoScanOmnibus/scan_omnibus.sh --watch | grep -E "(ERROR|DEGRADED|🔴)"
```

Alerts you to any module failures.

---

## 🛠️ Auto-Repair Workflow

```bash
./InfoScanOmnibus/scan_omnibus.sh --auto-repair
```

**What happens:**

1. **Scan Phase**: Detects degraded modules
2. **Diagnosis**: Identifies root cause (memory error? timeout? checksum fail?)
3. **Trigger**: Issues IPC request to AutoRepair OS @ 0x320000
   ```
   IPC_REQUEST = REQUEST_MODULE_INIT
   IPC_MODULE_ID = 10 (AutoRepair OS)
   IPC_STATUS = BUSY
   ```
4. **Recovery**: AutoRepair OS reads error flags, applies fixes
   - Corrupted memory? Restore from backup
   - Hung module? Reset & reinitialize
   - Checksum fail? Verify integrity
5. **Verify**: Re-run health check, confirm module recovered
6. **Report**: Show before/after status

---

## 📈 Output Locations

All reports saved to relative paths:

```
InfoScanOmniBus/
├── logs/
│   ├── omnibus_diagnostic_2026-03-11_19-50-00.txt
│   ├── omnibus_diagnostic_2026-03-11_20-00-00.txt
│   └── ...
├── reports/
│   ├── omnibus_diagnostic_2026-03-11_19-50-00.json
│   └── ...
├── scan_omnibus.sh          (master coordinator)
├── omnibus_kernel_scanner.py (kernel reader)
├── connectivity_mapper.py     (dependency analyzer)
├── security_validator.py      (isolation checker)
├── health_reporter.py         (status reporter)
└── README.md                  (this file)
```

---

## 🔧 Requirements

- **Python 3.7+**
- **Bash 4.0+**
- **Linux kernel** (for /dev/mem access)
- **Sudo** (for physical memory reads)

### Check Prerequisites

```bash
python3 --version     # Should be 3.7+
bash --version        # Should be 4.0+
[ -e /dev/mem ] && echo "✓ /dev/mem available"
sudo -l &>/dev/null && echo "✓ Sudo available"
```

---

## 📚 Integration with CI/CD

### GitHub Actions Example

```yaml
name: OmniBus Health Check
on: [push, pull_request]
jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: |
          python3 InfoScanOmniBus/connectivity_mapper.py --json > conn.json
          python3 InfoScanOmniBus/security_validator.py --json > sec.json
          python3 InfoScanOmniBus/health_reporter.py --json > health.json

          # Fail if circular deps or security issues
          if grep -q '"circular_deps": [1-9]' conn.json; then
            echo "❌ Circular dependencies detected!"; exit 1
          fi
          if grep -q '"violations": [1-9]' sec.json; then
            echo "❌ Security violations detected!"; exit 1
          fi
          echo "✅ All checks passed"
```

---

## 🐛 Troubleshooting

### "Permission denied: /dev/mem"
→ Run with sudo: `sudo ./scan_omnibus.sh`

### "No module named 'json'"
→ Python 3 standard library - should be included. Check Python version: `python3 --version`

### "Python3 not found"
→ Install: `apt-get install python3` (Linux) or `brew install python3` (macOS)

### Scan hangs on `--watch`
→ Press `Ctrl+C` to exit. Normal if many modules being scanned.

---

## 📖 Related Documentation

- **[CLAUDE.md](../CLAUDE.md)** - Project architecture & module definitions
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Complete system design (5 tiers, 47 modules)
- **[WHITEPAPER.md](../WHITEPAPER.md)** - Full specifications & algorithms
- **[PHASE_51.md](../PHASE_51.md)** - Blockchain domain resolution integration
- **[ipc_protocol.md](../modules/ipc_protocol.md)** - IPC message format & validation

---

## 🚀 Next Steps

1. **Run first diagnostic:**
   ```bash
   ./scan_omnibus.sh | tee first_run.txt
   ```

2. **Review for issues:**
   ```bash
   grep -E "(ERROR|CRITICAL|❌)" first_run.txt
   ```

3. **Set up continuous monitoring:**
   ```bash
   # Run in tmux/screen background
   tmux new-session -d -s omnibus_monitor './scan_omnibus.sh --watch'
   ```

4. **Integrate with dashboards:**
   ```bash
   while true; do
     ./scan_omnibus.sh --json | curl -X POST http://dashboard:8080/health -d @-
     sleep 60
   done
   ```

---

## 📝 Version History

- **v1.0** (2026-03-11) - Initial release with 4 scanning engines
  - Kernel memory scanner
  - Connectivity mapper
  - Security validator
  - Health reporter

---

**Made with ❤️ for OmniBus v2.0.0**

Questions? See [CLAUDE.md](../CLAUDE.md) or [/help in Claude Code](/help).
