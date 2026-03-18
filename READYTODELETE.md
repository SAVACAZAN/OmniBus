# OmniBus Project Cleanup - READY TO DELETE

## Status: Phase 72 Cleanup Initiative
**Date:** 2026-03-18
**Purpose:** Remove obsolete files, organize structure, maintain production readiness

---

## SECTION 1: Orphaned Build Artifacts (Move to build/)

**Object Files (.o) - MOVE TO build/objects/**
```
- /home/kiss/OmniBus/ws_collector.o
- /home/kiss/OmniBus/p2p_node.o
- /home/kiss/OmniBus/vault_storage.o
- /home/kiss/OmniBus/pqc_wallet_bridge.o
- /home/kiss/OmniBus/vid_shard_grid.o
- /home/kiss/OmniBus/omnibus_blockchain_os.o
- /home/kiss/OmniBus/omnibus_wallet.o
- /home/kiss/OmniBus/wallet_api.o
- /home/kiss/OmniBus/node_identity.o
- /home/kiss/OmniBus/omnibus_opcodes.o
```

**Test Binaries - MOVE TO test/**
```
- /home/kiss/OmniBus/test_wallets_extended
- /home/kiss/OmniBus/test_omnibus_native
- /home/kiss/OmniBus/test_wallets
- /home/kiss/OmniBus/test_omnibus_unified_addresses
- /home/kiss/OmniBus/test_omnibus_bip44_lightning
```

**Metadata Artifacts - MOVE TO build/artifacts/**
```
- /home/kiss/OmniBus/omnibus_complete_metadata_with_keys
- /home/kiss/OmniBus/omnibus_complete_metadata
- /home/kiss/OmniBus/omnibus_wallet_metadata
- /home/kiss/OmniBus/omnibus_complete_wallet_test
- /home/kiss/OmniBus/wallet_generation_examples
```

**Logs - MOVE TO build/logs/**
```
- /home/kiss/OmniBus/qemu_full_output.log
- /home/kiss/OmniBus/qemu_wallet_output.log
```

---

## SECTION 2: Orphaned Files

**Sensitive Files (DELETE or move to archive/sensitive/)**
```
- /home/kiss/OmniBus/YOUR_WALLET.txt  (Contains test keys - archive if needed)
```

**Build Scripts (consolidate with Makefile)**
```
- /home/kiss/OmniBus/QUICK_START_WALLET.sh  (Legacy - check if still used)
```

---

## SECTION 3: Duplicate/Redundant Markdown

**Keep (Essential Documentation):**
- `README.md` – Project overview
- `CLAUDE.md` – Development instructions
- `WALLET_STRUCTURE_DEMO.md` – Current wallet spec (Phase 72)
- `SEPOLIA_TESTING_GUIDE.md` – Current testing guide (Phase 72)

**Archive to docs/archive/ (Legacy/Superseded):**
```
- SEPOLIA_TESTNET_GUIDE.md  (replaced by SEPOLIA_TESTING_GUIDE.md)
- CLIENT_WALLET_SETUP.md  (replaced by WALLET_STRUCTURE_DEMO.md)
- AGENT_WALLET_MANIFEST.md  (design doc - archive)
- AGENT_OMNI_SALES.md  (Phase 66 - archive)
- PHASE_66_ZIG_MONETIZATION.md  (Phase 66 - archive)
- PRIVATE_KEY_ADDRESS_MAPPING.md  (design doc - archive)
- PRIVATE_KEY_ADDRESS_TABLE.md  (design doc - archive)
- OMNIBUS_WALLET_METADATA_SUMMARY.md  (superseded)
- QUICK_START_MONETIZATION.md  (legacy)
- STATUS_TOKEN_PARTICIPATION.md  (Phase 52 - archive)
- MONETIZATION_SYSTEM.md  (Phase 52 - archive)
- OMNI_NATIVE_TOKEN.md  (design doc - archive)
```

**Keep in docs/reference/ (Reference Material):**
```
- CRYPTO_ALGORITHMS.md  (Algorithm reference)
- WEB_INTEGRATION_GUIDE.md  (Integration reference)
- RoyalOmniBusPaper.md  (Whitepaper reference)
```

---

## SECTION 4: Directory Reorganization

**Create New Structure:**
```
/home/kiss/OmniBus/
├── arch/                    (KEEP)
├── build/                   (KEEP - but organize)
│   ├── objects/            (ADD - .o files)
│   ├── artifacts/          (ADD - metadata outputs)
│   ├── logs/               (ADD - qemu logs)
│   └── omnibus.iso         (KEEP)
├── modules/                (KEEP - but audit)
│   ├── [54 active modules] (KEEP)
│   └── archive/            (ADD - deprecated modules)
├── test/                   (KEEP)
│   ├── [existing tests]
│   └── [move binaries here]
├── docs/                   (CREATE)
│   ├── README.md
│   ├── WALLET_STRUCTURE_DEMO.md
│   ├── SEPOLIA_TESTING_GUIDE.md
│   ├── CRYPTO_ALGORITHMS.md
│   ├── reference/          (Whitepapers, design docs)
│   └── archive/            (Obsolete documentation)
├── configs/                (KEEP)
├── docker/                 (KEEP)
├── k8s/                    (KEEP)
├── services/               (KEEP)
├── tools/                  (KEEP)
├── web/                    (KEEP)
├── archive/                (KEEP - legacy code snapshots)
└── [Root level]
    ├── Makefile            (KEEP)
    ├── README.md           (points to docs/)
    ├── CLAUDE.md           (KEEP)
    └── ⚠️ NO .o, .log, test_* files
```

---

## SECTION 5: Module Audit Status

**Active Modules (54):** KEEP
```
All modules in /modules/omnibus_blockchain_os/ + other active OS layers
```

**Candidate for Archive (Review):**
```
- test_omnibus_*.zig files in modules/ (move to test/)
- wallet_generation_examples.zig (move to docs/examples/)
```

---

## SECTION 6: Execution Checklist

- [ ] Create `/build/objects/`, `/build/artifacts/`, `/build/logs/`
- [ ] Create `/docs/`, `/docs/reference/`, `/docs/archive/`
- [ ] Create `/modules/archive/`
- [ ] Move all .o files → `/build/objects/`
- [ ] Move test binaries → `/test/`
- [ ] Move qemu logs → `/build/logs/`
- [ ] Move metadata artifacts → `/build/artifacts/`
- [ ] Archive duplicate/legacy .md → `/docs/archive/`
- [ ] Create `/docs/README.md` (index)
- [ ] Keep essential .md at root (README.md, CLAUDE.md)
- [ ] Delete `/YOUR_WALLET.txt` (sensitive) or archive
- [ ] Update root README.md to reference `/docs/`
- [ ] Git commit: "Cleanup: Reorganize project structure"

---

## SECTION 7: Disk Space Recovery

**Before Cleanup:**
- build/: 290GB (⚠️ CRITICAL)
- modules/: 4.5MB (OK)
- Root .o files: ~50MB (can move)

**After Cleanup:**
- Organize build artifacts
- Verify omnibus.iso location
- Archive old logs
- Root directory: CLEAN

---

## SECTION 8: Files to Permanently Delete (Sensitive/Unused)

**🚨 HIGH PRIORITY - SENSITIVE FILES:**
```
- /home/kiss/OmniBus/YOUR_WALLET.txt  (Contains test private keys!)
  ACTION: Delete or move to archive/sensitive/ with restricted access
```

**❌ NOT NEEDED:**
- Any .asm files at root (should be in arch/)
- Any duplicate config files

---

## Notes

- **Do NOT delete** .git/ or .claude/ directories
- **Do NOT delete** Makefile or arch/ directory (bootloader essential)
- **Do NOT move** active module source code
- **Verify** 290GB build/ directory content before cleanup
- **Keep** all .gitignore rules intact
- **Update** CI/CD paths if any (check Makefile)

---

**Created by:** Phase 72 Cleanup Initiative
**Status:** READY FOR EXECUTION
**Review by:** User before running cleanup script
