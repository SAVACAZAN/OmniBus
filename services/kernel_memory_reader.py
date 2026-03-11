#!/usr/bin/env python3
"""
Kernel Memory Reader for Analytics OS Market Matrix
Reads OHLCV candle data from bare-metal kernel memory (0x169000)
"""

import struct
import os
import logging
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# Kernel memory addresses
MATRIX_BASE = 0x169000
OHLCV_SIZE = 40  # 5 × u64 = 40 bytes per candle
CANDLES_PER_PAIR = 30
PRICE_LEVELS = 32

# Memory layout offsets
OFFSET_BTC_GRID = 0
OFFSET_ETH_GRID = OFFSET_BTC_GRID + (PRICE_LEVELS * CANDLES_PER_PAIR * 8)
OFFSET_LCX_GRID = OFFSET_ETH_GRID + (PRICE_LEVELS * CANDLES_PER_PAIR * 8)

OFFSET_BTC_OHLCV = OFFSET_LCX_GRID + (PRICE_LEVELS * CANDLES_PER_PAIR * 8)
OFFSET_ETH_OHLCV = OFFSET_BTC_OHLCV + (CANDLES_PER_PAIR * OHLCV_SIZE)
OFFSET_LCX_OHLCV = OFFSET_ETH_OHLCV + (CANDLES_PER_PAIR * OHLCV_SIZE)

OFFSET_BTC_TICKS = OFFSET_LCX_OHLCV + (CANDLES_PER_PAIR * OHLCV_SIZE)
OFFSET_ETH_TICKS = OFFSET_BTC_TICKS + 4
OFFSET_LCX_TICKS = OFFSET_ETH_TICKS + 4

OFFSET_BTC_VOLUME = OFFSET_LCX_TICKS + 4
OFFSET_ETH_VOLUME = OFFSET_BTC_VOLUME + 8
OFFSET_LCX_VOLUME = OFFSET_ETH_VOLUME + 8

OFFSET_EXCHANGE_VOLUME = OFFSET_LCX_VOLUME + 8 + 8 + 8 + 8  # + session_start + cycle + padding


class KernelMemoryReader:
    """Read market matrix data from kernel memory"""

    def __init__(self):
        self.mem_file = None
        self.cache = {}
        self.cache_valid = False

    def open(self) -> bool:
        """Open kernel memory device"""
        try:
            # Try /dev/mem first (requires sudo)
            if os.path.exists('/dev/mem'):
                self.mem_file = open('/dev/mem', 'rb')
                logger.info("Opened /dev/mem for kernel memory access")
                return True
            # Fallback: simulate from test file
            elif os.path.exists('/tmp/omnibus_market_matrix.bin'):
                self.mem_file = open('/tmp/omnibus_market_matrix.bin', 'rb')
                logger.info("Opened test market matrix file")
                return True
            else:
                logger.warning("No kernel memory device found, using mock data")
                return False
        except PermissionError:
            logger.warning("Permission denied opening /dev/mem (requires sudo)")
            return False
        except Exception as e:
            logger.error(f"Failed to open kernel memory: {e}")
            return False

    def close(self):
        """Close kernel memory device"""
        if self.mem_file:
            self.mem_file.close()
            self.mem_file = None

    def read_bytes(self, offset: int, size: int) -> bytes:
        """Read bytes from kernel memory"""
        if not self.mem_file:
            return b'\x00' * size

        try:
            self.mem_file.seek(MATRIX_BASE + offset)
            return self.mem_file.read(size)
        except Exception as e:
            logger.warning(f"Failed to read kernel memory at 0x{MATRIX_BASE + offset:x}: {e}")
            return b'\x00' * size

    def read_u64(self, offset: int) -> int:
        """Read 64-bit unsigned integer"""
        data = self.read_bytes(offset, 8)
        return struct.unpack('<Q', data)[0] if len(data) == 8 else 0

    def read_u32(self, offset: int) -> int:
        """Read 32-bit unsigned integer"""
        data = self.read_bytes(offset, 4)
        return struct.unpack('<I', data)[0] if len(data) == 4 else 0

    def read_ohlcv_candle(self, pair_id: int, bucket: int) -> Dict:
        """Read single OHLCV candle"""
        offset_map = {
            0: OFFSET_BTC_OHLCV,
            1: OFFSET_ETH_OHLCV,
            2: OFFSET_LCX_OHLCV,
        }

        if pair_id not in offset_map:
            return {"open": 0, "high": 0, "low": 0, "close": 0, "volume": 0}

        base_offset = offset_map[pair_id]
        candle_offset = base_offset + (bucket * OHLCV_SIZE)

        return {
            "open": self.read_u64(candle_offset + 0),
            "high": self.read_u64(candle_offset + 8),
            "low": self.read_u64(candle_offset + 16),
            "close": self.read_u64(candle_offset + 24),
            "volume": self.read_u64(candle_offset + 32),
        }

    def read_ohlcv_series(self, pair_id: int) -> List[Dict]:
        """Read all OHLCV candles for a pair (30 buckets)"""
        candles = []
        for bucket in range(CANDLES_PER_PAIR):
            candles.append({
                "bucket": bucket,
                **self.read_ohlcv_candle(pair_id, bucket)
            })
        return candles

    def read_exchange_volume(self, exchange_id: int, pair_id: int) -> int:
        """Read per-exchange volume"""
        if exchange_id >= 3 or pair_id >= 3:
            return 0

        # exchange_volume[3][3] at offset OFFSET_EXCHANGE_VOLUME
        offset = OFFSET_EXCHANGE_VOLUME + (exchange_id * 3 * 8) + (pair_id * 8)
        return self.read_u64(offset)

    def read_exchange_ticks(self, exchange_id: int, pair_id: int) -> int:
        """Read per-exchange tick count"""
        if exchange_id >= 3 or pair_id >= 3:
            return 0

        # exchange_ticks[3][3] is right after exchange_volume
        offset = OFFSET_EXCHANGE_VOLUME + (3 * 3 * 8) + (exchange_id * 3 * 4) + (pair_id * 4)
        return self.read_u32(offset)

    def get_ohlcv_data(self, pair: str) -> Dict:
        """Get OHLCV data for a pair"""
        pair_map = {"BTC/USD": 0, "ETH/USD": 1, "LCX/USD": 2}
        pair_id = pair_map.get(pair, -1)

        if pair_id < 0:
            return {"error": "Unknown pair", "candles": []}

        pair_label = pair.split("/")[0]
        total_volume = sum(c["volume"] for c in self.read_ohlcv_series(pair_id))

        return {
            "pair": pair,
            "timeframe": "1m",
            "candles": self.read_ohlcv_series(pair_id),
            "total_volume": total_volume,
            "status": "operational",
            "exchange": "omnibus_aggregated",
        }

    def get_market_matrix_stats(self) -> Dict:
        """Get full market matrix statistics"""
        return {
            "status": "operational",
            "matrix_base": "0x169000",
            "pairs": {
                "BTC/USD": {
                    "total_volume": sum(
                        c["volume"] for c in self.read_ohlcv_series(0)
                    ),
                    "candles_generated": CANDLES_PER_PAIR,
                    "exchanges": {
                        "kraken": {
                            "volume": self.read_exchange_volume(0, 0),
                            "ticks": self.read_exchange_ticks(0, 0),
                        },
                        "coinbase": {
                            "volume": self.read_exchange_volume(1, 0),
                            "ticks": self.read_exchange_ticks(1, 0),
                        },
                        "lcx": {
                            "volume": self.read_exchange_volume(2, 0),
                            "ticks": self.read_exchange_ticks(2, 0),
                        },
                    },
                },
                "ETH/USD": {
                    "total_volume": sum(
                        c["volume"] for c in self.read_ohlcv_series(1)
                    ),
                    "candles_generated": CANDLES_PER_PAIR,
                    "exchanges": {
                        "kraken": {
                            "volume": self.read_exchange_volume(0, 1),
                            "ticks": self.read_exchange_ticks(0, 1),
                        },
                        "coinbase": {
                            "volume": self.read_exchange_volume(1, 1),
                            "ticks": self.read_exchange_ticks(1, 1),
                        },
                        "lcx": {
                            "volume": self.read_exchange_volume(2, 1),
                            "ticks": self.read_exchange_ticks(2, 1),
                        },
                    },
                },
                "LCX/USD": {
                    "total_volume": sum(
                        c["volume"] for c in self.read_ohlcv_series(2)
                    ),
                    "candles_generated": CANDLES_PER_PAIR,
                    "exchanges": {
                        "kraken": {
                            "volume": self.read_exchange_volume(0, 2),
                            "ticks": self.read_exchange_ticks(0, 2),
                        },
                        "coinbase": {
                            "volume": self.read_exchange_volume(1, 2),
                            "ticks": self.read_exchange_ticks(1, 2),
                        },
                        "lcx": {
                            "volume": self.read_exchange_volume(2, 2),
                            "ticks": self.read_exchange_ticks(2, 2),
                        },
                    },
                },
            },
        }


# Global singleton
_reader: Optional[KernelMemoryReader] = None


def get_kernel_reader() -> KernelMemoryReader:
    """Get or initialize kernel memory reader"""
    global _reader
    if _reader is None:
        _reader = KernelMemoryReader()
        _reader.open()
    return _reader


def read_ohlcv(pair: str) -> Dict:
    """Read OHLCV data for a pair"""
    reader = get_kernel_reader()
    return reader.get_ohlcv_data(pair)


def read_market_matrix() -> Dict:
    """Read full market matrix stats"""
    reader = get_kernel_reader()
    return reader.get_market_matrix_stats()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    reader = KernelMemoryReader()
    reader.open()

    print("BTC/USD OHLCV:")
    btc_data = reader.get_ohlcv_data("BTC/USD")
    print(f"  Total Volume: {btc_data['total_volume']}")
    print(f"  Latest Candle: {btc_data['candles'][-1] if btc_data['candles'] else 'None'}")

    print("\nMarket Matrix Stats:")
    stats = reader.get_market_matrix_stats()
    print(f"  BTC Volume: {stats['pairs']['BTC/USD']['total_volume']}")
    print(f"  ETH Volume: {stats['pairs']['ETH/USD']['total_volume']}")
    print(f"  LCX Volume: {stats['pairs']['LCX/USD']['total_volume']}")

    reader.close()
