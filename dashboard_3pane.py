#!/usr/bin/env python3
"""
Phase 14: 3-Pane Dashboard + Real-Time Arbitrage Monitor
=========================================================

Real-time display of prices from all 3 exchanges + live arbitrage detection:
- Pane 0 (Left, Yellow): Kraken
- Pane 1 (Middle, Green): Coinbase
- Pane 2 (Right, Cyan): LCX Exchange
- Bottom: Arbitrage opportunities + cumulative P&L tracking

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
import argparse
from collections import deque

# Buffer files from each feeder
KRAKEN_FILE = "/tmp/omnibus_kraken_buffer.bin"
COINBASE_FILE = "/tmp/omnibus_coinbase_buffer.bin"
LCX_FILE = "/tmp/omnibus_lcx_buffer.bin"

REFRESH_MS = 500
WINDOW_SIZE = 60

# Optional SHM file for kernel metrics (set via --shm flag)
SHM_FILE = ""

# Kernel metrics reader (optional — only when SHM file is given)
try:
    from shm_reader import ShmMetricsReader
    _SHM_READER_AVAILABLE = True
except ImportError:
    _SHM_READER_AVAILABLE = False

# Exchange fees (maker+taker combined, conservative)
KRAKEN_FEE   = 0.0026   # 0.26%
COINBASE_FEE = 0.0040   # 0.40%
LCX_FEE      = 0.0010   # 0.10%

# Min spread (bps) to report as opportunity
MIN_SPREAD_BPS = 10      # 0.10% gross minimum


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


class ArbOpportunity:
    """Single arbitrage opportunity snapshot"""

    def __init__(self, pair, buy_ex, sell_ex, buy_price_cents, sell_price_cents, fee_total):
        self.pair = pair
        self.buy_ex = buy_ex
        self.sell_ex = sell_ex
        self.buy_price = buy_price_cents
        self.sell_price = sell_price_cents
        if buy_price_cents > 0:
            self.gross_bps = int(((sell_price_cents - buy_price_cents) / buy_price_cents) * 10000)
        else:
            self.gross_bps = 0
        self.net_bps = self.gross_bps - int(fee_total * 10000)
        self.profitable = self.net_bps > 50   # >0.5% net = actionable


class ArbTracker:
    """Tracks arbitrage opportunities across all exchange pairs"""

    def __init__(self):
        self.opportunities_count = 0
        self.profitable_count = 0
        self.cumulative_net_bps = 0
        self.best_bps = 0
        self.best_pair = ""
        self.best_pair_hist: deque = deque(maxlen=5)   # last 5 profitable arbs
        self.start_time = time.time()

    def scan(self, kraken: ExchangeData, coinbase: ExchangeData, lcx_exch: ExchangeData):
        """Scan all pairs and return best opportunity for each asset"""
        best_btc: ArbOpportunity | None = None
        best_eth: ArbOpportunity | None = None
        best_lcx: ArbOpportunity | None = None

        # --- BTC arbitrage ---
        candidates_btc = []
        if kraken.btc > 0 and coinbase.btc > 0:
            fee = KRAKEN_FEE + COINBASE_FEE
            if kraken.btc < coinbase.btc:
                candidates_btc.append(ArbOpportunity("BTC", "Kraken", "Coinbase", kraken.btc, coinbase.btc, fee))
            else:
                candidates_btc.append(ArbOpportunity("BTC", "Coinbase", "Kraken", coinbase.btc, kraken.btc, fee))
        if kraken.btc > 0 and lcx_exch.btc > 0:
            fee = KRAKEN_FEE + LCX_FEE
            if kraken.btc < lcx_exch.btc:
                candidates_btc.append(ArbOpportunity("BTC", "Kraken", "LCX", kraken.btc, lcx_exch.btc, fee))
            else:
                candidates_btc.append(ArbOpportunity("BTC", "LCX", "Kraken", lcx_exch.btc, kraken.btc, fee))
        if coinbase.btc > 0 and lcx_exch.btc > 0:
            fee = COINBASE_FEE + LCX_FEE
            if coinbase.btc < lcx_exch.btc:
                candidates_btc.append(ArbOpportunity("BTC", "Coinbase", "LCX", coinbase.btc, lcx_exch.btc, fee))
            else:
                candidates_btc.append(ArbOpportunity("BTC", "LCX", "Coinbase", lcx_exch.btc, coinbase.btc, fee))
        if candidates_btc:
            best_btc = max(candidates_btc, key=lambda o: o.net_bps)

        # --- ETH arbitrage ---
        candidates_eth = []
        if kraken.eth > 0 and coinbase.eth > 0:
            fee = KRAKEN_FEE + COINBASE_FEE
            if kraken.eth < coinbase.eth:
                candidates_eth.append(ArbOpportunity("ETH", "Kraken", "Coinbase", kraken.eth, coinbase.eth, fee))
            else:
                candidates_eth.append(ArbOpportunity("ETH", "Coinbase", "Kraken", coinbase.eth, kraken.eth, fee))
        if candidates_eth:
            best_eth = max(candidates_eth, key=lambda o: o.net_bps)

        # --- LCX arbitrage (Kraken LCX vs LCX Exchange LCX) ---
        if kraken.lcx > 0 and lcx_exch.lcx > 0:
            fee = KRAKEN_FEE + LCX_FEE
            if kraken.lcx < lcx_exch.lcx:
                best_lcx = ArbOpportunity("LCX", "Kraken", "LCX", kraken.lcx, lcx_exch.lcx, fee)
            else:
                best_lcx = ArbOpportunity("LCX", "LCX", "Kraken", lcx_exch.lcx, kraken.lcx, fee)

        # Track stats
        for opp in [best_btc, best_eth, best_lcx]:
            if opp and opp.gross_bps >= MIN_SPREAD_BPS:
                self.opportunities_count += 1
                self.cumulative_net_bps += max(0, opp.net_bps)
                if opp.profitable:
                    self.profitable_count += 1
                    if opp.net_bps > self.best_bps:
                        self.best_bps = opp.net_bps
                        self.best_pair = f"{opp.pair}:{opp.buy_ex[:3]}→{opp.sell_ex[:3]}"
                    self.best_pair_hist.append(
                        f"{opp.pair} {opp.buy_ex[:3]}→{opp.sell_ex[:3]} +{opp.net_bps}bps"
                    )

        return best_btc, best_eth, best_lcx


class Dashboard3Pane:
    """3-pane terminal dashboard with colors + arbitrage monitor"""

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.stdscr.nodelay(True)
        curses.curs_set(0)

        # Colors
        curses.init_pair(1, curses.COLOR_YELLOW, curses.COLOR_BLACK)   # Kraken
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)    # Coinbase
        curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)     # LCX
        curses.init_pair(4, curses.COLOR_WHITE, curses.COLOR_BLACK)    # Default
        curses.init_pair(5, curses.COLOR_RED, curses.COLOR_BLACK)      # Error/loss
        curses.init_pair(6, curses.COLOR_MAGENTA, curses.COLOR_BLACK)  # Arb header
        curses.init_pair(7, curses.COLOR_GREEN, curses.COLOR_BLACK)    # Profitable arb

        self.kraken_btc = PriceTracker()
        self.kraken_eth = PriceTracker()
        self.kraken_lcx = PriceTracker()

        self.coinbase_btc = PriceTracker()
        self.coinbase_eth = PriceTracker()
        self.coinbase_lcx = PriceTracker()

        self.lcx_lcx = PriceTracker()

        self.arb = ArbTracker()

        # Kernel metrics reader (SHM mode only)
        self._shm_reader = None
        if SHM_FILE and _SHM_READER_AVAILABLE:
            self._shm_reader = ShmMetricsReader(SHM_FILE)

    def safe_addstr(self, row, col, text, attr=0):
        """Safely add string to curses window"""
        try:
            h, w = self.stdscr.getmaxyx()
            if row >= 0 and row < h and col >= 0 and col < w:
                self.stdscr.addstr(row, col, text[:max(1, w-col-1)], attr)
        except:
            pass

    def _fmt_arb(self, opp: ArbOpportunity | None) -> tuple[str, int]:
        """Format arb opportunity → (text, color_pair)"""
        if opp is None:
            return "  ---", curses.color_pair(4)
        gross = opp.gross_bps / 100
        net = opp.net_bps / 100
        arrow = "✓" if opp.profitable else "✗"
        color = curses.color_pair(7) if opp.profitable else curses.color_pair(5)
        text = f"  {arrow} {opp.buy_ex[:3]}→{opp.sell_ex[:3]}  gross:{gross:+.2f}%  net:{net:+.2f}%"
        return text, color

    def render(self):
        """Render dashboard"""
        try:
            self.stdscr.clear()
        except:
            return

        try:
            h, w = self.stdscr.getmaxyx()
        except:
            return

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

        # Update price trackers
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

        # Run arbitrage scan
        best_btc, best_eth, best_lcx = self.arb.scan(kraken, coinbase, lcx_exch)

        pane_w = w // 3 - 1

        # === HEADER ===
        now_str = time.strftime('%H:%M:%S')
        uptime = int(time.time() - self.arb.start_time)
        header = f"OmniBus Multi-Exchange Dashboard [{now_str}] uptime:{uptime}s"
        self.safe_addstr(0, 0, header[:w].ljust(w), curses.color_pair(4) | curses.A_BOLD)

        # === KRAKEN PANE (Yellow) ===
        row = 2
        self.safe_addstr(row, 1, "╔ KRAKEN ╗", curses.color_pair(1) | curses.A_BOLD)
        row += 1
        if kraken.valid:
            btc_change = self.kraken_btc.pct_change()
            btc_arrow = "▲" if btc_change > 0 else "▼" if btc_change < 0 else "─"
            self.safe_addstr(row, 2, f"BTC ${kraken.btc/100:>10,.0f}", curses.color_pair(1))
            row += 1
            self.safe_addstr(row, 2, f"  {btc_arrow}{abs(btc_change):+.1f}%", curses.color_pair(1))
            row += 1
            eth_change = self.kraken_eth.pct_change()
            eth_arrow = "▲" if eth_change > 0 else "▼" if eth_change < 0 else "─"
            self.safe_addstr(row, 2, f"ETH ${kraken.eth/100:>10,.0f}", curses.color_pair(1))
            row += 1
            self.safe_addstr(row, 2, f"  {eth_arrow}{abs(eth_change):+.1f}%", curses.color_pair(1))
            row += 1
            lcx_change = self.kraken_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.safe_addstr(row, 2, f"LCX ${kraken.lcx/1_000_000:.4f}", curses.color_pair(1))
            row += 1
            self.safe_addstr(row, 2, f"  {lcx_arrow}{abs(lcx_change):+.1f}%", curses.color_pair(1))
        else:
            self.safe_addstr(row+2, 2, "NO DATA", curses.color_pair(5))

        # === COINBASE PANE (Green) ===
        row = 2
        col = pane_w + 2
        self.safe_addstr(row, col, "╔ COINBASE ╗", curses.color_pair(2) | curses.A_BOLD)
        row += 1
        if coinbase.valid:
            btc_change = self.coinbase_btc.pct_change()
            btc_arrow = "▲" if btc_change > 0 else "▼" if btc_change < 0 else "─"
            self.safe_addstr(row, col+1, f"BTC ${coinbase.btc/100:>10,.0f}", curses.color_pair(2))
            row += 1
            self.safe_addstr(row, col+1, f"  {btc_arrow}{abs(btc_change):+.1f}%", curses.color_pair(2))
            row += 1
            eth_change = self.coinbase_eth.pct_change()
            eth_arrow = "▲" if eth_change > 0 else "▼" if eth_change < 0 else "─"
            self.safe_addstr(row, col+1, f"ETH ${coinbase.eth/100:>10,.0f}", curses.color_pair(2))
            row += 1
            self.safe_addstr(row, col+1, f"  {eth_arrow}{abs(eth_change):+.1f}%", curses.color_pair(2))
            row += 1
            lcx_change = self.coinbase_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.safe_addstr(row, col+1, f"LCX ${coinbase.lcx/1_000_000:.4f}", curses.color_pair(2))
            row += 1
            self.safe_addstr(row, col+1, f"  {lcx_arrow}{abs(lcx_change):+.1f}%", curses.color_pair(2))
        else:
            self.safe_addstr(row+2, col+1, "NO DATA", curses.color_pair(5))

        # === LCX EXCHANGE PANE (Cyan) ===
        row = 2
        col = 2 * pane_w + 3
        self.safe_addstr(row, col, "╔ LCX EXCH ╗", curses.color_pair(3) | curses.A_BOLD)
        row += 1
        if lcx_exch.valid:
            lcx_change = self.lcx_lcx.pct_change()
            lcx_arrow = "▲" if lcx_change > 0 else "▼" if lcx_change < 0 else "─"
            self.safe_addstr(row, col+1, f"BTC ${lcx_exch.btc/100:>10,.0f}", curses.color_pair(3))
            row += 1
            self.safe_addstr(row, col+1, f"  ETH ${lcx_exch.eth/100:>10,.0f}", curses.color_pair(3))
            row += 1
            self.safe_addstr(row, col+1, f"LCX ${lcx_exch.lcx/1_000_000:.4f}", curses.color_pair(3))
            row += 1
            self.safe_addstr(row, col+1, f"  {lcx_arrow}{abs(lcx_change):+.1f}%", curses.color_pair(3))
        else:
            self.safe_addstr(row+2, col+1, "NO DATA", curses.color_pair(5))

        # === ARBITRAGE MONITOR (bottom section) ===
        arb_row = 11  # Below price panes
        sep = "═" * (w - 2)
        self.safe_addstr(arb_row, 1, sep, curses.color_pair(6))
        arb_row += 1

        title = f"  ARB MONITOR  │  scans:{self.arb.opportunities_count}  profitable:{self.arb.profitable_count}  best:{self.arb.best_bps}bps  record:{self.arb.best_pair}"
        self.safe_addstr(arb_row, 0, title, curses.color_pair(6) | curses.A_BOLD)
        arb_row += 1

        # BTC opportunities
        self.safe_addstr(arb_row, 2, "BTC:", curses.color_pair(4) | curses.A_BOLD)
        if best_btc:
            txt, color = self._fmt_arb(best_btc)
            self.safe_addstr(arb_row, 6, txt, color)
            if best_btc.buy_price > 0 and best_btc.profitable:
                profit_usd = (best_btc.net_bps / 10000) * (best_btc.buy_price / 100)
                self.safe_addstr(arb_row, min(55, w-20), f"  ~${profit_usd:.0f}/BTC", curses.color_pair(7))
        else:
            self.safe_addstr(arb_row, 6, "  waiting for data...", curses.color_pair(4))
        arb_row += 1

        # ETH opportunities
        self.safe_addstr(arb_row, 2, "ETH:", curses.color_pair(4) | curses.A_BOLD)
        if best_eth:
            txt, color = self._fmt_arb(best_eth)
            self.safe_addstr(arb_row, 6, txt, color)
            if best_eth.buy_price > 0 and best_eth.profitable:
                profit_usd = (best_eth.net_bps / 10000) * (best_eth.buy_price / 100)
                self.safe_addstr(arb_row, min(55, w-20), f"  ~${profit_usd:.2f}/ETH", curses.color_pair(7))
        else:
            self.safe_addstr(arb_row, 6, "  waiting for data...", curses.color_pair(4))
        arb_row += 1

        # LCX opportunities
        self.safe_addstr(arb_row, 2, "LCX:", curses.color_pair(4) | curses.A_BOLD)
        if best_lcx:
            txt, color = self._fmt_arb(best_lcx)
            self.safe_addstr(arb_row, 6, txt, color)
            if best_lcx.buy_price > 0 and best_lcx.profitable:
                profit_usd = (best_lcx.net_bps / 10000) * (best_lcx.buy_price / 100) * 10000  # per 10k LCX
                self.safe_addstr(arb_row, min(55, w-22), f"  ~${profit_usd:.4f}/10kLCX", curses.color_pair(7))
        else:
            self.safe_addstr(arb_row, 6, "  waiting for data...", curses.color_pair(4))
        arb_row += 1

        # Recent profitable arbs history
        if self.arb.best_pair_hist:
            arb_row += 1
            self.safe_addstr(arb_row, 2, "Recent:", curses.color_pair(6))
            for entry in list(self.arb.best_pair_hist)[-3:]:
                arb_row += 1
                self.safe_addstr(arb_row, 4, f"• {entry}", curses.color_pair(7))

        # === KERNEL METRICS (Phase 17 — SHM mode only) ===
        if self._shm_reader:
            km = self._shm_reader.read()
            arb_row += 1
            sep2 = "─" * (w - 2)
            self.safe_addstr(arb_row, 1, sep2, curses.color_pair(6))
            arb_row += 1

            if km.shm_available:
                gs = km.grid_state
                ge = km.grid_export

                if gs.valid:
                    status = "ACTIVE" if gs.active else "IDLE"
                    if gs.rebalancing:
                        status += "+REBAL"
                    profit_color = curses.color_pair(7) if gs.profit_usd >= 0 else curses.color_pair(5)
                    self.safe_addstr(arb_row, 2,
                        f"KERNEL Grid[{status}]  levels:{gs.level_count}  orders:{gs.order_count}  "
                        f"step:{gs.step_cents/100:.2f}  profit:",
                        curses.color_pair(6) | curses.A_BOLD)
                    profit_col = min(70, w - 15)
                    self.safe_addstr(arb_row, profit_col,
                        f"${gs.profit_usd:+.2f}", profit_color | curses.A_BOLD)
                else:
                    self.safe_addstr(arb_row, 2, "KERNEL Grid: waiting (SHM data not yet valid)",
                        curses.color_pair(4))
                arb_row += 1

                if ge.valid:
                    win_rate_pct = ge.win_rate * 100
                    self.safe_addstr(arb_row, 2,
                        f"  cycles:{ge.cycle_count}  wins:{ge.winning_trades}/{ge.total_trades}"
                        f"  win_rate:{win_rate_pct:.1f}%  total_P&L:${ge.profit_usd:+.2f}",
                        curses.color_pair(4))
                    arb_row += 1

                # Show top 2 kernel-detected arb opportunities
                if km.arb_opps:
                    for opp in km.arb_opps[:2]:
                        pair_name = ["BTC", "ETH", "LCX"].get(opp.pair_id, f"P{opp.pair_id}") \
                            if hasattr(opp.pair_id, '__index__') else f"P{opp.pair_id}"
                        pair_name = ["BTC", "ETH", "LCX"][opp.pair_id] if opp.pair_id < 3 else f"P{opp.pair_id}"
                        exec_tag = "[EXEC]" if opp.executed else "      "
                        opp_color = curses.color_pair(7) if opp.net_profit_bps > 0 else curses.color_pair(5)
                        self.safe_addstr(arb_row, 2,
                            f"  {exec_tag} {pair_name} {opp.buy_exchange}→{opp.sell_exchange} "
                            f"net:{opp.net_profit_bps}bps ~${opp.profit_usd_per_unit:.2f}",
                            opp_color)
                        arb_row += 1
            else:
                self.safe_addstr(arb_row, 2, "KERNEL: SHM not available (run with run_omnibus_live.sh)",
                    curses.color_pair(4))

        # === FOOTER ===
        row = h - 2
        shm_tag = " | SHM LIVE" if self._shm_reader else ""
        footer = f"Press 'q' to quit | Updates every 500ms | Phase 17: Kernel Metrics{shm_tag}"
        self.safe_addstr(row, 1, footer, curses.color_pair(4))

        try:
            self.stdscr.refresh()
        except:
            pass

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
    parser = argparse.ArgumentParser(description="OmniBus Multi-Exchange Dashboard")
    parser.add_argument('--shm', default='', metavar='SHM_FILE',
                        help='QEMU shared memory file for live kernel metrics '
                             '(e.g. /tmp/omnibus_live_mem). Shows Grid OS state + arb opps.')
    args = parser.parse_args()

    # Set global SHM path before curses starts
    if args.shm:
        SHM_FILE = args.shm  # module-level global

    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("\nDashboard stopped")
        sys.exit(0)
