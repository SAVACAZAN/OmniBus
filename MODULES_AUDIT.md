# OmniBus Modules Audit & Cleanup

**Date:** 2026-03-18 (Phase 72)
**Status:** Complete analysis of orphaned/unused modules

---

## 🔍 FINDINGS

### Section 1: Orphaned .zig Files (No Imports)

**⚠️ 11 files NOT IMPORTED ANYWHERE:**

```
- bip32_bip39.zig          (0 imports) – BIP32/39 HD wallet
- chain_addressing.zig     (0 imports) – Address generation
- crypto_primitives.zig    (0 imports) – Crypto utilities
- domain_attestation.zig   (0 imports) – Domain system
- gas_vault.zig            (0 imports) – Gas pricing
- key_rotation.zig         (0 imports) – Key management
- liboqs_ffi.zig           (0 imports) – Post-quantum FFI
- liboqs_wrapper.zig       (0 imports) – Post-quantum wrapper
- math_formulas.zig        (0 imports) – Math utilities
- post_quantum_crypto.zig  (0 imports) – PQ cryptography
- wallet_manager.zig       (0 imports) – Wallet management
```

**Status:** These are likely **planned/preparatory modules** for future phases
**Action:** MOVE TO `/modules/archive/planned_libraries/`

---

### Section 2: Build/Config Files (Should Not Be in modules/)

```
✗ wallet_manager.ld           – Linker script (move to build/)
✗ wallet_manager_egld_patch.txt – Patch file (move to archive/patches/)
```

**Action:** MOVE OUT OF modules/

---

### Section 3: Documentation Files (Should Be in docs/)

```
✗ cross_module_ipc.md         – IPC documentation (move to docs/reference/)
✗ ipc_protocol.md             – Protocol documentation (move to docs/reference/)
✗ performance_analysis.md     – Analysis document (move to docs/reference/)
✗ phase5d_disk_io_roadmap.md  – Legacy roadmap (move to docs/archive/)
```

**Action:** MOVE TO docs/ structure

---

## 📊 Module Organization Status

### Active Modules (54 verified in subdirectories)

**Core OS Layers (KEEP):**
```
✓ omnibus_blockchain_os/      – USDC on-ramp, wallet, trading [Phase 72 ACTIVE]
✓ grid_os/                    – Grid trading engine
✓ execution_os/               – Order execution
✓ analytics_os/               – Price aggregation
✓ ada_mother_os/              – Kernel validation
✓ neuro_os/                   – ML/genetic algorithm
✓ bank_os/                    – SWIFT/ACH settlement
✓ stealth_os/                 – MEV protection
```

**Security & Governance (KEEP):**
```
✓ consensus_engine_os/        – Byzantine fault tolerance
✓ checksum_os/                – Tier 1 validation
✓ audit_log_os/               – Event logging
✓ zorin_os/                   – Access control
✓ domain_resolver/            – ENS/ArNS resolution
✓ sel4_microkernel/           – Formal verification
✓ cross_validator_os/         – Divergence detection
```

**Data & Storage (KEEP):**
```
✓ database_os/                – Data persistence
✓ cassandra_os/               – Distributed storage
✓ historical_analytics_os/    – Time-series data
✓ persistent_state_os/        – State checkpointing
```

**Specialized Functions (KEEP):**
```
✓ mev_guard_os/               – Sandwich protection
✓ circuit_breaker_os/         – Emergency halt
✓ liquid_staking_os/          – Staking rewards
✓ slashing_protection_os/     – Validator insurance
✓ flash_loan_protection_os/   – DEX security
✓ orderflow_auction_os/       – MEV recapture
✓ multi_node_federation_os/   – Multi-processor
✓ cloud_federation_os/        – Multi-cloud
```

**...and 26 more active modules**

---

## 🗂️ Cleanup Actions

### Priority 1: Move Orphaned Files

```bash
# Move unused library files to archive/planned
mkdir -p modules/archive/planned_libraries
mv modules/{bip32_bip39,chain_addressing,crypto_primitives,domain_attestation,gas_vault,key_rotation,liboqs_ffi,liboqs_wrapper,math_formulas,post_quantum_crypto,wallet_manager}.zig modules/archive/planned_libraries/

# Move linker script to build/
mv modules/wallet_manager.ld build/

# Move patch file to archive/
mkdir -p archive/patches
mv modules/wallet_manager_egld_patch.txt archive/patches/
```

### Priority 2: Move Documentation

```bash
# Move reference docs to docs/reference/
mv modules/{cross_module_ipc,ipc_protocol,performance_analysis}.md docs/reference/

# Move legacy docs to docs/archive/
mv modules/phase5d_disk_io_roadmap.md docs/archive/
```

### Priority 3: Create Module-Level README Files

Each active module directory should have a README.md explaining:
- Purpose
- Key functions
- Integration points
- Memory layout (if applicable)
- Current status (active/experimental/deprecated)

---

## 📋 Execution Checklist

- [ ] Create modules/archive/planned_libraries/
- [ ] Move 11 unused .zig files → modules/archive/planned_libraries/
- [ ] Move wallet_manager.ld → build/
- [ ] Move wallet_manager_egld_patch.txt → archive/patches/
- [ ] Move .md files → docs/reference/ and docs/archive/
- [ ] Create README.md in each active module directory (54 modules)
- [ ] Create modules/README.md (index of all modules)
- [ ] Git commit: "Audit: Clean up modules directory - move orphaned files"
- [ ] Review: Are any "planned" modules needed for upcoming phases?

---

## 📝 Notes

**Why are these files orphaned?**
- Prepared for future integration (Phases 73+)
- Designed in early phases, not yet wired into build
- May be waiting on dependencies
- Could be alternate implementations

**Should we delete them?**
- NO - Keep in archive (may be needed later)
- Document why they exist
- Reference from roadmap

**Next Phase (73+):**
- Review "planned_libraries" for actual integration
- Wire up unused crypto/PQ libraries if needed
- Create module-level tests
- Verify all 54 modules compile together

---

**Status:** READY FOR EXECUTION
**Estimated Time:** ~15 minutes to execute all moves + create README files

See: /home/kiss/OmniBus/READYTODELETE.md for complete cleanup plan
