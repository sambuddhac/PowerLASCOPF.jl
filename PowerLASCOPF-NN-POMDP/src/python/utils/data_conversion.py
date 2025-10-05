"""
Data conversion utilities between Julia and Python frameworks
"""

import numpy as np
import tensorflow as tf
import torch
from typing import Union, List, Any

def julia_to_numpy(julia_array: Any) -> np.ndarray:
    """Convert Julia array to NumPy array"""
    if hasattr(julia_array, '__array__'):
        return np.array(julia_array)
    elif isinstance(julia_array, (list, tuple)):
        return np.array(julia_array)
    else:
        # Assume it's already a numpy array or convertible
        return np.asarray(julia_array)

def julia_to_tf_tensor(julia_array: Any) -> tf.Tensor:
    """Convert Julia array to TensorFlow tensor"""
    numpy_array = julia_to_numpy(julia_array)
    return tf.convert_to_tensor(numpy_array, dtype=tf.float32)

def julia_to_torch_tensor(julia_array: Any, device: str = "cpu") -> torch.Tensor:
    """Convert Julia array to PyTorch tensor"""
    numpy_array = julia_to_numpy(julia_array)
    return torch.tensor(numpy_array, dtype=torch.float32, device=device)

def tf_tensor_to_julia(tensor: tf.Tensor) -> List[float]:
    """Convert TensorFlow tensor to Julia-compatible list"""
    return tensor.numpy().flatten().tolist()

def torch_tensor_to_julia(tensor: torch.Tensor) -> List[float]:
    """Convert PyTorch tensor to Julia-compatible list"""
    return tensor.detach().cpu().numpy().flatten().tolist()

def numpy_to_julia(array: np.ndarray) -> List[float]:
    """Convert NumPy array to Julia-compatible list"""
    return array.flatten().tolist()

# Batch conversion functions
def convert_batch_to_framework(states: Any, actions: Any, rewards: Any, 
                              next_states: Any, dones: Any, 
                              framework: str = "tensorflow"):
    """Convert batch of data to specified framework"""
    
    # Convert to numpy first
    states_np = julia_to_numpy(states)
    actions_np = julia_to_numpy(actions)
    rewards_np = julia_to_numpy(rewards)
    next_states_np = julia_to_numpy(next_states)
    dones_np = julia_to_numpy(dones)
    
    if framework.lower() == "tensorflow":
        return (
            tf.convert_to_tensor(states_np, dtype=tf.float32),
            tf.convert_to_tensor(actions_np, dtype=tf.float32),
            tf.convert_to_tensor(rewards_np, dtype=tf.float32),
            tf.convert_to_tensor(next_states_np, dtype=tf.float32),
            tf.convert_to_tensor(dones_np, dtype=tf.float32)
        )
    elif framework.lower() == "pytorch":
        device = "cuda" if torch.cuda.is_available() else "cpu"
        return (
            torch.tensor(states_np, dtype=torch.float32, device=device),
            torch.tensor(actions_np, dtype=torch.float32, device=device),
            torch.tensor(rewards_np, dtype=torch.float32, device=device),
            torch.tensor(next_states_np, dtype=torch.float32, device=device),
            torch.tensor(dones_np, dtype=torch.float32, device=device)
        )
    else:
        return states_np, actions_np, rewards_np, next_states_np, dones_np