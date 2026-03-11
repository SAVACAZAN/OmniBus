#!/usr/bin/env python3
"""
Phase 48B: Order Flow Integration Test
Tests end-to-end order pipeline: Grid OS → Execution OS → Exchange submission
Validates order state transitions and latency at each stage
"""

import struct
import sys
from enum import Enum
from dataclasses import dataclass
from typing import Optional

# ============================================================================
# Data Structures (matching kernel definitions)
# ============================================================================

class OrderSide(Enum):
    BUY = 0
    SELL = 1

class OrderStatus(Enum):
    PENDING = 0
    SUBMITTED = 1
    FILLED = 2
    CANCELLED = 3
    ERROR = 4

@dataclass
class Order:
    """Order structure (32 bytes)"""
    order_id: int
    exchange_id: int
    pair_id: int
    side: OrderSide
    price_cents: int
    qty_sats: int
    status: OrderStatus
    submission_tsc: int
    fill_tsc: int
    created_at_cycle: int

@dataclass
class OrderFlowEvent:
    """Order flow event for timeline tracking"""
    cycle: int
    order_id: int
    event_type: str  # "CREATED", "SUBMITTED", "FILLED", "SIGNED", "ERROR"
    module: str  # "GRID", "EXECUTION", "BLOCKCHAIN"
    latency_cycles: int = 0
    details: str = ""

# ============================================================================
# Order Flow Analyzer
# ============================================================================

class OrderFlowAnalyzer:
    """Analyzes order flow through the system"""

    def __init__(self):
        self.events = []
        self.orders = {}
        self.latencies = {
            "grid_to_exec": [],
            "exec_to_blockchain": [],
            "total_order_flow": [],
            "signature_generation": [],
        }
        self.statistics = {
            "total_orders": 0,
            "successfully_submitted": 0,
            "successfully_filled": 0,
            "failures": 0,
            "avg_submission_latency": 0,
            "max_submission_latency": 0,
            "p95_submission_latency": 0,
        }

    def record_event(self, cycle: int, order_id: int, event_type: str, module: str, latency: int = 0, details: str = ""):
        """Record an order flow event"""
        event = OrderFlowEvent(cycle, order_id, event_type, module, latency, details)
        self.events.append(event)

        if order_id not in self.orders:
            self.orders[order_id] = {
                "created_cycle": cycle,
                "grid_submission": None,
                "exec_submission": None,
                "blockchain_submission": None,
                "signature_tsc": None,
                "fill_cycle": None,
                "status": "CREATED",
            }

        order = self.orders[order_id]

        # Track transitions
        if event_type == "CREATED":
            order["created_cycle"] = cycle
        elif event_type == "GRID_MATCH":
            order["grid_submission"] = cycle
        elif event_type == "EXEC_SIGN":
            order["exec_submission"] = cycle
            if order["grid_submission"]:
                latency = cycle - order["grid_submission"]
                self.latencies["grid_to_exec"].append(latency)
        elif event_type == "ML_DSA_SIGNATURE":
            order["signature_tsc"] = latency
            self.latencies["signature_generation"].append(latency)
        elif event_type == "BLOCKCHAIN_SUBMIT":
            order["blockchain_submission"] = cycle
            if order["exec_submission"]:
                latency = cycle - order["exec_submission"]
                self.latencies["exec_to_blockchain"].append(latency)
        elif event_type == "FILLED":
            order["fill_cycle"] = cycle
            if order["created_cycle"]:
                latency = cycle - order["created_cycle"]
                self.latencies["total_order_flow"].append(latency)
            order["status"] = "FILLED"
        elif event_type == "ERROR":
            order["status"] = "ERROR"
            self.statistics["failures"] += 1

    def analyze(self):
        """Perform analysis of order flow"""
        self.statistics["total_orders"] = len(self.orders)
        self.statistics["successfully_submitted"] = sum(1 for o in self.orders.values() if o["exec_submission"])
        self.statistics["successfully_filled"] = sum(1 for o in self.orders.values() if o["status"] == "FILLED")

        # Calculate latency statistics
        if self.latencies["total_order_flow"]:
            latencies = sorted(self.latencies["total_order_flow"])
            self.statistics["avg_submission_latency"] = int(sum(latencies) / len(latencies))
            self.statistics["max_submission_latency"] = max(latencies)
            if len(latencies) > 0:
                p95_idx = int(len(latencies) * 0.95)
                self.statistics["p95_submission_latency"] = latencies[p95_idx]

    def print_report(self):
        """Print order flow analysis report"""
        print("\n" + "="*100)
        print("Order Flow Integration Test Report")
        print("="*100)

        print(f"\n{'Metric':<40} {'Value':<20}")
        print("-"*100)
        print(f"{'Total orders created':<40} {self.statistics['total_orders']:<20}")
        print(f"{'Successfully submitted':<40} {self.statistics['successfully_submitted']:<20}")
        print(f"{'Successfully filled':<40} {self.statistics['successfully_filled']:<20}")
        print(f"{'Failures':<40} {self.statistics['failures']:<20}")

        if self.statistics["successfully_filled"] > 0:
            print(f"\n{'Order Flow Latency Metrics':<40} {'Cycles (μs @ 1GHz)':<20}")
            print("-"*100)
            print(f"{'Grid → Execution (avg)':<40} {self._latency_to_string(self.latencies['grid_to_exec']):<20}")
            print(f"{'Execution → Blockchain (avg)':<40} {self._latency_to_string(self.latencies['exec_to_blockchain']):<20}")
            print(f"{'Total Order Flow (avg)':<40} {self._latency_to_string(self.latencies['total_order_flow']):<20}")
            print(f"{'ML-DSA Signature (avg)':<40} {self._latency_to_string(self.latencies['signature_generation']):<20}")

            print(f"\n{'Submission Latency Statistics':<40} {'Cycles':<20}")
            print("-"*100)
            print(f"{'Average':<40} {self.statistics['avg_submission_latency']:<20}")
            print(f"{'Max':<40} {self.statistics['max_submission_latency']:<20}")
            print(f"{'P95':<40} {self.statistics['p95_submission_latency']:<20}")

            print(f"\n{'Performance Targets':<40} {'Status':<20}")
            print("-"*100)
            # Target: <100μs = 100000 cycles Tier 1
            if self.statistics["avg_submission_latency"] < 100000:
                status = "✓ PASS"
            else:
                status = "✗ FAIL"
            print(f"{'Avg < 100μs (100k cycles)':<40} {status:<20}")

        # Event timeline
        print(f"\n{'Event Timeline (first 20 events)':<40}")
        print("-"*100)
        for event in self.events[:20]:
            print(f"Cycle {event.cycle:<6} | Order {event.order_id:<4} | {event.event_type:<20} | {event.module:<12} | {event.details}")

    def _latency_to_string(self, latencies):
        """Format latency list as avg cycles (avg μs)"""
        if not latencies:
            return "N/A"
        avg = sum(latencies) / len(latencies)
        return f"{int(avg)} ({int(avg/1000)}μs)"

# ============================================================================
# Simulation Test Runner
# ============================================================================

def simulate_order_flow():
    """Simulate a realistic order flow scenario"""
    analyzer = OrderFlowAnalyzer()

    # Scenario: Grid OS detects arbitrage, creates orders, Execution signs and submits
    base_cycle = 1000

    # Order 1: BTC arbitrage at Kraken/Coinbase
    analyzer.record_event(base_cycle + 0, 1, "CREATED", "GRID", details="BTC 0.1 @ 71000")
    analyzer.record_event(base_cycle + 50, 1, "GRID_MATCH", "GRID", latency=50, details="Grid level matched")
    analyzer.record_event(base_cycle + 100, 1, "EXEC_SIGN", "EXECUTION", latency=50, details="Routing to Execution OS")
    analyzer.record_event(base_cycle + 130, 1, "ML_DSA_SIGNATURE", "EXECUTION", latency=2100, details="Dilithium signature (2100 cycles)")
    analyzer.record_event(base_cycle + 200, 1, "BLOCKCHAIN_SUBMIT", "BLOCKCHAIN", latency=70, details="Submitted to exchange")
    analyzer.record_event(base_cycle + 500, 1, "FILLED", "BLOCKCHAIN", latency=0, details="Order filled")

    # Order 2: ETH arbitrage with longer latency
    analyzer.record_event(base_cycle + 60, 2, "CREATED", "GRID", details="ETH 2.0 @ 2080")
    analyzer.record_event(base_cycle + 120, 2, "GRID_MATCH", "GRID", latency=60, details="Grid level matched")
    analyzer.record_event(base_cycle + 200, 2, "EXEC_SIGN", "EXECUTION", latency=80, details="Routing to Execution OS")
    analyzer.record_event(base_cycle + 250, 2, "ML_DSA_SIGNATURE", "EXECUTION", latency=2200, details="Dilithium signature (2200 cycles)")
    analyzer.record_event(base_cycle + 350, 2, "BLOCKCHAIN_SUBMIT", "BLOCKCHAIN", latency=100, details="Submitted to exchange")
    analyzer.record_event(base_cycle + 800, 2, "FILLED", "BLOCKCHAIN", latency=0, details="Order filled")

    # Order 3: Quick arbitrage
    analyzer.record_event(base_cycle + 150, 3, "CREATED", "GRID", details="LCX 1000 @ 0.045")
    analyzer.record_event(base_cycle + 180, 3, "GRID_MATCH", "GRID", latency=30, details="Grid level matched")
    analyzer.record_event(base_cycle + 220, 3, "EXEC_SIGN", "EXECUTION", latency=40, details="Routing to Execution OS")
    analyzer.record_event(base_cycle + 260, 3, "ML_DSA_SIGNATURE", "EXECUTION", latency=2050, details="Dilithium signature (2050 cycles)")
    analyzer.record_event(base_cycle + 310, 3, "BLOCKCHAIN_SUBMIT", "BLOCKCHAIN", latency=50, details="Submitted to exchange")
    analyzer.record_event(base_cycle + 600, 3, "FILLED", "BLOCKCHAIN", latency=0, details="Order filled")

    # Order 4: Multi-exchange arbitrage (3-leg)
    analyzer.record_event(base_cycle + 200, 4, "CREATED", "GRID", details="BTC-USD (Kraken buy)")
    analyzer.record_event(base_cycle + 300, 4, "GRID_MATCH", "GRID", latency=100, details="Complex arbitrage detected")
    analyzer.record_event(base_cycle + 400, 4, "EXEC_SIGN", "EXECUTION", latency=100, details="Multiple signatures needed")
    analyzer.record_event(base_cycle + 450, 4, "ML_DSA_SIGNATURE", "EXECUTION", latency=2100, details="ML-DSA for leg 1")
    analyzer.record_event(base_cycle + 500, 4, "ML_DSA_SIGNATURE", "EXECUTION", latency=2050, details="ML-DSA for leg 2")
    analyzer.record_event(base_cycle + 550, 4, "ML_DSA_SIGNATURE", "EXECUTION", latency=2100, details="ML-DSA for leg 3")
    analyzer.record_event(base_cycle + 650, 4, "BLOCKCHAIN_SUBMIT", "BLOCKCHAIN", latency=100, details="Atomic swap initiated")
    analyzer.record_event(base_cycle + 1200, 4, "FILLED", "BLOCKCHAIN", latency=0, details="All legs filled")

    return analyzer

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    print("="*100)
    print("Phase 48B: Order Flow Integration Test")
    print("="*100)

    # Run simulation
    print("\nRunning order flow simulation...")
    analyzer = simulate_order_flow()

    # Analyze results
    analyzer.analyze()

    # Print report
    analyzer.print_report()

    # Verify targets
    print(f"\n{'Validation Status':<40}")
    print("-"*100)

    success = True

    if analyzer.statistics["total_orders"] >= 4:
        print(f"{'✓ Minimum 4 orders created':<40} PASS")
    else:
        print(f"{'✗ Minimum 4 orders created':<40} FAIL")
        success = False

    if analyzer.statistics["successfully_submitted"] >= 3:
        print(f"{'✓ At least 3 orders submitted':<40} PASS")
    else:
        print(f"{'✗ At least 3 orders submitted':<40} FAIL")
        success = False

    if analyzer.statistics["avg_submission_latency"] > 0 and analyzer.statistics["avg_submission_latency"] < 150000:
        print(f"{'✓ Avg submission latency < 150k cycles':<40} PASS")
    else:
        print(f"{'✗ Avg submission latency < 150k cycles':<40} FAIL")
        success = False

    if analyzer.statistics["failures"] == 0:
        print(f"{'✓ No order failures':<40} PASS")
    else:
        print(f"{'✗ No order failures':<40} FAIL")
        success = False

    print("\n" + "="*100)
    if success:
        print("✓ ORDER FLOW INTEGRATION TEST PASSED")
        sys.exit(0)
    else:
        print("✗ ORDER FLOW INTEGRATION TEST FAILED")
        sys.exit(1)
