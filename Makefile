# ============================================================================
# OmniBus Makefile
# Builds bare-metal bootloader and kernel for QEMU x86-64
# ============================================================================

.PHONY: all build clean qemu qemu-debug help

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

build: $(BUILD_DIR) $(OUTPUT)
	@echo "✓ OmniBus built successfully!"
	@echo "  Image: $(OUTPUT)"
	@echo "  Run with: make qemu"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile boot sector (Stage 1)
$(BUILD_DIR)/boot.bin: $(ARCH_DIR)/boot.asm
	@echo "[AS] Compiling boot sector..."
	$(NASM) -f bin -o $@ $<
	@echo "  Boot sector: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# Compile Stage 2 bootloader (using fixed version with register-indirect addressing)
$(BUILD_DIR)/stage2.bin: $(ARCH_DIR)/stage2_fixed.asm
	@echo "[AS] Compiling Stage 2..."
	$(NASM) -f bin -o $@ $<
	@echo "  Stage 2: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# Copy Ada kernel binary
$(BUILD_DIR)/kernel_stub.bin: ./modules/ada_mother_os/kernel.bin
	@echo "[CP] Copying Ada kernel binary..."
	cp $< $@
	@echo "  Kernel binary: $@ (size: $$(stat -f%z $@ 2>/dev/null || stat -c%s $@) bytes)"

# Create bootable disk image
$(OUTPUT): $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel_stub.bin
	@echo "[IMG] Creating bootable disk image..."
	@# Create an empty 10MB disk image
	dd if=/dev/zero of=$(OUTPUT) bs=512 count=20480 2>/dev/null
	@# Write boot sector at offset 0
	dd if=$(BUILD_DIR)/boot.bin of=$(OUTPUT) bs=512 count=1 conv=notrunc 2>/dev/null
	@# Write Stage 2 at offset 1 sector (0x200 bytes)
	dd if=$(BUILD_DIR)/stage2.bin of=$(OUTPUT) bs=512 seek=1 conv=notrunc 2>/dev/null
	@# Write kernel stub at offset 0x100000 (1MB) = 2048 sectors (1MB / 512 bytes per sector)
	dd if=$(BUILD_DIR)/kernel_stub.bin of=$(OUTPUT) bs=512 seek=2048 conv=notrunc 2>/dev/null
	@echo "  Disk image: $(OUTPUT) ($$(stat -f%z $(OUTPUT) 2>/dev/null || stat -c%s $(OUTPUT)) bytes)"

# ============================================================================
# RUN: Execute in QEMU
# ============================================================================

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
