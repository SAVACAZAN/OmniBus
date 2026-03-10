#!/usr/bin/env python3
"""
Phase 17: SHM Kernel Metrics Reader
=====================================

Reads live kernel state from QEMU shared memory file.
Used by dashboard to show real-time Grid OS + NeuroOS metrics.

Memory addresses (matching grid_os/types.zig extern structs):
  0x110000  GridState (64 bytes) — trading state header
  0x113840  ArbitrageOpportunity[32] (32 × 96 bytes) — detected arbs
  0x120000  GridMetrics export buffer (kernel writes every cycle)
  0x2D0000  NeuroState (128 bytes) — evolution state

Usage:
    from shm_reader import ShmMetricsReader
    reader = ShmMetricsReader("/tmp/omnibus_live_mem")
    metrics = reader.read()
"""

import mmap
import os
import struct
from dataclasses import dataclass, field

# Memory addresses (must match kernel)
GRID_STATE_ADDR    = 0x110000   # GridState (64 bytes)
ARB_OPP_ADDR       = 0x113840   # ArbitrageOpportunity[32]
GRID_EXPORT_ADDR   = 0x120000   # GridMetrics export (kernel writes)
NEURO_STATE_ADDR   = 0x2D0000   # NeuroState (128 bytes)

# GridState extern struct: 64 bytes
# magic(4) pair_id(2) flags(1) pad(1) lower(8) upper(8) step(8) profit(8)
#   tsc(8) level_cnt(4) order_cnt(4) pad2(8) = 64
GRID_STATE_FMT  = '<I H B B Q Q Q q Q I I 8s'
GRID_STATE_SIZE = struct.calcsize(GRID_STATE_FMT)   # = 64

# ArbitrageOpportunity extern struct: 96 bytes
# pair_id(2) exch_a(1) exch_b(1) flags(1) pad(3) priceA(8) priceB(8)
#   net_bps(4) confidence(1) pad(3) tsc(8) pad56(56) = 96
ARB_OPP_FMT  = '<H B B B 3x Q Q i B 3x Q 56s'
ARB_OPP_SIZE = struct.calcsize(ARB_OPP_FMT)         # = 96
ARB_OPP_COUNT = 32

# GridMetrics export buffer (64 bytes, u64 fields written by kernel)
# Kernel writes: [cycle_count(8)] [profit_i64(8)] [winning(8)] [total(8)]
#                [valid_flag(1)] pad(7) rest(32)
GRID_EXPORT_FMT  = '<Q q Q Q B 7x 32s'
GRID_EXPORT_SIZE = struct.calcsize(GRID_EXPORT_FMT)  # = 64

EXCHANGE_NAMES = {0: "Kraken", 1: "Coinbase", 2: "LCX", 3: "?"}


@dataclass
class GridStateData:
    valid: bool = False
    magic: int = 0
    pair_id: int = 0
    flags: int = 0
    lower_bound: int = 0      # cents
    upper_bound: int = 0      # cents
    step_cents: int = 0       # cents
    last_trade_profit: int = 0  # cents (i64, can be negative)
    tsc_last_update: int = 0
    level_count: int = 0
    order_count: int = 0

    @property
    def profit_usd(self) -> float:
        return self.last_trade_profit / 100.0

    @property
    def active(self) -> bool:
        return bool(self.flags & 0x01)

    @property
    def rebalancing(self) -> bool:
        return bool(self.flags & 0x02)


@dataclass
class ArbOppData:
    valid: bool = False
    executed: bool = False
    pair_id: int = 0
    exchange_a: int = 0
    exchange_b: int = 0
    price_a: int = 0          # cents
    price_b: int = 0          # cents
    net_profit_bps: int = 0   # basis points
    confidence: int = 0

    @property
    def buy_exchange(self) -> str:
        return EXCHANGE_NAMES.get(self.exchange_a, "?")

    @property
    def sell_exchange(self) -> str:
        return EXCHANGE_NAMES.get(self.exchange_b, "?")

    @property
    def gross_bps(self) -> int:
        if self.price_a > 0:
            return int(((self.price_b - self.price_a) / self.price_a) * 10000)
        return 0

    @property
    def profit_usd_per_unit(self) -> float:
        """Estimated profit per unit based on net bps × buy price"""
        if self.price_a > 0:
            return (self.net_profit_bps / 10000) * (self.price_a / 100)
        return 0.0


@dataclass
class GridExportData:
    valid: bool = False
    cycle_count: int = 0
    total_profit_cents: int = 0
    winning_trades: int = 0
    total_trades: int = 0

    @property
    def profit_usd(self) -> float:
        return self.total_profit_cents / 100.0

    @property
    def win_rate(self) -> float:
        if self.total_trades == 0:
            return 0.0
        return self.winning_trades / self.total_trades


@dataclass
class KernelMetrics:
    grid_state: GridStateData = field(default_factory=GridStateData)
    arb_opps: list[ArbOppData] = field(default_factory=list)   # active opportunities
    grid_export: GridExportData = field(default_factory=GridExportData)
    shm_available: bool = False


class ShmMetricsReader:
    """Reads kernel metrics from QEMU shared memory file"""

    def __init__(self, shm_file: str):
        self.shm_file = shm_file
        self._mm: mmap.mmap | None = None
        self._fd = None

    def _open(self) -> bool:
        """Open/reopen the SHM file"""
        try:
            if not os.path.exists(self.shm_file):
                return False
            if self._mm is None:
                self._fd = open(self.shm_file, 'rb')
                self._mm = mmap.mmap(self._fd.fileno(), 0, access=mmap.ACCESS_READ)
            return True
        except Exception:
            self._mm = None
            self._fd = None
            return False

    def _read_bytes(self, addr: int, size: int) -> bytes | None:
        """Read bytes from SHM at physical address"""
        try:
            if self._mm is None:
                return None
            self._mm.seek(addr)
            return self._mm.read(size)
        except Exception:
            self._mm = None
            return None

    def read_grid_state(self) -> GridStateData:
        data = self._read_bytes(GRID_STATE_ADDR, GRID_STATE_SIZE)
        if not data or len(data) < GRID_STATE_SIZE:
            return GridStateData()
        try:
            fields = struct.unpack(GRID_STATE_FMT, data)
            # fields: magic, pair_id, flags, _pad, lower, upper, step, profit, tsc, lvl, ord, _pad2
            magic, pair_id, flags, _, lower, upper, step, profit, tsc, lvl_cnt, ord_cnt, _ = fields
            if magic != 0x47524944:  # "GRID"
                return GridStateData()
            return GridStateData(
                valid=True,
                magic=magic,
                pair_id=pair_id,
                flags=flags,
                lower_bound=lower,
                upper_bound=upper,
                step_cents=step,
                last_trade_profit=profit,
                tsc_last_update=tsc,
                level_count=lvl_cnt,
                order_count=ord_cnt,
            )
        except struct.error:
            return GridStateData()

    def read_arb_opportunities(self) -> list[ArbOppData]:
        """Read all 32 ArbitrageOpportunity slots, return valid ones"""
        results = []
        for i in range(ARB_OPP_COUNT):
            addr = ARB_OPP_ADDR + i * ARB_OPP_SIZE
            data = self._read_bytes(addr, ARB_OPP_SIZE)
            if not data or len(data) < ARB_OPP_SIZE:
                continue
            try:
                fields = struct.unpack(ARB_OPP_FMT, data)
                pair_id, exch_a, exch_b, flags, price_a, price_b, net_bps, conf, tsc, _ = fields
                is_valid = bool(flags & 0x01)
                if not is_valid:
                    continue
                opp = ArbOppData(
                    valid=True,
                    executed=bool(flags & 0x02),
                    pair_id=pair_id,
                    exchange_a=exch_a,
                    exchange_b=exch_b,
                    price_a=price_a,
                    price_b=price_b,
                    net_profit_bps=net_bps,
                    confidence=conf,
                )
                results.append(opp)
            except struct.error:
                continue
        return sorted(results, key=lambda o: o.net_profit_bps, reverse=True)

    def read_grid_export(self) -> GridExportData:
        """Read kernel-written metrics export at 0x120000"""
        data = self._read_bytes(GRID_EXPORT_ADDR, GRID_EXPORT_SIZE)
        if not data or len(data) < GRID_EXPORT_SIZE:
            return GridExportData()
        try:
            fields = struct.unpack(GRID_EXPORT_FMT, data)
            cycle_cnt, profit_cents, winning, total, valid_flag, _ = fields
            if valid_flag != 1:
                return GridExportData()
            return GridExportData(
                valid=True,
                cycle_count=cycle_cnt,
                total_profit_cents=profit_cents,
                winning_trades=winning,
                total_trades=total,
            )
        except struct.error:
            return GridExportData()

    def read(self) -> KernelMetrics:
        """Read all kernel metrics from SHM"""
        if not self._open():
            return KernelMetrics(shm_available=False)

        metrics = KernelMetrics(shm_available=True)
        metrics.grid_state = self.read_grid_state()
        metrics.arb_opps = self.read_arb_opportunities()
        metrics.grid_export = self.read_grid_export()
        return metrics

    def close(self):
        if self._mm:
            self._mm.close()
        if self._fd:
            self._fd.close()
        self._mm = None
        self._fd = None
