using Flux
using POMDPs
using POMDPTools
using CUDA
using Statistics

"""
Neural Network Policy for PowerLASCOPF POMDP using Flux.jl
"""
struct NeuralNetworkPolicy <: PowerSystemPolicy
    pomdp::PowerLASCOPFPOMDP
    
    # Neural networks
    actor_network::Chain          # Policy network (state/belief -> action)
    critic_network::Chain         # Value network (state/belief -> value)
    target_actor::Chain          # Target actor for stable training
    target_critic::Chain         # Target critic for stable training
    
    # Network parameters
    state_dim::Int
    action_dim::Int
    hidden_dims::Vector{Int}
    
    # Training parameters
    learning_rate_actor::Float64
    learning_rate_critic::Float64
    discount_factor::Float64
    target_update_rate::Float64
    
    # Experience replay
    replay_buffer::CircularBuffer{Tuple}
    batch_size::Int
    
    # Exploration
    noise_scale::Float64
    noise_decay::Float64
    
    function NeuralNetworkPolicy(pomdp::PowerLASCOPFPOMDP; 
                                hidden_dims=[512, 256, 128],
                                lr_actor=1e-4, lr_critic=1e-3,
                                discount=0.95, tau=0.005,
                                buffer_size=100000, batch_size=64,
                                noise_scale=0.1, noise_decay=0.995)
        
        # Calculate dimensions from POMDP
        state_dim = calculate_state_dimension(pomdp)
        action_dim = calculate_action_dimension(pomdp)
        
        # Create actor network (policy): belief/state -> action
        actor = Chain(
            Dense(state_dim, hidden_dims[1], relu),
            BatchNorm(hidden_dims[1]),
            Dropout(0.1),
            Dense(hidden_dims[1], hidden_dims[2], relu),
            BatchNorm(hidden_dims[2]),
            Dropout(0.1),
            Dense(hidden_dims[2], hidden_dims[3], relu),
            Dense(hidden_dims[3], action_dim, tanh)  # tanh for bounded actions
        )
        
        # Create critic network (value): belief/state -> Q-value
        critic = Chain(
            Dense(state_dim + action_dim, hidden_dims[1], relu),
            BatchNorm(hidden_dims[1]),
            Dropout(0.1),
            Dense(hidden_dims[1], hidden_dims[2], relu),
            BatchNorm(hidden_dims[2]),
            Dropout(0.1),
            Dense(hidden_dims[2], hidden_dims[3], relu),
            Dense(hidden_dims[3], 1)  # Single Q-value output
        )
        
        # Create target networks (copies for stable training)
        target_actor = deepcopy(actor)
        target_critic = deepcopy(critic)
        
        # Initialize replay buffer
        replay_buffer = CircularBuffer{Tuple}(buffer_size)
        
        new(pomdp, actor, critic, target_actor, target_critic,
            state_dim, action_dim, hidden_dims,
            lr_actor, lr_critic, discount, tau,
            replay_buffer, batch_size, noise_scale, noise_decay)
    end
end

"""
Convert belief state to neural network input
"""
function belief_to_neural_input(policy::NeuralNetworkPolicy, belief::PowerSystemBelief)
    # Extract features from belief state
    features = Float32[]
    
    # 1. Topology belief (most likely configuration)
    if !isempty(belief.topology_particles)
        best_particle_idx = argmax(belief.topology_weights)
        append!(features, Float32.(belief.topology_particles[best_particle_idx]))
    end
    
    # 2. Parameter means and uncertainties
    for (param_name, mean_vec) in belief.parameter_means
        append!(features, Float32.(mean_vec))
        
        # Add uncertainty measure (trace of covariance)
        if haskey(belief.parameter_covariances, param_name)
            cov_trace = tr(belief.parameter_covariances[param_name])
            push!(features, Float32(cov_trace))
        end
    end
    
    # 3. System state features
    append!(features, Float32[
        belief.effective_particles / belief.n_particles,  # Belief quality
        Float32(length(belief.topology_particles)),        # Number of scenarios
    ])
    
    # 4. Pad or truncate to fixed size
    target_size = policy.state_dim
    if length(features) < target_size
        append!(features, zeros(Float32, target_size - length(features)))
    elseif length(features) > target_size
        features = features[1:target_size]
    end
    
    return reshape(features, :, 1)  # Column vector for Flux
end

"""
Convert neural network output to PowerSystemAction
"""
function neural_output_to_action(policy::NeuralNetworkPolicy, nn_output::AbstractArray)
    pomdp = policy.pomdp
    n_gens = length(pomdp.generators)
    n_lines = length(pomdp.transmission_lines)
    n_loads = length(pomdp.loads)
    
    # Interpret neural network output
    output_vec = vec(nn_output)
    idx = 1
    
    # 1. Generator setpoints (first n_gens outputs)
    gen_setpoints = output_vec[idx:idx+n_gens-1]
    idx += n_gens
    
    # Scale to generator limits
    for i in 1:n_gens
        gen = pomdp.generators[i].generator
        limits = PSY.get_active_power_limits(gen)
        # Map from [-1, 1] to [Pmin, Pmax]
        gen_setpoints[i] = limits.min + (gen_setpoints[i] + 1) * (limits.max - limits.min) / 2
    end
    
    # 2. Line switching actions (next n_lines outputs)
    line_actions = output_vec[idx:idx+n_lines-1] .> 0  # Binary decisions
    idx += n_lines
    
    # 3. Load shedding (next n_loads outputs)
    load_shedding = max.(0, output_vec[idx:idx+n_loads-1])  # Non-negative
    idx += n_loads
    
    # 4. Reserves (remaining outputs)
    reserves = zeros(n_gens)
    if idx <= length(output_vec)
        reserves = max.(0, output_vec[idx:min(idx+n_gens-1, end)])
    end
    
    return PowerSystemAction(gen_setpoints, line_actions, load_shedding, reserves)
end

"""
Policy action selection using neural network
"""
function POMDPs.action(policy::NeuralNetworkPolicy, belief::PowerSystemBelief)
    # Convert belief to neural network input
    state_input = belief_to_neural_input(policy, belief)
    
    # Forward pass through actor network
    if CUDA.functional() && policy.actor_network isa CuArray
        state_input = gpu(state_input)
    end
    
    action_output = policy.actor_network(state_input)
    
    # Add exploration noise during training
    if policy.noise_scale > 0
        noise = policy.noise_scale * randn(Float32, size(action_output))
        if CUDA.functional() && action_output isa CuArray
            noise = gpu(noise)
        end
        action_output += noise
    end
    
    # Convert to CPU if needed
    if action_output isa CuArray
        action_output = cpu(action_output)
    end
    
    # Convert to PowerSystemAction
    return neural_output_to_action(policy, action_output)
end

"""
Calculate state and action dimensions for neural network
"""
function calculate_state_dimension(pomdp::PowerLASCOPFPOMDP)
    dim = 0
    
    # Topology particles (line status)
    dim += length(pomdp.transmission_lines)
    
    # Parameter beliefs (load errors, renewable errors, etc.)
    dim += length(pomdp.loads) * 2  # mean + uncertainty
    dim += count(g -> isa(g.generator, RenewableDispatch), pomdp.generators) * 2
    
    # System metadata
    dim += 2  # belief quality, number of scenarios
    
    return dim
end

function calculate_action_dimension(pomdp::PowerLASCOPFPOMDP)
    n_gens = length(pomdp.generators)
    n_lines = length(pomdp.transmission_lines)
    n_loads = length(pomdp.loads)
    
    return n_gens + n_lines + n_loads + n_gens  # gen + lines + loads + reserves
end