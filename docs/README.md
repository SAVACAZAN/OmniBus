# OmniBus Documentation Index

## 📚 Quick Navigation

### Getting Started
- **[CLAUDE.md](../CLAUDE.md)** – Project setup & development instructions
- **[../README.md](../README.md)** – Project overview

### Phase 72: Current Development

#### Wallet & On-Ramp System
- **[WALLET_STRUCTURE_DEMO.md](WALLET_STRUCTURE_DEMO.md)** ⭐ CURRENT
  - 5-domain post-quantum address mapping
  - Algorithm-to-prefix scheme (ob_omni_, ob_k1_, ob_f5_, ob_d5_, ob_s3_)
  - Ethereum bridge integration

- **[SEPOLIA_TESTING_GUIDE.md](SEPOLIA_TESTING_GUIDE.md)** ⭐ CURRENT
  - Step-by-step USDC → OMNI on-ramp testing
  - Real Sepolia testnet integration
  - 6-part testing procedure

### Reference Material

#### Cryptography
- **[reference/CRYPTO_ALGORITHMS.md](reference/CRYPTO_ALGORITHMS.md)**
  - NIST post-quantum algorithms
  - Key sizes & security levels
  - Algorithm implementations

#### Integration Guides
- **[reference/WEB_INTEGRATION_GUIDE.md](reference/WEB_INTEGRATION_GUIDE.md)**
  - Web3 integration patterns
  - API endpoint documentation

#### Whitepapers
- **[reference/RoyalOmniBusPaper.md](reference/RoyalOmniBusPaper.md)**
  - Complete system specification
  - Design rationale

---

## 📂 Archive (Legacy Documentation)

Superseded by current Phase 72 documentation:

- **archive/SEPOLIA_TESTNET_GUIDE.md** – Old Sepolia guide (replaced by SEPOLIA_TESTING_GUIDE.md)
- **archive/CLIENT_WALLET_SETUP.md** – Old wallet setup (replaced by WALLET_STRUCTURE_DEMO.md)
- **archive/AGENT_WALLET_MANIFEST.md** – Design documentation
- **archive/AGENT_OMNI_SALES.md** – Phase 66 agent sales system
- **archive/PHASE_66_ZIG_MONETIZATION.md** – Phase 66 monetization
- **archive/PRIVATE_KEY_ADDRESS_*.md** – Design documents
- **archive/OMNIBUS_WALLET_METADATA_SUMMARY.md** – Old metadata spec
- **archive/QUICK_START_MONETIZATION.md** – Legacy startup guide
- **archive/STATUS_TOKEN_PARTICIPATION.md** – Phase 52 token system
- **archive/MONETIZATION_SYSTEM.md** – Phase 52 monetization

---

## 🏗️ Project Structure

```
/home/kiss/OmniBus/
├── arch/                   Bootloader & x86-64 assembly
├── build/                  Build artifacts & compiled binaries
│   ├── objects/           Compiled .o files
│   ├── artifacts/         Test outputs & metadata
│   └── logs/              QEMU serial logs
├── modules/               OS layers (54 active modules)
│   ├── omnibus_blockchain_os/  USDC on-ramp, wallet, trading
│   ├── grid_os/           Grid trading engine
│   ├── analytics_os/      Price aggregation
│   └── [51 more active modules]
├── test/                  Test binaries & test code
├── docs/                  📍 You are here
│   ├── reference/        Reference material (whitepapers, algorithms)
│   └── archive/          Obsolete documentation
├── configs/              Configuration files
├── docker/               Docker deployment
├── k8s/                  Kubernetes manifests
├── services/             Microservice specs
├── tools/                Utility scripts
└── web/                  Web3 integration & front-end
```

---

## 🔗 Key Files at Root

- **Makefile** – Build system (170+ targets)
- **README.md** – Project overview
- **CLAUDE.md** – Development guide (CRITICAL)
- **READYTODELETE.md** – Cleanup manifest

---

## 📋 Phase 72 Status

✅ **Completed:**
- [x] Client multi-domain wallet (5 addresses per client)
- [x] Post-quantum algorithm mapping (Kyber-768, Falcon-512, Dilithium-5, SPHINCS+)
- [x] USDC → OMNI bridge on Sepolia testnet
- [x] Comprehensive testing guide
- [x] Project reorganization & cleanup

🚀 **Ready for:**
- [ ] Real Sepolia testnet integration
- [ ] Multiple client testing
- [ ] Mainnet migration planning

---

## 🗑️ Cleanup Status

**Phase 72 Reorganization Complete:**
- ✅ Moved all .o files → build/objects/
- ✅ Moved test binaries → test/binaries/
- ✅ Moved logs → build/logs/
- ✅ Archived legacy markdown → docs/archive/
- ✅ Organized reference docs → docs/reference/
- ✅ Created docs/ index
- ✅ Root directory: CLEAN

See **[../READYTODELETE.md](../READYTODELETE.md)** for full cleanup checklist.

---

**Last Updated:** 2026-03-18 (Phase 72)
