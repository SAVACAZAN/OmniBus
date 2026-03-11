#!/bin/bash
# OmniBus QEMU + GDB Debugging Script
# Launches QEMU with GDB stub and detailed interrupt logging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_FILE="${SCRIPT_DIR}/build/omnibus.iso"

if [ ! -f "$ISO_FILE" ]; then
    echo "ERROR: ${ISO_FILE} not found. Run 'make build' first."
    exit 1
fi

echo "=================================================================="
echo "OmniBus Bootloader Debugger"
echo "=================================================================="
echo ""
echo "Starting QEMU with:"
echo "  - GDB stub on localhost:1234"
echo "  - CPU frozen at startup (-S flag)"
echo "  - Interrupt logging enabled"
echo "  - CPU reset tracking enabled"
echo ""
echo "In another terminal, run:"
echo "  $ gdb -x .gdbinit"
echo ""
echo "GDB will auto-load .gdbinit and connect to QEMU."
echo ""
echo "Key debugging commands:"
echo "  (gdb) si          - Step one instruction"
echo "  (gdb) c           - Continue execution"
echo "  (gdb) info regs   - Show all registers"
echo "  (gdb) x/i \$pc    - Disassemble current instruction"
echo ""
echo "=================================================================="
echo ""

# Launch QEMU with:
# -S = freeze CPU at startup (waiting for GDB)
# -s = enable GDB stub on TCP:1234 (shorthand for -gdb tcp::1234)
# -d int,cpu_reset = log interrupts and CPU resets (helps diagnose triple faults)
# -serial stdio = serial port output to terminal
# -m 256 = 256MB RAM
# -drive = boot from ISO
# -monitor none = disable monitor to avoid conflicting with serial

qemu-system-x86_64 \
    -m 256 \
    -S \
    -s \
    -d int,cpu_reset \
    -drive format=raw,file="${ISO_FILE}" \
    -chardev stdio,id=ser0 \
    -device isa-serial,chardev=ser0 \
    -monitor none \
    -nographic

echo ""
echo "QEMU exited."
