# Middle Interval Generator Solver
function solve_generator_middle_interval!(
    pm::AbstractPowerModel,
    gen_id::Int,
    interval::Int,
    data::LASCOPF_GenIntervalData,
    λ_prev::Float64,  # Dual variable from previous interval
    λ_next::Float64,  # Dual variable from next interval
    ρ::Float64        # ADMM penalty parameter
)
    # Get generator reference
    gen = ref(pm, :gen, gen_id)
    
    # Decision variables for this interval
    @variable(pm.model, gen["pmin"] <= Pg <= gen["pmax"])
    @variable(pm.model, gen["qmin"] <= Qg <= gen["qmax"])
    
    # Binary commitment variable (if unit commitment is enabled)
    if haskey(gen, "commitment") && gen["commitment"]
        @variable(pm.model, u, Bin)
        @constraint(pm.model, Pg <= gen["pmax"] * u)
        @constraint(pm.model, Pg >= gen["pmin"] * u)
    # ADMM Coordination for Generator Solvers
struct LASCOPF_ADMMData
    # Dual variables between intervals
    λ_gen::Dict{Tuple{Int,Int}, Float64}  # (gen_id, interval) -> dual variable
    
    # Primal variables (power outputs)
    Pg_admm::Dict{Tuple{Int,Int}, Float64}  # (gen_id, interval) -> power output
    
    # Penalty parameters
    ρ_gen::Float64
    ρ_network::Float64
    
    # Convergence tracking
    primal_residual::Float64
    dual_residual::Float64
    tolerance::Float64
    max_iterations::Int
    
    # Constructor
    function LASCOPF_ADMMData(num_gens::Int, num_intervals::Int; 
                              ρ_gen=1.0, ρ_network=1.0, 
                              tolerance=1e-4, max_iterations=100)
        new(
            Dict{Tuple{Int,Int}, Float64}(),
            Dict{Tuple{Int,Int}, Float64}(),
            ρ_gen, ρ_network,
            Inf, Inf, tolerance, max_iterations
        )
    # Helper functions for ADMM coordination

function initialize_admm_variables!(
    pm::AbstractPowerModel,
    num_intervals::Int,
    admm_data::LASCOPF_ADMMData
)
    # Initialize dual variables to zero
    for gen_id in keys(ref(pm, :gen))
        for interval in 1:num_intervals
            admm_data.λ_gen[(gen_id, interval)] = 0.0
            # Initialize primal variables to mid-range values
            gen = ref(pm, :gen, gen_id)
            admm_data.Pg_admm[(gen_id, interval)] = (gen["pmax"] + gen["pmin"]) / 2
        end
    end
end

function update_dual_variables!(
    pm::AbstractPowerModel,
    num_intervals::Int,
    admm_data::LASCOPF_ADMMData
)
    # Update dual variables based on consensus violations
    for gen_id in keys(ref(pm, :gen))
        for interval in 1:(num_intervals-1)
            # Consensus between adjacent intervals
            pg_current = get(admm_data.Pg_admm, (gen_id, interval), 0.0)
            pg_next = get(admm_data.Pg_admm, (gen_id, interval+1), 0.0)
            
            # Update dual variable
            admm_data.λ_gen[(gen_id, interval)] += 
                admm_data.ρ_gen * (pg_current - pg_next)
        end
    end
end

function calculate_residuals!(admm_data::LASCOPF_ADMMData)
    # Calculate primal and dual residuals for convergence check
    primal_residual = 0.0
    dual_residual = 0.0
    
    # This is simplified - actual implementation would compute
    # proper residuals based on constraint violations
    for ((gen_id, interval), pg_val) in admm_data.Pg_admm
        if haskey(admm_data.Pg_admm, (gen_id, interval+1))
            pg_next = admm_data.Pg_admm[(gen_id, interval+1)]
            primal_residual += (pg_val - pg_next)^2
        end
    end
    
    admm_data.primal_residual = sqrt(primal_residual)
    admm_data.dual_residual = dual_residual  # Simplified
end

function update_penalty_parameters!(admm_data::LASCOPF_ADMMData, iteration::Int)
    # Adaptive penalty parameter update
    if admm_data.primal_residual > 10 * admm_data.dual_residual
        admm_data.ρ_gen *= 2.0
        admm_data.ρ_network *= 2.0
    elseif admm_data.dual_residual > 10 * admm_data.primal_residual
        admm_data.ρ_gen /= 2.0
        admm_data.ρ_network /= 2.0
    end
    
    # Keep penalty parameters within reasonable bounds
    admm_data.ρ_gen = clamp(admm_data.ρ_gen, 0.01, 100.0)
    admm_data.ρ_network = clamp(admm_data.ρ_network, 0.01, 100.0)
end

function get_generator_interval_data(
    pm::AbstractPowerModel,
    gen_id::Int,
    interval::Int
)::LASCOPF_GenIntervalData
    # This would retrieve or create interval-specific data for the generator
    # For now, return a default structure
    return LASCOPF_GenIntervalData()
end

# Main entry point for PowerLASCOPF
function solve_lascopf(
    network_data::Dict,
    num_intervals::Int;
    optimizer = nothing,
    model_type = DCPPowerModel,
    tolerance = 1e-4,
    max_iterations = 100
)
    # Create PowerModel
    pm = instantiate_model(network_data, model_type, build_opf)
    
    # Initialize ADMM data structure
    num_gens = length(network_data["gen"])
    admm_data = LASCOPF_ADMMData(
        num_gens, num_intervals,
        tolerance=tolerance,
        max_iterations=max_iterations
    )
    
    # Solve using ADMM
    converged = solve_lascopf_admm!(pm, num_intervals, admm_data)
    
    # Return results
    return Dict(
        "converged" => converged,
        "admm_data" => admm_data,
        "power_outputs" => admm_data.Pg_admm,
        "dual_variables" => admm_data.λ_gen,
        "iterations" => min(max_iterations, 
                           findfirst(x -> x < tolerance, 
                                   [admm_data.primal_residual]) || max_iterations)
    )
end

# Example usage function
function example_lascopf_usage()
    # Load network data (this would come from PowerModels.jl format)
    network_data = Dict(
        "gen" => Dict(
            1 => Dict("pmin" => 0, "pmax" => 100, "cost" => [0.02, 20, 0])
        ),
        "bus" => Dict(1 => Dict("bus_type" => 3)),
        "load" => Dict(),
        "branch" => Dict()
    )
    
    # Solve LASCOPF for 24 intervals (hours)
    result = solve_lascopf(
        network_data, 24,
        tolerance=1e-4,
        max_iterations=50
    )
    
    println("LASCOPF Solution:")
    println("Converged: ", result["converged"])
    println("Power outputs: ", result["power_outputs"])
    
    return result
end
end

# Main ADMM coordination function
function solve_lascopf_admm!(
    pm::AbstractPowerModel,
    num_intervals::Int,
    admm_data::LASCOPF_ADMMData
)
    println("Starting LASCOPF ADMM iterations...")
    
    # Initialize dual variables and primal estimates
    initialize_admm_variables!(pm, num_intervals, admm_data)
    
    for iteration in 1:admm_data.max_iterations
        println("ADMM Iteration $iteration")
        
        # Step 1: Solve all generator subproblems in parallel
        solve_all_generator_subproblems!(pm, num_intervals, admm_data)
        
        # Step 2: Solve network subproblem
        solve_network_subproblem!(pm, num_intervals, admm_data)
        
        # Step 3: Update dual variables
        update_dual_variables!(pm, num_intervals, admm_data)
        
        # Step 4: Check convergence
        calculate_residuals!(admm_data)
        
        if admm_data.primal_residual < admm_data.tolerance && 
           admm_data.dual_residual < admm_data.tolerance
            println("ADMM converged in $iteration iterations")
            return true
        end
        
        # Step 5: Update penalty parameters (optional)
        update_penalty_parameters!(admm_data, iteration)
    end
    
    @warn "ADMM did not converge within $(admm_data.max_iterations) iterations"
    return false
end

# Helper function to solve all generator subproblems
function solve_all_generator_subproblems!(
    pm::AbstractPowerModel,
    num_intervals::Int,
    admm_data::LASCOPF_ADMMData
)
    gen_ids = collect(keys(ref(pm, :gen)))
    
    # Parallel execution of generator subproblems
    Threads.@threads for gen_id in gen_ids
        for interval in 1:num_intervals
            # Get interval-specific data
            interval_data = get_generator_interval_data(pm, gen_id, interval)
            
            # Solve based on interval type
            if interval == 1
                solve_generator_first_interval!(
                    pm, gen_id, interval, interval_data,
                    get(admm_data.λ_gen, (gen_id, interval+1), 0.0),
                    admm_data.ρ_gen
                )
            elseif interval == num_intervals
                solve_generator_last_interval!(
                    pm, gen_id, interval, interval_data,
                    get(admm_data.λ_gen, (gen_id, interval-1), 0.0),
                    admm_data.ρ_gen
                )
            else
                solve_generator_middle_interval!(
                    pm, gen_id, interval, interval_data,
                    get(admm_data.λ_gen, (gen_id, interval-1), 0.0),
                    get(admm_data.λ_gen, (gen_id, interval+1), 0.0),
                    admm_data.ρ_gen
                )
            end
            
            # Store solution
            admm_data.Pg_admm[(gen_id, interval)] = interval_data.Pg_opt
        end
    end
end

# Network subproblem solver (placeholder - would integrate with PowerModels.jl)
function solve_network_subproblem!(
    pm::AbstractPowerModel,
    num_intervals::Int,
    admm_data::LASCOPF_ADMMData
)
    # This would solve the network equations with fixed generation
    # Integration with PowerModels.jl AC or DC power flow
    println("Solving network subproblem...")
    
    # For each interval, solve power flow with current generation values
    for interval in 1:num_intervals
        # Update generator injections based on ADMM variables
        for (gen_id, bus_id) in [(g, ref(pm, :gen, g)["gen_bus"]) for g in keys(ref(pm, :gen))]
            if haskey(admm_data.Pg_admm, (gen_id, interval))
                # Update bus injection with generator output
                # This is simplified - actual implementation would be more complex
            end
        end
        
        # Solve power flow for this interval
        # result = solve_opf(pm, optimizer)  # Simplified
    end
end
    
    # Ramp constraints (coupling with adjacent intervals)
    if haskey(gen, "ramp_30")
        ramp_limit = gen["ramp_30"]
        @constraint(pm.model, Pg - data.Pg_prev <= ramp_limit)
        @constraint(pm.model, data.Pg_prev - Pg <= ramp_limit)
        @constraint(pm.model, Pg - data.Pg_next <= ramp_limit)  # Forward coupling
        @constraint(pm.model, data.Pg_next - Pg <= ramp_limit)
    end
    
    # Operating cost for this interval
    if haskey(gen, "model") && gen["model"] == 2  # Quadratic cost
        cost_terms = gen["cost"]
        @objective(pm.model, Min, 
            cost_terms[1] * Pg^2 + cost_terms[2] * Pg + cost_terms[3]
        )
    else  # Linear cost (simplified)
        @objective(pm.model, Min, gen["cost"][1] * Pg)
    end
    
    # ADMM augmented Lagrangian terms
    # Coupling with previous interval
    @objective(pm.model, Min, 
        pm.model[:objective] + 
        λ_prev * (Pg - data.Pg_prev) + 
        (ρ/2) * (Pg - data.Pg_prev)^2 +
        λ_next * (Pg - data.Pg_next) + 
        (ρ/2) * (Pg - data.Pg_next)^2
    )
    
    # Solve the subproblem
    optimize!(pm.model)
    
    # Extract solution
    if termination_status(pm.model) == MOI.OPTIMAL
        data.Pg_opt = value(Pg)
        data.Qg_opt = value(Qg)
        data.dual_λ = λ_prev + ρ * (data.Pg_opt - data.Pg_prev)  # Update dual
        return true
    else
        @warn "Generator $gen_id interval $interval optimization failed"
        return false
    end
end

# Last Interval Generator Solver
function solve_generator_last_interval!(
    pm::AbstractPowerModel,
    gen_id::Int,
    interval::Int,
    data::LASCOPF_GenIntervalData,
    λ_prev::Float64,  # Dual variable from previous interval
    ρ::Float64        # ADMM penalty parameter
)
    # Get generator reference
    gen = ref(pm, :gen, gen_id)
    
    # Decision variables for this interval
    @variable(pm.model, gen["pmin"] <= Pg <= gen["pmax"])
    @variable(pm.model, gen["qmin"] <= Qg <= gen["qmax"])
    
    # Binary commitment variable (if unit commitment is enabled)
    if haskey(gen, "commitment") && gen["commitment"]
        @variable(pm.model, u, Bin)
        @constraint(pm.model, Pg <= gen["pmax"] * u)
        @constraint(pm.model, Pg >= gen["pmin"] * u)
    end
    
    # Ramp constraints (only backward coupling for last interval)
    if haskey(gen, "ramp_30")
        ramp_limit = gen["ramp_30"]
        @constraint(pm.model, Pg - data.Pg_prev <= ramp_limit)
        @constraint(pm.model, data.Pg_prev - Pg <= ramp_limit)
    end
    
    # Terminal constraints (if any)
    # Could include end-of-horizon storage levels, must-run requirements, etc.
    if haskey(gen, "terminal_power")
        @constraint(pm.model, Pg >= gen["terminal_power"])
    end
    
    # Operating cost for this interval
    if haskey(gen, "model") && gen["model"] == 2  # Quadratic cost
        cost_terms = gen["cost"]
        @objective(pm.model, Min, 
            cost_terms[1] * Pg^2 + cost_terms[2] * Pg + cost_terms[3]
        )
    else  # Linear cost (simplified)
        @objective(pm.model, Min, gen["cost"][1] * Pg)
    end
    
    # ADMM augmented Lagrangian terms (only previous coupling)
    @objective(pm.model, Min, 
        pm.model[:objective] + 
        λ_prev * (Pg - data.Pg_prev) + 
        (ρ/2) * (Pg - data.Pg_prev)^2
    )
    
    # Solve the subproblem
    optimize!(pm.model)
    
    # Extract solution
    if termination_status(pm.model) == MOI.OPTIMAL
        data.Pg_opt = value(Pg)
        data.Qg_opt = value(Qg)
        data.dual_λ = λ_prev + ρ * (data.Pg_opt - data.Pg_prev)  # Update dual
        return true
    else
        @warn "Generator $gen_id interval $interval optimization failed"
        return false
    end
end
end