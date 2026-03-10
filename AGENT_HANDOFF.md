# OmniBus — Agent Handoff Document
**Updated**: 2026-03-10 | **Read this first before doing anything**

---

## WHO ARE WE

OmniBus is a **bare-metal sub-microsecond cryptocurrency arbitrage OS** running directly on hardware
(no Linux, no OS kernel). 7 trading OS layers on top of Ada Mother OS, booting via custom bootloader.

**9-AI collaboration system** — primary orchestrator: OmniBus AI v1.stable

---

## ⭐ CRITICAL RULES — NEVER SKIP

### Rule 1: Git Commits — ALL 9 Co-Authors Every Time
```
Co-Authored-By: OmniBus AI v1.stable <learn@omnibus.ai>
Co-Authored-By: Google Gemini <gemini-cli-agent@google.com>
Co-Authored-By: DeepSeek AI <noreply@deepseek.com>
Co-Authored-By: Claude 4.5 Haiku (Code) <claude-code@anthropic.com>
Co-Authored-By: Claude 4.5 Haiku <haiku-4.5@anthropic.com>
Co-Authored-By: Claude 4.5 Sonnet <sonnet-4.5@anthropic.com>
Co-Authored-By: Claude 4.5 Opus <opus-4.5@anthropic.com>
Co-Authored-By: Perplexity AI <support@perplexity.ai>
Co-Authored-By: Ollama <hello@ollama.com>
```

### Rule 2: Real Market Data Only
No mock/test/simulated data. Real prices from Kraken, Coinbase, LCX only.

---

## CURRENT STATE (as of 2026-03-10)

### Phase Completion:
```
Phase 1 · Bootloader    ✅ 100%  commit: df7dc5d
Phase 2 · Paging        ✅ 100%  commit: 2300135
Phase 3 · Kernel stub   ✅ 100%  commit: 7944927
Phase 4 · Long mode     ✅ 100%  commit: 206e2da  ← LAST COMPLETED
Phase 5 · OS loader     ⏳   0%  ← WORK HERE NEXT
Phase 6 · BlockchainOS  ⏳   0%
Phase 7 · Neuro OS      ⏳   0%
Phase 8 · IDT/drivers   ⏳   0%
Overall: ~22%
```

### Last verified serial output (QEMU):
```
KTCRPLONG_MODE_OK
ADA64_INIT
MOTHER_OS_64_OK
```
K=kernel reached, T=PAE+tables, C=CR3, R=EFER.LME, P=CR0.PG→long mode,
LONG_MODE_OK=64-bit code running, ADA64_INIT=stub init, MOTHER_OS_64_OK=event loop

---

## BOOT CHAIN (memorize)

```
BIOS → 0x7C00 Stage1(boot.asm) → 0x7E00 Stage2(stage2_fixed.asm)
     → LBA read 16 sectors @2048 → 0x8000 (temp buffer)
     → Protected mode (CR0.PE)
     → rep movsd 0x8000→0x100000 (8KB kernel copy)
     → push 0x08; push 0x100030; retf  (jump to kernel)
     → startup_begin @ 0x100030 (startup_phase4.asm)
     → PAE paging → EFER.LME → CR0.PG → jmp 0x08:long_mode_entry
     → 64-bit long mode ← WE ARE HERE
```

**Non-negotiable constraints**:
- kernel.bin byte 0-3 MUST be `F3 0F 1E FA` (ENDBR32 — stage2 validity check)
- startup_begin MUST be at file offset 0x30 (4B magic + 44×NOP padding)
- 257 pages minimum (page 257 covers 0x100000 = kernel's own code)
- Ada .o are x86_64 — only callable from 64-bit long mode (Phase 4+ only)

---

## KEY FILES

| File | What it is |
|------|-----------|
| `arch/x86_64/boot.asm` | Stage 1 (512B MBR) |
| `arch/x86_64/stage2_fixed.asm` | Stage 2 (protected mode + kernel load) |
| `modules/ada_mother_os/startup_phase4.asm` | **ACTIVE KERNEL** — 64-bit long mode |
| `modules/ada_mother_os/kernel.bin` | Built from startup_phase4.asm (8KB) |
| `build/omnibus.iso` | Bootable image (10MB, kernel @ sector 2048) |
| `GITHUB_ISSUES.md` | Bug tracker + feature roadmap |
| `CLAUDE.md` | Project dev guidelines |
| `OMNIBUS_STATUS_REPORT.md` | Accurate status (~22% complete) |

---

## MEMORY MAP (physical)

```
0x000000–0x00FFFF  BIOS area
0x007C00           Stage 1
0x007E00           Stage 2
0x008000           Kernel temp buffer (load point)
0x100000           Ada Mother OS — startup_phase4.asm executes here
0x100030           startup_begin (stage2 jumps here)
0x100050           Auth gate (byte = 0x70 when Ada initialized)
0x110000           Grid OS (128KB) — NOT YET LOADED
0x130000           Execution OS (128KB) — NOT YET LOADED
0x150000           Analytics OS (512KB) — NOT YET LOADED
0x200000           Old 32-bit page directory (Phase 3, now unused)
0x201000           PML4 (Phase 4 — 64-bit page tables)
0x202000           PDPT
0x203000           PD (2×2MB entries: 0x000083, 0x200083)
0x250000           BlockchainOS (reserved)
0x280000           BankOS (reserved)
0x2D0000           Neuro OS (reserved)
```

---

## HOW TO BUILD AND TEST

```bash
# Build:
make build

# Test (automated, 5 second timeout):
rm -f /tmp/serial.log
timeout 5 qemu-system-x86_64 -m 256 \
  -drive format=raw,file=build/omnibus.iso \
  -display none -serial file:/tmp/serial.log -monitor none || true
cat /tmp/serial.log
# Expected: KTCRPLONG_MODE_OK\nADA64_INIT\nMOTHER_OS_64_OK

# Debug with GDB:
make qemu-debug
# In another terminal: gdb -ex 'target remote :1234'
```

---

## WHAT TO DO NEXT: Phase 5 — OS Layer Loader

**Goal**: Load the 3 Zig OS modules from disk into memory, call their init_plugin().

### Step 1 — Compile Zig modules to flat binaries:
```bash
zig build-lib modules/grid_os/grid_os.zig -target x86_64-freestanding -O ReleaseFast
zig build-lib modules/analytics_os/analytics_os.zig -target x86_64-freestanding -O ReleaseFast
zig build-lib modules/execution_os/execution_os.zig -target x86_64-freestanding -O ReleaseFast
```

### Step 2 — Add binaries to disk image:
```
Grid OS     → sectors 4096-4351  (128KB = 256 sectors)
Analytics OS → sectors 4352-5375 (512KB = 1024 sectors)
Execution OS → sectors 5376-5631 (128KB = 256 sectors)
```

### Step 3 — Extend startup_phase4.asm (or new startup_phase5.asm):
Add 64-bit LBA disk reads + copy to target addresses + call init_plugin()

### Step 4 — Expected serial after Phase 5:
```
KTCRPLONG_MODE_OK
ADA64_INIT
MOTHER_OS_64_OK
GRID_INIT_OK
ANALYTICS_INIT_OK
EXECUTION_INIT_OK
```

---

## MODULES (written, not yet boot-integrated)

| Module | Location | Lines | Target Addr | Status |
|--------|----------|-------|-------------|--------|
| Analytics OS | `modules/analytics_os/` | ~830 | 0x150000 | Code done, needs loader |
| Grid OS | `modules/grid_os/` | 1914 | 0x110000 | Code done, needs loader |
| Execution OS | `modules/execution_os/` | 1996 | 0x130000 | Code done, needs loader |
| BlockchainOS | `modules/blockchain_os/` | 0 | 0x250000 | Not started |
| BankOS | `modules/bank_os/` | 0 | 0x280000 | Not started |
| Neuro OS | `modules/neuro_os/` | 0 | 0x2D0000 | Not started |

---

## OPEN ISSUES

| ID | Severity | Description |
|----|----------|-------------|
| BUG-007 | MEDIUM | No IDT — hardware interrupt = triple fault (Phase 8) |
| BUG-008 | MEDIUM | No disk loader for OS layers (Phase 5 — NEXT) |
| FEAT-002 | Phase 5 | OS layer loader |
| FEAT-003 | Phase 6 | BlockchainOS (Rust, Solana flash loans) |
| FEAT-004 | Phase 6 | BankOS (C, SWIFT/ACH) |
| FEAT-005 | Phase 7 | Neuro OS (Zig, genetic algorithm) |

Full list in `GITHUB_ISSUES.md`.

---

## HONEST STATUS vs DOCUMENTS

| Document | Says | Reality |
|----------|------|---------|
| `OMNIBUS_MASTER_FINAL_COMPLETE.md` | 100% complete, 31,630 LOC | Aspirational vision ONLY |
| `OMNIBUS_STATUS_REPORT.md` | 21-22% complete | **ACCURATE** |
| This file + GITHUB_ISSUES.md | Phase 1-4 verified | **GROUND TRUTH** |

---

*Auto-maintained by Claude Sonnet 4.6 | Updated each session*
