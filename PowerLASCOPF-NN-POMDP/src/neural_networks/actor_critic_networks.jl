"""
Native Julia Actor-Critic Neural Networks for RL Policy
Built on existing PowerLASCOPF neural network infrastructure
"""

using LinearAlgebra
using Random
using Statistics

# Import existing neural network components
include("neural_network.jl")  # Assuming this contains base NeuralNetwork type
include("activation_functions.jl")
include("optimizers.jl")

"""
Actor Network for policy approximation
Outputs action probabilities or deterministic actions
"""
mutable struct ActorNetwork
    network::NeuralNetwork
    output_type::Symbol  # :stochastic or :deterministic
    action_bounds::Tuple{Vector{Float64}, Vector{Float64}}  # (min, max) bounds
    exploration_noise::Float64
    
    function ActorNetwork(state_dim::Int, action_dim::Int, hidden_dims::Vector{Int};
                         output_type::Symbol=:stochastic,
                         action_bounds::Tuple{Vector{Float64}, Vector{Float64}}=(fill(-1.0, action_dim), fill(1.0, action_dim)),
                         exploration_noise::Float64=0.1)
        
        # Build network architecture
        layer_dims = [state_dim, hidden_dims..., action_dim]
        
        # Create activation functions
        activations = [relu for _ in 1:(length(layer_dims)-2)]
        if output_type == :stochastic
            push!(activations, softmax)  # For probability outputs
        else
            push!(activations, tanh)     # For bounded continuous actions
        end
        
        network = NeuralNetwork(layer_dims, activations)
        
        new(network, output_type, action_bounds, exploration_noise)
    end
end

"""
Critic Network for value function approximation
Outputs state value estimates
"""
mutable struct CriticNetwork
    network::NeuralNetwork
    value_bounds::Tuple{Float64, Float64}  # Expected value range
    
    function CriticNetwork(state_dim::Int, hidden_dims::Vector{Int};
                          value_bounds::Tuple{Float64, Float64}=(-100.0, 100.0))
        
        # Build network architecture
        layer_dims = [state_dim, hidden_dims..., 1]  # Single output for value
        
        # Create activation functions (linear output for value)
        activations = [relu for _ in 1:(length(layer_dims)-2)]
        push!(activations, identity)  # Linear output layer
        
        network = NeuralNetwork(layer_dims, activations)
        
        new(network, value_bounds)
    end
end

"""
Forward pass through actor network
"""
function forward(actor::ActorNetwork, state::Vector{Float64})::Vector{Float64}
    logits = forward(actor.network, state)
    
    if actor.output_type == :stochastic
        # Apply softmax and sample action
        probs = softmax(logits)
        action_idx = sample_categorical(probs)
        action = zeros(length(probs))
        action[action_idx] = 1.0
        return action
    else
        # Deterministic action with bounds
        bounded_action = clamp.(logits, 
                               actor.action_bounds[1], 
                               actor.action_bounds[2])
        
        # Add exploration noise during training
        if actor.exploration_noise > 0
            noise = randn(length(bounded_action)) * actor.exploration_noise
            bounded_action += noise
            bounded_action = clamp.(bounded_action,
                                   actor.action_bounds[1],
                                   actor.action_bounds[2])
        end
        
        return bounded_action
    end
end

"""
Forward pass through critic network
"""
function forward(critic::CriticNetwork, state::Vector{Float64})::Float64
    value = forward(critic.network, state)[1]  # Single output
    return clamp(value, critic.value_bounds[1], critic.value_bounds[2])
end

"""
Compute policy gradient for actor network
"""
function compute_policy_gradient!(actor::ActorNetwork, 
                                 states::Matrix{Float64},
                                 actions::Matrix{Float64},
                                 advantages::Vector{Float64})
    
    batch_size = size(states, 2)
    total_grad = zero_gradients(actor.network)
    
    for i in 1:batch_size
        state = states[:, i]
        action = actions[:, i]
        advantage = advantages[i]
        
        # Forward pass to get action probabilities/logits
        output = forward(actor.network, state)
        
        if actor.output_type == :stochastic
            # Policy gradient for stochastic policy
            probs = softmax(output)
            action_idx = argmax(action)  # Assuming one-hot encoding
            
            # Compute gradient: ∇log(π(a|s)) * A(s,a)
            grad_log_prob = zeros(length(probs))
            grad_log_prob[action_idx] = advantage / max(probs[action_idx], 1e-8)
            
        else
            # Policy gradient for deterministic policy
            # Use advantage-weighted mean squared error
            action_error = action - output
            grad_log_prob = advantage * action_error
        end
        
        # Backpropagate through network
        grad = backward(actor.network, state, grad_log_prob)
        total_grad = add_gradients(total_grad, grad)
    end
    
    # Average gradients
    return scale_gradients(total_grad, 1.0 / batch_size)
end

"""
Compute value function gradient for critic network
"""
function compute_value_gradient!(critic::CriticNetwork,
                                states::Matrix{Float64},
                                target_values::Vector{Float64})
    
    batch_size = size(states, 2)
    total_grad = zero_gradients(critic.network)
    total_loss = 0.0
    
    for i in 1:batch_size
        state = states[:, i]
        target = target_values[i]
        
        # Forward pass
        predicted_value = forward(critic.network, state)[1]
        
        # Compute MSE loss and gradient
        error = predicted_value - target
        total_loss += 0.5 * error^2
        
        # Gradient of MSE w.r.t. output
        grad_output = [error]
        
        # Backpropagate
        grad = backward(critic.network, state, grad_output)
        total_grad = add_gradients(total_grad, grad)
    end
    
    # Return average gradient and loss
    avg_grad = scale_gradients(total_grad, 1.0 / batch_size)
    avg_loss = total_loss / batch_size
    
    return avg_grad, avg_loss
end

"""
Helper function to sample from categorical distribution
"""
function sample_categorical(probs::Vector{Float64})::Int
    cumsum_probs = cumsum(probs)
    rand_val = rand()
    return findfirst(x -> x >= rand_val, cumsum_probs)
end

"""
Compute advantages using temporal difference
"""
function compute_advantages(values::Vector{Float64}, 
                           rewards::Vector{Float64},
                           next_values::Vector{Float64},
                           dones::Vector{Bool},
                           gamma::Float64=0.99,
                           lambda::Float64=0.95)::Vector{Float64}
    
    T = length(rewards)
    advantages = zeros(T)
    td_errors = zeros(T)
    
    # Compute TD errors
    for t in 1:T
        if dones[t]
            td_errors[t] = rewards[t] - values[t]
        else
            td_errors[t] = rewards[t] + gamma * next_values[t] - values[t]
        end
    end
    
    # Compute GAE (Generalized Advantage Estimation)
    advantages[T] = td_errors[T]
    for t in (T-1):-1:1
        if dones[t]
            advantages[t] = td_errors[t]
        else
            advantages[t] = td_errors[t] + gamma * lambda * advantages[t+1]
        end
    end
    
    return advantages
end

export ActorNetwork, CriticNetwork
export forward, compute_policy_gradient!, compute_value_gradient!
export compute_advantages, sample_categorical
