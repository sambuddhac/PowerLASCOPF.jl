"""
TensorFlow implementation of Actor-Critic networks for LASCOPF
"""

import tensorflow as tf
import numpy as np
from typing import Tuple, Dict, Any, Optional
import logging

from ..base.actor_critic_base import ActorCriticBase

logger = logging.getLogger(__name__)

class TFActorCritic(ActorCriticBase):
    """TensorFlow Actor-Critic implementation"""
    
    def __init__(self, state_dim: int, action_dim: int, learning_rate: float = 3e-4):
        super().__init__(state_dim, action_dim, learning_rate)
        
        # Build networks
        self.actor = self.create_actor_model()
        self.critic = self.create_critic_model()
        
        # Optimizers
        self.actor_optimizer = tf.keras.optimizers.Adam(learning_rate)
        self.critic_optimizer = tf.keras.optimizers.Adam(learning_rate)
        
        # Loss tracking
        self.actor_loss_metric = tf.keras.metrics.Mean()
        self.critic_loss_metric = tf.keras.metrics.Mean()
        
    def create_actor_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> tf.keras.Model:
        """Create actor network with TensorFlow"""
        inputs = tf.keras.layers.Input(shape=(self.state_dim,))
        
        x = inputs
        for hidden_dim in hidden_dims:
            x = tf.keras.layers.Dense(hidden_dim, activation='relu')(x)
            x = tf.keras.layers.BatchNormalization()(x)
            x = tf.keras.layers.Dropout(0.1)(x)
            
        # Output layer - actions (continuous)
        actions = tf.keras.layers.Dense(self.action_dim, activation='tanh')(x)
        
        # For LASCOPF, we might want to scale actions to appropriate ranges
        # This can be done with custom scaling layers
        
        model = tf.keras.Model(inputs=inputs, outputs=actions, name="Actor")
        return model
        
    def create_critic_model(self, hidden_dims: Tuple[int, ...] = (256, 256)) -> tf.keras.Model:
        """Create critic network with TensorFlow"""
        state_input = tf.keras.layers.Input(shape=(self.state_dim,))
        action_input = tf.keras.layers.Input(shape=(self.action_dim,))
        
        # Concatenate state and action
        concat = tf.keras.layers.Concatenate()([state_input, action_input])
        
        x = concat
        for hidden_dim in hidden_dims:
            x = tf.keras.layers.Dense(hidden_dim, activation='relu')(x)
            x = tf.keras.layers.BatchNormalization()(x)
            x = tf.keras.layers.Dropout(0.1)(x)
            
        # Output layer - single value
        value = tf.keras.layers.Dense(1)(x)
        
        model = tf.keras.Model(inputs=[state_input, action_input], 
                              outputs=value, name="Critic")
        return model
        
    @tf.function
    def get_action(self, state: tf.Tensor, deterministic: bool = False) -> tf.Tensor:
        """Get action from actor network"""
        action = self.actor(state)
        
        if not deterministic:
            # Add exploration noise
            noise = tf.random.normal(tf.shape(action), stddev=0.1)
            action = tf.clip_by_value(action + noise, -1.0, 1.0)
            
        return action
        
    def get_value(self, state: np.ndarray, action: np.ndarray) -> float:
        """Get state-action value from critic network"""
        state_tensor = tf.convert_to_tensor(state.reshape(1, -1), dtype=tf.float32)
        action_tensor = tf.convert_to_tensor(action.reshape(1, -1), dtype=tf.float32)
        
        value = self.critic([state_tensor, action_tensor])
        return float(value.numpy()[0, 0])
        
    @tf.function
    def _train_step(self, states: tf.Tensor, actions: tf.Tensor, 
                   rewards: tf.Tensor, next_states: tf.Tensor, 
                   dones: tf.Tensor, gamma: float = 0.99) -> Tuple[tf.Tensor, tf.Tensor]:
        """Single training step"""
        
        with tf.GradientTape() as critic_tape, tf.GradientTape() as actor_tape:
            # Critic loss (TD error)
            current_q = self.critic([states, actions])
            next_actions = self.actor(next_states)
            next_q = self.critic([next_states, next_actions])
            target_q = rewards + gamma * next_q * (1 - dones)
            
            critic_loss = tf.keras.losses.MSE(target_q, current_q)
            
            # Actor loss (policy gradient)
            predicted_actions = self.actor(states)
            predicted_q = self.critic([states, predicted_actions])
            actor_loss = -tf.reduce_mean(predicted_q)
            
        # Update critic
        critic_grads = critic_tape.gradient(critic_loss, self.critic.trainable_variables)
        self.critic_optimizer.apply_gradients(zip(critic_grads, self.critic.trainable_variables))
        
        # Update actor
        actor_grads = actor_tape.gradient(actor_loss, self.actor.trainable_variables)
        self.actor_optimizer.apply_gradients(zip(actor_grads, self.actor.trainable_variables))
        
        return actor_loss, critic_loss
        
    def update(self, states: np.ndarray, actions: np.ndarray,
               rewards: np.ndarray, next_states: np.ndarray,
               dones: np.ndarray) -> Dict[str, float]:
        """Update networks with batch of experiences"""
        
        # Convert to tensors
        states_tensor = tf.convert_to_tensor(states, dtype=tf.float32)
        actions_tensor = tf.convert_to_tensor(actions, dtype=tf.float32)
        rewards_tensor = tf.convert_to_tensor(rewards.reshape(-1, 1), dtype=tf.float32)
        next_states_tensor = tf.convert_to_tensor(next_states, dtype=tf.float32)
        dones_tensor = tf.convert_to_tensor(dones.reshape(-1, 1), dtype=tf.float32)
        
        actor_loss, critic_loss = self._train_step(
            states_tensor, actions_tensor, rewards_tensor, 
            next_states_tensor, dones_tensor
        )
        
        # Update metrics
        self.actor_loss_metric.update_state(actor_loss)
        self.critic_loss_metric.update_state(critic_loss)
        self.training_step += 1
        
        return {
            "actor_loss": float(actor_loss),
            "critic_loss": float(critic_loss),
            "training_step": self.training_step
        }
        
    def save_models(self, filepath: str) -> None:
        """Save trained models"""
        self.actor.save(f"{filepath}_actor.h5")
        self.critic.save(f"{filepath}_critic.h5")
        logger.info(f"Models saved to {filepath}")
        
    def load_models(self, filepath: str) -> None:
        """Load trained models"""
        self.actor = tf.keras.models.load_model(f"{filepath}_actor.h5")
        self.critic = tf.keras.models.load_model(f"{filepath}_critic.h5")
        logger.info(f"Models loaded from {filepath}")

# Factory functions for Julia interface
def create_actor_model(state_dim: int, action_dim: int, **kwargs) -> tf.keras.Model:
    """Factory function to create actor model"""
    ac = TFActorCritic(state_dim, action_dim)
    return ac.actor

def create_critic_model(state_dim: int, **kwargs) -> tf.keras.Model:
    """Factory function to create critic model"""
    ac = TFActorCritic(state_dim, 1)  # Action dim doesn't matter for this factory
    return ac.critic