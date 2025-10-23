"""
Main coordination module for PowerLASCOPF
Handles multi-interval, multi-scenario optimization with ADMM/APP coordination
"""

using LinearAlgebra
using Statistics
using Printf

# Include necessary components
include("../components/network.jl")
include("../algorithms/admm_algorithm.jl")
include("../algorithms/app_algorithm.jl")

"""
SuperNetwork structure for coordinating multiple Network instances
Handles temporal and scenario coordination in PowerLASCOPF
"""
@kwdef mutable struct SuperNetwork
    # Network instances
    networks::Vector{Network} = Network[]
    base_networks::Vector{Network} = Network[]
    contingency_networks::Vector{Network} = Network[]
    
    # System parameters
    system_size::Int = 14
    num_intervals::Int = 2
    num_scenarios::Int = 1
    dummy_zero_flag::Bool = true
    
    # Algorithm parameters
    max_outer_iterations::Int = 100
    max_inner_iterations::Int = 50
    convergence_tolerance::Float64 = 1e-4
    rho_initial::Float64 = 1.0
    
    # Coordination variables
    lambda_outer::Vector{Float64} = Float64[]
    power_diff_outer::Vector{Float64} = Float64[]
    power_self_beliefs::Vector{Float64} = Float64[]
    power_next_beliefs::Vector{Float64} = Float64[]
    power_prev_beliefs::Vector{Float64} = Float64[]
    
    # APP coordination
    app_lambda::Vector{Float64} = Float64[]
    diff_of_power::Vector{Float64} = Float64[]
    
    # Line flow coordination
    lambda_line::Vector{Float64} = Float64[]
    power_diff_line::Vector{Float64} = Float64[]
    power_self_flow_beliefs::Vector{Float64} = Float64[]
    power_next_flow_beliefs::Vector{Float64} = Float64[]
    
    # Performance tracking
    outer_iteration_times::Vector{Float64} = Float64[]
    inner_iteration_times::Vector{Float64} = Float64[]
    convergence_history::Vector{Float64} = Float64[]
    objective_history::Vector{Float64} = Float64[]
    
    # Results
    final_objective::Float64 = 0.0
    total_execution_time::Float64 = 0.0
    converged::Bool = false
    
    # Configuration
    solver_choice::Int = 1  # 1=IPOPT, 2=Gurobi
    data_path::String = ""
    output_path::String = "output"
end

"""
Initialize SuperNetwork with specified configuration
"""
function initialize_super_network(;
    system_size::Int = 14,
    num_intervals::Int = 2,
    num_scenarios::Int = 1,
    dummy_zero_flag::Bool = true,
    solver_choice::Int = 1,
    data_path::String = "",
    output_path::String = "output"
)
    super_net = SuperNetwork(
        system_size = system_size,
        num_intervals = num_intervals,
        num_scenarios = num_scenarios,
        dummy_zero_flag = dummy_zero_flag,
        solver_choice = solver_choice,
        data_path = data_path,
        output_path = output_path
    )
    
    # Create network instances
    create_network_instances!(super_net)
    
    # Initialize coordination variables
    initialize_coordination_variables!(super_net)
    
    return super_net
end

"""
Create all required network instances for intervals and scenarios
"""
function create_network_instances!(super_net::SuperNetwork)
    println("Creating network instances...")
    
    empty!(super_net.networks)
    empty!(super_net.base_networks)
    empty!(super_net.contingency_networks)
    
    network_id = 1
    
    # Create base case networks for each interval
    for interval in 0:(super_net.num_intervals-1)
        for scenario in 0:(super_net.num_scenarios-1)
            println("  Creating base network: Interval $interval, Scenario $scenario")
            
            network = network_init_var(
                super_net.system_size,      # val
                0,                          # postContScen
                scenario,                   # scenarioContingency  
                0,                          # lineOutaged
                0,                          # prePostScenario
                super_net.solver_choice,    # solverChoice
                super_net.dummy_zero_flag ? 1 : 0,  # dummy
                1,                          # accuracy
                interval,                   # intervalNum
                interval == super_net.num_intervals-1 ? 1 : 0,  # lasIntFlag
                1,                          # nextChoice
                0;                          # outagedLine
                data_path = super_net.data_path
            )
            
            push!(super_net.networks, network)
            push!(super_net.base_networks, network)
            network_id += 1
        end
    end
    
    # Create contingency networks if scenarios > 1
    if super_net.num_scenarios > 1
        # Get contingency count from first network
        contingency_count = super_net.base_networks[1].contingencyCount
        
        for interval in 0:(super_net.num_intervals-1)
            for cont_scenario in 1:contingency_count
                println("  Creating contingency network: Interval $interval, Contingency $cont_scenario")
                
                network = network_init_var(
                    super_net.system_size,
                    cont_scenario,              # postContScen
                    cont_scenario,              # scenarioContingency
                    0,                          # lineOutaged
                    0,                          # prePostScenario
                    super_net.solver_choice,
                    super_net.dummy_zero_flag ? 1 : 0,
                    1,
                    interval,
                    interval == super_net.num_intervals-1 ? 1 : 0,
                    1,
                    0;
                    data_path = super_net.data_path
                )
                
                push!(super_net.networks, network)
                push!(super_net.contingency_networks, network)
                network_id += 1
            end
        end
    end
    
    println("Created $(length(super_net.networks)) network instances")
end

"""
Initialize coordination variables for ADMM/APP algorithms
"""
function initialize_coordination_variables!(super_net::SuperNetwork)
    if isempty(super_net.networks)
        error("Networks must be created before initializing coordination variables")
    end
    
    # Get dimensions from first network
    gen_count = super_net.networks[1].genNumber
    total_intervals = super_net.num_intervals
    total_scenarios = length(super_net.networks)
    
    # Outer coordination variables (between intervals)
    coord_size = total_intervals * gen_count * 2  # 2 for current and next
    resize!(super_net.lambda_outer, coord_size)
    resize!(super_net.power_diff_outer, coord_size)
    fill!(super_net.lambda_outer, 0.0)
    fill!(super_net.power_diff_outer, 0.0)
    
    # Power beliefs coordination
    belief_size = total_scenarios * gen_count
    resize!(super_net.power_self_beliefs, belief_size)
    resize!(super_net.power_next_beliefs, belief_size) 
    resize!(super_net.power_prev_beliefs, belief_size)
    fill!(super_net.power_self_beliefs, 0.0)
    fill!(super_net.power_next_beliefs, 0.0)
    fill!(super_net.power_prev_beliefs, 0.0)
    
    # APP coordination (between scenarios)
    app_size = super_net.num_scenarios * gen_count
    resize!(super_net.app_lambda, app_size)
    resize!(super_net.diff_of_power, app_size)
    fill!(super_net.app_lambda, 0.0)
    fill!(super_net.diff_of_power, 0.0)
    
    println("Initialized coordination variables: $coord_size outer, $belief_size beliefs, $app_size APP")
end

"""
Main optimization loop for PowerLASCOPF
"""
function run_power_lascopf_optimization!(super_net::SuperNetwork)
    println("🚀 Starting PowerLASCOPF optimization...")
    println("   System: $(super_net.system_size)-bus")
    println("   Intervals: $(super_net.num_intervals)")
    println("   Scenarios: $(super_net.num_scenarios)")
    
    start_time = time()
    
    # Outer APP iterations (temporal coordination)
    for outer_iter in 1:super_net.max_outer_iterations
        println("\n📈 Outer Iteration $outer_iter")
        outer_start = time()
        
        # Inner ADMM iterations for each scenario
        scenario_objectives = Float64[]
        
        for (net_idx, network) in enumerate(super_net.networks)
            println("  🔧 Solving Network $net_idx (Interval $(network.intervalID), Scenario $(network.scenarioIndex))")
            
            # Run ADMM optimization for this network
            objective = run_network_admm_optimization!(
                network, 
                super_net,
                outer_iter,
                net_idx
            )
            
            push!(scenario_objectives, objective)
        end
        
        # Update coordination variables
        update_coordination_variables!(super_net, outer_iter)
        
        # Check convergence
        convergence_measure = calculate_convergence_measure(super_net)
        push!(super_net.convergence_history, convergence_measure)
        
        total_objective = sum(scenario_objectives)
        push!(super_net.objective_history, total_objective)
        
        outer_time = time() - outer_start
        push!(super_net.outer_iteration_times, outer_time)
        
        @printf("  📊 Objective: %.2f, Convergence: %.6f, Time: %.2fs\n", 
                total_objective, convergence_measure, outer_time)
        
        # Check for convergence
        if convergence_measure < super_net.convergence_tolerance
            println("✅ Converged after $outer_iter iterations!")
            super_net.converged = true
            super_net.final_objective = total_objective
            break
        end
    end
    
    super_net.total_execution_time = time() - start_time
    
    if !super_net.converged
        println("⚠️  Maximum iterations reached without convergence")
        super_net.final_objective = isempty(super_net.objective_history) ? 0.0 : super_net.objective_history[end]
    end
    
    # Generate results summary
    generate_optimization_summary(super_net)
    
    return super_net.converged
end

"""
Run ADMM optimization for a single network
"""
function run_network_admm_optimization!(
    network::Network, 
    super_net::SuperNetwork,
    outer_iter::Int,
    net_idx::Int
)
    # Update beliefs from coordination
    update_network_beliefs!(network, super_net, net_idx)
    
    # Run ADMM iterations
    max_admm_iter = 100
    admm_tolerance = 1e-3
    
    # ...existing code for ADMM implementation...
    # This would include the main ADMM loop from the original code
    
    # For now, return a placeholder objective
    objective = 1000.0 + 100.0 * randn()  # Placeholder
    
    # Update power buffers
    get_power_self(network)
    get_power_next(network) 
    get_power_prev(network)
    
    return objective
end

"""
Update network beliefs from coordination variables
"""
function update_network_beliefs!(network::Network, super_net::SuperNetwork, net_idx::Int)
    gen_count = network.genNumber
    
    # Calculate offset for this network's beliefs
    belief_offset = (net_idx - 1) * gen_count
    
    for i in 1:gen_count
        idx = belief_offset + i
        if idx <= length(super_net.power_self_beliefs)
            network.pSelfBeleif[i] = super_net.power_self_beliefs[idx]
            network.pNextBeleif[i] = super_net.power_next_beliefs[idx]
            network.pPrevBeleif[i] = super_net.power_prev_beliefs[idx]
        end
    end
end

"""
Update coordination variables between iterations
"""
function update_coordination_variables!(super_net::SuperNetwork, iteration::Int)
    # Collect beliefs from all networks
    for (net_idx, network) in enumerate(super_net.networks)
        gen_count = network.genNumber
        belief_offset = (net_idx - 1) * gen_count
        
        # Update power beliefs
        power_self = get_power_self(network)
        power_next = get_power_next(network)
        power_prev = get_power_prev(network)
        
        for i in 1:gen_count
            idx = belief_offset + i
            if idx <= length(super_net.power_self_beliefs)
                super_net.power_self_beliefs[idx] = power_self[i]
                super_net.power_next_beliefs[idx] = power_next[i]
                super_net.power_prev_beliefs[idx] = power_prev[i]
            end
        end
    end
    
    # Update dual variables (simplified)
    step_size = 0.1 / iteration  # Decreasing step size
    
    for i in 1:length(super_net.lambda_outer)
        super_net.lambda_outer[i] += step_size * super_net.power_diff_outer[i]
    end
    
    for i in 1:length(super_net.app_lambda)
        super_net.app_lambda[i] += step_size * super_net.diff_of_power[i]
    end
end

"""
Calculate convergence measure
"""
function calculate_convergence_measure(super_net::SuperNetwork)::Float64
    # Calculate primal residual norm
    primal_residual = norm(super_net.power_diff_outer)
    
    # Calculate dual residual norm (simplified)
    if length(super_net.convergence_history) > 1
        dual_residual = abs(super_net.convergence_history[end] - super_net.convergence_history[end-1])
    else
        dual_residual = primal_residual
    end
    
    return max(primal_residual, dual_residual)
end

"""
Generate optimization results summary
"""
function generate_optimization_summary(super_net::SuperNetwork)
    println("\n" * "="^60)
    println("POWERLASCOPF OPTIMIZATION SUMMARY")
    println("="^60)
    
    println("System Configuration:")
    println("  Network Size: $(super_net.system_size) buses")
    println("  Time Intervals: $(super_net.num_intervals)")
    println("  Scenarios: $(super_net.num_scenarios)")
    println("  Total Networks: $(length(super_net.networks))")
    println()
    
    println("Algorithm Performance:")
    println("  Converged: $(super_net.converged ? "Yes" : "No")")
    println("  Final Objective: \$$(round(super_net.final_objective, digits=2))")
    println("  Total Iterations: $(length(super_net.convergence_history))")
    println("  Total Time: $(round(super_net.total_execution_time, digits=2)) seconds")
    
    if !isempty(super_net.outer_iteration_times)
        avg_iter_time = mean(super_net.outer_iteration_times)
        println("  Average Iteration Time: $(round(avg_iter_time, digits=3)) seconds")
    end
    
    if !isempty(super_net.convergence_history)
        final_convergence = super_net.convergence_history[end]
        println("  Final Convergence Measure: $(round(final_convergence, digits=6))")
    end
    
    println()
    
    # Network-specific results
    println("Network Results:")
    for (i, network) in enumerate(super_net.networks)
        println("  Network $i: Interval $(network.intervalID), Scenario $(network.scenarioIndex)")
        println("    Generators: $(network.genNumber), Load: $(network.loadNumber)")
        
        # Get total generation
        total_gen = sum(gen.Pg for gen in network.genObject) * network.divConvMWPU
        println("    Total Generation: $(round(total_gen, digits=1)) MW")
    end
    
    println("="^60)
end

"""
Save results to files
"""
function save_optimization_results(super_net::SuperNetwork)
    output_dir = super_net.output_path
    mkpath(output_dir)
    
    # Save convergence history
    conv_file = joinpath(output_dir, "convergence_history.txt")
    open(conv_file, "w") do f
        println(f, "Iteration,Convergence,Objective")
        for (i, (conv, obj)) in enumerate(zip(super_net.convergence_history, super_net.objective_history))
            println(f, "$i,$conv,$obj")
        end
    end
    
    # Save final generation results
    gen_file = joinpath(output_dir, "generation_results.txt")
    open(gen_file, "w") do f
        println(f, "Network,Interval,Scenario,Generator,Power_MW")
        for (net_idx, network) in enumerate(super_net.networks)
            for (gen_idx, gen) in enumerate(network.genObject)
                power_mw = gen.Pg * network.divConvMWPU
                println(f, "$net_idx,$(network.intervalID),$(network.scenarioIndex),$gen_idx,$power_mw")
            end
        end
    end
    
    println("Results saved to $output_dir")
end

"""
Main entry point for PowerLASCOPF optimization
"""
function run_power_lascopf(;
    system_size::Int = 14,
    num_intervals::Int = 2, 
    num_scenarios::Int = 1,
    dummy_zero_flag::Bool = true,
    solver_choice::Int = 1,
    data_path::String = "",
    output_path::String = "output",
    save_results::Bool = true
)
    # Initialize SuperNetwork
    super_net = initialize_super_network(
        system_size = system_size,
        num_intervals = num_intervals,
        num_scenarios = num_scenarios,
        dummy_zero_flag = dummy_zero_flag,
        solver_choice = solver_choice,
        data_path = data_path,
        output_path = output_path
    )
    
    # Run optimization
    converged = run_power_lascopf_optimization!(super_net)
    
    # Save results if requested
    if save_results
        save_optimization_results(super_net)
    end
    
    return super_net, converged
end

# Export main functions
export SuperNetwork, initialize_super_network
export run_power_lascopf_optimization!, run_power_lascopf
export save_optimization_results, generate_optimization_summary
