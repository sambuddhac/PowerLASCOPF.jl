"""
Python Bridge for Neural Network Integration
Handles communication between Julia and Python ML frameworks
"""

using PyCall

# Global Python modules
const tf = PyNULL()
const torch = PyNULL()
const power_lascopf_nn = PyNULL()

function __init__()
    # Import Python modules
    try
        copy!(tf, pyimport("tensorflow"))
        copy!(torch, pyimport("torch"))
        copy!(power_lascopf_nn, pyimport("power_lascopf_nn"))
        @info "Successfully imported Python ML frameworks"
    catch e
        @warn "Failed to import Python frameworks: $e"
    end
end

"""
Initialize TensorFlow policy
"""
function _initialize_tensorflow_policy!(policy::ActorCriticPolicy)
    try
        # Create TensorFlow models
        py_tf_module = power_lascopf_nn.tensorflow.tf_actor_critic
        
        policy.actor_model = py_tf_module.create_actor_model(
            policy.state_dim, 
            policy.action_dim
        )
        
        policy.critic_model = py_tf_module.create_critic_model(
            policy.state_dim
        )
        
        # Initialize TensorFlow session if needed
        if policy.backend.session == PyNULL()
            policy.backend.session = tf.compat.v1.Session()
        end
        
        @info "TensorFlow actor-critic policy initialized"
        
    catch e
        error("Failed to initialize TensorFlow policy: $e")
    end
end

"""
Initialize PyTorch policy
"""
function _initialize_pytorch_policy!(policy::ActorCriticPolicy)
    try
        # Create PyTorch models
        py_torch_module = power_lascopf_nn.pytorch.torch_actor_critic
        
        policy.actor_model = py_torch_module.create_actor_model(
            policy.state_dim,
            policy.action_dim,
            device=policy.backend.device
        )
        
        policy.critic_model = py_torch_module.create_critic_model(
            policy.state_dim,
            device=policy.backend.device
        )
        
        @info "PyTorch actor-critic policy initialized"
        
    catch e
        error("Failed to initialize PyTorch policy: $e")
    end
end

"""
Convert Julia state to appropriate tensor format
"""
function _convert_state_to_tensor(policy::ActorCriticPolicy, state::Vector{Float64})
    if policy.policy_type == :tensorflow
        return power_lascopf_nn.utils.data_conversion.julia_to_tf_tensor(state)
    else
        return power_lascopf_nn.utils.data_conversion.julia_to_torch_tensor(
            state, device=policy.backend.device
        )
    end
end

"""
Convert tensor output back to Julia vector
"""
function _convert_tensor_to_vector(policy::ActorCriticPolicy, tensor)
    if policy.policy_type == :tensorflow
        return power_lascopf_nn.utils.data_conversion.tf_tensor_to_julia(tensor)
    else
        return power_lascopf_nn.utils.data_conversion.torch_tensor_to_julia(tensor)
    end
end

# TensorFlow-specific functions
function _get_tf_action(policy::ActorCriticPolicy, state_tensor)
    return policy.actor_model(state_tensor)
end

function _get_tf_value(policy::ActorCriticPolicy, state_tensor)
    return policy.critic_model(state_tensor)
end

function _update_tf_policy!(policy::ActorCriticPolicy, states, actions, rewards, next_states, dones)
    py_trainer = power_lascopf_nn.tensorflow.tf_training.TFTrainer(
        policy.actor_model, 
        policy.critic_model
    )
    
    return py_trainer.update(states, actions, rewards, next_states, dones)
end

# PyTorch-specific functions
function _get_torch_action(policy::ActorCriticPolicy, state_tensor)
    return policy.actor_model(state_tensor)
end

function _get_torch_value(policy::ActorCriticPolicy, state_tensor)
    return policy.critic_model(state_tensor)
end

function _update_torch_policy!(policy::ActorCriticPolicy, states, actions, rewards, next_states, dones)
    py_trainer = power_lascopf_nn.pytorch.torch_training.TorchTrainer(
        policy.actor_model,
        policy.critic_model,
        device=policy.backend.device
    )
    
    return py_trainer.update(states, actions, rewards, next_states, dones)
end

export _initialize_tensorflow_policy!, _initialize_pytorch_policy!
export _convert_state_to_tensor, _convert_tensor_to_vector