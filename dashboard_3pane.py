#!/usr/bin/env python3
"""
Phase 23-d: 3-Pane Metrics Dashboard with Colors
=================================================

Real-time display of prices from all 3 exchanges side-by-side:
- Pane 0 (Left, Yellow): Kraken
- Pane 1 (Middle, Green): Coinbase
- Pane 2 (Right, Blue): LCX Exchange

Usage:
    python3 dashboard_3pane.py

Requirements:
    None (uses curses from stdlib)
"""

import curses
import struct
import time
import os
import sys
from collections import deque

# Buffer files from each feeder
KRAKEN_FILE = "/tmp/omnibus_kraken_buffer.bin"
COINBASE_FILE = "/tmp/omnibus_coinbase_buffer.bin"
LCX_FILE = "/tmp/omnibus_lcx_buffer.bin"

REFRESH_MS = 500
WINDOW_SIZE = 60


class ExchangeData:
    """Parse exchange buffer"""

    def __init__(self):
        self.btc = 0
        self.eth = 0
        self.lcx = 0
        self.timestamp = 0
        self.valid = False

    @classmethod
    def from_file(cls, filepath: str):
        """Read 72-byte buffer from file"""
        obj = cls()
        try:
            if not os.path.exists(filepath):
                return obj
            with open(filepath, 'rb') as f:
                data = f.read(72)
            if len(data) < 72:
                return obj
            values = struct.unpack('<Q Q Q Q Q I I Q Q Q', data)
            obj.timestamp = values[0]
            obj.btc = values[1]  # cents
            obj.eth = values[3]  # cents
            obj.lcx = values[8]  # cents
            obj.valid = obj.btc > 0 or obj.lcx > 0
            return obj
        except:
            return obj


class PriceTracker:
    """Rolling window for % change"""

    def __init__(self, window=60):
        self.window = deque(maxlen=window)

    def update(self, price: int) -> None:
        if price > 0:
            self.window.append(price)

    def pct_change(self) -> float:
        if len(self.window) < 2:
            return 0.0
        oldest = self.window[0]
        newest = self.window[-1]
        if oldest == 0:
            return 0.0
        return ((newest - oldest) / oldest) * 100


class Dashboard3Pane:
    """3-pane terminal dashboard with colors"""

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.stdscr.nodelay(True)
        curses.curs_set(0)

        # Initialize colors
        curses.init_pair(1, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # Kraken
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)   # Coinbase
        curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)    # LCX
        curses.init_pair(4, curses.COLOR_WHITE, curses.COLOR_BLACK)   # Default
        curses.init_pair(5, curses.COLOR_RED, curses.COLOR_BLACK)     # Error

        self.kraken_btc = PriceTracker()
        self.kraken_eth = PriceTracker()
        self.kraken_lcx = PriceTracker()

        self.coinbase_btc = PriceTracker()
        self.coinbase_eth = PriceTracker()
        self.coinbase_lcx = PriceTracker()

        self.lcx_lcx = PriceTracker()

    def render(self):
        """Render 3-pane dashboard"""
        self.stdscr.clear()
        h, w = self.stdscr.getmaxyx()

        # Quit on 'q'
        try:
            ch = self.stdscr.getch()
            if ch == ord('q'):
                sys.exit(0)
        except:
            pass

        # Read all buffers
        kraken = ExchangeData.from_file(KRAKEN_FILE)
        coinbase = ExchangeData.from_file(COINBASE_FILE)
        lcx_exch = ExchangeData.from_file(LCX_FILE)

        # Update trackers
        if kraken.btc > 0:
            self.kraken_btc.update(kraken.btc)
            self.kraken_eth.update(kraken.eth)
            self.kraken_lcx.update(kraken.lcx)

        if coinbase.btc > 0:
            self.coinbase_btc.update(coinbase.btc)
            self.coinbase_eth.update(coinbase.eth)
            self.coinbase_lcx.update(coinbase.lcx)

        if lcx_exch.lcx > 0:
            self.lcx_lcx.update(lcx_exch.lcx)

        # Pane width
        pane_w = w // 3 - 1

        # === HEADER ===
        now_str = time.strftime('%H:%M:%S')
        header = f"OmniBus 3-Exchange Dashboard [{now_str}]"
        self.stdscr.addstr(0, 0, header[:w].ljust(w), curses.color_pair(4) | curses.A_BOLD)

        # === KRAKEN PANE (Yellow) ===
        row = 2
        self.stdscr.addstr(row, 1, "╔ KRAKEN ╗", curses.color_pair(1) | curses.A_BOLD)
        row += 1
        if kraken.valid:
            btc_change = self.kraken_btc.pct_change()
            btc_arrow = "▲" if btc_change > 0 else "▼" if btc_change < 0 else "─"
            self.stdscr.addstr(row, 2, f"BTC ${kraken.btc/100:>10,.0f}"[:pane_w-2], curses.color_pair(1))
            row += 1
            self.stdscr.addstr(row, 2, f"  {btc_arrow}{abs(btc_change):+.1f}%"[:pane_w-2], curses.color_pair(1))
            row += 1
            eth_change = self.kraken_eth.pct_change()
            eth_arrow = "▲" if eth_change > 0 else "▼" if eth_change < 0 else "─"
            self.stdscr.addstr(row, 2, f"ETH ${kraken.eth/100:>10,.0f}"[:pane_w-2], curses.color_pair(1))
            row += 1
            self.stdscr.addstr(row, 2, f"  {eth_arrow}{abs(eth_change):+.1f}%"[:pane_w-2], curses.color_pair(1))
            row += 1
            lcx_change = self.kraken_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.stdscr.addstr(row, 2, f"LCX ${kraken.lcx/1_000_000:>10.5f}"[:pane_w-2], curses.color_pair(1))
            row += 1
            self.stdscr.addstr(row, 2, f"  {lcx_arrow}{abs(lcx_change):+.1f}%"[:pane_w-2], curses.color_pair(1))
        else:
            self.stdscr.addstr(row+2, 2, "NO DATA", curses.color_pair(5))

        # === COINBASE PANE (Green) ===
        row = 2
        col = pane_w + 2
        self.stdscr.addstr(row, col, "╔ COINBASE ╗", curses.color_pair(2) | curses.A_BOLD)
        row += 1
        if coinbase.valid:
            btc_change = self.coinbase_btc.pct_change()
            btc_arrow = "▲" if btc_change > 0 else "▼" if btc_change < 0 else "─"
            self.stdscr.addstr(row, col+1, f"BTC ${coinbase.btc/100:>10,.0f}"[:pane_w-2], curses.color_pair(2))
            row += 1
            self.stdscr.addstr(row, col+1, f"  {btc_arrow}{abs(btc_change):+.1f}%"[:pane_w-2], curses.color_pair(2))
            row += 1
            eth_change = self.coinbase_eth.pct_change()
            eth_arrow = "▲" if eth_change > 0 else "▼" if eth_change < 0 else "─"
            self.stdscr.addstr(row, col+1, f"ETH ${coinbase.eth/100:>10,.0f}"[:pane_w-2], curses.color_pair(2))
            row += 1
            self.stdscr.addstr(row, col+1, f"  {eth_arrow}{abs(eth_change):+.1f}%"[:pane_w-2], curses.color_pair(2))
            row += 1
            lcx_change = self.coinbase_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.stdscr.addstr(row, col+1, f"LCX ${coinbase.lcx/1_000_000:>10.5f}"[:pane_w-2], curses.color_pair(2))
            row += 1
            self.stdscr.addstr(row, col+1, f"  {lcx_arrow}{abs(lcx_change):+.1f}%"[:pane_w-2], curses.color_pair(2))
        else:
            self.stdscr.addstr(row+2, col+1, "NO DATA", curses.color_pair(5))

        # === LCX EXCHANGE PANE (Cyan) ===
        row = 2
        col = 2 * pane_w + 3
        self.stdscr.addstr(row, col, "╔ LCX EXCH ╗", curses.color_pair(3) | curses.A_BOLD)
        row += 1
        if lcx_exch.valid:
            lcx_change = self.lcx_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.stdscr.addstr(row, col+1, f"LCX ${lcx_exch.lcx/1_000_000:>10.5f}"[:pane_w-2], curses.color_pair(3))
            row += 1
            self.stdscr.addstr(row, col+1, f"  {lcx_arrow}{abs(lcx_change):+.1f}%"[:pane_w-2], curses.color_pair(3))
        else:
            self.stdscr.addstr(row+2, col+1, "NO DATA", curses.color_pair(5))

        # === FOOTER ===
        row = h - 2
        footer = "Press 'q' to quit | Updates every 500ms"
        self.stdscr.addstr(row, 1, footer[:w-2], curses.color_pair(4))

        self.stdscr.refresh()

    def run(self):
        """Main loop"""
        while True:
            self.render()
            time.sleep(REFRESH_MS / 1000.0)


def main(stdscr):
    """Entry point"""
    dashboard = Dashboard3Pane(stdscr)
    dashboard.run()


if __name__ == '__main__':
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("\nDashboard stopped")
        sys.exit(0)
