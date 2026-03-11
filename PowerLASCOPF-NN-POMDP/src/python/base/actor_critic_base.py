"""
Base classes for Actor-Critic networks
Provides common interface for TensorFlow and PyTorch implementations
"""

from abc import ABC, abstractmethod
import numpy as np
from typing import Tuple, Dict, Any, Optional, Union
import logging

logger = logging.getLogger(__name__)

class ActorCriticBase(ABC):
    """Base class for Actor-Critic implementations"""
    
    def __init__(self, state_dim: int, action_dim: int, learning_rate: float = 3e-4):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.learning_rate = learning_rate
        self.training_step = 0
        
    @abstractmethod
    def create_actor_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> Any:
        """Create actor network"""
        pass
    
    @abstractmethod
    def create_critic_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> Any:
        """Create critic network"""
        pass
    
    @abstractmethod
    def get_action(self, state: np.ndarray, deterministic: bool = False) -> np.ndarray:
        """Get action from actor network"""
        pass
    
    @abstractmethod
    def get_value(self, state: np.ndarray) -> float:
        """Get state value from critic network"""
        pass
    
    @abstractmethod
    def update(self, states: np.ndarray, actions: np.ndarray, 
               rewards: np.ndarray, next_states: np.ndarray, 
               dones: np.ndarray) -> Dict[str, float]:
        """Update actor and critic networks"""
        pass
    
    @abstractmethod
    def save_models(self, filepath: str) -> None:
        """Save trained models"""
        pass
    
    @abstractmethod
    def load_models(self, filepath: str) -> None:
        """Load trained models"""
        pass

class PolicyBase(ABC):
    """Base class for policy implementations"""
    
    def __init__(self, actor_critic: ActorCriticBase):
        self.actor_critic = actor_critic
        self.episode_rewards = []
        self.episode_steps = []
        
    @abstractmethod
    def select_action(self, state: np.ndarray, 
                     exploration_mode: str = "stochastic") -> np.ndarray:
        """Select action using policy"""
        pass
    
    def add_episode_data(self, reward: float, steps: int) -> None:
        """Add episode performance data"""
        self.episode_rewards.append(reward)
        self.episode_steps.append(steps)
        
    def get_performance_stats(self) -> Dict[str, float]:
        """Get performance statistics"""
        if not self.episode_rewards:
            return {}
            
        return {
            "mean_reward": np.mean(self.episode_rewards[-100:]),  # Last 100 episodes
            "std_reward": np.std(self.episode_rewards[-100:]),
            "mean_steps": np.mean(self.episode_steps[-100:]),
            "total_episodes": len(self.episode_rewards)
        }