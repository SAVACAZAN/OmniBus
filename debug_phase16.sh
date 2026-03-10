#!/bin/bash
###############################################################################
# Phase 16 Debugging: Module Execution Blocker (GDB Investigation)
#
# This script:
#   1. Starts QEMU with GDB stub
#   2. Connects GDB and inspects state before module call
#   3. Collects diagnostic info (GDT, paging, IDT, EFLAGS)
#   4. Attempts to step through the call
#   5. Reports findings
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 16: Module Execution Debug (GDB Investigation)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Build if needed
echo -e "${YELLOW}[1/4] Building OmniBus...${NC}"
if ! [ -f build/omnibus.iso ]; then
    make build >/dev/null 2>&1
fi
echo -e "${GREEN}✓ Built${NC}"
echo ""

# Step 2: Start QEMU with GDB stub in background
echo -e "${YELLOW}[2/4] Starting QEMU with GDB stub (port 1234)...${NC}"
timeout 30 qemu-system-x86_64 -m 256 \
    -drive format=raw,file=./build/omnibus.iso \
    -serial mon:stdio \
    -gdb tcp::1234,server,wait \
    &
QEMU_PID=$!
echo -e "${GREEN}✓ QEMU PID: $QEMU_PID${NC}"

# Give QEMU time to start
sleep 2

# Step 3: Create GDB script for diagnosis
echo -e "${YELLOW}[3/4] Creating GDB diagnostic script...${NC}"

cat > /tmp/phase16_debug.gdb <<'EOF'
set architecture i386:x86-64
target remote localhost:1234

# Let system boot to stable state (wait ~5 seconds)
set pagination off
set logging on
set logging file /tmp/phase16_debug.log

# Try to add symbols
add-symbol-file build/kernel.elf 0x100000 2>/dev/null || true
add-symbol-file build/blockchain_os.elf 0x250000 2>/dev/null || true

# Give it time to boot
shell sleep 5

# Interrupt the running system
interrupt

# Print state
printf "=== CPU STATE ===\n"
info registers
printf "\n=== CODE SEGMENTS ===\n"
print/x $cs
print/x $ss
print/x $ds

printf "\n=== PAGING ===\n"
print/x $cr0
print/x $cr3

printf "\n=== EFLAGS ===\n"
print/x $eflags

printf "\n=== GDT CHECK ===\n"
x/4gx 0x100110

printf "\n=== MODULE MEMORY @ 0x250000 ===\n"
x/8i 0x250000

printf "\n=== STACK ===\n"
print/x $rsp
x/8gx $rsp

printf "\n=== PAGE TABLES ===\n"
print/x *(unsigned long*)0x201000
print/x *(unsigned long*)0x202000
print/x *(unsigned long*)0x203008

# Try simple test: read from module
printf "\n=== TEST: Read from 0x250000 ===\n"
x/8x 0x250000

# Attempt: Set breakpoint near call, then step
printf "\n=== ATTEMPTING MODULE CALL ===\n"
printf "This may cause restart. Watching...\n"

# Don't actually call - just report state
quit
EOF

# Step 4: Run GDB with diagnostic script
echo -e "${YELLOW}[4/4] Running GDB diagnostics...${NC}"
gdb -x /tmp/phase16_debug.gdb 2>&1 | tee /tmp/phase16_output.log || true

# Kill QEMU
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    DEBUG RESULTS                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Analyze results
if grep -q "RIP" /tmp/phase16_output.log 2>/dev/null; then
    echo -e "${GREEN}✓ GDB connected successfully${NC}"
    grep "RIP\|CS\|CR0\|EFLAGS" /tmp/phase16_output.log | head -10
else
    echo -e "${YELLOW}⚠ GDB connection issues - check QEMU/GDB setup${NC}"
fi

echo ""
echo -e "${YELLOW}Full output saved to:${NC}"
echo "  GDB log: /tmp/phase16_debug.log"
echo "  GDB output: /tmp/phase16_output.log"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review GDB output for CPU state (CS, CR0, EFLAGS)"
echo "2. Check if module memory is readable"
echo "3. Verify GDT and paging setup"
echo "4. Try direct call in controlled GDB environment"
