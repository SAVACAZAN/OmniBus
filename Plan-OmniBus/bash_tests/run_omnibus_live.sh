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

# === Step 3: Start all 3 price feeders (SHM mode) ===
echo -e "${YELLOW}[3/4] Starting price feeders (SHM mode)...${NC}"

# Kraken: BTC/ETH/LCX → 0x140000
python3 "$SCRIPT_DIR/kraken_feeder.py" \
    --shm "$SHM_FILE" \
    --interval "$INTERVAL_MS" \
    > /tmp/omnibus_live_kraken.log 2>&1 &
FEEDER_PID=$!
echo -e "${GREEN}  ✓ Kraken feeder PID: $FEEDER_PID (→ 0x140000)${NC}"

# Coinbase: BTC/ETH/LCX → 0x141000
python3 "$SCRIPT_DIR/coinbase_feeder.py" \
    --shm "$SHM_FILE" \
    --interval "$INTERVAL_MS" \
    > /tmp/omnibus_live_coinbase.log 2>&1 &
CB_PID=$!
echo -e "${GREEN}  ✓ Coinbase feeder PID: $CB_PID (→ 0x141000)${NC}"

# LCX Exchange: BTC/ETH/LCX → 0x142000
python3 "$SCRIPT_DIR/lcx_feeder.py" \
    --shm "$SHM_FILE" \
    --interval "$INTERVAL_MS" \
    > /tmp/omnibus_live_lcx.log 2>&1 &
LCX_PID=$!
echo -e "${GREEN}  ✓ LCX feeder PID: $LCX_PID (→ 0x142000)${NC}"

# Wait for first price writes (check Kraken which is fastest)
echo "  Waiting for first prices..."
for i in $(seq 1 12); do
    sleep 0.5
    if [ -f /tmp/omnibus_kraken_buffer.bin ]; then
        BTC_HEX=$(xxd -p /tmp/omnibus_kraken_buffer.bin 2>/dev/null | tr -d '\n' | cut -c17-32)
        BTC_CENTS=$(printf '%d\n' "0x$(echo $BTC_HEX | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\8\7\6\5\4\3\2\1/')" 2>/dev/null || echo 0)
        if [ "$BTC_CENTS" -gt 0 ] 2>/dev/null; then
            BTC_USD=$(echo "scale=2; $BTC_CENTS / 100" | bc 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓ Live BTC=\$$BTC_USD (Kraken)${NC}"
            break
        fi
    fi
done

# Update cleanup to kill all feeders
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    for pid in "$FEEDER_PID" "$CB_PID" "$LCX_PID"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
    wait "$FEEDER_PID" "$CB_PID" "$LCX_PID" 2>/dev/null || true
    rm -f "$SHM_FILE"
    echo -e "${GREEN}✓ Stopped cleanly${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT
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
echo "  Kraken log:  /tmp/omnibus_live_kraken.log  (→ 0x140000)"
echo "  Coinbase log: /tmp/omnibus_live_coinbase.log (→ 0x141000)"
echo "  LCX log:     /tmp/omnibus_live_lcx.log     (→ 0x142000)"
echo "  Dashboard:   python3 dashboard_3pane.py --shm $SHM_FILE"
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
FEEDER_CYCLES=$(grep -c "Cycle\|cycle" /tmp/omnibus_live_kraken.log 2>/dev/null || echo "0")
LAST_PRICE=$(grep -o "BTC=\$[0-9.]*" /tmp/omnibus_live_kraken.log 2>/dev/null | tail -1 || echo "N/A")
echo "  Feeder cycles: $FEEDER_CYCLES"
echo "  Last price:    $LAST_PRICE"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
