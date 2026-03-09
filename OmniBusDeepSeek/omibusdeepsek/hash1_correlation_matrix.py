#!/usr/bin/env python3
# hash_correlation_matrix.py

import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import pearsonr

class CorrelationMatrix:
    def __init__(self, hash_dict):
        self.hashes = hash_dict
        self.names = list(hash_dict.keys())
        self.vectors = self._to_vectors()
    
    def _to_vectors(self):
        """Convert hashes to vectors"""
        vectors = {}
        for name, hash_str in self.hashes.items():
            vec = [int(hash_str[i:i+2], 16) for i in range(0, len(hash_str), 2)]
            vectors[name] = vec
        return vectors
    
    def compute_correlation(self):
        """Compute correlation matrix"""
        n = len(self.names)
        corr_matrix = np.zeros((n, n))
        
        for i, name1 in enumerate(self.names):
            for j, name2 in enumerate(self.names):
                if i <= j:
                    corr, _ = pearsonr(self.vectors[name1], self.vectors[name2])
                    corr_matrix[i, j] = corr
                    corr_matrix[j, i] = corr
        
        return corr_matrix
    
    def plot_matrix(self):
        """Plot correlation matrix"""
        corr_matrix = self.compute_correlation()
        
        plt.figure(figsize=(10, 8))
        plt.imshow(corr_matrix, cmap='coolwarm', vmin=-1, vmax=1)
        plt.colorbar(label='Correlation')
        
        # Add labels
        plt.xticks(range(len(self.names)), self.names, rotation=45)
        plt.yticks(range(len(self.names)), self.names)
        
        # Add correlation values
        for i in range(len(self.names)):
            for j in range(len(self.names)):
                plt.text(j, i, f'{corr_matrix[i, j]:.2f}', 
                        ha='center', va='center', color='white')
        
        plt.title('Hash Correlation Matrix')
        plt.tight_layout()
        plt.savefig("agent_hashes/shared/correlation_matrix.png")
        plt.show()

# Load hashes
hashes = {}
agents = ["chatgpt", "claude", "deepseek", "gemini"]

for agent in agents:
    with open(f"agent_hashes/{agent}/identity.cfg", "r") as f:
        hash_val = f.readline().strip().split("=")[1]
        hashes[agent] = hash_val

# Create and plot correlation matrix
cm = CorrelationMatrix(hashes)
cm.plot_matrix()

print("✅ Correlation matrix saved")