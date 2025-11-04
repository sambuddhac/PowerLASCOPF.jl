"""
Extended Thermal Generator component for PowerLASCOPF.jl

This module defines the ExtendedThermalGenerator struct that extends PowerSystems.ThermalGen
for LASCOPF optimization with ADMM/APP state variables, thermal-specific constraints,
and enhanced cost modeling.
"""

using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries

# Include necessary modules from the codebase
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
        # Get time series container
        #ts_container = PSY.get_time_series_container(psy_gen)
        
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

# Export thermal-specific functions
export ExtendedThermalGenerator
export initialize_thermal_parameters!, extract_thermal_timeseries!, set_thermal_gen_data!
export update_thermal_performance!, update_unit_commitment_status!
export check_minimum_up_down_time_constraints, calculate_thermal_operating_cost
export solve_thermal_generator_subproblem!
