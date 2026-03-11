# 🚀 InfoScanOmniBus QuickStart

**Generated: 2026-03-11**

---

## 5-Second Start

```bash
cd /home/kiss/OmniBus/InfoScanOmniBus
./scan_omnibus.sh
```

That's it! Full diagnostic report in ~30 seconds.

---

## What You Get

### After Running `./scan_omnibus.sh`:

**Text Report:**
```
logs/omnibus_diagnostic_2026-03-11_19-50-00.txt
```

**On-Screen Output:**
```
📡 SCANNING ALL 47 MODULES...
  [Module status indicators]

🔗 INTERCONNECTIVITY MAP
  [Dependency graph]

🔒 SECURITY VALIDATION
  [Memory overlaps, IPC safety, crypto validation]

❤️  SYSTEM HEALTH REPORT
  [Latency, errors, memory profile]
```

---

## Common Tasks

### 1. Health Check Only (Fast)
```bash
./scan_omnibus.sh --health
```
**Output:** Module count, latency percentiles, error summary

### 2. Real-Time Monitoring
```bash
./scan_omnibus.sh --watch
```
Press `Ctrl+C` to exit. Updates every 5 seconds.

### 3. Check for Circular Dependencies
```bash
./scan_omnibus.sh --connectivity
```
If you see `✓ NO CIRCULAR DEPENDENCIES` → System is safe

### 4. Security Audit
```bash
./scan_omnibus.sh --security
```
Validates memory isolation, IPC safety, cryptographic signatures

### 5. Export to JSON (for CI/CD)
```bash
./scan_omnibus.sh --json > diagnostic.json
cat diagnostic.json | grep '"violations"'
```

### 6. Auto-Fix Issues
```bash
./scan_omnibus.sh --auto-repair
```
Automatically triggers AutoRepair OS (L10) if degradation detected

---

## Understanding the Output

### ✅ Green = All Good
```
🟢 HEALTHY:  36 modules
✅ SYSTEM STATUS: FULLY OPERATIONAL
✓ NO CIRCULAR DEPENDENCIES
✓ All memory segments properly isolated
```

### ⚠️ Yellow = Degraded (But Still Works)
```
🟡 DEGRADED: 1 module (AutoRepair OS - 3 repairs done)
⚠️  SYSTEM STATUS: DEGRADED (1 module)
```
→ Monitor closely, may need action soon

### 🔴 Red = Critical
```
🔴 ERROR: 2 modules
🚨 SYSTEM STATUS: CRITICAL (2 errors)
```
→ **STOP TRADING** - Fix immediately

---

## Key Files

| File | Purpose |
|------|---------|
| `scan_omnibus.sh` | Master coordinator (run this!) |
| `omnibus_kernel_scanner.py` | Reads kernel memory & module states |
| `connectivity_mapper.py` | Analyzes inter-module dependencies |
| `security_validator.py` | Validates memory isolation & IPC safety |
| `health_reporter.py` | System health & latency profiling |
| `INTERCONNECTIVITY_MATRIX.md` | Detailed map of module communication |
| `README.md` | Full documentation |

---

## 47 Modules Organized by Tier

### Tier 1: Trading (Critical)
- Grid OS (L01) - Matching engine
- Execution OS (L02) - Order signing
- Analytics OS (L03) - Price aggregation
- BlockchainOS (L04) - Flash loans
- NeuroOS (L05) - AI optimization
- BankOS (L06) - SWIFT/ACH settlement
- StealthOS (L07) - MEV protection

### Tier 2: System Services
- Report OS (L08) - Daily PnL/Sharpe
- Checksum OS (L09) - Memory validation
- AutoRepair OS (L10) - Auto-healing
- Zorin OS (L11) - Access control
- Audit Log OS (L12) - Forensics
- Parameter Tuning OS (L13) - Grid optimization
- Historical Analytics OS (L14) - Time-series DB

### Tier 3: Notification
- Alert System OS (L15)
- Consensus Engine OS (L16)
- Federation OS (L17)
- MEV Guard OS (L18)

### Tier 4: Protection
- Cross-Chain Bridge OS (L19)
- DAO Governance OS (L20)
- Recovery OS (L21)
- Compliance OS (L22)
- Staking OS (L23)
- Slashing Protection OS (L24)
- Orderflow Auction OS (L25)
- Circuit Breaker OS (L26)
- Flash Loan Protection OS (L27)
- L2 Rollup Bridge OS (L28)
- Quantum-Resistant Crypto OS (L29)
- PQC-GATE OS (L30)

### Tier 5: Formal Verification
- seL4 Microkernel (L31)
- Cross-Validator OS (L32)
- Formal Proofs OS (L33)
- Convergence Test OS (L34)
- Domain Resolver OS (L35)
- LoggingOS (L36) - Phase 57
- DatabaseOS (L37) - Phase 58
- CassandraOS (L38) - Phase 58B
- MetricsOS (L39) - Phase 59

---

## Troubleshooting

### Error: "Permission denied: /dev/mem"
```bash
sudo ./scan_omnibus.sh
```
Kernel memory reads require sudo.

### Error: "Python3 not found"
```bash
apt-get install python3  # Linux
brew install python3     # macOS
```

### Scan is slow
This is normal! 47 modules = lots to scan. Takes 30-60 seconds.

### See: "DEGRADED" or "ERROR"
→ Run `./scan_omnibus.sh --auto-repair` to fix

---

## Integration Examples

### Before Starting Trading
```bash
./scan_omnibus.sh | grep "FULLY OPERATIONAL"
# If found → Safe to start trading
```

### CI/CD Pipeline (GitHub Actions)
```bash
python3 connectivity_mapper.py --json | grep -q '"circular_deps": 0' || exit 1
```

### Monitor in Background
```bash
# In tmux/screen
./scan_omnibus.sh --watch
```

### Regular Health Snapshots
```bash
# Daily cron
0 0 * * * cd /path/to/OmniBus && ./InfoScanOmniBus/scan_omnibus.sh --json >> diagnostics.log
```

---

## What Happens Inside?

**The 4 Scanning Engines:**

1. **Kernel Scanner** - Reads `/dev/mem`, scans all 47 module headers
   - State code (initializing/ready/running/error)
   - Execution counters
   - Error flags

2. **Connectivity Mapper** - Analyzes dependency graph
   - Detects circular deps (FATAL if found)
   - Calculates critical path
   - Identifies bottlenecks (fan-in) & complexity (fan-out)

3. **Security Validator** - Checks isolation & IPC safety
   - Memory segment overlaps (CRITICAL if found)
   - Cryptographic signatures
   - Formal verification coverage (T1-T4)

4. **Health Reporter** - Current status snapshot
   - Module health (HEALTHY/DEGRADED/ERROR)
   - Latency percentiles (P50/P95/P99)
   - Memory usage profile
   - Error summary & recommendations

---

## Expected Healthy State

```
✅ 36 modules HEALTHY
✅ 0 circular dependencies
✅ 0 memory overlaps
✅ 0 IPC authorization violations
✅ All crypto signatures valid
✅ <100μs Tier 1 latency
✅ Formal proof coverage >85%
```

---

## Next Steps

1. **Run first diagnostic:**
   ```bash
   ./scan_omnibus.sh > baseline.txt
   ```

2. **Review for issues:**
   ```bash
   grep -E "(ERROR|CRITICAL|❌)" baseline.txt
   ```

3. **Set up monitoring:**
   ```bash
   ./scan_omnibus.sh --watch &  # Background
   ```

4. **Before each trading session:**
   ```bash
   ./scan_omnibus.sh --health | grep "FULLY OPERATIONAL"
   ```

---

## Advanced Usage

### Export metrics to Prometheus
```bash
./scan_omnibus.sh --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('omnibus_modules_healthy', data['diagnostics']['overall_status']['healthy'])
print('omnibus_latency_p99_us', data['diagnostics']['latency_percentiles']['p99'])
"
```

### Track latency over time
```bash
for i in {1..10}; do
  ./scan_omnibus.sh --json | \
    python3 -c "import json, sys; d=json.load(sys.stdin); print(d['diagnostics']['latency_percentiles']['p99'])"
  sleep 60
done | tee latency_trend.txt
```

### Git-tracked health snapshots
```bash
./scan_omnibus.sh --json > diagnostics/$(date +%s).json
git add diagnostics/
git commit -m "Health snapshot: $(./scan_omnibus.sh --health | grep HEALTHY)"
```

---

## Support

- **Full docs:** `README.md`
- **Detailed interconnectivity:** `INTERCONNECTIVITY_MATRIX.md`
- **Project architecture:** `../CLAUDE.md`
- **System design:** `../ARCHITECTURE.md`
- **Formal verification:** `../WHITEPAPER.md`

---

**Ready? Start scanning!**

```bash
./scan_omnibus.sh
```

Good luck! 🚀
