#!/usr/bin/env python3
"""
Phase 48B: Multi-Exchange Arbitrage Integration Test
Tests arbitrage detection and execution across Kraken, Coinbase, LCX
Validates trading logic with real market data patterns
"""

import sys
from dataclasses import dataclass
from typing import List, Dict, Optional

# ============================================================================
# Market Data Structures
# ============================================================================

@dataclass
class ExchangePrice:
    """Market price on a single exchange"""
    exchange: str
    asset: str
    bid: float
    ask: float
    volume_available: float
    timestamp: int

@dataclass
class ArbitrageOpportunity:
    """Detected arbitrage opportunity"""
    pair: str
    buy_exchange: str
    sell_exchange: str
    buy_price: float
    sell_price: float
    spread_bps: float  # basis points
    volume: float
    estimated_profit: float
    detected_cycle: int
    execution_cycle: Optional[int] = None
    filled: bool = False

# ============================================================================
# Exchange Simulator
# ============================================================================

class ExchangeMarket:
    """Simulates market conditions on an exchange"""

    def __init__(self, exchange: str):
        self.exchange = exchange
        self.prices = {}
        self.volatility = 0.005  # 0.5% volatility
        self._init_prices()

    def _init_prices(self):
        """Initialize realistic prices for BTC, ETH, LCX"""
        if self.exchange == "Kraken":
            self.prices["BTC"] = {"bid": 71600, "ask": 71610, "volume": 10.5}
            self.prices["ETH"] = {"bid": 2070, "ask": 2071, "volume": 150.0}
            self.prices["LCX"] = {"bid": 0.0449, "ask": 0.0450, "volume": 50000.0}
        elif self.exchange == "Coinbase":
            self.prices["BTC"] = {"bid": 71605, "ask": 71620, "volume": 8.2}
            self.prices["ETH"] = {"bid": 2069, "ask": 2072, "volume": 140.0}
            self.prices["LCX"] = {"bid": 0.0448, "ask": 0.0451, "volume": 45000.0}
        elif self.exchange == "LCX":
            self.prices["BTC"] = {"bid": 71590, "ask": 71625, "volume": 5.0}
            self.prices["ETH"] = {"bid": 2068, "ask": 2073, "volume": 120.0}
            self.prices["LCX"] = {"bid": 0.0447, "ask": 0.0452, "volume": 60000.0}

    def get_price(self, asset: str, cycle: int) -> ExchangePrice:
        """Get current market price with volatility"""
        if asset not in self.prices:
            return None

        base = self.prices[asset]
        # Add volatility based on cycle (simulates market movement)
        volatility_factor = 1.0 + (((cycle * 17) % 100) / 1000.0 * self.volatility)

        bid = base["bid"] * volatility_factor
        ask = base["ask"] * volatility_factor

        return ExchangePrice(
            exchange=self.exchange,
            asset=asset,
            bid=bid,
            ask=ask,
            volume_available=base["volume"],
            timestamp=cycle,
        )

# ============================================================================
# Arbitrage Engine
# ============================================================================

class ArbitrageEngine:
    """Detects and tracks arbitrage opportunities"""

    MIN_SPREAD_BPS = 10  # 0.1% minimum spread to trade
    EXCHANGES = ["Kraken", "Coinbase", "LCX"]
    ASSETS = ["BTC", "ETH", "LCX"]

    def __init__(self):
        self.markets = {ex: ExchangeMarket(ex) for ex in self.EXCHANGES}
        self.opportunities = []
        self.executed_trades = []
        self.statistics = {
            "total_opportunities": 0,
            "profitable_opportunities": 0,
            "executed_trades": 0,
            "total_profit": 0.0,
            "max_spread": 0.0,
            "avg_spread": 0.0,
        }

    def detect_opportunities(self, cycle: int, assets: List[str] = None) -> List[ArbitrageOpportunity]:
        """Detect all available arbitrage opportunities"""
        assets = assets or self.ASSETS
        opportunities = []

        # For each asset, find best buy and sell prices across exchanges
        for asset in assets:
            prices = {}
            for exchange in self.EXCHANGES:
                price = self.markets[exchange].get_price(asset, cycle)
                if price:
                    prices[exchange] = price

            if len(prices) < 2:
                continue

            # Find best buy (lowest ask) and best sell (highest bid)
            best_buy = min(prices.values(), key=lambda p: p.ask)
            best_sell = max(prices.values(), key=lambda p: p.bid)

            # Calculate spread
            if best_buy.ask > 0 and best_sell.bid > 0:
                spread = ((best_sell.bid - best_buy.ask) / best_buy.ask) * 10000  # in basis points

                if spread >= self.MIN_SPREAD_BPS:
                    # Calculate volume available (limited by both sides)
                    volume = min(best_buy.volume_available, best_sell.volume_available)

                    # Estimate profit (simplified: ignore fees for now)
                    profit = (best_sell.bid - best_buy.ask) * volume

                    opp = ArbitrageOpportunity(
                        pair=asset,
                        buy_exchange=best_buy.exchange,
                        sell_exchange=best_sell.exchange,
                        buy_price=best_buy.ask,
                        sell_price=best_sell.bid,
                        spread_bps=spread,
                        volume=volume,
                        estimated_profit=profit,
                        detected_cycle=cycle,
                    )

                    opportunities.append(opp)
                    self.statistics["total_opportunities"] += 1
                    self.statistics["max_spread"] = max(self.statistics["max_spread"], spread)

                    if profit > 0:
                        self.statistics["profitable_opportunities"] += 1

        # Update average spread
        if self.statistics["total_opportunities"] > 0:
            total_spread = sum(o.spread_bps for o in opportunities)
            self.statistics["avg_spread"] = total_spread / len(opportunities)

        return opportunities

    def execute_opportunity(self, opp: ArbitrageOpportunity, execution_cycle: int):
        """Simulate execution of arbitrage opportunity"""
        opp.execution_cycle = execution_cycle
        opp.filled = True
        self.executed_trades.append(opp)
        self.statistics["executed_trades"] += 1
        self.statistics["total_profit"] += opp.estimated_profit

    def print_report(self):
        """Print arbitrage analysis report"""
        print("\n" + "="*120)
        print("Multi-Exchange Arbitrage Integration Test Report")
        print("="*120)

        print(f"\n{'Metric':<50} {'Value':<30}")
        print("-"*120)
        print(f"{'Total opportunities detected':<50} {self.statistics['total_opportunities']:<30}")
        print(f"{'Profitable opportunities':<50} {self.statistics['profitable_opportunities']:<30}")
        print(f"{'Executed trades':<50} {self.statistics['executed_trades']:<30}")
        print(f"{'Total estimated profit':<50} ${self.statistics['total_profit']:,.2f}{'<':<6}")
        print(f"{'Max spread detected':<50} {self.statistics['max_spread']:.2f} bps{'<':<20}")
        print(f"{'Average spread':<50} {self.statistics['avg_spread']:.2f} bps{'<':<20}")

        # Executed trades summary
        if self.executed_trades:
            print(f"\n{'Executed Trades (top 10)':<50}")
            print("-"*120)
            print(f"{'Asset':<10} {'Buy@':<15} {'Sell@':<15} {'Spread':<12} {'Profit':<20}")
            print("-"*120)

            for trade in sorted(self.executed_trades, key=lambda t: t.estimated_profit, reverse=True)[:10]:
                print(
                    f"{trade.pair:<10} "
                    f"{trade.buy_exchange:>6} {trade.buy_price:>6.4f}  "
                    f"{trade.sell_exchange:>6} {trade.sell_price:>6.4f}  "
                    f"{trade.spread_bps:>10.2f} bps  "
                    f"${trade.estimated_profit:>15,.2f}"
                )

        # Top opportunities detected
        if self.opportunities:
            print(f"\n{'Top Opportunities Detected (by spread)':<50}")
            print("-"*120)
            print(f"{'Asset':<10} {'Buy Exchange':<20} {'Sell Exchange':<20} {'Spread':<15}")
            print("-"*120)

            top_opps = sorted(self.opportunities, key=lambda o: o.spread_bps, reverse=True)[:10]
            for opp in top_opps:
                print(
                    f"{opp.pair:<10} {opp.buy_exchange:<20} {opp.sell_exchange:<20} {opp.spread_bps:>12.2f} bps"
                )

        # Validation
        print(f"\n{'Validation Status':<50}")
        print("-"*120)

        if self.statistics["total_opportunities"] >= 5:
            print(f"{'✓ Detected minimum 5 opportunities':<50} PASS")
        else:
            print(f"{'✗ Detected minimum 5 opportunities':<50} FAIL ({self.statistics['total_opportunities']})")

        if self.statistics["avg_spread"] >= self.MIN_SPREAD_BPS:
            print(f"{'✓ Average spread >= {:.1f} bps':<50} PASS ({self.statistics['avg_spread']:.2f} bps)")
        else:
            print(f"{'✗ Average spread >= {:.1f} bps':<50} FAIL")

        if self.statistics["max_spread"] > 0:
            print(f"{'✓ Multi-exchange price divergence detected':<50} PASS ({self.statistics['max_spread']:.2f} bps max)")
        else:
            print(f"{'✗ Multi-exchange price divergence detected':<50} FAIL")

        if self.statistics["executed_trades"] >= 3:
            print(f"{'✓ Executed minimum 3 trades':<50} PASS")
        else:
            print(f"{'✗ Executed minimum 3 trades':<50} FAIL")

        if self.statistics["total_profit"] > 0:
            print(f"{'✓ Profitable trades detected':<50} PASS (${self.statistics['total_profit']:,.2f})")
        else:
            print(f"{'✗ Profitable trades detected':<50} FAIL")

# ============================================================================
# Integration Test Scenario
# ============================================================================

def run_integration_test():
    """Run complete multi-exchange arbitrage integration test"""

    print("="*120)
    print("Phase 48B: Multi-Exchange Arbitrage Integration Test")
    print("="*120)

    engine = ArbitrageEngine()

    print("\nSimulating 200 cycles of arbitrage detection and execution...")
    print("-"*120)

    # Run simulation
    executed_count = 0
    for cycle in range(200):
        # Detect opportunities
        opportunities = engine.detect_opportunities(cycle)

        # Simulate execution decisions
        if opportunities:
            # Execute top 3 opportunities by profit
            for opp in sorted(opportunities, key=lambda o: o.estimated_profit, reverse=True)[:3]:
                engine.execute_opportunity(opp, cycle + 10)  # 10 cycle execution delay
                executed_count += 1

        engine.opportunities.extend(opportunities)

        # Print progress
        if cycle % 50 == 0:
            print(f"Cycle {cycle:>3}: Detected {len(opportunities)} opportunities, Executed {executed_count} trades so far")

    print("-"*120)

    # Print comprehensive report
    engine.print_report()

    return engine

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    # Run test
    engine = run_integration_test()

    # Determine success
    print("\n" + "="*120)

    success = True

    if engine.statistics["total_opportunities"] < 5:
        success = False
    if engine.statistics["avg_spread"] < engine.MIN_SPREAD_BPS:
        success = False
    if engine.statistics["executed_trades"] < 3:
        success = False

    if success:
        print("✓ MULTI-EXCHANGE ARBITRAGE INTEGRATION TEST PASSED")
        sys.exit(0)
    else:
        print("✗ MULTI-EXCHANGE ARBITRAGE INTEGRATION TEST FAILED")
        sys.exit(1)
