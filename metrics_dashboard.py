#!/usr/bin/env python3
"""
Phase 23: OmniBus Metrics Dashboard — Real-Time Terminal UI
============================================================

Reads multi-source price buffer from kraken_feeder.py and displays:
- Real-time BTC/ETH/LCX prices
- Arbitrage spreads across Kraken/Coinbase/LCX Exchange
- Price % change (vs 60s ago)
- Exchange status and update timestamps
- Feed statistics (cycle count, errors, uptime)

Usage:
    python3 metrics_dashboard.py

Requirements:
    None (uses curses from stdlib)

Display: 80×24 terminal with ANSI box drawing
"""

import curses
import struct
import time
import os
import sys
from collections import deque
from typing import Optional, Tuple, Dict

MULTI_SOURCE_FILE = "/tmp/omnibus_all_prices.bin"
REFRESH_MS = 500
WINDOW_SIZE = 60  # samples for % change (60 updates × 500ms ≈ 30sec)


class PriceTracker:
    """Tracks rolling window of prices for % change calculation"""

    def __init__(self, window_size=WINDOW_SIZE):
        self.window = deque(maxlen=window_size)
        self.last_price = 0

    def update(self, price: int) -> None:
        """Add price to rolling window (in cents or micro-cents)"""
        if price > 0:
            self.window.append(price)
            self.last_price = price

    def pct_change(self) -> float:
        """Return % change from oldest to newest sample"""
        if len(self.window) < 2:
            return 0.0
        oldest = self.window[0]
        newest = self.window[-1]
        if oldest == 0:
            return 0.0
        return ((newest - oldest) / oldest) * 100


class ArbScanner:
    """Detects arbitrage spread between exchanges"""

    def scan(self, kraken_uc: int, coinbase_uc: int, lcx_exch_uc: int) -> Tuple[float, float, str]:
        """
        Compare LCX prices across exchanges (micro-cents).
        Return: (max_price, min_price, opportunity_str)
        """
        prices = [p for p in [kraken_uc, coinbase_uc, lcx_exch_uc] if p > 0]

        if not prices:
            return 0, 0, "NO DATA"

        max_price = max(prices)
        min_price = min(prices)

        if min_price == 0:
            return max_price, min_price, "INCOMPLETE"

        spread_pct = ((max_price - min_price) / min_price) * 100

        if spread_pct > 0.5:
            return max_price, min_price, f"YES ({spread_pct:.2f}%)"
        else:
            return max_price, min_price, "LOW"


class Dashboard:
    """Terminal UI using curses"""

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.stdscr.nodelay(True)
        curses.curs_set(0)

        # Trackers
        self.btc_tracker = PriceTracker()
        self.eth_tracker = PriceTracker()
        self.lcx_tracker = PriceTracker()

        # Status
        self.last_read_time = 0
        self.file_exists = False
        self.last_update_ts = 0

        # Counters
        self.reads_successful = 0
        self.reads_failed = 0

    def read_buffer(self) -> Optional[Dict]:
        """Read 144-byte multi-source buffer"""
        try:
            if not os.path.exists(MULTI_SOURCE_FILE):
                self.file_exists = False
                return None

            self.file_exists = True

            with open(MULTI_SOURCE_FILE, 'rb') as f:
                data = f.read(144)

            if len(data) < 144:
                return None

            # Unpack: 9 Q + 4 I + 6 Q padding = 144 bytes
            values = struct.unpack('<Q Q Q Q Q Q Q Q Q I I I I Q Q Q Q Q Q Q', data)

            return {
                'timestamp': values[0],
                'kraken_btc_cents': values[1],
                'kraken_eth_cents': values[2],
                'kraken_lcx_uc': values[3],  # micro-cents
                'kraken_lcx_vol': values[4],
                'coinbase_lcx_uc': values[5],  # micro-cents
                'coinbase_lcx_vol': values[6],
                'lcxexch_lcx_uc': values[7],  # micro-cents
                'lcxexch_lcx_vol': values[8],
                'flags': values[9],
                'cycle_count': values[10],
                'error_count': values[11],
                'uptime_seconds': values[13],
            }
        except (IOError, struct.error, OSError):
            self.reads_failed += 1
            return None

    def render(self, data: Optional[Dict]) -> None:
        """Render dashboard to terminal"""
        self.stdscr.clear()
        h, w = self.stdscr.getmaxyx()

        # Check for quit
        try:
            ch = self.stdscr.getch()
            if ch == ord('q'):
                sys.exit(0)
        except:
            pass

        if not data:
            self.stdscr.addstr(2, 2, "⏳ Waiting for data from kraken_feeder.py...")
            self.stdscr.addstr(3, 2, f"File: {MULTI_SOURCE_FILE}")
            self.stdscr.refresh()
            return

        # Update trackers
        self.btc_tracker.update(data['kraken_btc_cents'])
        self.eth_tracker.update(data['kraken_eth_cents'])
        if data['kraken_lcx_uc'] > 0:
            self.lcx_tracker.update(data['kraken_lcx_uc'])

        self.reads_successful += 1
        self.last_read_time = time.time()

        # === HEADER ===
        now_str = time.strftime('%Y-%m-%d %H:%M:%S')
        header = f"OmniBus — Real-Time Metrics Dashboard   [{now_str}]"
        try:
            self.stdscr.addstr(0, 0, "╔" + "═" * (w - 2) + "╗")
            header_line = "║" + header[: w - 2].ljust(w - 2) + "║"
            self.stdscr.addstr(1, 0, header_line[: w - 1])
        except:
            pass  # Terminal too small

        # === PRICES SECTION ===
        row = 2
        self.stdscr.addstr(row, 0, "╠" + "═ PRICES (REAL DATA) " + "═" * (w - 22) + "╣")

        row += 1
        btc_change = self.btc_tracker.pct_change()
        btc_arrow = "▲" if btc_change > 0 else "▼" if btc_change < 0 else "─"
        btc_line = f"  BTC/USD   ${data['kraken_btc_cents']/100:>10,.2f}   Kraken  {btc_arrow}{abs(btc_change):+.2f}%"
        self.stdscr.addstr(row, 1, btc_line[: w - 2].ljust(w - 2))

        row += 1
        eth_change = self.eth_tracker.pct_change()
        eth_arrow = "▲" if eth_change > 0 else "▼" if eth_change < 0 else "─"
        eth_line = f"  ETH/USD   ${data['kraken_eth_cents']/100:>10,.2f}   Kraken  {eth_arrow}{abs(eth_change):+.2f}%"
        self.stdscr.addstr(row, 1, eth_line[: w - 2].ljust(w - 2))

        row += 1
        lcx_change = self.lcx_tracker.pct_change()
        lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
        lcx_price_str = f"${data['kraken_lcx_uc']/1_000_000:>10,.4f}" if data['kraken_lcx_uc'] > 0 else "N/A".rjust(10)
        lcx_line = f"  LCX/USD   {lcx_price_str}   Kraken  {lcx_arrow}{abs(lcx_change):+.2f}%"
        self.stdscr.addstr(row, 1, lcx_line[: w - 2].ljust(w - 2))

        # === ARBITRAGE SECTION ===
        row += 1
        self.stdscr.addstr(row, 0, "╠" + "═ ARBITRAGE SPREAD " + "═" * (w - 20) + "╣")

        row += 1
        scanner = ArbScanner()
        max_p, min_p, opp = scanner.scan(data['kraken_lcx_uc'], data['coinbase_lcx_uc'], data['lcxexch_lcx_uc'])

        kraken_str = f"${data['kraken_lcx_uc']/1_000_000:.4f}" if data['kraken_lcx_uc'] > 0 else "N/A"
        coinbase_str = f"${data['coinbase_lcx_uc']/1_000_000:.4f}" if data['coinbase_lcx_uc'] > 0 else "N/A"
        lcx_exch_str = f"${data['lcxexch_lcx_uc']/1_000_000:.4f}" if data['lcxexch_lcx_uc'] > 0 else "N/A"

        arb_line = f"  LCX  Kraken: {kraken_str:>8}  Coinbase: {coinbase_str:>8}  LCX Exch: {lcx_exch_str:>8}  Opportunity: {opp}"
        self.stdscr.addstr(row, 1, arb_line[: w - 2].ljust(w - 2))

        # === EXCHANGE STATUS ===
        row += 1
        self.stdscr.addstr(row, 0, "╠" + "═ EXCHANGE STATUS " + "═" * (w - 18) + "╣")

        row += 1
        flags = data['flags']
        kraken_status = "[ACTIVE]" if flags & 0x01 else "[OFFLINE]"
        coinbase_status = "[ACTIVE]" if flags & 0x02 else "[OFFLINE]"
        lcx_status = "[ACTIVE]" if flags & 0x04 else "[OFFLINE]"

        last_upd = time.time() - data['timestamp']
        upd_str = f"{last_upd:.1f}s" if last_upd < 60 else f"{last_upd/60:.1f}m"

        kraken_line = f"  Kraken      {kraken_status}  last update:  {upd_str}"
        self.stdscr.addstr(row, 1, kraken_line[: w - 2].ljust(w - 2))

        row += 1
        coinbase_line = f"  Coinbase    {coinbase_status}  last update:  {upd_str}"
        self.stdscr.addstr(row, 1, coinbase_line[: w - 2].ljust(w - 2))

        row += 1
        lcx_line = f"  LCX Exch    {lcx_status}  last update:  {upd_str}"
        self.stdscr.addstr(row, 1, lcx_line[: w - 2].ljust(w - 2))

        # === FEED STATS ===
        row += 1
        self.stdscr.addstr(row, 0, "╠" + "═ FEED STATS " + "═" * (w - 14) + "╣")

        row += 1
        uptime_h = data['uptime_seconds'] // 3600
        uptime_m = (data['uptime_seconds'] % 3600) // 60
        uptime_s = data['uptime_seconds'] % 60

        stats_line = f"  Cycle: {data['cycle_count']:>5}   Errors: {data['error_count']:>3}   Uptime: {uptime_h:02d}:{uptime_m:02d}:{uptime_s:02d}   Reads: {self.reads_successful}"
        self.stdscr.addstr(row, 1, stats_line[: w - 2].ljust(w - 2))

        # === FOOTER ===
        row += 1
        self.stdscr.addstr(row, 0, "╚" + "═" * (w - 2) + "╝")

        row += 1
        self.stdscr.addstr(row, 2, "Press 'q' to quit | Updates every 500ms")

        self.stdscr.refresh()

    def run(self) -> None:
        """Main dashboard loop"""
        while True:
            data = self.read_buffer()
            self.render(data)
            time.sleep(REFRESH_MS / 1000.0)


def main(stdscr):
    """Entry point"""
    dashboard = Dashboard(stdscr)
    dashboard.run()


if __name__ == '__main__':
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("\nDashboard stopped")
        sys.exit(0)
