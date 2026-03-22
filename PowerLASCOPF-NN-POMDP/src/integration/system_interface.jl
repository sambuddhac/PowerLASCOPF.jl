"""
System Interface for PowerLASCOPF-NN-POMDP Integration
Provides the main interface between POMDP, RL policies, and PowerLASCOPF core
"""

using LinearAlgebra
using Statistics
using Random
using Distributions

# Include required modules
include("../julia_interface/rl_policy_interface.jl")
include("../pomdp/power_system_pomdp.jl")
include("../../src/extensions/extended_system.jl")

"""
Main integration structure that coordinates all components
"""
mutable struct PowerSystemController
    # Core systems
    power_system::PowerLASCOPFSystem
    pomdp_model::PowerSystemPOMDP
    rl_policy::ActorCriticPolicy
    
    # State management
    current_belief::BeliefState
    observation_history::Vector{Vector{Float64}}
    action_history::Vector{Vector{Float64}}
    reward_history::Vector{Float64}
    
    # Control parameters
    control_frequency::Float64  # Hz
    prediction_horizon::Int     # steps ahead
    safety_margin::Float64      # constraint buffer
    
    # Performance tracking
    performance_metrics::Dict{String, Any}
    operational_status::Symbol  # :normal, :emergency, :training
    
    function PowerSystemController(
        power_system::PowerLASCOPFSystem,
        pomdp_model::PowerSystemPOMDP,
        rl_policy::ActorCriticPolicy;
        control_frequency::Float64 = 1.0,
        prediction_horizon::Int = 24,
        safety_margin::Float64 = 0.05
    )
        new(
            power_system,
            pomdp_model,
            rl_policy,
            initialize_belief(pomdp_model),
            Vector{Vector{Float64}}(),
            Vector{Vector{Float64}}(),
            Float64[],
            control_frequency,
            prediction_horizon,
            safety_margin,
            Dict{String, Any}(),
            :normal
        )
    end
end

"""
State extraction from PowerLASCOPF system to RL-compatible format
"""
function extract_system_state(sys::PowerLASCOPFSystem)::Vector{Float64}
    state = Float64[]
    
    # Extract node information (voltages, angles, power injections)
    for node in get_nodes(sys)
        append!(state, [
            node.theta_avg,      # Bus angle
            node.P_avg,          # Active power injection
            node.v_avg,          # Voltage magnitude
            node.u               # Nodal price/multiplier
        ])
    end
    
    # Extract generator information
    for gen in get_extended_thermal_generators(sys)
        append!(state, [
            gen.power_output,    # Current output
            gen.ramp_rate,       # Ramping capability
            gen.marginal_cost,   # Operating cost
            gen.availability     # Unit availability
        ])
    end
    
    # Extract transmission line information
    for line in get_transmission_lines(sys)
        append!(state, [
            line.power_flow,     # Current flow
            line.thermal_limit,  # Capacity limit
            line.reactance,      # Line impedance
            Float64(line.status) # Line status (1=online, 0=offline)
        ])
    end
    
    # System-wide metrics
    append!(state, [
        calculate_total_generation(sys),
        calculate_total_load(sys),
        calculate_system_frequency(sys),
        calculate_voltage_stability_margin(sys),
        calculate_transmission_loading(sys)
    ])
    
    return state
end

"""
Convert RL policy actions to PowerLASCOPF control commands
"""
function apply_policy_action(
    sys::PowerLASCOPFSystem, 
    action::Vector{Float64}
)::Dict{String, Any}
    
    num_generators = get_extended_thermal_generator_count(sys)
    num_nodes = get_node_count(sys)
    num_lines = get_transmission_line_count(sys)
    
    # Parse action vector
    action_idx = 1
    
    # Generator dispatch adjustments
    gen_dispatch = action[action_idx:(action_idx + num_generators - 1)]
    action_idx += num_generators
    
    # Voltage setpoint adjustments
    voltage_adjustments = action[action_idx:(action_idx + num_nodes - 1)]
    action_idx += num_nodes
    
    # Emergency actions (load shedding, line switching)
    emergency_actions = action[action_idx:end]
    
    # Apply generator dispatch
    for (i, gen) in enumerate(get_extended_thermal_generators(sys))
        new_output = clamp(
            gen.power_output + gen_dispatch[i],
            gen.min_power,
            gen.max_power
        )
        set_generator_output!(gen, new_output)
    end
    
    # Apply voltage control
    for (i, node) in enumerate(get_nodes(sys))
        voltage_setpoint = clamp(
            1.0 + voltage_adjustments[i] * 0.1,  # ±10% adjustment
            0.9, 1.1  # NERC voltage limits
        )
        set_voltage_setpoint!(node, voltage_setpoint)
    end
    
    # Process emergency actions if needed
    control_actions = Dict{String, Any}(
        "generator_dispatch" => gen_dispatch,
        "voltage_adjustments" => voltage_adjustments,
        "emergency_actions" => emergency_actions,
        "total_cost_change" => calculate_cost_impact(sys, gen_dispatch)
    )
    
    return control_actions
end

"""
Calculate reward signal based on system performance
"""
function calculate_reward(
    sys::PowerLASCOPFSystem,
    prev_state::Vector{Float64},
    current_state::Vector{Float64},
    actions::Vector{Float64}
)::Float64
    
    # Economic efficiency (minimize operating cost)
    economic_reward = -calculate_total_operating_cost(sys) / 1000.0  # Normalize
    
    # System security (penalize constraint violations)
    security_penalty = -1000.0 * count_security_violations(sys)
    
    # Voltage stability
    voltage_deviations = [abs(node.v_avg - 1.0) for node in get_nodes(sys)]
    voltage_penalty = -100.0 * sum(voltage_deviations)
    
    # Frequency stability
    frequency_deviation = abs(calculate_system_frequency(sys) - 60.0)
    frequency_penalty = -50.0 * frequency_deviation
    
    # Transmission congestion
    line_loadings = [line.power_flow / line.thermal_limit for line in get_transmission_lines(sys)]
    congestion_penalty = -10.0 * sum(max.(line_loadings .- 0.9, 0.0))  # Penalty above 90%
    
    # Action smoothness (discourage erratic control)
    action_penalty = -0.1 * sum(abs2.(actions))
    
    total_reward = (
        economic_reward +
        security_penalty +
        voltage_penalty +
        frequency_penalty +
        congestion_penalty +
        action_penalty
    )
    
    return total_reward
end

"""
Main control loop that integrates all components
"""
function control_step!(controller::PowerSystemController)
    try
        # 1. Get current observation from power system
        raw_observation = extract_system_state(controller.power_system)
        
        # 2. Update POMDP belief state
        observation = add_measurement_noise(raw_observation)
        controller.current_belief = update_belief(
            controller.pomdp_model,
            controller.current_belief,
            observation
        )
        
        # 3. Get action from RL policy
        belief_vector = belief_to_vector(controller.current_belief)
        policy_action = get_action(controller.rl_policy, belief_vector)
        
        # 4. Apply safety checks and constraints
        safe_action = apply_safety_layer(controller, policy_action)
        
        # 5. Execute action in PowerLASCOPF system
        control_commands = apply_policy_action(controller.power_system, safe_action)
        
        # 6. Run PowerLASCOPF optimization
        optimization_result = solve_power_system!(controller.power_system)
        
        # 7. Calculate reward and update metrics
        new_state = extract_system_state(controller.power_system)
        reward = calculate_reward(
            controller.power_system,
            raw_observation,
            new_state,
            safe_action
        )
        
        # 8. Store experience for training
        push!(controller.observation_history, raw_observation)
        push!(controller.action_history, safe_action)
        push!(controller.reward_history, reward)
        
        # 9. Update performance metrics
        update_performance_metrics!(controller, optimization_result, reward)
        
        return Dict(
            "success" => true,
            "action" => safe_action,
            "reward" => reward,
            "state" => new_state,
            "control_commands" => control_commands
        )
        
    catch e
        # Emergency fallback
        emergency_action = emergency_control_action(controller)
        controller.operational_status = :emergency
        
        return Dict(
            "success" => false,
            "error" => string(e),
            "emergency_action" => emergency_action
        )
    end
end

"""
Apply safety constraints to RL policy actions
"""
function apply_safety_layer(
    controller::PowerSystemController, 
    raw_action::Vector{Float64}
)::Vector{Float64}
    
    safe_action = copy(raw_action)
    sys = controller.power_system
    
    # Constraint 1: Generator ramp rate limits
    for (i, gen) in enumerate(get_extended_thermal_generators(sys))
        max_ramp = gen.ramp_rate * (1.0 / controller.control_frequency)
        current_output = gen.power_output
        
        # Limit action to respect ramp rates
        if i <= length(safe_action)
            proposed_change = safe_action[i] * gen.max_power * 0.1  # 10% max change
            clamped_change = clamp(proposed_change, -max_ramp, max_ramp)
            safe_action[i] = clamped_change / (gen.max_power * 0.1)
        end
    end
    
    # Constraint 2: Voltage limits
    num_gens = get_extended_thermal_generator_count(sys)
    for (i, node) in enumerate(get_nodes(sys))
        voltage_action_idx = num_gens + i
        if voltage_action_idx <= length(safe_action)
            # Limit voltage adjustments to ±5%
            safe_action[voltage_action_idx] = clamp(safe_action[voltage_action_idx], -0.5, 0.5)
        end
    end
    
    # Constraint 3: Emergency action thresholds
    # Only allow emergency actions if system is in distress
    system_stress = calculate_system_stress_level(sys)
    if system_stress < 0.7  # Below 70% stress
        # Disable emergency actions
        emergency_start_idx = num_gens + get_node_count(sys) + 1
        if emergency_start_idx <= length(safe_action)
            safe_action[emergency_start_idx:end] .*= 0.0
        end
    end
    
    return safe_action
end

"""
Emergency control action when RL policy fails
"""
function emergency_control_action(controller::PowerSystemController)::Vector{Float64}
    sys = controller.power_system
    
    # Simple rule-based emergency controller
    emergency_action = zeros(Float64, length(controller.action_history[end]))
    
    # Emergency generator dispatch: Increase lowest-cost units
    generators = get_extended_thermal_generators(sys)
    sorted_gens = sort(generators, by=gen -> gen.marginal_cost)
    
    for (i, gen) in enumerate(sorted_gens[1:min(3, length(generators))])
        gen_idx = findfirst(g -> g == gen, generators)
        if gen_idx !== nothing && gen_idx <= length(emergency_action)
            emergency_action[gen_idx] = 0.2  # 20% increase
        end
    end
    
    return emergency_action
end

"""
Training interface for the RL policy
"""
function train_policy!(
    controller::PowerSystemController;
    num_episodes::Int = 1000,
    episode_length::Int = 100,
    batch_size::Int = 64
)
    
    println("🚀 Starting RL policy training...")
    training_rewards = Float64[]
    
    for episode in 1:num_episodes
        # Reset environment
        reset_power_system!(controller.power_system)
        controller.current_belief = initialize_belief(controller.pomdp_model)
        empty!(controller.observation_history)
        empty!(controller.action_history)
        empty!(controller.reward_history)
        
        episode_reward = 0.0
        
        # Run episode
        for step in 1:episode_length
            result = control_step!(controller)
            
            if result["success"]
                episode_reward += result["reward"]
            else
                # Early termination on failure
                break
            end
            
            # Add random disturbances for training
            if rand() < 0.1  # 10% chance
                apply_random_disturbance!(controller.power_system)
            end
        end
        
        # Train policy on collected experience
        if length(controller.observation_history) >= batch_size
            states = hcat(controller.observation_history[end-batch_size+1:end]...)
            actions = hcat(controller.action_history[end-batch_size+1:end]...)
            rewards = controller.reward_history[end-batch_size+1:end]
            
            # Create dummy next states and dones for training
            next_states = hcat([states[:, 2:end] zeros(size(states, 1))]...)
            dones = [fill(false, batch_size-1); true]
            
            loss = update_policy!(
                controller.rl_policy,
                states, actions, rewards, next_states, dones
            )
            
            if episode % 10 == 0
                avg_reward = mean(training_rewards[max(1, end-9):end])
                println("Episode $episode: Avg Reward = $(round(avg_reward, digits=2)), Loss = $(round(loss, digits=4))")
            end
        end
        
        push!(training_rewards, episode_reward)
    end
    
    println("✅ Training completed!")
    return training_rewards
end

"""
Comprehensive system validation and testing
"""
function validate_system_integration(controller::PowerSystemController)
    println("🔍 Validating PowerLASCOPF-NN-POMDP integration...")
    
    validation_results = Dict{String, Any}()
    
    # Test 1: State extraction
    try
        state = extract_system_state(controller.power_system)
        validation_results["state_extraction"] = Dict(
            "success" => true,
            "state_dim" => length(state),
            "state_range" => (minimum(state), maximum(state))
        )
    catch e
        validation_results["state_extraction"] = Dict(
            "success" => false,
            "error" => string(e)
        )
    end
    
    # Test 2: Policy inference
    try
        test_state = randn(controller.rl_policy.state_dim)
        action = get_action(controller.rl_policy, test_state)
        validation_results["policy_inference"] = Dict(
            "success" => true,
            "action_dim" => length(action),
            "action_range" => (minimum(action), maximum(action))
        )
    catch e
        validation_results["policy_inference"] = Dict(
            "success" => false,
            "error" => string(e)
        )
    end
    
    # Test 3: POMDP belief updates
    try
        test_obs = randn(length(extract_system_state(controller.power_system)))
        new_belief = update_belief(
            controller.pomdp_model,
            controller.current_belief,
            test_obs
        )
        validation_results["pomdp_update"] = Dict(
            "success" => true,
            "belief_type" => typeof(new_belief)
        )
    catch e
        validation_results["pomdp_update"] = Dict(
            "success" => false,
            "error" => string(e)
        )
    end
    
    # Test 4: Full control loop
    try
        result = control_step!(controller)
        validation_results["control_loop"] = result
    catch e
        validation_results["control_loop"] = Dict(
            "success" => false,
            "error" => string(e)
        )
    end
    
    # Print results
    println("📊 Validation Results:")
    for (test_name, result) in validation_results
        status = result["success"] ? "✅" : "❌"
        println("  $status $test_name")
        if !result["success"]
            println("     Error: $(result["error"])")
        end
    end
    
    return validation_results
end

# Helper functions for system calculations
calculate_total_generation(sys::PowerLASCOPFSystem) = sum(gen.power_output for gen in get_extended_thermal_generators(sys))
calculate_total_load(sys::PowerLASCOPFSystem) = sum(node.conn_load_val for node in get_nodes(sys))
calculate_system_frequency(sys::PowerLASCOPFSystem) = 60.0 + 0.1 * (calculate_total_generation(sys) - calculate_total_load(sys))
calculate_voltage_stability_margin(sys::PowerLASCOPFSystem) = minimum([1.0 - abs(node.v_avg - 1.0) for node in get_nodes(sys)])
calculate_transmission_loading(sys::PowerLASCOPFSystem) = maximum([line.power_flow / line.thermal_limit for line in get_transmission_lines(sys)])
calculate_total_operating_cost(sys::PowerLASCOPFSystem) = sum(gen.operating_cost for gen in get_extended_thermal_generators(sys))
count_security_violations(sys::PowerLASCOPFSystem) = count(line -> line.power_flow > line.thermal_limit, get_transmission_lines(sys))
calculate_system_stress_level(sys::PowerLASCOPFSystem) = calculate_transmission_loading(sys)

function add_measurement_noise(observation::Vector{Float64}, noise_level::Float64 = 0.01)
    return observation + noise_level * randn(length(observation))
end

export PowerSystemController, extract_system_state, apply_policy_action, calculate_reward
export control_step!, train_policy!, validate_system_integration
export apply_safety_layer, emergency_control_action
