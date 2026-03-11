#!/usr/bin/env python3
"""
ens_feeder.py — Ethereum Name Service (ENS) domain resolver feeder
Phase 51: Feeds resolved ENS names into OmniBus domain cache

Resolves .eth domains via Infura/Alchemy and writes results to kernel
memory shared buffer at 0x4E0080 (Domain Resolver cache @ 0x4E0000).

Usage:
    python3 ens_feeder.py [--rpc-url https://eth-mainnet.g.alchemy.com/v2/KEY]

Requirements:
    pip install web3==6.0.0
"""

import struct
import time
import sys
import os
from typing import Tuple, Optional
from web3 import Web3

# Constants
DOMAIN_RESOLVER_BASE = 0x4E0000
CACHE_ENTRIES_OFFSET = 0x80  # After 128B header
CACHE_ENTRY_SIZE = 64  # Bytes per entry

# Domain type codes
TYPE_ENS = 1
TYPE_ANYONE = 2
TYPE_ARNS = 3

# Chain ID codes
CHAIN_ETHEREUM = 1
CHAIN_SOLANA = 2
CHAIN_ARWEAVE = 3

# Cache status codes
STATUS_EMPTY = 0
STATUS_CACHED = 1
STATUS_PENDING = 2
STATUS_FAILED = 3

# Default RPC endpoints (Infura/Alchemy free tier)
DEFAULT_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/demo"

class ENSFeeder:
    """Feeds ENS domain resolutions into OmniBus kernel cache."""

    def __init__(self, rpc_url: str = DEFAULT_RPC_URL):
        """Initialize with Web3 provider."""
        self.web3 = Web3(Web3.HTTPProvider(rpc_url))
        if not self.web3.is_connected():
            print(f"ERROR: Cannot connect to {rpc_url}")
            sys.exit(1)

        print(f"Connected to Ethereum RPC: {rpc_url}")
        print(f"Chain ID: {self.web3.eth.chain_id}")

        # Open /dev/mem for kernel memory access
        try:
            self.mem_fd = open("/dev/mem", "r+b")
        except PermissionError:
            print("ERROR: Need root access to read/write /dev/mem")
            print("Run with: sudo python3 ens_feeder.py")
            sys.exit(1)

    def resolve_ens_name(self, domain_name: str) -> Optional[str]:
        """Resolve .eth domain to Ethereum address via ENS.

        Args:
            domain_name: e.g., "vitalik.eth"

        Returns:
            Ethereum address (0x...) or None if not found
        """
        try:
            # Normalize domain (lowercase)
            domain_name = domain_name.lower()

            # Ensure .eth suffix
            if not domain_name.endswith('.eth'):
                domain_name += '.eth'

            # Resolve via Web3.py ENS wrapper
            address = self.web3.ens.address(domain_name)

            if address:
                return address
            else:
                print(f"  {domain_name}: NOT FOUND")
                return None

        except Exception as e:
            print(f"  {domain_name}: ERROR - {e}")
            return None

    def compute_ens_name_hash(self, domain_name: str) -> int:
        """Compute ENS name hash (deterministic for caching).

        Uses FNV-1a hash for compatibility with Zig implementation.
        """
        # Normalize
        domain_name = domain_name.lower()
        if not domain_name.endswith('.eth'):
            domain_name += '.eth'

        # FNV-1a hash
        hash_val = 0xcbf29ce484222325  # FNV offset basis

        for byte in domain_name.encode('utf-8'):
            hash_val ^= byte
            hash_val = (hash_val * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF

        return hash_val

    def add_to_cache(self, domain_name: str, address: str, ttl: int = 3600):
        """Add resolved domain to kernel cache.

        Args:
            domain_name: e.g., "vitalik.eth"
            address: Ethereum address (0x...)
            ttl: Time-to-live in seconds
        """
        try:
            # Compute hash
            domain_hash = self.compute_ens_name_hash(domain_name)

            # Parse address (remove 0x prefix, convert to bytes)
            if address.startswith('0x'):
                address = address[2:]

            if len(address) != 40:  # 20 bytes = 40 hex chars
                print(f"  Invalid address length: {address}")
                return False

            address_bytes = bytes.fromhex(address)
            # Pad to 32 bytes (Ethereum uses 20 bytes, padded to 32)
            address_bytes = address_bytes + (b'\x00' * 12)

            # Find free cache entry
            for entry_idx in range(256):
                offset = DOMAIN_RESOLVER_BASE + CACHE_ENTRIES_OFFSET + (entry_idx * CACHE_ENTRY_SIZE)

                # Read current entry status
                self.mem_fd.seek(offset + 10)  # status byte at offset 10
                status_bytes = self.mem_fd.read(1)

                if not status_bytes or status_bytes[0] == STATUS_EMPTY:
                    # Found free slot — write entry
                    entry_data = struct.pack(
                        '<QBBBxI32sQIBx',
                        domain_hash,           # 0-7: domain_hash
                        CHAIN_ETHEREUM,        # 8: chain_id
                        TYPE_ENS,              # 9: domain_type
                        STATUS_CACHED,         # 10: status
                        0,                     # 14-17: padding (reserved)
                        address_bytes,         # 12-43: address [32]u8
                        int(time.time()),      # 44-51: resolving_since (UNIX timestamp)
                        ttl,                   # 52-55: ttl_seconds
                    )

                    self.mem_fd.seek(offset)
                    self.mem_fd.write(entry_data)
                    self.mem_fd.flush()

                    print(f"  ✓ Cached: {domain_name} → {address}")
                    return True

            print(f"  ✗ Cache full — cannot add {domain_name}")
            return False

        except Exception as e:
            print(f"  ERROR adding to cache: {e}")
            return False

    def update_statistics(self):
        """Update resolver statistics in kernel state."""
        try:
            # Read current state @ 0x4E0000
            self.mem_fd.seek(DOMAIN_RESOLVER_BASE)
            state_bytes = self.mem_fd.read(128)

            # For now: just log
            if len(state_bytes) >= 32:
                cache_hits = struct.unpack_from('<I', state_bytes, 16)[0]
                print(f"Cache hits: {cache_hits}")

        except Exception as e:
            print(f"Error reading statistics: {e}")

    def resolve_batch(self, domains: list[str]):
        """Resolve a batch of domains and cache results.

        Args:
            domains: List of domain names (e.g., ["vitalik.eth", "opensea.eth"])
        """
        print(f"\n=== Resolving {len(domains)} domains ===")

        resolved = 0
        for domain in domains:
            print(f"Resolving {domain}...")
            address = self.resolve_ens_name(domain)

            if address:
                self.add_to_cache(domain, address)
                resolved += 1

        print(f"\n=== Results: {resolved}/{len(domains)} resolved ===")
        self.update_statistics()

    def watch_mode(self, domains: list[str], interval: int = 10):
        """Continuously resolve and cache domains.

        Args:
            domains: List of domain names to watch
            interval: Seconds between resolution cycles
        """
        print(f"\n=== Watch Mode (interval: {interval}s) ===")
        print("Press Ctrl+C to stop")

        try:
            cycle = 0
            while True:
                cycle += 1
                print(f"\n[Cycle {cycle}] {time.strftime('%Y-%m-%d %H:%M:%S')}")
                self.resolve_batch(domains)
                time.sleep(interval)

        except KeyboardInterrupt:
            print("\nStopped")
            sys.exit(0)

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="ENS domain feeder for OmniBus Phase 51"
    )
    parser.add_argument(
        '--rpc-url',
        default=DEFAULT_RPC_URL,
        help='Ethereum RPC URL (default: Alchemy demo)'
    )
    parser.add_argument(
        '--domains',
        default='vitalik.eth,opensea.eth,lido.eth',
        help='Comma-separated list of domains to resolve'
    )
    parser.add_argument(
        '--watch',
        action='store_true',
        help='Enable watch mode (continuous resolution)'
    )
    parser.add_argument(
        '--interval',
        type=int,
        default=10,
        help='Watch mode interval in seconds'
    )

    args = parser.parse_args()

    # Parse domain list
    domains = [d.strip() for d in args.domains.split(',')]

    # Initialize feeder
    feeder = ENSFeeder(args.rpc_url)

    # Run
    if args.watch:
        feeder.watch_mode(domains, args.interval)
    else:
        feeder.resolve_batch(domains)

if __name__ == '__main__':
    main()
