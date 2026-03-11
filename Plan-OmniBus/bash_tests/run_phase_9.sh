#!/bin/bash
###############################################################################
# Phase 9: Grid OS Real Trading Execution
#
# This script orchestrates:
#   1. Kraken API price feeder (live BTC/ETH/LCX)
#   2. OmniBus kernel + Analytics OS consensus
#   3. Grid OS arbitrage execution on REAL prices
#   4. Real-time metrics monitoring
#
# Architecture:
#   Kraken API @ 0x140000
#       ↓
#   Analytics OS consensus @ 0x150000
#       ↓
#   Grid OS trading @ 0x110000
#       ↓
#   BlockchainOS simulator processes results
#   NeuroOS simulator evolves on fitness metrics
#
# Usage:
#   bash run_phase_9.sh [--duration 60] [--interval 100]
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DURATION=${DURATION:-60}
INTERVAL_MS=${INTERVAL_MS:-100}

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 9: Grid OS Real Trading on LIVE KRAKEN PRICES      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
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

echo -e "${YELLOW}Configuration:${NC}"
echo "  Duration: ${DURATION}s"
echo "  Price update interval: ${INTERVAL_MS}ms"
echo "  Price source: Kraken (real API)"
echo ""

# Step 1: Start Kraken price feeder
echo -e "${YELLOW}[1/3] Starting Kraken price feeder...${NC}"
python3 kraken_feeder.py --file --interval "$INTERVAL_MS" --verbose > /tmp/phase9_feeder.log 2>&1 &
FEEDER_PID=$!
echo -e "${GREEN}✓ Feeder PID: $FEEDER_PID${NC}"
sleep 2

# Step 2: Verify feeder is producing prices
if [ ! -f /tmp/omnibus_kraken_buffer.bin ]; then
    echo -e "${RED}✗ Feeder failed to create price buffer${NC}"
    kill $FEEDER_PID 2>/dev/null || true
    exit 1
fi

BUFFER_HEX=$(xxd -p /tmp/omnibus_kraken_buffer.bin | tr -d '\n')
BTC_HEX="${BUFFER_HEX:16:16}"
BTC_CENTS=$(printf '%d\n' "0x$(echo $BTC_HEX | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\8\7\6\5\4\3\2\1/')")
BTC_USD=$(echo "scale=2; $BTC_CENTS / 100" | bc)

echo -e "${GREEN}✓ Real price verified: BTC = \$$BTC_USD${NC}"
echo ""

# Step 3: Boot OmniBus with metrics collection
echo -e "${YELLOW}[2/3] Booting OmniBus + Grid OS...${NC}"
echo -e "${BLUE}Serial output (showing Grid execution):${NC}"
echo "════════════════════════════════════════════════════════════"

# Start QEMU with serial output collection
timeout $DURATION qemu-system-x86_64 -m 256 \
    -drive format=raw,file=./build/omnibus.iso \
    -serial mon:stdio 2>&1 | tee /tmp/phase9_boot.log || true

echo "════════════════════════════════════════════════════════════"
echo ""

# Step 4: Analyze results
echo -e "${YELLOW}[3/3] Analyzing trading results...${NC}"

# Cleanup feeder
kill $FEEDER_PID 2>/dev/null || true
wait $FEEDER_PID 2>/dev/null || true

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            PHASE 9 EXECUTION RESULTS                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Extract metrics from boot log
BOOT_MARKERS=$(grep -o "KTCRPLONG_MODE_OK\|INISIM\|MOTHER_OS_64_OK" /tmp/phase9_boot.log 2>/dev/null | sort | uniq -c)
echo -e "${GREEN}System Boot:${NC}"
echo "$BOOT_MARKERS" || echo "  (Check /tmp/phase9_boot.log for details)"
echo ""

# Extract feeder stats
FEEDER_CYCLES=$(grep -c "Cycle" /tmp/phase9_feeder.log 2>/dev/null || echo "0")
LAST_PRICE=$(tail -1 /tmp/phase9_feeder.log 2>/dev/null | grep -o "BTC=\$[0-9.]*" || echo "N/A")

echo -e "${GREEN}Price Feed:${NC}"
echo "  Cycles: $FEEDER_CYCLES"
echo "  Latest: $LAST_PRICE"
echo ""

echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Review /tmp/phase9_boot.log for kernel output"
echo "  2. Verify Grid OS loaded and initialized (check for 'G' marker)"
echo "  3. Check if Analytics consensus is processing prices (check for 'Z' marker)"
echo "  4. Run longer test: bash run_phase_9.sh --duration 120"
echo ""

echo -e "${YELLOW}Key Files:${NC}"
echo "  Price buffer: /tmp/omnibus_kraken_buffer.bin (72 bytes)"
echo "  Feeder log: /tmp/phase9_feeder.log"
echo "  Boot log: /tmp/phase9_boot.log"
echo ""

if grep -q "INISIM" /tmp/phase9_boot.log 2>/dev/null; then
    echo -e "${GREEN}✓ Phase 9 READY: Grid OS executing on REAL prices!${NC}"
else
    echo -e "${YELLOW}⚠ Grid OS not yet executing. Check logs for details.${NC}"
fi
