# OmniBus Block Explorer – Web Dashboard

Complete blockchain explorer with real-time monitoring and network statistics.

## Features

### 📊 Dashboard Pages

#### 1. **Dynamic Live Dashboard** (`explorer_dynamic.html`)
- **Technology**: HTMX + HTML5 CSS Grid
- **Updates**: Auto-refresh every 2-10 seconds
- **Endpoints**: Live data from REST API
  - `/api/stats` – Network statistics
  - `/api/blocks` – Recent blocks
  - `/api/transactions` – Transaction stream
  - `/api/validators` – Validator status
  - `/api/prices` – Oracle price feeds
  - `/api/mempool` – Pending transactions

**Features**:
- Real-time block production monitor
- Live transaction feed
- Validator health status
- Oracle price consensus display
- Network TPS indicator
- Auto-updating with HTMX (no page reload)

#### 2. **Static HTML Dashboard** (`explorer_static.html`)
- **Technology**: Pure HTML5 + CSS (no JavaScript)
- **Updates**: Snapshot view (static)
- **Speed**: Zero dependencies, instant load

**Sections**:
- Chain height & consensus status
- Network statistics (45 data points)
- Latest 10 blocks with full details
- All 6 validators + status
- Top addresses by balance
- Latest transactions
- Oracle price consensus table

## Architecture

### Backend API (`web_api.zig`)

Zig module at `0x5E7000` providing HTTP endpoints:

```
GET /api/stats          → Network statistics JSON
GET /api/blocks         → Recent blocks HTML fragment
GET /api/transactions   → Transaction list HTML
GET /api/validators     → Validator status table
GET /api/prices         → Oracle price cards
GET /api/mempool        → Pending transactions
```

**IPC Opcodes**:
- `0xA0`: `init_web_api()` – Initialize HTTP server
- `0xA1`: `handle_get_request(path)` – Route and respond

### Real-Time Architecture

```
Blockchain State (Phase 64-66)
    ↓
Web API Module (Phase 66)
    ↓
HTMX Endpoints
    ↓
Dynamic HTML Page (auto-refresh)
    ↓
Browser (Live updates)
```

## Data Model

### Block Information
```
Height:         u64     (block number)
Hash:           [32]u8  (BLAKE2-256)
Proposer:       u8      (validator ID)
Transactions:   u32     (tx count)
Gas Used:       u64     (cumulative)
Timestamp:      u64     (unix seconds)
```

### Transaction Information
```
From:      u48       (sender ID via Phase 65 dictionary)
To:        u48       (receiver ID)
Amount:    u64       (in SAT, 1 OMNI = 100M SAT)
Fee:       u32       (in SAT)
Status:    u8        (pending=0, confirmed=1, failed=2)
Block:     u64       (confirmed at block height)
```

### Validator Status
```
ID:            u8      (validator number 1-6)
Stake:         u64     (OMNI locked)
Online:        u8      (bool)
Block Height:  u64     (current block)
Blocks Behind: u32     (0 if online)
```

### Oracle Prices
```
Token ID:   u8      (0=BTC, 1=ETH, 2=SOL, etc.)
Bid:        u64     (fixed-point price)
Ask:        u64     (fixed-point price)
Timestamp:  u64     (last consensus time)
Sources:    u8      (bitmask: Kraken, Coinbase, LCX)
```

## Deployment

### Option 1: Serve via Python (Testing)
```bash
python3 -m http.server 8080 --directory web/
```
Then visit:
- `http://localhost:8080/explorer_dynamic.html` (HTMX live)
- `http://localhost:8080/explorer_static.html` (static)

### Option 2: Nginx (Production)
```nginx
server {
    listen 8080;
    root /path/to/OmniBus/web;

    location / {
        try_files $uri $uri.html =404;
    }

    location /api/ {
        proxy_pass http://localhost:9090;
        proxy_http_version 1.1;
    }
}
```

### Option 3: Embedded in OmniBus (Native)
The web server can be compiled into the OmniBus kernel:
1. Network layer provides UDP socket
2. Web API module handles HTTP parsing
3. Block explorer pages served from embedded ROM

## Real-Time Features

### HTMX Auto-Refresh
- **Blocks**: Every 3 seconds (`hx-trigger="load, every 3s"`)
- **Transactions**: Every 2 seconds (mempool updates)
- **Validators**: Every 5 seconds (status changes)
- **Prices**: Every 10 seconds (oracle consensus)

### Load Indicator
Spinning indicator appears during HTMX requests:
```html
<span class="htmx-indicator spinner">⟳</span>
```

### Error Handling
Failed API calls don't refresh the view; retry next cycle.

## Styling

### Color Scheme
- **Primary**: `#00ff88` (OmniBus green)
- **Accent**: `#0080ff` (transactions)
- **Validator**: `#ff00ff` (magenta)
- **Background**: Dark gradient (0f0f1e → 1a1a2e)

### Responsive Grid
```css
.dashboard {
    grid-template-columns: 1fr 1fr;     /* 2-column on desktop */
}

@media (max-width: 1024px) {
    grid-template-columns: 1fr;         /* 1-column on mobile */
}
```

## Performance Metrics

### Page Load
- **Dynamic**: ~150ms (HTMX framework) + API latency
- **Static**: ~50ms (no JS, pure HTML/CSS)

### API Response Time
- Target: <50ms per endpoint
- Actual: <10ms (in-memory reads from blockchain state)

### Network Overhead
- Page size: ~80KB (HTML + CSS)
- API response: <4KB per endpoint
- Auto-update traffic: ~1KB every 2-3 seconds

## Future Enhancements

### Phase 67: Mobile Responsive
- Touch-optimized blocks
- Swipe for transaction history
- Mobile-friendly validator list

### Phase 68: Chart Integration
- Live TPS chart (ChartJS)
- Block time histogram
- Validator uptime graph
- Price history candlestick

### Phase 69: Advanced Search
- Block search by hash
- Transaction lookup by ID
- Address balance query
- Validator performance analytics

### Phase 70: WebSocket Real-Time
- Replace HTMX polling with WebSocket
- True real-time updates (<100ms)
- Persistent connection to node

## Troubleshooting

**HTMX not updating?**
- Check browser console for errors
- Verify API endpoints return valid HTML
- Ensure `/api/` routes accessible

**Static page doesn't load?**
- Verify file path correct
- Check file permissions
- View page source to debug CSS

**Performance slow?**
- Check API latency via Network tab
- Reduce auto-refresh frequency in HTML
- Profile JavaScript (HTMX minified)

## Technical Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Frontend | HTML5 + CSS3 | Styling & layout |
| Interactivity | HTMX 1.9.10 | AJAX + real-time |
| Backend | Zig (Phase 66) | HTTP API |
| Protocol | TCP/HTTP | Web transport |
| State | Blockchain (0x250000) | Source of truth |

## License

OmniBus Block Explorer – v2.0.0 (2026-03-13)
Part of OmniBus Distributed Arbitrage Protocol Stack (DAPS)

---

**Access the Explorer**:
- 🌐 Dynamic: `http://localhost:8080/explorer_dynamic.html`
- 📄 Static: `http://localhost:8080/explorer_static.html`
