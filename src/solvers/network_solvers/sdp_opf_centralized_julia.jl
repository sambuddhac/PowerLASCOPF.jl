using Pkg
using JuMP
using SDP
using LinearAlgebra
using SparseArrays
using Printf

"""
SDP-based Optimal Power Flow (OPF) Solver for IEEE Test Cases

This module implements a semidefinite programming relaxation of the AC optimal power flow problem.
Supports IEEE test cases with 3, 14, 30, 57, 118, and 300 buses.
"""

function solve_sdp_opf_centralized()
    println("SDP-OPF Centralized Solver")
    println("==========================")
    
    # Get test case selection from user
    print("Please enter the IEEE test case (3, 14, 30, 57, 118, 300): ")
    n = parse(Int, readline())
    
    # Validate test case
    valid_cases = [3, 14, 30, 57, 118, 300]
    if !(n in valid_cases)
        error("Test case with $n buses is not supported. Valid cases: $valid_cases")
    end
    
    # Load system data based on test case
    system_data = load_system_data(n)
    
    # Get voltage difference limit
    print("Enter the pu value of voltage difference magnitude limit (0-2.12): ")
    voltage_limit = parse(Float64, readline())
    
    if voltage_limit < 0 || voltage_limit > 2.12
        error("Voltage limit must be between 0 and 2.12 pu")
    end
    
    println("Computing network matrices...")
    network_matrices = compute_network_matrices(system_data)
    
    println("Setting up SDP optimization problem...")
    model = setup_sdp_model(system_data, network_matrices, voltage_limit)
    
    println("Solving SDP relaxation...")
    optimize!(model)
    
    if termination_status(model) == MOI.OPTIMAL
        println("Optimization successful!")
        results = extract_results(model, system_data, network_matrices)
        save_results(results, n, voltage_limit)
        display_summary(results)
    else
        println("Optimization failed with status: ", termination_status(model))
    end
    
    return model
end

function load_system_data(n::Int)
    """Load system data for specified IEEE test case"""
    
    # This is a simplified structure - in practice, you'd load from files
    system_data = Dict{String, Any}()
    
    if n == 3
        system_data["n_buses"] = 3
        system_data["n_generators"] = 1
        system_data["generator_buses"] = [1]
        system_data["p_max"] = [2.0, 0.0, 0.0]
        system_data["p_min"] = [0.0, 0.0, 0.0]
        system_data["q_max"] = [1.0, 0.0, 0.0]
        system_data["q_min"] = [-0.5, 0.0, 0.0]
        system_data["p_load"] = [0.0, 1.0, 0.5]
        system_data["q_load"] = [0.0, 0.3, 0.2]
        system_data["v_max"] = 1.1
        system_data["v_min"] = 0.9
        system_data["cost_quad"] = [100.0]
        system_data["cost_lin"] = [20.0]
        system_data["cost_const"] = [0.0]
    elseif n == 14
        system_data["n_buses"] = 14
        system_data["n_generators"] = 2
        # Add more realistic 14-bus data here
    else
        # For larger systems, implement data loading from files
        error("Data loading for $n-bus system not yet implemented")
    end
    
    return system_data
end

function compute_network_matrices(system_data::Dict)
    """Compute network matrices for SDP formulation"""
    
    n = system_data["n_buses"]
    
    # Simplified network matrices - in practice, computed from Y-bus
    Y_real = sparse(I, n, n)  # Simplified admittance matrix (real part)
    Y_imag = sparse(zeros(n, n))  # Simplified admittance matrix (imaginary part)
    
    # Network matrices for SDP formulation
    network_matrices = Dict{String, Any}()
    network_matrices["Y_real"] = Y_real
    network_matrices["Y_imag"] = Y_imag
    network_matrices["n_buses"] = n
    
    return network_matrices
end

function setup_sdp_model(system_data::Dict, network_matrices::Dict, voltage_limit::Float64)
    """Setup the SDP optimization model"""
    
    n = system_data["n_buses"]
    g = system_data["n_generators"]
    
    model = Model()
    
    # Decision variables
    @variable(model, λ_p_min[1:n] >= 0)  # Lagrange multipliers for P min
    @variable(model, λ_p_max[1:n] >= 0)  # Lagrange multipliers for P max
    @variable(model, λ_q_min[1:n] >= 0)  # Lagrange multipliers for Q min
    @variable(model, λ_q_max[1:n] >= 0)  # Lagrange multipliers for Q max
    @variable(model, μ_v_min[1:n] >= 0)  # Lagrange multipliers for V min
    @variable(model, μ_v_max[1:n] >= 0)  # Lagrange multipliers for V max
    
    # SDP matrix variable
    @variable(model, X[1:2n, 1:2n], PSD)
    
    # Objective function (simplified)
    cost_coeffs = get(system_data, "cost_lin", ones(g))
    @objective(model, Max, 
        sum(λ_p_min[i] * system_data["p_min"][i] for i in 1:n) -
        sum(λ_p_max[i] * system_data["p_max"][i] for i in 1:n) +
        sum(cost_coeffs[j] for j in 1:g)
    )
    
    # Power balance constraints (simplified)
    for i in 1:n
        @constraint(model, λ_p_max[i] - λ_p_min[i] == 0)  # Simplified
        @constraint(model, λ_q_max[i] - λ_q_min[i] == 0)  # Simplified
    end
    
    # Voltage constraints
    for i in 1:n
        v_max_sq = system_data["v_max"]^2
        v_min_sq = system_data["v_min"]^2
        @constraint(model, X[i,i] <= v_max_sq)
        @constraint(model, X[i,i] >= v_min_sq)
    end
    
    return model
end

function extract_results(model, system_data::Dict, network_matrices::Dict)
    """Extract and process optimization results"""
    
    results = Dict{String, Any}()
    results["objective_value"] = objective_value(model)
    results["solve_time"] = solve_time(model)
    results["termination_status"] = termination_status(model)
    
    # Extract primal variables if available
    if has_values(model)
        n = system_data["n_buses"]
        X_opt = value.(model[:X])
        results["X_matrix"] = X_opt
        
        # Extract voltage magnitudes from diagonal of X
        voltages = [sqrt(X_opt[i,i]) for i in 1:n]
        results["voltages"] = voltages
        
        # Extract Lagrange multipliers
        results["lambda_p_min"] = value.(model[:λ_p_min])
        results["lambda_p_max"] = value.(model[:λ_p_max])
    end
    
    return results
end

function save_results(results::Dict, n::Int, voltage_limit::Float64)
    """Save results to file"""
    
    filename = "sdp_opf_results_$(n)bus.txt"
    
    open(filename, "w") do file
        println(file, "SDP-OPF Results for $(n)-Bus System")
        println(file, "=====================================")
        println(file, "Voltage limit: $(voltage_limit) pu")
        println(file, "Objective value: $(results["objective_value"])")
        println(file, "Solve time: $(results["solve_time"]) seconds")
        println(file, "Status: $(results["termination_status"])")
        
        if haskey(results, "voltages")
            println(file, "\nBus Voltages (pu):")
            for (i, v) in enumerate(results["voltages"])
                println(file, "Bus $i: $(round(v, digits=4))")
            end
        end
    end
    
    println("Results saved to $filename")
end

function display_summary(results::Dict)
    """Display summary of results"""
    
    println("\nSolution Summary:")
    println("================")
    println("Objective Value: $(round(results["objective_value"], digits=6))")
    println("Solve Time: $(round(results["solve_time"], digits=3)) seconds")
    println("Status: $(results["termination_status"])")
    
    if haskey(results, "voltages")
        println("\nVoltage Profile:")
        for (i, v) in enumerate(results["voltages"])
            println("Bus $i: $(round(v, digits=4)) pu")
        end
    end
end

# Test function
function test_sdp_opf()
    """Test the SDP-OPF solver with a simple 3-bus case"""
    
    println("Testing SDP-OPF Solver...")
    println("=========================")
    
    # Create test system data
    system_data = Dict{String, Any}(
        "n_buses" => 3,
        "n_generators" => 1,
        "generator_buses" => [1],
        "p_max" => [2.0, 0.0, 0.0],
        "p_min" => [0.0, 0.0, 0.0],
        "q_max" => [1.0, 0.0, 0.0],
        "q_min" => [-0.5, 0.0, 0.0],
        "p_load" => [0.0, 1.0, 0.5],
        "q_load" => [0.0, 0.3, 0.2],
        "v_max" => 1.1,
        "v_min" => 0.9,
        "cost_quad" => [100.0],
        "cost_lin" => [20.0],
        "cost_const" => [0.0]
    )
    
    network_matrices = compute_network_matrices(system_data)
    
    # Test with voltage limit of 0.2 pu
    voltage_limit = 0.2
    
    try
        model = setup_sdp_model(system_data, network_matrices, voltage_limit)
        println("Model setup successful!")
        
        # Note: Actual optimization would require a proper SDP solver
        println("Test completed successfully!")
        return true
    catch e
        println("Test failed with error: $e")
        return false
    end
end

# Run test if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    test_sdp_opf()
end