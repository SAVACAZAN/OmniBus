#!/usr/bin/env python3
"""
Parallel Tick Aggregator — ExoGridChart-style architecture
Concurrent Kraken/Coinbase/LCX streams with atomic tick callbacks
"""

import threading
import queue
import json
import logging
import requests
import time
from typing import Callable, Optional, Dict
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class Tick:
    """Atomic market tick (one order book update)"""
    exchange: str      # 'kraken', 'coinbase', 'lcx'
    pair: str          # 'BTC/USD', 'ETH/USD', 'LCX/USD'
    bid: float
    ask: float
    timestamp: float
    tick_id: int       # Global tick counter

    def to_dict(self):
        return {
            'exchange': self.exchange,
            'pair': self.pair,
            'bid': self.bid,
            'ask': self.ask,
            'timestamp': self.timestamp,
            'tick_id': self.tick_id,
            'mid': (self.bid + self.ask) / 2,
            'spread_bps': ((self.ask - self.bid) / self.bid * 10000) if self.bid > 0 else 0,
        }


class ExchangeCollector(threading.Thread):
    """Parallel thread collecting ticks from one exchange"""

    def __init__(self, exchange: str, tick_queue: queue.Queue, interval: float = 0.05):
        """
        Args:
            exchange: 'kraken', 'coinbase', or 'lcx'
            tick_queue: Thread-safe queue for ticks
            interval: Polling interval in seconds (50ms = 20 ticks/sec per exchange)
        """
        super().__init__(daemon=True)
        self.exchange = exchange
        self.tick_queue = tick_queue
        self.interval = interval
        self.running = True
        self.last_bid = None
        self.last_ask = None
        self.tick_count = 0

        # Exchange endpoints
        self.kraken_url = "https://api.kraken.com/0/public/Depth"
        self.coinbase_url = "https://api.exchange.coinbase.com/products"
        self.lcx_url = "https://api.lcx.com/api/v1/orderbook"

        self.session = requests.Session()

    def run(self):
        """Main collection loop"""
        logger.info(f"[{self.exchange}] Collector started")

        while self.running:
            try:
                tick = self.fetch_tick()
                if tick:
                    self.tick_queue.put(tick)
                    self.tick_count += 1

                    # Log every 100 ticks
                    if self.tick_count % 100 == 0:
                        logger.debug(f"[{self.exchange}] {self.tick_count} ticks → queue")

            except Exception as e:
                logger.warning(f"[{self.exchange}] Fetch error: {e}")

            time.sleep(self.interval)

    def fetch_tick(self) -> Optional[Tick]:
        """Fetch latest orderbook and always return tick (even if unchanged)"""
        try:
            tick = None
            if self.exchange == 'kraken':
                tick = self._fetch_kraken_tick()
            elif self.exchange == 'coinbase':
                tick = self._fetch_coinbase_tick()
            elif self.exchange == 'lcx':
                tick = self._fetch_lcx_tick()

            # Always return a tick (emit on every fetch, not just on price change)
            # This ensures continuous stream even when price is stable
            if tick:
                return tick

        except Exception as e:
            logger.debug(f"[{self.exchange}] Tick fetch failed: {e}")
        return None

    def _fetch_kraken_tick(self) -> Optional[Tick]:
        """Fetch Kraken BTC/USD orderbook - emit tick on every fetch"""
        resp = self.session.get(
            self.kraken_url,
            params={'pair': 'XXBTZUSD', 'count': '1'},
            timeout=2
        )
        data = resp.json()

        if data.get('result'):
            ob = list(data['result'].values())[0]
            bid = float(ob['bids'][0][0])
            ask = float(ob['asks'][0][0])

            # Store for next comparison, but always emit tick (continuous stream)
            self.last_bid = bid
            self.last_ask = ask

            return Tick(
                exchange='kraken',
                pair='BTC/USD',
                bid=bid,
                ask=ask,
                timestamp=time.time(),
                tick_id=self.tick_count
            )
        return None

    def _fetch_coinbase_tick(self) -> Optional[Tick]:
        """Fetch Coinbase BTC/USD orderbook - emit tick on every fetch"""
        resp = self.session.get(
            f"{self.coinbase_url}/BTC-USD/book?level=1",
            timeout=2
        )
        data = resp.json()

        if data.get('bids') and data.get('asks'):
            bid = float(data['bids'][0][0])
            ask = float(data['asks'][0][0])

            self.last_bid = bid
            self.last_ask = ask

            return Tick(
                exchange='coinbase',
                pair='BTC/USD',
                bid=bid,
                ask=ask,
                timestamp=time.time(),
                tick_id=self.tick_count
            )
        return None

    def _fetch_lcx_tick(self) -> Optional[Tick]:
        """Fetch LCX BTC/USD orderbook - emit tick on every fetch"""
        try:
            resp = self.session.get(
                f"{self.lcx_url}/BTC_USD",
                timeout=2
            )
            data = resp.json()

            if data.get('bids') and data.get('asks'):
                bid = float(data['bids'][0][0])
                ask = float(data['asks'][0][0])

                self.last_bid = bid
                self.last_ask = ask

                return Tick(
                    exchange='lcx',
                    pair='BTC/USD',
                    bid=bid,
                    ask=ask,
                    timestamp=time.time(),
                    tick_id=self.tick_count
                )
        except Exception as e:
            logger.debug(f"[lcx] Fetch failed: {e}")
        return None

    def stop(self):
        """Stop collection thread"""
        self.running = False


class ParallelTickAggregator:
    """
    Manages 3 parallel exchange collectors + atomic tick buffer
    Architecture inspired by ExoGridChart
    """

    def __init__(self, max_queue_size: int = 10000):
        self.tick_queue = queue.Queue(maxsize=max_queue_size)
        self.tick_counter = 0
        self.exchanges = {}
        self.stats = {
            'ticks_processed': 0,
            'kraken_ticks': 0,
            'coinbase_ticks': 0,
            'lcx_ticks': 0,
        }
        self.lock = threading.Lock()

    def start(self):
        """Start all 3 parallel collectors"""
        logger.info("Starting parallel exchange collectors...")

        # Start collector threads (25ms interval = 40 ticks/sec per exchange)
        # 3 exchanges × 40 = 120 ticks/sec potential throughput
        self.exchanges['kraken'] = ExchangeCollector('kraken', self.tick_queue, interval=0.025)
        self.exchanges['coinbase'] = ExchangeCollector('coinbase', self.tick_queue, interval=0.025)
        self.exchanges['lcx'] = ExchangeCollector('lcx', self.tick_queue, interval=0.025)

        for collector in self.exchanges.values():
            collector.start()

        logger.info("✓ 3 parallel collectors started (Kraken, Coinbase, LCX)")

    def get_next_tick(self, timeout: float = 0.1) -> Optional[Tick]:
        """
        Get next tick from atomic buffer (non-blocking)
        Returns immediately if tick available, None if timeout
        """
        try:
            tick = self.tick_queue.get(timeout=timeout)

            # Update stats atomically
            with self.lock:
                self.tick_counter += 1
                tick.tick_id = self.tick_counter
                self.stats['ticks_processed'] = self.tick_counter
                self.stats[f'{tick.exchange}_ticks'] += 1

            return tick

        except queue.Empty:
            return None

    def get_stats(self) -> Dict:
        """Get current aggregation statistics"""
        with self.lock:
            return self.stats.copy()

    def stop(self):
        """Stop all collectors"""
        for collector in self.exchanges.values():
            collector.stop()
        logger.info("✓ All collectors stopped")


# Global aggregator instance
_aggregator: Optional[ParallelTickAggregator] = None

def init_aggregator():
    """Initialize global aggregator"""
    global _aggregator
    _aggregator = ParallelTickAggregator()
    _aggregator.start()
    return _aggregator

def get_aggregator() -> ParallelTickAggregator:
    """Get global aggregator instance"""
    global _aggregator
    if _aggregator is None:
        _aggregator = init_aggregator()
    return _aggregator
