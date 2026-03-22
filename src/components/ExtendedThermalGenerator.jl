"""
Extended Thermal Generator component for PowerLASCOPF.jl

This module defines the ExtendedThermalGenerator struct that extends PowerSystems.ThermalGen
for LASCOPF optimization with ADMM/APP state variables, thermal-specific constraints,
and enhanced cost modeling.
"""
# APP-ADMM Power Angle Message Passing for Extended Thermal Generators
# This implements the power angle message passing for the Alternating Direction Method of Multipliers (ADMM)
# specifically for thermal generators in the Accelerated Proximal Point (APP) variant

using LinearAlgebra
using JuMP
using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries

# Include necessary modules from the codebase
include("../core/types.jl")
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedThermalGenerationCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedThermalGenerator{T<:PSY.ThermalGen, U<:GenIntervals}

An extended thermal generator component that extends PowerSystems.ThermalGen for LASCOPF optimization.
Includes thermal-specific constraints like ramp rates, minimum up/down times, startup costs,
and enhanced thermal cost modeling with ADMM/APP state variables.
"""
@kwdef mutable struct ExtendedThermalGenerator{T<:PSY.ThermalGen, U<:GenIntervals} <: PowerGenerator
    # Core thermal generator from PowerSystems
    generator::T
    
    # Extended thermal cost function with regularization
    thermal_cost_function::ExtendedThermalGenerationCost{U}
    
    # Generator identification
    gen_id::Int64
    dispatch_interval::Int64
    flag_last::Bool
    dummy_zero_int_flag::Int64
    cont_solver_accuracy::Int64
    
    # Scenario management
    scenario_cont_count::Int64
    post_cont_scen_count::Int64
    base_cont_scenario::Int64
    cont_count_gen::Int64

    # Node connection
    conn_nodeg_ptr::Node
    
    # Solver interface for thermal generators
    gen_solver::GenSolver{ExtendedThermalGenerationCost{U}, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Thermal-specific operating variables
    unit_status::Bool = true                    # Unit commitment status (on/off)
    startup_status::Bool = false                # Startup indicator
    shutdown_status::Bool = false               # Shutdown indicator
    hours_online::Int = 0                       # Consecutive hours online
    hours_offline::Int = 0                      # Consecutive hours offline
    startup_cost_incurred::Float64 = 0.0        # Startup cost for current period
    shutdown_cost_incurred::Float64 = 0.0       # Shutdown cost for current period
    
    # Thermal constraints tracking
    ramp_up_violation::Float64 = 0.0            # Ramp up constraint violation
    ramp_down_violation::Float64 = 0.0          # Ramp down constraint violation
    min_power_violation::Float64 = 0.0          # Minimum power constraint violation
    max_power_violation::Float64 = 0.0          # Maximum power constraint violation
    
    # Heat rate and efficiency tracking
    heat_rate::Float64 = 0.0                    # Current heat rate (MMBtu/MWh)
    fuel_consumption::Float64 = 0.0             # Fuel consumption (MMBtu/h)
    efficiency::Float64 = 0.0                   # Current efficiency (%)
    
    # Environmental variables
    emissions_rate::Float64 = 0.0               # CO2 emissions rate (tons/MWh)
    total_emissions::Float64 = 0.0              # Total emissions (tons)
    
    # Timeseries management for thermal operations
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    fuel_price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    emission_price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    maintenance_schedule::Vector{Tuple{DateTime, DateTime}} = Tuple{DateTime, DateTime}[]
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Capacity factor
    availability_factor::Float64 = 1.0          # Availability factor
    forced_outage_rate::Float64 = 0.0           # Forced outage rate
    
    # Cache for performance
    _thermal_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedThermalGenerator(
        generator::T,
        thermal_cost_function::ExtendedThermalGenerationCost{U},
        id_of_gen::Int64,
        interval::Int64,
        last_flag::Bool,
        cont_scenario_count::Int64,
        PC_scenario_count::Int64,
        baseCont::Int64,
        dummyZero::Int64,
        accuracy::Int64,
        nodeConng::Node,
        countOfContingency::Int64;
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.ThermalGen, U<:GenIntervals}
        
        # Create solver with thermal cost model
        gensolver = GenSolver(
            interval_type = thermal_cost_function.regularization_term,
            cost_curve = thermal_cost_function,
            config = config
        )
        
        # Fix: Specify both type parameters
        self = new{T,U}()  # Changed from new{U}() to new{T,U}()
        self.generator = generator
        self.thermal_cost_function = thermal_cost_function
        self.gen_id = id_of_gen
        self.dispatch_interval = interval
        self.flag_last = last_flag
        self.dummy_zero_int_flag = dummyZero
        self.cont_solver_accuracy = accuracy
        self.scenario_cont_count = cont_scenario_count
        self.post_cont_scen_count = PC_scenario_count
        self.base_cont_scenario = baseCont
        self.conn_nodeg_ptr = nodeConng
        self.cont_count_gen = countOfContingency
        self.gen_solver = gensolver
        
        # Initialize connection node
        set_g_conn!(self.conn_nodeg_ptr, id_of_gen)
        
        # Initialize thermal-specific parameters from PSY.ThermalGen
        initialize_thermal_parameters!(self)
        
        # Extract timeseries data
        extract_thermal_timeseries!(self)
        
        # Set initial generator data
        set_thermal_gen_data!(self)
        
        return self
    end
end

"""
    initialize_thermal_parameters!(gen::ExtendedThermalGenerator)

Initialize thermal-specific parameters from the PowerSystems.ThermalGen.
"""
function initialize_thermal_parameters!(gen::ExtendedThermalGenerator)
    psy_gen = gen.generator
    
    # Extract basic parameters
    gen.Pg = PSY.get_active_power(psy_gen)
    gen.P_gen_prev = gen.Pg
    gen.P_gen_next = gen.Pg
    
    # Initialize thermal status
    gen.unit_status = PSY.get_available(psy_gen)
    
    # Extract thermal limits and characteristics
    op_cost = PSY.get_operation_cost(psy_gen)
    
    # Initialize heat rate and efficiency
    if isa(op_cost, PSY.ThermalGenerationCost)
        # Try to extract heat rate from cost data
        fuel_cost = PSY.get_fuel_cost(op_cost.variable)
        if !isnothing(fuel_cost) && fuel_cost > 0.0
            # Estimate heat rate from cost structure
            var_cost = PSY.get_variable(op_cost)
            if isa(var_cost, PSY.LinearCurve)
                # Heat rate ≈ variable cost / fuel cost (simplified)
                gen.heat_rate = var_cost.linear_term / fuel_cost
            elseif isa(var_cost, PSY.QuadraticCurve)
                # Use linear term for average heat rate
                gen.heat_rate = var_cost.linear_term / fuel_cost
            end
        else
            gen.heat_rate = 10.0  # Default heat rate (MMBtu/MWh)
        end
        
        # Calculate efficiency (3412 BTU/kWh conversion factor)
        gen.efficiency = 3412.0 / (gen.heat_rate * 1000.0) * 100.0  # Percentage
        
        # Initialize emissions rate (default: 0.5 tons CO2/MWh for natural gas)
        gen.emissions_rate = 0.5
    end
    
    # Initialize performance metrics
    rating = PSY.get_rating(psy_gen)
    if rating > 0 && gen.Pg >= 0
        gen.capacity_factor = gen.Pg / rating
    end
    
    gen.availability_factor = gen.unit_status ? 1.0 : 0.0
end

"""
    extract_thermal_timeseries!(gen::ExtendedThermalGenerator)

Extract thermal-specific timeseries data from PowerSystems generator.
"""
function extract_thermal_timeseries!(gen::ExtendedThermalGenerator)
    psy_gen = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries - use correct PowerSystems function
    try
        
        if IS.has_time_series(psy_gen)
            # Get all time series keys
            ts_keys = PSY.get_time_series_keys(psy_gen)

            if !isempty(ts_keys)
                for ts_key in ts_keys
                    try
                        # Get the time series data
                        ts_data = PSY.get_time_series(psy_gen, ts_key)
                        
                        # Map timeseries based on name
                        key_name = string(ts_key.name)
                        if occursin("FuelPrice", key_name) || occursin("Fuel", key_name)
                            gen.fuel_price_forecast = ts_data
                        elseif occursin("EmissionPrice", key_name) || occursin("Carbon", key_name)
                            gen.emission_price_forecast = ts_data
                        elseif occursin("Maintenance", key_name)
                            # Parse maintenance schedule (simplified)
                            # In practice, this would parse maintenance windows
                        end
                        
                    catch e
                        @debug "Could not extract timeseries $ts_key for thermal generator $(PSY.get_name(psy_gen)): $e"
                    end
                end
            end
        else 
            @info "No timeseries available for thermal generator $(PSY.get_name(psy_gen))"
        end
        
    catch e
        @debug "Could not access time series container for thermal generator $(PSY.get_name(psy_gen)): $e"
        # If time series access fails, just continue without time series data
    end
end
"""
    set_thermal_gen_data!(gen::ExtendedThermalGenerator)

Set thermal generator data and validate constraints.
"""
function set_thermal_gen_data!(gen::ExtendedThermalGenerator)
    psy_gen = gen.generator
    
    # Validate thermal constraints
    active_power_limits = PSY.get_active_power_limits(psy_gen)
    
    # Check minimum power constraint
    if gen.unit_status && gen.Pg < active_power_limits.min
        gen.min_power_violation = active_power_limits.min - gen.Pg
        gen.Pg = active_power_limits.min  # Enforce minimum power
    end
    
    # Check maximum power constraint
    if gen.Pg > active_power_limits.max
        gen.max_power_violation = gen.Pg - active_power_limits.max
        gen.Pg = active_power_limits.max  # Enforce maximum power
    end
    
    # Check ramp rate constraints
    ramp_limits = PSY.get_ramp_limits(psy_gen)
    if !isnothing(ramp_limits)
        ramp_up_limit = ramp_limits.up
        ramp_down_limit = ramp_limits.down
        
        power_change = gen.Pg - gen.P_gen_prev
        
        if power_change > ramp_up_limit
            gen.ramp_up_violation = power_change - ramp_up_limit
        elseif power_change < -ramp_down_limit
            gen.ramp_down_violation = -ramp_down_limit - power_change
        end
    end
    
    # Update fuel consumption and emissions
    update_thermal_performance!(gen)
end

"""
    update_thermal_performance!(gen::ExtendedThermalGenerator)

Update thermal performance metrics based on current operating point.
"""
function update_thermal_performance!(gen::ExtendedThermalGenerator)
    if gen.unit_status && gen.Pg > 0
        # Calculate fuel consumption
        gen.fuel_consumption = gen.heat_rate * gen.Pg / 1000.0  # MMBtu/h
        
        # Calculate emissions
        gen.total_emissions += gen.emissions_rate * gen.Pg  # tons/h
        
        # Update efficiency based on loading
        rating = PSY.get_rating(gen.generator)
        load_factor = gen.Pg / rating
        
        # Efficiency typically decreases at partial load (simplified model)
        base_efficiency = 3412.0 / (gen.heat_rate * 1000.0) * 100.0
        gen.efficiency = base_efficiency * (0.8 + 0.2 * load_factor)
        
        # Update capacity factor
        gen.capacity_factor = load_factor
    else
        gen.fuel_consumption = 0.0
        gen.efficiency = 0.0
        gen.capacity_factor = 0.0
    end
end

"""
    update_unit_commitment_status!(gen::ExtendedThermalGenerator, new_status::Bool)

Update unit commitment status and handle startup/shutdown logic.
"""
function update_unit_commitment_status!(gen::ExtendedThermalGenerator, new_status::Bool)
    old_status = gen.unit_status
    gen.unit_status = new_status
    
    # Handle status transitions
    if !old_status && new_status
        # Unit starting up
        gen.startup_status = true
        gen.shutdown_status = false
        gen.hours_offline = 0
        gen.hours_online = 1
        
        # Calculate startup cost
        op_cost = PSY.get_operation_cost(gen.generator)
        if isa(op_cost, PSY.ThermalGenerationCost)
            startup_cost = PSY.get_startup(op_cost)
            if !isnothing(startup_cost)
                gen.startup_cost_incurred = startup_cost
            end
        end
        
    elseif old_status && !new_status
        # Unit shutting down
        gen.startup_status = false
        gen.shutdown_status = true
        gen.hours_online = 0
        gen.hours_offline = 1
        
        # Calculate shutdown cost if applicable
        op_cost = PSY.get_operation_cost(gen.generator)
        if isa(op_cost, PSY.ThermalGenerationCost)
            shutdown_cost = PSY.get_shutdown(op_cost)
            if !isnothing(shutdown_cost)
                gen.shutdown_cost_incurred = shutdown_cost
            end
        end
        
        # Reset power output
        gen.Pg = 0.0
        
    elseif old_status && new_status
        # Unit continues online
        gen.startup_status = false
        gen.shutdown_status = false
        gen.hours_online += 1
        gen.startup_cost_incurred = 0.0
        gen.shutdown_cost_incurred = 0.0
        
    else
        # Unit continues offline
        gen.startup_status = false
        gen.shutdown_status = false
        gen.hours_offline += 1
        gen.startup_cost_incurred = 0.0
        gen.shutdown_cost_incurred = 0.0
    end
    
    # Update availability factor
    gen.availability_factor = new_status ? 1.0 : 0.0
end

"""
    check_minimum_up_down_time_constraints(gen::ExtendedThermalGenerator)::Bool

Check if minimum up/down time constraints are satisfied.
"""
function check_minimum_up_down_time_constraints(gen::ExtendedThermalGenerator)::Bool
    psy_gen = gen.generator
    time_limits = PSY.get_time_limits(psy_gen)
    
    if isnothing(time_limits)
        return true  # No constraints to check
    end
    
    min_up_time = time_limits.up
    min_down_time = time_limits.down
    
    # Check minimum up time
    if gen.unit_status && gen.hours_online < min_up_time
        return false
    end
    
    # Check minimum down time
    if !gen.unit_status && gen.hours_offline < min_down_time
        return false
    end
    
    return true
end

"""
    calculate_thermal_operating_cost(gen::ExtendedThermalGenerator, time_step::Float64 = 1.0)::Float64

Calculate total thermal operating cost including fuel, startup, and shutdown costs.
"""
function calculate_thermal_operating_cost(gen::ExtendedThermalGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    if gen.unit_status
        # Variable operating cost
        if is_regularization_active(gen.thermal_cost_function)
            # Use sophisticated cost model with regularization
            total_cost += build_thermal_cost_expression(
                gen.thermal_cost_function, 
                gen.Pg, 
                time_step, 
                gen.P_gen_next, 
                gen.theta_g
            )
        else
            # Use simple cost model
            op_cost = PSY.get_operation_cost(gen.generator)
            if isa(op_cost, PSY.ThermalGenerationCost)
                var_cost = PSY.get_variable(op_cost)
                if isa(var_cost, PSY.QuadraticCurve)
                    total_cost += (var_cost.quadratic_term * gen.Pg^2 + 
                                  var_cost.linear_term * gen.Pg + 
                                  var_cost.constant_term) * time_step
                elseif isa(var_cost, PSY.LinearCurve)
                    total_cost += (var_cost.linear_term * gen.Pg + 
                                  var_cost.constant_term) * time_step
                end
                
                # Add fixed cost
                fixed_cost = PSY.get_fixed(op_cost)
                if !isnothing(fixed_cost)
                    total_cost += fixed_cost * time_step
                end
            end
        end
        
        # Add startup cost (only incurred once per startup)
        total_cost += gen.startup_cost_incurred
        
        # Add fuel cost if using timeseries
        if !isnothing(gen.fuel_price_forecast) && !isnothing(gen.current_time)
            try
                fuel_price = PSY.get_value_at_time(gen.fuel_price_forecast, gen.current_time)
                total_cost += fuel_price * gen.fuel_consumption * time_step
            catch e
                @debug "Could not get fuel price at time $(gen.current_time): $e"
            end
        end
        
        # Add emission cost if using timeseries
        if !isnothing(gen.emission_price_forecast) && !isnothing(gen.current_time)
            try
                emission_price = PSY.get_value_at_time(gen.emission_price_forecast, gen.current_time)
                total_cost += emission_price * gen.emissions_rate * gen.Pg * time_step
            catch e
                @debug "Could not get emission price at time $(gen.current_time): $e"
            end
        end
    end
    
    # Add shutdown cost
    total_cost += gen.shutdown_cost_incurred
    
    return total_cost
end

"""
    solve_thermal_generator_subproblem!(gen::ExtendedThermalGenerator, sys::PSY.System; kwargs...)

Solve the thermal generator subproblem with thermal-specific constraints.
"""
function solve_thermal_generator_subproblem!(gen::ExtendedThermalGenerator, sys::PSY.System; 
                                           optimizer_factory=nothing, 
                                           solve_options=Dict(),
                                           time_horizon=24,
                                           include_unit_commitment=false)
    
    # Update solver parameters from generator state
    update_thermal_solver_from_generator!(gen)
    
    # Add thermal-specific solve options
    thermal_solve_options = merge(solve_options, Dict(
        "include_ramp_constraints" => true,
        "include_min_up_down_time" => include_unit_commitment,
        "include_startup_shutdown_costs" => include_unit_commitment
    ))
    
    # Solve using the integrated solver
    results = build_and_solve_gensolver!(
        gen.gen_solver, 
        sys;
        optimizer_factory=optimizer_factory,
        solve_options=thermal_solve_options,
        time_horizon=time_horizon
    )
    
    # Extract results back to generator
    extract_thermal_results_to_generator!(gen, results)

    # Update thermal performance metrics
    update_thermal_performance!(gen)

    return results
end

"""
    solve_thermal_generator_subproblem!(gen::ExtendedThermalGenerator; solve_options, time_horizon, include_unit_commitment)

Sys-less overload for the APP distributed algorithm. Uses `build_and_solve_gensolver_for_gen!`
with `gen.generator` directly instead of querying a `PSY.System`, enabling per-generator
subproblem solves without access to the full system object. Mirrors the pre/post-processing
steps of the sys-based overload.
"""
function solve_thermal_generator_subproblem!(gen::ExtendedThermalGenerator;
                                             optimizer_factory=nothing,
                                             solve_options=Dict(),
                                             time_horizon=24,
                                             include_unit_commitment=false)
    update_thermal_solver_from_generator!(gen)

    thermal_solve_options = merge(solve_options, Dict(
        "include_ramp_constraints"       => true,
        "include_min_up_down_time"       => include_unit_commitment,
        "include_startup_shutdown_costs" => include_unit_commitment
    ))

    results = build_and_solve_gensolver_for_gen!(
        gen.gen_solver, gen.generator;
        optimizer_factory=optimizer_factory,
        solve_options=thermal_solve_options,
        time_horizon=time_horizon
    )

    extract_thermal_results_to_generator!(gen, results)
    update_thermal_performance!(gen)

    return results
end

"""
    solve_thermal_generator_subproblem!(gen_solver, device; solve_options, time_horizon, include_unit_commitment)

Dispatch point for `GeneralizedGenerator` calls arriving from the APP solver. Accepts the
`GenSolver` and raw `PSY.StaticInjection` device exposed by `GeneralizedGenerator` and
routes through `build_and_solve_gensolver_for_gen!`.
"""
function solve_thermal_generator_subproblem!(gen_solver::GenSolver,
                                             device::PSY.StaticInjection;
                                             optimizer_factory=nothing,
                                             solve_options=Dict(),
                                             time_horizon=24,
                                             include_unit_commitment=false)
    thermal_solve_options = merge(solve_options, Dict(
        "include_ramp_constraints"       => true,
        "include_min_up_down_time"       => include_unit_commitment,
        "include_startup_shutdown_costs" => include_unit_commitment
    ))
    return build_and_solve_gensolver_for_gen!(gen_solver, device;
                                              optimizer_factory=optimizer_factory,
                                              solve_options=thermal_solve_options,
                                              time_horizon=time_horizon)
end

"""
    update_thermal_solver_from_generator!(gen::ExtendedThermalGenerator)

Update solver parameters with thermal-specific data.
"""
function update_thermal_solver_from_generator!(gen::ExtendedThermalGenerator)
    # Get the interval type
    interval_type = gen.gen_solver.interval_type
    
    # Update interval parameters
    if isa(interval_type, GenFirstBaseInterval)
        interval_type.Pg_prev = gen.P_gen_prev
        interval_type.Pg_nu = gen.Pg
        interval_type.Pg_nu_inner = gen.Pg
    end
    
    # Update thermal cost function with current state
    update_thermal_cost_parameters!(gen.thermal_cost_function, gen)
end

"""
    extract_thermal_results_to_generator!(gen::ExtendedThermalGenerator, results::Dict)

Extract solver results with thermal-specific processing.
"""
function extract_thermal_results_to_generator!(gen::ExtendedThermalGenerator, results::Dict)
    device_name = PSY.get_name(gen.generator)
    
    # Extract standard results
    if haskey(results, "Pg") && !isempty(results["Pg"])
        for ((name, t), value) in results["Pg"]
            if name == device_name
                gen.Pg = value
                break
            end
        end
    end
    
    if haskey(results, "PgNext") && !isempty(results["PgNext"])
        for ((name, t), value) in results["PgNext"]
            if name == device_name
                gen.P_gen_next = value
                break
            end
        end
    end
    
    if haskey(results, "thetag") && !isempty(results["thetag"])
        for ((name, t), value) in results["thetag"]
            if name == device_name
                gen.theta_g = value
                break
            end
        end
    end
    
    # Extract unit commitment results if available
    if haskey(results, "unit_status") && !isempty(results["unit_status"])
        for ((name, t), value) in results["unit_status"]
            if name == device_name
                update_unit_commitment_status!(gen, value > 0.5)
                break
            end
        end
    end
end

# ...existing code for utility functions...

"""
    thermal_admm_dispatch_update!(thermal, voltage_angle, lambda, rho; neighbors, iteration, temperature)

Closed-form ADMM local dispatch update for a thermal generator. Uses a quadratic
approximation of the cost function to compute the optimal power output and voltage
angle analytically given current dual variables and penalty parameter.

Note: This is distinct from `gpower_angle_message!`, which is the full APP subproblem
solver operating on `GeneralizedGenerator` with the complete APP consensus parameter set.

Arguments:
- thermal: ExtendedThermalGenerator object
- voltage_angle: Current voltage angle at the generator bus (radians)
- lambda: Lagrange multiplier for power balance constraint
- rho: Penalty parameter for ADMM
- neighbors: Vector of neighboring generators/buses power outputs
- iteration: Current ADMM iteration number

Returns:
- NamedTuple (power, angle) with optimal power output and updated voltage angle
"""
function thermal_admm_dispatch_update!(thermal::ExtendedThermalGenerator,
                                       voltage_angle::Float64,
                                       lambda::Float64,
                                       rho::Float64;
                                       neighbors::Vector{Float64} = Float64[],
                                       iteration::Int = 1,
                                       temperature::Float64 = 25.0)
    
    # Extract generator parameters
    min_power = get_active_power_limits(thermal).min
    max_power = get_active_power_limits(thermal).max
    
    # Current operating point
    current_power = thermal.active_power
    current_fuel_cost = thermal.fuel_cost
    
    # Temperature derating factor
    temp_derate = calculate_temperature_derating(thermal, temperature)
    effective_max_power = max_power * temp_derate
    
    # Ramp rate constraints
    ramp_up = thermal.ramp_up_rate
    ramp_down = thermal.ramp_down_rate
    
    # Calculate marginal cost at current operating point
    marginal_cost = calculate_marginal_cost(thermal, current_power)
    
    # Heat rate curve evaluation
    heat_rate = evaluate_heat_rate(thermal, current_power)
    
    # Start-up cost consideration
    startup_cost_factor = thermal.is_on ? 0.0 : thermal.startup_cost / max_power
    
    # Emissions cost
    emissions_cost = calculate_emissions_cost(thermal, current_power)
    
    # Total incremental cost
    total_incremental_cost = marginal_cost + startup_cost_factor + emissions_cost
    
    # ADMM optimization step
    # Minimize: (λ - c(p))p + (ρ/2)(p - p_avg)² + startup costs + emissions costs
    # where p_avg is the average power from neighbors
    
    p_avg = length(neighbors) > 0 ? mean(neighbors) : current_power
    
    # Quadratic approximation of cost function around current point
    # Cost function: C(p) = a*p² + b*p + c
    # Marginal cost: C'(p) = 2*a*p + b
    
    # Estimate quadratic coefficients from heat rate curve
    if current_power > min_power + 1.0  # Avoid division by zero
        # Numerical differentiation for second derivative
        delta_p = min(1.0, (max_power - min_power) * 0.01)
        p_test = min(effective_max_power, current_power + delta_p)
        
        mc_high = calculate_marginal_cost(thermal, p_test)
        mc_low = calculate_marginal_cost(thermal, max(min_power, current_power - delta_p))
        
        # Second derivative approximation
        second_derivative = (mc_high - mc_low) / (2 * delta_p)
        second_derivative = max(0.001, second_derivative)  # Ensure positive definiteness
        
        # Quadratic coefficient
        a_quad = second_derivative / 2
        b_quad = marginal_cost - 2 * a_quad * current_power
    else
        # Use default quadratic approximation for small power levels
        a_quad = 0.01
        b_quad = marginal_cost
    end
    
    # ADMM subproblem solution
    # Minimize: (λ - b_quad)p - a_quad*p² + (ρ/2)(p - p_avg)² + startup_costs
    # Taking derivative and setting to zero:
    # λ - b_quad - 2*a_quad*p + ρ(p - p_avg) = 0
    # Solving for p: p = (λ - b_quad + ρ*p_avg) / (2*a_quad + ρ)
    
    denominator = 2 * a_quad + rho
    numerator = lambda - b_quad + rho * p_avg
    
    # Unconstrained optimal power
    p_optimal = numerator / denominator
    
    # Apply operational constraints
    # Ramp rate constraints
    p_min_ramp = current_power - ramp_down
    p_max_ramp = current_power + ramp_up
    
    # Combine all constraints
    p_min_total = max(min_power, p_min_ramp)
    p_max_total = min(effective_max_power, p_max_ramp)
    
    # Unit commitment constraints
    if !thermal.is_on
        # If unit is off, check if it should start up
        startup_benefit = lambda - total_incremental_cost
        if startup_benefit * max_power > thermal.startup_cost
            # Beneficial to start up
            p_min_total = max(p_min_total, thermal.min_stable_power)
            thermal.is_on = true
            thermal.startup_time = 0.0
        else
            # Keep unit off
            p_optimal = 0.0
            p_min_total = 0.0
            p_max_total = 0.0
        end
    else
        # Unit is on, check if it should shut down
        shutdown_benefit = total_incremental_cost - lambda
        if shutdown_benefit * current_power > thermal.shutdown_cost
            # Beneficial to shut down
            p_optimal = 0.0
            thermal.is_on = false
        else
            # Keep unit on with minimum stable power
            p_min_total = max(p_min_total, thermal.min_stable_power)
        end
    end
    
    # Project onto feasible region
    p_final = max(p_min_total, min(p_max_total, p_optimal))
    
    # Update voltage angle based on power dispatch
    # Simplified relationship: δ = δ₀ + K*(P - P₀)
    # where K is the sensitivity coefficient
    
    # Voltage angle sensitivity (simplified)
    angle_sensitivity = 0.001  # radians per MW (typical value)
    power_change = p_final - current_power
    
    # Consider system impedance and network effects
    if length(neighbors) > 0
        # Network effect: angle depends on power flow to neighbors
        neighbor_avg = mean(neighbors)
        network_effect = (p_final - neighbor_avg) * angle_sensitivity * 0.5
    else
        network_effect = 0.0
    end
    
    # Updated voltage angle
    new_angle = voltage_angle + power_change * angle_sensitivity + network_effect
    
    # Angle limits (typical power system limits)
    angle_limit = π/6  # 30 degrees
    new_angle = max(-angle_limit, min(angle_limit, new_angle))
    
    # Update generator state
    thermal.active_power = p_final
    
    # Return optimal power and angle
    return (power = p_final, angle = new_angle)
end

"""
Dual variable update for thermal generator in APP-ADMM
"""
function update_thermal_duals!(thermal::ExtendedThermalGenerator, 
                              power_mismatch::Float64,
                              rho::Float64, 
                              lambda::Vector{Float64}, 
                              t::Int)
    # Standard ADMM dual update
    lambda[t] += rho * power_mismatch
    
    # Adaptive penalty parameter adjustment
    if abs(power_mismatch) > 0.1
        # Large mismatch - increase penalty
        rho *= 1.1
    elseif abs(power_mismatch) < 0.01
        # Small mismatch - decrease penalty
        rho *= 0.95
    end
    
    # Bounds on penalty parameter
    rho = max(0.1, min(1000.0, rho))
    
    # Store updated values
    thermal.ext["lambda"] = lambda[t]
    thermal.ext["rho"] = rho
    
    return lambda, rho
end

"""
Consensus step for thermal generator in APP-ADMM
"""
function thermal_consensus_step!(thermal::ExtendedThermalGenerator,
                                neighbor_powers::Vector{Float64},
                                rho::Float64,
                                alpha::Float64 = 1.0)
    # Accelerated consensus update (APP-ADMM)
    current_power = thermal.active_power
    
    # Compute consensus power
    if length(neighbor_powers) > 0
        neighbor_avg = mean(neighbor_powers)
        
        # Weighted average based on generator capacity
        weight = thermal.rating / (thermal.rating + 100.0)  # Normalize by 100 MW
        consensus_power = alpha * neighbor_avg + (1 - alpha) * current_power
        
        # Apply constraints
        min_power = get_active_power_limits(thermal).min
        max_power = get_active_power_limits(thermal).max
        
        if thermal.is_on
            min_power = max(min_power, thermal.min_stable_power)
        else
            min_power = 0.0
            max_power = 0.0
        end
        
        consensus_power = max(min_power, min(max_power, consensus_power))
    else
        consensus_power = current_power
    end
    
    return consensus_power
end

"""
Calculate marginal cost for thermal generator
Uses piecewise linear approximation of heat rate curve
"""
function calculate_marginal_cost(thermal::ExtendedThermalGenerator, power::Float64)
    # Get heat rate at current power level
    heat_rate = evaluate_heat_rate(thermal, power)
    
    # Fuel cost ($/MMBtu) * Heat rate (MMBtu/MWh) = $/MWh
    fuel_cost_per_mwh = thermal.fuel_cost * heat_rate
    
    # Variable O&M cost ($/MWh)
    vom_cost = get(thermal.ext, "variable_om_cost", 5.0)  # Default 5 $/MWh
    
    # Marginal cost = fuel cost + variable O&M
    marginal_cost = fuel_cost_per_mwh + vom_cost
    
    # Add penalty for operating near limits (helps with numerical stability)
    min_power = get_active_power_limits(thermal).min
    max_power = get_active_power_limits(thermal).max
    
    if power > 0.95 * max_power
        # High penalty near maximum power
        penalty = 1000.0 * (power - 0.95 * max_power) / (0.05 * max_power)
        marginal_cost += penalty
    elseif power < 1.05 * min_power && power > min_power
        # Penalty near minimum power (avoid shutdown)
        penalty = 500.0 * (1.05 * min_power - power) / (0.05 * min_power)
        marginal_cost += penalty
    end
    
    return marginal_cost
end

"""
Evaluate heat rate curve for thermal generator
Typically a quadratic function: HR(P) = a + b*P + c*P²
"""
function evaluate_heat_rate(thermal::ExtendedThermalGenerator, power::Float64)
    # Get heat rate curve coefficients
    # Format: [a, b, c] for quadratic HR(P) = a + b*P + c*P²
    heat_rate_coeffs = get(thermal.ext, "heat_rate_coeffs", [9.5, 0.0, 0.0001])
    
    if length(heat_rate_coeffs) >= 3
        # Quadratic heat rate curve
        a, b, c = heat_rate_coeffs[1], heat_rate_coeffs[2], heat_rate_coeffs[3]
        heat_rate = a + b * power + c * power^2
    elseif length(heat_rate_coeffs) == 2
        # Linear heat rate curve
        a, b = heat_rate_coeffs[1], heat_rate_coeffs[2]
        heat_rate = a + b * power
    else
        # Constant heat rate
        heat_rate = heat_rate_coeffs[1]
    end
    
    # Typical heat rate bounds for thermal units (MMBtu/MWh)
    heat_rate = max(7.0, min(15.0, heat_rate))
    
    return heat_rate
end

"""
Calculate temperature derating factor for thermal generator
Account for reduced capacity at high ambient temperatures
"""
function calculate_temperature_derating(thermal::ExtendedThermalGenerator, temperature::Float64)
    # Reference temperature (°C) - typically 15°C for ISO conditions
    reference_temp = get(thermal.ext, "reference_temperature", 15.0)
    
    # Temperature derating coefficient (%/°C) - typically 0.5-1.0% per °C
    temp_coeff = get(thermal.ext, "temperature_coefficient", 0.007)
    
    # Calculate derating factor
    temp_difference = temperature - reference_temp
    derating_factor = 1.0 - temp_coeff * temp_difference
    
    # Bound the derating factor between 0.7 and 1.05
    derating_factor = max(0.7, min(1.05, derating_factor))
    
    return derating_factor
end

"""
Calculate emissions cost for thermal generator
Includes CO2, NOx, and SO2 emissions
"""
function calculate_emissions_cost(thermal::ExtendedThermalGenerator, power::Float64)
    # Get emissions rates (tons/MWh) and costs ($/ton)
    co2_rate = get(thermal.ext, "co2_emission_rate", 0.85)      # tons CO2/MWh
    nox_rate = get(thermal.ext, "nox_emission_rate", 0.002)     # tons NOx/MWh  
    so2_rate = get(thermal.ext, "so2_emission_rate", 0.005)     # tons SO2/MWh
    
    co2_cost = get(thermal.ext, "co2_cost", 25.0)              # $/ton CO2
    nox_cost = get(thermal.ext, "nox_cost", 5000.0)            # $/ton NOx
    so2_cost = get(thermal.ext, "so2_cost", 1000.0)            # $/ton SO2
    
    # Total emissions cost ($/MWh)
    emissions_cost = co2_rate * co2_cost + nox_rate * nox_cost + so2_rate * so2_cost
    
    return emissions_cost
end

"""
Get active power limits for thermal generator
"""
function get_active_power_limits(thermal::ExtendedThermalGenerator)
    # Return named tuple with min and max power limits
    return (min = thermal.active_power_limits.min, max = thermal.active_power_limits.max)
end

# Export thermal-specific functions
export ExtendedThermalGenerator
export initialize_thermal_parameters!, extract_thermal_timeseries!, set_thermal_gen_data!
export update_thermal_performance!, update_unit_commitment_status!
export check_minimum_up_down_time_constraints, calculate_thermal_operating_cost
export solve_thermal_generator_subproblem!
