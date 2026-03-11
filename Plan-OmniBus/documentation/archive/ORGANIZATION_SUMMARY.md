# OmniBus Directory Organization — Clean App Structure

**Completed**: 2026-03-11
**Status**: ✅ Clean, organized, production-ready

---

## What We Did

We reorganized the OmniBus project to separate the **production application** from the **testing & planning hub**.

### Before
```
/OmniBus/ (cluttered)
├── services/
├── web/
├── modules/
├── docker/
├── k8s/
├── arch/
├── scripts/          ← Mixed with everything
├── docs/
└── [15+ documentation files scattered]
```

### After
```
/OmniBus/ (clean)
├── services/         — Production API code
├── web/              — Production UI (HTMX dashboard)
├── modules/          — 33 OS layers (bare-metal)
├── docker/           — Docker configs (referenced in Plan-OmniBus)
├── k8s/              — K8s manifests (referenced in Plan-OmniBus)
├── arch/             — Bootloader & kernel
├── build/            — Build artifacts
├── Plan-OmniBus/     ← All testing & planning here
└── [Essential docs only in root]

Plan-OmniBus/ (organized hub)
├── bash_tests/       — All bash test scripts
├── python_tests/     — All Python analysis tools
├── documentation/    — All guides & planning docs
└── config/           — All deployment configs
```

---

## Clean Root Directory

**Essential files remaining in root**:
- `CLAUDE.md` — Project guidelines
- `AGENT_HANDOFF.md` — Handoff documentation
- `IMPLEMENTATION_PLAN.md` — Architecture overview
- `Makefile` — Build system
- `README.md` — Project overview
- `.gitignore` — Git configuration

**This keeps the app clean and focused.**

---

## Production Application (Untouched)

### `/services/` — API Layer
- `omnibus_api_gateway.py` — FastAPI server (650 lines)
- `omnibus_integration_bridge.py` — Order pipeline (500 lines)

### `/web/` — Frontend
- `dashboard_scaled.html` — Real-time HTMX dashboard (500 lines)

### `/modules/` — 33 OS Layers
- Grid OS, Analytics OS, Execution OS
- BlockchainOS, NeuroOS, BankOS, StealthOS
- + 26 more protection/system layers
- All compiled bare-metal binaries

### `/arch/` — Bootloader & Kernel
- `boot.asm` — Stage 1 (512B)
- `stage2_fixed_final.asm` — Stage 2 (4KB)
- `kernel_stub.asm` — Kernel entry
- Complete boot chain to 64-bit long mode

### `/docker/` & `/k8s/`
- Production deployment configs
- Copied to Plan-OmniBus/config/ for reference

---

## Testing & Planning Hub: `Plan-OmniBus/`

### `/bash_tests/`
Complete deployment & integration testing:
```
bash_tests/
├── test_phase49_deployment.sh    (500+ lines) — 10 deployment tests
├── run_unit_tests.sh             (250 lines) — Unit tests (all 33 layers)
├── run_integration_tests.sh       (350 lines) — Order pipeline tests
└── run_stress_tests.sh            (400 lines) — Stress & stability tests
```

**Run any test**:
```bash
bash Plan-OmniBus/bash_tests/test_phase49_deployment.sh
bash Plan-OmniBus/bash_tests/run_unit_tests.sh
bash Plan-OmniBus/bash_tests/run_integration_tests.sh
bash Plan-OmniBus/bash_tests/run_stress_tests.sh
```

### `/python_tests/`
Analysis & validation utilities:
```
python_tests/
├── test_order_flow.py           — End-to-end order pipeline simulation
├── test_latency_baseline.py      — Per-module cycle measurements
├── test_multi_exchange_arb.py    — Kraken/Coinbase/LCX price analysis
├── test_percentiles.py           — P50/P95/P99/P99.9 latency distribution
├── test_critical_path.py         — Bottleneck identification
├── test_jitter_analysis.py       — Scheduler variance analysis
├── validate_memory.py            — Memory layout validation
└── analyze_performance.py        — Module profiling tool
```

**Run any analysis**:
```bash
python3 Plan-OmniBus/python_tests/test_latency_baseline.py
python3 Plan-OmniBus/python_tests/test_percentiles.py
python3 Plan-OmniBus/python_tests/analyze_performance.py
```

### `/documentation/`
Complete planning & deployment guides:
```
documentation/
├── SESSION_COMPLETE_SUMMARY.md          — ⭐ START HERE (Complete overview)
├── NEXT_STEPS_QUICK_START.md            — 6 deployment options
├── QUICKSTART_PHASE49.md                — 5-minute local setup
├── PHASE_49_ENTERPRISE_SCALING.md       — Full production guide
└── PHASE_49_50_COMPLETE_INTEGRATION.md  — Integration architecture
```

**READ THESE (in order)**:
1. `SESSION_COMPLETE_SUMMARY.md` — Understand what was delivered
2. `NEXT_STEPS_QUICK_START.md` — Choose your next action
3. `QUICKSTART_PHASE49.md` — Get running locally
4. Other docs — Deep dive into specific topics

### `/config/`
All deployment configurations:
```
config/
├── Dockerfile                    — Production API image
├── docker-compose.yml            — Local dev stack (Redis + API + Nginx)
├── omnibus-namespace.yaml        — K8s namespace
├── redis-statefulset.yaml        — K8s Redis cluster (3 nodes)
├── api-gateway-deployment.yaml   — K8s API replicas (100-1000)
├── ingress.yaml                  — K8s load balancer + TLS
└── prometheus-monitoring.yaml    — K8s monitoring (Prometheus)
```

**Deploy locally**:
```bash
cd Plan-OmniBus/config
docker-compose up -d
```

**Deploy to Kubernetes**:
```bash
kubectl apply -f Plan-OmniBus/config/
```

---

## File Organization Summary

| Location | Files | Purpose |
|----------|-------|---------|
| `/services/` | 2 | Production API code |
| `/web/` | 1 | Production dashboard |
| `/modules/` | 33 | Bare-metal OS layers |
| `/arch/` | 3 | Bootloader & kernel |
| `Plan-OmniBus/bash_tests/` | 4 | Bash test suites |
| `Plan-OmniBus/python_tests/` | 8 | Python analysis tools |
| `Plan-OmniBus/documentation/` | 5 | Planning & guides |
| `Plan-OmniBus/config/` | 7 | Deployment configs |
| **Root** | 15 | Essential project docs |

**Total**: ~88 files, cleanly organized

---

## Directory Tree (Clean View)

```
OmniBus/
│
├── 📁 PRODUCTION APPLICATION (untouched)
│   ├── services/              — FastAPI gateway + integration bridge
│   ├── web/                   — HTMX dashboard
│   ├── modules/               — 33 bare-metal OS layers
│   ├── arch/                  — Bootloader & kernel
│   └── build/                 — Build artifacts
│
├── 📁 TESTING & PLANNING HUB → Plan-OmniBus/
│   ├── bash_tests/            — 4 test suites (deployment, unit, integration, stress)
│   ├── python_tests/          — 8 analysis tools (latency, percentiles, validation)
│   ├── documentation/         — 5 planning guides (complete summary, quick start, etc.)
│   └── config/                — 7 deployment configs (Docker, K8s, Prometheus)
│
└── 📄 ESSENTIAL PROJECT DOCS
    ├── CLAUDE.md              — Project guidelines
    ├── AGENT_HANDOFF.md       — Handoff documentation
    ├── IMPLEMENTATION_PLAN.md — Architecture overview
    ├── README.md              — Project overview
    ├── Makefile               — Build system
    └── [Other reference docs]
```

---

## Quick Commands

### Local Testing
```bash
# Run deployment tests
bash Plan-OmniBus/bash_tests/test_phase49_deployment.sh

# Run all tests
bash Plan-OmniBus/bash_tests/run_*.sh

# Run Python analysis
python3 Plan-OmniBus/python_tests/test_latency_baseline.py
```

### Local Deployment
```bash
cd Plan-OmniBus/config
docker-compose up -d
open http://localhost/dashboard_scaled.html
```

### Cloud Deployment
```bash
kubectl apply -f Plan-OmniBus/config/
kubectl scale deployment api-gateway --replicas=1000 -n omnibus
```

### Read Documentation
```bash
# Complete overview
less Plan-OmniBus/documentation/SESSION_COMPLETE_SUMMARY.md

# Quick start
less Plan-OmniBus/documentation/NEXT_STEPS_QUICK_START.md

# Setup guide
less Plan-OmniBus/documentation/QUICKSTART_PHASE49.md
```

---

## Benefits of This Organization

✅ **Clean Root**: Core app files only
✅ **Separated Concerns**: Tests/docs isolated from production code
✅ **Easy Navigation**: All tests in one place, all configs in one place
✅ **Scalable**: Easy to add new tests/docs without cluttering root
✅ **Professional**: Clear structure for team collaboration
✅ **Documented**: Plan-OmniBus/README.md explains everything

---

## Next Steps

1. **Review organization**: `ls -la Plan-OmniBus/`
2. **Read docs**: Start with `Plan-OmniBus/documentation/SESSION_COMPLETE_SUMMARY.md`
3. **Run tests**: `bash Plan-OmniBus/bash_tests/test_phase49_deployment.sh`
4. **Deploy**: Choose Docker or Kubernetes from `Plan-OmniBus/config/`

---

## Status

✅ **Organization Complete**
- Production app: Clean and focused
- Tests & docs: Organized in Plan-OmniBus/
- All systems ready for deployment
- Clear path for continued development

**App is ready for production use.**
