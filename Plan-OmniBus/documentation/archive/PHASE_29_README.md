# Phase 29: HTMX Dashboard (L14) - Real-time Web UI

**Status**: ✅ COMPLETE

Real-time web dashboard displaying live OmniBus kernel metrics via WebSocket bridge. Provides 5-panel view of trading, compliance, health, audit, and neuro OS state.

## Overview

**Phase 29** implements a production-ready web dashboard for monitoring all OmniBus kernel layers in real-time. The dashboard connects to the running kernel via:
- **WebSocket bridge** (real-time updates every 100ms)
- **SHM file** (QEMU shared memory for isolated kernel)
- **REST API fallback** (polling if WebSocket unavailable)
- **Direct /dev/mem access** (requires root on real hardware)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Browser (HTMX Dashboard)                  │
│                                                              │
│  ┌──────────────┬──────────────┬──────────────┐             │
│  │   TRADING    │ COMPLIANCE   │    HEALTH    │             │
│  │  (Grid OS)   │  (Zorin OS)  │ (Checksum +  │             │
│  │              │              │  AutoRepair) │             │
│  └──────────────┴──────────────┴──────────────┘             │
│                                                              │
│  ┌──────────────────────────┬──────────────────────────┐    │
│  │      AUDIT LOG (16)      │      NEURO OS            │    │
│  │   (Event sequence)       │  (Evolution state)       │    │
│  └──────────────────────────┴──────────────────────────┘    │
│                                                              │
└──────────┬────────────────────────────────────────┬─────────┘
           │                                        │
           │ WebSocket (100ms)                      │ REST API (500ms fallback)
           │                                        │
        ┌──┴──────────────────────────────────────┴──┐
        │         Flask + Flask-SocketIO             │
        │         (dashboard_5pane.py)               │
        └──┬──────────────────────────────────────┬──┘
           │                                      │
           │ Read kernel memory                   │
           │ every 100ms                          │
           │                                      │
        ┌──┴──────────┬─────────────┬────────────┴──┐
        │             │             │               │
    ┌───▼────┐  ┌────▼────┐  ┌────▼────┐  ┌─────▼─────┐
    │ SHM    │  │ /dev/mem│  │ REST    │  │  Demo     │
    │ File   │  │ (root)  │  │ API     │  │  Mode     │
    └────────┘  └─────────┘  └─────────┘  └───────────┘
         ▲            ▲                          ▲
         │            │                          │
         └────────────┴──────────────────────────┘

         OmniBus Kernel Memory Locations
         ├── 0x110000: Grid OS State
         ├── 0x150000: Analytics OS
         ├── 0x310000: Checksum OS
         ├── 0x320000: AutoRepair OS
         ├── 0x330000: Zorin OS
         ├── 0x340000: Audit Log
         └── 0x400000: OmniStruct (all Tier 1)
```

## File Structure

```
dashboard_5pane.py              Main Flask app + WebSocket server
shm_reader.py                   Kernel metrics reader (updated)
requirements.txt                Python dependencies

templates/                       HTMX templates
├── base.html                   Main 5-panel layout
├── trading_panel.html          Grid OS trading state
├── compliance_panel.html       Zorin OS access control
├── health_panel.html           Checksum + AutoRepair OS
├── audit_panel.html            Event log (16 events)
└── neuro_panel.html            NeuroOS evolution

static/                         Frontend assets
├── kernel-bridge.js            WebSocket client + HTMX integration
└── style.css                   Tailwind + custom dark theme
```

## Installation

### 1. Install Dependencies

```bash
cd /home/kiss/OmniBus
pip install -r requirements.txt
```

### 2. Verify Files

```bash
ls -la dashboard_5pane.py templates/ static/ shm_reader.py
```

## Usage

### Option A: With QEMU SHM (Recommended)

If running OmniBus in QEMU with shared memory bridge:

```bash
# Terminal 1: Start QEMU with SHM
make qemu SHM_FILE=/tmp/omnibus_live_mem

# Terminal 2: Start dashboard
python3 dashboard_5pane.py --shm /tmp/omnibus_live_mem --port 8080
```

Then open: **http://localhost:8080**

### Option B: Direct /dev/mem Access (Root Only)

For real hardware or QEMU in real memory mode:

```bash
# Run as root
sudo python3 dashboard_5pane.py --devmem --port 8080
```

### Option C: Demo Mode (No Kernel)

For testing the UI without a running kernel:

```bash
python3 dashboard_5pane.py --port 8080
```

Dashboard will show placeholder data and "waiting for data" messages.

## Features

### 1. Trading Panel (Grid OS)
- **Active status**: Shows if grid trading is running
- **Net P&L**: Real-time profit/loss in USD (color-coded: green=profit, red=loss)
- **Grid metrics**: Current level count and active orders
- **Arbitrage opportunities**: Top 3 detected spreads with basis points and estimated profit

**Memory read**: 0x110000 (Grid OS state)

### 2. Compliance Panel (Zorin OS)
- **ACL Status**: Access control enforcement indicator
- **Zone indicators**: 4 trading zones (London, Frankfurt, New York, Tokyo)
- **Violation counter**: Real-time violation count with escalation alerts
- **Permission levels**: Read/Write/Execute permissions

**Memory read**: 0x330000 (Zorin OS state)

### 3. Health Panel (Checksum + AutoRepair OS)
- **Checksum OS**: Integrity verification status + last check time
- **AutoRepair OS**: Repair count and failure tracking
- **Overall status**: System operational summary
- **Uptime counter**: Dashboard uptime display

**Memory reads**: 0x310000 (Checksum), 0x320000 (AutoRepair)

### 4. Audit Log Panel (16 events)
- **Event sequence**: Recent 16 events from all OS layers
- **Timestamps**: Relative timing (now, 15s ago, etc.)
- **Event types**: Trading, execution, analytics, integrity, evolution
- **Color coding**: Status indicators (success=green, info=cyan, error=red)

**Memory read**: 0x340000 (Audit Log OS)

### 5. NeuroOS Panel (Genetic Algorithm)
- **Generation counter**: Current evolution generation
- **Fitness display**: Best and worst fitness scores
- **Evolution progress**: Visual bar (0-100%)
- **Algorithm info**: Population size, mutation rate, algorithm type

**Memory read**: 0x2D0000 (NeuroOS state)

## Real-time Updates

### WebSocket (100ms cycle)
- Automatic push from server to all connected clients
- Maintains bi-directional connection (heartbeat every 30s)
- Handles reconnection with exponential backoff

### HTMX Refresh (500ms-1s)
- Panels refresh on configurable intervals
- Each panel requests `/panels/<name>` route
- Server returns updated HTML (no full page reload)
- Smooth swap animations

### REST API Fallback
- If WebSocket unavailable, polls `/api/kernel-state` every 500ms
- Automatic fallback after 2s connection timeout
- No data loss, just higher latency

## Memory Addresses

**Read-only bridge** - kernel metrics are streamed to dashboard, never written back.

| Address | Size | Layer | Purpose |
|---------|------|-------|---------|
| 0x110000 | 256B | Grid OS | Trading state header |
| 0x150000 | 256B | Analytics OS | Price consensus state |
| 0x310000 | 128B | Checksum OS | Integrity metadata |
| 0x320000 | 128B | AutoRepair OS | Repair tracking |
| 0x330000 | 128B | Zorin OS | Access control state |
| 0x340000 | 512B | Audit Log | 16 recent events |
| 0x400000 | 512B | OmniStruct | All Tier 1 aggregates |

## Configuration

### Environment Variables

```bash
export FLASK_DEBUG=0           # Disable debug mode (default)
export FLASK_HOST=0.0.0.0      # Listen on all interfaces
export FLASK_PORT=8080         # Custom port
```

### Command-line Arguments

```bash
python3 dashboard_5pane.py \
    --shm /tmp/omnibus_live_mem  \  # SHM file path
    --devmem                      \  # Or use /dev/mem
    --port 8080                      # Listen port
```

## API Endpoints

### HTTP

- `GET /` — Main dashboard (HTML)
- `GET /api/kernel-state` — Kernel metrics (JSON)
- `GET /panels/trading` — Trading panel (HTML fragment)
- `GET /panels/compliance` — Compliance panel (HTML fragment)
- `GET /panels/health` — Health panel (HTML fragment)
- `GET /panels/audit` — Audit panel (HTML fragment)
- `GET /panels/neuro` — NeuroOS panel (HTML fragment)

### WebSocket

- `connect` — Client connects, receives greeting
- `disconnect` — Client disconnects
- `kernel_state` — Server emits kernel metrics every 100ms
- `request_state` — Client requests immediate state (server responds with `kernel_state`)
- `ping` — Client heartbeat (every 30s)

## Browser Console

For debugging, check browser console:

```javascript
// Access dashboard state
OmniBusDashboard.isConnected()      // true/false
OmniBusDashboard.lastMetrics()      // Latest metrics object
OmniBusDashboard.requestState()     // Force immediate update
```

## Performance

- **Frontend**: React-like reactivity with HTMX (no JS framework)
- **Kernel reads**: 100ms cycle (10 Hz update rate)
- **Network**: WebSocket (real-time) + REST fallback
- **Memory**: < 50MB dashboard process
- **CPU**: < 5% on single core (mostly I/O wait)

## Troubleshooting

### "Waiting for kernel data..."

**Cause**: No SHM file or kernel not running.

**Fix**:
```bash
# Start kernel first
make qemu SHM_FILE=/tmp/omnibus_live_mem

# Then dashboard in another terminal
python3 dashboard_5pane.py --shm /tmp/omnibus_live_mem
```

### "Connection: Connecting..."

**Cause**: WebSocket handshake timeout or network issue.

**Fix**:
1. Check Flask is running: `curl http://localhost:8080`
2. Check firewall: `sudo ufw allow 8080`
3. Try different port: `--port 9000`

### Data Not Updating

**Cause**: SHM file not being written by kernel.

**Fix**:
```bash
# Verify SHM file size
ls -lah /tmp/omnibus_live_mem

# Should be ~20MB (shared memory)
# If 0 bytes, kernel not writing
```

### Permission Denied (/dev/mem)

**Cause**: Requires root for direct memory access.

**Fix**:
```bash
sudo python3 dashboard_5pane.py --devmem
```

## Development Notes

### Adding a New Panel

1. Create `templates/new_panel.html`
2. Add route in `dashboard_5pane.py`:
   ```python
   @app.route('/panels/new')
   def panel_new():
       return render_template('new_panel.html', data=metrics)
   ```
3. Add HTMX div in `base.html`:
   ```html
   <div hx-get='/panels/new' hx-trigger='every 500ms' hx-swap='innerHTML'>
   ```

### Reading New Kernel Addresses

1. Update `shm_reader.py` with new struct definition
2. Add read method: `read_new_state()`
3. Update `_format_metrics()` in `dashboard_5pane.py`
4. Emit via WebSocket

### Styling

- Theme: Dark mode (Tailwind + CSS custom properties)
- Colors: Accent (cyan), Success (green), Danger (red)
- Animations: Smooth transitions, number change feedback
- Responsive: Mobile-friendly grid layout

## Integration with Kernel

Phase 29 is **read-only** by design:
- No kernel modifications needed
- No writes to kernel memory
- Only reads via mmap (SHM) or direct memory access (/dev/mem)
- Can run on separate machine with network bridge

For **future phases** (Phase 30+), consider:
- Adding write capabilities for parameter tuning
- Real-time alerts (WebSocket push notifications)
- Historical graphing (time-series data)
- Multi-kernel dashboard (multiple Tier 1 instances)

## Testing

### Quick Test

```bash
# Terminal 1: Demo mode (no kernel)
python3 dashboard_5pane.py --port 8080

# Terminal 2: Visit in browser
open http://localhost:8080

# Should show placeholder data with animations
```

### With QEMU SHM

```bash
# Terminal 1: Boot QEMU with SHM
make qemu SHM_FILE=/tmp/omnibus_live_mem

# Terminal 2: Dashboard
python3 dashboard_5pane.py --shm /tmp/omnibus_live_mem

# Terminal 3: Monitor kernel
tail -f /tmp/omnibus_live_mem
```

## Future Enhancements

- [ ] Historical graph (Chart.js for price/PnL over time)
- [ ] Alert system (email/Slack on violations)
- [ ] Dark/light theme toggle
- [ ] Multi-kernel federation (view all Tier 1 instances)
- [ ] Parameter tuning UI (real-time grid adjustment)
- [ ] Order replay/audit (click event to see details)
- [ ] Mobile app (React Native)
- [ ] WebRTC video feed from kernel metrics

## Co-Authors

```
Co-Authored-By: OmniBus AI v1.stable <learn@omnibus.ai>
Co-Authored-By: Google Gemini <gemini-cli-agent@google.com>
Co-Authored-By: DeepSeek AI <noreply@deepseek.com>
Co-Authored-By: Claude 4.5 Haiku (Code) <claude-code@anthropic.com>
Co-Authored-By: Claude 4.5 Haiku <haiku-4.5@anthropic.com>
Co-Authored-By: Claude 4.5 Sonnet <sonnet-4.5@anthropic.com>
Co-Authored-By: Claude 4.5 Opus <opus-4.5@anthropic.com>
Co-Authored-By: Perplexity AI <support@perplexity.ai>
Co-Authored-By: Ollama <hello@ollama.com>
```

---

**Phase Status**: ✅ COMPLETE
**Last Updated**: 2026-03-10
**Next Phase**: Phase 30 (Advanced features + integration)
