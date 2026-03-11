#!/usr/bin/env python3
"""
OmniBus Performance Profiler Analysis Tool
Analyzes module latencies and identifies optimization bottlenecks
"""

import struct
import sys
from collections import namedtuple

# Module definitions (0-33)
MODULES = {
    0: ("Grid OS", 0x110000),
    1: ("Execution OS", 0x130000),
    2: ("Analytics OS", 0x150000),
    3: ("BlockchainOS", 0x250000),
    4: ("NeuroOS", 0x2D0000),
    5: ("BankOS", 0x280000),
    6: ("StealthOS", 0x2C0000),
    7: ("Report OS", 0x300000),
    8: ("Checksum OS", 0x310000),
    9: ("AutoRepair OS", 0x320000),
    10: ("Zorin OS", 0x330000),
    11: ("Audit Log OS", 0x340000),
    12: ("Param Tuning OS", 0x360000),
    13: ("Historical Analytics OS", 0x370000),
    14: ("Alert System OS", 0x380000),
    15: ("Consensus Engine OS", 0x390000),
    16: ("Federation OS", 0x3A0000),
    17: ("MEV Guard OS", 0x3B0000),
    18: ("Cross-Chain Bridge OS", 0x3C0000),
    19: ("DAO Governance OS", 0x3D0000),
    20: ("Performance Profiler OS", 0x3E0000),
    21: ("Disaster Recovery OS", 0x3F0000),
    22: ("Compliance Reporter OS", 0x410000),
    23: ("Liquid Staking OS", 0x420000),
    24: ("Slashing Protection OS", 0x430000),
    25: ("Orderflow Auction OS", 0x440000),
    26: ("Circuit Breaker OS", 0x450000),
    27: ("Flash Loan Protection OS", 0x460000),
    28: ("L2 Rollup Bridge OS", 0x470000),
    29: ("Quantum Resistant Crypto OS", 0x480000),
    30: ("PQC-GATE OS", 0x490000),
    31: ("Reserved", 0),
    32: ("Reserved", 0),
}

ModuleProfile = namedtuple("ModuleProfile",
    ["module_id", "call_count", "total_cycles", "min_cycles", "max_cycles", "avg_cycles", "last_call_cycles"])

def parse_module_profile(data, module_id):
    """Parse a single module profile from binary data"""
    offset = module_id * 40  # ModuleProfile is 40 bytes
    if offset + 40 > len(data):
        return None

    unpacked = struct.unpack("<HHIIIII", data[offset:offset+40])
    return ModuleProfile(module_id=unpacked[0], call_count=unpacked[2],
                        total_cycles=unpacked[3], min_cycles=unpacked[4],
                        max_cycles=unpacked[5], avg_cycles=unpacked[6],
                        last_call_cycles=unpacked[7])

def analyze_performance(memory_data, profiler_base=0x3E0000):
    """
    Analyze performance data from memory image
    Returns profiling statistics for all modules
    """

    # Skip ProfilerState (128 bytes) to get to module profiles
    profiles_offset = profiler_base + 128

    results = []
    for module_id in range(33):
        profile_offset = profiles_offset - profiler_base + (module_id * 40)
        if profile_offset + 40 <= len(memory_data):
            try:
                profile = parse_module_profile(memory_data[profile_offset:], 0)
                if profile and profile.call_count > 0:
                    module_name = MODULES[module_id][0]
                    avg_latency = profile.total_cycles // profile.call_count if profile.call_count > 0 else 0
                    efficiency = (profile.avg_cycles / profile.max_cycles * 100) if profile.max_cycles > 0 else 0

                    results.append({
                        "module_id": module_id,
                        "name": module_name,
                        "calls": profile.call_count,
                        "total_cycles": profile.total_cycles,
                        "min_cycles": profile.min_cycles,
                        "max_cycles": profile.max_cycles,
                        "avg_cycles": profile.avg_cycles,
                        "last_cycles": profile.last_call_cycles,
                        "efficiency": efficiency,
                    })
            except:
                pass

    return results

def print_performance_report(results):
    """Print formatted performance report"""
    print("\n" + "="*100)
    print("OmniBus Performance Analysis Report")
    print("="*100)
    print(f"\n{'Module':<30} {'Calls':<8} {'Avg μs':<10} {'Min μs':<10} {'Max μs':<10} {'Jitter':<10}")
    print("-"*100)

    total_calls = sum(r["calls"] for r in results)
    total_cycles = sum(r["total_cycles"] for r in results)

    # Sort by max latency (bottlenecks first)
    results_sorted = sorted(results, key=lambda x: x["max_cycles"], reverse=True)

    for r in results_sorted:
        jitter = ((r["max_cycles"] - r["min_cycles"]) / r["avg_cycles"] * 100) if r["avg_cycles"] > 0 else 0
        print(f"{r['name']:<30} {r['calls']:<8} {r['avg_cycles']:<10} {r['min_cycles']:<10} {r['max_cycles']:<10} {jitter:>7.1f}%")

    print("-"*100)
    print(f"{'TOTAL':<30} {total_calls:<8} {total_cycles//total_calls if total_calls > 0 else 0:<10}")

    # Critical path analysis
    print("\n" + "="*100)
    print("Critical Path Analysis (Top 5 Bottlenecks)")
    print("="*100)

    for i, r in enumerate(results_sorted[:5], 1):
        pct = (r["total_cycles"] / total_cycles * 100) if total_cycles > 0 else 0
        print(f"{i}. {r['name']:<30} | Max: {r['max_cycles']:>8} cycles | {pct:>5.2f}% of total time")

    print("\n" + "="*100)
    print("Optimization Opportunities")
    print("="*100)

    # High variance modules
    high_jitter = [r for r in results_sorted if ((r["max_cycles"] - r["min_cycles"]) / r["avg_cycles"]) > 0.5]
    if high_jitter:
        print("\n⚠️  High Jitter Modules (unpredictable latency):")
        for r in high_jitter[:3]:
            jitter = ((r["max_cycles"] - r["min_cycles"]) / r["avg_cycles"] * 100)
            print(f"   - {r['name']}: {jitter:.1f}% jitter (investigate cache/branch behavior)")

    # Slow modules
    slow_modules = [r for r in results_sorted if r["max_cycles"] > 100000]
    if slow_modules:
        print("\n🐢 Slow Modules (>100k cycles):")
        for r in slow_modules[:3]:
            print(f"   - {r['name']}: {r['max_cycles']} cycles (candidate for optimization)")

    # Quick wins
    quick_wins = [r for r in results_sorted if r["calls"] > 100 and r["avg_cycles"] > 1000]
    if quick_wins:
        print("\n⚡ Quick Win Opportunities (high call count + moderate latency):")
        for r in quick_wins[:3]:
            savings = (r["max_cycles"] - r["avg_cycles"]) * r["calls"]
            print(f"   - {r['name']}: {r['calls']} calls, reducing max by 20% saves {savings} cycles")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_performance.py <memory_dump.bin>")
        sys.exit(1)

    try:
        with open(sys.argv[1], "rb") as f:
            memory_data = f.read()

        results = analyze_performance(memory_data)
        print_performance_report(results)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
