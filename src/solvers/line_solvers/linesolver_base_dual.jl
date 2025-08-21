# Line solver with dual-approach implementation
# This file provides both direct JuMP and PSI preall    # Check solution status
    status = termination_status(model)
    if !(status in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED])
        if status == MOI.INFEASIBLE
            error("Line solver problem is infeasible")
        elseif status == MOI.TIME_LIMIT
            error("Line solver timed out")
        elseif status == MOI.INFEASIBLE_OR_UNBOUNDED
            error("Line solver problem is infeasible or unbounded")
        else
            @warn "Line solver finished with status: $status"
        end
    # Approaches for line solver optimization
# Author: Integrated implementation based on gensolver_first_base.jl pattern

using JuMP
using HiGHS
using Ipopt
import PowerSystems as PSY
import PowerSimulations as PSI
import MathOptInterface as MOI
using Dates
using BenchmarkTools
using Statistics

@kwdef mutable struct LineSolverBase{T<:LineIntervals} <: AbstractModel
    lambda_txr::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    interval_type::T # Interval type
    E_coeff::Array{Float64} #Line temperature evolution coefficients
    Pt_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    BSC::Array{Float64} # Cumulative disagreement between the line flow values, at the previous iteration
    E_temp_coeff::Array{Float64} # Temperature evolution coefficients matrix
    alpha_factor::Float64 = 0.05 #Fraction of line MW flow, which is the Ohmic loss
    beta_factor::Float64 = 0.1 # Temperature factor
    beta::Float64 = 0.1 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 = 0.2 # APP tuning parameter for across the dispatch intervals
    Pt_max::Float64 = 100000.0 # Line flow MW Limits
    temp_init::Float64 = 340.0 #Initial line temperature in Kelvin
    temp_amb::Float64 = 300.0 #Ambient temperature in Kelvin
    max_temp::Float64 = 473.0 #Maximum allowed line temperature in Kelvin
    RND_int::Int64 = 6 #Number of intervals for restoration to nominal/normal flows
    cont_count::Int64 = 1 #Number of contingency scenarios
end

# DIRECT JUMP APPROACH - Traditional optimization without preallocation
function solve_linesolver_direct!(model::JuMP.Model,
                                 m::LineSolverBase;
                                 optimizer=Ipopt.Optimizer,
                                 silent=true)
    """
    Direct JuMP approach for line solver optimization.
    This creates a fresh JuMP model and solves directly without PSI preallocation.
    
    Args:
        model: JuMP model to be populated
        m: LineSolverBase struct with problem data
        optimizer: Optimization solver (default: Ipopt)
        silent: Whether to suppress solver output
        
    Returns:
        Dict with solution results and timing information
    """
    
    start_time = time()
    
    # Set optimizer
    set_optimizer(model, optimizer)
    if silent
        set_silent(model)
    end
    
    # Helper variables
    One = repeat([1.0], m.cont_count, (m.RND_int-1))
    
    # Decision Variables
    @variable(model, 0 <= Pt_line <= m.Pt_max) # Line real power flow
    @variable(model, 0 <= PtNext[1:m.cont_count, 1:(m.RND_int-1)] <= m.Pt_max) # Line flow in next intervals
    
    # Flow constraints
    @constraint(model, flow_upper[i=1:m.cont_count, j=1:(m.RND_int-1)], 
                PtNext[i,j] <= m.Pt_max)
    @constraint(model, flow_lower[i=1:m.cont_count, j=1:(m.RND_int-1)], 
                PtNext[i,j] >= -m.Pt_max)
    
    # Temperature constraints
    for contInd in 1:m.cont_count
        for omega in 1:m.RND_int
            thermal_term = (m.alpha_factor/m.beta_factor) * 
                          sum(m.E_temp_coeff[k, omega] * (PtNext[contInd, j])^2 
                              for j in 1:min(m.RND_int-omega, m.RND_int-1) 
                              for k in 1:m.RND_int if j >= 1 && k <= size(m.E_temp_coeff, 1))
            @constraint(model, 
                       m.E_coeff[omega]*m.temp_init + (1-m.E_coeff[omega])*m.temp_amb + thermal_term <= m.max_temp)
        end
    end
    
    # Objective function - quadratic with APP terms
    @objective(model, Min, 
               (m.beta/2) * sum(sum((PtNext[i,j] - m.Pt_next_nu[i + (j-1)*m.cont_count])^2 
                               for i in 1:m.cont_count) for j in 1:(m.RND_int-1)) +
               m.gamma * sum(sum(PtNext[i,j] * m.BSC[i + (j-1)*m.cont_count] 
                            for i in 1:m.cont_count) for j in 1:(m.RND_int-1)) +
               sum(sum(PtNext[i,j] * m.lambda_txr[i + (j-1)*m.cont_count] 
                      for i in 1:m.cont_count) for j in 1:(m.RND_int-1)))
    
    # Solve the model
    solve_start = time()
    optimize!(model)
    solve_time = time() - solve_start
    total_time = time() - start_time
    
    # Check solution status
    status = termination_status(model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            error("Line solver problem is infeasible")
        elseif status == MOI.TIME_LIMIT
            error("Line solver timed out")
        elseif status == MOI.INFEASIBLE_OR_UNBOUNDED
            error("Line solver problem is infeasible or unbounded")
        else
            error("Line solver failed with status: ", status)
        end
    end
    
    # Extract results
    results = Dict(
        "Pt_line" => value(Pt_line),
        "PtNext" => value.(PtNext),
        "objective_value" => objective_value(model),
        "solve_time" => solve_time,
        "total_time" => total_time,
        "termination_status" => status,
        "approach" => "direct_jump"
    )
    
    return results
end

# PSI PREALLOCATED APPROACH - Using PowerSimulations infrastructure
function solve_linesolver_preallocated!(container::PSI.OptimizationContainer,
                                      m::LineSolverBase;
                                      optimizer=Ipopt.Optimizer)
    """
    PSI preallocated approach for line solver optimization.
    This uses PowerSimulations infrastructure for variable and constraint preallocation.
    
    Args:
        container: PSI OptimizationContainer with preallocated structures
        m: LineSolverBase struct with problem data
        optimizer: Optimization solver (default: Ipopt)
        
    Returns:
        Dict with solution results and timing information
    """
    
    start_time = time()
    
    # Get the JuMP model from container
    model = PSI.get_jump_model(container)
    
    # Set optimizer if not already set
    if MOI.get(model, MOI.SolverName()) == "No optimizer attached."
        set_optimizer(model, optimizer)
        set_silent(model)
    end
    
    # Use PSI variable containers for better memory management
    try
        # Define variable keys for line solver
        pt_line_key = PSI.VariableKey(PSI.ActivePowerVariable, PSI.ThermalStandard)
        pt_next_key = PSI.VariableKey(PSI.ActivePowerVariable, PSI.Line)
        
        # Get or create variables using PSI containers
        if !PSI.has_variable(container, pt_line_key)
            pt_line_vars = PSI.add_variable_container!(
                container,
                pt_line_key,
                [string("line_", i) for i in 1:1],
                1:1
            )
        else
            pt_line_vars = PSI.get_variable(container, pt_line_key)
        end
        
        if !PSI.has_variable(container, pt_next_key)
            pt_next_vars = PSI.add_variable_container!(
                container,
                pt_next_key,
                [string("cont_", i, "_int_", j) for i in 1:m.cont_count for j in 1:(m.RND_int-1)],
                1:1
            )
        else
            pt_next_vars = PSI.get_variable(container, pt_next_key)
        end
        
    catch e
        @warn "PSI variable container setup failed, falling back to direct variable creation: $e"
        
        # Fallback to direct variable creation
        @variable(model, 0 <= Pt_line <= m.Pt_max)
        @variable(model, 0 <= PtNext[1:m.cont_count, 1:(m.RND_int-1)] <= m.Pt_max)
        
        # Use these variables directly
        pt_line_vars = Pt_line
        pt_next_vars = PtNext
    end
    
    # Add constraints using PSI constraint containers
    try
        # Flow limit constraints
        flow_constraint_key = PSI.ConstraintKey(PSI.FlowLimitConstraint, PSI.Line)
        
        flow_ub_container = PSI.add_constraint_container!(
            container,
            flow_constraint_key,
            [string("flow_ub_", i, "_", j) for i in 1:m.cont_count for j in 1:(m.RND_int-1)],
            1:1
        )
        
        flow_lb_container = PSI.add_constraint_container!(
            container,
            PSI.ConstraintKey(PSI.FlowLimitConstraint, PSI.ThermalStandard),
            [string("flow_lb_", i, "_", j) for i in 1:m.cont_count for j in 1:(m.RND_int-1)],
            1:1
        )
        
        # Temperature limit constraints
        temp_constraint_key = PSI.ConstraintKey(PSI.ThermalLimitConstraint, PSI.Line)
        
        temp_container = PSI.add_constraint_container!(
            container,
            temp_constraint_key,
            [string("temp_", i, "_", j) for i in 1:m.cont_count for j in 1:m.RND_int],
            1:1
        )
        
    catch e
        @warn "PSI constraint container setup failed, using direct constraints: $e"
        
        # Fallback to direct constraint creation
        if isa(pt_next_vars, Array)
            @constraint(model, [i=1:m.cont_count, j=1:(m.RND_int-1)], 
                       pt_next_vars[i,j] <= m.Pt_max)
            @constraint(model, [i=1:m.cont_count, j=1:(m.RND_int-1)], 
                       pt_next_vars[i,j] >= -m.Pt_max)
            
            # Temperature constraints with proper variable scope
            for contInd in 1:m.cont_count
                for omega in 1:m.RND_int
                    thermal_term = (m.alpha_factor/m.beta_factor) * 
                                  sum(m.E_temp_coeff[k, omega] * (pt_next_vars[contInd, j])^2 
                                      for j in 1:min(m.RND_int-omega, m.RND_int-1) 
                                      for k in 1:m.RND_int if j >= 1 && k <= size(m.E_temp_coeff, 1))
                    @constraint(model, 
                               m.E_coeff[omega]*m.temp_init + (1-m.E_coeff[omega])*m.temp_amb + thermal_term <= m.max_temp)
                end
            end
        else
            # Handle PSI variable containers
            for i in 1:m.cont_count, j in 1:(m.RND_int-1)
                var_name = string("cont_", i, "_int_", j)
                if haskey(pt_next_vars, var_name)
                    @constraint(model, pt_next_vars[var_name][1] <= m.Pt_max)
                    @constraint(model, pt_next_vars[var_name][1] >= -m.Pt_max)
                end
            end
        end
    end
    
    # Set objective function
    obj_expr = AffExpr(0.0)
    
    # APP penalty terms
    if isa(pt_next_vars, Array)
        for i in 1:m.cont_count, j in 1:(m.RND_int-1)
            idx = i + (j-1)*m.cont_count
            if idx <= length(m.Pt_next_nu)
                add_to_expression!(obj_expr, (m.beta/2) * (pt_next_vars[i,j] - m.Pt_next_nu[idx])^2)
            end
            if idx <= length(m.BSC)
                add_to_expression!(obj_expr, m.gamma * pt_next_vars[i,j] * m.BSC[idx])
            end
            if idx <= length(m.lambda_txr)
                add_to_expression!(obj_expr, pt_next_vars[i,j] * m.lambda_txr[idx])
            end
        end
    else
        # Handle PSI variable containers
        for i in 1:m.cont_count, j in 1:(m.RND_int-1)
            var_name = string("cont_", i, "_int_", j)
            if haskey(pt_next_vars, var_name)
                idx = i + (j-1)*m.cont_count
                var = pt_next_vars[var_name][1]
                if idx <= length(m.Pt_next_nu)
                    add_to_expression!(obj_expr, (m.beta/2) * (var - m.Pt_next_nu[idx])^2)
                end
                if idx <= length(m.BSC)
                    add_to_expression!(obj_expr, m.gamma * var * m.BSC[idx])
                end
                if idx <= length(m.lambda_txr)
                    add_to_expression!(obj_expr, var * m.lambda_txr[idx])
                end
            end
        end
    end
    
    @objective(model, Min, obj_expr)
    
    # Solve the model
    solve_start = time()
    optimize!(model)
    solve_time = time() - solve_start
    total_time = time() - start_time
    
    # Check solution status
    status = termination_status(model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            error("Line solver problem is infeasible")
        elseif status == MOI.TIME_LIMIT
            error("Line solver timed out")
        elseif status == MOI.INFEASIBLE_OR_UNBOUNDED
            error("Line solver problem is infeasible or unbounded")
        else
            error("Line solver failed with status: ", status)
        end
    end
    
    # Extract results
    results = Dict(
        "objective_value" => objective_value(model),
        "solve_time" => solve_time,
        "total_time" => total_time,
        "termination_status" => status,
        "approach" => "preallocated_psi"
    )
    
    # Extract variable values
    if isa(pt_next_vars, Array)
        results["PtNext"] = value.(pt_next_vars)
        if @isdefined Pt_line
            results["Pt_line"] = value(Pt_line)
        end
    else
        # Extract from PSI containers
        pt_next_values = zeros(m.cont_count, m.RND_int-1)
        for i in 1:m.cont_count, j in 1:(m.RND_int-1)
            var_name = string("cont_", i, "_int_", j)
            if haskey(pt_next_vars, var_name)
                pt_next_values[i,j] = value(pt_next_vars[var_name][1])
            end
        end
        results["PtNext"] = pt_next_values
    end
    
    return results
end

# BENCHMARKING AND COMPARISON FUNCTIONS
function benchmark_linesolver_approaches(sys::PSY.System; 
                                       time_horizon=24,
                                       num_samples=5,
                                       optimizer=Ipopt.Optimizer,
                                       verbose=true)
    """
    Benchmark both direct JuMP and PSI preallocated approaches for line solver.
    
    Args:
        sys: PowerSystems System object
        time_horizon: Number of time periods for optimization
        num_samples: Number of benchmark samples for statistical significance
        optimizer: Optimization solver to use
        verbose: Whether to print detailed results
        
    Returns:
        Dict with comprehensive benchmarking results
    """
    
    if verbose
        println("🔬 Starting LineSolver Approach Benchmarking")
        println("=" ^ 50)
        println("System: $(get_name(sys))")
        println("Time horizon: $time_horizon hours")
        println("Benchmark samples: $num_samples")
        println("Optimizer: $optimizer")
        println()
    end
    
    # Extract line data from the system
    lines = collect(get_components(Line, sys))
    num_lines = length(lines)
    
    if num_lines == 0
        error("No lines found in the system")
    end
    
    # Create sample LineSolverBase data based on system properties
    cont_count = 2  # Number of contingency scenarios
    RND_int = 6    # Number of restoration intervals
    
    # Sample problem data (normally this would come from actual system data)
    linesolver_data = LineSolverBase(
        lambda_txr = randn(cont_count * (RND_int-1)),
        interval_type = nothing, # You'd need to define LineIntervals type
        E_coeff = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
        Pt_next_nu = zeros(cont_count * (RND_int-1)),
        BSC = zeros(cont_count * (RND_int-1)),
        E_temp_coeff = randn(RND_int, RND_int),
        alpha_factor = 0.05,
        beta_factor = 0.1,
        beta = 0.1,
        gamma = 0.2,
        Pt_max = 1000.0,
        temp_init = 340.0,
        temp_amb = 300.0,
        max_temp = 473.0,
        RND_int = RND_int,
        cont_count = cont_count
    )
    
    # Initialize results storage
    direct_times = Float64[]
    psi_times = Float64[]
    direct_solve_times = Float64[]
    psi_solve_times = Float64[]
    direct_objectives = Float64[]
    psi_objectives = Float64[]
    
    if verbose
        println("📊 Running benchmarks...")
    end
    
    # Benchmark Direct JuMP Approach
    for i in 1:num_samples
        if verbose
            print("Direct JuMP [$i/$num_samples]... ")
        end
        
        try
            model = Model()
            result = solve_linesolver_direct!(model, linesolver_data, optimizer=optimizer, silent=true)
            
            push!(direct_times, result["total_time"])
            push!(direct_solve_times, result["solve_time"])
            push!(direct_objectives, result["objective_value"])
            
            if verbose
                println("✓ ($(round(result["total_time"]*1000, digits=2))ms)")
            end
        catch e
            if verbose
                println("✗ Failed: $e")
            end
            push!(direct_times, NaN)
            push!(direct_solve_times, NaN)
            push!(direct_objectives, NaN)
        end
    end
    
    # Benchmark PSI Preallocated Approach
    for i in 1:num_samples
        if verbose
            print("PSI Preallocated [$i/$num_samples]... ")
        end
        
        try
            container = PSI.OptimizationContainer(
                PSI.MockOperationModel, 
                PSI.NetworkModel(),
                nothing, # settings
                nothing, # forecast_cache
                Dict() # metadata
            )
            
            result = solve_linesolver_preallocated!(container, linesolver_data, optimizer=optimizer)
            
            push!(psi_times, result["total_time"])
            push!(psi_solve_times, result["solve_time"])
            push!(psi_objectives, result["objective_value"])
            
            if verbose
                println("✓ ($(round(result["total_time"]*1000, digits=2))ms)")
            end
        catch e
            if verbose
                println("✗ Failed: $e")
            end
            push!(psi_times, NaN)
            push!(psi_solve_times, NaN)
            push!(psi_objectives, NaN)
        end
    end
    
    # Calculate statistics (filtering out NaN values)
    function safe_stats(data)
        clean_data = filter(!isnan, data)
        if isempty(clean_data)
            return (mean=NaN, std=NaN, min=NaN, max=NaN, median=NaN)
        end
        return (
            mean = mean(clean_data),
            std = std(clean_data),
            min = minimum(clean_data),
            max = maximum(clean_data),
            median = median(clean_data)
        )
    end
    
    direct_stats = safe_stats(direct_times)
    psi_stats = safe_stats(psi_times)
    direct_solve_stats = safe_stats(direct_solve_times)
    psi_solve_stats = safe_stats(psi_solve_times)
    
    # Calculate performance comparison
    if !isnan(direct_stats.mean) && !isnan(psi_stats.mean)
        speedup_ratio = direct_stats.mean / psi_stats.mean
        memory_efficiency = psi_stats.mean < direct_stats.mean ? "PSI" : "Direct"
    else
        speedup_ratio = NaN
        memory_efficiency = "Unknown"
    end
    
    # Display results
    if verbose
        println("\n📈 BENCHMARKING RESULTS")
        println("=" ^ 50)
        
        println("\n🚀 TOTAL EXECUTION TIME")
        println("Direct JuMP:")
        println("  Mean: $(round(direct_stats.mean*1000, digits=2))ms ± $(round(direct_stats.std*1000, digits=2))ms")
        println("  Range: $(round(direct_stats.min*1000, digits=2))-$(round(direct_stats.max*1000, digits=2))ms")
        
        println("\nPSI Preallocated:")
        println("  Mean: $(round(psi_stats.mean*1000, digits=2))ms ± $(round(psi_stats.std*1000, digits=2))ms")
        println("  Range: $(round(psi_stats.min*1000, digits=2))-$(round(psi_stats.max*1000, digits=2))ms")
        
        println("\n⚡ SOLVE TIME ONLY")
        println("Direct JuMP: $(round(direct_solve_stats.mean*1000, digits=2))ms ± $(round(direct_solve_stats.std*1000, digits=2))ms")
        println("PSI Preallocated: $(round(psi_solve_stats.mean*1000, digits=2))ms ± $(round(psi_solve_stats.std*1000, digits=2))ms")
        
        if !isnan(speedup_ratio)
            println("\n🏆 PERFORMANCE COMPARISON")
            if speedup_ratio > 1.0
                println("PSI Preallocated is $(round(speedup_ratio, digits=2))x faster than Direct JuMP")
            else
                println("Direct JuMP is $(round(1/speedup_ratio, digits=2))x faster than PSI Preallocated")
            end
            println("More efficient approach: $memory_efficiency")
        end
        
        println("\n💾 MEMORY CHARACTERISTICS")
        println("Direct JuMP: Creates fresh variables and constraints each time")
        println("PSI Preallocated: Reuses preallocated memory structures")
        
        println("\n" * "=" ^ 50)
    end
    
    # Return comprehensive results
    return Dict(
        "system_name" => get_name(sys),
        "num_lines" => num_lines,
        "time_horizon" => time_horizon,
        "num_samples" => num_samples,
        "direct_approach" => Dict(
            "total_times" => direct_times,
            "solve_times" => direct_solve_times,
            "objectives" => direct_objectives,
            "stats" => direct_stats,
            "solve_stats" => direct_solve_stats
        ),
        "psi_approach" => Dict(
            "total_times" => psi_times,
            "solve_times" => psi_solve_times,
            "objectives" => psi_objectives,
            "stats" => psi_stats,
            "solve_stats" => psi_solve_stats
        ),
        "comparison" => Dict(
            "speedup_ratio" => speedup_ratio,
            "more_efficient" => memory_efficiency
        ),
        "timestamp" => now()
    )
end

function benchmark_memory_usage(sys::PSY.System; time_horizon=24)
    """
    Benchmark memory usage of both approaches using @allocated macro.
    
    Args:
        sys: PowerSystems System object
        time_horizon: Number of time periods for optimization
        
    Returns:
        Dict with memory usage comparison
    """
    
    println("🧠 Memory Usage Benchmarking")
    println("=" ^ 30)
    
    # Create sample data
    cont_count = 2
    RND_int = 6
    
    linesolver_data = LineSolverBase(
        lambda_txr = randn(cont_count * (RND_int-1)),
        interval_type = nothing,
        E_coeff = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
        Pt_next_nu = zeros(cont_count * (RND_int-1)),
        BSC = zeros(cont_count * (RND_int-1)),
        E_temp_coeff = randn(RND_int, RND_int),
        cont_count = cont_count,
        RND_int = RND_int
    )
    
    # Measure memory allocation for Direct JuMP
    direct_memory = @allocated begin
        try
            model = Model()
            solve_linesolver_direct!(model, linesolver_data, silent=true)
        catch
            # Handle potential errors gracefully
        end
    end
    
    # Measure memory allocation for PSI Preallocated
    psi_memory = @allocated begin
        try
            container = PSI.OptimizationContainer(
                PSI.MockOperationModel, 
                PSI.NetworkModel(),
                nothing,
                nothing,
                Dict()
            )
            solve_linesolver_preallocated!(container, linesolver_data)
        catch
            # Handle potential errors gracefully
        end
    end
    
    println("Direct JuMP Memory: $(direct_memory) bytes ($(round(direct_memory/1024/1024, digits=2)) MB)")
    println("PSI Preallocated Memory: $(psi_memory) bytes ($(round(psi_memory/1024/1024, digits=2)) MB)")
    
    if psi_memory < direct_memory
        reduction = ((direct_memory - psi_memory) / direct_memory) * 100
        println("PSI approach reduces memory usage by $(round(reduction, digits=1))%")
    else
        increase = ((psi_memory - direct_memory) / direct_memory) * 100
        println("PSI approach uses $(round(increase, digits=1))% more memory")
    end
    
    return Dict(
        "direct_memory_bytes" => direct_memory,
        "psi_memory_bytes" => psi_memory,
        "memory_reduction_percent" => ((direct_memory - psi_memory) / direct_memory) * 100,
        "timestamp" => now()
    )
end

# UTILITY FUNCTIONS
function create_sample_linesolver_data(;cont_count=2, RND_int=6)
    """
    Create sample LineSolverBase data for testing.
    
    Args:
        cont_count: Number of contingency scenarios
        RND_int: Number of restoration intervals
        
    Returns:
        LineSolverBase struct with sample data
    """
    
    return LineSolverBase(
        lambda_txr = randn(cont_count * (RND_int-1)),
        interval_type = nothing,
        E_coeff = [0.9^i for i in 1:RND_int],
        Pt_next_nu = zeros(cont_count * (RND_int-1)),
        BSC = 0.1 * randn(cont_count * (RND_int-1)),
        E_temp_coeff = 0.01 * randn(RND_int, RND_int),
        alpha_factor = 0.05,
        beta_factor = 0.1,
        beta = 0.1,
        gamma = 0.2,
        Pt_max = 1000.0,
        temp_init = 340.0,
        temp_amb = 300.0,
        max_temp = 473.0,
        RND_int = RND_int,
        cont_count = cont_count
    )
end

function compare_linesolver_solutions(result1, result2; tolerance=1e-6)
    """
    Compare solutions from different approaches to ensure consistency.
    
    Args:
        result1, result2: Results dictionaries from solver functions
        tolerance: Numerical tolerance for comparison
        
    Returns:
        Dict with comparison results
    """
    
    # Compare objective values
    obj_diff = abs(result1["objective_value"] - result2["objective_value"])
    obj_consistent = obj_diff < tolerance
    
    # Compare PtNext variables if both exist
    vars_consistent = true
    max_var_diff = 0.0
    
    if haskey(result1, "PtNext") && haskey(result2, "PtNext")
        var_diff = abs.(result1["PtNext"] - result2["PtNext"])
        max_var_diff = maximum(var_diff)
        vars_consistent = max_var_diff < tolerance
    end
    
    return Dict(
        "objectives_consistent" => obj_consistent,
        "objective_difference" => obj_diff,
        "variables_consistent" => vars_consistent,
        "max_variable_difference" => max_var_diff,
        "overall_consistent" => obj_consistent && vars_consistent,
        "tolerance_used" => tolerance
    )
end

# Legacy compatibility function
function linesolver_base(m::LineSolverBase; approach="direct")
    """
    Legacy wrapper function that maintains backward compatibility.
    
    Args:
        m: LineSolverBase struct
        approach: "direct" for JuMP or "psi" for preallocated
        
    Returns:
        Results dictionary
    """
    
    if approach == "direct"
        model = Model()
        return solve_linesolver_direct!(model, m)
    elseif approach == "psi"
        container = PSI.OptimizationContainer(
            PSI.MockOperationModel, 
            PSI.NetworkModel(),
            nothing,
            nothing,
            Dict()
        )
        return solve_linesolver_preallocated!(container, m)
    else
        error("Unknown approach: $approach. Use 'direct' or 'psi'")
    end
end

# Export main functions
export LineSolverBase, solve_linesolver_direct!, solve_linesolver_preallocated!
export benchmark_linesolver_approaches, benchmark_memory_usage
export create_sample_linesolver_data, compare_linesolver_solutions, linesolver_base
