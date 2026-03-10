#!/bin/bash
# test_qemu_integration.sh — Full OmniBus QEMU integration test
# Tests bootloader → Ada kernel → OS layers pipeline

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        OmniBus Full Stack Integration Test                  ║"
echo "║        Bootloader → Ada Kernel → OS Layers                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if disk image exists
if [ ! -f build/omnibus.iso ]; then
    echo "❌ Error: build/omnibus.iso not found"
    echo "   Run: make build"
    exit 1
fi

echo "✓ Disk image found: $(ls -lh build/omnibus.iso | awk '{print $5, $9}')"
echo ""

# Expected boot sequence
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Expected Output Sequence:                                 ║"
echo "├────────────────────────────────────────────────────────────┤"
echo "║  1. SeaBIOS/iPXE boot messages                             ║"
echo "║  2. 'OmniBus: Boot Stage 1 loaded. Jumping to Stage 2..'    ║"
echo "║  3. 'PMODE OK' (protected mode entry)                      ║"
echo "║  4. '[KERN] Ada kernel booting @ 0x100000'                 ║"
echo "║  5. '[KERN] PQC vault loaded @ 0x100800'                   ║"
echo "║  6. '[KERN] Auth gate ENABLED'                             ║"
echo "║  7. '[SCHED] Dispatching L2/L3/L4'                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "🔄 Starting QEMU (timeout 10 seconds)..."
echo "════════════════════════════════════════════════════════════════"

# Capture output
timeout 10 qemu-system-x86_64 \
    -m 256 \
    -drive format=raw,file=build/omnibus.iso \
    -chardev stdio,id=ser0 \
    -device isa-serial,chardev=ser0 \
    -monitor none \
    -nographic \
    2>&1 | tee /tmp/qemu_output.log || true

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Analyze output
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Results Analysis:                                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

LOG_FILE="/tmp/qemu_output.log"

# Check for critical markers
check_marker() {
    local marker="$1"
    local description="$2"

    if grep -q "$marker" "$LOG_FILE" 2>/dev/null; then
        echo "  ✅ PASS: $description"
        return 0
    else
        echo "  ❌ FAIL: $description"
        return 1
    fi
}

PASS_COUNT=0
FAIL_COUNT=0

# Stage 1 boot
if check_marker "Boot.*Stage 1" "Stage 1 bootloader executed"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# Stage 2 transition
if check_marker "Jumping to Stage 2" "Stage 2 transition"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# Protected mode
if check_marker "PMODE OK" "Protected mode entry"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# Ada kernel boot
if check_marker "\[KERN\].*Ada kernel" "Ada kernel initialization"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# PQC vault
if check_marker "PQC vault" "PQC vault loading"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# Auth gate
if check_marker "Auth gate.*ENABLED" "Authorization gate enabled"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

# Scheduler dispatch
if check_marker "\[SCHED\]" "Scheduler dispatching"; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Summary:                                                  ║"
echo "├────────────────────────────────────────────────────────────┤"
echo "║  Passed: $PASS_COUNT / 7                                     ║"
echo "║  Failed: $FAIL_COUNT / 7                                     ║"

if [ $FAIL_COUNT -eq 0 ]; then
    echo "║  Status: ✅ ALL TESTS PASSED                               ║"
    RESULT="PASS"
else
    echo "║  Status: ⚠️  PARTIAL FAILURE (see details below)          ║"
    RESULT="PARTIAL"
fi

echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Raw output for debugging
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Raw QEMU Output:                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Extract only relevant lines
echo "Boot sequence:"
grep -E "OmniBus|PMODE|KERN|SCHED|UART|Auth" "$LOG_FILE" | head -30 || echo "(No kernel output detected)"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Detailed diagnostics
if [ "$RESULT" = "PARTIAL" ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Troubleshooting Guide:                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    if ! grep -q "\[KERN\]" "$LOG_FILE" 2>/dev/null; then
        echo "❌ Ada kernel not running:"
        echo "   - Check if kernel.bin loaded correctly"
        echo "   - Verify bootloader jump to 0x100030"
        echo "   - Use: gdb -ex 'target remote :1234' for debugging"
        echo ""
        echo "Debug with GDB:"
        echo "   1. Terminal 1: make qemu-debug"
        echo "   2. Terminal 2: gdb build/omnibus.iso"
        echo "   3. (gdb) target remote :1234"
        echo "   4. (gdb) set breakpoint at 0x100030"
        echo "   5. (gdb) continue"
    fi

    if ! grep -q "PMODE" "$LOG_FILE" 2>/dev/null; then
        echo "❌ Protected mode not reached:"
        echo "   - Check GDT descriptor D-bit"
        echo "   - Verify far jump address"
        echo "   - Test with: make qemu-debug"
    fi
fi

# Recommendations
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Next Steps:                                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ "$RESULT" = "PASS" ]; then
    echo "✅ Full integration successful!"
    echo ""
    echo "Recommended next steps:"
    echo "  1. Run: ./test_qemu_integration.sh --debug"
    echo "  2. Verify OS layer initialization"
    echo "  3. Test trading pipeline (Grid → Execution → Exchange)"
    echo "  4. Profile performance under load"
    echo ""
    echo "To debug specific layers:"
    echo "  - Analytics OS: check price feed at 0x150000"
    echo "  - Grid OS: verify order ring at 0x110000"
    echo "  - Execution OS: trace signing at 0x130000"
elif [ "$RESULT" = "PARTIAL" ]; then
    echo "⚠️  Partial success - investigate failures above"
    echo ""
    echo "Debug with GDB:"
    echo "  make qemu-debug  # (in one terminal)"
    echo "  gdb              # (in another terminal)"
fi

echo ""
exit $FAIL_COUNT
