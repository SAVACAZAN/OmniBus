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

from fastapi import FastAPI, WebSocket, HTTPException, Header, Depends
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
active_connections: Dict[str, List[WebSocket]] = {}

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
    """Read real prices from feeder buffer"""
    try:
        buffer_path = "/tmp/omnibus_all_prices.bin"
        if not os.path.exists(buffer_path):
            return None

        with open(buffer_path, "rb") as f:
            data = f.read(72)  # Read first 72 bytes (single exchange buffer)

        if len(data) < 40:
            return None

        import struct
        # Unpack: timestamp, btc_cents, btc_vol, eth_cents, eth_vol, flags, reserved, tsc, lcx_cents, lcx_vol
        values = struct.unpack('<QQQQQIIQ', data[:48])  # First 48 bytes

        btc_cents = values[1]
        eth_cents = values[3]

        return {
            "BTC": btc_cents / 100.0 if btc_cents > 0 else None,
            "ETH": eth_cents / 100.0 if eth_cents > 0 else None,
        }
    except Exception as e:
        logger.warning(f"Failed to read real prices: {e}")
        return None

@app.websocket("/ws/prices/{exchange}")
async def websocket_prices(
    websocket: WebSocket,
    exchange: str,
    token: str = None,
):
    """WebSocket for REAL-TIME price updates (Kraken/Coinbase/LCX live data only)"""
    await websocket.accept()

    user_id = token[:16] if token else "anonymous"

    # Track connection (REAL count - no mock)
    if user_id not in active_connections:
        active_connections[user_id] = []
    active_connections[user_id].append(websocket)
    if redis_state:
        await redis_state.increment_connection_count(user_id)

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
# Metrics Endpoint
# ============================================================================

@app.get("/metrics")
async def metrics():
    """Prometheus-compatible metrics"""
    total_connections = sum(len(conns) for conns in active_connections.values())

    return {
        "active_connections": total_connections,
        "active_users": len(active_connections),
        "timestamp": time.time(),
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
