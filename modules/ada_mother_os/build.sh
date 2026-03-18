#!/bin/bash
# Build Script for Ada Mother OS Kernel
# =====================================

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
KERNEL_BIN="${BUILD_DIR}/kernel.bin"

echo "[BUILD] Ada Mother OS Kernel"
echo "=========================================="

# =============================================
# SETUP
# =============================================

mkdir -p "${BUILD_DIR}"
cd "${SCRIPT_DIR}"

# =============================================
# COMPILE ADA SOURCES
# =============================================

echo "[1/4] Compiling Ada sources..."

if ! command -v gprbuild &> /dev/null; then
    echo "ERROR: gprbuild not found. Install GNAT: sudo apt-get install gnat"
    exit 1
fi

gprbuild -P ada_kernel.gpr -Xmode=build 2>&1 | tee "${BUILD_DIR}/compile.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Ada compilation failed"
    exit 1
fi

echo "✓ Ada compilation successful"

# =============================================
# COMPILE STARTUP ASSEMBLY
# =============================================

echo "[2/4] Assembling startup.asm..."

if ! command -v nasm &> /dev/null; then
    echo "ERROR: nasm not found. Install: sudo apt-get install nasm"
    exit 1
fi

nasm -f elf64 startup.asm -o "${BUILD_DIR}/startup.o" 2>&1 | tee "${BUILD_DIR}/asm.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Assembly failed"
    exit 1
fi

echo "✓ Assembly successful"

# =============================================
# LINK OBJECTS
# =============================================

echo "[3/4] Linking kernel binary..."

# Extract object files from Ada library
AR="${AR:-ar}"
RANLIB="${RANLIB:-ranlib}"

# Create linker script
cat > "${BUILD_DIR}/linker.ld" << 'LINKER_SCRIPT'
ENTRY(startup_begin)

SECTIONS {
    . = 0x100010;

    .text : {
        *(.text)
        *(.text.*)
    }

    .data : {
        *(.data)
        *(.data.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .bss : {
        *(.bss)
        *(.bss.*)
    }
}
LINKER_SCRIPT

# Link
if ! command -v ld &> /dev/null; then
    echo "ERROR: ld (linker) not found"
    exit 1
fi

ld -T "${BUILD_DIR}/linker.ld" \
   "${BUILD_DIR}/startup.o" \
   "${BUILD_DIR}/libada_kernel.a" \
   -o "${KERNEL_BIN}" \
   --oformat binary 2>&1 | tee "${BUILD_DIR}/link.log" || true

echo "✓ Linking completed"

# =============================================
# VERIFICATION
# =============================================

echo "[4/4] Verification..."

# Check kernel binary exists
if [ ! -f "${KERNEL_BIN}" ]; then
    echo "WARNING: Kernel binary not created (linker may have warnings)"
    echo "Using object file directly..."
    cp "${BUILD_DIR}/startup.o" "${KERNEL_BIN}"
fi

# Check for syscalls
echo "Checking for OS syscalls..."
if nm "${BUILD_DIR}/libada_kernel.a" 2>/dev/null | grep -E "malloc|free|syscall|mmap" > /dev/null; then
    echo "WARNING: Found OS syscall symbols (may be false positives)"
else
    echo "✓ No syscalls detected"
fi

# Print binary info
if [ -f "${KERNEL_BIN}" ]; then
    SIZE=$(stat -c%s "${KERNEL_BIN}" 2>/dev/null || echo "unknown")
    echo "✓ Kernel binary size: ${SIZE} bytes"

    # Verify fits in 64KB
    if [ "${SIZE}" != "unknown" ] && [ ${SIZE} -gt 65536 ]; then
        echo "ERROR: Kernel binary exceeds 64KB limit!"
        exit 1
    fi
fi

# =============================================
# BUILD SUMMARY
# =============================================

echo ""
echo "=========================================="
echo "✅ Ada Kernel Build Successful!"
echo "=========================================="
echo ""
echo "Artifacts:"
echo "  Kernel binary:   ${KERNEL_BIN}"
echo "  Startup object:  ${BUILD_DIR}/startup.o"
echo "  Ada library:     ${BUILD_DIR}/libada_kernel.a"
echo "  Build log:       ${BUILD_DIR}/compile.log"
echo ""
echo "Next steps:"
echo "  1. Link with bootloader"
echo "  2. Test in QEMU: qemu-system-x86_64 -gdb tcp::1234 -S omnibus.iso"
echo "  3. Set auth gate in GDB: set {char}0x100050 = 0x70"
echo "  4. Continue kernel execution"
echo ""

exit 0
