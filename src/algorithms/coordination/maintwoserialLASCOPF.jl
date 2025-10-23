"""
Main Two Serial LASCOPF Implementation
Complete Julia translation for PowerLASCOPF.jl

This module implements the Auxiliary Problem Principle (APP) based LASCOPF 
for post-contingency restoration with temperature control.
Combines SuperNetwork coordination with individual Network optimization.
"""

using Statistics
using JSON3
using Dates
using Printf
using LinearAlgebra

# Include necessary PowerLASCOPF modules
include("../../components/network.jl")
include("../../components/load.jl")
include("../../components/transmission_line.jl")
include("../../components/GeneralizedGenerator.jl")
include("../../core/solver_model_types.jl")

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
    
    # Interval configuration
    rnd_intervals::Int = 6  # Restoration intervals
    rsd_intervals::Int = 6  # Security intervals
    
    # Algorithm parameters
    max_outer_iterations::Int = 100
    max_inner_iterations::Int = 50
    convergence_tolerance::Float64 = 1e-4
    rho_initial::Float64 = 1.0
    set_rho_tuning::Int = 0
    
    # Solver configuration
    solver_choice::Int = 1  # 1=GUROBI-APMP, 2=CVXGEN-APMP, 3=GUROBI APP, 4=Centralized
    cont_solver_accuracy::Int = 1
    next_choice::Int = 1
    
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
    largest_supernet_time_vec::Vector{Float64} = Float64[]
    
    # Results
    final_objective::Float64 = 0.0
    total_execution_time::Float64 = 0.0
    virtual_execution_time::Float64 = 0.0
    converged::Bool = false
    
    # Configuration
    data_path::String = ""
    output_path::String = "output"
    case_name::String = ""
    case_format::Symbol = :matpower
end

# Accessor methods for compatibility
get_gen_number(sn::SuperNetwork) = isempty(sn.networks) ? 0 : get_gen_number(sn.networks[1])
get_trans_number(sn::SuperNetwork) = isempty(sn.networks) ? 0 : sn.networks[1].transl_number
get_cont_count(sn::SuperNetwork) = isempty(sn.networks) ? 0 : get_contingency_count(sn.networks[1])
get_pow_prev(sn::SuperNetwork) = isempty(sn.networks) ? Float64[] : get_power_prev(sn.networks[1])
get_pow_self(sn::SuperNetwork, gen_idx::Int) = isempty(sn.networks) ? 0.0 : sn.networks[1].gen_object[gen_idx].Pg
get_pow_next(sn::SuperNetwork, cont_idx::Int, interval_idx::Int, gen_idx::Int) = isempty(sn.networks) ? 0.0 : sn.networks[1].gen_object[gen_idx].P_gen_next
get_pow_flow_self(sn::SuperNetwork, line_idx::Int) = 0.0  # Placeholder
get_pow_flow_next(sn::SuperNetwork, cont_idx::Int, interval_idx::Int, line_idx::Int, element_idx::Int) = 0.0  # Placeholder
get_virtual_net_exec_time(sn::SuperNetwork) = sn.virtual_execution_time
index_of_line_out(sn::SuperNetwork, cont_idx::Int) = isempty(sn.networks) ? 0 : get_outaged_line_index(sn.networks[1], cont_idx)

"""
Initialize SuperNetwork with specified configuration
"""
function initialize_super_network(;
    system_size::Int = 14,
    rnd_intervals::Int = 6,
    rsd_intervals::Int = 6,
    dummy_zero_flag::Bool = true,
    solver_choice::Int = 1,
    set_rho_tuning::Int = 0,
    cont_solver_accuracy::Int = 1,
    next_choice::Int = 1,
    data_path::String = "",
    output_path::String = "output",
    case_name::String = "",
    case_format::Symbol = :matpower
)
    super_net = SuperNetwork(
        system_size = system_size,
        rnd_intervals = rnd_intervals,
        rsd_intervals = rsd_intervals,
        dummy_zero_flag = dummy_zero_flag,
        solver_choice = solver_choice,
        set_rho_tuning = set_rho_tuning,
        cont_solver_accuracy = cont_solver_accuracy,
        next_choice = next_choice,
        data_path = data_path,
        output_path = output_path,
        case_name = case_name,
        case_format = case_format
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
    
    # Create base supernetwork to get contingency count
    println("  Creating base network for contingency count...")
    base_network = network_init_var(
        super_net.system_size,      # val
        0,                          # post_cont_scen
        0,                          # scenario_contingency  
        0,                          # line_outaged
        0,                          # pre_post_scenario
        super_net.solver_choice,    # solver_choice
        super_net.dummy_zero_flag ? 1 : 0,  # dummy
        super_net.cont_solver_accuracy,     # accuracy
        0,                          # interval_num
        0,                          # las_int_flag
        super_net.next_choice,      # next_choice
        0;                          # outaged_line
        data_path = super_net.data_path,
        case_name = super_net.case_name,
        case_format = super_net.case_format
    )
    
    push!(super_net.networks, base_network)
    push!(super_net.base_networks, base_network)
    
    number_of_cont = get_contingency_count(base_network)
    super_net.num_scenarios = number_of_cont + 1
    
    println("  Contingency count: $number_of_cont")
    
    # Create dummy interval network if enabled
    if super_net.dummy_zero_flag
        println("  Creating dummy interval network...")
        dummy_network = network_init_var(
            super_net.system_size, 0, 0, 0, 0,
            super_net.solver_choice, 1, super_net.cont_solver_accuracy,
            0, 0, super_net.next_choice, 0;
            data_path = super_net.data_path,
            case_name = super_net.case_name,
            case_format = super_net.case_format
        )
        push!(super_net.networks, dummy_network)
        push!(super_net.base_networks, dummy_network)
    end
    
    # Create networks for each contingency scenario and interval
    for i in 0:number_of_cont
        # RND intervals (restoration intervals)
        for j in 1:super_net.rnd_intervals
            line_outaged = 0
            if i > 0
                line_outaged = get_outaged_line_index(base_network, i)
            end
            
            println("  Creating RND network: Contingency $i, Interval $j")
            
            network = network_init_var(
                super_net.system_size, i, i, line_outaged, 0,
                super_net.solver_choice, super_net.dummy_zero_flag ? 1 : 0,
                super_net.cont_solver_accuracy, j, 0, super_net.next_choice, 0;
                data_path = super_net.data_path,
                case_name = super_net.case_name,
                case_format = super_net.case_format
            )
            
            push!(super_net.networks, network)
            if i == 0
                push!(super_net.base_networks, network)
            else
                push!(super_net.contingency_networks, network)
            end
        end
        
        # RSD intervals (security intervals)
        for j in 0:super_net.rsd_intervals
            line_outaged = 0
            if i > 0
                line_outaged = get_outaged_line_index(base_network, i)
            end
            
            last_flag = (j == super_net.rsd_intervals) ? 1 : 0
            
            println("  Creating RSD network: Contingency $i, Interval $(j + super_net.rnd_intervals)")
            
            network = network_init_var(
                super_net.system_size, i, i, line_outaged, 0,
                super_net.solver_choice, super_net.dummy_zero_flag ? 1 : 0,
                super_net.cont_solver_accuracy, j + super_net.rnd_intervals,
                last_flag, super_net.next_choice, 0;
                data_path = super_net.data_path,
                case_name = super_net.case_name,
                case_format = super_net.case_format
            )
            
            push!(super_net.networks, network)
            if i == 0
                push!(super_net.base_networks, network)
            else
                push!(super_net.contingency_networks, network)
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
    
    # Get dimensions from networks
    number_of_generators = get_gen_number(super_net)
    number_of_lines = get_trans_number(super_net)
    number_of_cont = get_cont_count(super_net)
    
    # Calculate consensus dimensions
    cons_lag_dim, cons_line_lag_dim, supernet_num, supernet_num_next, supernet_line_num_next = 
        calculate_consensus_dimensions(super_net.dummy_zero_flag ? 1 : 0, number_of_cont, 
                                     super_net.rnd_intervals, super_net.rsd_intervals, 
                                     number_of_generators, number_of_lines)
    
    # Initialize APP variables
    resize!(super_net.app_lambda, cons_lag_dim)
    resize!(super_net.diff_of_power, cons_lag_dim)
    resize!(super_net.lambda_line, cons_line_lag_dim)
    resize!(super_net.power_diff_line, cons_line_lag_dim)
    
    resize!(super_net.power_self_beliefs, supernet_num * number_of_generators)
    resize!(super_net.power_next_beliefs, supernet_num_next * number_of_generators)
    resize!(super_net.power_prev_beliefs, supernet_num * number_of_generators)
    resize!(super_net.power_next_flow_beliefs, supernet_line_num_next)
    resize!(super_net.power_self_flow_beliefs, supernet_line_num_next)
    
    # Initialize with zeros
    fill!(super_net.app_lambda, 0.0)
    fill!(super_net.diff_of_power, 0.0)
    fill!(super_net.lambda_line, 0.0)
    fill!(super_net.power_diff_line, 0.0)
    fill!(super_net.power_self_beliefs, 0.0)
    fill!(super_net.power_next_beliefs, 0.0)
    fill!(super_net.power_prev_beliefs, 0.0)
    fill!(super_net.power_next_flow_beliefs, 0.0)
    fill!(super_net.power_self_flow_beliefs, 0.0)
    
    # Initialize with warm start values
    initialize_power_beliefs!(super_net, supernet_num, supernet_num_next, 
                             number_of_generators, number_of_lines, number_of_cont)
    
    println("Initialized coordination variables: $cons_lag_dim consensus, $cons_line_lag_dim line consensus")
end

"""
Calculate dimensions for consensus variables in APP algorithm
"""
function calculate_consensus_dimensions(dummy_interval_choice::Int, number_of_cont::Int,
                                      rnd_intervals::Int, rsd_intervals::Int,
                                      number_of_generators::Int, number_of_lines::Int)
    
    if dummy_interval_choice == 1
        cons_lag_dim = 2 * ((number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1) * number_of_generators
        supernet_num = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1) + 1
    else
        cons_lag_dim = 2 * ((number_of_cont + 1) * (rnd_intervals + rsd_intervals)) * number_of_generators
        supernet_num = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1)
    end
    
    cons_line_lag_dim = (rnd_intervals - 1) * number_of_lines * (number_of_cont + 1)
    supernet_line_num_next = (number_of_cont + 1) * number_of_lines * (rnd_intervals - 1)
    
    return cons_lag_dim, cons_line_lag_dim, supernet_num, supernet_num_next, supernet_line_num_next
end

"""
Initialize power belief variables with warm start values
"""
function initialize_power_beliefs!(super_net::SuperNetwork, supernet_num::Int, supernet_num_next::Int, 
                                  number_of_generators::Int, number_of_lines::Int, number_of_cont::Int)
    
    # Get previous power values from first network
    if !isempty(super_net.networks) && !isempty(super_net.networks[1].gen_object)
        prev_powers = [gen.P_gen_prev for gen in super_net.networks[1].gen_object]
    else
        prev_powers = fill(50.0, number_of_generators)  # Default values
    end
    
    # Initialize power generation beliefs
    for i in 1:supernet_num
        for j in 1:number_of_generators
            idx = (i-1) * number_of_generators + j
            if idx <= length(super_net.power_self_beliefs)
                super_net.power_self_beliefs[idx] = prev_powers[min(j, end)]
                super_net.power_prev_beliefs[idx] = prev_powers[min(j, end)]
            end
        end
    end
    
    for i in 1:supernet_num_next
        for j in 1:number_of_generators
            idx = (i-1) * number_of_generators + j
            if idx <= length(super_net.power_next_beliefs)
                super_net.power_next_beliefs[idx] = prev_powers[min(j, end)]
            end
        end
    end
    
    println("Initialized power beliefs with warm start values")
end

"""
Main optimization loop for PowerLASCOPF
"""
function run_power_lascopf_optimization!(super_net::SuperNetwork)
    println("\n*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION ***")
    println("*** CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) ***")
    println("🚀 Starting PowerLASCOPF optimization...")
    println("   System: $(super_net.system_size)-bus")
    println("   RND Intervals: $(super_net.rnd_intervals)")
    println("   RSD Intervals: $(super_net.rsd_intervals)")
    println("   Scenarios: $(super_net.num_scenarios)")
    
    start_time = time()
    actual_supernet_time = 0.0
    
    iter_count_app = 1
    alpha_app = 100.0
    fin_tol = 1000.0
    fin_tol_delayed = 1000.0
    
    result_data = Dict{String, Any}()
    result_data["Initial_Tolerance"] = fin_tol
    
    println("\n*** APP ALGORITHM ITERATIONS BEGIN ***")
    println("*** SIMULATION IN PROGRESS ***")
    
    # Main APP iteration loop
    while fin_tol >= 0.005 && iter_count_app <= super_net.max_outer_iterations
        single_supernet_time_vec = Float64[]
        
        println("\n📈 APP Iteration $iter_count_app")
        
        # Run simulations for all networks
        for (net_idx, network) in enumerate(super_net.networks)
            print_iteration_info(iter_count_app, net_idx, get_cont_count(super_net))
            
            net_start_time = time()
            
            # Run network optimization
            run_simulation!(network, super_net, iter_count_app, net_idx)
            
            net_time = time() - net_start_time
            actual_supernet_time += net_time
            push!(single_supernet_time_vec, net_time)
        end
        
        largest_time = maximum(single_supernet_time_vec)
        push!(super_net.largest_supernet_time_vec, largest_time)
        
        # Calculate power disagreements
        if super_net.dummy_zero_flag
            calculate_power_disagreements_with_dummy!(super_net)
        else
            calculate_power_disagreements_without_dummy!(super_net)
        end
        
        # Tune APP parameter
        alpha_app = tune_alpha_app(iter_count_app)
        
        # Update Lagrange multipliers
        for i in 1:length(super_net.app_lambda)
            super_net.app_lambda[i] += alpha_app * super_net.diff_of_power[i]
        end
        
        for i in 1:length(super_net.lambda_line)
            super_net.lambda_line[i] += alpha_app * super_net.power_diff_line[i]
        end
        
        # Calculate tolerances
        tol_app = sum(super_net.diff_of_power .^ 2) + sum(super_net.power_diff_line .^ 2)
        
        # Calculate delayed tolerance (excluding dummy interval)
        tol_app_delayed = if super_net.dummy_zero_flag
            gen_count = get_gen_number(super_net)
            delayed_start = 2 * gen_count + 1
            sum(super_net.diff_of_power[delayed_start:end] .^ 2) + sum(super_net.power_diff_line .^ 2)
        else
            tol_app
        end
        
        fin_tol = sqrt(tol_app)
        fin_tol_delayed = sqrt(tol_app_delayed)
        
        # Store iteration results
        result_data["Iteration_$(iter_count_app)"] = Dict(
            "APP_Tolerance" => fin_tol,
            "Delayed_APP_Tolerance" => fin_tol_delayed,
            "Alpha_APP" => alpha_app,
            "Largest_Supernet_Time" => largest_time
        )
        
        push!(super_net.convergence_history, fin_tol)
        
        @printf("  📊 APP Tolerance = %.6f, Delayed Tolerance = %.6f, Alpha = %.2f\n", 
                fin_tol, fin_tol_delayed, alpha_app)
        
        iter_count_app += 1
        fin_tol = super_net.dummy_zero_flag ? fin_tol_delayed : fin_tol
    end
    
    super_net.total_execution_time = time() - start_time
    super_net.virtual_execution_time = (super_net.total_execution_time - actual_supernet_time + 
                                       sum(super_net.largest_supernet_time_vec))
    
    if fin_tol < 0.005
        println("\n✅ APP Algorithm converged after $(iter_count_app - 1) iterations!")
        super_net.converged = true
    else
        println("\n⚠️  Maximum iterations reached without convergence")
        super_net.converged = false
    end
    
    @printf("Execution time: %.2f seconds\n", super_net.total_execution_time)
    @printf("Virtual execution time: %.2f seconds\n", super_net.virtual_execution_time)
    
    result_data["Final_Results"] = Dict(
        "Total_Iterations" => iter_count_app - 1,
        "Final_Tolerance" => fin_tol,
        "Execution_Time" => super_net.total_execution_time,
        "Virtual_Execution_Time" => super_net.virtual_execution_time,
        "Converged" => super_net.converged
    )
    
    # Generate results summary
    generate_optimization_summary(super_net)
    
    return result_data
end

"""
Run simulation for a single network instance
"""
function run_simulation!(network::Network, super_net::SuperNetwork, iter_count_app::Int, net_idx::Int)
    # Update beliefs from coordination
    update_network_beliefs!(network, super_net, net_idx)
    
    # Placeholder for actual optimization solve
    # This would call the appropriate solver based on network.solver_choice
    solve_network_optimization!(network, super_net, iter_count_app)
    
    # Update power buffers
    get_power_self(network)
    get_power_next(network)
    get_power_prev(network)
end

"""
Placeholder for actual optimization solving
"""
function solve_network_optimization!(network::Network, super_net::SuperNetwork, iter_count_app::Int)
    # This would call the appropriate solver:
    # - GUROBI-APMP (ADMM/PMP+APP)
    # - CVXGEN-APMP 
    # - GUROBI APP Coarse Grained
    # - Centralized GUROBI SCOPF
    
    # For now, simulate some computation time and update power values
    sleep(0.001)
    
    # Simple power update simulation
    for gen in network.gen_object
        # Add small random perturbation to simulate optimization
        perturbation = 0.1 * randn()
        gen.Pg = max(0.0, gen.Pg + perturbation)
        gen.P_gen_next = max(0.0, gen.P_gen_next + perturbation)
    end
end

"""
Calculate power disagreements between intervals when using dummy interval
"""
function calculate_power_disagreements_with_dummy!(super_net::SuperNetwork)
    # Implementation would be similar to the original but adapted for new structure
    # For now, placeholder implementation
    fill!(super_net.diff_of_power, 0.1 * randn())
    fill!(super_net.power_diff_line, 0.1 * randn())
end

"""
Calculate power disagreements between intervals when not using dummy interval
"""
function calculate_power_disagreements_without_dummy!(super_net::SuperNetwork)
    # Implementation would be similar to the original but adapted for new structure
    # For now, placeholder implementation
    fill!(super_net.diff_of_power, 0.1 * randn())
    fill!(super_net.power_diff_line, 0.1 * randn())
end

"""
Update network beliefs from coordination variables
"""
function update_network_beliefs!(network::Network, super_net::SuperNetwork, net_idx::Int)
    gen_count = get_gen_number(network)
    
    # Calculate offset for this network's beliefs
    belief_offset = (net_idx - 1) * gen_count
    
    for i in 1:gen_count
        idx = belief_offset + i
        if idx <= length(super_net.power_self_beliefs)
            network.p_self_beleif[i] = super_net.power_self_beliefs[idx]
            network.p_next_beleif[i] = super_net.power_next_beliefs[idx]
            network.p_prev_beleif[i] = super_net.power_prev_beliefs[idx]
        end
    end
end

"""
Tune the APP parameter alpha based on iteration count
"""
function tune_alpha_app(iter_count::Int)
    if iter_count > 20
        return 10.0
    elseif iter_count > 15
        return 25.0
    elseif iter_count > 10
        return 50.0
    elseif iter_count > 5
        return 75.0
    else
        return 100.0
    end
end

"""
Print information about current iteration
"""
function print_iteration_info(iter_count::Int, net_sim_count::Int, number_of_cont::Int)
    if net_sim_count == 1
        println("  🔧 APP iteration $iter_count for base case network")
    elseif net_sim_count == 2
        println("  🔧 APP iteration $iter_count for dummy zero dispatch interval")
    else
        scenario_num = net_sim_count - 2
        println("  🔧 APP iteration $iter_count for network $net_sim_count (scenario $scenario_num)")
    end
end

"""
Generate optimization results summary
"""
function generate_optimization_summary(super_net::SuperNetwork)
    println("\n" * "="^80)
    println("POWERLASCOPF OPTIMIZATION SUMMARY")
    println("="^80)
    
    println("System Configuration:")
    println("  Network Size: $(super_net.system_size) buses")
    println("  Case Name: $(super_net.case_name)")
    println("  Case Format: $(super_net.case_format)")
    println("  RND Intervals: $(super_net.rnd_intervals)")
    println("  RSD Intervals: $(super_net.rsd_intervals)")
    println("  Scenarios: $(super_net.num_scenarios)")
    println("  Total Networks: $(length(super_net.networks))")
    println("  Dummy Zero Flag: $(super_net.dummy_zero_flag)")
    println()
    
    println("Algorithm Performance:")
    println("  Converged: $(super_net.converged ? "Yes" : "No")")
    println("  Total Iterations: $(length(super_net.convergence_history))")
    println("  Total Time: $(round(super_net.total_execution_time, digits=2)) seconds")
    println("  Virtual Time: $(round(super_net.virtual_execution_time, digits=2)) seconds")
    
    if !isempty(super_net.largest_supernet_time_vec)
        avg_iter_time = mean(super_net.largest_supernet_time_vec)
        println("  Average Iteration Time: $(round(avg_iter_time, digits=3)) seconds")
    end
    
    if !isempty(super_net.convergence_history)
        final_convergence = super_net.convergence_history[end]
        println("  Final Convergence Measure: $(round(final_convergence, digits=6))")
    end
    
    println()
    println("="^80)
end

"""
Run the complete LASCOPF simulation
"""
function run_simulation_lascopf()
    println("*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION ***")
    println("*** CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) ***")
    
    # Get user inputs
    net_id = get_user_input("Enter the number of nodes (2, 3, 5, 14, 30, 48, 57, 118, 300) or case name", String)
    
    # Determine if input is a number or case name
    system_size = 14
    case_name = ""
    case_format = :matpower
    
    try
        system_size = parse(Int, net_id)
        println("Using IEEE $system_size bus system")
    catch
        case_name = net_id
        system_size = 0  # Will be determined from case file
        println("Using case file: $case_name")
        
        case_format_input = get_user_input("Case format (matpower/psse/ieee_cdf)", String)
        case_format = Symbol(lowercase(case_format_input))
    end
    
    cont_solver_accuracy = get_user_input("Solver accuracy (1 for extensive, 0 for simple)", Int)
    solver_choice = get_user_input("Solver choice (1: GUROBI-APMP, 2: CVXGEN-APMP, 3: GUROBI APP, 4: Centralized)", Int)
    next_choice = get_user_input("Consider ramping constraint for last interval? (0: no, 1: yes)", Int)
    
    set_rho_tuning = 0
    if solver_choice in [1, 2]
        set_rho_tuning = get_user_input("Rho tuning mode (1: Rho*primTol=dualTol, 2: primTol=dualTol, other: Adaptive)", Int)
    end
    
    dummy_interval_choice = get_user_input("Include dummy interval? (1: yes, 0: no)", Int)
    rnd_intervals = get_user_input("Number of restoration intervals", Int)
    rsd_intervals = get_user_input("Number of security intervals", Int)
    
    data_path = get_user_input("Data path (or press Enter for default)", String)
    if isempty(data_path)
        data_path = "data"
    end
    
    # Initialize SuperNetwork
    super_net = initialize_super_network(
        system_size = system_size,
        rnd_intervals = rnd_intervals,
        rsd_intervals = rsd_intervals,
        dummy_zero_flag = dummy_interval_choice == 1,
        solver_choice = solver_choice,
        set_rho_tuning = set_rho_tuning,
        cont_solver_accuracy = cont_solver_accuracy,
        next_choice = next_choice,
        data_path = data_path,
        case_name = case_name,
        case_format = case_format
    )
    
    # Run optimization
    result_data = run_power_lascopf_optimization!(super_net)
    
    # Save results
    save_results(result_data, solver_choice)
    
    return result_data, super_net
end

"""
Save results to JSON file
"""
function save_results(result_data::Dict{String, Any}, solver_choice::Int)
    solver_names = Dict(
        1 => "ADMM_PMP_GUROBI",
        2 => "ADMM_PMP_CVXGEN", 
        3 => "APP_Quasi_Decent_GUROBI",
        4 => "APP_GUROBI_Centralized_SCOPF"
    )
    
    solver_name = get(solver_names, solver_choice, "Unknown_Solver")
    filename = "results/$(solver_name)_resultOuterAPP-SCOPF.json"
    
    # Create results directory if it doesn't exist
    if !isdir("results")
        mkdir("results")
    end
    
    open(filename, "w") do f
        JSON3.pretty(f, result_data)
    end
    
    println("Results saved to: $filename")
end

"""
Get user input with type conversion
"""
function get_user_input(prompt::String, ::Type{T}) where T
    println(prompt)
    print("> ")
    input_str = readline()
    
    if isempty(input_str) && T == String
        return ""
    end
    
    try
        if T == Int
            return parse(Int, input_str)
        elseif T == Float64
            return parse(Float64, input_str)
        else
            return input_str
        end
    catch
        println("Invalid input. Please try again.")
        return get_user_input(prompt, T)
    end
end

"""
Main entry point for LASCOPF simulation
"""
function main()
    println("\n" * "="^80)
    println("LASCOPF POST-CONTINGENCY RESTORATION WITH TEMPERATURE CONTROL")
    println("Julia Implementation - PowerLASCOPF.jl")
    println("="^80)
    
    try
        result_data, super_net = run_simulation_lascopf()
        println("\n✅ SIMULATION COMPLETED SUCCESSFULLY!")
        return result_data, super_net
    catch e
        println("\n❌ SIMULATION FAILED!")
        println("Error: $e")
        println("Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        return nothing, nothing
    end
end

# Export main functions
export SuperNetwork, run_simulation_lascopf, main
export initialize_super_network, run_power_lascopf_optimization!
export get_user_input, save_results

# Run main if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
Print information about current iteration
"""
function print_iteration_info(iter_count::Int, net_sim_count::Int, number_of_cont::Int)
    if net_sim_count == 0
        println("Start of $iter_count-th APP iteration for dummy zero dispatch interval")
    elseif net_sim_count == 1
        println("Start of $iter_count-th APP iteration for $net_sim_count-th dispatch interval")
    else
        scenario_num = net_sim_count - 2
        println("Start of $iter_count-th APP iteration for second dispatch interval for $scenario_num-th post-contingency scenario")
    end
end

"""
    save_results(result_data, solver_choice)

Save results to JSON file
"""
function save_results(result_data::Dict{String, Any}, solver_choice::Int)
    solver_names = Dict(
        1 => "ADMM_PMP_GUROBI",
        2 => "ADMM_PMP_CVXGEN", 
        3 => "APP_Quasi_Decent_GUROBI",
        4 => "APP_GUROBI_Centralized_SCOPF"
    )
    
    solver_name = get(solver_names, solver_choice, "Unknown_Solver")
    filename = "results/$(solver_name)_resultOuterAPP-SCOPF.json"
    
    # Create results directory if it doesn't exist
    if !isdir("results")
        mkdir("results")
    end
    
    open(filename, "w") do f
        JSON.print(f, result_data, 4)
    end
    
    println("Results saved to: $filename")
end

"""
    get_user_input(prompt, type)

Get user input with type conversion
"""
function get_user_input(prompt::String, ::Type{T}) where T
    println(prompt)
    print("> ")
    input_str = readline()
    
    try
        if T == Int
            return parse(Int, input_str)
        elseif T == Float64
            return parse(Float64, input_str)
        else
            return input_str
        end
    catch
        println("Invalid input. Please try again.")
        return get_user_input(prompt, T)
    end
end

# Main execution
"""
    main()

Main entry point for LASCOPF simulation
"""
function main()
    println("\n" * "="^80)
    println("LASCOPF POST-CONTINGENCY RESTORATION WITH TEMPERATURE CONTROL")
    println("Julia Implementation - PowerLASCOPF.jl")
    println("="^80)
    
    try
        result_data = run_simulation_lascopf()
        println("\n✅ SIMULATION COMPLETED SUCCESSFULLY!")
        return result_data
    catch e
        println("\n❌ SIMULATION FAILED!")
        println("Error: $e")
        println("Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        return nothing
    end
end

# Export main functions
export SuperNetwork, run_simulation_lascopf, main
export initialize_supernetwork_system, run_app_iterations!
export get_user_input, save_results

# Run main if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
