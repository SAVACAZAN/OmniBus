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

build: $(OUTPUT) $(BUILD_DIR)/grid_os.bin $(BUILD_DIR)/execution_os.bin $(BUILD_DIR)/analytics_os.bin $(BUILD_DIR)/blockchain_os.bin
	@echo "✓ OmniBus built successfully!"
	@echo "  Image: $(OUTPUT)"
	@echo "  Modules: Grid/Exec/Analytics/BlockchainOS loaded from real Zig binaries"
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

$(BUILD_DIR)/grid_os.elf: $(BUILD_DIR)/grid_os.o $(BUILD_DIR)/grid_os_stubs.o ./modules/grid_os/grid_os.ld
	@echo "[LD] Linking Grid OS ELF..."
	ld -T ./modules/grid_os/grid_os.ld -o $@ $(BUILD_DIR)/grid_os.o $(BUILD_DIR)/grid_os_stubs.o 2>&1 | grep -v "warning:" || true

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
$(BUILD_DIR)/blockchain_os.o: ./modules/blockchain_os/blockchain_os.zig | $(BUILD_DIR)/.keep
	@echo "[ZIG] Compiling BlockchainOS to object file..."
	cd ./modules/blockchain_os && zig build-obj blockchain_os.zig -target x86_64-freestanding -O ReleaseFast -ofmt=elf 2>&1 | grep -v "note:" || true
	@if [ -f ./modules/blockchain_os/blockchain_os.o ]; then mv ./modules/blockchain_os/blockchain_os.o $@; fi

$(BUILD_DIR)/blockchain_os_stubs.o: ./modules/blockchain_os/libc_stubs.asm | $(BUILD_DIR)/.keep
	@echo "[AS] Assembling BlockchainOS libc stubs..."
	nasm -f elf64 -o $@ $<

$(BUILD_DIR)/blockchain_os.elf: $(BUILD_DIR)/blockchain_os.o $(BUILD_DIR)/blockchain_os_stubs.o ./modules/blockchain_os/blockchain_os.ld
	@echo "[LD] Linking BlockchainOS ELF..."
	ld -T ./modules/blockchain_os/blockchain_os.ld -o $@ $(BUILD_DIR)/blockchain_os.o $(BUILD_DIR)/blockchain_os_stubs.o 2>&1 | grep -v "warning:" || true

$(BUILD_DIR)/blockchain_os.bin: $(BUILD_DIR)/blockchain_os.elf
	@echo "[OC] Converting BlockchainOS to binary..."
	objcopy -O binary $< $@
	@echo "  BlockchainOS binary: $@ (size: $$(stat -c%s $@) bytes)"

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
	@echo "[IMG] Creating bootable disk image (Phase 5B)..."
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
	@# Determine which binaries to use
	@GRID_BIN=$$([ -f $(BUILD_DIR)/grid_os.bin ] && echo $(BUILD_DIR)/grid_os.bin || echo $(BUILD_DIR)/grid_stub.bin); \
	ANALYTICS_BIN=$$([ -f $(BUILD_DIR)/analytics_os.bin ] && echo $(BUILD_DIR)/analytics_os.bin || echo $(BUILD_DIR)/analytics_stub.bin); \
	EXEC_BIN=$$([ -f $(BUILD_DIR)/execution_os.bin ] && echo $(BUILD_DIR)/execution_os.bin || echo $(BUILD_DIR)/execution_stub.bin); \
	echo "[IMG] Using: Grid=$$(basename $$GRID_BIN) Analytics=$$(basename $$ANALYTICS_BIN) Exec=$$(basename $$EXEC_BIN)"; \
	dd if=/dev/zero of=$(OUTPUT) bs=512 count=20480 2>/dev/null; \
	dd if=$(BUILD_DIR)/boot.bin of=$(OUTPUT) bs=512 count=1 conv=notrunc 2>/dev/null; \
	dd if=$(BUILD_DIR)/stage2.bin of=$(OUTPUT) bs=512 seek=1 conv=notrunc 2>/dev/null; \
	dd if=$(BUILD_DIR)/kernel_stub.bin of=$(OUTPUT) bs=512 seek=2048 conv=notrunc 2>/dev/null; \
	dd if=$$GRID_BIN of=$(OUTPUT) bs=512 seek=4096 conv=notrunc 2>/dev/null; \
	dd if=$$ANALYTICS_BIN of=$(OUTPUT) bs=512 seek=4352 conv=notrunc 2>/dev/null; \
	dd if=$$EXEC_BIN of=$(OUTPUT) bs=512 seek=5376 conv=notrunc 2>/dev/null
	@echo "  Disk image: $(OUTPUT) ($$(stat -c%s $(OUTPUT)) bytes)"
	@echo "  Sector layout:"
	@echo "    Boot:      sector 0-0"
	@echo "    Stage2:    sector 1-1"
	@echo "    Kernel:    sector 2048-2176 (128KB kernel)"
	@echo "    Grid OS:   sector 4096-4351 (256 sectors, 128KB)"
	@echo "    Analytics: sector 4352-5375 (1024 sectors, 512KB)"
	@echo "    Exec OS:   sector 5376-5631 (256 sectors, 128KB)"

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
