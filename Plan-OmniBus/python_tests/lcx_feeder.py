#!/usr/bin/env python3
"""
Phase 23-c: LCX Exchange Price Feeder for OmniBus
==================================================

Fetches real LCX/USDC prices from LCX Exchange REST API.
Writes to shared memory buffer @ 0x140000.

Usage:
    python3 lcx_feeder.py          # Run with file-based buffer
    python3 lcx_feeder.py --interval 100

Requirements:
    pip install requests

API: https://docs.lcx.com/
Endpoint: https://exchange-api.lcx.com/api/ticker?pair=LCX/USDC
"""

import mmap
import os
import requests
import struct
import time
import sys
import argparse
import logging
from typing import Optional, Tuple

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

# LCX Exchange API (https://docs.lcx.com/)
LCX_EXCHANGE_BASE = "https://exchange-api.lcx.com"
LCX_TICKER_URL = f"{LCX_EXCHANGE_BASE}/api/ticker"


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
        btc = f"BTC=${self.btc_price_cents/100:.2f}" if self.btc_price_cents > 0 else "BTC=N/A"
        eth = f"ETH=${self.eth_price_cents/100:.2f}" if self.eth_price_cents > 0 else "ETH=N/A"
        lcx = f"LCX=${self.lcx_price_cents/1_000_000:.5f}" if self.lcx_price_cents > 0 else "LCX=N/A"
        return (
            f"ExchangeBuffer({btc}, {eth}, {lcx}, "
            f"flags=0x{self.exchange_flags:02x})"
        )


class LCXExchangeFeeder:
    """Fetches prices from LCX Exchange API"""

    # LCX Exchange buffer at 0x142000 (Kraken=0x140000, Coinbase=0x141000)
    KERNEL_BUFFER_ADDR = 0x142000

    def __init__(self, buffer_file: str = "/tmp/omnibus_lcx_buffer.bin",
                 shm_file: str = ""):
        self.buffer_file = buffer_file
        self.shm_file = shm_file
        self._shm_mm: mmap.mmap | None = None
        self.session = requests.Session()
        self.cycle = 0
        self.error_count = 0
        self.start_time = time.time()

    def fetch_price(self, pair: str) -> Optional[Tuple[int, int]]:
        """Fetch price for a pair from LCX Exchange"""
        try:
            response = self.session.get(
                LCX_TICKER_URL,
                params={"pair": pair},
                timeout=5
            )
            response.raise_for_status()

            data = response.json()

            if data.get("status") != "success":
                log.debug(f"LCX API error for {pair}: {data.get('message')}")
                return None

            ticker = data.get("data", {})

            # Extract price (prioritize lastPrice)
            price = None
            if "lastPrice" in ticker and ticker["lastPrice"] > 0:
                price = float(ticker["lastPrice"])
            elif "equivalent" in ticker and ticker["equivalent"] > 0:
                price = float(ticker["equivalent"])
            elif "bestBid" in ticker and "bestAsk" in ticker:
                bid = float(ticker["bestBid"])
                ask = float(ticker["bestAsk"])
                if bid > 0 and ask > 0:
                    price = (bid + ask) / 2

            if price is None or price <= 0:
                log.debug(f"{pair}: invalid price data")
                return None

            # BTC/ETH: store as cents (×100)
            # LCX: store as micro-cents (×1,000,000) for precision
            if pair.startswith("LCX"):
                price_cents = int(price * 1_000_000)  # micro-cents
            else:
                price_cents = int(price * 100)  # cents

            volume = float(ticker.get("volume", 0))
            vol_units = int(volume * 1e8)

            log.debug(f"{pair} @ LCX Exchange: ${price:.5f}")
            return (price_cents, vol_units)

        except requests.exceptions.RequestException as e:
            log.debug(f"LCX Exchange fetch failed for {pair}: {e}")
            return None
        except (KeyError, ValueError, TypeError) as e:
            log.debug(f"LCX Exchange parse error for {pair}: {e}")
            return None

    def write_buffer_shm(self, buf: ExchangeBuffer) -> bool:
        """Write to QEMU shared memory at 0x142000"""
        try:
            if not self.shm_file or not os.path.exists(self.shm_file):
                return False
            if self._shm_mm is None:
                fd = open(self.shm_file, 'r+b')
                self._shm_mm = mmap.mmap(fd.fileno(), 0)
            data = buf.to_bytes()
            self._shm_mm.seek(self.KERNEL_BUFFER_ADDR)
            self._shm_mm.write(data)
            self._shm_mm.flush()
            with open(self.buffer_file, 'wb') as f:
                f.write(data)
            return True
        except Exception as e:
            log.error(f"SHM write failed: {e}")
            self._shm_mm = None
            return False

    def write_buffer(self, buf: ExchangeBuffer) -> bool:
        """Write buffer (SHM if available, else file)"""
        if self.shm_file:
            return self.write_buffer_shm(buf)
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

        # Fetch all three prices
        btc_result = self.fetch_price("BTC/USDC")
        eth_result = self.fetch_price("ETH/USDC")
        lcx_result = self.fetch_price("LCX/USDC")

        # Check if we got at least LCX data
        if not lcx_result:
            log.warning(f"Cycle {self.cycle}: No price data from LCX Exchange")
            return False

        btc_cents, btc_vol = btc_result if btc_result else (0, 0)
        eth_cents, eth_vol = eth_result if eth_result else (0, 0)
        lcx_cents, lcx_vol = lcx_result if lcx_result else (0, 0)

        buf = ExchangeBuffer()
        buf.timestamp = int(time.time())
        buf.btc_price_cents = btc_cents
        buf.btc_volume_sats = btc_vol
        buf.eth_price_cents = eth_cents
        buf.eth_volume_sats = eth_vol
        buf.lcx_price_cents = lcx_cents
        buf.lcx_volume_sats = lcx_vol
        buf.exchange_flags = LCX_VALID
        buf.last_tsc = int(time.time() * 1e9) & 0xFFFFFFFFFFFFFFFF

        success = self.write_buffer(buf)

        if success:
            btc_str = f"BTC=${buf.btc_price_cents/100:.2f}" if buf.btc_price_cents > 0 else "BTC=N/A"
            eth_str = f"ETH=${buf.eth_price_cents/100:.2f}" if buf.eth_price_cents > 0 else "ETH=N/A"
            lcx_str = f"LCX=${buf.lcx_price_cents/1_000_000:.5f}" if buf.lcx_price_cents > 0 else "LCX=N/A"
            log.info(f"Cycle {self.cycle}: {btc_str} {eth_str} {lcx_str}")
            self.error_count = 0
        else:
            self.error_count += 1
            if self.error_count > 10:
                log.error(f"Too many errors ({self.error_count}), exiting")
                return False

        return success

    def run(self, interval_ms: float = 100) -> bool:
        """Run feeder loop"""
        log.info(f"Starting LCX Exchange feeder (interval={interval_ms}ms)")
        log.info(f"Pairs: BTC/USDC, ETH/USDC, LCX/USDC")
        if self.shm_file:
            log.info(f"SHM backend → {self.shm_file} (0x{self.KERNEL_BUFFER_ADDR:X})")
        else:
            log.info(f"File backend → {self.buffer_file}")

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
    parser = argparse.ArgumentParser(description="LCX Exchange Price Feeder")
    parser.add_argument('--interval', type=float, default=100, help='Update interval (ms)')
    parser.add_argument('--buffer-file', default='/tmp/omnibus_lcx_buffer.bin')
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--shm', default='', metavar='SHM_FILE',
                        help='QEMU memory-backend-file path for live kernel injection at 0x142000')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    feeder = LCXExchangeFeeder(buffer_file=args.buffer_file, shm_file=args.shm)
    success = feeder.run(args.interval)
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
