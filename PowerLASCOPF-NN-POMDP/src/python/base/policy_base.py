"""
Advanced policy base with LASCOPF-specific functionality
"""

import numpy as np
from typing import Dict, List, Optional, Tuple
from .actor_critic_base import PolicyBase, ActorCriticBase

class LASCOPFPolicyBase(PolicyBase):
    """LASCOPF-specific policy base class"""
    
    def __init__(self, actor_critic: ActorCriticBase, 
                 power_system_params: Dict[str, Any]):
        super().__init__(actor_critic)
        self.power_system_params = power_system_params
        self.action_constraints = self._setup_action_constraints()
        self.state_normalizer = self._setup_state_normalizer()
        
    def _setup_action_constraints(self) -> Dict[str, Tuple[float, float]]:
        """Setup action constraints based on power system parameters"""
        constraints = {}
        
        # Generator power limits
        gen_count = self.power_system_params.get("generator_count", 10)
        for i in range(gen_count):
            gen_params = self.power_system_params.get(f"gen_{i}", {})
            p_min = gen_params.get("p_min", 0.0)
            p_max = gen_params.get("p_max", 100.0)
            constraints[f"gen_{i}_power"] = (p_min, p_max)
            
        # ADMM penalty parameters
        constraints["rho"] = (0.1, 10.0)
        constraints["beta"] = (0.1, 5.0)
        
        return constraints
        
    def _setup_state_normalizer(self) -> Dict[str, Tuple[float, float]]:
        """Setup state normalization parameters"""
        normalizer = {}
        
        # Voltage magnitude normalization (typically 0.9 - 1.1 pu)
        normalizer["voltage"] = (0.9, 1.1)
        
        # Power flow normalization (based on line ratings)
        normalizer["power_flow"] = (0.0, 1.0)  # Per unit
        
        # Generator output normalization
        normalizer["generation"] = (0.0, 1.0)  # Per unit
        
        return normalizer
        
    def normalize_state(self, state: np.ndarray) -> np.ndarray:
        """Normalize state vector for better neural network training"""
        normalized_state = state.copy()
        
        # Apply normalization based on state components
        # This would be customized based on your specific state representation
        
        return normalized_state
        
    def constrain_action(self, action: np.ndarray) -> np.ndarray:
        """Apply physical constraints to actions"""
        constrained_action = action.copy()
        
        # Apply generator limits, ADMM parameter bounds, etc.
        # This would be customized based on your action space
        
        return constrained_action
        
    def compute_reward(self, state: np.ndarray, action: np.ndarray, 
                      next_state: np.ndarray, done: bool,
                      system_info: Dict[str, Any]) -> float:
        """Compute reward for LASCOPF optimization"""
        reward = 0.0
        
        # Economic cost component (negative of generation cost)
        generation_cost = system_info.get("generation_cost", 0.0)
        reward -= generation_cost
        
        # Security constraint violation penalty
        constraint_violations = system_info.get("constraint_violations", 0.0)
        reward -= 1000.0 * constraint_violations  # Heavy penalty
        
        # Convergence bonus
        if system_info.get("converged", False):
            reward += 100.0
            
        # Stability bonus (voltage and frequency within limits)
        stability_score = system_info.get("stability_score", 0.0)
        reward += 10.0 * stability_score
        
        return reward