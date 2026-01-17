"""
Reinforcement Learning Policy Interface for PowerLASCOPF
Provides unified interface for TensorFlow and PyTorch actor-critic models
"""

using PyCall
using JSON3
using Statistics
using LinearAlgebra

# Include native Julia neural networks
include("../neural_networks/actor_critic_networks.jl")

# Abstract types for RL components
abstract type AbstractRLPolicy end
abstract type AbstractActorCritic end
abstract type AbstractPolicyBackend end

# Backend types
struct TensorFlowBackend <: AbstractPolicyBackend
    session::PyObject
    model_path::String
end

struct PyTorchBackend <: AbstractPolicyBackend
    device::String
    model_path::String
end

# Add native Julia backend
struct JuliaBackend <: AbstractPolicyBackend
    device::Symbol  # :cpu or :gpu
    optimizer_config::Dict{String, Any}
    model_save_path::String
end

# Enhanced Actor-Critic Policy wrapper
mutable struct ActorCriticPolicy <: AbstractRLPolicy
    backend::AbstractPolicyBackend
    actor_model::Union{PyObject, ActorNetwork}
    critic_model::Union{PyObject, CriticNetwork}
    state_dim::Int
    action_dim::Int
    policy_type::Symbol  # :tensorflow, :pytorch, or :julia
    performance_metrics::Dict{String, Any}
    training_config::Dict{String, Any}
    
    function ActorCriticPolicy(backend::AbstractPolicyBackend, state_dim::Int, action_dim::Int)
        policy_type = if typeof(backend) == TensorFlowBackend
            :tensorflow
        elseif typeof(backend) == PyTorchBackend
            :pytorch
        else
            :julia
        end
        
        new(backend, PyNULL(), PyNULL(), state_dim, action_dim, policy_type,
            Dict{String, Any}(), Dict{String, Any}())
    end
end

"""
Initialize RL policy with specified backend
"""
function initialize_rl_policy(backend_type::Symbol, state_dim::Int, action_dim::Int; 
                              model_path::String="", device::String="cpu",
                              hidden_dims::Vector{Int}=[128, 64],
                              learning_rate::Float64=0.001)
    if backend_type == :tensorflow
        backend = TensorFlowBackend(PyNULL(), model_path)
        policy = ActorCriticPolicy(backend, state_dim, action_dim)
        _initialize_tensorflow_policy!(policy)
    elseif backend_type == :pytorch
        backend = PyTorchBackend(device, model_path)
        policy = ActorCriticPolicy(backend, state_dim, action_dim)
        _initialize_pytorch_policy!(policy)
    elseif backend_type == :julia
        device_sym = device == "gpu" ? :gpu : :cpu
        backend = JuliaBackend(device_sym, 
                              Dict("learning_rate" => learning_rate), 
                              model_path)
        policy = ActorCriticPolicy(backend, state_dim, action_dim)
        _initialize_julia_policy!(policy, hidden_dims, learning_rate)
    else
        error("Unsupported backend: $backend_type. Use :tensorflow, :pytorch, or :julia")
    end
    
    return policy
end

"""
Get action from policy given current state (enhanced for all backends)
"""
function get_action(policy::ActorCriticPolicy, state::Vector{Float64})::Vector{Float64}
    if policy.policy_type == :julia
        return _get_julia_action(policy, state)
    else
        state_tensor = _convert_state_to_tensor(policy, state)
        
        if policy.policy_type == :tensorflow
            action = _get_tf_action(policy, state_tensor)
        else
            action = _get_torch_action(policy, state_tensor)
        end
        
        return _convert_tensor_to_vector(policy, action)
    end
end

"""
Get state value estimate from critic (enhanced for all backends)
"""
function get_state_value(policy::ActorCriticPolicy, state::Vector{Float64})::Float64
    if policy.policy_type == :julia
        return _get_julia_value(policy, state)
    else
        state_tensor = _convert_state_to_tensor(policy, state)
        
        if policy.policy_type == :tensorflow
            value = _get_tf_value(policy, state_tensor)
        else
            value = _get_torch_value(policy, state_tensor)
        end
        
        return Float64(value)
    end
end

"""
Update policy with experience (enhanced for all backends)
"""
function update_policy!(policy::ActorCriticPolicy, 
                       states::Matrix{Float64},
                       actions::Matrix{Float64}, 
                       rewards::Vector{Float64},
                       next_states::Matrix{Float64},
                       dones::Vector{Bool})
    
    start_time = time()
    
    if policy.policy_type == :julia
        loss = _update_julia_policy!(policy, states, actions, rewards, next_states, dones)
    elseif policy.policy_type == :tensorflow
        loss = _update_tf_policy!(policy, states, actions, rewards, next_states, dones)
    else
        loss = _update_torch_policy!(policy, states, actions, rewards, next_states, dones)
    end
    
    # Update performance metrics
    policy.performance_metrics["last_update_time"] = time() - start_time
    policy.performance_metrics["last_loss"] = loss
    
    return loss
end

export AbstractRLPolicy, ActorCriticPolicy, TensorFlowBackend, PyTorchBackend, JuliaBackend
export initialize_rl_policy, get_action, get_state_value, update_policy!
export benchmark_policies, save_policy, load_policy