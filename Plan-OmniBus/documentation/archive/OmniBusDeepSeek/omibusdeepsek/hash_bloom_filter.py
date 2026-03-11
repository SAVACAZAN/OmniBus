#!/usr/bin/env python3
# hash_bloom_filter.py

import hashlib
import math

class BloomFilter:
    def __init__(self, size=1000, hash_count=3):
        self.size = size
        self.hash_count = hash_count
        self.bit_array = [0] * size
    
    def _hashes(self, item):
        """Generate multiple hash values"""
        result = []
        for i in range(self.hash_count):
            hash_val = hashlib.sha256(f"{item}{i}".encode()).hexdigest()
            result.append(int(hash_val, 16) % self.size)
        return result
    
    def add(self, item):
        """Add item to bloom filter"""
        for pos in self._hashes(item):
            self.bit_array[pos] = 1
    
    def check(self, item):
        """Check if item might be in filter"""
        for pos in self._hashes(item):
            if self.bit_array[pos] == 0:
                return False
        return True

# Create bloom filter for all hashes
bloom = BloomFilter(size=1000, hash_count=5)

# Add all hashes
agents = ["chatgpt", "claude", "deepseek", "gemini"]
print("🌸 Bloom Filter pentru hash-uri")

for agent in agents:
    with open(f"agent_hashes/{agent}/identity.cfg", "r") as f:
        for line in f:
            if "=" in line:
                _, hash_val = line.strip().split("=")
                bloom.add(hash_val)
                print(f"  ✅ Adăugat hash de la {agent}")

# Test membership
test_hash = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
print(f"\n🔍 Test hash: {test_hash[:16]}...")
print(f"  Posibil în set: {bloom.check(test_hash)}")

# Test with known hash
known_hash = "4f4d4e494255535f43524541544f525f30315f5b5051435f5349473a5f65336230633434323938666331633134396166626634633839393666623932345d"
print(f"\n🔍 Test hash cunoscut: {known_hash[:16]}...")
print(f"  Posibil în set: {bloom.check(known_hash)}")

# Save bloom filter
with open("agent_hashes/shared/bloom_filter.txt", "w") as f:
    f.write(','.join(map(str, bloom.bit_array)))