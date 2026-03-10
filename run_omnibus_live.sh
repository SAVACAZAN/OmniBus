#!/bin/bash
###############################################################################
# Phase 15: OmniBus Live Trading — QEMU + Real Price Bridge
# ===========================================================
#
# Architecture:
#   Kraken API → kraken_feeder.py --shm /tmp/omnibus_mem
#                      ↓ mmap.write @ offset 0x140000
#               /tmp/omnibus_mem (256MB shared memory file)
#                      ↑ -object memory-backend-file
#   QEMU kernel reads from physical 0x140000 → Analytics OS → Grid OS
#
# Usage:
#   ./run_omnibus_live.sh [--duration 60] [--interval 500]
#
# Controls:
#   Ctrl+A then X — exit QEMU
#   Ctrl+C        — stop everything cleanly
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
SHM_FILE="/tmp/omnibus_live_mem"
SHM_SIZE="256M"
DURATION="${DURATION:-0}"        # 0 = run forever
INTERVAL_MS="${INTERVAL_MS:-500}"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --duration) DURATION="$2"; shift 2 ;;
        --interval) INTERVAL_MS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   OmniBus Phase 15: Live Trading — Real Prices via SHM       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Config:${NC}"
echo "  SHM file:  $SHM_FILE"
echo "  Interval:  ${INTERVAL_MS}ms"
[[ $DURATION -gt 0 ]] && echo "  Duration:  ${DURATION}s" || echo "  Duration:  unlimited"
echo ""

# Cleanup on exit
FEEDER_PID=""
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    [[ -n "$FEEDER_PID" ]] && kill "$FEEDER_PID" 2>/dev/null || true
    wait "$FEEDER_PID" 2>/dev/null || true
    rm -f "$SHM_FILE"
    echo -e "${GREEN}✓ Stopped cleanly${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# === Step 1: Build ===
echo -e "${YELLOW}[1/4] Building OmniBus kernel...${NC}"
make build > /dev/null 2>&1
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# === Step 2: Create shared memory file ===
echo -e "${YELLOW}[2/4] Creating 256MB shared memory file...${NC}"
rm -f "$SHM_FILE"
dd if=/dev/zero of="$SHM_FILE" bs=1M count=256 status=none
chmod 600 "$SHM_FILE"
echo -e "${GREEN}✓ $SHM_FILE created (256MB)${NC}"
echo ""

# === Step 3: Start price feeder (writes to SHM at 0x140000) ===
echo -e "${YELLOW}[3/4] Starting Kraken price feeder (SHM mode)...${NC}"
python3 "$SCRIPT_DIR/kraken_feeder.py" \
    --shm "$SHM_FILE" \
    --interval "$INTERVAL_MS" \
    --verbose \
    > /tmp/omnibus_live_feeder.log 2>&1 &
FEEDER_PID=$!
echo -e "${GREEN}✓ Feeder PID: $FEEDER_PID${NC}"

# Wait for first price write
echo "  Waiting for first prices..."
for i in $(seq 1 10); do
    sleep 0.5
    if [ -f /tmp/omnibus_kraken_buffer.bin ]; then
        BTC_HEX=$(xxd -p /tmp/omnibus_kraken_buffer.bin 2>/dev/null | tr -d '\n' | cut -c17-32)
        BTC_CENTS=$(printf '%d\n' "0x$(echo $BTC_HEX | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\8\7\6\5\4\3\2\1/')" 2>/dev/null || echo 0)
        if [ "$BTC_CENTS" -gt 0 ] 2>/dev/null; then
            BTC_USD=$(echo "scale=2; $BTC_CENTS / 100" | bc 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓ Live price: BTC=\$$BTC_USD${NC}"
            break
        fi
    fi
done
echo ""

# === Step 4: Boot QEMU with shared memory ===
echo -e "${YELLOW}[4/4] Booting OmniBus kernel with live price bridge...${NC}"
echo ""
echo "  Expected serial output:"
echo "    KTCRPLONG_MODE_OK  (64-bit long mode)"
echo "    MOTHER_OS_64_OK    (Ada kernel)"
echo "    INISIM!            (simulators active)"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "  Live prices injected at: phys 0x140000 (via SHM mmap)"
echo "  Feeder log: /tmp/omnibus_live_feeder.log"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Boot command
QEMU_CMD="qemu-system-x86_64
  -object memory-backend-file,id=mem0,size=${SHM_SIZE},mem-path=${SHM_FILE},share=on
  -machine q35,memory-backend=mem0
  -drive format=raw,file=./build/omnibus.iso
  -serial mon:stdio"

if [ "$DURATION" -gt 0 ]; then
    timeout "$DURATION" $QEMU_CMD || true
else
    $QEMU_CMD || true
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  OmniBus session ended${NC}"
FEEDER_CYCLES=$(grep -c "Cycle\|cycle" /tmp/omnibus_live_feeder.log 2>/dev/null || echo "0")
LAST_PRICE=$(grep -o "BTC=\\\$[0-9.]*" /tmp/omnibus_live_feeder.log 2>/dev/null | tail -1 || echo "N/A")
echo "  Feeder cycles: $FEEDER_CYCLES"
echo "  Last price:    $LAST_PRICE"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
