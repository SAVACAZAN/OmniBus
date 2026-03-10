#!/usr/bin/env python3
"""
Phase 22-d/23: Multi-Exchange Price Feeder + Dashboard Support
==============================================================

Fetches real BTC/ETH/LCX prices from Kraken, LCX, and Coinbase REST APIs.
Writes to two buffers:
  1. 72-byte single-source buffer @ 0x140000 (OmniBus kernel)
  2. 144-byte multi-source buffer @ /tmp/omnibus_all_prices.bin (metrics_dashboard)

Usage:
    python3 kraken_feeder.py                  # Default: writes both buffers
    python3 kraken_feeder.py --file           # File-based only
    python3 kraken_feeder.py --no-lcx         # No LCX feeds
    python3 kraken_feeder.py --interval 100   # Custom interval (ms)

Requirements:
    pip install requests

Architecture:
    ╔═══════════════════════════════════════════════════╗
    ║  Kraken API  +  LCX API  +  Coinbase API          ║
    ║  BTC/ETH     LCX/USDC    LCX-USD                  ║
    ╚═══════════════════════════════════════════════════╝
        ↓ Fetch prices from 3 exchanges (micro-cents precision for LCX)
        ↓ Write 72-byte buffer (OmniBus kernel @ 0x140000)
        ↓ Write 144-byte multi-source buffer (dashboard @ /tmp/omnibus_all_prices.bin)
        ↓
    Analytics OS reads 72-byte buffer, injects into consensus
    metrics_dashboard.py reads 144-byte buffer, displays real-time UI
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

# Exchange buffer structure (extended for LCX)
# Layout: 56 bytes (BTC/ETH) + 16 bytes (LCX) = 72 bytes
EXCHANGE_BUFFER_ADDR = 0x140000
EXCHANGE_BUFFER_SIZE = 72  # Extended for LCX support

# Exchange flags
KRAKEN_VALID = 0x01
COINBASE_VALID = 0x02
LCX_VALID = 0x04

# Kraken API endpoints
KRAKEN_API_URL = "https://api.kraken.com/0/public/Ticker"
KRAKEN_PAIRS = {
    "XXBTZUSD": ("BTC", 0),      # BTC_USD @ Kraken
    "XETHZUSD": ("ETH", 1),      # ETH_USD @ Kraken
    "LCXUSD": ("LCX", 2),        # LCX_USD @ Kraken (Kraken's native pair name)
}

# Exchange-specific APIs for LCX
# Kraken: LCXUSD (already in KRAKEN_PAIRS above)
# Coinbase: LCX-USD ticker endpoint
COINBASE_LCX_URL = "https://api.exchange.coinbase.com/products/LCX-USD/ticker"

# LCX Exchange API (https://docs.lcx.com/)
LCX_EXCHANGE_BASE = "https://exchange-api.lcx.com"
LCX_EXCHANGE_TICKER_URL = f"{LCX_EXCHANGE_BASE}/api/ticker"  # Requires pair parameter
LCX_EXCHANGE_PAIR = "LCX/USDC"

class ExchangeBuffer:
    """Represents the shared memory exchange buffer (extended with LCX)"""

    def __init__(self):
        self.timestamp = 0
        # BTC prices and volume
        self.btc_price_cents = 0
        self.btc_volume_sats = 0
        # ETH prices and volume
        self.eth_price_cents = 0
        self.eth_volume_sats = 0
        # Exchange flags and reserved
        self.exchange_flags = 0
        self.reserved1 = 0
        self.last_tsc = 0
        # LCX prices and volume (extended)
        self.lcx_price_cents = 0
        self.lcx_volume_sats = 0

    def to_bytes(self) -> bytes:
        """Pack struct to bytes (little-endian) - 72 bytes total"""
        fmt = '<Q Q Q Q Q I I Q Q Q'
        args = (
            self.timestamp,           # 0x00-0x07: timestamp
            self.btc_price_cents,     # 0x08-0x0F: BTC cents
            self.btc_volume_sats,     # 0x10-0x17: BTC satoshis
            self.eth_price_cents,     # 0x18-0x1F: ETH cents
            self.eth_volume_sats,     # 0x20-0x27: ETH satoshis
            self.exchange_flags,      # 0x28-0x2B: flags
            self.reserved1,           # 0x2C-0x2F: reserved
            self.last_tsc,            # 0x30-0x37: TSC
            self.lcx_price_cents,     # 0x38-0x3F: LCX cents
            self.lcx_volume_sats      # 0x40-0x47: LCX units
        )
        result = struct.pack(fmt, *args)
        log.debug(f"ExchangeBuffer.to_bytes: format={fmt}, args_len={len(args)}, result_len={len(result)}")
        return result

    def __repr__(self):
        lcx_str = f", LCX=${self.lcx_price_cents/1_000_000:.5f}" if self.lcx_price_cents > 0 else ""
        return (
            f"ExchangeBuffer(BTC=${self.btc_price_cents/100:.2f}, "
            f"ETH=${self.eth_price_cents/100:.2f}{lcx_str}, "
            f"flags=0x{self.exchange_flags:02x})"
        )


class MultiSourceBuffer:
    """Extended buffer for metrics_dashboard.py (144 bytes, all 3 exchanges)"""

    def __init__(self):
        self.timestamp = 0
        # Kraken (BTC/ETH in cents, LCX in micro-cents)
        self.kraken_btc_cents = 0
        self.kraken_eth_cents = 0
        self.kraken_lcx_microcents = 0  # $0.0444 → 44400 μ¢
        self.kraken_lcx_vol = 0
        # Coinbase (LCX in micro-cents)
        self.coinbase_lcx_microcents = 0
        self.coinbase_lcx_vol = 0
        # LCX Exchange (LCX in micro-cents)
        self.lcxexch_lcx_microcents = 0
        self.lcxexch_lcx_vol = 0
        # Status
        self.flags = 0
        self.cycle_count = 0
        self.error_count = 0
        self.uptime_seconds = 0

    def to_bytes(self) -> bytes:
        """Pack to 144 bytes (little-endian)"""
        # Format: 9 Q (72) + 4 I (16) + 8 Q (64) = 152, so use only 6 Q for padding
        data = struct.pack('<Q Q Q Q Q Q Q Q Q I I I I Q',
            self.timestamp,                # Q @0
            self.kraken_btc_cents,         # Q @8
            self.kraken_eth_cents,         # Q @16
            self.kraken_lcx_microcents,    # Q @24
            self.kraken_lcx_vol,           # Q @32
            self.coinbase_lcx_microcents,  # Q @40
            self.coinbase_lcx_vol,         # Q @48
            self.lcxexch_lcx_microcents,   # Q @56
            self.lcxexch_lcx_vol,          # Q @64
            self.flags,                    # I @72
            self.cycle_count,              # I @76
            self.error_count,              # I @80
            0,                             # I pad @84
            self.uptime_seconds            # Q @88
        )
        # Pad to exactly 144 bytes: current is 96, need 48 more = 6 Q's
        data += struct.pack('<Q Q Q Q Q Q', 0, 0, 0, 0, 0, 0)
        return data


class MultiExchangeFeeder:
    """Fetches prices from Kraken, LCX, and Coinbase - writes to both OmniBus + dashboard buffers"""

    def __init__(self, use_file: bool = False, buffer_file: str = "/tmp/omnibus_kraken_buffer.bin",
                 include_lcx: bool = True, write_dashboard_buffer: bool = True):
        self.use_file = use_file
        self.buffer_file = buffer_file
        self.include_lcx = include_lcx
        self.write_dashboard_buffer = write_dashboard_buffer
        self.session = requests.Session()
        self.cycle = 0
        self.last_error_time = 0
        self.error_count = 0
        self.lcx_sources = {}  # Track which exchange provided LCX price
        self.start_time = time.time()  # For uptime tracking

    def fetch_kraken_prices(self) -> Optional[Dict[str, Dict]]:
        """Fetch current prices from Kraken API (BTC, ETH, LCX)"""
        try:
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
            return None

    def fetch_lcx_exchange_price(self) -> Optional[Tuple[int, int]]:
        """Fetch LCX/USDC price from LCX exchange API (https://docs.lcx.com/)"""
        try:
            # LCX Exchange ticker endpoint: /api/ticker?pair=LCX/USDC
            response = self.session.get(
                LCX_EXCHANGE_TICKER_URL,
                params={"pair": LCX_EXCHANGE_PAIR},
                timeout=5
            )
            response.raise_for_status()

            response_data = response.json()

            # LCX Exchange wraps response in {"status":"success", "data": {...}}
            if response_data.get("status") != "success":
                log.debug(f"LCX Exchange API error: {response_data.get('message')}")
                return None

            data = response_data.get("data", {})

            # Parse LCX/USDC ticker response
            # Available fields: lastPrice, last24Price, bestBid, bestAsk, volume, usdVolume
            lcx_price = None
            if "lastPrice" in data and data["lastPrice"] > 0:
                lcx_price = float(data["lastPrice"])
            elif "last24Price" in data and data["last24Price"] > 0:
                lcx_price = float(data["last24Price"])
            elif "equivalent" in data and data["equivalent"] > 0:
                lcx_price = float(data["equivalent"])
            elif "bestBid" in data and "bestAsk" in data:
                bid = float(data["bestBid"])
                ask = float(data["bestAsk"])
                if bid > 0 and ask > 0:
                    lcx_price = (bid + ask) / 2

            if lcx_price is None or lcx_price <= 0:
                log.debug(f"LCX exchange: invalid price data")
                return None

            lcx_price_cents = int(lcx_price * 1_000_000)  # micro-cents for precision
            lcx_volume = float(data.get("volume", 0))
            lcx_volume_units = int(lcx_volume * 1e8)

            log.debug(f"LCX/USDC @ LCX Exchange: ${lcx_price:.4f}")
            return (lcx_price_cents, lcx_volume_units)

        except requests.exceptions.RequestException as e:
            log.debug(f"LCX Exchange API fetch failed: {e}")
            return None
        except (KeyError, ValueError, TypeError) as e:
            log.debug(f"LCX Exchange API parse error: {e}")
            return None

    def fetch_coinbase_lcx_price(self) -> Optional[Tuple[int, int]]:
        """Fetch LCX-USD price from Coinbase ticker endpoint"""
        try:
            response = self.session.get(COINBASE_LCX_URL, timeout=5)
            response.raise_for_status()

            data = response.json()
            if "price" not in data:
                log.warning("Coinbase API: 'price' not found for LCX-USD")
                return None

            # Price is in USD, convert to cents
            price = float(data["price"])
            price_cents = int(price * 100)

            # Volume from Coinbase
            volume = float(data.get("volume", 0))
            volume_units = int(volume * 1e8)

            log.debug(f"LCX-USD @ Coinbase: ${price:.4f}")
            return (price_cents, volume_units)

        except requests.exceptions.RequestException as e:
            log.debug(f"Coinbase LCX-USD fetch failed: {e}")
            return None

    def parse_prices(self, kraken_data: Dict[str, Dict]) -> Tuple[int, int, int, int, int, int]:
        """Parse Kraken response into price values (BTC, ETH, LCX from Kraken)"""
        btc_price_cents = 0
        btc_volume_sats = 0
        eth_price_cents = 0
        eth_volume_sats = 0
        lcx_price_cents = 0
        lcx_volume_sats = 0

        try:
            # BTC_USD
            if "XXBTZUSD" in kraken_data:
                btc_data = kraken_data["XXBTZUSD"]
                btc_price = float(btc_data["c"][0])
                btc_price_cents = int(btc_price * 100)
                btc_vol = float(btc_data["v"][0])
                btc_volume_sats = int(btc_vol * 1e8)

            # ETH_USD
            if "XETHZUSD" in kraken_data:
                eth_data = kraken_data["XETHZUSD"]
                eth_price = float(eth_data["c"][0])
                eth_price_cents = int(eth_price * 100)
                eth_vol = float(eth_data["v"][0])
                eth_volume_sats = int(eth_vol * 1e8)

            # LCX_USD from Kraken (if available)
            if "LCXUSD" in kraken_data:
                lcx_data = kraken_data["LCXUSD"]
                lcx_price = float(lcx_data["c"][0])
                lcx_price_cents = int(lcx_price * 1_000_000)  # micro-cents for precision
                lcx_vol = float(lcx_data["v"][0])
                lcx_volume_sats = int(lcx_vol * 1e8)
                self.lcx_sources["kraken"] = lcx_price_cents

            return btc_price_cents, btc_volume_sats, eth_price_cents, eth_volume_sats, \
                   lcx_price_cents, lcx_volume_sats

        except (KeyError, ValueError, IndexError) as e:
            log.error(f"Price parsing failed: {e}")
            return 0, 0, 0, 0, 0, 0

    def write_buffer_file(self, buf: ExchangeBuffer) -> bool:
        """Write buffer to file (alternative to GDB)"""
        try:
            data = buf.to_bytes()
            log.debug(f"Writing {len(data)} bytes to {self.buffer_file}")
            with open(self.buffer_file, 'wb') as f:
                f.write(data)
            return True
        except IOError as e:
            log.error(f"Failed to write buffer file: {e}")
            return False

    def write_buffer_gdb(self, buf: ExchangeBuffer) -> bool:
        """Write buffer via GDB memory write (requires GDB to be attached)"""
        try:
            data = buf.to_bytes()
            hex_str = ' '.join(f"0x{b:02x}" for b in data)
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
            if not self.write_buffer_gdb(buf):
                return self.write_buffer_file(buf)
            return True

    def write_multi_source_buffer(self, kraken_btc: int, kraken_eth: int, kraken_lcx: int, kraken_lcx_vol: int,
                                  coinbase_lcx: int, coinbase_lcx_vol: int,
                                  lcxexch_lcx: int, lcxexch_lcx_vol: int, flags: int) -> bool:
        """Write multi-source buffer for metrics_dashboard.py (144 bytes)"""
        try:
            buf = MultiSourceBuffer()
            buf.timestamp = int(time.time())
            buf.kraken_btc_cents = kraken_btc
            buf.kraken_eth_cents = kraken_eth
            buf.kraken_lcx_microcents = kraken_lcx  # Already in micro-cents from conversion
            buf.kraken_lcx_vol = kraken_lcx_vol
            buf.coinbase_lcx_microcents = coinbase_lcx  # Already in micro-cents
            buf.coinbase_lcx_vol = coinbase_lcx_vol
            buf.lcxexch_lcx_microcents = lcxexch_lcx  # Already in micro-cents
            buf.lcxexch_lcx_vol = lcxexch_lcx_vol
            buf.flags = flags
            buf.cycle_count = self.cycle
            buf.error_count = self.error_count
            buf.uptime_seconds = int(time.time() - self.start_time)

            data = buf.to_bytes()
            with open('/tmp/omnibus_all_prices.bin', 'wb') as f:
                f.write(data)
            return True
        except IOError as e:
            log.debug(f"Failed to write multi-source buffer: {e}")
            return False

    def run_cycle(self):
        """Run one update cycle: fetch prices from multiple exchanges, write buffer"""
        self.cycle += 1
        self.lcx_sources.clear()

        # Fetch from Kraken (BTC, ETH, optionally LCX)
        kraken_data = self.fetch_kraken_prices()
        if not kraken_data:
            log.warning(f"Cycle {self.cycle}: No price data from Kraken")
            return False

        # Parse prices from Kraken
        btc_price_cents, btc_volume_sats, eth_price_cents, eth_volume_sats, \
            lcx_price_cents, lcx_volume_sats = self.parse_prices(kraken_data)

        if btc_price_cents == 0 or eth_price_cents == 0:
            log.warning(f"Cycle {self.cycle}: Invalid price data")
            return False

        # Fetch LCX from multiple sources with smart priority
        # Priority: Kraken (already fetched) → Coinbase → LCX Exchange
        exchange_flags = KRAKEN_VALID
        lcx_source_name = None

        if self.include_lcx:
            # If we got LCX from Kraken, use it
            if lcx_price_cents > 0 and "kraken" in self.lcx_sources:
                lcx_source_name = "Kraken"
            # Else try Coinbase
            elif lcx_result := self.fetch_coinbase_lcx_price():
                if lcx_result[0] > 0:
                    lcx_price_cents, lcx_volume_sats = lcx_result
                    exchange_flags |= COINBASE_VALID
                    lcx_source_name = "Coinbase"
                    self.lcx_sources["coinbase"] = lcx_price_cents

            # Else try LCX Exchange
            if lcx_source_name is None:
                lcx_result = self.fetch_lcx_exchange_price()
                if lcx_result and lcx_result[0] > 0:
                    lcx_price_cents, lcx_volume_sats = lcx_result
                    exchange_flags |= LCX_VALID
                    lcx_source_name = "LCX Exchange"
                    self.lcx_sources["lcx_exchange"] = lcx_price_cents

        # Build exchange buffer (72 bytes for OmniBus kernel)
        buf = ExchangeBuffer()
        buf.timestamp = int(time.time())
        buf.btc_price_cents = btc_price_cents
        buf.btc_volume_sats = btc_volume_sats
        buf.eth_price_cents = eth_price_cents
        buf.eth_volume_sats = eth_volume_sats
        buf.lcx_price_cents = lcx_price_cents
        buf.lcx_volume_sats = lcx_volume_sats
        buf.exchange_flags = exchange_flags
        buf.last_tsc = int(time.time() * 1e9) & 0xFFFFFFFFFFFFFFFF

        # Write to system
        success = self.write_buffer(buf)

        # Also write multi-source buffer for metrics_dashboard (144 bytes)
        # Convert LCX cents to micro-cents for precision ($0.044 → 44000 μ¢)
        if self.write_dashboard_buffer:
            kraken_lcx_mc = int(float(lcx_price_cents) * 10000) if lcx_price_cents > 0 else 0
            coinbase_lcx_mc = int(float(lcx_price_cents) * 10000) if "coinbase" in self.lcx_sources else 0
            lcxexch_lcx_mc = int(float(lcx_price_cents) * 10000) if "lcx_exchange" in self.lcx_sources else 0

            self.write_multi_source_buffer(
                btc_price_cents, eth_price_cents,
                kraken_lcx_mc, lcx_volume_sats,
                coinbase_lcx_mc, lcx_volume_sats,
                lcxexch_lcx_mc, lcx_volume_sats,
                exchange_flags
            )

        if success:
            lcx_info = ""
            if buf.lcx_price_cents > 0 and lcx_source_name:
                lcx_info = f" LCX=${buf.lcx_price_cents/1_000_000:.5f}({lcx_source_name})"
            log.info(f"Cycle {self.cycle}: BTC=${buf.btc_price_cents/100:.2f} ETH=${buf.eth_price_cents/100:.2f}{lcx_info}")
            self.error_count = 0
        else:
            self.error_count += 1
            if self.error_count > 10:
                log.error(f"Too many errors ({self.error_count}), exiting")
                return False

        return success

    def run(self, interval_ms: float = 100):
        """Run feeder loop"""
        log.info(f"Starting multi-exchange feeder (interval={interval_ms}ms)")
        log.info(f"Exchange buffer @ 0x{EXCHANGE_BUFFER_ADDR:x} (72 bytes)")
        if self.include_lcx:
            log.info(f"Assets: BTC (Kraken), ETH (Kraken), LCX (Kraken→Coinbase→LCX Exchange)")
        else:
            log.info(f"Assets: BTC (Kraken), ETH (Kraken)")
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


# Backward compatibility alias
KrakenFeeder = MultiExchangeFeeder


def main():
    parser = argparse.ArgumentParser(
        description="Multi-Exchange Price Feeder for OmniBus (Kraken + LCX + Coinbase)"
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
        default='/tmp/omnibus_kraken_buffer.bin',
        help='Path to exchange buffer file (for file mode)'
    )
    parser.add_argument(
        '--no-lcx',
        action='store_true',
        help='Disable LCX price feeds (only fetch BTC/ETH)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    feeder = MultiExchangeFeeder(
        use_file=args.file,
        buffer_file=args.buffer_file,
        include_lcx=not args.no_lcx
    )

    success = feeder.run(args.interval)
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
