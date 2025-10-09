"""
Extended Renewable Generator component for PowerLASCOPF.jl

This module defines the ExtendedRenewableGenerator struct that extends PowerSystems renewable generators
for LASCOPF optimization with ADMM/APP state variables, renewable-specific constraints,
and enhanced renewable cost modeling including curtailment and forecasting uncertainty.
"""

using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries

# Include necessary modules from the codebase
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedRenewableGenerationCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedRenewableGenerator{T<:PSY.RenewableGen, U<:GenIntervals}

An extended renewable generator component that extends PowerSystems renewable generators for LASCOPF optimization.
Supports wind, solar, and other renewable technologies with renewable-specific constraints like
forecast uncertainty, curtailment penalties, and environmental variability.
"""
@kwdef mutable struct ExtendedRenewableGenerator{T<:PSY.RenewableGen, U<:GenIntervals} <: PowerGenerator
    # Core renewable generator from PowerSystems
    generator::T  # RenewableDispatch, RenewableFix, etc.
    
    # Extended renewable cost function with regularization
    renewable_cost_function::ExtendedRenewableGenerationCost{U}
    
    # Generator identification
    gen_id::Int64
    number_of_generators::Int64
    dispatch_interval::Int64
    flag_last::Bool
    dummy_zero_int_flag::Int64
    cont_solver_accuracy::Int64
    
    # Scenario management
    scenario_cont_count::Int64
    post_cont_scen_count::Int64
    base_cont_scenario::Int64
    cont_count_gen::Int64
    gen_total::Int64
    
    # Node connection
    conn_nodeg_ptr::Node
    
    # Solver interface for renewable generators
    gen_solver::GenSolver{ExtendedRenewableGenerationCost, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Renewable-specific operating variables
    available_power::Float64 = 0.0              # Available renewable power (MW)
    forecast_power::Float64 = 0.0               # Forecasted renewable power (MW)
    curtailment::Float64 = 0.0                  # Curtailed power (MW)
    curtailment_cost::Float64 = 0.0             # Cost of curtailment ($/MWh)
    capacity_factor_current::Float64 = 0.0      # Real-time capacity factor
    
    # Forecast uncertainty and scenarios
    forecast_error::Float64 = 0.0               # Current forecast error (MW)
    forecast_std::Float64 = 0.0                 # Forecast standard deviation (MW)
    confidence_interval::Tuple{Float64, Float64} = (0.0, 0.0)  # 95% confidence interval
    forecast_scenarios::Vector{Float64} = Float64[]  # Multiple forecast scenarios
    scenario_probabilities::Vector{Float64} = Float64[]  # Scenario probabilities
    
    # Environmental conditions
    wind_speed::Float64 = 0.0                   # Wind speed (m/s) for wind generators
    solar_irradiance::Float64 = 0.0             # Solar irradiance (W/m²) for solar
    temperature::Float64 = 25.0                 # Ambient temperature (°C)
    cloud_cover::Float64 = 0.0                  # Cloud cover percentage (0-100)
    
    # Performance and degradation
    performance_ratio::Float64 = 0.85           # Performance ratio (accounting for losses)
    degradation_rate::Float64 = 0.005           # Annual degradation rate
    years_in_service::Float64 = 0.0             # Years since commissioning
    maintenance_derate::Float64 = 0.0           # Maintenance-related derate (MW)
    
    # Grid integration variables
    ramp_rate_limit::Float64 = 0.0              # Ramp rate limit (MW/min)
    grid_support_capability::Bool = false        # Can provide grid support services
    reactive_power_capability::Float64 = 0.0    # Reactive power capability (MVAr)
    
    # Renewable timeseries management
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    weather_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    power_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    uncertainty_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    curtailment_signals::Union{TimeSeries.TimeArray, Nothing} = nothing
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Long-term capacity factor
    availability_factor::Float64 = 1.0          # Availability factor
    energy_yield::Float64 = 0.0                 # Cumulative energy yield (MWh)
    
    # Renewable-specific cache
    _renewable_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedRenewableGenerator(
        generator::T,
        renewable_cost_function::ExtendedRenewableGenerationCost{U},
        id_of_gen::Int64,
        interval::Int64,
        last_flag::Bool,
        cont_scenario_count::Int64,
        PC_scenario_count::Int64,
        baseCont::Int64,
        dummyZero::Int64,
        accuracy::Int64,
        nodeConng::Node,
        countOfContingency::Int64,
        gen_total::Int64;
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.RenewableGen, U<:GenIntervals}
        
        # Create solver with renewable cost model
        gensolver = GenSolver(
            interval_type = renewable_cost_function.regularization_term,
            cost_curve = renewable_cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.renewable_cost_function = renewable_cost_function
        # ...existing code for other assignments...
        
        # Initialize renewable-specific parameters
        initialize_renewable_parameters!(self)
        
        # Extract timeseries data
        extract_renewable_timeseries!(self)
        
        # Set initial generator data
        set_renewable_gen_data!(self)
        
        return self
    end
end

"""
    initialize_renewable_parameters!(gen::ExtendedRenewableGenerator)

Initialize renewable-specific parameters from the PowerSystems renewable generator.
"""
function initialize_renewable_parameters!(gen::ExtendedRenewableGenerator{T}) where T
    psy_gen = gen.generator
    
    # Extract basic parameters
    gen.Pg = PSY.get_active_power(psy_gen)
    gen.P_gen_prev = gen.Pg
    gen.P_gen_next = gen.Pg
    
    # Get renewable technology type
    prime_mover = PSY.get_prime_mover_type(psy_gen)
    
    # Initialize technology-specific parameters
    if prime_mover == PSY.PrimeMovers.WT  # Wind turbine
        gen.wind_speed = 10.0  # Default wind speed
        gen.ramp_rate_limit = PSY.get_rating(psy_gen) * 0.3  # 30% per minute typical for wind
        gen.curtailment_cost = 25.0  # $/MWh typical wind curtailment cost
        
    elseif prime_mover == PSY.PrimeMovers.PVe  # Solar PV
        gen.solar_irradiance = 800.0  # W/m²
        gen.temperature = 25.0
        gen.ramp_rate_limit = PSY.get_rating(psy_gen) * 0.5  # 50% per minute for solar
        gen.curtailment_cost = 0.0  # Solar curtailment typically free
        
    else  # Other renewable types
        gen.ramp_rate_limit = PSY.get_rating(psy_gen) * 0.2  # Conservative default
        gen.curtailment_cost = 10.0  # Default curtailment cost
    end
    
    # Initialize available and forecast power
    rating = PSY.get_rating(psy_gen)
    gen.available_power = rating  # Assume full availability initially
    gen.forecast_power = gen.Pg
    
    # Initialize performance metrics
    gen.performance_ratio = 0.85  # Typical performance ratio
    gen.capacity_factor = gen.Pg / rating if rating > 0
    
    # Initialize forecast uncertainty (percentage of rating)
    gen.forecast_std = rating * 0.1  # 10% standard deviation
    gen.confidence_interval = (
        max(0.0, gen.forecast_power - 1.96 * gen.forecast_std),
        min(rating, gen.forecast_power + 1.96 * gen.forecast_std)
    )
end

"""
    extract_renewable_timeseries!(gen::ExtendedRenewableGenerator)

Extract renewable-specific timeseries data from PowerSystems generator.
"""
function extract_renewable_timeseries!(gen::ExtendedRenewableGenerator)
    psy_gen = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries
    time_series_names = PSY.get_time_series_names(psy_gen)
    
    for ts_name in time_series_names
        try
            ts_data = PSY.get_time_series(psy_gen, ts_name)
            
            # Map timeseries based on name
            if occursin("max_active_power", string(ts_name)) || occursin("MaxActivePower", string(ts_name))
                gen.power_forecast = ts_data
            elseif occursin("Weather", string(ts_name)) || occursin("Wind", string(ts_name)) || occursin("Solar", string(ts_name))
                gen.weather_forecast = ts_data
            elseif occursin("Uncertainty", string(ts_name)) || occursin("Error", string(ts_name))
                gen.uncertainty_forecast = ts_data
            elseif occursin("Curtailment", string(ts_name))
                gen.curtailment_signals = ts_data
            end
            
        catch e
            @debug "Could not extract timeseries $ts_name for renewable generator $(PSY.get_name(psy_gen)): $e"
        end
    end
end

"""
    update_renewable_forecast!(gen::ExtendedRenewableGenerator, current_time::DateTime)

Update renewable power forecast based on weather conditions and timeseries.
"""
function update_renewable_forecast!(gen::ExtendedRenewableGenerator{T}, current_time::DateTime) where T
    gen.current_time = current_time
    
    # Update from power forecast timeseries if available
    if !isnothing(gen.power_forecast)
        try
            gen.forecast_power = PSY.get_value_at_time(gen.power_forecast, current_time)
            gen.available_power = gen.forecast_power
        catch e
            @debug "Could not get power forecast at time $current_time: $e"
        end
    end
    
    # Update weather conditions if available
    if !isnothing(gen.weather_forecast)
        try
            weather_data = PSY.get_value_at_time(gen.weather_forecast, current_time)
            
            prime_mover = PSY.get_prime_mover_type(gen.generator)
            if prime_mover == PSY.PrimeMovers.WT
                # Update wind speed and calculate available power
                gen.wind_speed = weather_data
                gen.available_power = calculate_wind_power(gen)
            elseif prime_mover == PSY.PrimeMovers.PVe
                # Update solar irradiance and calculate available power
                gen.solar_irradiance = weather_data
                gen.available_power = calculate_solar_power(gen)
            end
        catch e
            @debug "Could not get weather data at time $current_time: $e"
        end
    end
    
    # Update uncertainty estimates
    if !isnothing(gen.uncertainty_forecast)
        try
            gen.forecast_std = PSY.get_value_at_time(gen.uncertainty_forecast, current_time)
            gen.confidence_interval = (
                max(0.0, gen.forecast_power - 1.96 * gen.forecast_std),
                min(PSY.get_rating(gen.generator), gen.forecast_power + 1.96 * gen.forecast_std)
            )
        catch e
            @debug "Could not get uncertainty forecast at time $current_time: $e"
        end
    end
    
    # Calculate forecast error
    gen.forecast_error = gen.Pg - gen.forecast_power
    
    # Update curtailment
    gen.curtailment = max(0.0, gen.available_power - gen.Pg)
    
    # Update capacity factor
    rating = PSY.get_rating(gen.generator)
    gen.capacity_factor_current = gen.Pg / rating if rating > 0
    
    gen._cache_valid = true
end

"""
    calculate_wind_power(gen::ExtendedRenewableGenerator)::Float64

Calculate available wind power based on wind speed and turbine characteristics.
"""
function calculate_wind_power(gen::ExtendedRenewableGenerator)::Float64
    # Simplified wind power curve
    wind_speed = gen.wind_speed
    rating = PSY.get_rating(gen.generator)
    
    if wind_speed < 3.0  # Cut-in speed
        return 0.0
    elseif wind_speed > 25.0  # Cut-out speed
        return 0.0
    elseif wind_speed < 12.0  # Below rated speed
        # Cubic relationship below rated speed
        return rating * (wind_speed - 3.0)^3 / (12.0 - 3.0)^3
    else  # Above rated speed
        return rating
    end
end

"""
    calculate_solar_power(gen::ExtendedRenewableGenerator)::Float64

Calculate available solar power based on irradiance and temperature.
"""
function calculate_solar_power(gen::ExtendedRenewableGenerator)::Float64
    # Simplified solar power calculation
    irradiance = gen.solar_irradiance
    temperature = gen.temperature
    rating = PSY.get_rating(gen.generator)
    
    # Standard test conditions: 1000 W/m², 25°C
    stc_irradiance = 1000.0
    stc_temperature = 25.0
    
    # Temperature coefficient (typically -0.4%/°C for silicon)
    temp_coeff = -0.004
    
    # Power calculation
    irradiance_factor = irradiance / stc_irradiance
    temperature_factor = 1.0 + temp_coeff * (temperature - stc_temperature)
    
    power = rating * irradiance_factor * temperature_factor * gen.performance_ratio
    
    # Account for degradation
    degradation_factor = 1.0 - gen.degradation_rate * gen.years_in_service
    
    return max(0.0, power * degradation_factor - gen.maintenance_derate)
end

"""
    calculate_renewable_operating_cost(gen::ExtendedRenewableGenerator, time_step::Float64 = 1.0)::Float64

Calculate total renewable operating cost including curtailment penalties.
"""
function calculate_renewable_operating_cost(gen::ExtendedRenewableGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    # Variable operating cost (typically very low for renewables)
    if is_regularization_active(gen.renewable_cost_function)
        total_cost += build_renewable_cost_expression(
            gen.renewable_cost_function, 
            gen.Pg, 
            gen.curtailment,
            time_step,
            gen.P_gen_next, 
            gen.theta_g
        )
    else
        # Simple cost model
        op_cost = PSY.get_operation_cost(gen.generator)
        var_cost = PSY.get_variable(op_cost)
        total_cost += var_cost * gen.Pg * time_step
    end
    
    # Curtailment penalty
    total_cost += gen.curtailment_cost * gen.curtailment * time_step
    
    # Forecast error penalty (if significant)
    if abs(gen.forecast_error) > gen.forecast_std
        error_penalty = 5.0  # $/MWh penalty for large forecast errors
        total_cost += error_penalty * abs(gen.forecast_error) * time_step
    end
    
    return total_cost
end

# ...existing code for solver functions...

export ExtendedRenewableGenerator
export initialize_renewable_parameters!, extract_renewable_timeseries!
export update_renewable_forecast!, calculate_wind_power, calculate_solar_power
export calculate_renewable_operating_cost
