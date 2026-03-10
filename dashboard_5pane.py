#!/usr/bin/env python3
"""
Phase 29: HTMX Dashboard (L14) - Real-time Web UI with WebSocket Kernel Memory Bridge
======================================================================================

Real-time web dashboard displaying live OmniBus kernel metrics via WebSocket bridge.

Features:
- 5-panel layout: TRADING | COMPLIANCE | HEALTH | AUDIT | NEURO
- WebSocket bridge reading /dev/mem or SHM file
- HTMX auto-refresh every 500ms
- Real-time animations for price/PnL updates
- Color-coded violation alerts

Usage:
    python3 dashboard_5pane.py [--shm SHM_FILE] [--port PORT] [--devmem]

    --shm SHM_FILE       : Use QEMU shared memory file (e.g. /tmp/omnibus_live_mem)
    --devmem             : Use /dev/mem for live kernel access (requires root)
    --port PORT          : Listen on port (default 8080)

Requirements:
    pip install flask flask-socketio python-socketio python-engineio
"""

import argparse
import ctypes
import json
import mmap
import os
import struct
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime
from threading import Event, Lock, Thread

from flask import Flask, jsonify, render_template, request
from flask_socketio import SocketIO, emit

# Import kernel metrics reader
try:
    from shm_reader import KernelMetrics, ShmMetricsReader
except ImportError:
    KernelMetrics = None
    ShmMetricsReader = None

# ===== Configuration =====
DEFAULT_PORT = 8080
KERNEL_REFRESH_MS = 100  # Emit kernel state every 100ms

# Memory addresses for direct /dev/mem access
OMNISTRUCT_ADDR = 0x400000      # All Tier 1 aggregates (512 bytes)
GRID_STATE_ADDR = 0x110000      # Grid OS state (256 bytes)
ANALYTICS_STATE_ADDR = 0x150000 # Analytics OS state (256 bytes)
CHECKSUM_STATE_ADDR = 0x310000  # Checksum OS state (128 bytes)
AUTOREPAIR_STATE_ADDR = 0x320000  # AutoRepair OS state (128 bytes)
ZORIN_STATE_ADDR = 0x330000     # Zorin OS access control (128 bytes)
AUDIT_LOG_ADDR = 0x340000       # Audit Log OS (header + events)

# ===== Flask Setup =====
app = Flask(__name__, template_folder='templates', static_folder='static')
app.config['SECRET_KEY'] = 'omnibus-phase-29-phase-29'
socketio = SocketIO(app, cors_allowed_origins="*", engineio_logger=False, logger=False)

# Global kernel metrics
_kernel_metrics = None
_kernel_lock = Lock()
_kernel_reader = None  # ShmMetricsReader or DevMemReader
_reader_mode = "shm"  # "shm" or "devmem"
_shutdown = Event()


# ===== DevMemReader (for direct /dev/mem access) =====
class DevMemReader:
    """Read OmniBus kernel state from /dev/mem (requires root)"""

    def __init__(self):
        self.fd = None
        self.mm = None
        self._open()

    def _open(self):
        """Open /dev/mem"""
        try:
            self.fd = open('/dev/mem', 'rb', buffering=0)
            # Don't mmap entire /dev/mem; seek + read instead
            return True
        except Exception as e:
            print(f"ERROR: Cannot open /dev/mem: {e}")
            return False

    def _read_bytes(self, addr, size) -> bytes:
        """Read bytes from physical address"""
        try:
            if self.fd is None:
                return b''
            self.fd.seek(addr)
            return self.fd.read(size)
        except Exception:
            return b''

    def read(self):
        """Return minimal kernel metrics (non-SHM format)"""
        if not self.fd:
            return {'timestamp': time.time(), 'source': 'devmem', 'valid': False}

        result = {
            'timestamp': time.time(),
            'source': 'devmem',
            'valid': True,
            'grid': self._read_grid(),
            'analytics': self._read_analytics(),
            'checksum': self._read_checksum(),
            'autorepair': self._read_autorepair(),
            'zorin': self._read_zorin(),
            'audit': self._read_audit(),
        }
        return result

    def _read_grid(self):
        """Read Grid OS state @ 0x110000"""
        data = self._read_bytes(GRID_STATE_ADDR, 256)
        if len(data) < 64:
            return {}
        try:
            # GridState: magic(4)+pair(2)+flags(1)+pad(1)+lower(8)+upper(8)+step(8)+profit(8)+tsc(8)+levels(4)+orders(4)+pad(8)
            fields = struct.unpack('<IHBBQQQQQII8s', data[:64])
            return {
                'magic': hex(fields[0]),
                'active': bool(fields[2] & 0x01),
                'profit_usd': fields[7] / 100.0,
                'levels': fields[9],
                'orders': fields[10],
            }
        except:
            return {}

    def _read_analytics(self):
        """Read Analytics OS state @ 0x150000"""
        data = self._read_bytes(ANALYTICS_STATE_ADDR, 256)
        if len(data) < 32:
            return {}
        return {'status': 'unknown'}  # Placeholder

    def _read_checksum(self):
        """Read Checksum OS state @ 0x310000"""
        data = self._read_bytes(CHECKSUM_STATE_ADDR, 128)
        if len(data) < 32:
            return {}
        return {'status': 'unknown'}  # Placeholder

    def _read_autorepair(self):
        """Read AutoRepair OS state @ 0x320000"""
        data = self._read_bytes(AUTOREPAIR_STATE_ADDR, 128)
        if len(data) < 32:
            return {}
        return {'status': 'unknown'}  # Placeholder

    def _read_zorin(self):
        """Read Zorin OS access control @ 0x330000"""
        data = self._read_bytes(ZORIN_STATE_ADDR, 128)
        if len(data) < 32:
            return {}
        return {'zones': 4, 'violations': 0}  # Placeholder

    def _read_audit(self):
        """Read Audit Log OS @ 0x340000"""
        data = self._read_bytes(AUDIT_LOG_ADDR, 512)
        if len(data) < 32:
            return {}
        return {'events': []}  # Placeholder

    def close(self):
        if self.fd:
            self.fd.close()


# ===== Kernel Reader Thread =====
def kernel_reader_worker():
    """Background thread that reads kernel state every KERNEL_REFRESH_MS"""
    global _kernel_reader, _kernel_metrics

    while not _shutdown.is_set():
        try:
            if _kernel_reader is None:
                time.sleep(0.1)
                continue

            # Read from appropriate source
            if isinstance(_kernel_reader, ShmMetricsReader):
                metrics = _kernel_reader.read()
            else:  # DevMemReader
                metrics = _kernel_reader.read()

            with _kernel_lock:
                _kernel_metrics = metrics

            # Emit via WebSocket
            try:
                socketio.emit('kernel_state', _format_metrics(metrics), namespace='/')
            except:
                pass

            time.sleep(KERNEL_REFRESH_MS / 1000.0)
        except Exception as e:
            print(f"ERROR in kernel reader: {e}")
            time.sleep(0.5)


def _format_metrics(metrics):
    """Convert metrics to JSON-serializable dict"""
    if isinstance(metrics, KernelMetrics):
        # SHM format
        return {
            'timestamp': time.time(),
            'source': 'shm',
            'grid': {
                'valid': metrics.grid_state.valid,
                'active': metrics.grid_state.active,
                'profit_usd': metrics.grid_state.profit_usd,
                'levels': metrics.grid_state.level_count,
                'orders': metrics.grid_state.order_count,
            },
            'arb_opps': [
                {
                    'pair': ['BTC', 'ETH', 'XRP'][opp.pair_id] if opp.pair_id < 3 else f"P{opp.pair_id}",
                    'buy_ex': opp.buy_exchange,
                    'sell_ex': opp.sell_exchange,
                    'net_bps': opp.net_profit_bps,
                    'profit_usd': opp.profit_usd_per_unit,
                }
                for opp in (metrics.arb_opps[:3] if metrics.arb_opps else [])
            ],
            'exec': {
                'valid': metrics.exec_state.valid,
                'active': metrics.exec_state.active,
                'orders_in': metrics.exec_state.order_in_count,
                'fills_out': metrics.exec_state.fill_out_count,
            },
            'pending_orders': [
                {
                    'exchange': ord.exchange_name,
                    'pair': ord.pair_name,
                    'side': ord.side_name,
                    'qty': ord.quantity_asset,
                    'price': ord.price_usd,
                }
                for ord in (metrics.pending_orders[:4] if metrics.pending_orders else [])
            ],
            'fills': [
                {
                    'order_id': fill.order_id,
                    'pair': fill.pair_name,
                    'status': fill.status_name,
                    'filled': fill.filled_asset,
                    'price': fill.price_usd,
                }
                for fill in (metrics.fill_results[:3] if metrics.fill_results else [])
            ],
            'neuro': {
                'valid': metrics.neuro_state.valid,
                'active': metrics.neuro_state.active,
                'generation': metrics.neuro_state.generation,
                'best_fitness': metrics.neuro_state.best_fitness,
            },
        }
    else:
        # DevMem format (already dict)
        return metrics


# ===== Flask Routes =====
@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('base.html')


@app.route('/api/kernel-state')
def kernel_state_api():
    """REST API for kernel state (for HTTP polling fallback)"""
    global _kernel_metrics
    with _kernel_lock:
        if _kernel_metrics is None:
            return jsonify({'error': 'No kernel data yet'}), 503
        return jsonify(_format_metrics(_kernel_metrics))


@app.route('/panels/trading')
def panel_trading():
    """HTMX trading panel"""
    global _kernel_metrics
    with _kernel_lock:
        metrics = _format_metrics(_kernel_metrics) if _kernel_metrics else {}
    return render_template('trading_panel.html', data=metrics)


@app.route('/panels/compliance')
def panel_compliance():
    """HTMX compliance panel"""
    global _kernel_metrics
    with _kernel_lock:
        metrics = _format_metrics(_kernel_metrics) if _kernel_metrics else {}
    return render_template('compliance_panel.html', data=metrics)


@app.route('/panels/health')
def panel_health():
    """HTMX health panel"""
    global _kernel_metrics
    with _kernel_lock:
        metrics = _format_metrics(_kernel_metrics) if _kernel_metrics else {}
    return render_template('health_panel.html', data=metrics)


@app.route('/panels/audit')
def panel_audit():
    """HTMX audit panel"""
    global _kernel_metrics
    with _kernel_lock:
        metrics = _format_metrics(_kernel_metrics) if _kernel_metrics else {}
    return render_template('audit_panel.html', data=metrics)


@app.route('/panels/neuro')
def panel_neuro():
    """HTMX neuro panel"""
    global _kernel_metrics
    with _kernel_lock:
        metrics = _format_metrics(_kernel_metrics) if _kernel_metrics else {}
    return render_template('neuro_panel.html', data=metrics)


# ===== WebSocket Events =====
@socketio.on('connect', namespace='/')
def on_connect():
    """Client connected"""
    emit('connection', {'status': 'Connected to OmniBus Dashboard', 'mode': _reader_mode})


@socketio.on('disconnect', namespace='/')
def on_disconnect():
    """Client disconnected"""
    pass


@socketio.on('request_state', namespace='/')
def on_request_state():
    """Client requests immediate state update"""
    global _kernel_metrics
    with _kernel_lock:
        if _kernel_metrics:
            emit('kernel_state', _format_metrics(_kernel_metrics))


# ===== Main =====
def main():
    global _kernel_reader, _reader_mode

    parser = argparse.ArgumentParser(
        description='Phase 29: HTMX Dashboard with WebSocket Kernel Memory Bridge'
    )
    parser.add_argument(
        '--shm', default='', metavar='SHM_FILE',
        help='QEMU shared memory file (e.g. /tmp/omnibus_live_mem)'
    )
    parser.add_argument(
        '--devmem', action='store_true',
        help='Use /dev/mem for live kernel access (requires root)'
    )
    parser.add_argument(
        '--port', type=int, default=DEFAULT_PORT,
        help=f'Listen port (default {DEFAULT_PORT})'
    )
    args = parser.parse_args()

    # Initialize kernel reader
    if args.devmem:
        print("[Dashboard] Using /dev/mem for kernel access (requires root)")
        _kernel_reader = DevMemReader()
        _reader_mode = "devmem"
    elif args.shm:
        print(f"[Dashboard] Using SHM file: {args.shm}")
        if ShmMetricsReader is None:
            print("ERROR: Cannot import ShmMetricsReader. Run: pip install -e .")
            sys.exit(1)
        _kernel_reader = ShmMetricsReader(args.shm)
        _reader_mode = "shm"
    else:
        print("[Dashboard] No kernel reader specified. Use --shm <file> or --devmem")
        print("[Dashboard] Running in demo mode (no live data)")
        _reader_mode = "demo"

    # Start kernel reader thread
    if _kernel_reader:
        reader_thread = Thread(target=kernel_reader_worker, daemon=True)
        reader_thread.start()

    # Start Flask app
    print(f"[Dashboard] Starting OmniBus Phase 29 Dashboard on port {args.port}")
    print(f"[Dashboard] Open browser: http://localhost:{args.port}")
    try:
        socketio.run(app, host='0.0.0.0', port=args.port, debug=False)
    except KeyboardInterrupt:
        print("\n[Dashboard] Shutting down...")
        _shutdown.set()
        if _kernel_reader and hasattr(_kernel_reader, 'close'):
            _kernel_reader.close()
        sys.exit(0)


if __name__ == '__main__':
    main()
