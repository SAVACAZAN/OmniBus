#!/usr/bin/env python3
"""
Phase 23-b: Coinbase Price Feeder for OmniBus
==============================================

Fetches real BTC/ETH/LCX prices from Coinbase REST API.
Writes to shared memory buffer @ 0x140000 (compatible with Analytics OS).

Usage:
    python3 coinbase_feeder.py          # Run with file-based buffer
    python3 coinbase_feeder.py --interval 100

Requirements:
    pip install requests

API: https://api.exchange.coinbase.com/products
"""

import requests
import struct
import time
import sys
import argparse
import logging
from typing import Optional, Dict, Tuple

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

EXCHANGE_BUFFER_ADDR = 0x140000
EXCHANGE_BUFFER_SIZE = 72

# Exchange flags
KRAKEN_VALID = 0x01
COINBASE_VALID = 0x02
LCX_VALID = 0x04

# Coinbase products
COINBASE_PRODUCTS = {
    "BTC-USD": ("BTC", 0),
    "ETH-USD": ("ETH", 1),
    "LCX-USD": ("LCX", 2),
}

COINBASE_BASE = "https://api.exchange.coinbase.com"


class ExchangeBuffer:
    """72-byte exchange buffer (compatible with kraken_feeder.py)"""

    def __init__(self):
        self.timestamp = 0
        self.btc_price_cents = 0
        self.btc_volume_sats = 0
        self.eth_price_cents = 0
        self.eth_volume_sats = 0
        self.exchange_flags = 0
        self.reserved1 = 0
        self.last_tsc = 0
        self.lcx_price_cents = 0
        self.lcx_volume_sats = 0

    def to_bytes(self) -> bytes:
        """Pack to 72 bytes (little-endian)"""
        return struct.pack('<Q Q Q Q Q I I Q Q Q',
            self.timestamp,
            self.btc_price_cents,
            self.btc_volume_sats,
            self.eth_price_cents,
            self.eth_volume_sats,
            self.exchange_flags,
            self.reserved1,
            self.last_tsc,
            self.lcx_price_cents,
            self.lcx_volume_sats
        )

    def __repr__(self):
        lcx_str = f", LCX=${self.lcx_price_cents/100:.4f}" if self.lcx_price_cents > 0 else ""
        return (
            f"ExchangeBuffer(BTC=${self.btc_price_cents/100:.2f}, "
            f"ETH=${self.eth_price_cents/100:.2f}{lcx_str}, "
            f"flags=0x{self.exchange_flags:02x})"
        )


class CoinbaseFeeder:
    """Fetches prices from Coinbase REST API"""

    def __init__(self, buffer_file: str = "/tmp/omnibus_coinbase_buffer.bin"):
        self.buffer_file = buffer_file
        self.session = requests.Session()
        self.cycle = 0
        self.error_count = 0
        self.start_time = time.time()

    def fetch_ticker(self, product_id: str) -> Optional[Dict]:
        """Fetch ticker for a product"""
        try:
            url = f"{COINBASE_BASE}/products/{product_id}/ticker"
            response = self.session.get(url, timeout=5)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            log.debug(f"Coinbase fetch failed for {product_id}: {e}")
            return None

    def fetch_all_prices(self) -> Tuple[int, int, int, int, int, int]:
        """Fetch BTC, ETH, LCX prices from Coinbase"""
        btc_cents, btc_vol = 0, 0
        eth_cents, eth_vol = 0, 0
        lcx_cents, lcx_vol = 0, 0

        try:
            # BTC-USD
            btc_data = self.fetch_ticker("BTC-USD")
            if btc_data and "price" in btc_data:
                btc_cents = int(float(btc_data["price"]) * 100)
                btc_vol = int(float(btc_data.get("volume", 0)) * 1e8)

            # ETH-USD
            eth_data = self.fetch_ticker("ETH-USD")
            if eth_data and "price" in eth_data:
                eth_cents = int(float(eth_data["price"]) * 100)
                eth_vol = int(float(eth_data.get("volume", 0)) * 1e8)

            # LCX-USD (use micro-cents for 5-decimal precision)
            lcx_data = self.fetch_ticker("LCX-USD")
            if lcx_data and "price" in lcx_data:
                lcx_price = float(lcx_data["price"])
                lcx_cents = int(lcx_price * 1_000_000)  # micro-cents for precision
                lcx_vol = int(float(lcx_data.get("volume", 0)) * 1e8)

            return btc_cents, btc_vol, eth_cents, eth_vol, lcx_cents, lcx_vol
        except Exception as e:
            log.error(f"Price fetch error: {e}")
            return 0, 0, 0, 0, 0, 0

    def write_buffer(self, buf: ExchangeBuffer) -> bool:
        """Write buffer to file"""
        try:
            with open(self.buffer_file, 'wb') as f:
                f.write(buf.to_bytes())
            return True
        except IOError as e:
            log.error(f"Failed to write buffer: {e}")
            return False

    def run_cycle(self) -> bool:
        """Run one update cycle"""
        self.cycle += 1

        btc_cents, btc_vol, eth_cents, eth_vol, lcx_cents, lcx_vol = self.fetch_all_prices()

        if btc_cents == 0 or eth_cents == 0:
            log.warning(f"Cycle {self.cycle}: Invalid price data")
            return False

        buf = ExchangeBuffer()
        buf.timestamp = int(time.time())
        buf.btc_price_cents = btc_cents
        buf.btc_volume_sats = btc_vol
        buf.eth_price_cents = eth_cents
        buf.eth_volume_sats = eth_vol
        buf.lcx_price_cents = lcx_cents
        buf.lcx_volume_sats = lcx_vol
        buf.exchange_flags = COINBASE_VALID
        buf.last_tsc = int(time.time() * 1e9) & 0xFFFFFFFFFFFFFFFF

        success = self.write_buffer(buf)

        if success:
            lcx_info = f" LCX=${buf.lcx_price_cents/1_000_000:.5f}" if buf.lcx_price_cents > 0 else ""
            log.info(f"Cycle {self.cycle}: BTC=${buf.btc_price_cents/100:.2f} ETH=${buf.eth_price_cents/100:.2f}{lcx_info}")
            self.error_count = 0
        else:
            self.error_count += 1
            if self.error_count > 10:
                log.error(f"Too many errors ({self.error_count}), exiting")
                return False

        return success

    def run(self, interval_ms: float = 100) -> bool:
        """Run feeder loop"""
        log.info(f"Starting Coinbase feeder (interval={interval_ms}ms)")
        log.info(f"Products: BTC-USD, ETH-USD, LCX-USD")
        log.info(f"Buffer: {self.buffer_file}")

        try:
            while True:
                start = time.time()
                self.run_cycle()

                elapsed = (time.time() - start) * 1000
                sleep_time = max(0, interval_ms - elapsed)
                if sleep_time > 0:
                    time.sleep(sleep_time / 1000)
        except KeyboardInterrupt:
            log.info("Feeder stopped by user")
            return True
        except Exception as e:
            log.error(f"Feeder crashed: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description="Coinbase Price Feeder")
    parser.add_argument('--interval', type=float, default=100, help='Update interval (ms)')
    parser.add_argument('--buffer-file', default='/tmp/omnibus_coinbase_buffer.bin')
    parser.add_argument('--verbose', action='store_true')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    feeder = CoinbaseFeeder(buffer_file=args.buffer_file)
    success = feeder.run(args.interval)
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
