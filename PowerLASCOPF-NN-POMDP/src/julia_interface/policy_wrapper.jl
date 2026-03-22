"""
High-level policy wrapper for PowerLASCOPF integration
"""

using Dates
using Statistics

"""
LASCOPF-specific policy wrapper with power system integration
"""
mutable struct LASCOPFRLPolicy <: AbstractRLPolicy
    actor_critic_policy::ActorCriticPolicy
    power_system::PSY.System
    state_extractor::Function
    action_interpreter::Function
    reward_computer::Function
    performance_history::Vector{Dict{String, Any}}
    
    function LASCOPFRLPolicy(backend_type::Symbol, power_system::PSY.System;
                            state_dim::Int=50, action_dim::Int=20)
        
        # Initialize actor-critic policy
        policy = initialize_rl_policy(backend_type, state_dim, action_dim)
        
        # Default state extractor (can be customized)
        state_extractor = default_state_extractor
        
        # Default action interpreter (can be customized)
        action_interpreter = default_action_interpreter
        
        # Default reward computer (can be customized)
        reward_computer = default_reward_computer
        
        new(policy, power_system, state_extractor, action_interpreter, 
            reward_computer, Dict{String, Any}[])
    end
end

"""
Extract state vector from power system for RL
"""
function default_state_extractor(system::PSY.System, 
                                lascopf_state::Dict{String, Any})::Vector{Float64}
    state = Float64[]
    
    # Generator states
    generators = PSY.get_components(PSY.ThermalGen, system)
    for gen in generators
        push!(state, PSY.get_active_power(gen))  # Current output
        push!(state, PSY.get_reactive_power(gen))  # Reactive output
        # Add more generator features as needed
    end
    
    # Bus voltages
    buses = PSY.get_components(PSY.Bus, system)
    for bus in buses
        push!(state, PSY.get_magnitude(bus))  # Voltage magnitude
        push!(state, PSY.get_angle(bus))      # Voltage angle
    end
    
    # Line flows (if available)
    lines = PSY.get_components(PSY.Line, system)
    for line in lines
        # Would need to get power flow results
        push!(state, 0.0)  # Placeholder for line flow
    end
    
    # ADMM/APP algorithm states
    admm_state = get(lascopf_state, "admm", Dict())
    push!(state, get(admm_state, "rho", 1.0))
    push!(state, get(admm_state, "beta", 1.0))
    
    # Pad or truncate to expected dimension
    target_dim = 50  # Should match state_dim
    while length(state) < target_dim
        push!(state, 0.0)
    end
    
    return state[1:target_dim]
end

"""
Interpret RL actions as power system control actions
"""
function default_action_interpreter(action::Vector{Float64}, 
                                   system::PSY.System)::Dict{String, Any}
    control_actions = Dict{String, Any}()
    
    generators = collect(PSY.get_components(PSY.ThermalGen, system))
    
    # Interpret actions as generator setpoints
    for (i, gen) in enumerate(generators)
        if i <= length(action)
            # Scale action from [-1, 1] to generator limits
            limits = PSY.get_active_power_limits(gen)
            scaled_power = limits.min + (action[i] + 1) * (limits.max - limits.min) / 2
            
            control_actions[PSY.get_name(gen)] = Dict(
                "active_power" => scaled_power,
                "commitment" => scaled_power > limits.min + 0.01
            )
        end
    end
    
    # ADMM parameter adjustments (last few actions)
    if length(action) >= 2
        control_actions["admm_params"] = Dict(
            "rho_adjustment" => action[end-1] * 0.1,  # Small adjustment
            "beta_adjustment" => action[end] * 0.1
        )
    end
    
    return control_actions
end

"""
Compute reward based on power system performance
"""
function default_reward_computer(system::PSY.System, 
                                control_actions::Dict{String, Any},
                                system_results::Dict{String, Any})::Float64
    reward = 0.0
    
    # Economic component - minimize generation cost
    total_cost = get(system_results, "total_generation_cost", 0.0)
    reward -= total_cost / 1000.0  # Scale down
    
    # Security constraints - penalize violations
    voltage_violations = get(system_results, "voltage_violations", 0.0)
    line_violations = get(system_results, "line_flow_violations", 0.0)
    reward -= 100.0 * (voltage_violations + line_violations)
    
    # Convergence reward
    if get(system_results, "converged", false)
        reward += 50.0
        
        # Additional reward for fast convergence
        iterations = get(system_results, "iterations", 100)
        reward += max(0.0, 50.0 - iterations)
    end
    
    # System stability reward
    max_voltage_deviation = get(system_results, "max_voltage_deviation", 0.0)
    reward -= 10.0 * max_voltage_deviation
    
    return reward
end

"""
Run RL-based LASCOPF optimization
"""
function run_rl_lascopf!(policy::LASCOPFRLPolicy, 
                        num_episodes::Int=100;
                        max_steps_per_episode::Int=50)
    
    episode_rewards = Float64[]
    
    for episode in 1:num_episodes
        println("Episode $episode/$num_episodes")
        
        # Reset system to initial state
        reset_power_system!(policy.power_system)
        
        episode_reward = 0.0
        episode_start_time = time()
        
        for step in 1:max_steps_per_episode
            # Extract current state
            lascopf_state = get_current_lascopf_state(policy.power_system)
            state = policy.state_extractor(policy.power_system, lascopf_state)
            
            # Get action from policy
            action = get_action(policy.actor_critic_policy, state)
            
            # Interpret action as control commands
            control_actions = policy.action_interpreter(action, policy.power_system)
            
            # Apply actions and run LASCOPF step
            system_results = apply_actions_and_solve!(policy.power_system, control_actions)
            
            # Compute reward
            step_reward = policy.reward_computer(policy.power_system, control_actions, system_results)
            episode_reward += step_reward
            
            # Check if episode is done
            done = get(system_results, "converged", false) || step == max_steps_per_episode
            
            # Get next state for learning
            next_lascopf_state = get_current_lascopf_state(policy.power_system)
            next_state = policy.state_extractor(policy.power_system, next_lascopf_state)
            
            # Store experience and update policy (if we had previous experience)
            if step > 1
                # Update policy with previous experience
                states = reshape(prev_state, 1, :)
                actions = reshape(prev_action, 1, :)
                rewards = [step_reward]
                next_states = reshape(state, 1, :)
                dones = [done]
                
                update_policy!(policy.actor_critic_policy, states, actions, rewards, next_states, dones)
            end
            
            # Store for next iteration
            prev_state = state
            prev_action = action
            
            if done
                break
            end
        end
        
        push!(episode_rewards, episode_reward)
        
        # Record performance
        episode_info = Dict{String, Any}(
            "episode" => episode,
            "reward" => episode_reward,
            "duration" => time() - episode_start_time,
            "backend" => policy.actor_critic_policy.policy_type
        )
        push!(policy.performance_history, episode_info)
        
        # Print progress
        if episode % 10 == 0
            avg_reward = mean(episode_rewards[max(1, end-9):end])
            println("  Average reward (last 10): $avg_reward")
        end
    end
    
    return episode_rewards
end

"""
Compare performance between TensorFlow and PyTorch
"""
function compare_rl_backends(power_system::PSY.System; 
                           num_episodes::Int=50, 
                           state_dim::Int=50, 
                           action_dim::Int=20)
    
    println("🧪 Comparing RL Backend Performance")
    println("=" * 50)
    
    results = Dict{Symbol, Any}()
    
    for backend in [:tensorflow, :pytorch]
        println("\n🚀 Testing $backend backend...")
        
        # Create policy with specific backend
        policy = LASCOPFRLPolicy(backend, power_system; 
                               state_dim=state_dim, action_dim=action_dim)
        
        # Run episodes
        start_time = time()
        episode_rewards = run_rl_lascopf!(policy, num_episodes)
        total_time = time() - start_time
        
        # Compute statistics
        results[backend] = Dict(
            "episode_rewards" => episode_rewards,
            "mean_reward" => mean(episode_rewards),
            "std_reward" => std(episode_rewards),
            "total_time" => total_time,
            "avg_time_per_episode" => total_time / num_episodes,
            "final_10_avg" => mean(episode_rewards[max(1, end-9):end])
        )
        
        println("  ✅ $backend completed:")
        println("    Mean reward: $(round(results[backend]["mean_reward"], digits=2))")
        println("    Final 10 avg: $(round(results[backend]["final_10_avg"], digits=2))")
        println("    Total time: $(round(total_time, digits=2))s")
    end
    
    # Performance comparison
    println("\n📊 Performance Comparison:")
    tf_time = results[:tensorflow]["avg_time_per_episode"]
    torch_time = results[:pytorch]["avg_time_per_episode"]
    
    if tf_time < torch_time
        speedup = torch_time / tf_time
        println("  🏆 TensorFlow is $(round(speedup, digits=2))x faster")
    else
        speedup = tf_time / torch_time
        println("  🏆 PyTorch is $(round(speedup, digits=2))x faster")
    end
    
    tf_reward = results[:tensorflow]["final_10_avg"]
    torch_reward = results[:pytorch]["final_10_avg"]
    
    if tf_reward > torch_reward
        println("  🎯 TensorFlow achieved better final performance")
    else
        println("  🎯 PyTorch achieved better final performance")
    end
    
    return results
end

# Placeholder functions - would be implemented based on your LASCOPF system
function reset_power_system!(system::PSY.System)
    # Reset system to initial state
end

function get_current_lascopf_state(system::PSY.System)::Dict{String, Any}
    # Extract current LASCOPF algorithm state
    return Dict{String, Any}()
end

function apply_actions_and_solve!(system::PSY.System, actions::Dict{String, Any})::Dict{String, Any}
    # Apply control actions and run one LASCOPF iteration
    return Dict{String, Any}("converged" => false, "total_generation_cost" => 1000.0)
end

export LASCOPFRLPolicy, run_rl_lascopf!, compare_rl_backends
export default_state_extractor, default_action_interpreter, default_reward_computer