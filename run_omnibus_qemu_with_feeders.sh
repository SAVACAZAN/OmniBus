#!/bin/bash
#
# OmniBus QEMU Boot with Real Price Feeders
# ==========================================
# Phase 25: Boot OmniBus kernel with live price data from 3 exchanges
#
# Usage:
#   ./run_omnibus_qemu_with_feeders.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT="$BUILD_DIR/omnibus.iso"

# QEMU settings
QEMU="qemu-system-x86_64"
QEMU_FLAGS="-m 256 -drive format=raw,file=$OUTPUT -serial mon:stdio"

# Feeder processes
KRAKEN_PID=""
COINBASE_PID=""
LCX_PID=""

# Cleanup function
cleanup() {
    echo ""
    echo "⏹  Shutting down OmniBus..."

    # Kill feeders
    if [ -n "$KRAKEN_PID" ]; then
        kill $KRAKEN_PID 2>/dev/null || true
    fi
    if [ -n "$COINBASE_PID" ]; then
        kill $COINBASE_PID 2>/dev/null || true
    fi
    if [ -n "$LCX_PID" ]; then
        kill $LCX_PID 2>/dev/null || true
    fi

    wait $KRAKEN_PID $COINBASE_PID $LCX_PID 2>/dev/null || true

    echo "✓ OmniBus stopped cleanly"
    exit 0
}

# Trap signals
trap cleanup SIGINT SIGTERM EXIT

# Main script
main() {
    echo "╔════════════════════════════════════════════════════╗"
    echo "║    OmniBus Phase 25: QEMU Boot with Live Prices    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""

    # Build OmniBus
    echo "🔨 Building OmniBus kernel and modules..."
    cd "$SCRIPT_DIR"
    make clean > /dev/null 2>&1 || true
    make build > /dev/null 2>&1
    echo "✓ Build complete"
    echo ""

    # Verify image exists
    if [ ! -f "$OUTPUT" ]; then
        echo "❌ Error: $OUTPUT not found"
        exit 1
    fi

    echo "🚀 Starting price feeders..."
    echo ""

    # Start Kraken feeder
    python3 "$SCRIPT_DIR/kraken_feeder.py" --file --interval 500 \
        > /tmp/omnibus_kraken.log 2>&1 &
    KRAKEN_PID=$!
    echo "  ✓ Kraken feeder started (PID: $KRAKEN_PID)"
    sleep 0.5

    # Start Coinbase feeder
    python3 "$SCRIPT_DIR/coinbase_feeder.py" --interval 500 \
        > /tmp/omnibus_coinbase.log 2>&1 &
    COINBASE_PID=$!
    echo "  ✓ Coinbase feeder started (PID: $COINBASE_PID)"
    sleep 0.5

    # Start LCX Exchange feeder
    python3 "$SCRIPT_DIR/lcx_feeder.py" --interval 500 \
        > /tmp/omnibus_lcx.log 2>&1 &
    LCX_PID=$!
    echo "  ✓ LCX Exchange feeder started (PID: $LCX_PID)"
    sleep 1.5

    # Verify feeders are writing data
    if [ -f /tmp/omnibus_kraken_buffer.bin ] && \
       [ -f /tmp/omnibus_coinbase_buffer.bin ] && \
       [ -f /tmp/omnibus_lcx_buffer.bin ]; then
        echo ""
        echo "✓ All price buffers created successfully"
        ls -lh /tmp/omnibus_*_buffer.bin | awk '{printf "    %s (%s)\n", $9, $5}'
    else
        echo "⚠ Warning: Not all buffer files created yet"
    fi

    echo ""
    echo "📊 QEMU Boot Status:"
    echo "  Expected serial output:"
    echo "    - KTCRPLONG_MODE_OK     (64-bit long mode)"
    echo "    - MOTHER_OS_64_OK       (Ada kernel initialized)"
    echo "    - GZWBNSVO              (Grid OS metrics available)"
    echo ""
    echo "💡 Price feed integration:"
    echo "    - Kraken   → /tmp/omnibus_kraken_buffer.bin"
    echo "    - Coinbase → /tmp/omnibus_coinbase_buffer.bin"
    echo "    - LCX Exch → /tmp/omnibus_lcx_buffer.bin"
    echo ""
    echo "🎮 QEMU Controls:"
    echo "    - Press Ctrl+A then X to exit"
    echo "    - Feeders will stop automatically"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Boot QEMU
    $QEMU $QEMU_FLAGS
}

# Run main
main
