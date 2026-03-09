#!/usr/bin/env python3
# hash_deduplication.py

import hashlib

class HashDeduplicator:
    def __init__(self):
        self.hash_store = {}
        self.references = {}
        self.deduplicated = {}
    
    def add_hash(self, name, hash_str):
        """Add hash with deduplication"""
        # Create fingerprint (first 16 chars)
        fingerprint = hash_str[:16]
        
        if fingerprint in self.hash_store:
            # Duplicate found
            original = self.hash_store[fingerprint]
            self.references[name] = original
            self.deduplicated[name] = {'ref': original, 'saved': True}
            return True
        else:
            # New hash
            self.hash_store[fingerprint] = hash_str
            self.references[name] = name
            self.deduplicated[name] = {'ref': name, 'saved': False}
            return False
    
    def get_stats(self):
        """Get deduplication statistics"""
        total_hashes = len(self.hash_store) + len(self.references)
        unique = len(self.hash_store)
        duplicates = len(self.references)
        savings = (duplicates * 64) / 1024  # KB savings (assuming 64 char hashes)
        
        return {
            'total': total_hashes,
            'unique': unique,
            'duplicates': duplicates,
            'savings_kb': savings
        }

# Load all hashes
dedup = HashDeduplicator()

agents = ["chatgpt", "claude", "deepseek", "gemini"]
for agent in agents:
    with open(f"agent_hashes/{agent}/identity.cfg", "r") as f:
        for line in f:
            if "=" in line:
                key, hash_val = line.strip().split("=")
                name = f"{agent}_{key}"
                dedup.add_hash(name, hash_val)

# Check for duplicates
print("🔍 Hash Deduplication Analysis")
stats = dedup.get_stats()

print(f"\n📊 Statistics:")
print(f"  Total hashes: {stats['total']}")
print(f"  Unique hashes: {stats['unique']}")
print(f"  Duplicates: {stats['duplicates']}")
print(f"  Storage savings: {stats['savings_kb']:.2f} KB")

# Save deduplicated map
with open("agent_hashes/shared/deduplication_map.json", "w") as f:
    import json
    json.dump(dedup.deduplicated, f, indent=2)