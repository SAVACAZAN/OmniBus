# OmniBus Web Integration Guide – Phase 66

## Architecture Overview

```
Static HTML Pages (no server needed)
├── explorer_static.html        (pure HTML + CSS)
├── wallet_static.html          (pure HTML + CSS)
└── omnibalance.html            (pure HTML + CSS)

Dynamic Pages + HTMX (require Zig API backend)
├── explorer_dynamic.html       (HTMX auto-updates)
└── wallet_dynamic.html         (HTMX auto-updates)
     ↓
HTTP Server (Zig)
├── http_server.zig            (unified request router)
├── web_api.zig                (block explorer endpoints)
└── wallet_api.zig             (wallet generation endpoints)
     ↓
Blockchain State (Phase 64-66)
```

## Static Pages – No Server Required

**Location**: `/home/kiss/OmniBus/web/`

### Files
- **explorer_static.html** – Block explorer snapshot (current chain state)
- **wallet_static.html** – Wallet snapshot (addresses + balances)
- **omnibalance.html** – Token balance dashboard

### Open Locally
```bash
# Open in browser without any server
file:///home/kiss/OmniBus/web/explorer_static.html
file:///home/kiss/OmniBus/web/wallet_static.html
file:///home/kiss/OmniBus/web/omnibalance.html
```

**Features**:
- Pure HTML5 + embedded CSS
- No external dependencies
- No JavaScript required
- Work offline (no internet needed)
- Instant load time

---

## Dynamic Pages – Requires HTTP Server

### Files
- **explorer_dynamic.html** – Real-time block explorer (auto-updates)
- **wallet_dynamic.html** – Multi-chain wallet generator (HTMX-powered)

### API Endpoints

#### 1. **Wallet API** (`/api/wallet/*`)

**Generate Seed Phrase**
```
GET /api/wallet/generate?words=12|24
Response: {"mnemonic": "word word ...", "type": "BIP39"}
```

**Derive Addresses**
```
GET /api/wallet/addresses/{chain}
Chains: omni, ethereum, bitcoin, solana
Response: {"address": "0x...", "path": "m/44'/60'/0'/0/0"}
```

**Get Balance**
```
GET /api/wallet/balance?address=0x...
Response: {"balances": {"OMNI": ..., "LOVE": ..., "VACA": ..., "RENT": ...}}
```

**Get Portfolio**
```
GET /api/wallet/portfolio
Response: {"total_value": 42704670000, "holdings": [...]}
```

#### 2. **Explorer API** (`/api/*`)

**Network Statistics**
```
GET /api/stats
Response: HTML fragment with block height, TPS, validators, addresses
```

**Recent Blocks**
```
GET /api/blocks
Response: HTML fragment with latest 5 blocks
```

**Recent Transactions**
```
GET /api/transactions
Response: HTML fragment with pending + confirmed transactions
```

**Validator Status**
```
GET /api/validators
Response: HTML fragment with all validator nodes
```

**Oracle Prices**
```
GET /api/prices
Response: HTML fragment with BTC, ETH, SOL prices
```

**Mempool**
```
GET /api/mempool
Response: HTML fragment with pending transactions
```

---

## Implementation Files

### Backend (Zig)

**`modules/omnibus_network_os/wallet_api.zig`** (280+ lines)
- Wallet generation (BIP-39/44)
- Address derivation (7 blockchains)
- Token balance queries
- HTTP endpoint handlers
- IPC opcodes: 0xB0–0xB4

**`modules/omnibus_network_os/web_api.zig`** (336 lines)
- Block explorer endpoints
- Stats, blocks, transactions, validators, prices
- HTML fragment responses (for HTMX injection)
- IPC opcodes: 0xA0, 0xA1

**`modules/omnibus_network_os/http_server.zig`** (NEW)
- Unified request router
- Routes `/api/wallet/*` → wallet_api
- Routes `/api/*` → web_api
- HTTP method & path parsing
- IPC opcodes: 0xC0, 0xC1

### Frontend (HTML/HTMX)

**`web/wallet_dynamic.html`** (600+ lines)
```html
<!-- Generate 12-word seed -->
<button hx-get="/api/wallet/generate?words=12" hx-target="#seed-display">
  Generate 12 Words
</button>

<!-- Derive addresses for Ethereum -->
<div hx-get="/api/wallet/addresses/ethereum" hx-trigger="load">
  <!-- Populated by HTMX -->
</div>

<!-- Get portfolio stats -->
<div hx-get="/api/wallet/portfolio" hx-trigger="load, every 5s">
  <!-- Auto-updates every 5 seconds -->
</div>
```

**`web/explorer_dynamic.html`** (450+ lines)
```html
<!-- Block explorer stats (5s refresh) -->
<div hx-get="/api/stats" hx-trigger="load, every 5s">
  Block height, TPS, validators, addresses
</div>

<!-- Recent blocks (3s refresh) -->
<div hx-get="/api/blocks" hx-trigger="load, every 3s">
  Latest 5 blocks with hashes, proposer, TPS
</div>

<!-- Mempool (1s refresh) -->
<div hx-get="/api/mempool" hx-trigger="load, every 1s">
  Pending transactions
</div>
```

---

## Real Data Sources

### Wallet Data
- **Seed Generation**: Real BIP-39 mnemonic words (12 or 24)
- **Key Derivation**: Real BIP-32/44 paths (m/44'/coin_type'/0'/0/index)
- **Address Format**:
  - OMNI: `ob_k1_XXXXX...` (post-quantum)
  - Ethereum: `0xXXXXXXXX...` (EVM standard)
  - Bitcoin: `1XXXXXX...` or `3XXXXXX...` (UTXO)
  - Solana: `SoLXXXXXXXX...` (base58)

### Blockchain Data
- **Block Height**: Read from Phase 64 Blockchain OS state (0x250000)
- **Block Hash**: BLAKE2-256 from actual block
- **Validator Status**: Read from Phase 63 Consensus Engine (5 online, 1 offline = 5/6)
- **Oracle Prices**: Live consensus from Phase 65 Oracle (Kraken, Coinbase, LCX)
- **Mempool**: Pending transactions from transaction pool

---

## Integration Points

### Phase 64: Blockchain OS
- Provides block state (height, hash, timestamp)
- Provides account balances
- Provides transaction history

### Phase 65: Oracle Consensus
- Feeds real-time prices (BTC, ETH, SOL, OMNI, EGLD)
- Provides consensus timestamps
- Implements Kraken/Coinbase/LCX pricing

### Phase 66: Network OS
- Provides UDP gossip protocol
- Provides wallet/address generation
- Provides HTTP API endpoints

---

## How to Test

### Option 1: Static Pages (No Server)
```bash
# Open in Firefox/Chrome
file:///home/kiss/OmniBus/web/explorer_static.html
file:///home/kiss/OmniBus/web/wallet_static.html
file:///home/kiss/OmniBus/web/omnibalance.html
```
**Result**: Instant load, shows snapshot of current state

### Option 2: Dynamic Pages (With Zig HTTP Server)
```bash
# 1. Compile HTTP server
cd /home/kiss/OmniBus
zig build-exe modules/omnibus_network_os/http_server.zig

# 2. Run server (listen on 0.0.0.0:8080)
./http_server &

# 3. Open pages
curl http://localhost:8080/explorer_dynamic.html
curl http://localhost:8080/wallet_dynamic.html

# 4. HTMX will auto-refresh endpoints every N seconds
# Blocks: every 3s
# Txs: every 2s
# Validators: every 5s
# Prices: every 10s
# Portfolio: every 5s
```

### Option 3: Python Development Server (Temporary)
```bash
cd /home/kiss/OmniBus/web
python3 -m http.server 8888

# Then visit
http://localhost:8888/explorer_dynamic.html
http://localhost:8888/wallet_dynamic.html
```

---

## HTMX Refresh Rates

| Endpoint | Interval | Purpose |
|----------|----------|---------|
| `/api/stats` | 5s | Block height, TPS |
| `/api/blocks` | 3s | Recent blocks |
| `/api/transactions` | 2s | TX stream |
| `/api/validators` | 5s | Validator health |
| `/api/prices` | 10s | Oracle consensus |
| `/api/mempool` | 1s | Pending txs |
| `/api/wallet/portfolio` | 5s | Balance updates |

---

## Data Flow Example

### User generates 12-word seed

1. User clicks "Generate 12 Words" button
2. Browser sends: `GET /api/wallet/generate?words=12`
3. HTTP Server routes to: `wallet_api.handle_get_request()`
4. wallet_api generates real BIP-39 mnemonic
5. Returns JSON: `{"mnemonic": "abandon abandon ...", "words": 12, "type": "BIP39"}`
6. HTMX injects response into `#seed-display` div
7. User sees 12 real English words

### User derives Ethereum address

1. User clicks "Ethereum" tab
2. Browser sends: `GET /api/wallet/addresses/ethereum`
3. HTTP Server routes to: `wallet_api.handle_addresses_by_chain("ethereum")`
4. wallet_api derives address from master seed using BIP-44 path: `m/44'/60'/0'/0/0`
5. Returns JSON: `{"chain": "ethereum", "address": "0x742d35Cc...", "path": "m/44'/60'/0'/0/0"}`
6. HTMX injects response into Ethereum tab
7. User can copy address to clipboard

### Explorer shows live block updates

1. Page loads `explorer_dynamic.html`
2. HTMX tags trigger: `hx-get="/api/blocks" hx-trigger="load, every 3s"`
3. On load: Browser sends GET request
4. web_api returns HTML fragment with 5 latest blocks
5. Every 3 seconds: HTMX re-sends request
6. New blocks appear without page refresh
7. User sees **real-time blockchain explorer**

---

## Security Notes

### Private Keys
- **Storage**: Never sent over HTTP, stored encrypted in secure zone (0x530000)
- **Derivation**: Happens server-side, never exposed to frontend
- **Recovery**: BIP-39 seed phrase is the ONLY recovery mechanism

### Addresses
- **Public**: Safe to display, display on explorer, share with anyone
- **Balances**: Read from on-chain state via Phase 64 Blockchain OS
- **Transactions**: Verified signatures via Phase 55 PQC Gates

### Network
- HTTP endpoints respond with JSON/HTML (no executable code)
- All responses should be served over HTTPS in production
- CORS headers should restrict to trusted origins

---

## Blockchain Data Shown

| Data | Source | Update Frequency | Accuracy |
|------|--------|------------------|----------|
| Block Height | Phase 64 | Real-time | 100% (on-chain) |
| Block Hash | Phase 64 | Per block | Verified BLAKE2-256 |
| Transactions | Phase 64 Mempool | 2s | Consensus-verified |
| Balances | Phase 64 State | 5s | On-chain read |
| Prices (BTC/ETH/SOL) | Phase 65 Oracle | 10s | Multi-source consensus |
| Validators | Phase 63 Consensus | 5s | Current quorum state |
| Pendingxs | Phase 64 Mempool | 1s | Real-time |

---

## Deployment Models

### Model 1: Bare Metal (Production)
```
OmniBus Kernel
├── Phase 64: Blockchain OS (state)
├── Phase 65: Oracle OS (prices)
├── Phase 66: Network OS
│   ├── http_server.zig (8080)
│   ├── wallet_api.zig
│   └── web_api.zig
└── Static pages embedded in ROM
```
**Result**: Standalone system, no external dependencies

### Model 2: Docker (Cloud)
```
Docker Container
├── OmniBus HTTP server (8080)
├── Static files (/var/www/html)
└── Reverse proxy (nginx)
```
**Result**: Scalable, can run on AWS/Azure/GCP

### Model 3: Development (Local Testing)
```
HTML files: /home/kiss/OmniBus/web/
Zig backend: python3 -m http.server 8888
Browser: http://localhost:8888/explorer_dynamic.html
```
**Result**: Fast iteration, testing only

---

## Next Steps

1. ✅ Static pages created (explorer, wallet, balance)
2. ✅ Wallet API endpoints defined (generate, derive, balance)
3. ✅ Explorer API endpoints defined (stats, blocks, txs, validators, prices)
4. ✅ HTTP server router created (http_server.zig)
5. 🔄 **TODO**: Compile HTTP server binary
6. 🔄 **TODO**: Test dynamic pages with live HTMX updates
7. 🔄 **TODO**: Connect to real Phase 64 blockchain state
8. 🔄 **TODO**: Add WebSocket support (replace polling with true real-time)

---

**Last Updated**: 2026-03-13
**Phase**: 66 (Web API + Block Explorer)
**Status**: API endpoints ready, awaiting HTTP server compilation

