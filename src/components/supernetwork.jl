# SuperNetwork source code for implementing APMP (Auxiliary Proximal Message Passing) Algorithm for the SCOPF in serial mode
using PowerSystems
using InfrastructureSystems
using Dates
using Printf
const PSY = PowerSystems
const IS = InfrastructureSystems

# Include necessary PowerLASCOPF components
include("../extensions/extended_system.jl")
include("network.jl")
@kwdef mutable struct SuperNetwork
    # Core properties
    network_id::Int
    cont_net_vector::Vector{PowerLASCOPFSystem} = PowerLASCOPFSystem[]
    net_object_vec::Vector{Network} = Network[]
    solver_choice::Int = 1
    set_rho_tuning::Float64 = 1.0
    post_contingency::Int = 0
    interval_count::Int = 0
    interval_class::Int = 0
    rnd_intervals::Int = 6
    rsd_intervals::Int = 6
    last_interval::Bool = false
    outaged_line::Int = 0
    
    # Algorithm parameters
    number_of_cont::Int = 0
    number_of_generators::Int = 0
    number_of_trans_lines::Int = 0
    cons_lag_dim::Int = 0
    
    # APP algorithm properties
    alpha_app::Float64 = 100.0
    iter_count_app::Int = 1
    fin_tol::Float64 = 1000.0
    
    # Performance tracking
    largest_net_time_vec::Vector{Float64} = Float64[]
    single_net_time_vec::Vector{Float64} = Float64[]
    virtual_net_exec_time::Float64 = 0.0
    
    # Results storage
    matrix_result_app_out::Dict{Any,Any} = Dict()
end

# Separate factory function for initialization logic
function initialize_supernetwork!(
    pre_post_scenario::Bool,
    powerlascopf_system::PowerLASCOPFSystem,
    super_net::SuperNetwork;
    build_contingencies::Bool = true
)
    println("\n*** NETWORK INITIALIZATION STAGE BEGINS ***\n")
    println("Creating lightweight Network interfaces that reference shared PowerLASCOPFSystem...")

    # Store reference to the shared PowerLASCOPFSystem
    # All networks in this SuperNetwork will reference THIS SAME system
    push!(super_net.cont_net_vector, powerlascopf_system)
    
    # Create base network interface (scenario 0)
    println("  Creating base case network interface...")
    network_object_base = create_network_from_system(;
        sys = powerlascopf_system,
        network_id = super_net.network_id,
        scenario_index = 0,
        post_contingency_scenario = super_net.post_contingency,
        pre_post_cont_scen = pre_post_scenario,  # Use the parameter passed to this function
        dummy_zero_flag = 0,
        accuracy = 1,
        interval_id = super_net.interval_count,
        last_flag = super_net.last_interval,
        outaged_line = 0, #super_net.outaged_line,
        base_outaged_line = 0, #super_net.outaged_line,
        contingency_count = super_net.number_of_cont,
        solver_choice = super_net.solver_choice
    )

    #=network_object_base = network_init_var(pre_post_scenario; 
                                        net_sys = powerlascopf_system
    )=#
    
    # Add base network to vector
    #push!(super_net.cont_net_vector, powerlascopf_system)
    push!(super_net.net_object_vec, network_object_base)
    
    # Get contingency count from base network
    super_net.number_of_cont = network_object_base.contingency_count
    
    # Create contingency network instances if requested
    if build_contingencies && 
       ((super_net.interval_count == 0) || 
        (super_net.interval_count == (super_net.rnd_intervals + super_net.rsd_intervals)))
        
        for i in 1:super_net.number_of_cont
            if i != super_net.post_contingency
                println("  Creating network interface for contingency scenario $i...")
                println("Total number of continegencies to build: $(super_net.number_of_cont) and the post contingency scenario is $(super_net.post_contingency)")
                line_outaged = get_outaged_line_index(network_object_base, i)
                if line_outaged != super_net.outaged_line
                    network_object_cont = create_network_from_system(
                        sys = powerlascopf_system,
                        network_id = super_net.network_id,
                        scenario_index = i,
                        post_contingency_scenario = super_net.post_contingency,
                        pre_post_cont_scen = pre_post_scenario,  # Use the parameter passed to this function
                        dummy_zero_flag = 0,
                        accuracy = 1,
                        interval_id = super_net.interval_count,
                        last_flag = super_net.last_interval,
                        base_outaged_line = super_net.outaged_line,
                        contingency_count = super_net.number_of_cont,
                        solver_choice = super_net.solver_choice,
                    )
                    #=network_object_cont = network_init_var(pre_post_scenario; 
                                                        net_sys = cont_system
                    )   =#
                    #push!(super_net.cont_net_vector, cont_system)
                    push!(super_net.net_object_vec, network_object_cont)
                end
            end
        end
    end
    
    println("\n*** NETWORK INITIALIZATION STAGE ENDS ***\n")
    
    # Update dimensions based on network information
    super_net.number_of_generators = get_extended_thermal_generator_count(powerlascopf_system)
    super_net.number_of_trans_lines = get_transmission_line_count(powerlascopf_system)
    super_net.cons_lag_dim = super_net.number_of_cont * super_net.number_of_generators
    
    return super_net
end

# Convenient constructor function that combines creation and initialization
function create_supernetwork_object(;
    powerlascopf_system::PowerLASCOPFSystem,
    pre_post_scenario::Bool,
    network_id::Int,
    solver_choice::Int = 1,
    set_rho_tuning::Float64 = 1.0,
    post_contingency::Int = 0,
    interval_count::Int = 0,
    interval_class::Int = 0,
    rnd_intervals::Int = 6,
    rsd_intervals::Int = 6,
    last_interval::Bool = false,
    outaged_line::Int = 0,
    build_contingencies::Bool = true,
    kwargs...  # Catch any extra parameters
)

    # Extract number_of_cont from kwargs with a default value
    number_of_cont = get(kwargs, :number_of_cont, 0)

    # Create the struct with basic parameters
    super_net = SuperNetwork(;
        network_id = network_id,
        solver_choice = solver_choice,
        set_rho_tuning = set_rho_tuning,
        post_contingency = post_contingency,
        interval_count = interval_count,
        interval_class = interval_class,
        rnd_intervals = rnd_intervals,
        rsd_intervals = rsd_intervals,
        last_interval = last_interval,
        outaged_line = outaged_line,
        number_of_cont = number_of_cont,  # Will be set during initialization
    )
    
    # Initialize with network building logic
    initialize_supernetwork!(pre_post_scenario, powerlascopf_system, super_net; build_contingencies = build_contingencies)
    
    return super_net
end

# Helper function to get outaged line index (placeholder implementation)
function get_outaged_line_index(system::PowerLASCOPFSystem, contingency_index::Int)
    # This should return the index of the line that is outaged in scenario i
    # For now, return a simple mapping - replace with actual logic
    return contingency_index
end

# Destructor equivalent
function finalize_super_network!(super_net::SuperNetwork)
    println("Dispatch interval super-network object for dispatch interval $(super_net.interval_count) destroyed")
end

# Getter functions
function get_virtual_net_exec_time(super_net::SuperNetwork)
    return super_net.virtual_net_exec_time
end

function index_of_line_out(super_net::SuperNetwork, post_scenar::Int)
    if !isempty(super_net.cont_net_vector)
        return get_outaged_line_index(super_net.cont_net_vector[1], post_scenar)
    end
    return 0
end

function ret_cont_count(super_net::SuperNetwork)
    return super_net.number_of_cont
end

function get_gen_number(super_net::SuperNetwork)
    return super_net.number_of_generators
end

function get_trans_number(super_net::SuperNetwork)
    return super_net.number_of_trans_lines
end
# Main simulation function for SuperNetwork
function run_simulation!(
    super_net::SuperNetwork,
    outer_iter::Int,
    lambda_outer::Vector{Float64},
    pow_diff_outer::Vector{Float64},
    pow_self_bel::Vector{Float64},
    pow_next_bel::Vector{Float64},
    pow_prev_bel::Vector{Float64},
    lambda_line::Vector{Float64},
    power_diff_line::Vector{Float64},
    pow_self_flow_bel::Vector{Float64},
    pow_next_flow_bel::Vector{Float64}
)
    # Initialize APP algorithm parameters
    lambda_app = zeros(Float64, super_net.cons_lag_dim)
    pow_diff = zeros(Float64, super_net.cons_lag_dim)
    super_net.alpha_app = 100.0
    super_net.iter_count_app = 1
    super_net.fin_tol = 1000.0
    
    if super_net.solver_choice in [1, 2]  # APMP Fully distributed, Bi-layer (N-1) SCOPF Simulation
        println("\n*** APMP ALGORITHM BASED COARSE+FINE GRAINED BILAYER DECENTRALIZED/DISTRIBUTED SCOPF (SERIAL IMPLEMENTATION) BEGINS ***\n")
        println("\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")
        
        # Initialize performance tracking
        super_net.largest_net_time_vec = Float64[]
        actual_net_time = 0.0
        
        # Full SCOPF only for present/forthcoming, dummy, and last intervals
        if (super_net.interval_count == 0) || (super_net.interval_count == (super_net.rnd_intervals + super_net.rsd_intervals))
            for iter_count in 1:10  # APP iterations
                super_net.single_net_time_vec = Float64[]
                
                # Iterate over base-case and contingency scenarios
                for net_sim_count in 1:(super_net.number_of_cont + 1)
                    # Calculate for base-case or contingency scenarios
                    if (net_sim_count == 1) || ((net_sim_count > 1) && (net_sim_count != super_net.post_contingency + 1))
                        network_index = adjust_network_index(super_net, net_sim_count)
                        
                        if network_index <= length(super_net.cont_net_vector)
                            println("Start of $iter_count-th Innermost APP iteration for $net_sim_count-th base/contingency scenario")
                            
                            # Run simulation on specific network
                            start_time = time()
                            run_network_simulation!(
                                super_net.cont_net_vector[network_index],
                                outer_iter,
                                lambda_outer,
                                pow_diff_outer,
                                super_net.set_rho_tuning,
                                iter_count,
                                lambda_app,
                                pow_diff,
                                pow_self_bel,
                                pow_next_bel,
                                pow_prev_bel,
                                lambda_line,
                                power_diff_line,
                                pow_self_flow_bel,
                                pow_next_flow_bel
                            )
                            single_net_time = time() - start_time
                            actual_net_time += single_net_time
                            push!(super_net.single_net_time_vec, single_net_time)
                        end
                    end
                end
                
                # Track largest network time
                if !isempty(super_net.single_net_time_vec)
                    largest_net_time = maximum(super_net.single_net_time_vec)
                    push!(super_net.largest_net_time_vec, largest_net_time)
                end
                
                # Calculate power differences for APP consensus
                calculate_power_differences!(super_net, pow_diff)
                
                # Update APP parameters
                update_app_parameters!(super_net, iter_count)
                
                # Update Lagrange multipliers
                update_lagrange_multipliers!(super_net, lambda_app, pow_diff)
                
                # Calculate tolerance
                tol_app = sqrt(sum(pow_diff[i]^2 for i in 1:super_net.cons_lag_dim))
                super_net.fin_tol = tol_app
                
                # Store results
                super_net.matrix_result_app_out[iter_count] = Dict(
                    "APP_Iteration_Count" => iter_count,
                    "APP_Tolerance" => super_net.fin_tol,
                    "Power_Differences" => copy(pow_diff)
                )
                
                # Check convergence
                if super_net.fin_tol < 0.5
                    println("APP algorithm converged at iteration $iter_count with tolerance $(super_net.fin_tol)")
                    break
                end
            end
            
        elseif (super_net.interval_count >= 1) && (super_net.interval_count <= (super_net.rnd_intervals - 1))
            # Base case only for restoration intervals
            println("Start of restoration interval simulation")
            start_time = time()
            run_network_simulation!(
                super_net.cont_net_vector[1],
                outer_iter,
                lambda_outer,
                pow_diff_outer,
                super_net.set_rho_tuning,
                1,
                lambda_app,
                pow_diff,
                pow_self_bel,
                pow_next_bel,
                pow_prev_bel,
                lambda_line,
                power_diff_line,
                pow_self_flow_bel,
                pow_next_flow_bel
            )
            single_net_time = time() - start_time
            actual_net_time += single_net_time
            push!(super_net.single_net_time_vec, single_net_time)
            
        elseif (super_net.interval_count >= super_net.rnd_intervals) && (super_net.interval_count < (super_net.rnd_intervals + super_net.rsd_intervals))
            # Security restoration intervals
            println("Start of security restoration interval simulation")
            start_time = time()
            run_network_simulation!(
                super_net.cont_net_vector[1],
                outer_iter,
                lambda_outer,
                pow_diff_outer,
                super_net.set_rho_tuning,
                1,
                lambda_app,
                pow_diff,
                pow_self_bel,
                pow_next_bel,
                pow_prev_bel,
                lambda_line,
                power_diff_line,
                pow_self_flow_bel,
                pow_next_flow_bel
            )
            single_net_time = time() - start_time
            actual_net_time += single_net_time
            push!(super_net.single_net_time_vec, single_net_time)
        end
        
        println("\n*** SCOPF SIMULATION ENDS ***\n")
        println("Final Value of APP Tolerance: $(super_net.fin_tol)")
        
        # Calculate virtual execution time
        if !isempty(super_net.largest_net_time_vec)
            super_net.virtual_net_exec_time = actual_net_time + sum(super_net.largest_net_time_vec)
        else
            super_net.virtual_net_exec_time = actual_net_time
        end
        
        println("Virtual Supernetwork Execution time (s): $(super_net.virtual_net_exec_time)")
        
    elseif super_net.solver_choice == 3  # Centralized (N-1) SCOPF Simulation
        println("\n*** CENTRALIZED (N-1) SCOPF SIMULATION ***\n")
        # TODO: Implement centralized solver
        @warn "Centralized solver not yet implemented"
        
    elseif super_net.solver_choice == 4  # Centralized SCOPF Simulation
        println("\n*** CENTRALIZED SCOPF SIMULATION ***\n")
        # TODO: Implement centralized SCOPF solver
        @warn "Centralized SCOPF solver not yet implemented"
        
    else
        error("Invalid choice of solution method and algorithm: $(super_net.solver_choice)")
    end
    
    # Save results
    save_simulation_results!(super_net)
    
    return super_net
end

# Helper functions for run_simulation!

function adjust_network_index(super_net::SuperNetwork, net_sim_count::Int)
    """Adjust network index based on post-contingency scenario"""
    if (super_net.post_contingency > 0) && (net_sim_count > super_net.post_contingency + 1)
        return net_sim_count - 1  # Skip one index and compensate
    else
        return net_sim_count
    end
end

function run_network_simulation!(
    system::PowerLASCOPFSystem,
    outer_iter::Int,
    lambda_outer::Vector{Float64},
    pow_diff_outer::Vector{Float64},
    rho_tuning::Float64,
    iter_count::Int,
    lambda_app::Vector{Float64},
    pow_diff::Vector{Float64},
    pow_self_bel::Vector{Float64},
    pow_next_bel::Vector{Float64},
    pow_prev_bel::Vector{Float64},
    lambda_line::Vector{Float64},
    power_diff_line::Vector{Float64},
    pow_self_flow_bel::Vector{Float64},
    pow_next_flow_bel::Vector{Float64}
)
    """Run simulation on a specific network system"""
    # TODO: Implement the actual network simulation logic
    # This would involve:
    # 1. Solving generator optimization problems
    # 2. Solving transmission line optimization problems
    # 3. Updating node variables
    # 4. Performing message passing between components
    
    println("  Running network simulation for system $(system.network_id)")
    
    # Placeholder implementation - replace with actual solver calls
    for gen in get_extended_thermal_generators(system)
        # Update generator variables based on APP iteration
        # This would call the generator solver methods
        @debug "Processing generator $(get_gen_id(gen))"
    end
    
    for line in get_transmission_lines(system)
        # Update transmission line variables
        # This would call the line solver methods
        @debug "Processing transmission line $(get_transl_id(line))"
    end
    
    for node in get_nodes(system)
        # Update node variables and perform message passing
        @debug "Processing node $(get_node_id(node))"
    end
end

function calculate_power_differences!(super_net::SuperNetwork, pow_diff::Vector{Float64})
    """Calculate power differences for APP consensus mechanism"""
    fill!(pow_diff, 0.0)  # Reset array
    
    if super_net.post_contingency > 0  # For outaged case
        for i in 1:super_net.number_of_cont
            for j in 1:super_net.number_of_generators
                idx = (i-1) * super_net.number_of_generators + j
                if idx <= length(pow_diff)
                    if (i < super_net.post_contingency)
                        # pow_diff[idx] = base_power - contingency_power
                        # This would access actual power values from the systems
                        pow_diff[idx] = get_power_difference(super_net, 1, i+1, j)
                    elseif (i > super_net.post_contingency)
                        pow_diff[idx] = get_power_difference(super_net, 1, i, j)
                    end
                end
            end
        end
    else  # For non-outaged case
        for i in 1:super_net.number_of_cont
            for j in 1:super_net.number_of_generators
                idx = (i-1) * super_net.number_of_generators + j
                if idx <= length(pow_diff)
                    pow_diff[idx] = get_power_difference(super_net, 1, i+1, j)
                end
            end
        end
    end
end

function get_power_difference(super_net::SuperNetwork, base_idx::Int, cont_idx::Int, gen_idx::Int)
    """Get power difference between base case and contingency scenario for a specific generator"""
    # TODO: Implement actual power extraction from systems
    # This would access the actual power values from the generator objects
    
    if base_idx <= length(super_net.cont_net_vector) && cont_idx <= length(super_net.cont_net_vector)
        base_system = super_net.cont_net_vector[base_idx]
        cont_system = super_net.cont_net_vector[cont_idx]
        
        # Get generators from both systems
        base_generators = get_extended_thermal_generators(base_system)
        cont_generators = get_extended_thermal_generators(cont_system)
        
        if gen_idx <= length(base_generators) && gen_idx <= length(cont_generators)
            # Return difference in power generation
            # base_power = gen_power(base_generators[gen_idx])
            # cont_power = gen_power(cont_generators[gen_idx])
            # return base_power - cont_power
            return 0.0  # Placeholder
        end
    end
    
    return 0.0
end

function update_app_parameters!(super_net::SuperNetwork, iter_count::Int)
    """Update APP algorithm parameters based on iteration count"""
    if (iter_count > 5) && (iter_count <= 10)
        super_net.alpha_app = 75.0
    elseif (iter_count > 10) && (iter_count <= 15)
        super_net.alpha_app = 2.5
    elseif (iter_count > 15) && (iter_count <= 20)
        super_net.alpha_app = 1.25
    elseif (iter_count > 20)
        super_net.alpha_app = 0.5
    end
end

function update_lagrange_multipliers!(super_net::SuperNetwork, lambda_app::Vector{Float64}, pow_diff::Vector{Float64})
    """Update APP Lagrange multipliers"""
    for i in 1:min(length(lambda_app), length(pow_diff))
        lambda_app[i] += super_net.alpha_app * pow_diff[i]
    end
end

function save_simulation_results!(super_net::SuperNetwork)
    """Save simulation results to file"""
    output_filename = get_output_filename(super_net.solver_choice)
    
    # Create results directory if it doesn't exist
    results_dir = "results"
    if !isdir(results_dir)
        mkdir(results_dir)
    end
    
    # Save results as text file for now (avoid JSON dependency)
    filepath = joinpath(results_dir, "$(output_filename)_resultOuterAPP-SCOPF.txt")
    
    try
        open(filepath, "w") do file
            println(file, "PowerLASCOPF Simulation Results")
            println(file, "=" * "^" * 40)
            println(file, "Solver Choice: $(super_net.solver_choice)")
            println(file, "Network ID: $(super_net.network_id)")
            println(file, "Final Tolerance: $(super_net.fin_tol)")
            println(file, "Virtual Execution Time: $(super_net.virtual_net_exec_time)")
            println(file, "Number of Contingencies: $(super_net.number_of_cont)")
            println(file, "Number of Generators: $(super_net.number_of_generators)")
            
            for (key, value) in super_net.matrix_result_app_out
                println(file, "Iteration $key: $value")
            end
        end
        println("Results saved to: $filepath")
    catch e
        @warn "Failed to save results: $e"
    end
end

function get_output_filename(solver_choice::Int)
    """Get output filename based on solver choice"""
    if solver_choice == 1
        return "ADMM_PMP_GUROBI"
    elseif solver_choice == 2
        return "ADMM_PMP_CVXGEN"
    elseif solver_choice == 3
        return "APP_Quasi_Decent_GUROBI"
    elseif solver_choice == 4
        return "APP_GUROBI_Centralized_SCOPF"
    else
        return "Unknown_Solver"
    end
end

# Power extraction functions
function get_pow_self(super_net::SuperNetwork, gener_count::Int)
    """Get self power belief for a generator"""
    if !isempty(super_net.cont_net_vector)
        system = super_net.cont_net_vector[1]
        generators = get_extended_thermal_generators(system)
        if gener_count <= length(generators)
            # return gen_power(generators[gener_count])
            return 0.0  # Placeholder
        end
    end
    return 0.0
end

function get_pow_prev(super_net::SuperNetwork, gener_count::Int)
    """Get previous power belief for a generator"""
    if !isempty(super_net.cont_net_vector)
        system = super_net.cont_net_vector[1]
        generators = get_extended_thermal_generators(system)
        if gener_count <= length(generators)
            # return gen_power_prev(generators[gener_count])
            return 0.0  # Placeholder
        end
    end
    return 0.0
end

function get_pow_next(super_net::SuperNetwork, contingency_counter::Int, disp_int_count::Int, gener_count::Int)
    """Get next power belief for a generator"""
    if disp_int_count == 1
        if !isempty(super_net.cont_net_vector)
            system = super_net.cont_net_vector[1]
            generators = get_extended_thermal_generators(system)
            if gener_count <= length(generators)
                # return gen_power_next(generators[gener_count], contingency_counter)
                return 0.0  # Placeholder
            end
        end
    else
        # Return power for specific dispatch interval
        return 0.0  # Placeholder
    end
    return 0.0
end

function get_pow_flow_next(super_net::SuperNetwork, contin_counter::Int, supernet_count::Int, rnd_inter_count::Int, line_count::Int)
    """Get next power flow belief for a transmission line"""
    if super_net.interval_class == 1
        # Implementation for forthcoming intervals
        return 0.0  # Placeholder
    else
        return 0.0
    end
end

function get_pow_flow_self(super_net::SuperNetwork, line_count::Int)
    """Get self power flow belief for a transmission line"""
    if super_net.interval_class == 2
        # Implementation for subsequent intervals
        return 0.0  # Placeholder
    else
        return 0.0
    end
end

# Export functions
export SuperNetwork, run_simulation!
export get_virtual_net_exec_time, index_of_line_out, ret_cont_count
export get_gen_number, get_trans_number
export get_pow_self, get_pow_prev, get_pow_next
export get_pow_flow_next, get_pow_flow_self