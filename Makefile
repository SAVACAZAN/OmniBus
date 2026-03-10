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

# ============================================================================
# BUILD: Compile Assembly sources
# ============================================================================

build: $(OUTPUT)
	@echo "✓ OmniBus built successfully!"
	@echo "  Image: $(OUTPUT)"
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

# Phase 5: OS Layer Loader (PIO ATA + 64-bit module stubs)
# startup_phase5.asm = phase4 long mode + disk reader + 3 OS module stubs
ADA_STARTUP := ./modules/ada_mother_os/startup_phase5.asm
ADA_KERNEL_BIN := ./modules/ada_mother_os/kernel.bin

$(ADA_KERNEL_BIN): $(ADA_STARTUP)
	@echo "[AS] Rebuilding Ada kernel binary (Phase 5)..."
	$(NASM) -f bin -o $@ $<
	@echo "  Ada kernel: $@ (size: $$(stat -c%s $@) bytes)"

# Copy Ada kernel binary
$(BUILD_DIR)/kernel_stub.bin: $(ADA_KERNEL_BIN)
	@echo "[CP] Copying Ada kernel binary..."
	cp $< $@
	@echo "  Kernel binary: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# OS module stubs (64-bit NASM flat binaries, loaded from disk at runtime)
$(BUILD_DIR)/grid_stub.bin: $(ARCH_DIR)/grid_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Grid OS stub..."
	$(NASM) -f bin -o $@ $<
	@echo "  Grid stub: $@ (size: $$(stat -c%s $@) bytes)"

$(BUILD_DIR)/analytics_stub.bin: $(ARCH_DIR)/analytics_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Analytics OS stub..."
	$(NASM) -f bin -o $@ $<
	@echo "  Analytics stub: $@ (size: $$(stat -c%s $@) bytes)"

$(BUILD_DIR)/execution_stub.bin: $(ARCH_DIR)/execution_stub.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling Execution OS stub..."
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

# Create bootable disk image (Phase 5: includes OS module stubs at fixed sectors)
$(OUTPUT): $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel_stub.bin \
           $(BUILD_DIR)/grid_stub.bin $(BUILD_DIR)/analytics_stub.bin $(BUILD_DIR)/execution_stub.bin
	@echo "[IMG] Creating bootable disk image (Phase 5)..."
	@# Create an empty 10MB disk image
	dd if=/dev/zero of=$(OUTPUT) bs=512 count=20480 2>/dev/null
	@# Stage 1: boot sector @ sector 0
	dd if=$(BUILD_DIR)/boot.bin of=$(OUTPUT) bs=512 count=1 conv=notrunc 2>/dev/null
	@# Stage 2: @ sector 1
	dd if=$(BUILD_DIR)/stage2.bin of=$(OUTPUT) bs=512 seek=1 conv=notrunc 2>/dev/null
	@# Kernel (startup_phase5.asm): @ sector 2048 (= 1MB offset)
	dd if=$(BUILD_DIR)/kernel_stub.bin of=$(OUTPUT) bs=512 seek=2048 conv=notrunc 2>/dev/null
	@# Grid OS stub: @ sector 4096 (= 2MB offset), 16 sectors = 8KB
	dd if=$(BUILD_DIR)/grid_stub.bin of=$(OUTPUT) bs=512 seek=4096 conv=notrunc 2>/dev/null
	@# Analytics OS stub: @ sector 4352 (= 2.125MB offset), 16 sectors = 8KB
	dd if=$(BUILD_DIR)/analytics_stub.bin of=$(OUTPUT) bs=512 seek=4352 conv=notrunc 2>/dev/null
	@# Execution OS stub: @ sector 4608 (= 2.25MB offset), 16 sectors = 8KB
	dd if=$(BUILD_DIR)/execution_stub.bin of=$(OUTPUT) bs=512 seek=4608 conv=notrunc 2>/dev/null
	@echo "  Disk image: $(OUTPUT) ($$(stat -f%z $(OUTPUT) 2>/dev/null || stat -c%s $(OUTPUT)) bytes)"

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
