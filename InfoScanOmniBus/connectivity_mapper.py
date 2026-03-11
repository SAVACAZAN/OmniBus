#!/usr/bin/env python3
"""
OmniBus Connectivity Mapper v1.0
Maps inter-module communication, detects circular dependencies, visualizes data flow
"""

import json
import sys
from dataclasses import dataclass
from typing import Dict, List, Set, Tuple
from collections import defaultdict, deque

@dataclass
class ModuleConnection:
    source: int
    target: int
    source_name: str
    target_name: str
    type: str  # "read", "write", "ipc"
    latency_cycles: int

# Module definitions
MODULES = {
    1: ("Grid OS", [3]),  # (name, [dependencies])
    2: ("Execution OS", [1, 3]),
    3: ("Analytics OS", []),
    4: ("BlockchainOS", [2]),
    5: ("NeuroOS", [1, 2]),
    6: ("BankOS", [2]),
    7: ("StealthOS", [2]),
    8: ("Report OS", [1, 2, 3, 4]),
    9: ("Checksum OS", []),
    10: ("AutoRepair OS", [9]),
    11: ("Zorin OS", []),
    12: ("Audit Log OS", []),
    13: ("Parameter Tuning OS", [1, 5]),
    14: ("Historical Analytics OS", [3]),
    15: ("Alert System OS", []),
    16: ("Consensus Engine OS", [1, 2, 4]),
    17: ("Federation OS", []),
    18: ("MEV Guard OS", [2, 6]),
    19: ("Cross-Chain Bridge OS", [4, 6]),
    20: ("DAO Governance OS", []),
    21: ("Recovery OS", [9, 10]),
    22: ("Compliance OS", [12]),
    23: ("Staking OS", [4]),
    24: ("Slashing Protection OS", [23]),
    25: ("Orderflow Auction OS", [2]),
    26: ("Circuit Breaker OS", [2]),
    27: ("Flash Loan Protection OS", [4]),
    28: ("L2 Rollup Bridge OS", [4]),
    29: ("Quantum-Resistant Crypto OS", []),
    30: ("PQC-GATE OS", [29]),
    31: ("seL4 Microkernel", []),
    32: ("Cross-Validator OS", [31]),
    33: ("Formal Proofs OS", [31, 32]),
    34: ("Convergence Test OS", [31, 32, 33]),
    35: ("Domain Resolver OS", [3]),
    36: ("LoggingOS", []),
    37: ("DatabaseOS", [36]),
    38: ("CassandraOS", [37]),
    39: ("MetricsOS", [36, 8]),
}

class ConnectivityAnalyzer:
    """Analyze module interconnectivity"""

    def __init__(self):
        self.modules = MODULES
        self.graph = defaultdict(list)  # module_id → [dependent_ids]
        self.reverse_graph = defaultdict(list)  # module_id → [modules_that_depend_on_it]
        self.cycles = []
        self.build_graph()

    def build_graph(self):
        """Build dependency graph"""
        for module_id, (name, deps) in self.modules.items():
            for dep_id in deps:
                self.graph[module_id].append(dep_id)
                self.reverse_graph[dep_id].append(module_id)

    def detect_circular_deps(self) -> List[List[int]]:
        """Detect circular dependencies (MUST BE ZERO)"""
        visited = set()
        rec_stack = set()
        cycles = []

        def dfs(node, path):
            visited.add(node)
            rec_stack.add(node)
            path.append(node)

            for neighbor in self.graph[node]:
                if neighbor not in visited:
                    dfs(neighbor, path[:])
                elif neighbor in rec_stack:
                    # Found cycle
                    cycle_start = path.index(neighbor)
                    cycle = path[cycle_start:] + [neighbor]
                    cycles.append(cycle)

            rec_stack.remove(node)

        for node in self.modules.keys():
            if node not in visited:
                dfs(node, [])

        return cycles

    def compute_dependency_depth(self) -> Dict[int, int]:
        """Compute depth of each module in dependency tree"""
        depths = {}

        def compute_depth(module_id, memo=None):
            if memo is None:
                memo = {}
            if module_id in memo:
                return memo[module_id]

            deps = self.graph[module_id]
            if not deps:
                depth = 0
            else:
                depth = 1 + max(compute_depth(d, memo) for d in deps)

            memo[module_id] = depth
            return depth

        for module_id in self.modules.keys():
            depths[module_id] = compute_depth(module_id)

        return depths

    def find_critical_path(self) -> Tuple[List[int], int]:
        """Find longest dependency chain (critical path)"""
        depths = self.compute_dependency_depth()
        max_depth = max(depths.values())
        critical_modules = [m for m, d in depths.items() if d == max_depth]
        return critical_modules, max_depth

    def analyze_fan_in_out(self) -> Dict[str, List[Tuple[int, int]]]:
        """Analyze fan-in (how many depend on each) and fan-out (how many each depends on)"""
        fan_in = {}
        fan_out = {}

        for module_id in self.modules.keys():
            fan_in[module_id] = len(self.reverse_graph[module_id])
            fan_out[module_id] = len(self.graph[module_id])

        # High fan-in (many modules depend on this) = bottleneck risk
        high_fan_in = sorted(fan_in.items(), key=lambda x: x[1], reverse=True)[:5]
        high_fan_out = sorted(fan_out.items(), key=lambda x: x[1], reverse=True)[:5]

        return {
            "high_fan_in": high_fan_in,  # Bottleneck risk
            "high_fan_out": high_fan_out,  # Complexity risk
        }

    def generate_visual_matrix(self) -> str:
        """Generate ASCII connectivity matrix"""
        output = []
        output.append("\n📊 CONNECTIVITY MATRIX (Module→Dependency)")
        output.append("=" * 100)

        # Group by tier
        tiers = {
            1: [m for m in self.modules if m <= 7],
            2: [m for m in self.modules if 8 <= m <= 14],
            3: [m for m in self.modules if 15 <= m <= 18],
            4: [m for m in self.modules if 19 <= m <= 30],
            5: [m for m in self.modules if 31 <= m <= 39],
        }

        tier_names = {
            1: "TIER 1: Real-Time Trading (Critical)",
            2: "TIER 2: System Services",
            3: "TIER 3: Notification & Coordination",
            4: "TIER 4: Advanced Protection",
            5: "TIER 5: Formal Verification",
        }

        for tier in range(1, 6):
            output.append(f"\n{tier_names[tier]}")
            output.append("-" * 100)

            for module_id in sorted(tiers[tier]):
                name, deps = self.modules[module_id]
                if deps:
                    dep_names = " + ".join([f"L{d}({self.modules[d][0][:10]})" for d in deps])
                    output.append(f"  L{module_id:02d} {name:30s} ← {dep_names}")
                else:
                    output.append(f"  L{module_id:02d} {name:30s} [SOURCE]")

        return "\n".join(output)

    def generate_report(self) -> str:
        """Generate full connectivity report"""
        output = []

        # Section 1: Circular dependencies
        output.append("\n" + "=" * 100)
        output.append("🔄 CIRCULAR DEPENDENCY CHECK")
        output.append("=" * 100)
        cycles = self.detect_circular_deps()
        if cycles:
            output.append(f"❌ {len(cycles)} CIRCULAR DEPENDENCIES DETECTED (FATAL!):")
            for cycle in cycles:
                cycle_str = " → ".join([f"L{m}" for m in cycle])
                output.append(f"   {cycle_str}")
        else:
            output.append("✓ NO CIRCULAR DEPENDENCIES (System is acyclic)")

        # Section 2: Dependency depth
        output.append("\n" + "=" * 100)
        output.append("📈 DEPENDENCY DEPTH (Execution Order)")
        output.append("=" * 100)
        depths = self.compute_dependency_depth()
        critical, max_depth = self.find_critical_path()
        output.append(f"Critical path depth: {max_depth}")
        output.append(f"Critical modules: {critical}")

        # Section 3: Fan-in/out analysis
        output.append("\n" + "=" * 100)
        output.append("⚠️  BOTTLENECK & COMPLEXITY ANALYSIS")
        output.append("=" * 100)
        analysis = self.analyze_fan_in_out()

        output.append("\nHIGH FAN-IN (Bottleneck Risk - Many modules depend on these):")
        for module_id, count in analysis["high_fan_in"]:
            name, _ = self.modules[module_id]
            output.append(f"  L{module_id:02d} {name:30s} | {count:2d} modules depend on it")

        output.append("\nHIGH FAN-OUT (Complexity Risk - Depends on many modules):")
        for module_id, count in analysis["high_fan_out"]:
            name, _ = self.modules[module_id]
            output.append(f"  L{module_id:02d} {name:30s} | Depends on {count:2d} modules")

        # Section 4: Visual matrix
        output.append(self.generate_visual_matrix())

        # Section 5: Data flow recommendations
        output.append("\n" + "=" * 100)
        output.append("💡 OPTIMIZATION RECOMMENDATIONS")
        output.append("=" * 100)

        for module_id, count in analysis["high_fan_in"][:3]:
            name, _ = self.modules[module_id]
            output.append(f"• L{module_id} ({name}): Cache output to reduce re-computation")

        for module_id, count in analysis["high_fan_out"][:3]:
            name, _ = self.modules[module_id]
            output.append(f"• L{module_id} ({name}): Simplify logic or split dependencies")

        return "\n".join(output)

    def export_json(self) -> str:
        """Export as JSON for tooling"""
        return json.dumps({
            "modules": len(self.modules),
            "circular_deps": len(self.detect_circular_deps()),
            "critical_path": self.find_critical_path()[1],
            "fan_analysis": self.analyze_fan_in_out(),
            "dependency_map": {
                str(k): list(v) for k, v in self.graph.items()
            }
        }, indent=2)

if __name__ == "__main__":
    analyzer = ConnectivityAnalyzer()

    if "--json" in sys.argv:
        print(analyzer.export_json())
    else:
        print(analyzer.generate_report())
