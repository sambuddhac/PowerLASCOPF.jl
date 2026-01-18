"""
PyTorch implementation of Actor-Critic networks for LASCOPF
"""

import torch
import torch.nn as nn
import torch.optim as optim
import torch.nn.functional as F
import numpy as np
from typing import Tuple, Dict, Any, Optional
import logging

from ..base.actor_critic_base import ActorCriticBase

logger = logging.getLogger(__name__)

class Actor(nn.Module):
    """Actor network in PyTorch"""
    
    def __init__(self, state_dim: int, action_dim: int, 
                 hidden_dims: Tuple[int, ...] = (256, 256)):
        super(Actor, self).__init__()
        
        self.layers = nn.ModuleList()
        
        # Input layer
        prev_dim = state_dim
        
        # Hidden layers
        for hidden_dim in hidden_dims:
            self.layers.append(nn.Linear(prev_dim, hidden_dim))
            self.layers.append(nn.BatchNorm1d(hidden_dim))
            self.layers.append(nn.ReLU())
            self.layers.append(nn.Dropout(0.1))
            prev_dim = hidden_dim
            
        # Output layer
        self.layers.append(nn.Linear(prev_dim, action_dim))
        self.layers.append(nn.Tanh())  # Actions in [-1, 1]
        
    def forward(self, state: torch.Tensor) -> torch.Tensor:
        x = state
        for layer in self.layers:
            if isinstance(layer, nn.BatchNorm1d) and x.size(0) == 1:
                # Skip batch norm for single samples
                continue
            x = layer(x)
        return x

class Critic(nn.Module):
    """Critic network in PyTorch"""
    
    def __init__(self, state_dim: int, action_dim: int,
                 hidden_dims: Tuple[int, ...] = (256, 256)):
        super(Critic, self).__init__()
        
        self.layers = nn.ModuleList()
        
        # Input layer (state + action)
        prev_dim = state_dim + action_dim
        
        # Hidden layers
        for hidden_dim in hidden_dims:
            self.layers.append(nn.Linear(prev_dim, hidden_dim))
            self.layers.append(nn.BatchNorm1d(hidden_dim))
            self.layers.append(nn.ReLU())
            self.layers.append(nn.Dropout(0.1))
            prev_dim = hidden_dim
            
        # Output layer
        self.layers.append(nn.Linear(prev_dim, 1))
        
    def forward(self, state: torch.Tensor, action: torch.Tensor) -> torch.Tensor:
        x = torch.cat([state, action], dim=1)
        for layer in self.layers:
            if isinstance(layer, nn.BatchNorm1d) and x.size(0) == 1:
                # Skip batch norm for single samples
                continue
            x = layer(x)
        return x

class TorchActorCritic(ActorCriticBase):
    """PyTorch Actor-Critic implementation"""
    
    def __init__(self, state_dim: int, action_dim: int, 
                 learning_rate: float = 3e-4, device: str = "cpu"):
        super().__init__(state_dim, action_dim, learning_rate)
        
        self.device = torch.device(device)
        
        # Build networks
        self.actor = self.create_actor_model().to(self.device)
        self.critic = self.create_critic_model().to(self.device)
        
        # Optimizers
        self.actor_optimizer = optim.Adam(self.actor.parameters(), lr=learning_rate)
        self.critic_optimizer = optim.Adam(self.critic.parameters(), lr=learning_rate)
        
        # Loss tracking
        self.actor_losses = []
        self.critic_losses = []
        
    def create_actor_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> nn.Module:
        """Create actor network with PyTorch"""
        return Actor(self.state_dim, self.action_dim, hidden_dims)
        
    def create_critic_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> nn.Module:
        """Create critic network with PyTorch"""
        return Critic(self.state_dim, self.action_dim, hidden_dims)
        
    def get_action(self, state: np.ndarray, deterministic: bool = False) -> np.ndarray:
        """Get action from actor network"""
        self.actor.eval()
        
        with torch.no_grad():
            state_tensor = torch.FloatTensor(state).unsqueeze(0).to(self.device)
            action = self.actor(state_tensor)
            
            if not deterministic:
                # Add exploration noise
                noise = torch.normal(0, 0.1, size=action.shape).to(self.device)
                action = torch.clamp(action + noise, -1.0, 1.0)
                
            return action.cpu().numpy().flatten()
            
    def get_value(self, state: np.ndarray, action: np.ndarray) -> float:
        """Get state-action value from critic network"""
        self.critic.eval()
        
        with torch.no_grad():
            state_tensor = torch.FloatTensor(state).unsqueeze(0).to(self.device)
            action_tensor = torch.FloatTensor(action).unsqueeze(0).to(self.device)
            value = self.critic(state_tensor, action_tensor)
            
            return float(value.cpu().numpy()[0, 0])
            
    def update(self, states: np.ndarray, actions: np.ndarray,
               rewards: np.ndarray, next_states: np.ndarray,
               dones: np.ndarray, gamma: float = 0.99) -> Dict[str, float]:
        """Update networks with batch of experiences"""
        
        # Convert to tensors
        states_tensor = torch.FloatTensor(states).to(self.device)
        actions_tensor = torch.FloatTensor(actions).to(self.device)
        rewards_tensor = torch.FloatTensor(rewards).unsqueeze(1).to(self.device)
        next_states_tensor = torch.FloatTensor(next_states).to(self.device)
        dones_tensor = torch.FloatTensor(dones).unsqueeze(1).to(self.device)
        
        # Update critic
        self.critic.train()
        current_q = self.critic(states_tensor, actions_tensor)
        
        with torch.no_grad():
            next_actions = self.actor(next_states_tensor)
            next_q = self.critic(next_states_tensor, next_actions)
            target_q = rewards_tensor + gamma * next_q * (1 - dones_tensor)
            
        critic_loss = F.mse_loss(current_q, target_q)
        
        self.critic_optimizer.zero_grad()
        critic_loss.backward()
        self.critic_optimizer.step()
        
        # Update actor
        self.actor.train()
        predicted_actions = self.actor(states_tensor)
        predicted_q = self.critic(states_tensor, predicted_actions)
        actor_loss = -predicted_q.mean()
        
        self.actor_optimizer.zero_grad()
        actor_loss.backward()
        self.actor_optimizer.step()
        
        # Update tracking
        self.actor_losses.append(float(actor_loss))
        self.critic_losses.append(float(critic_loss))
        self.training_step += 1
        
        return {
            "actor_loss": float(actor_loss),
            "critic_loss": float(critic_loss),
            "training_step": self.training_step
        }
        
    def save_models(self, filepath: str) -> None:
        """Save trained models"""
        torch.save(self.actor.state_dict(), f"{filepath}_actor.pth")
        torch.save(self.critic.state_dict(), f"{filepath}_critic.pth")
        logger.info(f"Models saved to {filepath}")
        
    def load_models(self, filepath: str) -> None:
        """Load trained models"""
        self.actor.load_state_dict(torch.load(f"{filepath}_actor.pth"))
        self.critic.load_state_dict(torch.load(f"{filepath}_critic.pth"))
        logger.info(f"Models loaded from {filepath}")

# Factory functions for Julia interface
def create_actor_model(state_dim: int, action_dim: int, device: str = "cpu", **kwargs) -> Actor:
    """Factory function to create actor model"""
    return Actor(state_dim, action_dim).to(device)

def create_critic_model(state_dim: int, action_dim: int = 1, device: str = "cpu", **kwargs) -> Critic:
    """Factory function to create critic model"""
    return Critic(state_dim, action_dim).to(device)