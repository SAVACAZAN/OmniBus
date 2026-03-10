#!/usr/bin/env python3
"""
Phase 22-c: Kraken Price Feeder for OmniBus
============================================

Fetches real BTC/ETH prices from Kraken REST API and writes to shared memory buffer @ 0x140000.
System runs in QEMU and reads prices via Analytics OS exchange_reader module.

Usage:
    python3 kraken_feeder.py          # Run with default QEMU GDB connection
    python3 kraken_feeder.py --file   # Run with shared memory file (alternative)

Requirements:
    pip install requests

Architecture:
    Kraken API (https://api.kraken.com/0/public/Ticker)
        ↓ Fetch BTC_USD, ETH_USD prices
        ↓ Convert to cents (BTC) and sats (volumes)
        ↓
    OmniBus Exchange Buffer @ 0x140000
        ↓ Analytics OS reads every cycle
        ↓ Injects into consensus engine
        ↓ Grid OS uses REAL market data for trading
"""

import requests
import struct
import time
import sys
import argparse
import logging
from typing import Optional, Dict, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

# Exchange buffer structure (must match exchange_reader.zig)
EXCHANGE_BUFFER_ADDR = 0x140000
EXCHANGE_BUFFER_SIZE = 56  # bytes

# Exchange flags
KRAKEN_VALID = 0x01
COINBASE_VALID = 0x02
LCX_VALID = 0x04

# Kraken API endpoints
KRAKEN_API_URL = "https://api.kraken.com/0/public/Ticker"
KRAKEN_PAIRS = {
    "XXBTZUSD": ("BTC", 0),  # BTC_USD
    "XETHZUSD": ("ETH", 1),  # ETH_USD
}

class ExchangeBuffer:
    """Represents the shared memory exchange buffer"""

    def __init__(self):
        self.timestamp = 0
        self.btc_price_cents = 0
        self.btc_volume_sats = 0
        self.eth_price_cents = 0
        self.eth_volume_sats = 0
        self.exchange_flags = 0
        self.last_tsc = 0

    def to_bytes(self) -> bytes:
        """Pack struct to bytes (little-endian)"""
        return struct.pack('<Q Q Q Q Q I I Q',
            self.timestamp,
            self.btc_price_cents,
            self.btc_volume_sats,
            self.eth_price_cents,
            self.eth_volume_sats,
            self.exchange_flags,
            0,  # reserved
            self.last_tsc
        )

    def __repr__(self):
        return (
            f"ExchangeBuffer(BTC=${self.btc_price_cents/100:.2f}, "
            f"ETH=${self.eth_price_cents/100:.2f}, "
            f"flags=0x{self.exchange_flags:02x})"
        )


class KrakenFeeder:
    """Fetches prices from Kraken and writes to OmniBus exchange buffer"""

    def __init__(self, use_file: bool = False, buffer_file: str = "/tmp/omnibus_exchange_buffer.bin"):
        self.use_file = use_file
        self.buffer_file = buffer_file
        self.session = requests.Session()
        self.cycle = 0
        self.last_error_time = 0
        self.error_count = 0

    def fetch_kraken_prices(self) -> Optional[Dict[str, Dict]]:
        """Fetch current prices from Kraken API"""
        try:
            # Request BTC and ETH tickers
            pairs = ",".join(KRAKEN_PAIRS.keys())
            response = self.session.get(
                KRAKEN_API_URL,
                params={"pair": pairs},
                timeout=5
            )
            response.raise_for_status()

            data = response.json()
            if data.get("error"):
                log.warning(f"Kraken API error: {data['error']}")
                return None

            return data.get("result", {})

        except requests.exceptions.RequestException as e:
            log.error(f"Kraken API fetch failed: {e}")
            self.error_count += 1
            return None

    def parse_prices(self, kraken_data: Dict[str, Dict]) -> Tuple[int, int, int, int]:
        """Parse Kraken response into price values"""
        btc_price_cents = 0
        btc_volume_sats = 0
        eth_price_cents = 0
        eth_volume_sats = 0

        try:
            # BTC_USD
            if "XXBTZUSD" in kraken_data:
                btc_data = kraken_data["XXBTZUSD"]
                # Last price in cents
                btc_price = float(btc_data["c"][0])  # c = last closed price
                btc_price_cents = int(btc_price * 100)

                # Volume in satoshis (volume is in BTC, convert to sats)
                btc_vol = float(btc_data["v"][0])  # v = volume
                btc_volume_sats = int(btc_vol * 1e8)  # 1 BTC = 1e8 satoshis

            # ETH_USD
            if "XETHZUSD" in kraken_data:
                eth_data = kraken_data["XETHZUSD"]
                eth_price = float(eth_data["c"][0])
                eth_price_cents = int(eth_price * 100)

                eth_vol = float(eth_data["v"][0])
                eth_volume_sats = int(eth_vol * 1e8)  # Use as proxy (actual wei conversion for later)

            return btc_price_cents, btc_volume_sats, eth_price_cents, eth_volume_sats

        except (KeyError, ValueError, IndexError) as e:
            log.error(f"Price parsing failed: {e}")
            return 0, 0, 0, 0

    def write_buffer_file(self, buf: ExchangeBuffer) -> bool:
        """Write buffer to file (alternative to GDB)"""
        try:
            with open(self.buffer_file, 'wb') as f:
                f.write(buf.to_bytes())
            return True
        except IOError as e:
            log.error(f"Failed to write buffer file: {e}")
            return False

    def write_buffer_gdb(self, buf: ExchangeBuffer) -> bool:
        """Write buffer via GDB memory write (requires GDB to be attached)"""
        try:
            # Format GDB command to write memory
            data = buf.to_bytes()
            hex_str = ' '.join(f"0x{b:02x}" for b in data)

            # This would require GDB to be running and accepting commands
            # For now, just log what would be written
            log.debug(f"Would write via GDB: {hex_str}")
            return False  # GDB integration not implemented yet

        except Exception as e:
            log.error(f"GDB write failed: {e}")
            return False

    def write_buffer(self, buf: ExchangeBuffer) -> bool:
        """Write exchange buffer to system"""
        if self.use_file:
            return self.write_buffer_file(buf)
        else:
            # Try GDB first, fall back to file
            if not self.write_buffer_gdb(buf):
                return self.write_buffer_file(buf)
            return True

    def run_cycle(self):
        """Run one update cycle: fetch prices, write buffer"""
        self.cycle += 1

        # Fetch from Kraken
        kraken_data = self.fetch_kraken_prices()
        if not kraken_data:
            log.warning(f"Cycle {self.cycle}: No price data from Kraken")
            return False

        # Parse prices
        btc_price_cents, btc_volume_sats, eth_price_cents, eth_volume_sats = \
            self.parse_prices(kraken_data)

        if btc_price_cents == 0 or eth_price_cents == 0:
            log.warning(f"Cycle {self.cycle}: Invalid price data")
            return False

        # Build exchange buffer
        buf = ExchangeBuffer()
        buf.timestamp = int(time.time())
        buf.btc_price_cents = btc_price_cents
        buf.btc_volume_sats = btc_volume_sats
        buf.eth_price_cents = eth_price_cents
        buf.eth_volume_sats = eth_volume_sats
        buf.exchange_flags = KRAKEN_VALID
        buf.last_tsc = int(time.time() * 1e9) & 0xFFFFFFFFFFFFFFFF  # Approximate TSC

        # Write to system
        success = self.write_buffer(buf)

        if success:
            log.info(f"Cycle {self.cycle}: {buf}")
            self.error_count = 0  # Reset error count on success
        else:
            self.error_count += 1
            if self.error_count > 10:
                log.error(f"Too many errors ({self.error_count}), exiting")
                return False

        return success

    def run(self, interval_ms: float = 100):
        """Run feeder loop"""
        log.info(f"Starting Kraken feeder (interval={interval_ms}ms)")
        log.info(f"Exchange buffer @ 0x{EXCHANGE_BUFFER_ADDR:x}")
        log.info(f"Using {'file' if self.use_file else 'GDB'} backend")

        try:
            while True:
                start = time.time()
                self.run_cycle()

                # Maintain interval
                elapsed = (time.time() - start) * 1000
                sleep_time = max(0, interval_ms - elapsed)
                if sleep_time > 0:
                    time.sleep(sleep_time / 1000)

        except KeyboardInterrupt:
            log.info("Feeder stopped by user")
        except Exception as e:
            log.error(f"Feeder crashed: {e}")
            return False

        return True


def main():
    parser = argparse.ArgumentParser(
        description="Kraken Price Feeder for OmniBus Exchange Integration"
    )
    parser.add_argument(
        '--file',
        action='store_true',
        help='Use file-based buffer instead of GDB'
    )
    parser.add_argument(
        '--interval',
        type=float,
        default=100,
        help='Update interval in milliseconds (default: 100ms)'
    )
    parser.add_argument(
        '--buffer-file',
        default='/tmp/omnibus_exchange_buffer.bin',
        help='Path to exchange buffer file (for file mode)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    feeder = KrakenFeeder(
        use_file=args.file,
        buffer_file=args.buffer_file
    )

    success = feeder.run(args.interval)
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
