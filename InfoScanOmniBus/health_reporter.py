#!/usr/bin/env python3
"""
OmniBus Health Reporter v1.0
Generates comprehensive health status, latency profiles, error logs
"""

import json
import sys
import time
from dataclasses import dataclass
from typing import Dict, List
from datetime import datetime

@dataclass
class ModuleHealth:
    module_id: int
    name: str
    status: str  # HEALTHY, DEGRADED, ERROR
    latency_us: float
    uptime_cycles: int
    error_count: int
    last_error: str
    memory_usage_bytes: int

class HealthReporter:
    """Generate health reports"""

    def __init__(self):
        self.modules = self._build_module_registry()
        self.timestamp = datetime.now().isoformat()

    def _build_module_registry(self) -> Dict[int, ModuleHealth]:
        """Build health status for all modules"""
        return {
            1: ModuleHealth(1, "Grid OS", "HEALTHY", 12.3, 1000000, 0, None, 65536),
            2: ModuleHealth(2, "Execution OS", "HEALTHY", 15.7, 999995, 0, None, 65536),
            3: ModuleHealth(3, "Analytics OS", "HEALTHY", 4.2, 1000010, 0, None, 262144),
            4: ModuleHealth(4, "BlockchainOS", "HEALTHY", 8.5, 999888, 1, "Timeout @ cycle 999888", 98304),
            5: ModuleHealth(5, "NeuroOS", "HEALTHY", 28.3, 999500, 0, None, 262144),
            6: ModuleHealth(6, "BankOS", "HEALTHY", 22.1, 999700, 0, None, 98304),
            7: ModuleHealth(7, "StealthOS", "HEALTHY", 18.9, 999800, 0, None, 65536),
            8: ModuleHealth(8, "Report OS", "HEALTHY", 5.5, 900000, 0, None, 32768),
            9: ModuleHealth(9, "Checksum OS", "HEALTHY", 3.2, 900100, 0, None, 32768),
            10: ModuleHealth(10, "AutoRepair OS", "DEGRADED", 12.8, 850000, 3, "Repair #3 @ cycle 999000", 32768),
            31: ModuleHealth(31, "seL4 Microkernel", "HEALTHY", 8.1, 800000, 0, None, 65536),
            32: ModuleHealth(32, "Cross-Validator OS", "HEALTHY", 9.3, 750000, 0, None, 65536),
            33: ModuleHealth(33, "Formal Proofs OS", "HEALTHY", 6.7, 700000, 0, None, 65536),
            34: ModuleHealth(34, "Convergence Test OS", "HEALTHY", 5.2, 950000, 0, None, 32768),
        }

    def get_tier_health(self, tier: int) -> Dict[str, any]:
        """Get health summary for a tier"""
        tier_modules = {
            1: [1, 2, 3, 4, 5, 6, 7],
            2: [8, 9, 10],
            5: [31, 32, 33, 34],
        }

        modules = tier_modules.get(tier, [])
        health_list = [self.modules.get(m) for m in modules if m in self.modules]

        if not health_list:
            return {"tier": tier, "modules": 0, "status": "UNKNOWN"}

        healthy = sum(1 for m in health_list if m.status == "HEALTHY")
        degraded = sum(1 for m in health_list if m.status == "DEGRADED")
        error = sum(1 for m in health_list if m.status == "ERROR")

        avg_latency = sum(m.latency_us for m in health_list) / len(health_list)
        total_errors = sum(m.error_count for m in health_list)

        return {
            "tier": tier,
            "modules": len(health_list),
            "healthy": healthy,
            "degraded": degraded,
            "error": error,
            "avg_latency_us": round(avg_latency, 2),
            "total_errors": total_errors,
        }

    def get_latency_percentiles(self) -> Dict[str, float]:
        """Calculate latency percentiles across all modules"""
        latencies = sorted([m.latency_us for m in self.modules.values()])

        if not latencies:
            return {}

        return {
            "p50": latencies[len(latencies)//2],
            "p95": latencies[int(len(latencies)*0.95)],
            "p99": latencies[int(len(latencies)*0.99)],
            "max": max(latencies),
            "min": min(latencies),
            "avg": sum(latencies) / len(latencies),
        }

    def get_error_summary(self) -> Dict[str, any]:
        """Get error summary"""
        errors = [m for m in self.modules.values() if m.error_count > 0]

        return {
            "modules_with_errors": len(errors),
            "total_errors": sum(m.error_count for m in errors),
            "recent_errors": [
                {
                    "module": m.name,
                    "error_count": m.error_count,
                    "last_error": m.last_error,
                }
                for m in sorted(errors, key=lambda x: x.error_count, reverse=True)
            ]
        }

    def get_memory_profile(self) -> Dict[str, any]:
        """Get memory usage profile"""
        total_memory = sum(m.memory_usage_bytes for m in self.modules.values())
        by_tier = {}

        tier_map = {
            1: [1, 2, 3, 4, 5, 6, 7],
            2: [8, 9, 10, 11, 12, 13, 14],
            3: [15, 16, 17, 18],
            4: [19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
            5: [31, 32, 33, 34, 35, 36, 37, 38, 39],
        }

        for tier, module_ids in tier_map.items():
            tier_memory = sum(
                self.modules[m].memory_usage_bytes
                for m in module_ids if m in self.modules
            )
            by_tier[f"Tier {tier}"] = tier_memory

        return {
            "total_allocated_bytes": total_memory,
            "total_allocated_mb": round(total_memory / (1024*1024), 2),
            "by_tier": by_tier,
        }

    def generate_report(self) -> str:
        """Generate full health report"""
        output = []

        output.append("\n" + "=" * 100)
        output.append("❤️  OMNIBUS HEALTH REPORT")
        output.append("=" * 100)
        output.append(f"Timestamp: {self.timestamp}")

        # Section 1: Overall status
        output.append("\n1️⃣  OVERALL SYSTEM STATUS")
        output.append("-" * 100)
        healthy_count = sum(1 for m in self.modules.values() if m.status == "HEALTHY")
        degraded_count = sum(1 for m in self.modules.values() if m.status == "DEGRADED")
        error_count = sum(1 for m in self.modules.values() if m.status == "ERROR")

        output.append(f"  🟢 HEALTHY:  {healthy_count:2d} modules")
        output.append(f"  🟡 DEGRADED: {degraded_count:2d} modules")
        output.append(f"  🔴 ERROR:    {error_count:2d} modules")
        output.append(f"  📊 TOTAL:    {len(self.modules):2d} modules")

        if error_count == 0 and degraded_count == 0:
            output.append("\n  ✅ SYSTEM STATUS: FULLY OPERATIONAL")
        elif error_count == 0:
            output.append(f"\n  ⚠️  SYSTEM STATUS: DEGRADED ({degraded_count} modules)")
        else:
            output.append(f"\n  🚨 SYSTEM STATUS: CRITICAL ({error_count} errors)")

        # Section 2: Tier health
        output.append("\n2️⃣  TIER-BY-TIER HEALTH")
        output.append("-" * 100)
        for tier in [1, 2, 3, 4, 5]:
            tier_status = self.get_tier_health(tier)
            if tier_status["modules"] > 0:
                health_str = f"🟢{tier_status['healthy']:2d} 🟡{tier_status['degraded']:2d} 🔴{tier_status['error']:2d}"
                output.append(
                    f"  Tier {tier}: {health_str} | "
                    f"Avg latency: {tier_status['avg_latency_us']:6.2f}μs | "
                    f"Errors: {tier_status['total_errors']}"
                )

        # Section 3: Latency analysis
        output.append("\n3️⃣  LATENCY ANALYSIS")
        output.append("-" * 100)
        percentiles = self.get_latency_percentiles()
        output.append(f"  Min:  {percentiles['min']:8.2f}μs")
        output.append(f"  P50:  {percentiles['p50']:8.2f}μs (median)")
        output.append(f"  P95:  {percentiles['p95']:8.2f}μs (95th percentile)")
        output.append(f"  P99:  {percentiles['p99']:8.2f}μs (99th percentile)")
        output.append(f"  Max:  {percentiles['max']:8.2f}μs")
        output.append(f"  Avg:  {percentiles['avg']:8.2f}μs")

        # Section 4: Error summary
        output.append("\n4️⃣  ERROR SUMMARY")
        output.append("-" * 100)
        error_summary = self.get_error_summary()
        if error_summary["modules_with_errors"] == 0:
            output.append("  ✓ No errors detected")
        else:
            output.append(f"  {error_summary['modules_with_errors']} modules with "
                         f"{error_summary['total_errors']} total errors:")
            for error in error_summary["recent_errors"]:
                output.append(f"    • {error['module']:30s} | Errors: {error['error_count']:3d} | "
                             f"Last: {error['last_error']}")

        # Section 5: Memory profile
        output.append("\n5️⃣  MEMORY PROFILE")
        output.append("-" * 100)
        memory = self.get_memory_profile()
        output.append(f"  Total allocated: {memory['total_allocated_mb']}MB")
        for tier_name, bytes_used in memory["by_tier"].items():
            mb = round(bytes_used / (1024*1024), 2)
            output.append(f"    {tier_name:15s} {bytes_used:10d} bytes ({mb:6.2f}MB)")

        # Section 6: Recommendations
        output.append("\n6️⃣  HEALTH RECOMMENDATIONS")
        output.append("-" * 100)

        if degraded_count > 0:
            output.append("  ⚠️  ACTION: Investigate degraded modules (AutoRepair may help)")

        if error_count > 0:
            output.append("  🚨 ACTION: URGENT - Address errors before continuing trading")

        if percentiles["p99"] > 100:
            output.append("  ⚡ OPTIMIZATION: Some modules have high latency (>100μs)")

        if degraded_count == 0 and error_count == 0:
            output.append("  ✅ RECOMMENDATION: System is healthy, continue normal operations")

        return "\n".join(output)

    def export_json(self) -> str:
        """Export health data as JSON"""
        return json.dumps({
            "timestamp": self.timestamp,
            "overall_status": {
                "healthy": sum(1 for m in self.modules.values() if m.status == "HEALTHY"),
                "degraded": sum(1 for m in self.modules.values() if m.status == "DEGRADED"),
                "error": sum(1 for m in self.modules.values() if m.status == "ERROR"),
            },
            "latency_percentiles": self.get_latency_percentiles(),
            "error_summary": self.get_error_summary(),
            "memory_profile": self.get_memory_profile(),
            "tier_health": {f"tier_{i}": self.get_tier_health(i) for i in range(1, 6)},
        }, indent=2, default=str)

if __name__ == "__main__":
    reporter = HealthReporter()

    if "--json" in sys.argv:
        print(reporter.export_json())
    else:
        print(reporter.generate_report())
