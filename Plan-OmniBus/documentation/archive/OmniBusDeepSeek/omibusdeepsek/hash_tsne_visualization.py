#!/usr/bin/env python3
# hash_tsne_visualization.py

import numpy as np
import matplotlib.pyplot as plt
from sklearn.manifold import TSNE

class TSNEVisualizer:
    def __init__(self, hash_dict):
        self.hashes = hash_dict
        self.names = list(hash_dict.keys())
        self.vectors = self._to_vectors()
    
    def _to_vectors(self):
        """Convert hashes to vectors"""
        vectors = []
        for name, hash_str in self.hashes.items():
            vec = [int(hash_str[i:i+2], 16) for i in range(0, len(hash_str), 2)]
            vectors.append(vec)
        return np.array(vectors)
    
    def visualize(self):
        """Perform t-SNE and visualize"""
        # Apply t-SNE
        tsne = TSNE(n_components=2, random_state=42, perplexity=2)
        embedded = tsne.fit_transform(self.vectors)
        
        # Plot
        plt.figure(figsize=(10, 8))
        
        colors = ['blue', 'green', 'red', 'purple']
        for i, (x, y) in enumerate(embedded):
            plt.scatter(x, y, c=colors[i], s=200, label=self.names[i], alpha=0.7)
            plt.annotate(self.names[i], (x, y), xytext=(5, 5), textcoords='offset points')
        
        plt.title('t-SNE Visualization of Agent Hashes')
        plt.xlabel('t-SNE Component 1')
        plt.ylabel('t-SNE Component 2')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.savefig("agent_hashes/shared/tsne_visualization.png")
        plt.show()
        
        print("✅ t-SNE visualization saved")

# Load hashes
hashes = {}
agents = ["chatgpt", "claude", "deepseek", "gemini"]

for agent in agents:
    with open(f"agent_hashes/{agent}/identity.cfg", "r") as f:
        hash_val = f.readline().strip().split("=")[1]
        hashes[agent] = hash_val

# Create t-SNE visualization
tsne_viz = TSNEVisualizer(hashes)
tsne_viz.visualize()