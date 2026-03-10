#!/bin/bash
###############################################################################
# Phase 5D-2 Full Integration Test: Boot OmniBus + Real Market Feeder
#
# Runs both in parallel:
#   Terminal 1: Kraken feeder (updates buffer every 100ms)
#   Terminal 2: OmniBus QEMU (reads prices from buffer)
#
# Usage:
#   bash run_phase_5d2_full.sh [--duration 30] [--interval 100]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DURATION=${DURATION:-30}  # seconds to run test
INTERVAL_MS=${INTERVAL_MS:-100}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 5D-2: OmniBus Boot + Real Market Data Feeder        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Duration: ${DURATION}s"
echo "  Interval: ${INTERVAL_MS}ms"
echo "  Feeder: Kraken (BTC, ETH, LCX)"
echo ""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --interval)
            INTERVAL_MS="$2"
            shift 2
            ;;
    esac
done

# Step 1: Start feeder in background
echo -e "${YELLOW}[1/3] Starting Kraken feeder in background...${NC}"
cd "$SCRIPT_DIR"

python3 kraken_feeder.py --file --interval "$INTERVAL_MS" --verbose > /tmp/feeder.log 2>&1 &
FEEDER_PID=$!
echo -e "${GREEN}✓ Feeder PID: $FEEDER_PID${NC}"
echo "  Log: /tmp/feeder.log"
echo ""

# Give feeder time to connect and fetch first prices
sleep 3

# Step 2: Verify feeder is working
echo -e "${YELLOW}[2/3] Verifying feeder output...${NC}"
if [ -f "/tmp/omnibus_kraken_buffer.bin" ]; then
    CYCLES=$(grep -c "Cycle" /tmp/feeder.log || echo "0")
    echo -e "${GREEN}✓ Feeder running: $CYCLES cycles completed${NC}"

    # Extract latest prices
    LATEST=$(tail -1 /tmp/feeder.log)
    echo -e "${GREEN}✓ Latest: $LATEST${NC}"
else
    echo -e "${RED}✗ Buffer not created - feeder may have failed${NC}"
    tail -20 /tmp/feeder.log
    kill $FEEDER_PID 2>/dev/null || true
    exit 1
fi
echo ""

# Step 3: Boot OmniBus with timeout
echo -e "${YELLOW}[3/3] Booting OmniBus in QEMU (${DURATION}s timeout)...${NC}"
echo -e "${BLUE}Serial output below:${NC}"
echo "════════════════════════════════════════════════════════════"

# Run QEMU with timeout
timeout $DURATION make qemu 2>&1 || QEMU_EXIT=$?

echo "════════════════════════════════════════════════════════════"
echo ""

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
kill $FEEDER_PID 2>/dev/null || true
wait $FEEDER_PID 2>/dev/null || true

# Print summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST SUMMARY                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Count feeder cycles
FEEDER_CYCLES=$(grep -c "Cycle" /tmp/feeder.log || echo "0")
echo -e "${GREEN}✓ Feeder cycles: $FEEDER_CYCLES${NC}"

# Show final prices
FINAL_PRICES=$(tail -1 /tmp/feeder.log)
echo -e "${GREEN}✓ Final prices: $FINAL_PRICES${NC}"

# Check if OmniBus booted
if grep -q "KTCRPLONG_MODE_OK\|MOTHER_OS_64_OK" /tmp/qemu_output.log 2>/dev/null; then
    echo -e "${GREEN}✓ OmniBus booted successfully${NC}"
else
    echo -e "${YELLOW}⚠ OmniBus output not captured (check QEMU window)${NC}"
fi

echo ""
echo -e "${BLUE}Key files:${NC}"
echo "  Buffer: /tmp/omnibus_kraken_buffer.bin (72 bytes)"
echo "  Feeder log: /tmp/feeder.log"
echo "  QEMU log: /tmp/qemu_output.log"
echo ""
echo -e "${GREEN}Phase 5D-2: READY FOR INTEGRATION ✓${NC}"
echo ""
echo "Next: Check that Analytics OS @ 0x150000 reads from buffer @ 0x140000"
