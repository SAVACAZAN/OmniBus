#!/usr/bin/env python3
"""
Orderbook data fetcher for Kraken, Coinbase, and LCX
Real-time bid/ask data for BTC/USD and BTC/USDC pairs
"""

import asyncio
import json
import logging
from typing import Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

class OrderbookFetcher:
    """Fetches orderbook data from multiple exchanges"""
    
    def __init__(self):
        self.kraken_url = "https://api.kraken.com"
        self.coinbase_url = "https://api.coinbase.com"
        self.lcx_url = "https://api.lcx.com"
        self.timeout = 5.0
    
    async def fetch_kraken_orderbook(self, pair: str) -> Optional[Dict]:
        """Fetch Kraken orderbook for BTC/USD or BTC/USDC"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                # Kraken: XBTUSDT (BTC/USD), XBTUSDC (BTC/USDC)
                kraken_pair = "XXBTZUSD" if "USD" in pair else "XXBTZUSDC"
                url = f"{self.kraken_url}/0/public/Depth?pair={kraken_pair}&count=20"
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()
                
                if data.get('result'):
                    pair_data = list(data['result'].values())[0]
                    return {
                        'exchange': 'kraken',
                        'pair': pair,
                        'bids': pair_data.get('bids', []),
                        'asks': pair_data.get('asks', []),
                        'timestamp': asyncio.get_event_loop().time()
                    }
        except Exception as e:
            logger.error(f"Kraken orderbook fetch failed: {e}")
        return None
    
    async def fetch_coinbase_orderbook(self, pair: str) -> Optional[Dict]:
        """Fetch Coinbase orderbook for BTC/USD or BTC/USDC"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                # Coinbase: BTC-USD, BTC-USDC
                cb_pair = "BTC-USD" if "USD" in pair else "BTC-USDC"
                url = f"{self.coinbase_url}/v2/exchange-rates?currency={cb_pair.split('-')[0]}"
                
                # Use public endpoint for orderbook
                url = f"https://api.exchange.coinbase.com/products/{cb_pair}/book?level=2"
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()
                
                return {
                    'exchange': 'coinbase',
                    'pair': pair,
                    'bids': [[float(p), float(s)] for p, s, _ in data.get('bids', [])[:20]],
                    'asks': [[float(p), float(s)] for p, s, _ in data.get('asks', [])[:20]],
                    'timestamp': asyncio.get_event_loop().time()
                }
        except Exception as e:
            logger.error(f"Coinbase orderbook fetch failed: {e}")
        return None
    
    async def fetch_lcx_orderbook(self, pair: str) -> Optional[Dict]:
        """Fetch LCX orderbook for BTC/USD or BTC/USDC"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                # LCX: BTC/USD, BTC/USDC
                url = f"{self.lcx_url}/api/v1/orderbook/{pair.replace('/', '_')}"
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()
                
                return {
                    'exchange': 'lcx',
                    'pair': pair,
                    'bids': data.get('bids', [])[:20],
                    'asks': data.get('asks', [])[:20],
                    'timestamp': asyncio.get_event_loop().time()
                }
        except Exception as e:
            logger.error(f"LCX orderbook fetch failed: {e}")
        return None
    
    async def fetch_all_orderbooks(self, pair: str) -> Dict[str, Optional[Dict]]:
        """Fetch orderbooks from all exchanges simultaneously"""
        results = await asyncio.gather(
            self.fetch_kraken_orderbook(pair),
            self.fetch_coinbase_orderbook(pair),
            self.fetch_lcx_orderbook(pair),
            return_exceptions=False
        )
        
        return {
            'kraken': results[0],
            'coinbase': results[1],
            'lcx': results[2],
            'pair': pair
        }
    
    def format_orderbook_display(self, orderbook_data: Dict) -> Dict:
        """Format orderbook for frontend display"""
        formatted = {'pair': orderbook_data.get('pair')}

        for exchange in ['kraken', 'coinbase', 'lcx']:
            data = orderbook_data.get(exchange)
            if data:
                try:
                    # Format bids and asks with price and size
                    bids = []
                    asks = []

                    # Process bids safely
                    bid_list = data.get('bids', [])
                    if bid_list and len(bid_list) > 0:
                        for bid_entry in bid_list[:10]:
                            try:
                                if isinstance(bid_entry, (list, tuple)) and len(bid_entry) >= 2:
                                    price, size = float(bid_entry[0]), float(bid_entry[1])
                                    bids.append({
                                        'price': price,
                                        'size': size,
                                        'total': price * size
                                    })
                            except (ValueError, TypeError, IndexError):
                                continue

                    # Process asks safely
                    ask_list = data.get('asks', [])
                    if ask_list and len(ask_list) > 0:
                        for ask_entry in ask_list[:10]:
                            try:
                                if isinstance(ask_entry, (list, tuple)) and len(ask_entry) >= 2:
                                    price, size = float(ask_entry[0]), float(ask_entry[1])
                                    asks.append({
                                        'price': price,
                                        'size': size,
                                        'total': price * size
                                    })
                            except (ValueError, TypeError, IndexError):
                                continue

                    formatted[exchange] = {
                        'bids': bids,
                        'asks': asks,
                        'spread': None
                    }

                    if bids and asks:
                        best_bid = bids[0]['price']
                        best_ask = asks[0]['price']
                        if best_bid > 0:
                            spread = ((best_ask - best_bid) / best_bid) * 10000  # in bps
                            formatted[exchange]['spread'] = round(spread, 2)
                except Exception as e:
                    logger.error(f"Error formatting {exchange} orderbook: {e}")
                    formatted[exchange] = {'bids': [], 'asks': [], 'spread': None}
            else:
                formatted[exchange] = {'bids': [], 'asks': [], 'spread': None}

        return formatted
