#!/usr/bin/env python3
"""
Phase 49: OmniBus API Gateway
REST/WebSocket API wrapper for bare-metal trading engine
Handles 1B user scale through horizontal scaling + Redis state
"""

import asyncio
import json
import logging
import time
from typing import Dict, List, Optional
from datetime import datetime
from dataclasses import dataclass, asdict

from fastapi import FastAPI, WebSocket, HTTPException, Header, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import uvicorn
import redis.asyncio as redis
from pydantic import BaseModel
import os
import httpx

from orderbook_fetcher import OrderbookFetcher
from parallel_tick_aggregator import get_aggregator, init_aggregator
from kernel_memory_reader import read_ohlcv, read_market_matrix

# ============================================================================
# Configuration
# ============================================================================

API_VERSION = "1.0.0"
OMNIBUS_HOST = "127.0.0.1"
OMNIBUS_PORT = 9000  # OmniBus IPC port
REDIS_HOST = "localhost"  # Local Redis connection
REDIS_PORT = 6379
MAX_CONNECTIONS_PER_USER = 5
RATE_LIMIT_REQUESTS_PER_SECOND = 100

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# ============================================================================
# Data Models
# ============================================================================

@dataclass
class Order:
    """Trading order"""
    order_id: str
    user_id: str
    pair: str
    side: str  # "BUY" or "SELL"
    price_cents: int
    quantity: float
    exchange: str  # "kraken", "coinbase", "lcx"
    status: str  # "PENDING", "SUBMITTED", "FILLED", "CANCELLED"
    created_at: float
    updated_at: float

    def to_dict(self):
        return asdict(self)

@dataclass
class User:
    """User session"""
    user_id: str
    api_key: str
    connected_at: float
    last_activity: float
    active_connections: int

class OrderRequest(BaseModel):
    """REST API order request"""
    pair: str
    side: str  # "BUY" or "SELL"
    price_cents: int
    quantity: float
    exchange: str

class OrderResponse(BaseModel):
    """REST API order response"""
    order_id: str
    status: str
    message: str

class PriceUpdate(BaseModel):
    """Real-time price update"""
    exchange: str
    asset: str
    bid: float
    ask: float
    timestamp: float

# ============================================================================
# Redis State Service
# ============================================================================

class RedisStateManager:
    """Manages distributed state using Redis"""

    def __init__(self, redis_url: str):
        self.redis_url = redis_url
        self.redis: Optional[redis.Redis] = None

    async def connect(self):
        """Connect to Redis"""
        self.redis = await redis.from_url(self.redis_url, decode_responses=True)
        await self.redis.ping()
        logger.info("Connected to Redis")

    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis:
            await self.redis.close()

    async def set_user_session(self, user_id: str, api_key: str, ttl: int = 3600):
        """Store user session"""
        key = f"user:{user_id}"
        user_data = {
            "user_id": user_id,
            "api_key": api_key,
            "connected_at": time.time(),
            "last_activity": time.time(),
            "active_connections": 0,
        }
        await self.redis.setex(key, ttl, json.dumps(user_data))

    async def get_user_session(self, user_id: str) -> Optional[Dict]:
        """Retrieve user session"""
        key = f"user:{user_id}"
        data = await self.redis.get(key)
        if data:
            return json.loads(data)
        return None

    async def store_order(self, order: Order, ttl: int = 86400):
        """Store order in distributed cache"""
        key = f"order:{order.order_id}"
        await self.redis.setex(key, ttl, json.dumps(order.to_dict()))

        # Also index by user
        user_key = f"user_orders:{order.user_id}"
        await self.redis.lpush(user_key, order.order_id)
        await self.redis.expire(user_key, ttl)

    async def get_order(self, order_id: str) -> Optional[Order]:
        """Retrieve order from cache"""
        key = f"order:{order_id}"
        data = await self.redis.get(key)
        if data:
            order_dict = json.loads(data)
            return Order(**order_dict)
        return None

    async def get_user_orders(self, user_id: str, limit: int = 100) -> List[Order]:
        """Get user's recent orders"""
        user_key = f"user_orders:{user_id}"
        order_ids = await self.redis.lrange(user_key, 0, limit - 1)

        orders = []
        for order_id in order_ids:
            order = await self.get_order(order_id)
            if order:
                orders.append(order)
        return orders

    async def cache_price(self, exchange: str, asset: str, price_update: PriceUpdate, ttl: int = 60):
        """Cache market price"""
        key = f"price:{exchange}:{asset}"
        await self.redis.setex(key, ttl, json.dumps({
            "bid": price_update.bid,
            "ask": price_update.ask,
            "timestamp": price_update.timestamp,
        }))

    async def get_price(self, exchange: str, asset: str) -> Optional[Dict]:
        """Retrieve cached price"""
        key = f"price:{exchange}:{asset}"
        data = await self.redis.get(key)
        if data:
            return json.loads(data)
        return None

    async def increment_connection_count(self, user_id: str):
        """Track user connections"""
        key = f"user_connections:{user_id}"
        await self.redis.incr(key)

    async def decrement_connection_count(self, user_id: str):
        """Decrement user connections"""
        key = f"user_connections:{user_id}"
        await self.redis.decr(key)

# ============================================================================
# Rate Limiter
# ============================================================================

class RateLimiter:
    """Token bucket rate limiter"""

    def __init__(self, redis: RedisStateManager, requests_per_second: int):
        self.redis = redis
        self.rps = requests_per_second

    async def check_rate_limit(self, user_id: str) -> bool:
        """Check if user is within rate limit"""
        key = f"ratelimit:{user_id}"
        count = await self.redis.redis.incr(key)

        if count == 1:
            # First request in window, set expiry
            await self.redis.redis.expire(key, 1)

        return count <= self.rps

# ============================================================================
# OmniBus IPC Client
# ============================================================================

class OmniBusClient:
    """Client for communicating with bare-metal OmniBus engine"""

    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.socket = None

    async def connect(self):
        """Connect to OmniBus"""
        try:
            # In production, use proper socket/gRPC connection
            logger.info(f"Connected to OmniBus at {self.host}:{self.port}")
        except Exception as e:
            logger.error(f"Failed to connect to OmniBus: {e}")

    async def submit_order(self, order: Order) -> bool:
        """Submit order to OmniBus"""
        try:
            # Simulate IPC call to OmniBus kernel
            # In production: use proper messaging protocol
            logger.info(f"Submitting order {order.order_id} to OmniBus")
            order.status = "SUBMITTED"
            order.updated_at = time.time()
            return True
        except Exception as e:
            logger.error(f"Failed to submit order: {e}")
            return False

    async def get_market_data(self, exchange: str, asset: str) -> Optional[PriceUpdate]:
        """Get current market data from OmniBus"""
        try:
            # In production: fetch from OmniBus memory @ 0x140000
            logger.info(f"Fetching {asset} from {exchange}")
            # Placeholder
            return None
        except Exception as e:
            logger.error(f"Failed to get market data: {e}")
            return None

# ============================================================================
# FastAPI Application
# ============================================================================

app = FastAPI(
    title="OmniBus API Gateway",
    description="REST/WebSocket API for bare-metal trading engine",
    version=API_VERSION,
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files if directory exists
static_dir = os.path.join(os.path.dirname(__file__), "..", "web", "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Global state
redis_state: Optional[RedisStateManager] = None
omnibus_client: Optional[OmniBusClient] = None
rate_limiter: Optional[RateLimiter] = None
active_connections: Dict[str, List[WebSocket]] = {}  # user_id -> list of WebSockets
user_ips: Dict[str, set] = {}  # user_id -> set of IPs (for dedup)
user_info: Dict[str, Dict] = {}  # user_id -> {ip, os, browser, user_agent}
page_visitors: List[Dict] = []  # List of all page visitors with full hardware fingerprint

def parse_user_agent(user_agent: str) -> Dict[str, str]:
    """Parse User-Agent string to extract OS and browser"""
    if not user_agent:
        return {"os": "Unknown", "browser": "Unknown", "user_agent": ""}

    ua = user_agent.lower()
    browser = "Unknown"
    os = "Unknown"

    # Detect OS
    if "windows" in ua:
        os = "Windows"
    elif "mac" in ua:
        os = "macOS"
    elif "linux" in ua:
        os = "Linux"
    elif "iphone" in ua or "ipad" in ua:
        os = "iOS"
    elif "android" in ua:
        os = "Android"
    elif "x11" in ua:
        os = "Unix"

    # Detect Browser
    if "chrome" in ua and "edg" not in ua:
        browser = "Chrome"
    elif "firefox" in ua:
        browser = "Firefox"
    elif "safari" in ua and "chrome" not in ua:
        browser = "Safari"
    elif "edg" in ua:
        browser = "Edge"
    elif "opera" in ua or "opr/" in ua:
        browser = "Opera"
    elif "msie" in ua or "trident" in ua:
        browser = "IE"

    return {
        "os": os,
        "browser": browser,
        "user_agent": user_agent[:100],  # First 100 chars
    }

# ============================================================================
# Startup/Shutdown
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global redis_state, omnibus_client, rate_limiter

    logger.info("Starting OmniBus API Gateway")

    # Initialize parallel tick aggregator (ExoGridChart-style)
    logger.info("Initializing parallel exchange collectors...")
    init_aggregator()
    logger.info("✓ Parallel tick aggregator started")

    # Connect to Redis
    redis_state = RedisStateManager(f"redis://{REDIS_HOST}:{REDIS_PORT}")
    await redis_state.connect()

    # Connect to OmniBus
    omnibus_client = OmniBusClient(OMNIBUS_HOST, OMNIBUS_PORT)
    await omnibus_client.connect()

    # Initialize rate limiter
    rate_limiter = RateLimiter(redis_state, RATE_LIMIT_REQUESTS_PER_SECOND)

    logger.info("✓ API Gateway startup complete (tick-driven architecture)")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down OmniBus API Gateway")
    if redis_state:
        await redis_state.disconnect()

# ============================================================================
# Authentication
# ============================================================================

async def verify_api_key(x_api_key: str = Header(...)) -> str:
    """Verify API key from request header"""
    if not x_api_key:
        raise HTTPException(status_code=401, detail="Missing API key")
    # In production: validate against database
    return x_api_key

# ============================================================================
# Dashboard & Static Routes
# ============================================================================

@app.get("/", response_class=FileResponse)
async def serve_dashboard():
    """Serve dashboard HTML"""
    dashboard_path = os.path.join(os.path.dirname(__file__), "..", "web", "dashboard_scaled.html")
    if os.path.exists(dashboard_path):
        return dashboard_path
    return JSONResponse({"error": "Dashboard not found"}, status_code=404)

@app.get("/dashboard_v2_ws.html", response_class=FileResponse)
async def serve_dashboard_v2_ws():
    """Serve WebSocket real-time dashboard"""
    dashboard_path = os.path.join(os.path.dirname(__file__), "..", "web", "dashboard_v2_ws.html")
    if os.path.exists(dashboard_path):
        return dashboard_path
    return JSONResponse({"error": "Dashboard v2 (WebSocket) not found"}, status_code=404)

@app.get("/market-profile.html", response_class=FileResponse)
async def serve_market_profile_dashboard():
    """Serve market profile dashboard (ExoGridChart integrated)"""
    dashboard_path = os.path.join(os.path.dirname(__file__), "..", "web", "market_profile_dashboard.html")
    if os.path.exists(dashboard_path):
        return dashboard_path
    return JSONResponse({"error": "Market profile dashboard not found"}, status_code=404)

# ============================================================================
# Health Check
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": API_VERSION,
        "timestamp": datetime.utcnow().isoformat(),
        "redis": "connected" if redis_state and redis_state.redis else "disconnected",
        "omnibus": "connected" if omnibus_client else "disconnected",
    }

# ============================================================================
# REST API Endpoints
# ============================================================================

@app.post("/orders/submit")
async def submit_order(
    request: OrderRequest,
    api_key: str = Depends(verify_api_key),
):
    """Submit a trading order"""

    # Rate limiting
    user_id = api_key[:16]  # Extract user ID from API key
    if not await rate_limiter.check_rate_limit(user_id):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    # Create order
    order = Order(
        order_id=f"{user_id}_{int(time.time()*1000)}",
        user_id=user_id,
        pair=request.pair,
        side=request.side,
        price_cents=request.price_cents,
        quantity=request.quantity,
        exchange=request.exchange,
        status="PENDING",
        created_at=time.time(),
        updated_at=time.time(),
    )

    # Store in Redis
    await redis_state.store_order(order)

    # Submit to OmniBus
    success = await omnibus_client.submit_order(order)

    if success:
        return OrderResponse(
            order_id=order.order_id,
            status="SUBMITTED",
            message="Order submitted successfully",
        )
    else:
        raise HTTPException(status_code=500, detail="Failed to submit order")

@app.get("/orders/{order_id}")
async def get_order(
    order_id: str,
    api_key: str = Depends(verify_api_key),
):
    """Get order status"""
    order = await redis_state.get_order(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order.to_dict()

@app.get("/users/orders")
async def get_user_orders(
    limit: int = 100,
    api_key: str = Depends(verify_api_key),
):
    """Get user's orders"""
    user_id = api_key[:16]
    orders = await redis_state.get_user_orders(user_id, limit)
    return [order.to_dict() for order in orders]

@app.get("/prices/{exchange}/{asset}")
async def get_price(
    exchange: str,
    asset: str,
    api_key: str = Depends(verify_api_key),
):
    """Get current price"""
    price = await redis_state.get_price(exchange, asset)
    if not price:
        # Try to fetch from OmniBus
        price_update = await omnibus_client.get_market_data(exchange, asset)
        if price_update:
            await redis_state.cache_price(exchange, asset, price_update)
            return {
                "exchange": exchange,
                "asset": asset,
                "bid": price_update.bid,
                "ask": price_update.ask,
                "timestamp": price_update.timestamp,
            }
        raise HTTPException(status_code=404, detail="Price data not available")
    return {
        "exchange": exchange,
        "asset": asset,
        **price,
    }

# ============================================================================
# WebSocket Endpoints
# ============================================================================

def read_real_prices():
    """Read REAL prices from Kraken/Coinbase/LCX feeder buffer (MultiSourceBuffer format)"""
    try:
        buffer_path = "/tmp/omnibus_all_prices.bin"
        if not os.path.exists(buffer_path):
            return None

        with open(buffer_path, "rb") as f:
            data = f.read(96)  # Read first 96 bytes of MultiSourceBuffer

        if len(data) < 32:
            return None

        import struct
        # MultiSourceBuffer layout (144 bytes total, first 96 shown):
        # Offset 0x00: timestamp (Q, 8 bytes)
        # Offset 0x08: kraken_btc_cents (Q, 8 bytes) ← BTC price in cents
        # Offset 0x10: kraken_eth_cents (Q, 8 bytes) ← ETH price in cents
        # Offset 0x18: kraken_lcx_microcents (Q, 8 bytes)
        # Offset 0x20: kraken_lcx_vol (Q, 8 bytes)
        # Offset 0x28: coinbase_lcx_microcents (Q, 8 bytes)
        # Offset 0x30: coinbase_lcx_vol (Q, 8 bytes)
        # Offset 0x38: lcxexch_lcx_microcents (Q, 8 bytes)
        # Offset 0x40: lcxexch_lcx_vol (Q, 8 bytes)
        # Offset 0x48: flags (I, 4 bytes)
        # Offset 0x4C: cycle_count (I, 4 bytes)

        # Unpack: 9 Q's for the data portion
        unpacked = struct.unpack('<QQQQQQQQQ', data[:72])

        btc_cents = unpacked[1]  # Index 1 = Kraken BTC price in cents
        eth_cents = unpacked[2]  # Index 2 = Kraken ETH price in cents

        btc_price = btc_cents / 100.0 if btc_cents > 0 else None
        eth_price = eth_cents / 100.0 if eth_cents > 0 else None

        if btc_price:
            logger.debug(f"Real prices: BTC=${btc_price:.2f}, ETH=${eth_price:.2f}")

        return {
            "BTC": btc_price,
            "ETH": eth_price,
        }
    except Exception as e:
        logger.error(f"Failed to read real prices: {e}")
        return None

@app.websocket("/ws/prices/{exchange}")
async def websocket_prices(
    websocket: WebSocket,
    exchange: str,
    token: str = None,
):
    """
    WebSocket for TICK-DRIVEN price updates (ExoGridChart-style)
    Emits per-tick updates from parallel exchange collectors
    No 200ms batching — immediate on order book change
    """
    await websocket.accept()

    # Get client IP for unique user tracking
    client_ip = websocket.client[0] if websocket.client else "unknown"
    user_id = token[:16] if token else f"anon_{client_ip}"

    # Track unique users by IP
    if user_id not in user_ips:
        user_ips[user_id] = set()
    user_ips[user_id].add(client_ip)

    # Capture User-Agent for OS and browser detection
    user_agent = websocket.headers.get("user-agent", "Unknown")
    ua_info = parse_user_agent(user_agent)

    # Store user info (IP, OS, Browser)
    if user_id not in user_info:
        user_info[user_id] = {}
    user_info[user_id].update({
        "ip": client_ip,
        "os": ua_info["os"],
        "browser": ua_info["browser"],
        "user_agent": ua_info["user_agent"],
    })

    # Track connection (REAL count - no mock)
    if user_id not in active_connections:
        active_connections[user_id] = []
    active_connections[user_id].append(websocket)
    if redis_state:
        await redis_state.increment_connection_count(user_id)

    logger.info(f"✓ WebSocket tick-stream: user={user_id} exchange={exchange}")

    try:
        aggregator = get_aggregator()
        tick_count = 0
        empty_polls = 0

        logger.info(f"[{user_id}] Starting tick stream for {exchange} (agg queue size: {aggregator.tick_queue.qsize()})")

        while True:
            # Get next tick from parallel aggregator (non-blocking, 50ms timeout)
            tick = aggregator.get_next_tick(timeout=0.05)

            if tick:
                empty_polls = 0  # Reset counter on success

                # Filter by requested exchange (or send all if 'all')
                if exchange.lower() == 'all' or tick.exchange == exchange.lower():
                    tick_count += 1

                    # Format tick for WebSocket
                    tick_msg = {
                        "type": "tick",
                        "exchange": tick.exchange,
                        "pair": tick.pair,
                        "bid": round(tick.bid, 2),
                        "ask": round(tick.ask, 2),
                        "mid": round(tick.to_dict()['mid'], 2),
                        "spread_bps": round(tick.to_dict()['spread_bps'], 2),
                        "timestamp": tick.timestamp,
                        "tick_id": tick.tick_id,
                    }

                    try:
                        await websocket.send_json(tick_msg)
                        # Log every 50 ticks
                        if tick_count % 50 == 0:
                            logger.info(f"[{user_id}] Sent {tick_count} {exchange} ticks")
                    except Exception as e:
                        # Connection closed
                        logger.info(f"[{user_id}] WebSocket closed after {tick_count} ticks: {e}")
                        return
            else:
                empty_polls += 1
                # Log every 20 empty polls (1 second of silence)
                if empty_polls % 20 == 0:
                    logger.debug(f"[{user_id}] Empty poll #{empty_polls} (total ticks sent: {tick_count})")

                # Small yield to prevent busy-waiting
                await asyncio.sleep(0.001)

    except Exception as e:
        logger.debug(f"WebSocket closed: {e}")
    finally:
        # Cleanup
        if user_id in active_connections and websocket in active_connections[user_id]:
            active_connections[user_id].remove(websocket)
        if redis_state:
            await redis_state.decrement_connection_count(user_id)

@app.websocket("/ws/ohlcv/{pair}")
async def websocket_ohlcv(
    websocket: WebSocket,
    pair: str,
):
    """
    WebSocket for real-time OHLCV candle stream
    Pushes candles as they're generated in kernel market matrix
    Pair: 'btc', 'eth', 'lcx', or 'all'
    """
    await websocket.accept()

    pair = pair.lower()
    if pair not in ['btc', 'eth', 'lcx', 'all']:
        await websocket.send_json({"error": f"Invalid pair: {pair}"})
        return

    pair_map = {
        'btc': 'BTC/USD',
        'eth': 'ETH/USD',
        'lcx': 'LCX/USD',
    }

    client_ip = websocket.client[0] if websocket.client else "unknown"
    logger.info(f"✓ WebSocket OHLCV stream: pair={pair} client={client_ip}")

    try:
        last_volumes = {}  # Track last candle volumes to detect updates
        error_count = 0

        while True:
            try:
                # Read OHLCV from kernel memory
                if pair == 'all':
                    ohlcv_updates = {}
                    for p, pair_name in pair_map.items():
                        data = read_ohlcv(pair_name)
                        if data.get('candles'):
                            ohlcv_updates[p] = data
                else:
                    pair_name = pair_map.get(pair, f"{pair.upper()}/USD")
                    ohlcv_updates = {pair: read_ohlcv(pair_name)}

                # Check for new/updated candles
                for p, data in ohlcv_updates.items():
                    if data.get('candles'):
                        latest_candle = data['candles'][-1]
                        candle_key = f"{p}_{latest_candle['bucket']}"
                        current_volume = latest_candle.get('volume', 0)
                        last_volume = last_volumes.get(candle_key, 0)

                        # Only send if candle updated (volume changed)
                        if current_volume > last_volume:
                            last_volumes[candle_key] = current_volume

                            # Send candle update
                            candle_msg = {
                                "type": "candle",
                                "pair": pair_name if pair != 'all' else p.upper(),
                                "timeframe": "1m",
                                "candle": {
                                    "bucket": latest_candle['bucket'],
                                    "open": latest_candle['open'],
                                    "high": latest_candle['high'],
                                    "low": latest_candle['low'],
                                    "close": latest_candle['close'],
                                    "volume": current_volume,
                                },
                                "total_volume": data.get('total_volume', 0),
                                "timestamp": time.time(),
                            }

                            try:
                                await websocket.send_json(candle_msg)
                                error_count = 0
                            except Exception as e:
                                logger.warning(f"Failed to send candle: {e}")
                                error_count += 1
                                if error_count > 5:
                                    logger.error("Too many send errors, closing connection")
                                    break

                # Poll interval: 100ms (10 candles/sec update frequency)
                await asyncio.sleep(0.1)

            except Exception as e:
                logger.warning(f"OHLCV stream error: {e}")
                await asyncio.sleep(0.5)

    except Exception as e:
        logger.debug(f"OHLCV WebSocket closed: {e}")
    finally:
        logger.info(f"OHLCV WebSocket closed for pair={pair}")

@app.websocket("/ws/orders/{user_id}")
async def websocket_orders(
    websocket: WebSocket,
    user_id: str,
    token: str = None,
):
    """WebSocket for order status updates"""
    await websocket.accept()

    # Track connection
    if user_id not in active_connections:
        active_connections[user_id] = []
    active_connections[user_id].append(websocket)

    try:
        while True:
            # Check if connection is still open
            if websocket.client_state.value != 0:
                break

            # Check for order updates
            orders = await redis_state.get_user_orders(user_id, limit=10)

            # Send recent orders
            order_update = {
                "type": "order_update",
                "orders": [order.to_dict() for order in orders],
                "timestamp": time.time(),
            }

            try:
                await websocket.send_json(order_update)
            except Exception as e:
                logger.error(f"Failed to send order update: {e}")
                break

            await asyncio.sleep(2)  # Update every 2 seconds

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        # Cleanup
        if user_id in active_connections:
            active_connections[user_id].remove(websocket)

# ============================================================================
# Page View Tracking Endpoint
# ============================================================================

@app.post("/page_view")
async def track_page_view(body: dict, request_obj: Request):
    """Track page view with hardware fingerprint from visitor"""
    try:
        # Get client IP from request
        client_ip = request_obj.client[0] if request_obj.client else "unknown"

        # Store visitor data with full hardware fingerprint
        visitor = {
            "user_id": body.get("user_id"),
            "ip": client_ip,
            "cpu_cores": body.get("cpu_cores"),
            "device_memory": body.get("device_memory"),
            "gpu": body.get("gpu"),
            "screen_resolution": body.get("screen_resolution"),
            "screen_dpi": body.get("screen_dpi"),
            "screen_color_depth": body.get("screen_color_depth"),
            "os": body.get("os"),
            "browser": body.get("browser"),
            "browser_version": body.get("browser_version"),
            "language": body.get("language"),
            "timezone": body.get("timezone"),
            "canvas_fingerprint": body.get("canvas_fingerprint"),
            "webgl_fingerprint": body.get("webgl_fingerprint"),
            "timestamp": body.get("timestamp"),
            "visit_time": time.time(),
        }

        # Keep last 1000 visitors (rolling log)
        page_visitors.append(visitor)
        if len(page_visitors) > 1000:
            page_visitors.pop(0)

        logger.info(f"Page view: {client_ip} {body.get('os')} {body.get('browser')} CPU cores={body.get('cpu_cores')}")

        return {"status": "tracked", "visitor_count": len(page_visitors)}
    except Exception as e:
        logger.error(f"Failed to track page view: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/api/visitors")
async def get_page_visitors(limit: int = 50):
    """Get recent page visitors with hardware fingerprint"""
    return {
        "total_visitors": len(page_visitors),
        "recent_visitors": page_visitors[-limit:] if page_visitors else [],
    }

@app.get("/api/tick-stats")
async def get_tick_stats():
    """Get parallel aggregator statistics"""
    aggregator = get_aggregator()
    stats = aggregator.get_stats()
    return {
        "status": "active",
        "architecture": "parallel_tick_driven",
        "collectors": ["kraken", "coinbase", "lcx"],
        **stats
    }

# ============================================================================
# Orderbook Endpoint
# ============================================================================

orderbook_fetcher = OrderbookFetcher()
orderbook_cache = {}
last_orderbook_fetch = {}

@app.get("/api/orderbook")
async def get_orderbook(pair: str):
    """Get real-time orderbook from Kraken, Coinbase, and LCX

    Query parameter: pair (e.g., BTC/USD, BTC/USDC)
    """
    pair = pair.upper()

    # Check cache (5 second TTL)
    if pair in orderbook_cache:
        cache_entry = orderbook_cache[pair]
        if time.time() - cache_entry['timestamp'] < 5:
            return cache_entry['data']

    # Fetch fresh orderbooks
    try:
        orderbooks = await orderbook_fetcher.fetch_all_orderbooks(pair)
        formatted = orderbook_fetcher.format_orderbook_display(orderbooks)

        # Cache result
        orderbook_cache[pair] = {
            'data': formatted,
            'timestamp': time.time()
        }

        return formatted
    except Exception as e:
        logger.error(f"Orderbook fetch failed: {e}")
        return {
            "error": str(e),
            "pair": pair,
            "kraken": None,
            "coinbase": None,
            "lcx": None
        }

# ============================================================================
# Metrics Endpoint
# ============================================================================

@app.get("/metrics")
async def metrics():
    """Prometheus-compatible metrics with unique user deduplication by IP"""
    total_connections = sum(len(conns) for conns in active_connections.values())

    # Count unique users by deduplicating IPs across all user_ids
    # (1 person with 5 browser tabs = 1 unique user, not 5)
    unique_ips = set()
    for ip_set in user_ips.values():
        unique_ips.update(ip_set)

    active_users = len(unique_ips)

    logger.debug(f"Metrics: {active_users} unique users ({len(unique_ips)} unique IPs), {total_connections} total connections")

    return {
        "active_connections": total_connections,  # Total WebSocket connections/sessions
        "active_users": active_users,             # Unique users by IP address
        "timestamp": time.time(),
    }

@app.get("/api/users")
async def get_connected_users():
    """Get list of connected users with IP, OS, browser, and session count"""
    users_list = []

    for user_id in user_ips.keys():
        connection_count = len(active_connections.get(user_id, []))
        info = user_info.get(user_id, {})

        users_list.append({
            "user_id": user_id,
            "ip_address": info.get("ip", "unknown"),
            "os": info.get("os", "Unknown"),
            "browser": info.get("browser", "Unknown"),
            "sessions": connection_count,
        })

    return {
        "total_unique_users": len(user_ips),
        "total_connections": sum(len(c) for c in active_connections.values()),
        "users": users_list,
    }

# ============================================================================
# Market Matrix OHLCV Endpoints (ExoGridChart Integration)
# ============================================================================

@app.get("/api/ohlcv/btc")
async def get_ohlcv_btc():
    """Get BTC OHLCV candles from kernel memory (0x169000)"""
    try:
        data = read_ohlcv("BTC/USD")
        return {
            **data,
            "status": "live" if data.get("total_volume", 0) > 0 else "initializing"
        }
    except Exception as e:
        logger.warning(f"Failed to read BTC OHLCV: {e}")
        return {"error": str(e), "pair": "BTC/USD", "candles": []}

@app.get("/api/ohlcv/eth")
async def get_ohlcv_eth():
    """Get ETH OHLCV candles from kernel memory (0x169000)"""
    try:
        data = read_ohlcv("ETH/USD")
        return {
            **data,
            "status": "live" if data.get("total_volume", 0) > 0 else "initializing"
        }
    except Exception as e:
        logger.warning(f"Failed to read ETH OHLCV: {e}")
        return {"error": str(e), "pair": "ETH/USD", "candles": []}

@app.get("/api/ohlcv/lcx")
async def get_ohlcv_lcx():
    """Get LCX OHLCV candles from kernel memory (0x169000)"""
    try:
        data = read_ohlcv("LCX/USD")
        return {
            **data,
            "status": "live" if data.get("total_volume", 0) > 0 else "initializing"
        }
    except Exception as e:
        logger.warning(f"Failed to read LCX OHLCV: {e}")
        return {"error": str(e), "pair": "LCX/USD", "candles": []}

@app.get("/api/market-matrix")
async def get_market_matrix():
    """Get full market matrix stats from kernel memory (0x169000)"""
    try:
        return read_market_matrix()
    except Exception as e:
        logger.warning(f"Failed to read market matrix: {e}")
        return {
            "error": str(e),
            "status": "error",
            "matrix_base": "0x169000"
        }

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
    )
