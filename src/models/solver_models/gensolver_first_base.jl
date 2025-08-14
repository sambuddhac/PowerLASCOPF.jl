# PowerLASCOPF Generator Solver - First Base Interval
# Integrated with PSI preallocation framework
# Supports both preallocated and non-preallocated approaches for benchmarking

using PowerSystems
using PowerSimulations 
using InfrastructureSystems
using JuMP
using Dates
try
    using DocStringExtensions
catch
    # DocStringExtensions not available, ignore
end
const PSY = PowerSystems
const PSI = PowerSimulations
const IS = InfrastructureSystems

# Import required types and functions
include(joinpath(@__DIR__, "solver_model_types.jl"))     # Core types (GenFirstBaseInterval, etc.)
include(joinpath(@__DIR__, "sienna_integration_improved.jl"))  # PSI formulations and variable implementations (defines LASCOPFGeneratorFormulation)
include(joinpath(@__DIR__, "parameters.jl"))             # PSI parameter definitions  
include(joinpath(@__DIR__, "variables.jl"))              # PSI variable definitions
include(joinpath(@__DIR__, "objective_functions.jl"))    # PSI objective function implementations
include(joinpath(@__DIR__, "solver_interface.jl"))       # High-level PSI model building interface

# Configuration for preallocation vs non-preallocation
@kwdef mutable struct GenSolverConfig
    use_preallocation::Bool = true  # Switch between approaches
    enable_benchmarking::Bool = false  # Enable detailed timing
    benchmark_results::Dict{String, Any} = Dict()  # Store benchmark data
end

@kwdef mutable struct GenSolver{T<:Union{ExtendedThermalGenerationCost,
    ExtendedRenewableGenerationCost,
    ExtendedHydroGenerationCost,
    ExtendedStorageGenerationCost}, U<:GenIntervals}<:AbstractModel
    interval_type::U # Interval type
    cost_curve::T
    model::Union{JuMP.Model, Nothing} = nothing
    config::GenSolverConfig = GenSolverConfig()  # Configuration settings
end

GenSolver(interval_type, cost_curve) = GenSolver(; interval_type, cost_curve)
GenSolver(interval_type, cost_curve, config) = GenSolver(; interval_type, cost_curve, config)

function GenSolver(::Nothing)
    GenSolver(interval_type=GenFirstBaseInterval(), 
              cost_curve=ExtendedThermalGenerationCost(ThermalGenerationCost(nothing), GenFirstBaseInterval()),
              config=GenSolverConfig())
end

# ============================================================================
# PREALLOCATED APPROACH (using PSI framework)
# ============================================================================

"""
Add decision variables to the optimization container for LASCOPF generator formulation (PREALLOCATED)
"""
function add_decision_variables_preallocated!(container::PSI.OptimizationContainer, 
                                             solver::GenSolver, 
                                             devices::IS.FlattenIteratorWrapper{PSY.ThermalGen})
    time_steps = PSI.get_time_steps(container)
    
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Add Pg variable
    PSI.add_variable!(container, PSI.ActivePowerVariable, LASCOPFGeneratorFormulation(), devices, nothing)
    
    # Add PgNext variable  
    PSI.add_variable!(container, PgNextVariable, LASCOPFGeneratorFormulation(), devices, nothing)
    
    # Add thetag variable
    PSI.add_variable!(container, ThetagVariable, LASCOPFGeneratorFormulation(), devices, nothing)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["variables_preallocated_time"] = time() - start_time
    end
    
    return container
end

"""
Add decision variables to JuMP model directly (NON-PREALLOCATED)
"""
function add_decision_variables_direct!(model::JuMP.Model, solver::GenSolver, devices, time_steps)
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Create variables directly in JuMP model
    Pg = Dict()
    PgNext = Dict()
    thetag = Dict()
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = PSY.get_active_power_limits(device)
        
        # Create Pg variable
        Pg[name, t] = JuMP.@variable(model, 
            base_name = "Pg_$(name)_$(t)",
            lower_bound = limits.min,
            upper_bound = limits.max
        )
        
        # Create PgNext variable
        PgNext[name, t] = JuMP.@variable(model,
            base_name = "PgNext_$(name)_$(t)", 
            lower_bound = limits.min,
            upper_bound = limits.max
        )
        
        # Create thetag variable (unbounded)
        thetag[name, t] = JuMP.@variable(model,
            base_name = "thetag_$(name)_$(t)"
        )
    end
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["variables_direct_time"] = time() - start_time
    end
    
    return Pg, PgNext, thetag
end

"""
Add constraints to the optimization container for LASCOPF generator formulation (PREALLOCATED)
"""
function add_constraints_preallocated!(container::PSI.OptimizationContainer,
                                      solver::GenSolver,
                                      devices::IS.FlattenIteratorWrapper{PSY.ThermalGen})
    
    time_steps = PSI.get_time_steps(container)
    jump_model = PSI.get_jump_model(container)
    
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    
    # Get parameters from the interval data
    if isa(solver.interval_type, GenFirstBaseInterval)
        interval_data = solver.interval_type
        Pg_prev = interval_data.Pg_prev
    else
        Pg_prev = 0.0  # Default value
    end
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        
        # Get device limits
        limits = PSY.get_active_power_limits(device)
        ramp_limits = PSY.get_ramp_limits(device)
        
        PgMax = limits.max
        PgMin = limits.min
        RgMax = isnothing(ramp_limits) ? PgMax : ramp_limits.up
        RgMin = isnothing(ramp_limits) ? -PgMax : -ramp_limits.down
        
        # Power limits constraints
        JuMP.@constraint(jump_model, Pg[name, t] <= PgMax)
        JuMP.@constraint(jump_model, Pg[name, t] >= PgMin)
        JuMP.@constraint(jump_model, PgNext[name, t] <= PgMax)
        JuMP.@constraint(jump_model, PgNext[name, t] >= PgMin)
        
        # Ramping constraints
        JuMP.@constraint(jump_model, PgNext[name, t] - Pg[name, t] <= RgMax)
        JuMP.@constraint(jump_model, PgNext[name, t] - Pg[name, t] >= RgMin)
        JuMP.@constraint(jump_model, Pg[name, t] - Pg_prev <= RgMax)
        JuMP.@constraint(jump_model, Pg[name, t] - Pg_prev >= RgMin)
    end
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["constraints_preallocated_time"] = time() - start_time
    end
    
    return container
end

"""
Add constraints to JuMP model directly (NON-PREALLOCATED)
"""
function add_constraints_direct!(model::JuMP.Model, solver::GenSolver, devices, time_steps, Pg, PgNext, thetag)
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Get parameters from the interval data
    if isa(solver.interval_type, GenFirstBaseInterval)
        interval_data = solver.interval_type
        Pg_prev = interval_data.Pg_prev
    else
        Pg_prev = 0.0  # Default value
    end
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        
        # Get device limits
        limits = PSY.get_active_power_limits(device)
        ramp_limits = PSY.get_ramp_limits(device)
        
        PgMax = limits.max
        PgMin = limits.min
        RgMax = isnothing(ramp_limits) ? PgMax : ramp_limits.up
        RgMin = isnothing(ramp_limits) ? -PgMax : -ramp_limits.down
        
        # Power limits constraints (bounds are already set in variables)
        # But we add explicit constraints for demonstration
        JuMP.@constraint(model, Pg[name, t] <= PgMax)
        JuMP.@constraint(model, Pg[name, t] >= PgMin)
        JuMP.@constraint(model, PgNext[name, t] <= PgMax)
        JuMP.@constraint(model, PgNext[name, t] >= PgMin)
        
        # Ramping constraints
        JuMP.@constraint(model, PgNext[name, t] - Pg[name, t] <= RgMax)
        JuMP.@constraint(model, PgNext[name, t] - Pg[name, t] >= RgMin)
        JuMP.@constraint(model, Pg[name, t] - Pg_prev <= RgMax)
        JuMP.@constraint(model, Pg[name, t] - Pg_prev >= RgMin)
    end
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["constraints_direct_time"] = time() - start_time
    end
    
    return model
end

"""
Set the objective function for LASCOPF generator formulation (PREALLOCATED)
"""
function set_objective_preallocated!(container::PSI.OptimizationContainer,
                                    solver::GenSolver,
                                    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen})
    
    time_steps = PSI.get_time_steps(container)
    jump_model = PSI.get_jump_model(container)
    
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    thetag = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen)
    
    # Initialize objective expression
    objective_expr = JuMP.AffExpr(0.0)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        
        # Get cost coefficients from device
        cost_func = PSY.get_cost(device)
        if isa(cost_func, PSY.QuadraticCost)
            c0 = cost_func.fixed
            c1 = cost_func.proportional  
            c2 = cost_func.quadratic
        elseif isa(cost_func, PSY.LinearCost)
            c0 = cost_func.fixed
            c1 = cost_func.proportional
            c2 = 0.0
        else
            c0, c1, c2 = 0.0, 1.0, 0.0  # Default linear cost
        end
        
        # Add generation cost
        JuMP.add_to_expression!(objective_expr, c2 * (Pg[name, t]^2))
        JuMP.add_to_expression!(objective_expr, c1 * Pg[name, t])
        JuMP.add_to_expression!(objective_expr, c0)
        
        # Add LASCOPF-specific terms if interval data is available
        if isa(solver.interval_type, GenFirstBaseInterval)
            interval_data = solver.interval_type
            
            # APP regularization terms  
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta/2) * (Pg[name, t] - interval_data.Pg_nu)^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta/2) * (PgNext[name, t] - sum(interval_data.Pg_next_nu))^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta_inner/2) * (Pg[name, t] - interval_data.Pg_nu_inner)^2)
            
            # Security constraint regularization
            for i in 1:interval_data.cont_count
                JuMP.add_to_expression!(objective_expr, 
                    interval_data.gamma_sc * Pg[name, t] * interval_data.BSC[i])
                JuMP.add_to_expression!(objective_expr, 
                    Pg[name, t] * interval_data.lambda_1_sc[i])
            end
            
            # Interval coupling terms
            JuMP.add_to_expression!(objective_expr, 
                interval_data.gamma * Pg[name, t] * sum(interval_data.B))
            JuMP.add_to_expression!(objective_expr, 
                interval_data.gamma * PgNext[name, t] * sum(interval_data.D))
            JuMP.add_to_expression!(objective_expr, 
                sum(interval_data.lambda_1) * Pg[name, t])
            JuMP.add_to_expression!(objective_expr, 
                sum(interval_data.lambda_2) * PgNext[name, t])
            
            # ADMM penalty terms
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.rho/2) * (Pg[name, t] - interval_data.Pg_N_init + 
                                       interval_data.Pg_N_avg + interval_data.ug_N)^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.rho/2) * (thetag[name, t] - interval_data.Vg_N_avg - 
                                       interval_data.thetag_N_avg + interval_data.vg_N)^2)
        end
    end
    
    # Set the objective
    JuMP.@objective(jump_model, Min, objective_expr)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["objective_preallocated_time"] = time() - start_time
    end
    
    return container
end

"""
Set the objective function for LASCOPF generator formulation (NON-PREALLOCATED)
"""
function set_objective_direct!(model::JuMP.Model, solver::GenSolver, devices, time_steps, Pg, PgNext, thetag)
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Initialize objective expression
    objective_expr = JuMP.AffExpr(0.0)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        
        # Get cost coefficients from device
        cost_func = PSY.get_cost(device)
        if isa(cost_func, PSY.QuadraticCost)
            c0 = cost_func.fixed
            c1 = cost_func.proportional  
            c2 = cost_func.quadratic
        elseif isa(cost_func, PSY.LinearCost)
            c0 = cost_func.fixed
            c1 = cost_func.proportional
            c2 = 0.0
        else
            c0, c1, c2 = 0.0, 1.0, 0.0  # Default linear cost
        end
        
        # Add generation cost
        JuMP.add_to_expression!(objective_expr, c2 * (Pg[name, t]^2))
        JuMP.add_to_expression!(objective_expr, c1 * Pg[name, t])
        JuMP.add_to_expression!(objective_expr, c0)
        
        # Add LASCOPF-specific terms if interval data is available
        if isa(solver.interval_type, GenFirstBaseInterval)
            interval_data = solver.interval_type
            
            # APP regularization terms  
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta/2) * (Pg[name, t] - interval_data.Pg_nu)^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta/2) * (PgNext[name, t] - sum(interval_data.Pg_next_nu))^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.beta_inner/2) * (Pg[name, t] - interval_data.Pg_nu_inner)^2)
            
            # Security constraint regularization
            for i in 1:interval_data.cont_count
                JuMP.add_to_expression!(objective_expr, 
                    interval_data.gamma_sc * Pg[name, t] * interval_data.BSC[i])
                JuMP.add_to_expression!(objective_expr, 
                    Pg[name, t] * interval_data.lambda_1_sc[i])
            end
            
            # Interval coupling terms
            JuMP.add_to_expression!(objective_expr, 
                interval_data.gamma * Pg[name, t] * sum(interval_data.B))
            JuMP.add_to_expression!(objective_expr, 
                interval_data.gamma * PgNext[name, t] * sum(interval_data.D))
            JuMP.add_to_expression!(objective_expr, 
                sum(interval_data.lambda_1) * Pg[name, t])
            JuMP.add_to_expression!(objective_expr, 
                sum(interval_data.lambda_2) * PgNext[name, t])
            
            # ADMM penalty terms
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.rho/2) * (Pg[name, t] - interval_data.Pg_N_init + 
                                       interval_data.Pg_N_avg + interval_data.ug_N)^2)
            JuMP.add_to_expression!(objective_expr, 
                (interval_data.rho/2) * (thetag[name, t] - interval_data.Vg_N_avg - 
                                       interval_data.thetag_N_avg + interval_data.vg_N)^2)
        end
    end
    
    # Set the objective
    JuMP.@objective(model, Min, objective_expr)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["objective_direct_time"] = time() - start_time
    end
    
    return model
end

# ============================================================================
# NON-PREALLOCATED APPROACH (direct JuMP model construction)
# ============================================================================

"""
Build and solve LASCOPF generator model using direct JuMP construction (NON-PREALLOCATED)
"""
function build_and_solve_gensolver_direct!(solver::GenSolver,
                                          sys::PSY.System;
                                          optimizer_factory=nothing,
                                          solve_options=Dict(),
                                          time_horizon=24)
    
    if solver.config.enable_benchmarking
        total_start_time = time()
    end
    
    # Get thermal generators from system
    thermal_gens = collect(PSY.get_components(PSY.ThermalGen, sys))
    
    # Create time steps
    time_steps = 1:time_horizon
    
    # Create JuMP model directly
    model = JuMP.Model()
    
    # Add decision variables
    Pg, PgNext, thetag = add_decision_variables_direct!(model, solver, thermal_gens, time_steps)
    
    # Add constraints
    add_constraints_direct!(model, solver, thermal_gens, time_steps, Pg, PgNext, thetag)
    
    # Set objective function
    set_objective_direct!(model, solver, thermal_gens, time_steps, Pg, PgNext, thetag)
    
    # Solve the problem
    results = solve_gensolver_direct!(model, solver, thermal_gens, time_steps, Pg, PgNext, thetag;
                                     optimizer_factory=optimizer_factory,
                                     solve_options=solve_options)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["total_direct_time"] = time() - total_start_time
    end
    
    return results
end

"""
Solve the direct JuMP model (NON-PREALLOCATED)
"""
function solve_gensolver_direct!(model::JuMP.Model,
                                solver::GenSolver,
                                devices,
                                time_steps,
                                Pg, PgNext, thetag;
                                optimizer_factory=nothing,
                                solve_options=Dict())
    
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    start_t = now()
    
    # Set optimizer if provided
    if optimizer_factory !== nothing
        JuMP.set_optimizer(model, optimizer_factory)
    end
    
    # Set solver options
    for (key, value) in solve_options
        JuMP.set_optimizer_attribute(model, key, value)
    end
    
    # Optimize the model
    JuMP.optimize!(model)
    elapsed = now() - start_t
    
    # Check termination status
    tstatus = JuMP.termination_status(model)
    if tstatus != JuMP.OPTIMAL
        if tstatus == JuMP.INFEASIBLE
            error("Generator solver infeasible")
        elseif tstatus == JuMP.TIME_LIMIT
            error("Generator solver timed out")
        elseif tstatus == JuMP.INFEASIBLE_OR_UNBOUNDED
            error("Generator solver infeasible or unbounded")
        else
            error("Generator solver status: $tstatus")
        end
    end
    
    # Extract results
    results = Dict{String, Any}()
    
    results["Pg"] = Dict()
    results["PgNext"] = Dict() 
    results["thetag"] = Dict()
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        results["Pg"][name, t] = JuMP.value(Pg[name, t])
        results["PgNext"][name, t] = JuMP.value(PgNext[name, t])
        results["thetag"][name, t] = JuMP.value(thetag[name, t])
    end
    
    # Add solution metadata
    results["objective_value"] = JuMP.objective_value(model)
    results["solve_time_ms"] = elapsed.value
    results["termination_status"] = tstatus
    results["primal_status"] = JuMP.primal_status(model)
    results["dual_status"] = JuMP.dual_status(model)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["solve_direct_time"] = time() - start_time
    end
    
    return results
end

# ============================================================================
# UNIFIED INTERFACE FUNCTIONS
# ============================================================================

"""
Solve the LASCOPF generator optimization problem (PREALLOCATED)
"""
function solve_gensolver_preallocated!(container::PSI.OptimizationContainer,
                                      solver::GenSolver,
                                      devices::IS.FlattenIteratorWrapper{PSY.ThermalGen};
                                      optimizer_factory=nothing,
                                      solve_options=Dict())
    
    jump_model = PSI.get_jump_model(container)
    start_t = now()
    
    if solver.config.enable_benchmarking
        start_time = time()
    end
    
    # Set optimizer if provided
    if optimizer_factory !== nothing
        JuMP.set_optimizer(jump_model, optimizer_factory)
    end
    
    # Set solver options
    for (key, value) in solve_options
        JuMP.set_optimizer_attribute(jump_model, key, value)
    end
    
    # Optimize the model
    JuMP.optimize!(jump_model)
    elapsed = now() - start_t
    
    # Check termination status
    tstatus = JuMP.termination_status(jump_model)
    if tstatus != JuMP.OPTIMAL
        if tstatus == JuMP.INFEASIBLE
            error("Generator solver infeasible")
        elseif tstatus == JuMP.TIME_LIMIT
            error("Generator solver timed out")
        elseif tstatus == JuMP.INFEASIBLE_OR_UNBOUNDED
            error("Generator solver infeasible or unbounded")
        else
            error("Generator solver status: $tstatus")
        end
    end
    
    # Extract results
    results = Dict{String, Any}()
    
    # Get variable values
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    thetag = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen)
    
    results["Pg"] = Dict()
    results["PgNext"] = Dict() 
    results["thetag"] = Dict()
    
    time_steps = PSI.get_time_steps(container)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        results["Pg"][name, t] = JuMP.value(Pg[name, t])
        results["PgNext"][name, t] = JuMP.value(PgNext[name, t])
        results["thetag"][name, t] = JuMP.value(thetag[name, t])
    end
    
    # Add solution metadata
    results["objective_value"] = JuMP.objective_value(jump_model)
    results["solve_time_ms"] = elapsed.value
    results["termination_status"] = tstatus
    results["primal_status"] = JuMP.primal_status(jump_model)
    results["dual_status"] = JuMP.dual_status(jump_model)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["solve_preallocated_time"] = time() - start_time
    end
    
    return results
end

"""
Build and solve the LASCOPF generator model using PSI framework (PREALLOCATED)
"""
function build_and_solve_gensolver_preallocated!(solver::GenSolver,
                                                sys::PSY.System;
                                                optimizer_factory=nothing,
                                                solve_options=Dict(),
                                                time_horizon=24)
    
    if solver.config.enable_benchmarking
        total_start_time = time()
    end
    
    # Get thermal generators from system
    thermal_gens = PSY.get_components(PSY.ThermalGen, sys)
    
    # Create time steps
    time_steps = 1:time_horizon
    
    # Create optimization container
    container = PSI.OptimizationContainer(
        JuMP.Model(),
        PSI.make_system_time_series_da_schedule(sys, time_steps),
        PSI.get_resolution(sys),
        PSI.get_name(sys)
    )
    
    # Add decision variables
    add_decision_variables_preallocated!(container, solver, thermal_gens)
    
    # Add constraints
    add_constraints_preallocated!(container, solver, thermal_gens)
    
    # Set objective function
    set_objective_preallocated!(container, solver, thermal_gens)
    
    # Solve the problem
    results = solve_gensolver_preallocated!(container, solver, thermal_gens;
                                           optimizer_factory=optimizer_factory,
                                           solve_options=solve_options)
    
    if solver.config.enable_benchmarking
        solver.config.benchmark_results["total_preallocated_time"] = time() - total_start_time
    end
    
    return results
end

"""
Main interface: Build and solve using configured approach (UNIFIED)
"""
function build_and_solve_gensolver!(solver::GenSolver,
                                   sys::PSY.System;
                                   optimizer_factory=nothing,
                                   solve_options=Dict(),
                                   time_horizon=24)
    
    if solver.config.use_preallocation
        return build_and_solve_gensolver_preallocated!(solver, sys;
                                                      optimizer_factory=optimizer_factory,
                                                      solve_options=solve_options,
                                                      time_horizon=time_horizon)
    else
        return build_and_solve_gensolver_direct!(solver, sys;
                                                optimizer_factory=optimizer_factory,
                                                solve_options=solve_options,
                                                time_horizon=time_horizon)
    end
end

"""
Update ADMM/APP parameters in the solver for next iteration
"""
function update_admm_parameters!(solver::GenSolver, new_params::Dict)
    if isa(solver.interval_type, GenFirstBaseInterval)
        interval_data = solver.interval_type
        
        # Update ADMM parameters
        get(new_params, "rho", interval_data.rho) |> x -> interval_data.rho = x
        get(new_params, "beta", interval_data.beta) |> x -> interval_data.beta = x
        get(new_params, "beta_inner", interval_data.beta_inner) |> x -> interval_data.beta_inner = x
        get(new_params, "gamma", interval_data.gamma) |> x -> interval_data.gamma = x
        get(new_params, "gamma_sc", interval_data.gamma_sc) |> x -> interval_data.gamma_sc = x
        
        # Update Lagrange multipliers
        haskey(new_params, "lambda_1") && (interval_data.lambda_1 = new_params["lambda_1"])
        haskey(new_params, "lambda_2") && (interval_data.lambda_2 = new_params["lambda_2"])
        haskey(new_params, "lambda_1_sc") && (interval_data.lambda_1_sc = new_params["lambda_1_sc"])
        
        # Update disagreement terms
        haskey(new_params, "B") && (interval_data.B = new_params["B"])
        haskey(new_params, "D") && (interval_data.D = new_params["D"])
        haskey(new_params, "BSC") && (interval_data.BSC = new_params["BSC"])
        
        # Update previous iteration values
        haskey(new_params, "Pg_nu") && (interval_data.Pg_nu = new_params["Pg_nu"])
        haskey(new_params, "Pg_nu_inner") && (interval_data.Pg_nu_inner = new_params["Pg_nu_inner"])
        haskey(new_params, "Pg_next_nu") && (interval_data.Pg_next_nu = new_params["Pg_next_nu"])
        haskey(new_params, "Pg_prev") && (interval_data.Pg_prev = new_params["Pg_prev"])
        
        # Update network variables
        haskey(new_params, "Pg_N_init") && (interval_data.Pg_N_init = new_params["Pg_N_init"])
        haskey(new_params, "Pg_N_avg") && (interval_data.Pg_N_avg = new_params["Pg_N_avg"])
        haskey(new_params, "thetag_N_avg") && (interval_data.thetag_N_avg = new_params["thetag_N_avg"])
        haskey(new_params, "ug_N") && (interval_data.ug_N = new_params["ug_N"])
        haskey(new_params, "vg_N") && (interval_data.vg_N = new_params["vg_N"])
        haskey(new_params, "Vg_N_avg") && (interval_data.Vg_N_avg = new_params["Vg_N_avg"])
    end
    
    return solver
end

# ============================================================================
# BENCHMARKING AND COMPARISON FUNCTIONS
# ============================================================================

"""
Run performance benchmark comparing preallocated vs direct approaches
"""
function benchmark_gensolver_approaches(sys::PSY.System; 
                                       num_runs=5, 
                                       time_horizon=24,
                                       optimizer_factory=nothing)
    
    println("🚀 Starting LASCOPF Generator Solver Benchmark")
    println("=" * 60)
    
    # Create test interval data
    interval_data = GenFirstBaseInterval(
        lambda_1 = rand(5),
        lambda_2 = rand(5), 
        B = rand(5),
        D = rand(5),
        BSC = rand(5),
        cont_count = 5,
        rho = 1.0,
        beta = 1.0,
        beta_inner = 0.5,
        gamma = 1.0,
        gamma_sc = 1.0,
        lambda_1_sc = rand(5),
        Pg_nu = 100.0,
        Pg_nu_inner = 100.0,
        Pg_next_nu = rand(5),
        Pg_prev = 95.0
    )
    
    # Create cost structure
    thermal_cost = ThermalGenerationCost(nothing)
    extended_cost = ExtendedThermalGenerationCost(thermal_cost, interval_data)
    
    # Results storage
    preallocated_times = []
    direct_times = []
    preallocated_results = []
    direct_results = []
    
    println("🔧 Testing Preallocated Approach...")
    for run in 1:num_runs
        print("  Run $run/$num_runs... ")
        
        # Create solver with preallocation enabled
        solver_prealloc = GenSolver(
            interval_type = interval_data,
            cost_curve = extended_cost,
            config = GenSolverConfig(use_preallocation=true, enable_benchmarking=true)
        )
        
        start_time = time()
        result = build_and_solve_gensolver!(solver_prealloc, sys;
                                           optimizer_factory=optimizer_factory,
                                           time_horizon=time_horizon)
        end_time = time()
        
        push!(preallocated_times, end_time - start_time)
        push!(preallocated_results, result)
        println("✓ $(round((end_time - start_time)*1000, digits=2))ms")
    end
    
    println("\n🔧 Testing Direct Approach...")
    for run in 1:num_runs
        print("  Run $run/$num_runs... ")
        
        # Create solver with preallocation disabled
        solver_direct = GenSolver(
            interval_type = interval_data,
            cost_curve = extended_cost,
            config = GenSolverConfig(use_preallocation=false, enable_benchmarking=true)
        )
        
        start_time = time()
        result = build_and_solve_gensolver!(solver_direct, sys;
                                           optimizer_factory=optimizer_factory,
                                           time_horizon=time_horizon)
        end_time = time()
        
        push!(direct_times, end_time - start_time)
        push!(direct_results, result)
        println("✓ $(round((end_time - start_time)*1000, digits=2))ms")
    end
    
    # Analyze results
    println("\n📊 Benchmark Results")
    println("=" * 60)
    
    avg_prealloc = mean(preallocated_times) * 1000  # Convert to ms
    avg_direct = mean(direct_times) * 1000
    speedup = avg_direct / avg_prealloc
    
    println("Preallocated Approach:")
    println("  • Average time: $(round(avg_prealloc, digits=2)) ms")
    println("  • Min time: $(round(minimum(preallocated_times)*1000, digits=2)) ms")
    println("  • Max time: $(round(maximum(preallocated_times)*1000, digits=2)) ms")
    
    println("\nDirect Approach:")
    println("  • Average time: $(round(avg_direct, digits=2)) ms")
    println("  • Min time: $(round(minimum(direct_times)*1000, digits=2)) ms")
    println("  • Max time: $(round(maximum(direct_times)*1000, digits=2)) ms")
    
    println("\nPerformance Comparison:")
    if speedup > 1
        println("  • Preallocated is $(round(speedup, digits=2))x FASTER ⚡")
    else
        println("  • Direct is $(round(1/speedup, digits=2))x FASTER ⚡")
    end
    
    # Verify solution consistency
    obj_diff = abs(preallocated_results[1]["objective_value"] - direct_results[1]["objective_value"])
    println("  • Objective difference: $(round(obj_diff, digits=6)) (should be ~0)")
    
    # Return detailed benchmark data
    return Dict(
        "preallocated_times" => preallocated_times,
        "direct_times" => direct_times,
        "avg_preallocated_ms" => avg_prealloc,
        "avg_direct_ms" => avg_direct,
        "speedup_factor" => speedup,
        "objective_difference" => obj_diff,
        "preallocated_results" => preallocated_results[1],
        "direct_results" => direct_results[1]
    )
end

"""
Compare memory usage between approaches (requires BenchmarkTools.jl)
"""
function benchmark_memory_usage(sys::PSY.System; time_horizon=24)
    try
        using BenchmarkTools
        
        # Create test data
        interval_data = GenFirstBaseInterval(
            lambda_1 = rand(5), lambda_2 = rand(5), B = rand(5), D = rand(5), BSC = rand(5),
            cont_count = 5, rho = 1.0, beta = 1.0, beta_inner = 0.5, gamma = 1.0, gamma_sc = 1.0,
            lambda_1_sc = rand(5), Pg_nu = 100.0, Pg_nu_inner = 100.0, Pg_next_nu = rand(5), Pg_prev = 95.0
        )
        
        thermal_cost = ThermalGenerationCost(nothing)
        extended_cost = ExtendedThermalGenerationCost(thermal_cost, interval_data)
        
        # Benchmark preallocated approach
        solver_prealloc = GenSolver(interval_type=interval_data, cost_curve=extended_cost,
                                   config=GenSolverConfig(use_preallocation=true))
        
        prealloc_bench = @benchmark build_and_solve_gensolver!($solver_prealloc, $sys; time_horizon=$time_horizon)
        
        # Benchmark direct approach  
        solver_direct = GenSolver(interval_type=interval_data, cost_curve=extended_cost,
                                 config=GenSolverConfig(use_preallocation=false))
        
        direct_bench = @benchmark build_and_solve_gensolver!($solver_direct, $sys; time_horizon=$time_horizon)
        
        println("Memory Usage Comparison:")
        println("Preallocated: $(BenchmarkTools.prettymemory(memory(prealloc_bench)))")
        println("Direct: $(BenchmarkTools.prettymemory(memory(direct_bench)))")
        println("Memory ratio: $(round(memory(direct_bench) / memory(prealloc_bench), digits=2))x")
        
        return (prealloc_bench, direct_bench)
        
    catch e
        println("BenchmarkTools.jl not available. Install it for detailed memory benchmarking.")
        println("Run: using Pkg; Pkg.add(\"BenchmarkTools\")")
        return nothing
    end
end

"""
Example usage of the integrated LASCOPF generator solver with approach selection
"""
function example_lascopf_generator_solve(sys::PSY.System; use_preallocation=true)
    # Create interval data with ADMM/APP parameters
    interval_data = GenFirstBaseInterval(
        lambda_1 = rand(5),      # Example array parameters
        lambda_2 = rand(5),
        B = rand(5),
        D = rand(5), 
        BSC = rand(5),
        cont_count = 5,          # Number of contingencies
        rho = 1.0,              # ADMM parameter
        beta = 1.0,             # APP parameter
        beta_inner = 0.5,       # Inner APP parameter
        gamma = 1.0,            # APP parameter
        gamma_sc = 1.0,         # Security constraint parameter
        lambda_1_sc = rand(5),  # Security constraint multipliers
        Pg_nu = 100.0,          # Previous iteration values
        Pg_nu_inner = 100.0,
        Pg_next_nu = rand(5),
        Pg_prev = 95.0
    )
    
    # Create cost structure - example for thermal generation
    thermal_cost = ThermalGenerationCost(nothing)  # You'll need to define this
    extended_cost = ExtendedThermalGenerationCost(thermal_cost, interval_data)
    
    # Create solver with configuration
    config = GenSolverConfig(
        use_preallocation = use_preallocation,
        enable_benchmarking = true
    )
    
    solver = GenSolver(
        interval_type = interval_data,
        cost_curve = extended_cost,
        config = config
    )
    
    approach_name = use_preallocation ? "PREALLOCATED" : "DIRECT"
    println("Solving using $approach_name approach...")
    
    # Build and solve
    results = build_and_solve_gensolver!(
        solver, 
        sys;
        optimizer_factory = HiGHS.Optimizer,  # Or your preferred optimizer
        solve_options = Dict("time_limit" => 300.0),
        time_horizon = 24
    )
    
    # Print benchmark results if available
    if haskey(solver.config.benchmark_results, "total_preallocated_time") || 
       haskey(solver.config.benchmark_results, "total_direct_time")
        println("Detailed timing breakdown:")
        for (key, value) in solver.config.benchmark_results
            println("  $key: $(round(value*1000, digits=2)) ms")
        end
    end
    
    return results
end

"""
Example ADMM iteration loop with approach comparison
"""
function example_admm_loop(sys::PSY.System, max_iterations=50; compare_approaches=false)
    # Initialize solver
    config = GenSolverConfig(
        use_preallocation = true,  # Default to preallocated
        enable_benchmarking = compare_approaches
    )
    
    solver = GenSolver(
        interval_type = GenFirstBaseInterval(),
        cost_curve = ExtendedThermalGenerationCost(ThermalGenerationCost(nothing), GenFirstBaseInterval()),
        config = config
    )
    
    results_history = []
    benchmark_data = Dict()
    
    # Optionally compare approaches on first iteration
    if compare_approaches
        println("🔍 Comparing approaches on first iteration...")
        
        # Test preallocated
        solver.config.use_preallocation = true
        start_time = time()
        results_prealloc = build_and_solve_gensolver!(solver, sys)
        prealloc_time = time() - start_time
        
        # Test direct  
        solver.config.use_preallocation = false
        start_time = time() 
        results_direct = build_and_solve_gensolver!(solver, sys)
        direct_time = time() - start_time
        
        # Report comparison
        speedup = direct_time / prealloc_time
        println("  Preallocated: $(round(prealloc_time*1000, digits=2)) ms")
        println("  Direct: $(round(direct_time*1000, digits=2)) ms")
        println("  Speedup: $(round(speedup, digits=2))x")
        
        # Use faster approach for remaining iterations
        use_prealloc = prealloc_time < direct_time
        solver.config.use_preallocation = use_prealloc
        println("  Using $(use_prealloc ? "PREALLOCATED" : "DIRECT") for remaining iterations")
        
        benchmark_data["approach_comparison"] = Dict(
            "preallocated_time" => prealloc_time,
            "direct_time" => direct_time,
            "speedup" => speedup,
            "chosen_approach" => use_prealloc ? "preallocated" : "direct"
        )
        
        push!(results_history, use_prealloc ? results_prealloc : results_direct)
    end
    
    # Run ADMM iterations
    start_iter = compare_approaches ? 2 : 1
    
    for iter in start_iter:max_iterations
        println("ADMM Iteration $iter")
        
        # Solve generator subproblem
        results = build_and_solve_gensolver!(solver, sys)
        push!(results_history, results)
        
        # Update ADMM/APP parameters (this would typically involve coordination
        # with other subproblems like transmission network, other generators, etc.)
        new_params = Dict(
            "rho" => 1.1 * solver.interval_type.rho,  # Example parameter update
            "Pg_nu" => results["Pg"][collect(keys(results["Pg"]))[1]],  # Use current solution as next iteration's reference
            # ... update other parameters based on coordination with other subproblems
        )
        
        update_admm_parameters!(solver, new_params)
        
        # Check convergence (simplified example)
        if iter > 1 && abs(results["objective_value"] - results_history[end-1]["objective_value"]) < 1e-6
            println("ADMM converged after $iter iterations")
            break
        end
    end
    
    return results_history, benchmark_data
end

"""
Comprehensive performance testing suite
"""
function run_performance_tests(sys::PSY.System)
    println("🧪 LASCOPF Generator Solver Performance Test Suite")
    println("=" * 70)
    
    # Test 1: Basic benchmark
    println("\n📈 Test 1: Basic Performance Comparison")
    basic_results = benchmark_gensolver_approaches(sys, num_runs=3)
    
    # Test 2: Memory usage (if BenchmarkTools available)
    println("\n💾 Test 2: Memory Usage Analysis") 
    memory_results = benchmark_memory_usage(sys)
    
    # Test 3: Scaling test with different problem sizes
    println("\n📏 Test 3: Problem Size Scaling")
    scaling_results = Dict()
    for horizon in [12, 24, 48]
        println("  Testing time horizon: $horizon hours")
        result = benchmark_gensolver_approaches(sys, num_runs=2, time_horizon=horizon)
        scaling_results[horizon] = result
        
        println("    Preallocated: $(round(result["avg_preallocated_ms"], digits=2)) ms")
        println("    Direct: $(round(result["avg_direct_ms"], digits=2)) ms")
        println("    Speedup: $(round(result["speedup_factor"], digits=2))x")
    end
    
    println("\n✅ Performance testing complete!")
    
    return Dict(
        "basic_benchmark" => basic_results,
        "memory_benchmark" => memory_results,
        "scaling_benchmark" => scaling_results
    )
end




