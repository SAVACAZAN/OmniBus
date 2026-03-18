#!/usr/bin/env python3
"""
Performance Profiler Reader
Reads module latency profiling data from kernel memory (0x3E0000)
TSC-based per-module cycle tracking
"""

import struct
import os
import logging
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# Kernel memory addresses
PROFILER_BASE = 0x3E0000
MAX_MODULES = 33

# Memory layout offsets
PROFILER_STATE_SIZE = 128
MODULE_PROFILE_SIZE = 64
MODULE_PROFILES_OFFSET = PROFILER_BASE + PROFILER_STATE_SIZE

# Module names (matching profiler enum)
MODULE_NAMES = [
    "Grid OS",
    "Execution OS",
    "Analytics OS",
    "BlockchainOS",
    "NeuroOS",
    "BankOS",
    "StealthOS",
    "Report OS",
    "Checksum OS",
    "AutoRepair OS",
    "Zorin OS",
    "Audit Log OS",
    "ParamTune OS",
    "HistAnalytics OS",
    "Alert System OS",
    "Consensus OS",
    "Federation OS",
    "MEVGuard OS",
    "CrossChain OS",
    "DAO Governance OS",
    "Profiler OS",
    "Recovery OS",
    "Compliance OS",
    "Staking OS",
    "Slashing OS",
    "Auction OS",
    "Breaker OS",
    "FlashLoan OS",
    "Rollup OS",
    "Quantum OS",
    "PQC-GATE OS",
    "Reserved 31",
    "Reserved 32",
]


class ProfilerReader:
    """Read performance profiling data from kernel memory"""

    def __init__(self):
        self.mem_file = None

    def open(self) -> bool:
        """Open kernel memory device"""
        try:
            if os.path.exists('/dev/mem'):
                self.mem_file = open('/dev/mem', 'rb')
                logger.info("Opened /dev/mem for profiler access")
                return True
            else:
                logger.warning("No kernel memory device found")
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
            self.mem_file.seek(PROFILER_BASE + offset)
            return self.mem_file.read(size)
        except Exception as e:
            logger.warning(f"Failed to read profiler memory at 0x{PROFILER_BASE + offset:x}: {e}")
            return b'\x00' * size

    def read_u32(self, offset: int) -> int:
        """Read 32-bit unsigned integer"""
        data = self.read_bytes(offset, 4)
        return struct.unpack('<I', data)[0] if len(data) == 4 else 0

    def read_u64(self, offset: int) -> int:
        """Read 64-bit unsigned integer"""
        data = self.read_bytes(offset, 8)
        return struct.unpack('<Q', data)[0] if len(data) == 8 else 0

    def read_u16(self, offset: int) -> int:
        """Read 16-bit unsigned integer"""
        data = self.read_bytes(offset, 2)
        return struct.unpack('<H', data)[0] if len(data) == 2 else 0

    def read_u8(self, offset: int) -> int:
        """Read 8-bit unsigned integer"""
        data = self.read_bytes(offset, 1)
        return struct.unpack('<B', data)[0] if len(data) == 1 else 0

    def get_profiler_state(self) -> Dict:
        """Read global profiler state"""
        magic = self.read_u32(0)
        flags = self.read_u8(4)

        return {
            "magic": f"0x{magic:08X}",
            "enabled": (flags & 0x01) != 0,
            "cycle_count": self.read_u64(8),
            "functions_tracked": self.read_u32(16),
            "total_calls": self.read_u64(20),
            "avg_call_time": self.read_u32(28),
            "max_latency": self.read_u32(32),
            "hottest_function": self.read_u16(36),
            "modules_profiled": self.read_u16(38),
            "scheduler_cycles_total": self.read_u64(40),
            "scheduler_jitter_max": self.read_u32(48),
            "slowest_module_id": self.read_u16(52),
            "fastest_module_id": self.read_u16(54),
        }

    def get_module_profile(self, module_id: int) -> Dict:
        """Read profile for a specific module"""
        if module_id >= MAX_MODULES:
            return {"error": f"Invalid module ID: {module_id}"}

        offset = MODULE_PROFILES_OFFSET + (module_id * MODULE_PROFILE_SIZE)

        return {
            "module_id": module_id,
            "module_name": MODULE_NAMES[module_id] if module_id < len(MODULE_NAMES) else f"Unknown({module_id})",
            "call_count": self.read_u32(offset + 4),  # Skip module_id (2B) and _pad (2B)
            "total_cycles": self.read_u64(offset + 8),
            "min_cycles": self.read_u32(offset + 16),
            "max_cycles": self.read_u32(offset + 20),
            "avg_cycles": self.read_u32(offset + 24),
            "last_call_cycles": self.read_u32(offset + 28),
        }

    def get_all_module_profiles(self) -> List[Dict]:
        """Read profiles for all modules"""
        profiles = []
        for module_id in range(MAX_MODULES):
            profile = self.get_module_profile(module_id)
            if profile.get("call_count", 0) > 0:  # Only include modules with calls
                profiles.append(profile)
        return profiles

    def get_latency_percentiles(self, module_id: int) -> Dict:
        """Calculate latency percentiles for a module"""
        profile = self.get_module_profile(module_id)
        if profile.get("error"):
            return profile

        calls = profile.get("call_count", 1)
        if calls == 0:
            return {
                "module_id": module_id,
                "module_name": profile.get("module_name"),
                "status": "no_data"
            }

        total = profile.get("total_cycles", 0)
        avg = total // calls if calls > 0 else 0

        return {
            "module_id": module_id,
            "module_name": profile.get("module_name"),
            "call_count": calls,
            "total_cycles": total,
            "min_cycles": profile.get("min_cycles", 0),
            "max_cycles": profile.get("max_cycles", 0),
            "avg_cycles": avg,
            "moving_avg": profile.get("avg_cycles", 0),
            "last_call": profile.get("last_call_cycles", 0),
        }

    def get_hottest_modules(self, limit: int = 10) -> List[Dict]:
        """Get modules with highest latency"""
        profiles = self.get_all_module_profiles()

        # Sort by max_cycles (descending)
        sorted_profiles = sorted(
            profiles,
            key=lambda x: x.get("max_cycles", 0),
            reverse=True
        )

        return sorted_profiles[:limit]

    def get_slowest_modules(self, limit: int = 10) -> List[Dict]:
        """Get modules with highest average latency"""
        profiles = self.get_all_module_profiles()

        # Calculate averages
        for profile in profiles:
            calls = profile.get("call_count", 1)
            total = profile.get("total_cycles", 0)
            profile["avg_latency"] = total // calls if calls > 0 else 0

        # Sort by average (descending)
        sorted_profiles = sorted(
            profiles,
            key=lambda x: x.get("avg_latency", 0),
            reverse=True
        )

        return sorted_profiles[:limit]

    def get_profiler_summary(self) -> Dict:
        """Get comprehensive profiler summary"""
        state = self.get_profiler_state()
        profiles = self.get_all_module_profiles()

        if not profiles:
            return {
                "status": "initializing",
                "total_modules": 0,
                "state": state
            }

        # Calculate statistics
        total_cycles = sum(p.get("total_cycles", 0) for p in profiles)
        total_calls = sum(p.get("call_count", 0) for p in profiles)
        slowest = max(profiles, key=lambda x: x.get("max_cycles", 0))
        fastest = min(profiles, key=lambda x: x.get("min_cycles", 0) or float('inf'))

        # Per-module breakdown
        module_breakdown = []
        for profile in sorted(profiles, key=lambda x: x.get("total_cycles", 0), reverse=True):
            calls = profile.get("call_count", 1)
            total = profile.get("total_cycles", 0)
            pct = (total / total_cycles * 100) if total_cycles > 0 else 0

            module_breakdown.append({
                "module_name": profile.get("module_name"),
                "module_id": profile.get("module_id"),
                "calls": calls,
                "total_cycles": total,
                "percentage": f"{pct:.1f}%",
                "avg_per_call": total // calls if calls > 0 else 0,
                "min_cycles": profile.get("min_cycles", 0),
                "max_cycles": profile.get("max_cycles", 0),
                "moving_avg": profile.get("avg_cycles", 0),
            })

        return {
            "status": "operational",
            "enabled": state.get("enabled", False),
            "global_cycle_count": state.get("cycle_count", 0),
            "total_modules_active": len(profiles),
            "total_calls": total_calls,
            "total_cycles": total_cycles,
            "slowest_module": {
                "name": slowest.get("module_name"),
                "id": slowest.get("module_id"),
                "max_cycles": slowest.get("max_cycles", 0),
            },
            "fastest_module": {
                "name": fastest.get("module_name"),
                "id": fastest.get("module_id"),
                "min_cycles": fastest.get("min_cycles", 0),
            },
            "module_breakdown": module_breakdown,
        }


# Global singleton
_reader: Optional[ProfilerReader] = None


def get_profiler_reader() -> ProfilerReader:
    """Get or initialize profiler reader"""
    global _reader
    if _reader is None:
        _reader = ProfilerReader()
        _reader.open()
    return _reader


def read_profiler_summary() -> Dict:
    """Get profiler summary"""
    reader = get_profiler_reader()
    return reader.get_profiler_summary()


def read_module_profile(module_id: int) -> Dict:
    """Get specific module profile"""
    reader = get_profiler_reader()
    return reader.get_latency_percentiles(module_id)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    reader = ProfilerReader()
    reader.open()

    print("Profiler Summary:")
    summary = reader.get_profiler_summary()
    print(f"  Status: {summary.get('status')}")
    print(f"  Total modules: {summary.get('total_modules_active')}")
    print(f"  Total calls: {summary.get('total_calls')}")
    print(f"  Total cycles: {summary.get('total_cycles')}")

    print("\nModule Breakdown (top 5):")
    for module in summary.get("module_breakdown", [])[:5]:
        print(f"  {module['module_name']:20s} {module['calls']:6d} calls, {module['total_cycles']:10d} cycles ({module['percentage']:>6s})")

    print("\nHottest Modules:")
    hottest = reader.get_hottest_modules(5)
    for profile in hottest:
        print(f"  {profile.get('module_name'):20s} max_cycles={profile.get('max_cycles', 0)}")

    reader.close()
