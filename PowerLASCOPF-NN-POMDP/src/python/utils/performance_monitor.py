"""
Performance monitoring for comparing TensorFlow vs PyTorch
"""

import time
import psutil
import numpy as np
from typing import Dict, List, Any, Optional
import logging
from contextlib import contextmanager

logger = logging.getLogger(__name__)

class PerformanceMonitor:
    """Monitor computational performance of different frameworks"""
    
    def __init__(self):
        self.metrics = {
            "tensorflow": {"times": [], "memory": [], "losses": []},
            "pytorch": {"times": [], "memory": [], "losses": []}
        }
        
    @contextmanager
    def monitor_framework(self, framework: str):
        """Context manager for monitoring framework performance"""
        start_time = time.time()
        start_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        
        try:
            yield
        finally:
            end_time = time.time()
            end_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
            
            execution_time = end_time - start_time
            memory_usage = end_memory - start_memory
            
            self.metrics[framework]["times"].append(execution_time)
            self.metrics[framework]["memory"].append(memory_usage)
            
    def record_loss(self, framework: str, loss: float):
        """Record training loss for framework"""
        self.metrics[framework]["losses"].append(loss)
        
    def get_performance_comparison(self) -> Dict[str, Any]:
        """Get comprehensive performance comparison"""
        comparison = {}
        
        for framework in ["tensorflow", "pytorch"]:
            if self.metrics[framework]["times"]:
                comparison[framework] = {
                    "avg_time": np.mean(self.metrics[framework]["times"]),
                    "std_time": np.std(self.metrics[framework]["times"]),
                    "avg_memory": np.mean(self.metrics[framework]["memory"]),
                    "std_memory": np.std(self.metrics[framework]["memory"]),
                    "avg_loss": np.mean(self.metrics[framework]["losses"][-100:]) if self.metrics[framework]["losses"] else 0.0,
                    "total_updates": len(self.metrics[framework]["times"])
                }
            else:
                comparison[framework] = {"message": "No data recorded"}
                
        # Add comparison metrics
        if "tensorflow" in comparison and "pytorch" in comparison:
            tf_time = comparison["tensorflow"].get("avg_time", 0)
            torch_time = comparison["pytorch"].get("avg_time", 0)
            
            if tf_time > 0 and torch_time > 0:
                comparison["speed_ratio"] = tf_time / torch_time
                comparison["faster_framework"] = "pytorch" if torch_time < tf_time else "tensorflow"
                
        return comparison
        
    def reset_metrics(self):
        """Reset all recorded metrics"""
        for framework in self.metrics:
            self.metrics[framework] = {"times": [], "memory": [], "losses": []}

# Global performance monitor instance
performance_monitor = PerformanceMonitor()