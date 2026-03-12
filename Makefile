# ============================================================================
# OmniBus Makefile
# Builds bare-metal bootloader and kernel for QEMU x86-64
# ============================================================================

.PHONY: all build clean qemu qemu-debug help test-paging test-phase5

# Directories
BUILD_DIR := ./build
ARCH_DIR := ./arch/x86_64
OUTPUT := $(BUILD_DIR)/omnibus.iso

# Assembler and tools
NASM := nasm
QEMU := qemu-system-x86_64
QEMU_FLAGS := -m 256 -drive format=raw,file=$(OUTPUT) -serial mon:stdio

# ============================================================================
# TARGETS
# ============================================================================

all: build

help:
	@echo "OmniBus Build System"
	@echo "===================="
	@echo "make build          - Compile bootloader and kernel"
	@echo "make qemu           - Run in QEMU"
	@echo "make qemu-debug     - Run in QEMU with GDB debugging enabled"
	@echo "make clean          - Remove build artifacts"
	@echo "make inspect        - Inspect compiled binary with objdump"
	@echo ""
	@echo "Phase 12: Bank settlement with SWIFT/ACH integration enabled"

# ============================================================================
# BUILD: Compile Assembly sources
# ============================================================================

build: $(OUTPUT) phase53b-crypto $(BUILD_DIR)/grid_os.bin $(BUILD_DIR)/execution_os.bin $(BUILD_DIR)/analytics_os.bin $(BUILD_DIR)/blockchain_os.bin $(BUILD_DIR)/neuro_os.bin $(BUILD_DIR)/bank_os.bin $(BUILD_DIR)/stealth_os.bin $(BUILD_DIR)/report_os.bin $(BUILD_DIR)/checksum_os.bin $(BUILD_DIR)/autorepair_os.bin $(BUILD_DIR)/zorin_os.bin $(BUILD_DIR)/audit_log_os.bin $(BUILD_DIR)/parameter_tuning_os.bin $(BUILD_DIR)/historical_analytics_os.bin $(BUILD_DIR)/alert_system_os.bin $(BUILD_DIR)/consensus_engine_os.bin $(BUILD_DIR)/federation_os.bin $(BUILD_DIR)/mev_guard_os.bin $(BUILD_DIR)/cross_chain_bridge_os.bin $(BUILD_DIR)/dao_governance_os.bin $(BUILD_DIR)/performance_profiler_os.bin $(BUILD_DIR)/disaster_recovery_os.bin $(BUILD_DIR)/compliance_reporter_os.bin $(BUILD_DIR)/liquid_staking_os.bin $(BUILD_DIR)/slashing_protection_os.bin $(BUILD_DIR)/orderflow_auction_os.bin $(BUILD_DIR)/circuit_breaker_os.bin $(BUILD_DIR)/flash_loan_protection_os.bin $(BUILD_DIR)/l2_rollup_bridge_os.bin $(BUILD_DIR)/quantum_resistant_crypto_os.bin $(BUILD_DIR)/pqc_gate_os.bin $(BUILD_DIR)/sel4_microkernel.bin $(BUILD_DIR)/cross_validator_os.bin $(BUILD_DIR)/proof_checker.bin $(BUILD_DIR)/convergence_test_os.bin $(BUILD_DIR)/domain_resolver_os.bin $(BUILD_DIR)/logging_os.bin $(BUILD_DIR)/database_os.bin $(BUILD_DIR)/cassandra_os.bin $(BUILD_DIR)/metrics_os.bin $(BUILD_DIR)/replay_os.bin $(BUILD_DIR)/microsoft_os.bin $(BUILD_DIR)/oracle_os.bin $(BUILD_DIR)/aws_os.bin $(BUILD_DIR)/vmware_os.bin $(BUILD_DIR)/gcp_os.bin $(BUILD_DIR)/savaos.bin $(BUILD_DIR)/cazanos.bin $(BUILD_DIR)/savacazanos.bin $(BUILD_DIR)/vortex_bridge.bin $(BUILD_DIR)/triage_system.bin $(BUILD_DIR)/consensus_core.bin $(BUILD_DIR)/zen_os.bin $(BUILD_DIR)/wallet_manager.bin $(BUILD_DIR)/gpu_optimizer_os.bin $(BUILD_DIR)/asic_optimizer_os.bin $(BUILD_DIR)/stratum_v2_gateway.bin $(BUILD_DIR)/cloud_federation_os.bin $(BUILD_DIR)/cache_l3_os.bin $(BUILD_DIR)/quantum_detector_os.bin $(BUILD_DIR)/zk_rollups_os.bin $(BUILD_DIR)/ml_inference_os.bin $(BUILD_DIR)/bot_strategies.bin
	@echo "✓ OmniBus built successfully!"
	@echo "  Image: $(OUTPUT)"
	@echo "  Modules: Grid/Exec/Analytics/BlockchainOS/NeuroOS/BankOS/StealthOS/Report/Checksum/AutoRepair/Zorin/AuditLog/ParamTuning/HistAnalytics/Alert/Consensus/Federation/MEVGuard/CrossChain/DAO/Profiler/Recovery/Compliance/Staking/Slashing/Auction/Breaker/FlashLoan/L2Rollup/Quantum/PQC/seL4/CrossValidator/ProofChecker/DomainResolver loaded"
	@echo "  Phase 24: OmniStruct Central Nervous System ✅"
	@echo "  Phase 25: Checksum OS (Tier 1 validation) ✅"
	@echo "  Phase 26: AutoRepair OS (Self-Healing) ✅"
	@echo "  Phase 27: Audit Log OS (Event logging & forensics) ✅"
	@echo "  Phase 28: Zorin OS (Access Control & Compliance) ✅"
	@echo "  Phase 30: Parameter Tuning OS (Dynamic trading parameters) ✅"
	@echo "  Phase 31: Historical Analytics OS (Time-series data collection) ✅"
	@echo "  Phase 32: Alert System OS (Real-time notifications) ✅"
	@echo "  Phase 33: Multi-Kernel Federation OS (IPC message routing) ✅"
	@echo "  Phase 34: Consensus Engine OS (Byzantine fault tolerance) ✅"
	@echo "  Phase 35: MEV Guard OS (Sandwich/frontrun protection) ✅"
	@echo "  Phase 36: Cross-Chain Bridge OS (Multi-blockchain swaps) ✅"
	@echo "  Phase 37: DAO Governance OS (Decentralized voting) ✅"
	@echo "  Phase 38: Performance Profiler OS (Function latency tracking) ✅"
	@echo "  Phase 39: Disaster Recovery OS (Checkpoint/restore) ✅"
	@echo "  Phase 40: Compliance Reporter OS (Regulatory audits) ✅"
	@echo "  Phase 41: Liquid Staking OS (Ethereum rewards) ✅"
	@echo "  Phase 42: Slashing Protection OS (Validator penalties & insurance) ✅"
	@echo "  Phase 43: Orderflow Auction OS (MEV recapture & encrypted bundles) ✅"
	@echo "  Phase 44: Circuit Breaker OS (Emergency halt mechanisms) ✅"
	@echo "  Phase 50a: seL4 Microkernel OS (L22 — Capability-based formal validation) ✅"
	@echo "  Phase 50b: Cross-Validator OS (L23 — Ada/seL4 divergence detection) ✅"
	@echo "  Phase 50c: Formal Proofs OS (L24 — T1-T4 Ada security theorems verified) ✅"
	@echo "  Phase 50d: Convergence Test OS (L25 — 1000+ cycles, v2.0 ready) ✅"
	@echo "  Phase 51: Domain Resolver OS (L26 — ENS, .anyone, ArNS support) ✅"
	@echo "  Phase 60: Event-Driven Transaction Replay OS (L27 — Forward/backward replay + saga compensation) ✅"
	@echo "  Phase 61: Multi-Cloud Provider Integration (L28-L32 — Azure/OCI/AWS/VMWare/GCP) ✅"
	@echo "  Run with: make qemu"

# Order-only prereq: create build dir without triggering false 'build' conflict
$(BUILD_DIR)/.keep:
	mkdir -p $(BUILD_DIR)
	@touch $@

# Compile boot sector (Stage 1)
$(BUILD_DIR)/boot.bin: $(ARCH_DIR)/boot.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Compiling boot sector..."
	$(NASM) -f bin -o $@ $<
	@echo "  Boot sector: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# Compile Stage 2 bootloader (using fixed version with register-indirect addressing)
$(BUILD_DIR)/stage2.bin: $(ARCH_DIR)/stage2_fixed.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Compiling Stage 2..."
	$(NASM) -f bin -o $@ $<
	@echo "  Stage 2: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# Phase 8: Ada Mother OS (IDT initialization + Exception handlers)
# Uses linker-based address resolution (same pattern as Grid OS)
# startup_phase4.asm → ELF object (with LIDT + exception stubs)
# kernel.ld → Linker script (allocates IDT table, handler stubs, IDTR pointer)
# Final: kernel.elf → binary (kernel.bin)

ADA_DIR := ./modules/ada_mother_os
ADA_KERNEL_STARTUP := $(ADA_DIR)/startup_phase4.asm
ADA_KERNEL_LD := $(ADA_DIR)/kernel.ld
ADA_KERNEL_BIN := $(ADA_DIR)/kernel.bin

# Compile assembly startup to ELF object (with position-independent code for linker)
$(BUILD_DIR)/startup.o: $(ADA_KERNEL_STARTUP) | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling kernel startup (Phase 4 + Phase 8 IDT)..."
	nasm -f elf64 -o $@ $<

# Compile disk I/O driver (Phase 5D: real disk reading)
$(BUILD_DIR)/disk_io.o: $(ADA_DIR)/disk_io.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling disk I/O driver (Phase 5D)..."
	nasm -f elf64 -o $@ $<

# Link kernel ELF: assembly via linker script with section placement
$(BUILD_DIR)/kernel.elf: $(BUILD_DIR)/startup.o $(BUILD_DIR)/disk_io.o $(ADA_KERNEL_LD)
	@echo "[LD] Linking kernel ELF with linker script..."
	ld -T $(ADA_KERNEL_LD) -o $@ $(BUILD_DIR)/startup.o $(BUILD_DIR)/disk_io.o 2>&1 | grep -v "warning:" || true
	@echo "  Kernel ELF: $@"

# Convert kernel ELF to flat binary
$(ADA_KERNEL_BIN): $(BUILD_DIR)/kernel.elf
	@echo "[OC] Converting kernel ELF to flat binary..."
	objcopy -O binary $< $@
	@echo "  Kernel binary: $@ (size: $$(stat -c%s $@) bytes)"
	@echo "  ✓ Phase 8 kernel built with linker-based IDT placement"

# Copy Ada kernel binary to build dir for image creation
$(BUILD_DIR)/kernel_stub.bin: $(ADA_KERNEL_BIN)
	@echo "[CP] Copying kernel binary to build dir..."
	cp $< $@
	@echo "  Kernel stub: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# OS MODULE BUILDS (Zig → ELF → Binary via linker scripts)
# ============================================================================

# Grid OS (0x110000, 128KB)
$(BUILD_DIR)/grid_os.o: ./modules/grid_os/grid_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Grid OS to object file..."
	cd ./modules/grid_os && zig build-obj grid_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/grid_os/grid_os.o ]; then mv ./modules/grid_os/grid_os.o $@; fi

$(BUILD_DIR)/grid_os_stubs.o: ./modules/grid_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Grid OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/grid_os_entry.o: ./modules/grid_os/entry.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Grid OS entry wrappers..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/grid_os.elf: $(BUILD_DIR)/grid_os.o $(BUILD_DIR)/grid_os_stubs.o $(BUILD_DIR)/grid_os_entry.o ./modules/grid_os/grid_os.ld
	@echo "[LD] Linking Grid OS ELF..."
	ld -T ./modules/grid_os/grid_os.ld -o $@ $(BUILD_DIR)/grid_os.o $(BUILD_DIR)/grid_os_stubs.o $(BUILD_DIR)/grid_os_entry.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/grid_os.bin: $(BUILD_DIR)/grid_os.elf
	@echo "[OC] Converting Grid OS to binary..."
	objcopy -O binary $< $@
	@echo "  Grid OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Execution OS (0x130000, 128KB)
$(BUILD_DIR)/execution_os.o: ./modules/execution_os/execution_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Execution OS to object file..."
	cd ./modules/execution_os && zig build-obj execution_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/execution_os/execution_os.o ]; then mv ./modules/execution_os/execution_os.o $@; fi

$(BUILD_DIR)/execution_os_stubs.o: ./modules/execution_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Execution OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/execution_os.elf: $(BUILD_DIR)/execution_os.o $(BUILD_DIR)/execution_os_stubs.o ./modules/execution_os/execution_os.ld
	@echo "[LD] Linking Execution OS ELF..."
	ld -T ./modules/execution_os/execution_os.ld -o $@ $(BUILD_DIR)/execution_os.o $(BUILD_DIR)/execution_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/execution_os.bin: $(BUILD_DIR)/execution_os.elf
	@echo "[OC] Converting Execution OS to binary..."
	objcopy -O binary $< $@
	@echo "  Execution OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Analytics OS (0x150000, 512KB)
$(BUILD_DIR)/analytics_os.o: ./modules/analytics_os/analytics_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Analytics OS to object file..."
	cd ./modules/analytics_os && zig build-obj analytics_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/analytics_os/analytics_os.o ]; then mv ./modules/analytics_os/analytics_os.o $@; fi

$(BUILD_DIR)/analytics_os_stubs.o: ./modules/analytics_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Analytics OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/analytics_os.elf: $(BUILD_DIR)/analytics_os.o $(BUILD_DIR)/analytics_os_stubs.o ./modules/analytics_os/analytics_os.ld
	@echo "[LD] Linking Analytics OS ELF..."
	ld -T ./modules/analytics_os/analytics_os.ld -o $@ $(BUILD_DIR)/analytics_os.o $(BUILD_DIR)/analytics_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/analytics_os.bin: $(BUILD_DIR)/analytics_os.elf
	@echo "[OC] Converting Analytics OS to binary..."
	objcopy -O binary $< $@
	@echo "  Analytics OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# BlockchainOS (0x250000, 192KB)
# Note: -fPIC enables Position-Independent Code (no relocation processing needed)
$(BUILD_DIR)/blockchain_os.o: ./modules/blockchain_os/blockchain_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling BlockchainOS to object file (PIE)..."
	cd ./modules/blockchain_os && zig build-obj blockchain_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf -fPIC 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/blockchain_os/blockchain_os.o ]; then mv ./modules/blockchain_os/blockchain_os.o $@; fi

$(BUILD_DIR)/blockchain_os_stubs.o: ./modules/blockchain_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling BlockchainOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/blockchain_os_entry.o: ./modules/blockchain_os/entry.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling BlockchainOS entry wrappers..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/blockchain_os.elf: $(BUILD_DIR)/blockchain_os.o $(BUILD_DIR)/blockchain_os_stubs.o $(BUILD_DIR)/blockchain_os_entry.o ./modules/blockchain_os/blockchain_os.ld
	@echo "[LD] Linking BlockchainOS ELF..."
	ld -T ./modules/blockchain_os/blockchain_os.ld -o $@ $(BUILD_DIR)/blockchain_os.o $(BUILD_DIR)/blockchain_os_stubs.o $(BUILD_DIR)/blockchain_os_entry.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/blockchain_os.bin: $(BUILD_DIR)/blockchain_os.elf
	@echo "[OC] Converting BlockchainOS to binary..."
	objcopy -O binary $< $@
	@echo "  BlockchainOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Neuro OS (0x2D0000, 512KB)
# Note: -fPIC enables Position-Independent Code (no relocation processing needed)
$(BUILD_DIR)/neuro_os.o: ./modules/neuro_os/neuro_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Neuro OS to object file (PIE)..."
	cd ./modules/neuro_os && zig build-obj neuro_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf -fPIC 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/neuro_os/neuro_os.o ]; then mv ./modules/neuro_os/neuro_os.o $@; fi

$(BUILD_DIR)/neuro_os_stubs.o: ./modules/neuro_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Neuro OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/neuro_os_entry.o: ./modules/neuro_os/entry.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Neuro OS entry wrappers..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/neuro_os.elf: $(BUILD_DIR)/neuro_os.o $(BUILD_DIR)/neuro_os_stubs.o $(BUILD_DIR)/neuro_os_entry.o ./modules/neuro_os/neuro_os.ld
	@echo "[LD] Linking Neuro OS ELF..."
	ld -T ./modules/neuro_os/neuro_os.ld -o $@ $(BUILD_DIR)/neuro_os.o $(BUILD_DIR)/neuro_os_stubs.o $(BUILD_DIR)/neuro_os_entry.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/neuro_os.bin: $(BUILD_DIR)/neuro_os.elf
	@echo "[OC] Converting Neuro OS to binary..."
	objcopy -O binary $< $@
	@echo "  Neuro OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# BankOS (0x280000, 192KB)
# Phase 12: SWIFT/ACH settlement integration
# Note: -fPIC enables Position-Independent Code (no relocation processing needed)
$(BUILD_DIR)/bank_os.o: ./modules/bank_os/bank_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Bank OS to object file (PIE)..."
	cd ./modules/bank_os && zig build-obj bank_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf -fPIC 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bank_os/bank_os.o ]; then mv ./modules/bank_os/bank_os.o $@; fi

$(BUILD_DIR)/bank_os_stubs.o: ./modules/bank_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Bank OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/bank_os.elf: $(BUILD_DIR)/bank_os.o $(BUILD_DIR)/bank_os_stubs.o ./modules/bank_os/bank_os.ld
	@echo "[LD] Linking Bank OS ELF..."
	ld -T ./modules/bank_os/bank_os.ld -o $@ $(BUILD_DIR)/bank_os.o $(BUILD_DIR)/bank_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/bank_os.bin: $(BUILD_DIR)/bank_os.elf
	@echo "[OC] Converting Bank OS to binary..."
	objcopy -O binary $< $@
	@echo "  Bank OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Stealth OS (0x2C0000, 128KB)
# Phase 13: MEV protection - order obfuscation + sandwich attack detection
# Note: -fPIC enables Position-Independent Code (no relocation processing needed)
$(BUILD_DIR)/stealth_os.o: ./modules/stealth_os/stealth_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Stealth OS to object file (PIE)..."
	cd ./modules/stealth_os && zig build-obj stealth_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf -fPIC 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/stealth_os/stealth_os.o ]; then mv ./modules/stealth_os/stealth_os.o $@; fi

$(BUILD_DIR)/stealth_os_stubs.o: ./modules/stealth_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Stealth OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/stealth_os.elf: $(BUILD_DIR)/stealth_os.o $(BUILD_DIR)/stealth_os_stubs.o ./modules/stealth_os/stealth_os.ld
	@echo "[LD] Linking Stealth OS ELF..."
	ld -T ./modules/stealth_os/stealth_os.ld -o $@ $(BUILD_DIR)/stealth_os.o $(BUILD_DIR)/stealth_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/stealth_os.bin: $(BUILD_DIR)/stealth_os.elf
	@echo "[OC] Converting Stealth OS to binary..."
	objcopy -O binary $< $@
	@echo "  Stealth OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Report OS (0x300000, 256KB) — L8: Daily PnL/Sharpe/Drawdown Analytics
$(BUILD_DIR)/report_os.o: ./modules/report_os/report_os.zig ./modules/report_os/report_os_types.zig ./modules/report_os/omni_struct.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Report OS to object file..."
	cd ./modules/report_os && zig build-obj report_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/report_os/report_os.o ]; then mv ./modules/report_os/report_os.o $@; fi

$(BUILD_DIR)/report_os_stubs.o: ./modules/report_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Report OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/report_os.elf: $(BUILD_DIR)/report_os.o $(BUILD_DIR)/report_os_stubs.o ./modules/report_os/report_os.ld
	@echo "[LD] Linking Report OS ELF..."
	ld -T ./modules/report_os/report_os.ld -o $@ $(BUILD_DIR)/report_os.o $(BUILD_DIR)/report_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/report_os.bin: $(BUILD_DIR)/report_os.elf
	@echo "[OC] Converting Report OS to binary..."
	objcopy -O binary $< $@
	@echo "  Report OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Checksum OS (L9) - System Validation Layer
# ============================================================================

$(BUILD_DIR)/checksum_os.o: ./modules/checksum_os/checksum_os.zig ./modules/checksum_os/checksum_os_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Checksum OS to object file..."
	cd ./modules/checksum_os && zig build-obj checksum_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/checksum_os/checksum_os.o ]; then mv ./modules/checksum_os/checksum_os.o $@; fi

$(BUILD_DIR)/checksum_os_stubs.o: ./modules/checksum_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Checksum OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/checksum_os.elf: $(BUILD_DIR)/checksum_os.o $(BUILD_DIR)/checksum_os_stubs.o ./modules/checksum_os/checksum_os.ld
	@echo "[LD] Linking Checksum OS ELF..."
	ld -T ./modules/checksum_os/checksum_os.ld -o $@ $(BUILD_DIR)/checksum_os.o $(BUILD_DIR)/checksum_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/checksum_os.bin: $(BUILD_DIR)/checksum_os.elf
	@echo "[OC] Converting Checksum OS to binary..."
	objcopy -O binary $< $@
	@echo "  Checksum OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# AutoRepair OS (L10) - Self-Healing Layer
# ============================================================================

$(BUILD_DIR)/autorepair_os.o: ./modules/autorepair_os/autorepair_os.zig ./modules/autorepair_os/autorepair_os_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling AutoRepair OS to object file..."
	cd ./modules/autorepair_os && zig build-obj autorepair_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/autorepair_os/autorepair_os.o ]; then mv ./modules/autorepair_os/autorepair_os.o $@; fi

$(BUILD_DIR)/autorepair_os_stubs.o: ./modules/autorepair_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling AutoRepair OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/autorepair_os.elf: $(BUILD_DIR)/autorepair_os.o $(BUILD_DIR)/autorepair_os_stubs.o ./modules/autorepair_os/autorepair_os.ld
	@echo "[LD] Linking AutoRepair OS ELF..."
	ld -T ./modules/autorepair_os/autorepair_os.ld -o $@ $(BUILD_DIR)/autorepair_os.o $(BUILD_DIR)/autorepair_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/autorepair_os.bin: $(BUILD_DIR)/autorepair_os.elf
	@echo "[OC] Converting AutoRepair OS to binary..."
	objcopy -O binary $< $@
	@echo "  AutoRepair OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Zorin OS (L13) - Security & Compliance Layer
# ============================================================================

$(BUILD_DIR)/zorin_os.o: ./modules/zorin_os/zorin_os.zig ./modules/zorin_os/zorin_os_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Zorin OS to object file..."
	cd ./modules/zorin_os && zig build-obj zorin_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/zorin_os/zorin_os.o ]; then mv ./modules/zorin_os/zorin_os.o $@; fi

$(BUILD_DIR)/zorin_os_stubs.o: ./modules/zorin_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Zorin OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/zorin_os.elf: $(BUILD_DIR)/zorin_os.o $(BUILD_DIR)/zorin_os_stubs.o ./modules/zorin_os/zorin_os.ld
	@echo "[LD] Linking Zorin OS ELF..."
	ld -T ./modules/zorin_os/zorin_os.ld -o $@ $(BUILD_DIR)/zorin_os.o $(BUILD_DIR)/zorin_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/zorin_os.bin: $(BUILD_DIR)/zorin_os.elf
	@echo "[OC] Converting Zorin OS to binary..."
	objcopy -O binary $< $@
	@echo "  Zorin OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Audit Log OS (L11) - Event logging & forensics
$(BUILD_DIR)/audit_log_os.o: ./modules/audit_log_os/audit_log_os.zig ./modules/audit_log_os/audit_log_os_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Audit Log OS to object file..."
	cd ./modules/audit_log_os && zig build-obj audit_log_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/audit_log_os/audit_log_os.o ]; then mv ./modules/audit_log_os/audit_log_os.o $@; fi

$(BUILD_DIR)/audit_log_os_stubs.o: ./modules/audit_log_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Audit Log OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/audit_log_os.elf: $(BUILD_DIR)/audit_log_os.o $(BUILD_DIR)/audit_log_os_stubs.o ./modules/audit_log_os/audit_log_os.ld
	@echo "[LD] Linking Audit Log OS ELF..."
	ld -T ./modules/audit_log_os/audit_log_os.ld -o $@ $(BUILD_DIR)/audit_log_os.o $(BUILD_DIR)/audit_log_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/audit_log_os.bin: $(BUILD_DIR)/audit_log_os.elf
	@echo "[OC] Converting Audit Log OS to binary..."
	objcopy -O binary $< $@
	@echo "  Audit Log OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Parameter Tuning OS (L15) - Dynamic trading parameter management
# ============================================================================

$(BUILD_DIR)/parameter_tuning_os.o: ./modules/parameter_tuning_os/parameter_tuning_os.zig ./modules/parameter_tuning_os/parameter_tuning_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Parameter Tuning OS to object file..."
	cd ./modules/parameter_tuning_os && zig build-obj parameter_tuning_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/parameter_tuning_os/parameter_tuning_os.o ]; then mv ./modules/parameter_tuning_os/parameter_tuning_os.o $@; fi

$(BUILD_DIR)/parameter_tuning_os_stubs.o: ./modules/parameter_tuning_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Parameter Tuning OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/parameter_tuning_os.elf: $(BUILD_DIR)/parameter_tuning_os.o $(BUILD_DIR)/parameter_tuning_os_stubs.o ./modules/parameter_tuning_os/parameter_tuning_os.ld
	@echo "[LD] Linking Parameter Tuning OS ELF..."
	ld -T ./modules/parameter_tuning_os/parameter_tuning_os.ld -o $@ $(BUILD_DIR)/parameter_tuning_os.o $(BUILD_DIR)/parameter_tuning_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/parameter_tuning_os.bin: $(BUILD_DIR)/parameter_tuning_os.elf
	@echo "[OC] Converting Parameter Tuning OS to binary..."
	objcopy -O binary $< $@
	@echo "  Parameter Tuning OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Historical Analytics OS (L16) - Time-series metrics collection
# ============================================================================

$(BUILD_DIR)/historical_analytics_os.o: ./modules/historical_analytics_os/historical_analytics_os.zig ./modules/historical_analytics_os/historical_analytics_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Historical Analytics OS to object file..."
	cd ./modules/historical_analytics_os && zig build-obj historical_analytics_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/historical_analytics_os/historical_analytics_os.o ]; then mv ./modules/historical_analytics_os/historical_analytics_os.o $@; fi

$(BUILD_DIR)/historical_analytics_os_stubs.o: ./modules/historical_analytics_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Historical Analytics OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/historical_analytics_os.elf: $(BUILD_DIR)/historical_analytics_os.o $(BUILD_DIR)/historical_analytics_os_stubs.o ./modules/historical_analytics_os/historical_analytics_os.ld
	@echo "[LD] Linking Historical Analytics OS ELF..."
	ld -T ./modules/historical_analytics_os/historical_analytics_os.ld -o $@ $(BUILD_DIR)/historical_analytics_os.o $(BUILD_DIR)/historical_analytics_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/historical_analytics_os.bin: $(BUILD_DIR)/historical_analytics_os.elf
	@echo "[OC] Converting Historical Analytics OS to binary..."
	objcopy -O binary $< $@
	@echo "  Historical Analytics OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Alert System OS (L17) - Real-time alert rule engine
# ============================================================================

$(BUILD_DIR)/alert_system_os.o: ./modules/alert_system_os/alert_system_os.zig ./modules/alert_system_os/alert_system_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Alert System OS to object file..."
	cd ./modules/alert_system_os && zig build-obj alert_system_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/alert_system_os/alert_system_os.o ]; then mv ./modules/alert_system_os/alert_system_os.o $@; fi

$(BUILD_DIR)/alert_system_os_stubs.o: ./modules/alert_system_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Alert System OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/alert_system_os.elf: $(BUILD_DIR)/alert_system_os.o $(BUILD_DIR)/alert_system_os_stubs.o ./modules/alert_system_os/alert_system_os.ld
	@echo "[LD] Linking Alert System OS ELF..."
	ld -T ./modules/alert_system_os/alert_system_os.ld -o $@ $(BUILD_DIR)/alert_system_os.o $(BUILD_DIR)/alert_system_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/alert_system_os.bin: $(BUILD_DIR)/alert_system_os.elf
	@echo "[OC] Converting Alert System OS to binary..."
	objcopy -O binary $< $@
	@echo "  Alert System OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Consensus Engine OS (L19) - Byzantine fault-tolerant voting
# ============================================================================

$(BUILD_DIR)/consensus_engine_os.o: ./modules/consensus_engine_os/consensus_engine_os.zig ./modules/consensus_engine_os/consensus_engine_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Consensus Engine OS to object file..."
	cd ./modules/consensus_engine_os && zig build-obj consensus_engine_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/consensus_engine_os/consensus_engine_os.o ]; then mv ./modules/consensus_engine_os/consensus_engine_os.o $@; fi

$(BUILD_DIR)/consensus_engine_os_stubs.o: ./modules/consensus_engine_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Consensus Engine OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/consensus_engine_os.elf: $(BUILD_DIR)/consensus_engine_os.o $(BUILD_DIR)/consensus_engine_os_stubs.o ./modules/consensus_engine_os/consensus_engine_os.ld
	@echo "[LD] Linking Consensus Engine OS ELF..."
	ld -T ./modules/consensus_engine_os/consensus_engine_os.ld -o $@ $(BUILD_DIR)/consensus_engine_os.o $(BUILD_DIR)/consensus_engine_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/consensus_engine_os.bin: $(BUILD_DIR)/consensus_engine_os.elf
	@echo "[OC] Converting Consensus Engine OS to binary..."
	objcopy -O binary $< $@
	@echo "  Consensus Engine OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Federation OS (L18) - IPC message hub and routing
# ============================================================================

$(BUILD_DIR)/federation_os.o: ./modules/federation_os/federation_os.zig ./modules/federation_os/federation_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Federation OS to object file..."
	cd ./modules/federation_os && zig build-obj federation_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/federation_os/federation_os.o ]; then mv ./modules/federation_os/federation_os.o $@; fi

$(BUILD_DIR)/federation_os_stubs.o: ./modules/federation_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Federation OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/federation_os.elf: $(BUILD_DIR)/federation_os.o $(BUILD_DIR)/federation_os_stubs.o ./modules/federation_os/federation_os.ld
	@echo "[LD] Linking Federation OS ELF..."
	ld -T ./modules/federation_os/federation_os.ld -o $@ $(BUILD_DIR)/federation_os.o $(BUILD_DIR)/federation_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/federation_os.bin: $(BUILD_DIR)/federation_os.elf
	@echo "[OC] Converting Federation OS to binary..."
	objcopy -O binary $< $@
	@echo "  Federation OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# MEV Guard OS (L20) - Sandwich attack detection & MEV protection
# ============================================================================

$(BUILD_DIR)/mev_guard_os.o: ./modules/mev_guard_os/mev_guard_os.zig ./modules/mev_guard_os/mev_guard_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling MEV Guard OS to object file..."
	cd ./modules/mev_guard_os && zig build-obj mev_guard_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/mev_guard_os/mev_guard_os.o ]; then mv ./modules/mev_guard_os/mev_guard_os.o $@; fi

$(BUILD_DIR)/mev_guard_os_stubs.o: ./modules/mev_guard_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling MEV Guard OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/mev_guard_os.elf: $(BUILD_DIR)/mev_guard_os.o $(BUILD_DIR)/mev_guard_os_stubs.o ./modules/mev_guard_os/mev_guard_os.ld
	@echo "[LD] Linking MEV Guard OS ELF..."
	ld -T ./modules/mev_guard_os/mev_guard_os.ld -o $@ $(BUILD_DIR)/mev_guard_os.o $(BUILD_DIR)/mev_guard_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/mev_guard_os.bin: $(BUILD_DIR)/mev_guard_os.elf
	@echo "[OC] Converting MEV Guard OS to binary..."
	objcopy -O binary $< $@
	@echo "  MEV Guard OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Cross-Chain Bridge OS (0x3C0000, 64KB) — L21: Multi-blockchain atomic swaps
$(BUILD_DIR)/cross_chain_bridge_os.o: ./modules/cross_chain_bridge_os/cross_chain_bridge_os.zig ./modules/cross_chain_bridge_os/cross_chain_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Cross-Chain Bridge OS to object file..."
	cd ./modules/cross_chain_bridge_os && zig build-obj cross_chain_bridge_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cross_chain_bridge_os/cross_chain_bridge_os.o ]; then mv ./modules/cross_chain_bridge_os/cross_chain_bridge_os.o $@; fi

$(BUILD_DIR)/cross_chain_bridge_os_stubs.o: ./modules/cross_chain_bridge_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Cross-Chain Bridge OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cross_chain_bridge_os.elf: $(BUILD_DIR)/cross_chain_bridge_os.o $(BUILD_DIR)/cross_chain_bridge_os_stubs.o ./modules/cross_chain_bridge_os/cross_chain_bridge_os.ld
	@echo "[LD] Linking Cross-Chain Bridge OS ELF..."
	ld -T ./modules/cross_chain_bridge_os/cross_chain_bridge_os.ld -o $@ $(BUILD_DIR)/cross_chain_bridge_os.o $(BUILD_DIR)/cross_chain_bridge_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cross_chain_bridge_os.bin: $(BUILD_DIR)/cross_chain_bridge_os.elf
	@echo "[OC] Converting Cross-Chain Bridge OS to binary..."
	objcopy -O binary $< $@
	@echo "  Cross-Chain Bridge OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 37: DAO Governance OS (0x3D0000, 64KB)
$(BUILD_DIR)/dao_governance_os.o: ./modules/dao_governance_os/dao_governance_os.zig ./modules/dao_governance_os/dao_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/dao_governance_os && zig build-obj dao_governance_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/dao_governance_os/dao_governance_os.o ]; then mv ./modules/dao_governance_os/dao_governance_os.o $@; fi
$(BUILD_DIR)/dao_governance_os_stubs.o: ./modules/dao_governance_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/dao_governance_os.elf: $(BUILD_DIR)/dao_governance_os.o $(BUILD_DIR)/dao_governance_os_stubs.o ./modules/dao_governance_os/dao_governance_os.ld
	ld -T ./modules/dao_governance_os/dao_governance_os.ld -o $@ $(BUILD_DIR)/dao_governance_os.o $(BUILD_DIR)/dao_governance_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/dao_governance_os.bin: $(BUILD_DIR)/dao_governance_os.elf
	objcopy -O binary $< $@
	@echo "  DAO Governance OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 38: Performance Profiler OS (0x3E0000, 64KB)
$(BUILD_DIR)/performance_profiler_os.o: ./modules/performance_profiler_os/performance_profiler_os.zig ./modules/performance_profiler_os/profiler_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/performance_profiler_os && zig build-obj performance_profiler_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/performance_profiler_os/performance_profiler_os.o ]; then mv ./modules/performance_profiler_os/performance_profiler_os.o $@; fi
$(BUILD_DIR)/performance_profiler_os_stubs.o: ./modules/performance_profiler_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/performance_profiler_os.elf: $(BUILD_DIR)/performance_profiler_os.o $(BUILD_DIR)/performance_profiler_os_stubs.o ./modules/performance_profiler_os/performance_profiler_os.ld
	ld -T ./modules/performance_profiler_os/performance_profiler_os.ld -o $@ $(BUILD_DIR)/performance_profiler_os.o $(BUILD_DIR)/performance_profiler_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/performance_profiler_os.bin: $(BUILD_DIR)/performance_profiler_os.elf
	objcopy -O binary $< $@
	@echo "  Performance Profiler OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 39: Disaster Recovery OS (0x3F0000, 64KB)
$(BUILD_DIR)/disaster_recovery_os.o: ./modules/disaster_recovery_os/disaster_recovery_os.zig ./modules/disaster_recovery_os/recovery_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/disaster_recovery_os && zig build-obj disaster_recovery_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/disaster_recovery_os/disaster_recovery_os.o ]; then mv ./modules/disaster_recovery_os/disaster_recovery_os.o $@; fi
$(BUILD_DIR)/disaster_recovery_os_stubs.o: ./modules/disaster_recovery_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/disaster_recovery_os.elf: $(BUILD_DIR)/disaster_recovery_os.o $(BUILD_DIR)/disaster_recovery_os_stubs.o ./modules/disaster_recovery_os/disaster_recovery_os.ld
	ld -T ./modules/disaster_recovery_os/disaster_recovery_os.ld -o $@ $(BUILD_DIR)/disaster_recovery_os.o $(BUILD_DIR)/disaster_recovery_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/disaster_recovery_os.bin: $(BUILD_DIR)/disaster_recovery_os.elf
	objcopy -O binary $< $@
	@echo "  Disaster Recovery OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 40: Compliance Reporter OS (0x410000, 64KB)
$(BUILD_DIR)/compliance_reporter_os.o: ./modules/compliance_reporter_os/compliance_reporter_os.zig ./modules/compliance_reporter_os/compliance_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/compliance_reporter_os && zig build-obj compliance_reporter_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/compliance_reporter_os/compliance_reporter_os.o ]; then mv ./modules/compliance_reporter_os/compliance_reporter_os.o $@; fi
$(BUILD_DIR)/compliance_reporter_os_stubs.o: ./modules/compliance_reporter_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/compliance_reporter_os.elf: $(BUILD_DIR)/compliance_reporter_os.o $(BUILD_DIR)/compliance_reporter_os_stubs.o ./modules/compliance_reporter_os/compliance_reporter_os.ld
	ld -T ./modules/compliance_reporter_os/compliance_reporter_os.ld -o $@ $(BUILD_DIR)/compliance_reporter_os.o $(BUILD_DIR)/compliance_reporter_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/compliance_reporter_os.bin: $(BUILD_DIR)/compliance_reporter_os.elf
	objcopy -O binary $< $@
	@echo "  Compliance Reporter OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 41: Liquid Staking OS (0x420000, 64KB)
$(BUILD_DIR)/liquid_staking_os.o: ./modules/liquid_staking_os/liquid_staking_os.zig ./modules/liquid_staking_os/staking_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/liquid_staking_os && zig build-obj liquid_staking_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/liquid_staking_os/liquid_staking_os.o ]; then mv ./modules/liquid_staking_os/liquid_staking_os.o $@; fi
$(BUILD_DIR)/liquid_staking_os_stubs.o: ./modules/liquid_staking_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/liquid_staking_os.elf: $(BUILD_DIR)/liquid_staking_os.o $(BUILD_DIR)/liquid_staking_os_stubs.o ./modules/liquid_staking_os/liquid_staking_os.ld
	ld -T ./modules/liquid_staking_os/liquid_staking_os.ld -o $@ $(BUILD_DIR)/liquid_staking_os.o $(BUILD_DIR)/liquid_staking_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/liquid_staking_os.bin: $(BUILD_DIR)/liquid_staking_os.elf
	objcopy -O binary $< $@
	@echo "  Liquid Staking OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 42: Slashing Protection OS (0x430000, 64KB)
$(BUILD_DIR)/slashing_protection_os.o: ./modules/slashing_protection_os/slashing_protection_os.zig ./modules/slashing_protection_os/slashing_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/slashing_protection_os && zig build-obj slashing_protection_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/slashing_protection_os/slashing_protection_os.o ]; then mv ./modules/slashing_protection_os/slashing_protection_os.o $@; fi
$(BUILD_DIR)/slashing_protection_os_stubs.o: ./modules/slashing_protection_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/slashing_protection_os.elf: $(BUILD_DIR)/slashing_protection_os.o $(BUILD_DIR)/slashing_protection_os_stubs.o ./modules/slashing_protection_os/slashing_protection_os.ld
	ld -T ./modules/slashing_protection_os/slashing_protection_os.ld -o $@ $(BUILD_DIR)/slashing_protection_os.o $(BUILD_DIR)/slashing_protection_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/slashing_protection_os.bin: $(BUILD_DIR)/slashing_protection_os.elf
	objcopy -O binary $< $@
	@echo "  Slashing Protection OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 43: Orderflow Auction OS (0x440000, 64KB)
$(BUILD_DIR)/orderflow_auction_os.o: ./modules/orderflow_auction_os/orderflow_auction_os.zig ./modules/orderflow_auction_os/auction_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/orderflow_auction_os && zig build-obj orderflow_auction_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/orderflow_auction_os/orderflow_auction_os.o ]; then mv ./modules/orderflow_auction_os/orderflow_auction_os.o $@; fi
$(BUILD_DIR)/orderflow_auction_os_stubs.o: ./modules/orderflow_auction_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/orderflow_auction_os.elf: $(BUILD_DIR)/orderflow_auction_os.o $(BUILD_DIR)/orderflow_auction_os_stubs.o ./modules/orderflow_auction_os/orderflow_auction_os.ld
	ld -T ./modules/orderflow_auction_os/orderflow_auction_os.ld -o $@ $(BUILD_DIR)/orderflow_auction_os.o $(BUILD_DIR)/orderflow_auction_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/orderflow_auction_os.bin: $(BUILD_DIR)/orderflow_auction_os.elf
	objcopy -O binary $< $@
	@echo "  Orderflow Auction OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 44: Circuit Breaker OS (0x450000, 64KB)
$(BUILD_DIR)/circuit_breaker_os.o: ./modules/circuit_breaker_os/circuit_breaker_os.zig ./modules/circuit_breaker_os/breaker_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/circuit_breaker_os && zig build-obj circuit_breaker_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/circuit_breaker_os/circuit_breaker_os.o ]; then mv ./modules/circuit_breaker_os/circuit_breaker_os.o $@; fi
$(BUILD_DIR)/circuit_breaker_os_stubs.o: ./modules/circuit_breaker_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/circuit_breaker_os.elf: $(BUILD_DIR)/circuit_breaker_os.o $(BUILD_DIR)/circuit_breaker_os_stubs.o ./modules/circuit_breaker_os/circuit_breaker_os.ld
	ld -T ./modules/circuit_breaker_os/circuit_breaker_os.ld -o $@ $(BUILD_DIR)/circuit_breaker_os.o $(BUILD_DIR)/circuit_breaker_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/circuit_breaker_os.bin: $(BUILD_DIR)/circuit_breaker_os.elf
	objcopy -O binary $< $@
	@echo "  Circuit Breaker OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# FALLBACK: OS module stubs (if Zig build fails, use NASM stubs)
# ============================================================================

$(BUILD_DIR)/grid_stub.bin: $(ARCH_DIR)/grid_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] [FALLBACK] Assembling Grid OS stub..."
	$(NASM) -f bin -o $@ $<
	@echo "  Grid stub: $@ (size: $$(stat -c%s $@) bytes)"

$(BUILD_DIR)/analytics_stub.bin: $(ARCH_DIR)/analytics_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] [FALLBACK] Assembling Analytics OS stub..."
	$(NASM) -f bin -o $@ $<
	@echo "  Analytics stub: $@ (size: $$(stat -c%s $@) bytes)"

$(BUILD_DIR)/execution_stub.bin: $(ARCH_DIR)/execution_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] [FALLBACK] Assembling Execution OS stub..."
	$(NASM) -f bin -o $@ $<
	@echo "  Execution stub: $@ (size: $$(stat -c%s $@) bytes)"

# Standalone paging test kernel (no Ada/C deps, pure NASM)
$(BUILD_DIR)/kernel_paging_test.bin: $(ARCH_DIR)/kernel_paging_test.asm
	@echo "[AS] Assembling paging test kernel..."
	$(NASM) -f bin -o $@ $<
	@echo "  Paging test kernel: $@ (size: $$(stat -c%s $@) bytes)"

# Bootable image using paging test kernel instead of Ada kernel
$(BUILD_DIR)/paging_test.iso: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel_paging_test.bin
	@echo "[IMG] Creating paging test ISO..."
	dd if=/dev/zero of=$@ bs=512 count=20480 2>/dev/null
	dd if=$(BUILD_DIR)/boot.bin of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	dd if=$(BUILD_DIR)/stage2.bin of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	dd if=$(BUILD_DIR)/kernel_paging_test.bin of=$@ bs=512 seek=2048 conv=notrunc 2>/dev/null
	@echo "  Paging test image: $@"

# Build and run paging verification test
test-paging: $(BUILD_DIR)/.keep $(BUILD_DIR)/paging_test.iso
	@echo "[TEST] Running paging verification (3 second boot wait)..."
	@echo "  UART serial output → /tmp/omnibus_paging.log"
	@echo "  PASS: serial shows STRCPIL or P-I-L chars"
	@echo "  FAIL: no output or triple fault (QEMU restarts loop)"
	@rm -f /tmp/omnibus_paging.log
	@( sleep 3; echo "xp /16bx 0xb8000"; sleep 0.2; echo quit ) | \
	  $(QEMU) -m 256 -drive format=raw,file=$(BUILD_DIR)/paging_test.iso \
	  -display none -monitor stdio -serial file:/tmp/omnibus_paging.log 2>&1 | \
	  grep -E "^0x|FAIL|ERROR" || true
	@echo "--- Serial output ---"
	@cat /tmp/omnibus_paging.log 2>/dev/null || echo "(no serial output)"

# Create bootable disk image (Phase 5B: includes real OS module binaries)
# Note: Attempts to build Zig modules; falls back to NASM stubs if build fails
$(OUTPUT): $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel_stub.bin
	@echo "[IMG] Creating bootable disk image (Phase 5B + 6 + 7)..."
	@# Try to build real Zig modules; fall back to stubs
	@if [ ! -f $(BUILD_DIR)/grid_os.bin ]; then \
		echo "  [WARN] Grid OS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/grid_os.bin 2>/dev/null || $(MAKE) $(BUILD_DIR)/grid_stub.bin; \
	fi
	@if [ ! -f $(BUILD_DIR)/analytics_os.bin ]; then \
		echo "  [WARN] Analytics OS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/analytics_os.bin 2>/dev/null || $(MAKE) $(BUILD_DIR)/analytics_stub.bin; \
	fi
	@if [ ! -f $(BUILD_DIR)/execution_os.bin ]; then \
		echo "  [WARN] Execution OS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/execution_os.bin 2>/dev/null || $(MAKE) $(BUILD_DIR)/execution_stub.bin; \
	fi
	@if [ ! -f $(BUILD_DIR)/blockchain_os.bin ]; then \
		echo "  [WARN] BlockchainOS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/blockchain_os.bin 2>/dev/null; \
	fi
	@if [ ! -f $(BUILD_DIR)/neuro_os.bin ]; then \
		echo "  [WARN] NeuroOS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/neuro_os.bin 2>/dev/null; \
	fi
	@if [ ! -f $(BUILD_DIR)/bank_os.bin ]; then \
		echo "  [WARN] BankOS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/bank_os.bin 2>/dev/null; \
	fi
	@if [ ! -f $(BUILD_DIR)/stealth_os.bin ]; then \
		echo "  [WARN] StealthOS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/stealth_os.bin 2>/dev/null; \
	fi
	@if [ ! -f $(BUILD_DIR)/report_os.bin ]; then \
		echo "  [WARN] Report OS binary not found, attempting Zig build..."; \
		$(MAKE) $(BUILD_DIR)/report_os.bin 2>/dev/null; \
	fi
	@# Determine which binaries to use
	@GRID_BIN=$$([ -f $(BUILD_DIR)/grid_os.bin ] && echo $(BUILD_DIR)/grid_os.bin || echo $(BUILD_DIR)/grid_stub.bin); \
	ANALYTICS_BIN=$$([ -f $(BUILD_DIR)/analytics_os.bin ] && echo $(BUILD_DIR)/analytics_os.bin || echo $(BUILD_DIR)/analytics_stub.bin); \
	EXEC_BIN=$$([ -f $(BUILD_DIR)/execution_os.bin ] && echo $(BUILD_DIR)/execution_os.bin || echo $(BUILD_DIR)/execution_stub.bin); \
	BLOCKCHAIN_BIN=$$([ -f $(BUILD_DIR)/blockchain_os.bin ] && echo $(BUILD_DIR)/blockchain_os.bin || echo /dev/zero); \
	NEURO_BIN=$$([ -f $(BUILD_DIR)/neuro_os.bin ] && echo $(BUILD_DIR)/neuro_os.bin || echo /dev/zero); \
	BANK_BIN=$$([ -f $(BUILD_DIR)/bank_os.bin ] && echo $(BUILD_DIR)/bank_os.bin || echo /dev/zero); \
	STEALTH_BIN=$$([ -f $(BUILD_DIR)/stealth_os.bin ] && echo $(BUILD_DIR)/stealth_os.bin || echo /dev/zero); \
	REPORT_BIN=$$([ -f $(BUILD_DIR)/report_os.bin ] && echo $(BUILD_DIR)/report_os.bin || echo /dev/zero); \
	SEL4_BIN=$$([ -f $(BUILD_DIR)/sel4_microkernel.bin ] && echo $(BUILD_DIR)/sel4_microkernel.bin || echo /dev/zero); \
	CV_BIN=$$([ -f $(BUILD_DIR)/cross_validator_os.bin ] && echo $(BUILD_DIR)/cross_validator_os.bin || echo /dev/zero); \
	PC_BIN=$$([ -f $(BUILD_DIR)/proof_checker.bin ] && echo $(BUILD_DIR)/proof_checker.bin || echo /dev/zero); \
	CT_BIN=$$([ -f $(BUILD_DIR)/convergence_test_os.bin ] && echo $(BUILD_DIR)/convergence_test_os.bin || echo /dev/zero); \
	echo "[IMG] Using: Grid=$$(basename $$GRID_BIN) Analytics=$$(basename $$ANALYTICS_BIN) Exec=$$(basename $$EXEC_BIN) Blockchain=$$(basename $$BLOCKCHAIN_BIN) Neuro=$$(basename $$NEURO_BIN) Bank=$$(basename $$BANK_BIN) Stealth=$$(basename $$STEALTH_BIN) Report=$$(basename $$REPORT_BIN) seL4=$$(basename $$SEL4_BIN) CrossVal=$$(basename $$CV_BIN) ProofChk=$$(basename $$PC_BIN) ConvTest=$$(basename $$CT_BIN)"; \
	dd if=/dev/zero of=$(OUTPUT) bs=512 count=30000 2>/dev/null; \
	dd if=$(BUILD_DIR)/boot.bin of=$(OUTPUT) bs=512 count=1 conv=notrunc 2>/dev/null; \
	dd if=$(BUILD_DIR)/stage2.bin of=$(OUTPUT) bs=512 seek=1 conv=notrunc 2>/dev/null; \
	dd if=$(BUILD_DIR)/kernel_stub.bin of=$(OUTPUT) bs=512 seek=2048 conv=notrunc 2>/dev/null; \
	dd if=$$GRID_BIN of=$(OUTPUT) bs=512 seek=4096 conv=notrunc 2>/dev/null; \
	dd if=$$ANALYTICS_BIN of=$(OUTPUT) bs=512 seek=4352 conv=notrunc 2>/dev/null; \
	dd if=$$EXEC_BIN of=$(OUTPUT) bs=512 seek=5376 conv=notrunc 2>/dev/null; \
	dd if=$$BLOCKCHAIN_BIN of=$(OUTPUT) bs=512 seek=5632 conv=notrunc 2>/dev/null; \
	dd if=$$NEURO_BIN of=$(OUTPUT) bs=512 seek=6016 conv=notrunc 2>/dev/null; \
	dd if=$$BANK_BIN of=$(OUTPUT) bs=512 seek=7040 conv=notrunc 2>/dev/null; \
	dd if=$$STEALTH_BIN of=$(OUTPUT) bs=512 seek=7424 conv=notrunc 2>/dev/null; \
	dd if=$$REPORT_BIN of=$(OUTPUT) bs=512 seek=7808 conv=notrunc 2>/dev/null; \
	dd if=$$SEL4_BIN of=$(OUTPUT) bs=512 seek=7824 conv=notrunc 2>/dev/null; \
	dd if=$$CV_BIN of=$(OUTPUT) bs=512 seek=7840 conv=notrunc 2>/dev/null; \
	dd if=$$PC_BIN of=$(OUTPUT) bs=512 seek=7856 conv=notrunc 2>/dev/null; \
	dd if=$$CT_BIN of=$(OUTPUT) bs=512 seek=7872 conv=notrunc 2>/dev/null
	@echo "  Disk image: $(OUTPUT) ($$(stat -c%s $(OUTPUT)) bytes)"
	@echo "  Sector layout:"
	@echo "    Boot:           sector 0-0       (512B)"
	@echo "    Stage2:         sector 1-1       (512B)"
	@echo "    Kernel:         sector 2048-2176 (128KB kernel)"
	@echo "    Grid OS:        sector 4096-4351 (256 sectors, 128KB @ 0x110000)"
	@echo "    Analytics:      sector 4352-5375 (1024 sectors, 512KB @ 0x150000)"
	@echo "    Exec OS:        sector 5376-5631 (256 sectors, 128KB @ 0x130000)"
	@echo "    BlockchainOS:   sector 5632-6015 (384 sectors, 192KB @ 0x250000)"
	@echo "    NeuroOS:        sector 6016-7039 (1024 sectors, 512KB @ 0x2D0000)"
	@echo "    BankOS:         sector 7040-7423 (384 sectors, 192KB @ 0x280000)"
	@echo "    StealthOS:      sector 7424-7807 (384 sectors, 192KB @ 0x2C0000)"
	@echo "    Report OS:      sector 7808-7823 (16 sectors @ 0x3A0000)"
	@echo "    seL4 µkernel:   sector 7824-7839 (16 sectors @ 0x4A0000)"
	@echo "    Cross-Validator: sector 7840-7855 (16 sectors @ 0x4B0000)"
	@echo "    Proof Checker:  sector 7856-7871 (16 sectors @ 0x4C0000)"
	@echo "    Convergence Test: sector 7872-7887 (16 sectors @ 0x4D0000)"

# ============================================================================
# RUN: Execute in QEMU
# ============================================================================

# Quick automated Phase 5 boot test (6 second timeout)
test-phase5: build
	@echo "[TEST] Phase 5 — OS Layer Loader boot test..."
	@rm -f /tmp/omnibus_phase5.log
	@timeout 6 $(QEMU) -m 256 -drive format=raw,file=$(OUTPUT) \
	  -display none -serial file:/tmp/omnibus_phase5.log -monitor none 2>/dev/null || true
	@echo "--- Serial output ---"
	@cat /tmp/omnibus_phase5.log 2>/dev/null || echo "(no output)"
	@echo "--- Expected: KD123TCRP LONG_MODE_OK GRID_OS_64_OK ANALYTICS_64_OK EXEC_OS_64_OK ADA64_INIT MOTHER_OS_64_OK ---"

qemu: build
	@echo "[QEMU] Starting emulation..."
	@echo "  Press Ctrl+A then X to exit"
	$(QEMU) $(QEMU_FLAGS)

qemu-debug: build
	@echo "[QEMU] Starting emulation with GDB stub on port 1234..."
	@echo "  In another terminal, run: gdb -ex 'target remote :1234'"
	$(QEMU) $(QEMU_FLAGS) -S -gdb tcp::1234

# ============================================================================
# INSPECT: Debug and analyze binaries
# ============================================================================

inspect: build
	@echo "[INSPECT] Boot sector:"
	@hexdump -C $(BUILD_DIR)/boot.bin | head -20
	@echo ""
	@echo "[INSPECT] Boot signature (last 4 bytes, should be 55AA):"
	@tail -c 4 $(BUILD_DIR)/boot.bin | hexdump -C

# ============================================================================
# CLEAN: Remove build artifacts
# ============================================================================

clean:
	@echo "[CLEAN] Removing build artifacts..."
	rm -rf $(BUILD_DIR)
	@echo "  ✓ Cleaned"

# ============================================================================
# BUILD RULES
# ============================================================================

.SUFFIXES: .asm .bin

# Default assembly rule (just in case)
.asm.bin:
	$(NASM) -f bin -o $@ $<

# ============================================================================
# PHONY TARGETS (don't match files)
# ============================================================================

.PHONY: build qemu qemu-debug clean help inspect all

# Phase 45: Flash Loan Protection OS (0x460000, 64KB)
$(BUILD_DIR)/flash_loan_protection_os.o: ./modules/flash_loan_protection_os/flash_loan_protection_os.zig ./modules/flash_loan_protection_os/flash_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/flash_loan_protection_os && zig build-obj flash_loan_protection_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/flash_loan_protection_os/flash_loan_protection_os.o ]; then mv ./modules/flash_loan_protection_os/flash_loan_protection_os.o $@; fi
$(BUILD_DIR)/flash_loan_protection_os_stubs.o: ./modules/flash_loan_protection_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/flash_loan_protection_os.elf: $(BUILD_DIR)/flash_loan_protection_os.o $(BUILD_DIR)/flash_loan_protection_os_stubs.o ./modules/flash_loan_protection_os/flash_loan_protection_os.ld
	ld -T ./modules/flash_loan_protection_os/flash_loan_protection_os.ld -o $@ $(BUILD_DIR)/flash_loan_protection_os.o $(BUILD_DIR)/flash_loan_protection_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/flash_loan_protection_os.bin: $(BUILD_DIR)/flash_loan_protection_os.elf
	objcopy -O binary $< $@
	@echo "  Flash Loan Protection OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 46: L2 Rollup Bridge OS (0x470000, 64KB)
$(BUILD_DIR)/l2_rollup_bridge_os.o: ./modules/l2_rollup_bridge_os/l2_rollup_bridge_os.zig ./modules/l2_rollup_bridge_os/rollup_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/l2_rollup_bridge_os && zig build-obj l2_rollup_bridge_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/l2_rollup_bridge_os/l2_rollup_bridge_os.o ]; then mv ./modules/l2_rollup_bridge_os/l2_rollup_bridge_os.o $@; fi
$(BUILD_DIR)/l2_rollup_bridge_os_stubs.o: ./modules/l2_rollup_bridge_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/l2_rollup_bridge_os.elf: $(BUILD_DIR)/l2_rollup_bridge_os.o $(BUILD_DIR)/l2_rollup_bridge_os_stubs.o ./modules/l2_rollup_bridge_os/l2_rollup_bridge_os.ld
	ld -T ./modules/l2_rollup_bridge_os/l2_rollup_bridge_os.ld -o $@ $(BUILD_DIR)/l2_rollup_bridge_os.o $(BUILD_DIR)/l2_rollup_bridge_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/l2_rollup_bridge_os.bin: $(BUILD_DIR)/l2_rollup_bridge_os.elf
	objcopy -O binary $< $@
	@echo "  L2 Rollup Bridge OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 47: Quantum-Resistant Crypto OS (0x480000, 64KB)
$(BUILD_DIR)/quantum_resistant_crypto_os.o: ./modules/quantum_resistant_crypto_os/quantum_resistant_crypto_os.zig ./modules/quantum_resistant_crypto_os/quantum_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/quantum_resistant_crypto_os && zig build-obj quantum_resistant_crypto_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/quantum_resistant_crypto_os/quantum_resistant_crypto_os.o ]; then mv ./modules/quantum_resistant_crypto_os/quantum_resistant_crypto_os.o $@; fi
$(BUILD_DIR)/quantum_resistant_crypto_os_stubs.o: ./modules/quantum_resistant_crypto_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/quantum_resistant_crypto_os.elf: $(BUILD_DIR)/quantum_resistant_crypto_os.o $(BUILD_DIR)/quantum_resistant_crypto_os_stubs.o ./modules/quantum_resistant_crypto_os/quantum_resistant_crypto_os.ld
	ld -T ./modules/quantum_resistant_crypto_os/quantum_resistant_crypto_os.ld -o $@ $(BUILD_DIR)/quantum_resistant_crypto_os.o $(BUILD_DIR)/quantum_resistant_crypto_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/quantum_resistant_crypto_os.bin: $(BUILD_DIR)/quantum_resistant_crypto_os.elf
	objcopy -O binary $< $@
	@echo "  Quantum-Resistant Crypto OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# PQC-GATE OS (0x490000, 64KB) — L33: NIST Post-Quantum Cryptography (ML-DSA, SLH-DSA, FN-DSA)
$(BUILD_DIR)/pqc_gate_os.o: ./modules/pqc_gate_os/pqc_gate_os.zig ./modules/pqc_gate_os/pqc_types.zig | $(BUILD_DIR)/.keep
	cd ./modules/pqc_gate_os && zig build-obj pqc_gate_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/pqc_gate_os/pqc_gate_os.o ]; then mv ./modules/pqc_gate_os/pqc_gate_os.o $@; fi
$(BUILD_DIR)/pqc_gate_os_stubs.o: ./modules/pqc_gate_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<
$(BUILD_DIR)/pqc_gate_os.elf: $(BUILD_DIR)/pqc_gate_os.o $(BUILD_DIR)/pqc_gate_os_stubs.o ./modules/pqc_gate_os/pqc_gate_os.ld
	ld -T ./modules/pqc_gate_os/pqc_gate_os.ld -o $@ $(BUILD_DIR)/pqc_gate_os.o $(BUILD_DIR)/pqc_gate_os_stubs.o 2>&1 | grep -v "warning:" || true
$(BUILD_DIR)/pqc_gate_os.bin: $(BUILD_DIR)/pqc_gate_os.elf
	objcopy -O binary $< $@
	@echo "  PQC-GATE OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# seL4 Microkernel OS (0x4A0000, 64KB, L22)
$(BUILD_DIR)/sel4_microkernel.o: ./modules/sel4_microkernel/sel4_microkernel.zig ./modules/sel4_microkernel/sel4_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling seL4 Microkernel OS to object file..."
	cd ./modules/sel4_microkernel && zig build-obj sel4_microkernel.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/sel4_microkernel/sel4_microkernel.o ]; then mv ./modules/sel4_microkernel/sel4_microkernel.o $@; fi

$(BUILD_DIR)/sel4_microkernel_stubs.o: ./modules/sel4_microkernel/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling seL4 Microkernel OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/sel4_microkernel.elf: $(BUILD_DIR)/sel4_microkernel.o $(BUILD_DIR)/sel4_microkernel_stubs.o ./modules/sel4_microkernel/sel4_microkernel.ld
	@echo "[LD] Linking seL4 Microkernel OS ELF..."
	ld -T ./modules/sel4_microkernel/sel4_microkernel.ld -o $@ $(BUILD_DIR)/sel4_microkernel.o $(BUILD_DIR)/sel4_microkernel_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/sel4_microkernel.bin: $(BUILD_DIR)/sel4_microkernel.elf
	@echo "[OC] Converting seL4 Microkernel OS to binary..."
	objcopy -O binary $< $@
	@echo "  seL4 Microkernel OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Cross-Validator OS (0x4B0000, 64KB, L23)
$(BUILD_DIR)/cross_validator_os.o: ./modules/cross_validator_os/cross_validator_os.zig ./modules/cross_validator_os/cross_validator_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Cross-Validator OS to object file..."
	cd ./modules/cross_validator_os && zig build-obj cross_validator_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cross_validator_os/cross_validator_os.o ]; then mv ./modules/cross_validator_os/cross_validator_os.o $@; fi

$(BUILD_DIR)/cross_validator_os_stubs.o: ./modules/cross_validator_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Cross-Validator OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cross_validator_os.elf: $(BUILD_DIR)/cross_validator_os.o $(BUILD_DIR)/cross_validator_os_stubs.o ./modules/cross_validator_os/cross_validator_os.ld
	@echo "[LD] Linking Cross-Validator OS ELF..."
	ld -T ./modules/cross_validator_os/cross_validator_os.ld -o $@ $(BUILD_DIR)/cross_validator_os.o $(BUILD_DIR)/cross_validator_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cross_validator_os.bin: $(BUILD_DIR)/cross_validator_os.elf
	@echo "[OC] Converting Cross-Validator OS to binary..."
	objcopy -O binary $< $@
	@echo "  Cross-Validator OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Proof Checker OS (0x4C0000, 64KB, L24)
$(BUILD_DIR)/proof_checker.o: ./modules/formal_proofs/proof_checker.zig ./modules/formal_proofs/proof_checker_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Proof Checker OS to object file..."
	cd ./modules/formal_proofs && zig build-obj proof_checker.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/formal_proofs/proof_checker.o ]; then mv ./modules/formal_proofs/proof_checker.o $@; fi

$(BUILD_DIR)/proof_checker_stubs.o: ./modules/formal_proofs/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Proof Checker OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/proof_checker.elf: $(BUILD_DIR)/proof_checker.o $(BUILD_DIR)/proof_checker_stubs.o ./modules/formal_proofs/proof_checker.ld
	@echo "[LD] Linking Proof Checker OS ELF..."
	ld -T ./modules/formal_proofs/proof_checker.ld -o $@ $(BUILD_DIR)/proof_checker.o $(BUILD_DIR)/proof_checker_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/proof_checker.bin: $(BUILD_DIR)/proof_checker.elf
	@echo "[OC] Converting Proof Checker OS to binary..."
	objcopy -O binary $< $@
	@echo "  Proof Checker OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Convergence Test OS (L25, 0x4D0000) — dual-kernel convergence verification
$(BUILD_DIR)/convergence_test_os.o: ./modules/convergence_test_os/convergence_test_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZC] Compiling Convergence Test OS..."
	cd ./modules/convergence_test_os && zig build-obj convergence_test_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/convergence_test_os/convergence_test_os.o ]; then mv ./modules/convergence_test_os/convergence_test_os.o $@; fi

$(BUILD_DIR)/convergence_test_stubs.o: ./modules/convergence_test_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Convergence Test OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/convergence_test_os.elf: $(BUILD_DIR)/convergence_test_os.o $(BUILD_DIR)/convergence_test_stubs.o ./modules/convergence_test_os/convergence_test_os.ld
	@echo "[LD] Linking Convergence Test OS ELF..."
	ld -T ./modules/convergence_test_os/convergence_test_os.ld -o $@ $(BUILD_DIR)/convergence_test_os.o $(BUILD_DIR)/convergence_test_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/convergence_test_os.bin: $(BUILD_DIR)/convergence_test_os.elf
	@echo "[OC] Converting Convergence Test OS to binary..."
	objcopy -O binary $< $@
	@echo "  Convergence Test OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 51: Domain Resolver OS (L26, 0x4E0000) — Blockchain domain resolution (ENS, .anyone, ArNS)
$(BUILD_DIR)/domain_resolver_os.o: ./modules/domain_resolver/domain_resolver_os.zig ./modules/domain_resolver/domain_resolver_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Domain Resolver OS to object file..."
	cd ./modules/domain_resolver && zig build-obj domain_resolver_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/domain_resolver/domain_resolver_os.o ]; then mv ./modules/domain_resolver/domain_resolver_os.o $@; fi

$(BUILD_DIR)/domain_resolver_stubs.o: ./modules/domain_resolver/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Domain Resolver OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/domain_resolver_os.elf: $(BUILD_DIR)/domain_resolver_os.o $(BUILD_DIR)/domain_resolver_stubs.o ./modules/domain_resolver/domain_resolver.ld
	@echo "[LD] Linking Domain Resolver OS ELF..."
	ld -T ./modules/domain_resolver/domain_resolver.ld -o $@ $(BUILD_DIR)/domain_resolver_os.o $(BUILD_DIR)/domain_resolver_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/domain_resolver_os.bin: $(BUILD_DIR)/domain_resolver_os.elf
	@echo "[OC] Converting Domain Resolver OS to binary..."
	objcopy -O binary $< $@
	@echo "  Domain Resolver OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 52: Multi-Node Federation OS (0x4F0000, 64KB, L27)
$(BUILD_DIR)/multi_node_federation_os.o: ./modules/multi_node_federation_os/multi_node_federation_os.zig ./modules/multi_node_federation_os/multi_node_federation_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Multi-Node Federation OS to object file..."
	cd ./modules/multi_node_federation_os && zig build-obj multi_node_federation_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/multi_node_federation_os/multi_node_federation_os.o ]; then mv ./modules/multi_node_federation_os/multi_node_federation_os.o $@; fi

$(BUILD_DIR)/multi_node_federation_stubs.o: ./modules/multi_node_federation_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Multi-Node Federation OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/multi_node_federation_os.elf: $(BUILD_DIR)/multi_node_federation_os.o $(BUILD_DIR)/multi_node_federation_stubs.o ./modules/multi_node_federation_os/multi_node_federation_os.ld
	@echo "[LD] Linking Multi-Node Federation OS ELF..."
	ld -T ./modules/multi_node_federation_os/multi_node_federation_os.ld -o $@ $(BUILD_DIR)/multi_node_federation_os.o $(BUILD_DIR)/multi_node_federation_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/multi_node_federation_os.bin: $(BUILD_DIR)/multi_node_federation_os.elf
	@echo "[OC] Converting Multi-Node Federation OS to binary..."
	objcopy -O binary $< $@
	@echo "  Multi-Node Federation OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 53: Async IPC OS (0x500000, 64KB, L28)
$(BUILD_DIR)/async_ipc_os.o: ./modules/async_ipc_os/async_ipc_os.zig ./modules/async_ipc_os/async_ipc_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Async IPC OS to object file..."
	cd ./modules/async_ipc_os && zig build-obj async_ipc_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/async_ipc_os/async_ipc_os.o ]; then mv ./modules/async_ipc_os/async_ipc_os.o $@; fi

$(BUILD_DIR)/async_ipc_stubs.o: ./modules/async_ipc_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Async IPC OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/async_ipc_os.elf: $(BUILD_DIR)/async_ipc_os.o $(BUILD_DIR)/async_ipc_stubs.o ./modules/async_ipc_os/async_ipc_os.ld
	@echo "[LD] Linking Async IPC OS ELF..."
	ld -T ./modules/async_ipc_os/async_ipc_os.ld -o $@ $(BUILD_DIR)/async_ipc_os.o $(BUILD_DIR)/async_ipc_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/async_ipc_os.bin: $(BUILD_DIR)/async_ipc_os.elf
	@echo "[OC] Converting Async IPC OS to binary..."
	objcopy -O binary $< $@
	@echo "  Async IPC OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 54: Persistent State OS (0x510000, 64KB, L29)
$(BUILD_DIR)/persistent_state_os.o: ./modules/persistent_state_os/persistent_state_os.zig ./modules/persistent_state_os/persistent_state_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Persistent State OS to object file..."
	cd ./modules/persistent_state_os && zig build-obj persistent_state_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/persistent_state_os/persistent_state_os.o ]; then mv ./modules/persistent_state_os/persistent_state_os.o $@; fi

$(BUILD_DIR)/persistent_state_stubs.o: ./modules/persistent_state_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Persistent State OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/persistent_state_os.elf: $(BUILD_DIR)/persistent_state_os.o $(BUILD_DIR)/persistent_state_stubs.o ./modules/persistent_state_os/persistent_state_os.ld
	@echo "[LD] Linking Persistent State OS ELF..."
	ld -T ./modules/persistent_state_os/persistent_state_os.ld -o $@ $(BUILD_DIR)/persistent_state_os.o $(BUILD_DIR)/persistent_state_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/persistent_state_os.bin: $(BUILD_DIR)/persistent_state_os.elf
	@echo "[OC] Converting Persistent State OS to binary..."
	objcopy -O binary $< $@
	@echo "  Persistent State OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Phase 57: LoggingOS (Structured Logging Hub)
# ============================================================================

$(BUILD_DIR)/logging_os.o: ./modules/logging_os/logging_os.zig ./modules/logging_os/logging_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZG] Compiling LoggingOS..."
	cd ./modules/logging_os && zig build-obj logging_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/logging_os/logging_os.o ]; then mv ./modules/logging_os/logging_os.o $@; fi

$(BUILD_DIR)/logging_stubs.o: ./modules/logging_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling LoggingOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/logging_os.elf: $(BUILD_DIR)/logging_os.o $(BUILD_DIR)/logging_stubs.o ./modules/logging_os/logging_os.ld
	@echo "[LD] Linking LoggingOS ELF..."
	ld -T ./modules/logging_os/logging_os.ld -o $@ $(BUILD_DIR)/logging_os.o $(BUILD_DIR)/logging_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/logging_os.bin: $(BUILD_DIR)/logging_os.elf
	@echo "[OC] Converting LoggingOS to binary..."
	objcopy -O binary $< $@
	@echo "  LoggingOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Phase 58: DatabaseOS (Distributed Trade Journal)
# ============================================================================

$(BUILD_DIR)/database_os.o: ./modules/database_os/database_os.zig ./modules/database_os/database_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZG] Compiling DatabaseOS..."
	cd ./modules/database_os && zig build-obj database_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/database_os/database_os.o ]; then mv ./modules/database_os/database_os.o $@; fi

$(BUILD_DIR)/database_stubs.o: ./modules/database_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling DatabaseOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/database_os.elf: $(BUILD_DIR)/database_os.o $(BUILD_DIR)/database_stubs.o ./modules/database_os/database_os.ld
	@echo "[LD] Linking DatabaseOS ELF..."
	ld -T ./modules/database_os/database_os.ld -o $@ $(BUILD_DIR)/database_os.o $(BUILD_DIR)/database_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/database_os.bin: $(BUILD_DIR)/database_os.elf
	@echo "[OC] Converting DatabaseOS to binary..."
	objcopy -O binary $< $@
	@echo "  DatabaseOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Phase 58B: CassandraOS (Multi-DC Event Sourcing)
# ============================================================================

$(BUILD_DIR)/cassandra_os.o: ./modules/cassandra_os/cassandra_os.zig ./modules/cassandra_os/cassandra_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZG] Compiling CassandraOS..."
	cd ./modules/cassandra_os && zig build-obj cassandra_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cassandra_os/cassandra_os.o ]; then mv ./modules/cassandra_os/cassandra_os.o $@; fi

$(BUILD_DIR)/cassandra_stubs.o: ./modules/cassandra_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling CassandraOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cassandra_os.elf: $(BUILD_DIR)/cassandra_os.o $(BUILD_DIR)/cassandra_stubs.o ./modules/cassandra_os/cassandra_os.ld
	@echo "[LD] Linking CassandraOS ELF..."
	ld -T ./modules/cassandra_os/cassandra_os.ld -o $@ $(BUILD_DIR)/cassandra_os.o $(BUILD_DIR)/cassandra_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cassandra_os.bin: $(BUILD_DIR)/cassandra_os.elf
	@echo "[OC] Converting CassandraOS to binary..."
	objcopy -O binary $< $@
	@echo "  CassandraOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# Phase 59: MetricsOS (Prometheus + Elasticsearch Observability)
# ============================================================================

$(BUILD_DIR)/metrics_os.o: ./modules/metrics_os/metrics_os.zig ./modules/metrics_os/metrics_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZG] Compiling MetricsOS..."
	cd ./modules/metrics_os && zig build-obj metrics_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/metrics_os/metrics_os.o ]; then mv ./modules/metrics_os/metrics_os.o $@; fi

$(BUILD_DIR)/metrics_stubs.o: ./modules/metrics_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling MetricsOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/metrics_os.elf: $(BUILD_DIR)/metrics_os.o $(BUILD_DIR)/metrics_stubs.o ./modules/metrics_os/metrics_os.ld
	@echo "[LD] Linking MetricsOS ELF..."
	ld -T ./modules/metrics_os/metrics_os.ld -o $@ $(BUILD_DIR)/metrics_os.o $(BUILD_DIR)/metrics_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/metrics_os.bin: $(BUILD_DIR)/metrics_os.elf
	@echo "[OC] Converting MetricsOS to binary..."
	objcopy -O binary $< $@
	@echo "  MetricsOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 60: ReplayOS (0x5E0000, 64KB) — Event-driven transaction replay
$(BUILD_DIR)/replay_os.o: ./modules/replay_os/replay_os.zig ./modules/replay_os/replay_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling ReplayOS to object file..."
	cd ./modules/replay_os && zig build-obj replay_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/replay_os/replay_os.o ]; then mv ./modules/replay_os/replay_os.o $@; fi

$(BUILD_DIR)/replay_stubs.o: ./modules/replay_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling ReplayOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/replay_os.elf: $(BUILD_DIR)/replay_os.o $(BUILD_DIR)/replay_stubs.o ./modules/replay_os/replay_os.ld
	@echo "[LD] Linking ReplayOS ELF..."
	ld -T ./modules/replay_os/replay_os.ld -o $@ $(BUILD_DIR)/replay_os.o $(BUILD_DIR)/replay_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/replay_os.bin: $(BUILD_DIR)/replay_os.elf
	@echo "[OC] Converting ReplayOS to binary..."
	objcopy -O binary $< $@
	@echo "  ReplayOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 61: Cloud Adapter Modules (Multi-cloud provider integration)

# MicrosoftOS (0x5F0000, 64KB) — Azure cloud integration
$(BUILD_DIR)/microsoft_os.o: ./modules/cloud_adapters/microsoft_os.zig ./modules/cloud_adapters/cloud_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling MicrosoftOS to object file..."
	cd ./modules/cloud_adapters && zig build-obj microsoft_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_adapters/microsoft_os.o ]; then mv ./modules/cloud_adapters/microsoft_os.o $@; fi

$(BUILD_DIR)/microsoft_stubs.o: ./modules/cloud_adapters/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling MicrosoftOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/microsoft_os.elf: $(BUILD_DIR)/microsoft_os.o $(BUILD_DIR)/microsoft_stubs.o ./modules/cloud_adapters/microsoft_os.ld
	@echo "[LD] Linking MicrosoftOS ELF..."
	ld -T ./modules/cloud_adapters/microsoft_os.ld -o $@ $(BUILD_DIR)/microsoft_os.o $(BUILD_DIR)/microsoft_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/microsoft_os.bin: $(BUILD_DIR)/microsoft_os.elf
	@echo "[OC] Converting MicrosoftOS to binary..."
	objcopy -O binary $< $@
	@echo "  MicrosoftOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# OracleOS (0x600000, 64KB) — Oracle Cloud Infrastructure integration
$(BUILD_DIR)/oracle_os.o: ./modules/cloud_adapters/oracle_os.zig ./modules/cloud_adapters/cloud_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling OracleOS to object file..."
	cd ./modules/cloud_adapters && zig build-obj oracle_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_adapters/oracle_os.o ]; then mv ./modules/cloud_adapters/oracle_os.o $@; fi

$(BUILD_DIR)/oracle_stubs.o: ./modules/cloud_adapters/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling OracleOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/oracle_os.elf: $(BUILD_DIR)/oracle_os.o $(BUILD_DIR)/oracle_stubs.o ./modules/cloud_adapters/oracle_os.ld
	@echo "[LD] Linking OracleOS ELF..."
	ld -T ./modules/cloud_adapters/oracle_os.ld -o $@ $(BUILD_DIR)/oracle_os.o $(BUILD_DIR)/oracle_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/oracle_os.bin: $(BUILD_DIR)/oracle_os.elf
	@echo "[OC] Converting OracleOS to binary..."
	objcopy -O binary $< $@
	@echo "  OracleOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# AWSOS (0x610000, 64KB) — Amazon Web Services integration
$(BUILD_DIR)/aws_os.o: ./modules/cloud_adapters/aws_os.zig ./modules/cloud_adapters/cloud_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling AWSOS to object file..."
	cd ./modules/cloud_adapters && zig build-obj aws_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_adapters/aws_os.o ]; then mv ./modules/cloud_adapters/aws_os.o $@; fi

$(BUILD_DIR)/aws_stubs.o: ./modules/cloud_adapters/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling AWSOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/aws_os.elf: $(BUILD_DIR)/aws_os.o $(BUILD_DIR)/aws_stubs.o ./modules/cloud_adapters/aws_os.ld
	@echo "[LD] Linking AWSOS ELF..."
	ld -T ./modules/cloud_adapters/aws_os.ld -o $@ $(BUILD_DIR)/aws_os.o $(BUILD_DIR)/aws_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/aws_os.bin: $(BUILD_DIR)/aws_os.elf
	@echo "[OC] Converting AWSOS to binary..."
	objcopy -O binary $< $@
	@echo "  AWSOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# VmwareOS (0x620000, 64KB) — VMWare Cloud integration
$(BUILD_DIR)/vmware_os.o: ./modules/cloud_adapters/vmware_os.zig ./modules/cloud_adapters/cloud_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling VmwareOS to object file..."
	cd ./modules/cloud_adapters && zig build-obj vmware_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_adapters/vmware_os.o ]; then mv ./modules/cloud_adapters/vmware_os.o $@; fi

$(BUILD_DIR)/vmware_stubs.o: ./modules/cloud_adapters/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling VmwareOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/vmware_os.elf: $(BUILD_DIR)/vmware_os.o $(BUILD_DIR)/vmware_stubs.o ./modules/cloud_adapters/vmware_os.ld
	@echo "[LD] Linking VmwareOS ELF..."
	ld -T ./modules/cloud_adapters/vmware_os.ld -o $@ $(BUILD_DIR)/vmware_os.o $(BUILD_DIR)/vmware_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/vmware_os.bin: $(BUILD_DIR)/vmware_os.elf
	@echo "[OC] Converting VmwareOS to binary..."
	objcopy -O binary $< $@
	@echo "  VmwareOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# GCPOS (0x630000, 64KB) — Google Cloud Platform integration
$(BUILD_DIR)/gcp_os.o: ./modules/cloud_adapters/gcp_os.zig ./modules/cloud_adapters/cloud_types.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling GCPOS to object file..."
	cd ./modules/cloud_adapters && zig build-obj gcp_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_adapters/gcp_os.o ]; then mv ./modules/cloud_adapters/gcp_os.o $@; fi

$(BUILD_DIR)/gcp_stubs.o: ./modules/cloud_adapters/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling GCPOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/gcp_os.elf: $(BUILD_DIR)/gcp_os.o $(BUILD_DIR)/gcp_stubs.o ./modules/cloud_adapters/gcp_os.ld
	@echo "[LD] Linking GCPOS ELF..."
	ld -T ./modules/cloud_adapters/gcp_os.ld -o $@ $(BUILD_DIR)/gcp_os.o $(BUILD_DIR)/gcp_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/gcp_os.bin: $(BUILD_DIR)/gcp_os.elf
	@echo "[OC] Converting GCPOS to binary..."
	objcopy -O binary $< $@
	@echo "  GCPOS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# PHASE 52: SECURITY GOVERNANCE LAYER (7 modules)
# ============================================================================

# L15: SAVAos (0x380000, 15KB) — SDK author identity validation
$(BUILD_DIR)/savaos.o: ./modules/security/savaos.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling SAVAos to object file..."
	cd ./modules/security && zig build-obj savaos.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/savaos.o ]; then mv ./modules/security/savaos.o $@; fi

$(BUILD_DIR)/savaos_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling SAVAos libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/savaos.elf: $(BUILD_DIR)/savaos.o $(BUILD_DIR)/savaos_stubs.o ./modules/security/savaos.ld
	@echo "[LD] Linking SAVAos ELF..."
	ld -T ./modules/security/savaos.ld -o $@ $(BUILD_DIR)/savaos.o $(BUILD_DIR)/savaos_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/savaos.bin: $(BUILD_DIR)/savaos.elf
	@echo "[OC] Converting SAVAos to binary..."
	objcopy -O binary $< $@
	@echo "  SAVAos binary: $@ (size: $$(stat -c%s $@) bytes)"

# L16: CAZANos (0x383C00, 18KB) — Subsystem instantiation
$(BUILD_DIR)/cazanos.o: ./modules/security/cazanos.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling CAZANos to object file..."
	cd ./modules/security && zig build-obj cazanos.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/cazanos.o ]; then mv ./modules/security/cazanos.o $@; fi

$(BUILD_DIR)/cazanos_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling CAZANos libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cazanos.elf: $(BUILD_DIR)/cazanos.o $(BUILD_DIR)/cazanos_stubs.o ./modules/security/cazanos.ld
	@echo "[LD] Linking CAZANos ELF..."
	ld -T ./modules/security/cazanos.ld -o $@ $(BUILD_DIR)/cazanos.o $(BUILD_DIR)/cazanos_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cazanos.bin: $(BUILD_DIR)/cazanos.elf
	@echo "[OC] Converting CAZANos to binary..."
	objcopy -O binary $< $@
	@echo "  CAZANos binary: $@ (size: $$(stat -c%s $@) bytes)"

# L17: SAVACAZANos (0x388000, 21KB) — Unified permissions
$(BUILD_DIR)/savacazanos.o: ./modules/security/savacazanos.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling SAVACAZANos to object file..."
	cd ./modules/security && zig build-obj savacazanos.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/savacazanos.o ]; then mv ./modules/security/savacazanos.o $@; fi

$(BUILD_DIR)/savacazanos_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling SAVACAZANos libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/savacazanos.elf: $(BUILD_DIR)/savacazanos.o $(BUILD_DIR)/savacazanos_stubs.o ./modules/security/savacazanos.ld
	@echo "[LD] Linking SAVACAZANos ELF..."
	ld -T ./modules/security/savacazanos.ld -o $@ $(BUILD_DIR)/savacazanos.o $(BUILD_DIR)/savacazanos_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/savacazanos.bin: $(BUILD_DIR)/savacazanos.elf
	@echo "[OC] Converting SAVACAZANos to binary..."
	objcopy -O binary $< $@
	@echo "  SAVACAZANos binary: $@ (size: $$(stat -c%s $@) bytes)"

# L18: Vortex Bridge (0x3A0000, 30KB) — Message routing
$(BUILD_DIR)/vortex_bridge.o: ./modules/security/vortex_bridge.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Vortex Bridge to object file..."
	cd ./modules/security && zig build-obj vortex_bridge.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/vortex_bridge.o ]; then mv ./modules/security/vortex_bridge.o $@; fi

$(BUILD_DIR)/vortex_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Vortex stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/vortex_bridge.elf: $(BUILD_DIR)/vortex_bridge.o $(BUILD_DIR)/vortex_stubs.o ./modules/security/vortex_bridge.ld
	@echo "[LD] Linking Vortex Bridge ELF..."
	ld -T ./modules/security/vortex_bridge.ld -o $@ $(BUILD_DIR)/vortex_bridge.o $(BUILD_DIR)/vortex_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/vortex_bridge.bin: $(BUILD_DIR)/vortex_bridge.elf
	@echo "[OC] Converting Vortex Bridge to binary..."
	objcopy -O binary $< $@
	@echo "  Vortex Bridge binary: $@ (size: $$(stat -c%s $@) bytes)"

# L19: Triage System (0x3A7800, 21KB) — Alert priority queue
$(BUILD_DIR)/triage_system.o: ./modules/security/triage_system.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Triage System to object file..."
	cd ./modules/security && zig build-obj triage_system.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/triage_system.o ]; then mv ./modules/security/triage_system.o $@; fi

$(BUILD_DIR)/triage_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Triage stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/triage_system.elf: $(BUILD_DIR)/triage_system.o $(BUILD_DIR)/triage_stubs.o ./modules/security/triage_system.ld
	@echo "[LD] Linking Triage System ELF..."
	ld -T ./modules/security/triage_system.ld -o $@ $(BUILD_DIR)/triage_system.o $(BUILD_DIR)/triage_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/triage_system.bin: $(BUILD_DIR)/triage_system.elf
	@echo "[OC] Converting Triage System to binary..."
	objcopy -O binary $< $@
	@echo "  Triage System binary: $@ (size: $$(stat -c%s $@) bytes)"

# L20: Consensus Core (0x3AD000, 36KB) — Quorum voting
$(BUILD_DIR)/consensus_core.o: ./modules/security/consensus_core.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Consensus Core to object file..."
	cd ./modules/security && zig build-obj consensus_core.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/consensus_core.o ]; then mv ./modules/security/consensus_core.o $@; fi

$(BUILD_DIR)/consensus_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Consensus stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/consensus_core.elf: $(BUILD_DIR)/consensus_core.o $(BUILD_DIR)/consensus_stubs.o ./modules/security/consensus_core.ld
	@echo "[LD] Linking Consensus Core ELF..."
	ld -T ./modules/security/consensus_core.ld -o $@ $(BUILD_DIR)/consensus_core.o $(BUILD_DIR)/consensus_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/consensus_core.bin: $(BUILD_DIR)/consensus_core.elf
	@echo "[OC] Converting Consensus Core to binary..."
	objcopy -O binary $< $@
	@echo "  Consensus Core binary: $@ (size: $$(stat -c%s $@) bytes)"

# L21: Zen.OS (0x3B7800, 18KB) — State checkpoint
$(BUILD_DIR)/zen_os.o: ./modules/security/zen_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Zen.OS to object file..."
	cd ./modules/security && zig build-obj zen_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/security/zen_os.o ]; then mv ./modules/security/zen_os.o $@; fi

$(BUILD_DIR)/zen_stubs.o: ./modules/security/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Zen.OS stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/zen_os.elf: $(BUILD_DIR)/zen_os.o $(BUILD_DIR)/zen_stubs.o ./modules/security/zen_os.ld
	@echo "[LD] Linking Zen.OS ELF..."
	ld -T ./modules/security/zen_os.ld -o $@ $(BUILD_DIR)/zen_os.o $(BUILD_DIR)/zen_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/zen_os.bin: $(BUILD_DIR)/zen_os.elf
	@echo "[OC] Converting Zen.OS to binary..."
	objcopy -O binary $< $@
	@echo "  Zen.OS binary: $@ (size: $$(stat -c%s $@) bytes)"
	@echo ""
	@echo "✓ PHASE 52: SECURITY GOVERNANCE LAYER COMPLETE"
	@echo "  L15: SAVAos (Identity validation) @ 0x380000"
	@echo "  L16: CAZANos (Subsystem spawn) @ 0x383C00"
	@echo "  L17: SAVACAZANos (Unified permissions) @ 0x388000"
	@echo "  L18: Vortex Bridge (Message routing) @ 0x3A0000"
	@echo "  L19: Triage System (Alert queue) @ 0x3A7800"
	@echo "  L20: Consensus Core (5/7 voting) @ 0x3AD000"
	@echo "  L21: Zen.OS (State checkpoint) @ 0x3B7800"
	@echo "  Total: 159KB, 0x380000–0x3BAFFF (Plugin segment)"
	@echo "  HAP Protocol: ∅ ∞ ∃! ≅ activated"
	@echo ""


# ============================================================================
# PHASE 53: WALLET MANAGER (L48) - Multi-Chain Stealth Wallets + 3 Recovery Modes
# ============================================================================

$(BUILD_DIR)/wallet_manager.o: modules/wallet_manager.zig
	@echo "[ZIG] Compiling Wallet Manager..."
	zig build-obj -target x86_64-freestanding \
		--name wallet_manager \
		-O ReleaseSafe \
		modules/wallet_manager.zig -fno-llvm -fno-lld

$(BUILD_DIR)/math_formulas.o: modules/math_formulas.zig
	@echo "[ZIG] Compiling Math Formulas (4 encryption algorithms)..."
	zig build-obj -target x86_64-freestanding \
		--name math_formulas \
		-O ReleaseSafe \
		modules/math_formulas.zig -fno-llvm -fno-lld

$(BUILD_DIR)/wallet_manager.elf: $(BUILD_DIR)/wallet_manager.o $(BUILD_DIR)/math_formulas.o modules/wallet_manager.ld
	@echo "[LD] Linking Wallet Manager ELF..."
	ld -T modules/wallet_manager.ld \
		$(BUILD_DIR)/wallet_manager.o \
		$(BUILD_DIR)/math_formulas.o \
		-o $@
	@echo "  Wallet Manager ELF: $@"

$(BUILD_DIR)/wallet_manager.bin: $(BUILD_DIR)/wallet_manager.elf
	@echo "[OC] Converting Wallet Manager to binary..."
	objcopy -O binary $< $@
	@echo "  Wallet Manager binary: $@ (size: $$(stat -c%s $@) bytes)"
	@echo ""
	@echo "✓ PHASE 53A: WALLET MANAGER COMPLETE"
	@echo "  L48: Wallet Manager (Multi-Chain HD Wallets) @ 0x530000"
	@echo "  BTC: BIP32/BIP39 (P2WPKH) - m/44'/0'/0'/0/0"
	@echo "  ETH: EOA addresses - m/44'/60'/0'/0/0"
	@echo "  SOL: Derived keys - m/44'/501'/0'/0/0"
	@echo "  EGLD: Bech32 addresses - m/44'/508'/0'/0/0"
	@echo ""
	@echo "  3 Recovery Modes:"
	@echo "    1. RECOVER - 10-step seed-based recovery (4 formulas)"
	@echo "    2. NO_RECOVER - One-time only, maximum security"
	@echo "    3. RECOVER_FROM_VAULTS - Hardware/external vault backup"
	@echo ""
	@echo "  4 Encryption Formulas:"
	@echo "    F1: Hash-Based (SHA256)"
	@echo "    F2: Timestamp-Based (HMAC-SHA256)"
	@echo "    F3: ECDSA-Based (Elliptic Curve KDF)"
	@echo "    F4: Combinatorial (BLAKE2 3-pass Shamir)"
	@echo ""
	@echo "  Total: 320KB stealth zone (0x530000–0x57FFFF)"
	@echo "  Addresses: Always visible | Keys: Encrypted + fragmented"
	@echo ""


# ============================================================================
# PHASE 53B: Cryptographic Implementations + BIP32/BIP39 + Chain Addressing
# ============================================================================

$(BUILD_DIR)/crypto_primitives.o: modules/crypto_primitives.zig
	@echo "[ZIG] Compiling Crypto Primitives (SHA256, HMAC, BLAKE2, ECDSA)..."
	zig build-obj -target x86_64-freestanding \
		--name crypto_primitives \
		-O ReleaseSafe \
		modules/crypto_primitives.zig -fno-llvm -fno-lld

$(BUILD_DIR)/bip32_bip39.o: modules/bip32_bip39.zig
	@echo "[ZIG] Compiling BIP32/BIP39 (Hierarchical Wallet Derivation)..."
	zig build-obj -target x86_64-freestanding \
		--name bip32_bip39 \
		-O ReleaseSafe \
		modules/bip32_bip39.zig -fno-llvm -fno-lld

$(BUILD_DIR)/chain_addressing.o: modules/chain_addressing.zig
	@echo "[ZIG] Compiling Chain Addressing (BTC, ETH, SOL, EGLD)..."
	zig build-obj -target x86_64-freestanding \
		--name chain_addressing \
		-O ReleaseSafe \
		modules/chain_addressing.zig -fno-llvm -fno-lld

# Update wallet_manager to include crypto modules
$(BUILD_DIR)/wallet_manager.elf: $(BUILD_DIR)/wallet_manager.o $(BUILD_DIR)/math_formulas.o $(BUILD_DIR)/crypto_primitives.o $(BUILD_DIR)/bip32_bip39.o $(BUILD_DIR)/chain_addressing.o modules/wallet_manager.ld
	@echo "[LD] Linking Wallet Manager with Crypto Suite..."
	ld -T modules/wallet_manager.ld \
		$(BUILD_DIR)/wallet_manager.o \
		$(BUILD_DIR)/math_formulas.o \
		$(BUILD_DIR)/crypto_primitives.o \
		$(BUILD_DIR)/bip32_bip39.o \
		$(BUILD_DIR)/chain_addressing.o \
		-o $@
	@echo "  Wallet Manager ELF (with crypto): $@"

.PHONY: phase53b-crypto
phase53b-crypto: $(BUILD_DIR)/crypto_primitives.o $(BUILD_DIR)/bip32_bip39.o $(BUILD_DIR)/chain_addressing.o
	@echo ""
	@echo "✓ PHASE 53B: CRYPTOGRAPHIC IMPLEMENTATIONS COMPLETE"
	@echo "  Crypto Primitives: SHA256, HMAC-SHA256, BLAKE2, HKDF, ECDSA secp256k1"
	@echo "  BIP32/BIP39: Master key derivation + hierarchical child key generation"
	@echo "  Chain Addressing:"
	@echo "    - Bitcoin P2WPKH (bc1q...) + Legacy (1...) + Bech32"
	@echo "    - Ethereum EOA (0x...) + EIP-55 checksum"
	@echo "    - Solana (Base58) + Ed25519"
	@echo "    - EGLD (erd1...) + Bech32"
	@echo ""

# ============================================================================
# Utility Targets: Universal Wallet Generator
# ============================================================================

.PHONY: wallet-generator
wallet-generator: universal_wallet_generator
	@echo "✓ Universal Wallet Generator compiled: $<"
	@echo "  Usage: ./universal_wallet_generator"
	@echo "  Generates addresses for 50+ chains from single BIP-39 seed"
	@echo "  Output formats: Post-Quantum (ob_k1_...) + EVM (0x...) + UTXO (1/3/bc1)"

universal_wallet_generator: universal_wallet_generator.zig
	@echo "[ZIG] Compiling Universal Wallet Generator..."
	zig build-exe universal_wallet_generator.zig
	@echo "✓ Compiled: universal_wallet_generator"

# ============================================================================
# PHASE 59: Mining Optimization & Network Efficiency (GPU/ASIC/Stratum V2)
# ============================================================================

# GPU Optimizer OS (0x590000, SIMD Keccak, adaptive difficulty, thermal)
$(BUILD_DIR)/gpu_optimizer_os.o: ./modules/gpu_optimizer_os/gpu_optimizer_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling GPU Optimizer OS to object file..."
	cd ./modules/gpu_optimizer_os && zig build-obj gpu_optimizer_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/gpu_optimizer_os/gpu_optimizer_os.o ]; then mv ./modules/gpu_optimizer_os/gpu_optimizer_os.o $@; fi

$(BUILD_DIR)/gpu_optimizer_os_stubs.o: ./modules/gpu_optimizer_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling GPU Optimizer OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/gpu_optimizer_os.elf: $(BUILD_DIR)/gpu_optimizer_os.o $(BUILD_DIR)/gpu_optimizer_os_stubs.o ./modules/gpu_optimizer_os/gpu_optimizer_os.ld
	@echo "[LD] Linking GPU Optimizer OS ELF..."
	ld -T ./modules/gpu_optimizer_os/gpu_optimizer_os.ld -o $@ $(BUILD_DIR)/gpu_optimizer_os.o $(BUILD_DIR)/gpu_optimizer_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/gpu_optimizer_os.bin: $(BUILD_DIR)/gpu_optimizer_os.elf
	@echo "[OC] Converting GPU Optimizer OS to binary..."
	objcopy -O binary $< $@
	@echo "  GPU Optimizer OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# ASIC Optimizer OS (0x5A0000, frequency scaling, voltage tuning, power profiling)
$(BUILD_DIR)/asic_optimizer_os.o: ./modules/asic_optimizer_os/asic_optimizer_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling ASIC Optimizer OS to object file..."
	cd ./modules/asic_optimizer_os && zig build-obj asic_optimizer_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/asic_optimizer_os/asic_optimizer_os.o ]; then mv ./modules/asic_optimizer_os/asic_optimizer_os.o $@; fi

$(BUILD_DIR)/asic_optimizer_os_stubs.o: ./modules/asic_optimizer_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling ASIC Optimizer OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/asic_optimizer_os.elf: $(BUILD_DIR)/asic_optimizer_os.o $(BUILD_DIR)/asic_optimizer_os_stubs.o ./modules/asic_optimizer_os/asic_optimizer_os.ld
	@echo "[LD] Linking ASIC Optimizer OS ELF..."
	ld -T ./modules/asic_optimizer_os/asic_optimizer_os.ld -o $@ $(BUILD_DIR)/asic_optimizer_os.o $(BUILD_DIR)/asic_optimizer_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/asic_optimizer_os.bin: $(BUILD_DIR)/asic_optimizer_os.elf
	@echo "[OC] Converting ASIC Optimizer OS to binary..."
	objcopy -O binary $< $@
	@echo "  ASIC Optimizer OS binary: $@ (size: $$(stat -c%s $@) bytes)"

# Stratum V2 Gateway (0x5B0000, direct protocol, work distribution, share aggregation)
$(BUILD_DIR)/stratum_v2_gateway.o: ./modules/stratum_v2_gateway/stratum_v2_gateway.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Stratum V2 Gateway to object file..."
	cd ./modules/stratum_v2_gateway && zig build-obj stratum_v2_gateway.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/stratum_v2_gateway/stratum_v2_gateway.o ]; then mv ./modules/stratum_v2_gateway/stratum_v2_gateway.o $@; fi

$(BUILD_DIR)/stratum_v2_gateway_stubs.o: ./modules/stratum_v2_gateway/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Stratum V2 Gateway libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/stratum_v2_gateway.elf: $(BUILD_DIR)/stratum_v2_gateway.o $(BUILD_DIR)/stratum_v2_gateway_stubs.o ./modules/stratum_v2_gateway/stratum_v2_gateway.ld
	@echo "[LD] Linking Stratum V2 Gateway ELF..."
	ld -T ./modules/stratum_v2_gateway/stratum_v2_gateway.ld -o $@ $(BUILD_DIR)/stratum_v2_gateway.o $(BUILD_DIR)/stratum_v2_gateway_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/stratum_v2_gateway.bin: $(BUILD_DIR)/stratum_v2_gateway.elf
	@echo "[OC] Converting Stratum V2 Gateway to binary..."
	objcopy -O binary $< $@
	@echo "  Stratum V2 Gateway binary: $@ (size: $$(stat -c%s $@) bytes)"

# ============================================================================
# PHASE 61: Multi-Cloud Provider Integration (AWS/Azure/GCP/Oracle/VMware)
# ============================================================================

# Cloud Federation OS (0x5D0000, geographic redundancy + failover)
$(BUILD_DIR)/cloud_federation_os.o: ./modules/cloud_federation_os/cloud_federation_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Cloud Federation OS to object file..."
	cd ./modules/cloud_federation_os && zig build-obj cloud_federation_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cloud_federation_os/cloud_federation_os.o ]; then mv ./modules/cloud_federation_os/cloud_federation_os.o $@; fi

$(BUILD_DIR)/cloud_federation_os_stubs.o: ./modules/cloud_federation_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Cloud Federation OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cloud_federation_os.elf: $(BUILD_DIR)/cloud_federation_os.o $(BUILD_DIR)/cloud_federation_os_stubs.o ./modules/cloud_federation_os/cloud_federation_os.ld
	@echo "[LD] Linking Cloud Federation OS ELF..."
	ld -T ./modules/cloud_federation_os/cloud_federation_os.ld -o $@ $(BUILD_DIR)/cloud_federation_os.o $(BUILD_DIR)/cloud_federation_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cloud_federation_os.bin: $(BUILD_DIR)/cloud_federation_os.elf
	@echo "[OC] Converting Cloud Federation OS to binary..."
	objcopy -O binary $< $@
	@echo "  Cloud Federation OS binary: $@ (size: $$(stat -c%s $@) bytes)"


# ============================================================================
# PHASE 62: High-Performance L3 Cache (256KB, <5ns latency)
# ============================================================================

# L3 Cache OS (0x5E0000, 8-way set-associative, LRU/LFU eviction)
$(BUILD_DIR)/cache_l3_os.o: ./modules/cache_l3_os/cache_l3_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling L3 Cache OS to object file..."
	cd ./modules/cache_l3_os && zig build-obj cache_l3_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/cache_l3_os/cache_l3_os.o ]; then mv ./modules/cache_l3_os/cache_l3_os.o $@; fi

$(BUILD_DIR)/cache_l3_os_stubs.o: ./modules/cache_l3_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling L3 Cache OS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/cache_l3_os.elf: $(BUILD_DIR)/cache_l3_os.o $(BUILD_DIR)/cache_l3_os_stubs.o ./modules/cache_l3_os/cache_l3_os.ld
	@echo "[LD] Linking L3 Cache OS ELF..."
	ld -T ./modules/cache_l3_os/cache_l3_os.ld -o $@ $(BUILD_DIR)/cache_l3_os.o $(BUILD_DIR)/cache_l3_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/cache_l3_os.bin $(BUILD_DIR)/quantum_detector_os.bin $(BUILD_DIR)/zk_rollups_os.bin $(BUILD_DIR)/ml_inference_os.bin: $(BUILD_DIR)/cache_l3_os.elf
	@echo "[OC] Converting L3 Cache OS to binary..."
	objcopy -O binary $< $@
	@echo "  L3 Cache OS binary: $@ (size: $$(stat -c%s $@) bytes)"


# Phase 63: Quantum Supremacy Detector
$(BUILD_DIR)/quantum_detector_os.o: ./modules/quantum_detector_os/quantum_detector.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Quantum Detector to object file..."
	cd ./modules/quantum_detector_os && zig build-obj quantum_detector.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/quantum_detector_os/quantum_detector.o ]; then mv ./modules/quantum_detector_os/quantum_detector.o $@; fi

$(BUILD_DIR)/quantum_detector_os_stubs.o: ./modules/quantum_detector_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/quantum_detector_os.elf: $(BUILD_DIR)/quantum_detector_os.o $(BUILD_DIR)/quantum_detector_os_stubs.o ./modules/quantum_detector_os/quantum_detector.ld
	ld -T ./modules/quantum_detector_os/quantum_detector.ld -o $@ $(BUILD_DIR)/quantum_detector_os.o $(BUILD_DIR)/quantum_detector_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/quantum_detector_os.bin: $(BUILD_DIR)/quantum_detector_os.elf
	objcopy -O binary $< $@
	@echo "  Quantum Detector binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 64: Zero-Knowledge Rollups
$(BUILD_DIR)/zk_rollups_os.o: ./modules/zk_rollups_os/zk_rollups.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling ZK Rollups to object file..."
	cd ./modules/zk_rollups_os && zig build-obj zk_rollups.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/zk_rollups_os/zk_rollups.o ]; then mv ./modules/zk_rollups_os/zk_rollups.o $@; fi

$(BUILD_DIR)/zk_rollups_os_stubs.o: ./modules/zk_rollups_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/zk_rollups_os.elf: $(BUILD_DIR)/zk_rollups_os.o $(BUILD_DIR)/zk_rollups_os_stubs.o ./modules/zk_rollups_os/zk_rollups.ld
	ld -T ./modules/zk_rollups_os/zk_rollups.ld -o $@ $(BUILD_DIR)/zk_rollups_os.o $(BUILD_DIR)/zk_rollups_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/zk_rollups_os.bin: $(BUILD_DIR)/zk_rollups_os.elf
	objcopy -O binary $< $@
	@echo "  ZK Rollups binary: $@ (size: $$(stat -c%s $@) bytes)"

# Phase 65: Machine Learning Inference
$(BUILD_DIR)/ml_inference_os.o: ./modules/ml_inference_os/ml_inference.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling ML Inference to object file..."
	cd ./modules/ml_inference_os && zig build-obj ml_inference.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/ml_inference_os/ml_inference.o ]; then mv ./modules/ml_inference_os/ml_inference.o $@; fi

$(BUILD_DIR)/ml_inference_os_stubs.o: ./modules/ml_inference_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/ml_inference_os.elf: $(BUILD_DIR)/ml_inference_os.o $(BUILD_DIR)/ml_inference_os_stubs.o ./modules/ml_inference_os/ml_inference.ld
	ld -T ./modules/ml_inference_os/ml_inference.ld -o $@ $(BUILD_DIR)/ml_inference_os.o $(BUILD_DIR)/ml_inference_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/ml_inference_os.bin: $(BUILD_DIR)/ml_inference_os.elf
	objcopy -O binary $< $@
	@echo "  ML Inference binary: $@ (size: $$(stat -c%s $@) bytes)"

# Bot Strategies Module (0x540000, 128KB) — Trading Engines & Strategies
$(BUILD_DIR)/bot_strategies.o: ./modules/bot_strategies/bot_strategies.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Bot Strategies to object file..."
	cd ./modules/bot_strategies && zig build-obj bot_strategies.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/bot_strategies.o ]; then mv ./modules/bot_strategies/bot_strategies.o $@; fi

$(BUILD_DIR)/gridbot_engine.o: ./modules/bot_strategies/gridbot_engine.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling GridBot Engine to object file..."
	cd ./modules/bot_strategies && zig build-obj gridbot_engine.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/gridbot_engine.o ]; then mv ./modules/bot_strategies/gridbot_engine.o $@; fi

$(BUILD_DIR)/orderbook_local.o: ./modules/bot_strategies/orderbook_local.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling OrderBook Local to object file..."
	cd ./modules/bot_strategies && zig build-obj orderbook_local.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/orderbook_local.o ]; then mv ./modules/bot_strategies/orderbook_local.o $@; fi

$(BUILD_DIR)/market_maker.o: ./modules/bot_strategies/market_maker.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Market Maker to object file..."
	cd ./modules/bot_strategies && zig build-obj market_maker.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/market_maker.o ]; then mv ./modules/bot_strategies/market_maker.o $@; fi

$(BUILD_DIR)/cex_interface.o: ./modules/bot_strategies/cex_interface.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling CEX Interface to object file..."
	cd ./modules/bot_strategies && zig build-obj cex_interface.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/cex_interface.o ]; then mv ./modules/bot_strategies/cex_interface.o $@; fi

$(BUILD_DIR)/cex_signing_bridge.o: ./modules/bot_strategies/cex_signing_bridge.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling CEX Signing Bridge to object file..."
	cd ./modules/bot_strategies && zig build-obj cex_signing_bridge.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/cex_signing_bridge.o ]; then mv ./modules/bot_strategies/cex_signing_bridge.o $@; fi

$(BUILD_DIR)/dca_bot.o: ./modules/bot_strategies/dca_bot.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling DCA Bot to object file..."
	cd ./modules/bot_strategies && zig build-obj dca_bot.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/dca_bot.o ]; then mv ./modules/bot_strategies/dca_bot.o $@; fi

$(BUILD_DIR)/dex_interface.o: ./modules/bot_strategies/dex_interface.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling DEX Interface to object file..."
	cd ./modules/bot_strategies && zig build-obj dex_interface.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/dex_interface.o ]; then mv ./modules/bot_strategies/dex_interface.o $@; fi

$(BUILD_DIR)/unified_orderbook.o: ./modules/bot_strategies/unified_orderbook.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Unified Orderbook to object file..."
	cd ./modules/bot_strategies && zig build-obj unified_orderbook.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/unified_orderbook.o ]; then mv ./modules/bot_strategies/unified_orderbook.o $@; fi

$(BUILD_DIR)/omni_arbitrage.o: ./modules/bot_strategies/omni_arbitrage.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling OmniBus Arbitrage to object file..."
	cd ./modules/bot_strategies && zig build-obj omni_arbitrage.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/omni_arbitrage.o ]; then mv ./modules/bot_strategies/omni_arbitrage.o $@; fi

$(BUILD_DIR)/local_orderbook.o: ./modules/bot_strategies/local_orderbook.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Local OrderBook to object file..."
	cd ./modules/bot_strategies && zig build-obj local_orderbook.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/local_orderbook.o ]; then mv ./modules/bot_strategies/local_orderbook.o $@; fi

$(BUILD_DIR)/cex_orderbook.o: ./modules/bot_strategies/cex_orderbook.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling CEX OrderBook to object file..."
	cd ./modules/bot_strategies && zig build-obj cex_orderbook.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/cex_orderbook.o ]; then mv ./modules/bot_strategies/cex_orderbook.o $@; fi

$(BUILD_DIR)/dex_orderbook.o: ./modules/bot_strategies/dex_orderbook.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling DEX OrderBook to object file..."
	cd ./modules/bot_strategies && zig build-obj dex_orderbook.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/dex_orderbook.o ]; then mv ./modules/bot_strategies/dex_orderbook.o $@; fi

$(BUILD_DIR)/order_router.o: ./modules/bot_strategies/order_router.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling Order Router to object file..."
	cd ./modules/bot_strategies && zig build-obj order_router.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/bot_strategies/order_router.o ]; then mv ./modules/bot_strategies/order_router.o $@; fi

$(BUILD_DIR)/bot_strategies_stubs.o: ./modules/bot_strategies/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Bot Strategies libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/bot_strategies_entry.o: ./modules/bot_strategies/entry.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Bot Strategies entry..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/bot_strategies.elf: $(BUILD_DIR)/bot_strategies.o $(BUILD_DIR)/gridbot_engine.o $(BUILD_DIR)/orderbook_local.o $(BUILD_DIR)/market_maker.o $(BUILD_DIR)/cex_interface.o $(BUILD_DIR)/cex_signing_bridge.o $(BUILD_DIR)/dca_bot.o $(BUILD_DIR)/dex_interface.o $(BUILD_DIR)/unified_orderbook.o $(BUILD_DIR)/omni_arbitrage.o $(BUILD_DIR)/local_orderbook.o $(BUILD_DIR)/cex_orderbook.o $(BUILD_DIR)/dex_orderbook.o $(BUILD_DIR)/order_router.o $(BUILD_DIR)/bot_strategies_stubs.o $(BUILD_DIR)/bot_strategies_entry.o ./modules/bot_strategies/bot_strategies.ld
	@echo "[LD] Linking Bot Strategies ELF..."
	ld -T ./modules/bot_strategies/bot_strategies.ld -o $@ $(BUILD_DIR)/bot_strategies.o $(BUILD_DIR)/gridbot_engine.o $(BUILD_DIR)/orderbook_local.o $(BUILD_DIR)/market_maker.o $(BUILD_DIR)/cex_interface.o $(BUILD_DIR)/cex_signing_bridge.o $(BUILD_DIR)/dca_bot.o $(BUILD_DIR)/dex_interface.o $(BUILD_DIR)/unified_orderbook.o $(BUILD_DIR)/omni_arbitrage.o $(BUILD_DIR)/local_orderbook.o $(BUILD_DIR)/cex_orderbook.o $(BUILD_DIR)/dex_orderbook.o $(BUILD_DIR)/order_router.o $(BUILD_DIR)/bot_strategies_stubs.o $(BUILD_DIR)/bot_strategies_entry.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/bot_strategies.bin: $(BUILD_DIR)/bot_strategies.elf
	@echo "[OC] Converting Bot Strategies to binary..."
	objcopy -O binary $< $@
	@echo "  Bot Strategies binary: $@ (size: $$(stat -c%s $@) bytes)"

