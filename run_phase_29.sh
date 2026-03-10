#!/bin/bash
# Phase 29: HTMX Dashboard - Quick Start Script

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "╔════════════════════════════════════════════════════════╗"
echo "║       Phase 29: HTMX Dashboard - Quick Start           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 not found. Install Python 3.8+"
    exit 1
fi

echo "[1/4] Checking dependencies..."
if ! python3 -c "import flask; import flask_socketio" 2>/dev/null; then
    echo "[!] Installing requirements..."
    pip install -r requirements.txt
else
    echo "✓ Dependencies OK"
fi

echo ""
echo "[2/4] Verifying file structure..."
files=(
    "dashboard_5pane.py"
    "shm_reader.py"
    "templates/base.html"
    "templates/trading_panel.html"
    "templates/compliance_panel.html"
    "templates/health_panel.html"
    "templates/audit_panel.html"
    "templates/neuro_panel.html"
    "static/kernel-bridge.js"
    "static/style.css"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ MISSING: $file"
        exit 1
    fi
done

echo ""
echo "[3/4] Testing Flask syntax..."
python3 -m py_compile dashboard_5pane.py && echo "✓ Python syntax OK"

echo ""
echo "[4/4] Starting OmniBus Phase 29 Dashboard..."
echo ""
echo "Usage options:"
echo "  1. With QEMU SHM (recommended):"
echo "     python3 dashboard_5pane.py --shm /tmp/omnibus_live_mem"
echo ""
echo "  2. With direct /dev/mem access (root required):"
echo "     sudo python3 dashboard_5pane.py --devmem"
echo ""
echo "  3. Demo mode (no kernel):"
echo "     python3 dashboard_5pane.py"
echo ""
echo "Default: Starting in demo mode on port 8080"
echo ""
echo "Open browser: http://localhost:8080"
echo "Stop dashboard: Press Ctrl+C"
echo ""

# Parse command-line arguments
MODE="demo"
SHM_FILE=""
PORT=8080

while [[ $# -gt 0 ]]; do
    case $1 in
        --shm)
            MODE="shm"
            SHM_FILE="$2"
            shift 2
            ;;
        --devmem)
            MODE="devmem"
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --shm FILE       Use QEMU shared memory file"
            echo "  --devmem         Use /dev/mem (requires root)"
            echo "  --port PORT      Listen port (default 8080)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Start dashboard
if [ "$MODE" = "shm" ] && [ -n "$SHM_FILE" ]; then
    echo "Starting in SHM mode with file: $SHM_FILE"
    python3 dashboard_5pane.py --shm "$SHM_FILE" --port "$PORT"
elif [ "$MODE" = "devmem" ]; then
    echo "Starting in /dev/mem mode (requires root)"
    sudo python3 dashboard_5pane.py --devmem --port "$PORT"
else
    echo "Starting in demo mode"
    python3 dashboard_5pane.py --port "$PORT"
fi
