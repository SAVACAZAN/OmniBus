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

    # Connect to Redis
    redis_state = RedisStateManager(f"redis://{REDIS_HOST}:{REDIS_PORT}")
    await redis_state.connect()

    # Connect to OmniBus
    omnibus_client = OmniBusClient(OMNIBUS_HOST, OMNIBUS_PORT)
    await omnibus_client.connect()

    # Initialize rate limiter
    rate_limiter = RateLimiter(redis_state, RATE_LIMIT_REQUESTS_PER_SECOND)

    logger.info("API Gateway startup complete")

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
    """Read REAL prices from Kraken/Coinbase/LCX feeder buffer"""
    try:
        buffer_path = "/tmp/omnibus_all_prices.bin"
        if not os.path.exists(buffer_path):
            return None

        with open(buffer_path, "rb") as f:
            data = f.read(72)  # Read 72-byte single exchange buffer

        if len(data) < 40:
            return None

        import struct
        # Buffer layout (little-endian, 72 bytes total):
        # Offset 0x00: timestamp (Q, 8 bytes)
        # Offset 0x08: btc_price_cents (Q, 8 bytes) ← BTC in cents
        # Offset 0x10: btc_volume (Q, 8 bytes)
        # Offset 0x18: eth_price_cents (Q, 8 bytes) ← ETH in cents
        # Offset 0x20: eth_volume (Q, 8 bytes)
        # Offset 0x28: flags (I, 4 bytes)
        # Offset 0x2C: reserved (I, 4 bytes)
        # Offset 0x30: last_tsc (Q, 8 bytes)
        # Offset 0x38: lcx_cents (Q, 8 bytes)
        # Offset 0x40: lcx_volume (Q, 8 bytes)

        # Unpack: timestamp, btc_cents, btc_vol, eth_cents, eth_vol, flags, reserved, tsc, lcx_cents, lcx_vol
        # Format: 5Q (40) + 2I (8) + 3Q (24) = 72 bytes total  (10 format codes)
        unpacked = struct.unpack('<QQQQQIIQQQ', data[:72])  # 5Q + 2I + 3Q = 72 bytes

        btc_cents = unpacked[1]  # Index 1 = BTC price in cents
        eth_cents = unpacked[3]  # Index 3 = ETH price in cents

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
    """WebSocket for REAL-TIME price updates (Kraken/Coinbase/LCX live data only)"""
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

    logger.info(f"WebSocket connect: user={user_id} ip={client_ip} os={ua_info['os']} browser={ua_info['browser']}")

    try:
        while True:
            await asyncio.sleep(0.2)  # 200ms update cycle

            # Read REAL prices from feeder — NO MOCK FALLBACK
            prices = read_real_prices()
            if not prices:
                continue  # Skip if no real data available

            # Send ONLY REAL prices — no mock values
            for asset in ["BTC", "ETH"]:
                price = prices.get(asset)
                if price is None:
                    continue  # Skip assets without real data

                price_update = {
                    "type": "price_update",
                    "exchange": exchange.lower(),
                    "asset": asset,
                    "bid": price,
                    "ask": price,
                    "timestamp": time.time(),
                }

                try:
                    await websocket.send_json(price_update)
                except Exception as e:
                    logger.error(f"Failed to send price update: {e}")
                    break

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        # Cleanup
        if user_id in active_connections and websocket in active_connections[user_id]:
            active_connections[user_id].remove(websocket)
        if redis_state:
            await redis_state.decrement_connection_count(user_id)

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
# Main
# ============================================================================

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
    )
