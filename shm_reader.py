#!/usr/bin/env python3
"""
Phase 19: SHM Kernel Metrics Reader (Execution OS + Grid OS + NeuroOS)
=======================================================================

Reads live kernel state from QEMU shared memory file.
Used by dashboard to show real-time Grid OS + Execution OS metrics.

Memory addresses (matching kernel extern structs):
  0x110000  GridState (64 bytes) — trading state header
  0x113840  ArbitrageOpportunity[32] (32 × 96 bytes) — detected arbs
  0x120000  GridMetrics export buffer (kernel writes every cycle)
  0x130000  ExecutionState (64 bytes) — execution OS header
  0x130040  OrderRingHeader (16 bytes) — ring buffer head/tail
  0x130050  OrderPacket[256] (128 bytes per slot) — pending orders
  0x13E050  FillResult[256] (64 bytes per slot) — exchange fills
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
GRID_STATE_ADDR    = 0x110000   # GridState (64 bytes, extern struct)
ARB_OPP_ADDR       = 0x113840   # ArbitrageOpportunity[32] (96 bytes each)
KERNEL_CYCLE_ADDR  = 0x100100   # kernel_cycle_count (u64, from startup_phase4.asm)
GRID_EXPORT_ADDR   = 0x120000   # profit i64 written by kernel every 128 cycles
GRID_EXPORT_TRADES = 0x120020   # total_trades u64 (written by kernel)
GRID_EXPORT_VALID  = 0x120040   # valid flag u8 (0x01 = valid)
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

# Kernel writes (startup_phase4.asm, every 128 cycles):
#   [0x120000] = i64 profit from 0x110100 (Grid profit metric)
#   [0x120020] = u64 trades from 0x110120 (Grid order count)
#   [0x120040] = byte 0x01 (valid flag)
GRID_EXPORT_PROFIT_FMT = '<q'   # i64 at 0x120000
GRID_EXPORT_TRADES_FMT = '<Q'   # u64 at 0x120020

EXCHANGE_NAMES = {0: "Kraken", 1: "Coinbase", 2: "LCX", 3: "?"}

# Execution OS memory addresses (execution_os/types.zig)
EXEC_STATE_ADDR       = 0x130000   # ExecutionState (64 bytes; slot size from RING_HEADER_OFFSET=0x40)
EXEC_RING_HEADER_ADDR = 0x130040   # OrderRingHeader (16 bytes)
EXEC_ORDER_RING_ADDR  = 0x130050   # OrderPacket[256] (128 bytes per slot)
EXEC_FILL_RESULT_ADDR = 0x13E050   # FillResult[256] (64 bytes per slot; API_KEY_OFFSET-FILL_RESULT_OFFSET=0x4000)

EXEC_MAGIC = 0x45584543            # "EXEC"

# ExecutionState: magic(4)+flags(1)+pad(3)+cycle(8)+order_in(4)+fill_out(4)+tsc(8) = 32 data bytes; slot=64
EXEC_STATE_FMT  = '<IB3xQIIQ'
EXEC_STATE_SIZE = 64

# OrderRingHeader: head(4)+tail(4)+pad(8) = 16 bytes
RING_HEADER_FMT  = '<II8x'
RING_HEADER_SIZE = 16

# OrderPacket: opcode(1)+pad(1)+exchange_id(2)+pad(4)+pair_id(2)+side(1)+pad(1)+qty(8)+price(8)+sig[64] = 92 data bytes; slot=128
ORDER_PACKET_FMT  = '<BBHIHBBQQ64s'
ORDER_PACKET_DATA = struct.calcsize(ORDER_PACKET_FMT)   # 92
ORDER_PACKET_SLOT = 128
ORDER_RING_MAX    = 256

# FillResult: order_id(4)+pair_id(2)+exchange_id(1)+status(1)+filled(8)+price(8)+tsc(8) = 32 data bytes; slot=64
FILL_RESULT_FMT  = '<IHBBQQQ'
FILL_RESULT_DATA = struct.calcsize(FILL_RESULT_FMT)     # 32
FILL_RESULT_SLOT = 64
FILL_RESULT_MAX  = 256

PAIR_NAMES   = {0: "BTC", 1: "ETH", 2: "XRP", 0xFFFF: "???"}
SIDE_NAMES   = {0: "BUY", 1: "SELL"}
STATUS_NAMES = {0: "PENDING", 1: "FILLED", 2: "PARTIAL", 3: "REJECTED"}

# NeuroState @ 0x2D0000 (88 bytes)
# magic(4)+flags(4)+generation(8)+evolution_cycles(8)+best_fitness(8)+worst_fitness(8)+tsc(8)+reserved(40)
NEURO_MAGIC      = 0x4E45524F   # "NERO"
NEURO_STATE_FMT  = '<IIQQddQ40s'
NEURO_STATE_SIZE = struct.calcsize(NEURO_STATE_FMT)  # 88


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
class ExecutionStateData:
    valid: bool = False
    active: bool = False
    cycle_count: int = 0
    order_in_count: int = 0
    fill_out_count: int = 0


@dataclass
class OrderData:
    exchange_id: int = 0    # 0=Kraken, 1=Coinbase, 2=LCX
    pair_id: int = 0        # 0=BTC, 1=ETH, 2=XRP
    side: int = 0           # 0=buy, 1=sell
    quantity_sats: int = 0
    price_cents: int = 0

    @property
    def pair_name(self) -> str:
        return PAIR_NAMES.get(self.pair_id, f"P{self.pair_id}")

    @property
    def side_name(self) -> str:
        return SIDE_NAMES.get(self.side, "?")

    @property
    def exchange_name(self) -> str:
        return EXCHANGE_NAMES.get(self.exchange_id, "?")

    @property
    def price_usd(self) -> float:
        return self.price_cents / 100.0

    @property
    def quantity_asset(self) -> float:
        return self.quantity_sats / 1e8


@dataclass
class FillResultData:
    order_id: int = 0
    pair_id: int = 0
    exchange_id: int = 0
    status: int = 0         # 0=pending, 1=filled, 2=partial, 3=rejected
    filled_sats: int = 0
    price_cents: int = 0

    @property
    def status_name(self) -> str:
        return STATUS_NAMES.get(self.status, f"?{self.status}")

    @property
    def pair_name(self) -> str:
        return PAIR_NAMES.get(self.pair_id, f"P{self.pair_id}")

    @property
    def exchange_name(self) -> str:
        return EXCHANGE_NAMES.get(self.exchange_id, "?")

    @property
    def price_usd(self) -> float:
        return self.price_cents / 100.0

    @property
    def filled_asset(self) -> float:
        return self.filled_sats / 1e8


@dataclass
class NeuroStateData:
    valid: bool = False
    flags: int = 0
    generation: int = 0
    evolution_cycles: int = 0
    best_fitness: float = 0.0
    worst_fitness: float = 0.0
    tsc_last_update: int = 0

    @property
    def active(self) -> bool:
        return bool(self.flags & 0x01)

    @property
    def fitness_range(self) -> float:
        return self.best_fitness - self.worst_fitness


@dataclass
class KernelMetrics:
    grid_state: GridStateData = field(default_factory=GridStateData)
    arb_opps: list[ArbOppData] = field(default_factory=list)   # active opportunities
    grid_export: GridExportData = field(default_factory=GridExportData)
    exec_state: ExecutionStateData = field(default_factory=ExecutionStateData)
    pending_orders: list[OrderData] = field(default_factory=list)
    fill_results: list[FillResultData] = field(default_factory=list)
    neuro_state: NeuroStateData = field(default_factory=NeuroStateData)
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
        """Read kernel-written metrics export.
        Kernel writes every 128 cycles (startup_phase4.asm scheduler):
          0x120000 = profit i64
          0x120020 = trades u64
          0x120040 = valid flag byte (0x01)
          0x100100 = kernel cycle count u64
        """
        try:
            # Check valid flag first
            valid_data = self._read_bytes(GRID_EXPORT_VALID, 1)
            if not valid_data or valid_data[0] != 0x01:
                return GridExportData()

            profit_data  = self._read_bytes(GRID_EXPORT_ADDR, 8)
            trades_data  = self._read_bytes(GRID_EXPORT_TRADES, 8)
            cycle_data   = self._read_bytes(KERNEL_CYCLE_ADDR, 8)

            if not all([profit_data, trades_data, cycle_data]):
                return GridExportData()

            profit_cents = struct.unpack('<q', profit_data)[0]
            total_trades = struct.unpack('<Q', trades_data)[0]
            cycle_count  = struct.unpack('<Q', cycle_data)[0]

            return GridExportData(
                valid=True,
                cycle_count=cycle_count,
                total_profit_cents=profit_cents,
                winning_trades=0,    # Not exported separately yet
                total_trades=total_trades,
            )
        except struct.error:
            return GridExportData()

    def read_execution_state(self) -> ExecutionStateData:
        """Read ExecutionState from 0x130000"""
        data = self._read_bytes(EXEC_STATE_ADDR, EXEC_STATE_SIZE)
        if not data or len(data) < EXEC_STATE_SIZE:
            return ExecutionStateData()
        try:
            fmt_size = struct.calcsize(EXEC_STATE_FMT)
            magic, flags, cycle, order_in, fill_out, tsc = struct.unpack(EXEC_STATE_FMT, data[:fmt_size])
            if magic != EXEC_MAGIC:
                return ExecutionStateData()
            return ExecutionStateData(
                valid=True,
                active=bool(flags & 0x01),
                cycle_count=cycle,
                order_in_count=order_in,
                fill_out_count=fill_out,
            )
        except struct.error:
            return ExecutionStateData()

    def read_execution_orders(self) -> list[OrderData]:
        """Read pending orders from ring buffer at 0x130050 (head..tail slots)"""
        hdr_data = self._read_bytes(EXEC_RING_HEADER_ADDR, RING_HEADER_SIZE)
        if not hdr_data or len(hdr_data) < RING_HEADER_SIZE:
            return []
        try:
            head, tail = struct.unpack('<II', hdr_data[:8])
        except struct.error:
            return []

        if head == tail:
            return []   # Ring empty

        count = min((tail - head) & 0xFF, 8)   # At most 8 pending slots
        orders = []
        for i in range(count):
            slot_idx = (head + i) & 0xFF
            addr = EXEC_ORDER_RING_ADDR + slot_idx * ORDER_PACKET_SLOT
            data = self._read_bytes(addr, ORDER_PACKET_DATA)
            if not data or len(data) < ORDER_PACKET_DATA:
                continue
            try:
                opcode, _p0, exchange_id, _p1, pair_id, side, _p2, qty_sats, price_cents, _ = \
                    struct.unpack(ORDER_PACKET_FMT, data)
                if opcode == 0:
                    continue   # Uninitialized slot
                orders.append(OrderData(
                    exchange_id=exchange_id & 0xFF,
                    pair_id=pair_id,
                    side=side,
                    quantity_sats=qty_sats,
                    price_cents=price_cents,
                ))
            except struct.error:
                continue
        return orders

    def read_fill_results(self) -> list[FillResultData]:
        """Read recent fill results from 0x13E050 (non-blank slots only)"""
        fills = []
        for i in range(FILL_RESULT_MAX):
            addr = EXEC_FILL_RESULT_ADDR + i * FILL_RESULT_SLOT
            data = self._read_bytes(addr, FILL_RESULT_DATA)
            if not data or len(data) < FILL_RESULT_DATA:
                continue
            try:
                order_id, pair_id, exchange_id, status, filled_sats, price_cents, tsc = \
                    struct.unpack(FILL_RESULT_FMT, data)
                # Skip blank/uninitialized slots
                if order_id == 0 and price_cents == 0:
                    continue
                fills.append(FillResultData(
                    order_id=order_id,
                    pair_id=pair_id,
                    exchange_id=exchange_id,
                    status=status,
                    filled_sats=filled_sats,
                    price_cents=price_cents,
                ))
            except struct.error:
                continue
        return fills[-5:]   # Show 5 most recent

    def read_neuro_state(self) -> NeuroStateData:
        """Read NeuroState from 0x2D0000 — genetic algorithm evolution header"""
        data = self._read_bytes(NEURO_STATE_ADDR, NEURO_STATE_SIZE)
        if not data or len(data) < NEURO_STATE_SIZE:
            return NeuroStateData()
        try:
            magic, flags, generation, evolution_cycles, best_fitness, worst_fitness, tsc, _ = \
                struct.unpack(NEURO_STATE_FMT, data)
            if magic != NEURO_MAGIC:
                return NeuroStateData()
            return NeuroStateData(
                valid=True,
                flags=flags,
                generation=generation,
                evolution_cycles=evolution_cycles,
                best_fitness=best_fitness,
                worst_fitness=worst_fitness,
                tsc_last_update=tsc,
            )
        except struct.error:
            return NeuroStateData()

    def read(self) -> KernelMetrics:
        """Read all kernel metrics from SHM"""
        if not self._open():
            return KernelMetrics(shm_available=False)

        metrics = KernelMetrics(shm_available=True)
        metrics.grid_state = self.read_grid_state()
        metrics.arb_opps = self.read_arb_opportunities()
        metrics.grid_export = self.read_grid_export()
        metrics.exec_state = self.read_execution_state()
        metrics.pending_orders = self.read_execution_orders()
        metrics.fill_results = self.read_fill_results()
        metrics.neuro_state = self.read_neuro_state()
        return metrics

    def close(self):
        if self._mm:
            self._mm.close()
        if self._fd:
            self._fd.close()
        self._mm = None
        self._fd = None
