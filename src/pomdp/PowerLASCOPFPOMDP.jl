using POMDPs
using POMDPTools
using Distributions
using LinearAlgebra
using PowerSystems
using TimeSeries

# Include PowerLASCOPF components
include("../components/GeneralizedGenerator.jl")
include("../components/Node.jl")
include("../components/transmission_line.jl")
include("../models/solver_models/solver_model_types.jl")

"""
POMDP formulation for Power System Operation with uncertain topology and parameters
"""
struct PowerLASCOPFPOMDP <: POMDP{PowerSystemState, PowerSystemAction, PowerSystemObservation}
    # System components
    nodes::Vector{Node}
    transmission_lines::Vector{transmissionLine}
    generators::Vector{GeneralizedGenerator}
    loads::Vector
    
    # Uncertainty parameters
    topology_uncertainty::Dict{String, Float64}  # Line failure probabilities
    parameter_uncertainty::Dict{String, Distribution}  # Parameter distributions
    
    # POMDP parameters
    discount_factor::Float64
    horizon::Int
    time_step::Float64
    
    # Penalty weights
    load_shedding_penalty::Float64
    generation_cost_weight::Float64
    reliability_weight::Float64
    
    function PowerLASCOPFPOMDP(nodes, lines, generators, loads; 
                              discount=0.95, horizon=24, dt=1.0,
                              load_penalty=1000.0, gen_weight=1.0, rel_weight=100.0)
        # Initialize uncertainty parameters
        topo_unc = Dict{String, Float64}()
        param_unc = Dict{String, Distribution}()
        
        # Default line failure probabilities
        for line in lines
            topo_unc[string(line.transl_id)] = 0.001  # 0.1% failure probability
        end
        
        # Default parameter uncertainties (load and renewable forecasts)
        param_unc["load_forecast_error"] = Normal(0.0, 0.1)
        param_unc["renewable_forecast_error"] = Normal(0.0, 0.15)
        param_unc["line_capacity_degradation"] = Normal(0.0, 0.05)
        
        new(nodes, lines, generators, loads, topo_unc, param_unc,
            discount, horizon, dt, load_penalty, gen_weight, rel_weight)
    end
end

"""
State representation for power system
"""
struct PowerSystemState
    # Topology state (which lines are operational)
    line_status::Vector{Bool}
    
    # System parameters
    load_demands::Vector{Float64}
    renewable_forecasts::Vector{Float64}
    line_capacities::Vector{Float64}
    
    # System operational state
    generator_outputs::Vector{Float64}
    node_voltages::Vector{Float64}
    node_angles::Vector{Float64}
    
    # Time and scenario information
    time_step::Int
    scenario_id::Int
    
    # Belief state parameters (for uncertain quantities)
    parameter_beliefs::Dict{String, Distribution}
end

"""
Action space for power system control
"""
struct PowerSystemAction
    # Generator dispatch decisions
    generator_setpoints::Vector{Float64}
    
    # Topology control actions
    line_switching_actions::Vector{Bool}  # true = close line, false = open line
    
    # Load shedding decisions
    load_shedding::Vector{Float64}
    
    # Reserve scheduling
    reserve_allocations::Vector{Float64}
end

"""
Observation from power system measurements
"""
struct PowerSystemObservation
    # Measured quantities (with noise)
    measured_voltages::Vector{Float64}
    measured_angles::Vector{Float64}
    measured_power_flows::Vector{Float64}
    measured_loads::Vector{Float64}
    
    # PMU/SCADA measurements
    line_flow_measurements::Vector{Float64}
    generator_output_measurements::Vector{Float64}
    
    # External forecasts
    load_forecasts::Vector{Float64}
    renewable_forecasts::Vector{Float64}
    
    # Topology observations
    line_status_observations::Vector{Bool}
    
    # Measurement uncertainty
    measurement_noise::Dict{String, Float64}
end

# POMDP Interface Implementation
POMDPs.discount(pomdp::PowerLASCOPFPOMDP) = pomdp.discount_factor
POMDPs.isterminal(pomdp::PowerLASCOPFPOMDP, s::PowerSystemState) = s.time_step >= pomdp.horizon

function POMDPs.actions(pomdp::PowerLASCOPFPOMDP)
    # Generate action space based on system components
    n_gens = length(pomdp.generators)
    n_lines = length(pomdp.transmission_lines)
    n_loads = length(pomdp.loads)
    
    # This would typically be discretized for practical implementation
    return [PowerSystemAction(
        zeros(n_gens),      # generator setpoints
        trues(n_lines),     # line switching (all closed initially)
        zeros(n_loads),     # load shedding
        zeros(n_gens)       # reserves
    )]
end

function POMDPs.observations(pomdp::PowerLASCOPFPOMDP)
    # Generate observation space
    n_nodes = length(pomdp.nodes)
    n_lines = length(pomdp.transmission_lines)
    n_gens = length(pomdp.generators)
    n_loads = length(pomdp.loads)
    
    return [PowerSystemObservation(
        zeros(n_nodes),     # measured voltages
        zeros(n_nodes),     # measured angles
        zeros(n_lines),     # measured power flows
        zeros(n_loads),     # measured loads
        zeros(n_lines),     # line flow measurements
        zeros(n_gens),      # generator measurements
        zeros(n_loads),     # load forecasts
        zeros(n_gens),      # renewable forecasts
        trues(n_lines),     # line status
        Dict{String, Float64}()  # measurement noise
    )]
end

"""
Transition model - evolve system state based on action and uncertainties
"""
function POMDPs.transition(pomdp::PowerLASCOPFPOMDP, s::PowerSystemState, a::PowerSystemAction)
    # Create new state
    new_line_status = copy(s.line_status)
    
    # Apply line switching actions
    for (i, switch_action) in enumerate(a.line_switching_actions)
        if !switch_action && s.line_status[i]  # Opening a line
            new_line_status[i] = false
        elseif switch_action && !s.line_status[i]  # Closing a line
            new_line_status[i] = true
        end
    end
    
    # Evolve uncertain parameters
    new_load_demands = s.load_demands .+ rand.(Normal(0, 0.05), length(s.load_demands))
    new_renewable_forecasts = s.renewable_forecasts .+ rand.(Normal(0, 0.1), length(s.renewable_forecasts))
    
    # Random line failures
    for (i, line) in enumerate(pomdp.transmission_lines)
        failure_prob = pomdp.topology_uncertainty[string(line.transl_id)]
        if rand() < failure_prob
            new_line_status[i] = false
        end
    end
    
    # Solve power flow to get new operational state
    new_gen_outputs, new_voltages, new_angles = solve_power_flow(
        pomdp, new_line_status, new_load_demands, a.generator_setpoints
    )
    
    # Update beliefs
    new_beliefs = update_parameter_beliefs(s.parameter_beliefs, new_load_demands, new_renewable_forecasts)
    
    new_state = PowerSystemState(
        new_line_status,
        new_load_demands,
        new_renewable_forecasts,
        s.line_capacities,
        new_gen_outputs,
        new_voltages,
        new_angles,
        s.time_step + 1,
        s.scenario_id,
        new_beliefs
    )
    
    return Deterministic(new_state)
end

"""
Observation model - generate observations from true state with measurement noise
"""
function POMDPs.observation(pomdp::PowerLASCOPFPOMDP, a::PowerSystemAction, sp::PowerSystemState)
    # Add measurement noise
    voltage_noise = 0.01
    angle_noise = 0.005
    flow_noise = 0.02
    
    measured_voltages = sp.node_voltages .+ randn(length(sp.node_voltages)) * voltage_noise
    measured_angles = sp.node_angles .+ randn(length(sp.node_angles)) * angle_noise
    
    # Calculate power flows with noise
    measured_flows = calculate_line_flows(pomdp, sp) .+ randn(length(pomdp.transmission_lines)) * flow_noise
    
    obs = PowerSystemObservation(
        measured_voltages,
        measured_angles,
        measured_flows,
        sp.load_demands .+ randn(length(sp.load_demands)) * 0.01,
        measured_flows,
        sp.generator_outputs .+ randn(length(sp.generator_outputs)) * 0.01,
        sp.load_demands,
        sp.renewable_forecasts,
        sp.line_status,
        Dict("voltage" => voltage_noise, "angle" => angle_noise, "flow" => flow_noise)
    )
    
    return Deterministic(obs)
end

"""
Reward function - based on economic dispatch, reliability, and constraint violations
"""
function POMDPs.reward(pomdp::PowerLASCOPFPOMDP, s::PowerSystemState, a::PowerSystemAction, sp::PowerSystemState)
    reward = 0.0
    
    # Generation cost
    gen_cost = calculate_generation_cost(pomdp, a.generator_setpoints)
    reward -= pomdp.generation_cost_weight * gen_cost
    
    # Load shedding penalty
    load_shed_penalty = sum(a.load_shedding) * pomdp.load_shedding_penalty
    reward -= load_shed_penalty
    
    # Reliability reward (negative penalty for line failures)
    reliability_bonus = sum(sp.line_status) * pomdp.reliability_weight
    reward += reliability_bonus
    
    # Constraint violation penalties
    voltage_violations = sum(max.(0, abs.(sp.node_voltages .- 1.0) .- 0.05)) * 1000
    reward -= voltage_violations
    
    # Line flow violations
    flow_violations = calculate_flow_violations(pomdp, sp)
    reward -= flow_violations * 500
    
    return reward
end
