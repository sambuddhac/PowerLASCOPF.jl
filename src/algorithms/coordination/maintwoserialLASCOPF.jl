"""
Main Two Serial LASCOPF Implementation
Complete Julia translation for PowerLASCOPF.jl

This module implements the Auxiliary Problem Principle (APP) based LASCOPF 
for post-contingency restoration with temperature control.
"""

using Statistics
using JSON
using Dates
using Printf

# Include necessary PowerLASCOPF modules
include("../../components/load.jl")
include("../../components/ExtendedThermalGenerator.jl")
include("../../models/solver_models/solver_model_types.jl")

"""
    SuperNetwork

Main supernetwork structure for LASCOPF coordination
"""
mutable struct SuperNetwork
    net_id::Int
    solver_choice::Int
    set_rho_tuning::Int
    last::Int
    next_choice::Int
    dummy_interval_choice::Int
    cont_solver_accuracy::Int
    future_net_vector::Vector{SuperNetwork}
    
    # Additional fields for network state
    contingency_scenario::Int
    dispatch_interval::Int
    line_outaged::Int
    rnd_intervals::Int
    rsd_intervals::Int
    
    # Network components
    generators::Vector{Any}
    loads::Vector{Load}
    transmission_lines::Vector{Any}
    
    # Solution state
    power_self::Vector{Float64}
    power_next::Vector{Float64}
    power_prev::Vector{Float64}
    power_flow_self::Vector{Float64}
    power_flow_next::Vector{Float64}
    
    # Execution time tracking
    virtual_net_exec_time::Float64
    
    # Constructor
    function SuperNetwork(net_id::Int, solver_choice::Int, set_rho_tuning::Int, 
                         contingency_scenario::Int, dispatch_interval::Int, 
                         last::Int, next_choice::Int, dummy_interval_choice::Int,
                         cont_solver_accuracy::Int, line_outaged::Int,
                         rnd_intervals::Int, rsd_intervals::Int)
        
        new(net_id, solver_choice, set_rho_tuning, last, next_choice, 
            dummy_interval_choice, cont_solver_accuracy, SuperNetwork[],
            contingency_scenario, dispatch_interval, line_outaged,
            rnd_intervals, rsd_intervals,
            Any[], Load[], Any[],
            Float64[], Float64[], Float64[], Float64[], Float64[],
            0.0)
    end
end

# Accessor methods for SuperNetwork
get_gen_number(sn::SuperNetwork) = length(sn.generators)
get_trans_number(sn::SuperNetwork) = length(sn.transmission_lines)
get_cont_count(sn::SuperNetwork) = 1  # Placeholder - should be determined from network data
get_pow_prev(sn::SuperNetwork) = sn.power_prev
get_pow_self(sn::SuperNetwork, gen_idx::Int) = sn.power_self[gen_idx]
get_pow_next(sn::SuperNetwork, cont_idx::Int, interval_idx::Int, gen_idx::Int) = sn.power_next[gen_idx]
get_pow_flow_self(sn::SuperNetwork, line_idx::Int) = sn.power_flow_self[line_idx]
get_pow_flow_next(sn::SuperNetwork, cont_idx::Int, interval_idx::Int, line_idx::Int, element_idx::Int) = sn.power_flow_next[line_idx]
get_virtual_net_exec_time(sn::SuperNetwork) = sn.virtual_net_exec_time
index_of_line_out(sn::SuperNetwork, cont_idx::Int) = sn.line_outaged

"""
    initialize_supernetwork_system(net_id::Int, solver_choice::Int, set_rho_tuning::Int,
                                   dummy_interval_choice::Int, cont_solver_accuracy::Int,
                                   next_choice::Int, rnd_intervals::Int, rsd_intervals::Int)

Initialize the supernetwork system with all required intervals and contingency scenarios
"""
function initialize_supernetwork_system(net_id::Int, solver_choice::Int, set_rho_tuning::Int,
                                       dummy_interval_choice::Int, cont_solver_accuracy::Int,
                                       next_choice::Int, rnd_intervals::Int, rsd_intervals::Int)
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***")
    
    future_net_vector = SuperNetwork[]
    
    # Create base supernetwork to get contingency count
    supernet = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 0, 
                           next_choice, dummy_interval_choice, cont_solver_accuracy, 
                           0, rnd_intervals, rsd_intervals)
    
    number_of_cont = get_cont_count(supernet)
    push!(future_net_vector, supernet)
    
    # Create first dispatch interval supernetwork
    supernet1 = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 1,
                            next_choice, dummy_interval_choice, cont_solver_accuracy,
                            0, rnd_intervals, rsd_intervals)
    push!(future_net_vector, supernet1)
    
    # Generate all contingency and interval combinations
    generate_supernetwork_instances!(future_net_vector, number_of_cont, rnd_intervals, 
                                   rsd_intervals, net_id, solver_choice, set_rho_tuning,
                                   dummy_interval_choice, cont_solver_accuracy, next_choice)
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE ENDS ***")
    
    return future_net_vector, number_of_cont
end

"""
    generate_supernetwork_instances!(future_net_vector, number_of_cont, rnd_intervals, 
                                    rsd_intervals, net_id, solver_choice, set_rho_tuning,
                                    dummy_interval_choice, cont_solver_accuracy, next_choice)

Generate all supernetwork instances for different contingencies and intervals
"""
function generate_supernetwork_instances!(future_net_vector::Vector{SuperNetwork}, 
                                        number_of_cont::Int, rnd_intervals::Int, 
                                        rsd_intervals::Int, net_id::Int, solver_choice::Int,
                                        set_rho_tuning::Int, dummy_interval_choice::Int,
                                        cont_solver_accuracy::Int, next_choice::Int)
    
    for i in 0:number_of_cont
        # RND intervals (restoration intervals)
        for j in 1:rnd_intervals
            line_outaged = 0
            if i > 0
                line_outaged = index_of_line_out(future_net_vector[1], i)
            end
            
            last_flag = 0
            supernet = SuperNetwork(net_id, solver_choice, set_rho_tuning, i, j, last_flag,
                                  next_choice, dummy_interval_choice, cont_solver_accuracy,
                                  line_outaged, rnd_intervals, rsd_intervals)
            push!(future_net_vector, supernet)
        end
        
        # RSD intervals (security intervals)
        for j in 0:rsd_intervals
            line_outaged = 0
            if i > 0
                line_outaged = index_of_line_out(future_net_vector[1], i)
            end
            
            last_flag = (j == rsd_intervals) ? 1 : 0
            
            supernet = SuperNetwork(net_id, solver_choice, set_rho_tuning, i, 
                                  j + rnd_intervals, last_flag, next_choice,
                                  dummy_interval_choice, cont_solver_accuracy,
                                  line_outaged, rnd_intervals, rsd_intervals)
            push!(future_net_vector, supernet)
        end
    end
end

"""
    run_simulation!(supernet::SuperNetwork, iter_count_app::Int, lambda_app::Vector{Float64},
                   pow_diff::Vector{Float64}, power_self_gen::Vector{Float64},
                   power_next_bel::Vector{Float64}, power_prev_bel::Vector{Float64},
                   lambda_app_line::Vector{Float64}, pow_diff_line::Vector{Float64},
                   power_self_flow_bel::Vector{Float64}, power_next_flow_bel::Vector{Float64})

Run simulation for a single supernetwork instance
"""
function run_simulation!(supernet::SuperNetwork, iter_count_app::Int, 
                        lambda_app::Vector{Float64}, pow_diff::Vector{Float64},
                        power_self_gen::Vector{Float64}, power_next_bel::Vector{Float64},
                        power_prev_bel::Vector{Float64}, lambda_app_line::Vector{Float64},
                        pow_diff_line::Vector{Float64}, power_self_flow_bel::Vector{Float64},
                        power_next_flow_bel::Vector{Float64})
    
    start_time = time()
    
    # Placeholder for actual optimization solve
    # This would call the appropriate solver based on supernet.solver_choice
    solve_supernetwork_optimization!(supernet, iter_count_app, lambda_app, pow_diff,
                                   power_self_gen, power_next_bel, power_prev_bel,
                                   lambda_app_line, pow_diff_line, power_self_flow_bel,
                                   power_next_flow_bel)
    
    supernet.virtual_net_exec_time = time() - start_time
end

"""
    solve_supernetwork_optimization!(supernet, ...)

Placeholder for actual optimization solving - would integrate with your solver framework
"""
function solve_supernetwork_optimization!(supernet::SuperNetwork, args...)
    # This would call the appropriate solver:
    # - GUROBI-APMP (ADMM/PMP+APP)
    # - CVXGEN-APMP 
    # - GUROBI APP Coarse Grained
    # - Centralized GUROBI SCOPF
    
    # For now, simulate some computation time
    sleep(0.001)
    
    # Initialize power values if not already set
    num_gens = max(1, get_gen_number(supernet))
    num_lines = max(1, get_trans_number(supernet))
    
    if isempty(supernet.power_self)
        supernet.power_self = rand(num_gens) * 100.0  # Random power values
    end
    if isempty(supernet.power_next)
        supernet.power_next = rand(num_gens) * 100.0
    end
    if isempty(supernet.power_flow_self)
        supernet.power_flow_self = rand(num_lines) * 50.0
    end
end

"""
    run_simulation_lascopf()

Main function to run the complete LASCOPF simulation
"""
function run_simulation_lascopf()
    println("*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION ***")
    println("*** CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) ***")
    
    # Get user inputs
    net_id = get_user_input("Enter the number of nodes (2, 3, 5, 14, 30, 48, 57, 118, 300)", Int)
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
    
    # Initialize supernetwork system
    future_net_vector, number_of_cont = initialize_supernetwork_system(
        net_id, solver_choice, set_rho_tuning, dummy_interval_choice,
        cont_solver_accuracy, next_choice, rnd_intervals, rsd_intervals)
    
    # Setup APP algorithm parameters
    number_of_generators = get_gen_number(future_net_vector[1])
    number_of_lines = get_trans_number(future_net_vector[1])
    
    # Calculate dimensions for consensus variables
    cons_lag_dim, cons_line_lag_dim, supernet_num, supernet_num_next, supernet_line_num_next = 
        calculate_consensus_dimensions(dummy_interval_choice, number_of_cont, rnd_intervals, 
                                     rsd_intervals, number_of_generators, number_of_lines)
    
    # Initialize APP variables
    lambda_app = zeros(Float64, cons_lag_dim)
    pow_diff = zeros(Float64, cons_lag_dim)
    lambda_app_line = zeros(Float64, cons_line_lag_dim)
    pow_diff_line = zeros(Float64, cons_line_lag_dim)
    
    power_self_gen = zeros(Float64, supernet_num * number_of_generators)
    power_next_bel = zeros(Float64, supernet_num_next * number_of_generators)
    power_prev_bel = zeros(Float64, supernet_num * number_of_generators)
    power_next_flow_bel = zeros(Float64, supernet_line_num_next)
    power_self_flow_bel = zeros(Float64, supernet_line_num_next)
    
    # Initialize with warm start values
    initialize_power_beliefs!(power_self_gen, power_next_bel, power_prev_bel,
                             power_next_flow_bel, power_self_flow_bel,
                             future_net_vector, supernet_num, supernet_num_next,
                             number_of_generators, number_of_lines, number_of_cont,
                             rnd_intervals)
    
    # Run APP iterations
    result_data = run_app_iterations!(future_net_vector, number_of_cont, rnd_intervals, 
                                    rsd_intervals, dummy_interval_choice, number_of_generators,
                                    number_of_lines, lambda_app, pow_diff, lambda_app_line,
                                    pow_diff_line, power_self_gen, power_next_bel, 
                                    power_prev_bel, power_next_flow_bel, power_self_flow_bel,
                                    cons_lag_dim, cons_line_lag_dim)
    
    # Save results
    save_results(result_data, solver_choice)
    
    return result_data
end

"""
    calculate_consensus_dimensions(dummy_interval_choice, number_of_cont, rnd_intervals, 
                                  rsd_intervals, number_of_generators, number_of_lines)

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
    initialize_power_beliefs!(...)

Initialize power belief variables with warm start values
"""
function initialize_power_beliefs!(power_self_gen::Vector{Float64}, power_next_bel::Vector{Float64},
                                  power_prev_bel::Vector{Float64}, power_next_flow_bel::Vector{Float64},
                                  power_self_flow_bel::Vector{Float64}, future_net_vector::Vector{SuperNetwork},
                                  supernet_num::Int, supernet_num_next::Int, number_of_generators::Int,
                                  number_of_lines::Int, number_of_cont::Int, rnd_intervals::Int)
    
    # Initialize power generation beliefs
    prev_powers = get_pow_prev(future_net_vector[1])
    if isempty(prev_powers)
        prev_powers = fill(50.0, number_of_generators)  # Default values
    end
    
    for i in 1:supernet_num
        for j in 1:number_of_generators
            idx = (i-1) * number_of_generators + j
            power_self_gen[idx] = prev_powers[min(j, end)]
            
            if i == 1
                power_prev_bel[idx] = prev_powers[min(j, end)]
            else
                power_prev_bel[idx] = prev_powers[min(j, end)]
            end
        end
    end
    
    for i in 1:supernet_num_next
        for j in 1:number_of_generators
            idx = (i-1) * number_of_generators + j
            power_next_bel[idx] = prev_powers[min(j, end)]
        end
    end
    
    # Initialize flow beliefs (difficult to warm start, use zeros)
    fill!(power_next_flow_bel, 0.0)
    fill!(power_self_flow_bel, 0.0)
end

"""
    run_app_iterations!(...)

Run the main APP iteration loop
"""
function run_app_iterations!(future_net_vector::Vector{SuperNetwork}, number_of_cont::Int,
                            rnd_intervals::Int, rsd_intervals::Int, dummy_interval_choice::Int,
                            number_of_generators::Int, number_of_lines::Int,
                            lambda_app::Vector{Float64}, pow_diff::Vector{Float64},
                            lambda_app_line::Vector{Float64}, pow_diff_line::Vector{Float64},
                            power_self_gen::Vector{Float64}, power_next_bel::Vector{Float64},
                            power_prev_bel::Vector{Float64}, power_next_flow_bel::Vector{Float64},
                            power_self_flow_bel::Vector{Float64}, cons_lag_dim::Int,
                            cons_line_lag_dim::Int)
    
    iter_count_app = 1
    alpha_app = 100.0
    fin_tol = 1000.0
    fin_tol_delayed = 1000.0
    
    result_data = Dict{String, Any}()
    result_data["Initial_Tolerance"] = fin_tol
    
    largest_supernet_time_vec = Float64[]
    actual_supernet_time = 0.0
    
    start_time = time()
    
    println("\n*** APP ALGORITHM ITERATIONS BEGIN ***")
    println("*** SIMULATION IN PROGRESS ***")
    
    # Main APP iteration loop
    while fin_tol >= 0.005
        single_supernet_time_vec = Float64[]
        
        if dummy_interval_choice == 1
            # With dummy interval
            num_supernetworks = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
            
            for net_sim_count in 0:(num_supernetworks - 1)
                print_iteration_info(iter_count_app, net_sim_count, number_of_cont)
                
                run_simulation!(future_net_vector[net_sim_count + 1], iter_count_app, lambda_app,
                              pow_diff, power_self_gen, power_next_bel, power_prev_bel,
                              lambda_app_line, pow_diff_line, power_self_flow_bel, power_next_flow_bel)
                
                single_time = get_virtual_net_exec_time(future_net_vector[net_sim_count + 1])
                actual_supernet_time += single_time
                push!(single_supernet_time_vec, single_time)
            end
            
            # Calculate power disagreements with dummy interval
            calculate_power_disagreements_with_dummy!(pow_diff, pow_diff_line, future_net_vector,
                                                    number_of_cont, rnd_intervals, rsd_intervals,
                                                    number_of_generators, number_of_lines,
                                                    power_self_gen, power_next_bel, power_prev_bel,
                                                    power_next_flow_bel, power_self_flow_bel)
        else
            # Without dummy interval
            num_supernetworks = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
            
            for net_sim_count in 0:(num_supernetworks - 1)
                print_iteration_info(iter_count_app, net_sim_count + 1, number_of_cont)
                
                run_simulation!(future_net_vector[net_sim_count + 2], iter_count_app, lambda_app,
                              pow_diff, power_self_gen, power_next_bel, power_prev_bel,
                              lambda_app_line, pow_diff_line, power_self_flow_bel, power_next_flow_bel)
                
                single_time = get_virtual_net_exec_time(future_net_vector[net_sim_count + 2])
                actual_supernet_time += single_time
                push!(single_supernet_time_vec, single_time)
            end
            
            # Calculate power disagreements without dummy interval
            calculate_power_disagreements_without_dummy!(pow_diff, pow_diff_line, future_net_vector,
                                                       number_of_cont, rnd_intervals, rsd_intervals,
                                                       number_of_generators, number_of_lines,
                                                       power_self_gen, power_next_bel, power_prev_bel,
                                                       power_next_flow_bel, power_self_flow_bel)
        end
        
        largest_time = maximum(single_supernet_time_vec)
        push!(largest_supernet_time_vec, largest_time)
        
        # Tune APP parameter
        alpha_app = tune_alpha_app(iter_count_app)
        
        # Update Lagrange multipliers
        for i in 1:cons_lag_dim
            lambda_app[i] += alpha_app * pow_diff[i]
        end
        
        for i in 1:cons_line_lag_dim
            lambda_app_line[i] += alpha_app * pow_diff_line[i]
        end
        
        # Calculate tolerances
        tol_app = 0.0
        tol_app_delayed = 0.0
        
        for i in 1:cons_lag_dim
            tol_app += pow_diff[i]^2
            if dummy_interval_choice == 1 && i > 2 * number_of_generators
                tol_app_delayed += pow_diff[i]^2
            elseif dummy_interval_choice == 0
                tol_app_delayed += pow_diff[i]^2
            end
        end
        
        for i in 1:cons_line_lag_dim
            tol_app += pow_diff_line[i]^2
            tol_app_delayed += pow_diff_line[i]^2
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
        
        println(@sprintf("\nIteration %d: APP Tolerance = %.6f, Delayed Tolerance = %.6f", 
                        iter_count_app, fin_tol, fin_tol_delayed))
        
        iter_count_app += 1
        fin_tol = dummy_interval_choice == 1 ? fin_tol_delayed : fin_tol
        
        # Safety break to prevent infinite loops
        if iter_count_app > 1000
            println("Warning: Maximum iterations reached")
            break
        end
    end
    
    total_time = time() - start_time
    virtual_time = total_time - actual_supernet_time + sum(largest_supernet_time_vec)
    
    println("\n*** APP ALGORITHM ITERATIONS COMPLETE ***")
    println(@sprintf("Execution time: %.2f seconds", total_time))
    println(@sprintf("Virtual execution time: %.2f seconds", virtual_time))
    
    result_data["Final_Results"] = Dict(
        "Total_Iterations" => iter_count_app - 1,
        "Final_Tolerance" => fin_tol,
        "Execution_Time" => total_time,
        "Virtual_Execution_Time" => virtual_time
    )
    
    return result_data
end

"""
    calculate_power_disagreements_with_dummy!(...)

Calculate power disagreements between intervals when using dummy interval
"""
function calculate_power_disagreements_with_dummy!(pow_diff::Vector{Float64}, pow_diff_line::Vector{Float64},
                                                 future_net_vector::Vector{SuperNetwork}, number_of_cont::Int,
                                                 rnd_intervals::Int, rsd_intervals::Int, number_of_generators::Int,
                                                 number_of_lines::Int, power_self_gen::Vector{Float64},
                                                 power_next_bel::Vector{Float64}, power_prev_bel::Vector{Float64},
                                                 power_next_flow_bel::Vector{Float64}, power_self_flow_bel::Vector{Float64})
    
    total_intervals = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
    
    for i in 0:(total_intervals - 1)
        if i == 0
            # Dummy interval case
            for j in 1:number_of_generators
                idx1 = 2 * i * number_of_generators + j
                idx2 = (2 * i + 1) * number_of_generators + j
                idx_self = i * number_of_generators + j
                idx_next = i * number_of_generators + j
                idx_prev = i * number_of_generators + j
                
                if idx1 <= length(pow_diff) && idx2 <= length(pow_diff)
                    pow_diff[idx1] = get_pow_self(future_net_vector[i + 1], j) - 
                                   get_pow_prev(future_net_vector[i + 2])[min(j, end)]
                    pow_diff[idx2] = get_pow_next(future_net_vector[i + 1], 0, i, j) - 
                                   get_pow_self(future_net_vector[i + 2], j)
                end
                
                if idx_self <= length(power_self_gen)
                    power_self_gen[idx_self] = get_pow_self(future_net_vector[i + 1], j)
                end
                if idx_next <= length(power_next_bel)
                    power_next_bel[idx_next] = get_pow_next(future_net_vector[i + 1], 0, i, j)
                end
                if idx_prev <= length(power_prev_bel)
                    power_prev_bel[idx_prev] = get_pow_prev(future_net_vector[i + 1])[min(j, end)]
                end
            end
        else
            # Regular intervals
            for j in 1:number_of_generators
                idx_self = i * number_of_generators + j
                idx_prev = i * number_of_generators + j
                
                if idx_self <= length(power_self_gen)
                    power_self_gen[idx_self] = get_pow_self(future_net_vector[i + 1], j)
                end
                if idx_prev <= length(power_prev_bel)
                    power_prev_bel[idx_prev] = get_pow_prev(future_net_vector[i + 1])[min(j, end)]
                end
                
                if i == 1
                    # First regular interval
                    for contin_counter in 0:number_of_cont
                        idx_next = (i + contin_counter) * number_of_generators + j
                        idx_diff1 = 2 * (i + contin_counter) * number_of_generators + j
                        idx_diff2 = (2 * (i + contin_counter) + 1) * number_of_generators + j
                        
                        if idx_next <= length(power_next_bel)
                            power_next_bel[idx_next] = get_pow_next(future_net_vector[i + 1], contin_counter, i, j)
                        end
                        
                        if idx_diff1 <= length(pow_diff) && i + contin_counter + 2 <= length(future_net_vector)
                            pow_diff[idx_diff1] = get_pow_self(future_net_vector[i + 1], j) - 
                                                 get_pow_prev(future_net_vector[i + contin_counter + 2])[min(j, end)]
                            pow_diff[idx_diff2] = get_pow_next(future_net_vector[i + 1], contin_counter, i, j) - 
                                                 get_pow_self(future_net_vector[i + contin_counter + 2], j)
                        end
                    end
                else
                    # Other intervals
                    idx_next = (i + number_of_cont) * number_of_generators + j
                    if idx_next <= length(power_next_bel)
                        power_next_bel[idx_next] = get_pow_next(future_net_vector[i + 1], 0, i, j)
                    end
                    
                    # Power disagreements for non-last intervals
                    for contin_counter in 0:number_of_cont
                        if i != (contin_counter + 1) * (rnd_intervals + rsd_intervals) + 1
                            idx_diff1 = 2 * (i + number_of_cont) * number_of_generators + j
                            idx_diff2 = (2 * (i + number_of_cont) + 1) * number_of_generators + j
                            
                            if idx_diff1 <= length(pow_diff) && i + 2 <= length(future_net_vector)
                                pow_diff[idx_diff1] = get_pow_self(future_net_vector[i + 1], j) - 
                                                     get_pow_prev(future_net_vector[i + 2])[min(j, end)]
                                pow_diff[idx_diff2] = get_pow_next(future_net_vector[i + 1], 0, i, j) - 
                                                     get_pow_self(future_net_vector[i + 2], j)
                            end
                        end
                    end
                end
            end
            
            # Handle line flow disagreements
            for j in 1:number_of_lines
                if i == 1
                    for contin_counter in 0:number_of_cont
                        for k in 0:(rnd_intervals - 2)
                            idx_flow = contin_counter * (rnd_intervals - 1) * number_of_lines + k * number_of_lines + j
                            
                            if idx_flow <= length(power_next_flow_bel)
                                power_next_flow_bel[idx_flow] = get_pow_flow_next(future_net_vector[i + 1], 
                                                                                contin_counter, i, k, j)
                            end
                            
                            target_idx = 2 + contin_counter * (rnd_intervals + rsd_intervals) + k + 1
                            if idx_flow <= length(pow_diff_line) && target_idx <= length(future_net_vector)
                                pow_diff_line[idx_flow] = get_pow_flow_next(future_net_vector[i + 1], 
                                                                          contin_counter, i, k, j) - 
                                                         get_pow_flow_self(future_net_vector[target_idx], j)
                            end
                        end
                    end
                else
                    for contin_counter in 0:number_of_cont
                        for k in 0:(rnd_intervals - 2)
                            if i == 2 + contin_counter * (rnd_intervals + rsd_intervals) + k
                                idx_flow = contin_counter * (rnd_intervals - 1) * number_of_lines + k * number_of_lines + j
                                if idx_flow <= length(power_self_flow_bel)
                                    power_self_flow_bel[idx_flow] = get_pow_flow_self(future_net_vector[i + 1], j)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

"""
    calculate_power_disagreements_without_dummy!(...)

Calculate power disagreements between intervals when not using dummy interval
"""
function calculate_power_disagreements_without_dummy!(pow_diff::Vector{Float64}, pow_diff_line::Vector{Float64},
                                                    future_net_vector::Vector{SuperNetwork}, number_of_cont::Int,
                                                    rnd_intervals::Int, rsd_intervals::Int, number_of_generators::Int,
                                                    number_of_lines::Int, power_self_gen::Vector{Float64},
                                                    power_next_bel::Vector{Float64}, power_prev_bel::Vector{Float64},
                                                    power_next_flow_bel::Vector{Float64}, power_self_flow_bel::Vector{Float64})
    
    total_intervals = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
    
    for i in 0:(total_intervals - 1)
        net_idx = i + 2  # Offset for future_net_vector indexing
        
        if i == 0
            # First interval
            for j in 1:number_of_generators
                idx_self = i * number_of_generators + j
                idx_prev = i * number_of_generators + j
                
                if idx_self <= length(power_self_gen) && net_idx <= length(future_net_vector)
                    power_self_gen[idx_self] = get_pow_self(future_net_vector[net_idx], j)
                    power_prev_bel[idx_prev] = get_pow_prev(future_net_vector[net_idx])[min(j, end)]
                end
                
                for contin_counter in 0:number_of_cont
                    idx_next = (i + contin_counter) * number_of_generators + j
                    idx_diff1 = 2 * (i + contin_counter) * number_of_generators + j
                    idx_diff2 = (2 * (i + contin_counter) + 1) * number_of_generators + j
                    
                    if idx_next <= length(power_next_bel) && net_idx <= length(future_net_vector)
                        power_next_bel[idx_next] = get_pow_next(future_net_vector[net_idx], contin_counter, i + 1, j)
                    end
                    
                    target_idx = i + contin_counter + 3
                    if idx_diff1 <= length(pow_diff) && target_idx <= length(future_net_vector)
                        pow_diff[idx_diff1] = get_pow_self(future_net_vector[net_idx], j) - 
                                             get_pow_prev(future_net_vector[target_idx])[min(j, end)]
                        pow_diff[idx_diff2] = get_pow_next(future_net_vector[net_idx], contin_counter, i + 1, j) - 
                                             get_pow_self(future_net_vector[target_idx], j)
                    end
                end
            end
        else
            # Other intervals
            for j in 1:number_of_generators
                idx_self = i * number_of_generators + j
                idx_next = (i + number_of_cont) * number_of_generators + j
                idx_prev = i * number_of_generators + j
                
                if net_idx <= length(future_net_vector)
                    if idx_self <= length(power_self_gen)
                        power_self_gen[idx_self] = get_pow_self(future_net_vector[net_idx], j)
                    end
                    if idx_next <= length(power_next_bel)
                        power_next_bel[idx_next] = get_pow_next(future_net_vector[net_idx], 0, i + 1, j)
                    end
                    if idx_prev <= length(power_prev_bel)
                        power_prev_bel[idx_prev] = get_pow_prev(future_net_vector[net_idx])[min(j, end)]
                    end
                end
                
                # Power disagreements for non-last intervals
                for contin_counter in 0:number_of_cont
                    if i != (contin_counter + 1) * (rnd_intervals + rsd_intervals)
                        idx_diff1 = 2 * (i + number_of_cont) * number_of_generators + j
                        idx_diff2 = (2 * (i + number_of_cont) + 1) * number_of_generators + j
                        target_idx = i + 3
                        
                        if (idx_diff1 <= length(pow_diff) && target_idx <= length(future_net_vector) && 
                            net_idx <= length(future_net_vector))
                            pow_diff[idx_diff1] = get_pow_self(future_net_vector[net_idx], j) - 
                                                 get_pow_prev(future_net_vector[target_idx])[min(j, end)]
                            pow_diff[idx_diff2] = get_pow_next(future_net_vector[net_idx], 0, i + 1, j) - 
                                                 get_pow_self(future_net_vector[target_idx], j)
                        end
                    end
                end
            end
        end
        
        # Handle line flow disagreements
        for j in 1:number_of_lines
            if i == 0
                for contin_counter in 0:number_of_cont
                    for k in 0:(rnd_intervals - 2)
                        idx_flow = contin_counter * (rnd_intervals - 1) * number_of_lines + k * number_of_lines + j
                        
                        if idx_flow <= length(power_next_flow_bel) && net_idx <= length(future_net_vector)
                            power_next_flow_bel[idx_flow] = get_pow_flow_next(future_net_vector[net_idx], 
                                                                            contin_counter, i + 1, k, j)
                        end
                        
                        target_idx = 2 + contin_counter * (rnd_intervals + rsd_intervals) + k + 1
                        if idx_flow <= length(pow_diff_line) && target_idx <= length(future_net_vector)
                            pow_diff_line[idx_flow] = get_pow_flow_next(future_net_vector[net_idx], 
                                                                      contin_counter, i + 1, k, j) - 
                                                       get_pow_flow_self(future_net_vector[target_idx], j)
                        end
                    end
                end
            else
                for contin_counter in 0:number_of_cont
                    for k in 0:(rnd_intervals - 2)
                        if i == 1 + contin_counter * (rnd_intervals + rsd_intervals) + k
                            idx_flow = contin_counter * (rnd_intervals - 1) * number_of_lines + k * number_of_lines + j
                            if idx_flow <= length(power_self_flow_bel) && net_idx <= length(future_net_vector)
                                power_self_flow_bel[idx_flow] = get_pow_flow_self(future_net_vector[net_idx], j)
                            end
                        end
                    end
                end
            end
        end
    end
end

"""
    tune_alpha_app(iter_count::Int)

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
    print_iteration_info(iter_count, net_sim_count, number_of_cont)

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
