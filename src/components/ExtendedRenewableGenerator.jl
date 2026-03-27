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
using JuMP
const PSY = PowerSystems
const IS = InfrastructureSystems

# Import the correct PowerSystems types
import PowerSystems: MinMax, UpDown, PrimeMovers, OperationalCost, RenewableGen

# Include necessary modules from the codebase
include("../core/types.jl")
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

    # Node connection
    conn_nodeg_ptr::Node
    
    # Solver interface for renewable generators
    gen_solver::GenSolver{ExtendedRenewableGenerationCost{U}, U}
    
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
        countOfContingency::Int64;
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
        
        # Initialize renewable-specific parameters
        initialize_renewable_parameters!(self)
        
        # Extract timeseries data
        extract_renewable_timeseries!(self)
        
        # Set initial generator data
        #set_renewable_gen_data!(self)
        
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

    # Fix: Complete the conditional statement properly
    if rating > 0
        gen.capacity_factor = gen.Pg / rating
    else
        gen.capacity_factor = 0.0
    end
    
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
                        # Map timeseries based on name
                        if occursin("max_active_power", key_name) || occursin("MaxActivePower", key_name)
                            gen.power_forecast = ts_data
                        elseif occursin("Weather", key_name) || occursin("Wind", key_name) || occursin("Solar", key_name)
                            gen.weather_forecast = ts_data
                        elseif occursin("Uncertainty", key_name) || occursin("Error", key_name)
                            gen.uncertainty_forecast = ts_data
                        elseif occursin("Curtailment", key_name)
                            gen.curtailment_signals = ts_data
                        end
                        
                    catch e
                        @debug "Could not extract timeseries $ts_name for renewable generator $(PSY.get_name(psy_gen)): $e"
                    end
                end
            end
        else 
            @info "No timeseries available for renewable generator $(PSY.get_name(psy_gen))"
        end
        
    catch e
        @debug "Could not access time series container for renewable generator $(PSY.get_name(psy_gen)): $e"
        # If time series access fails, just continue without time series data
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

    if rating > 0
        gen.capacity_factor_current = gen.Pg / rating
    else
        gen.capacity_factor_current = 0.0
    end
    
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

# Extended Renewable Generator for PowerLASCOPF with Sienna integration
mutable struct ExtendedRenewableGenSys{T<:PSY.RenewableGen} <: PSY.RenewableGen
    # Core renewable generator properties
    renewable_type::T
    gen_id::Int
    
    # Power and economic properties
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PSY.PrimeMovers
    active_power_limits::PSY.MinMax
    reactive_power_limits::Union{Nothing, PSY.MinMax}
    ramp_limits::Union{Nothing, PSY.UpDown}
    operation_cost::Union{Nothing, PSY.OperationalCost}

    # Renewable-specific properties
    power_factor::Float64
    max_active_power::Float64
    max_reactive_power::Float64
    
    # PowerLASCOPF specific properties
    node_connection::Int
    zone_id::Int
    scenario_count::Int
    
    # Economic and operational variables
    marginal_cost::Float64
    startup_cost::Float64
    shutdown_cost::Float64
    min_up_time::Float64
    min_down_time::Float64
    
    # Renewable forecasting and variability
    capacity_factor::Float64
    availability_factor::Float64
    curtailment_cost::Float64
    forecast_data::Vector{Float64}
    forecast_uncertainty::Float64
    
    # LASCOPF specific variables
    lambda_avg::Float64  # Average marginal price
    power_output::Float64
    commitment_status::Bool
    reserve_provision::Float64
    
    # Scenario-based variables
    power_scenarios::Vector{Float64}
    cost_scenarios::Vector{Float64}
    availability_scenarios::Vector{Float64}
    contingency_response::Vector{Float64}
    
    # Grid integration properties
    voltage_regulation::Bool
    frequency_response::Bool
    grid_forming_capability::Bool
    inverter_efficiency::Float64
    
    # Environmental and policy variables
    renewable_energy_credits::Float64
    carbon_offset::Float64
    policy_incentives::Float64
    
    # Maintenance and reliability
    forced_outage_rate::Float64
    maintenance_schedule::Vector{Int}
    reliability_factor::Float64
    
    # Performance tracking
    energy_produced::Float64
    capacity_utilization::Float64
    curtailment_hours::Float64
    
    # Inner constructor
    function ExtendedRenewableGenSys{T}(
        renewable_type::T,
        gen_id::Int,
        node_connection::Int,
        zone_id::Int,
        scenario_count::Int
    ) where T <: PSY.RenewableGen
        return new{T}(
            renewable_type,
            gen_id,
            PowerSystems.get_active_power(renewable_type),
            PowerSystems.get_reactive_power(renewable_type),
            PowerSystems.get_rating(renewable_type),
            PowerSystems.get_prime_mover_type(renewable_type),
            PowerSystems.get_active_power_limits(renewable_type),
            PowerSystems.get_reactive_power_limits(renewable_type),
            PowerSystems.get_ramp_limits(renewable_type),
            PowerSystems.get_operation_cost(renewable_type),
            PowerSystems.get_power_factor(renewable_type),
            PowerSystems.get_max_active_power(renewable_type),
            PowerSystems.get_max_reactive_power(renewable_type),
            node_connection,
            zone_id,
            scenario_count,
            0.0,  # marginal_cost
            0.0,  # startup_cost
            0.0,  # shutdown_cost
            0.0,  # min_up_time
            0.0,  # min_down_time
            1.0,  # capacity_factor
            1.0,  # availability_factor
            0.0,  # curtailment_cost
            zeros(24),  # forecast_data (24-hour default)
            0.1,  # forecast_uncertainty
            0.0,  # lambda_avg
            0.0,  # power_output
            true,  # commitment_status
            0.0,  # reserve_provision
            zeros(scenario_count),  # power_scenarios
            zeros(scenario_count),  # cost_scenarios
            ones(scenario_count),   # availability_scenarios
            zeros(scenario_count),  # contingency_response
            false,  # voltage_regulation
            false,  # frequency_response
            false,  # grid_forming_capability
            0.95,   # inverter_efficiency
            0.0,  # renewable_energy_credits
            0.0,  # carbon_offset
            0.0,  # policy_incentives
            0.02, # forced_outage_rate (2%)
            Int[], # maintenance_schedule
            0.98,  # reliability_factor
            0.0,  # energy_produced
            0.0,  # capacity_utilization
            0.0   # curtailment_hours
        )
    end
end

# Outer constructor
function ExtendedRenewableGenSys(
    renewable_type::T,
    gen_id::Int,
    node_connection::Int,
    zone_id::Int,
    scenario_count::Int
) where T <: PSY.RenewableGen
    return ExtendedRenewableGenSys{T}(renewable_type, gen_id, node_connection, zone_id, scenario_count)
end

# Extend PowerSystems.RenewableGen interface
PowerSystems.get_name(gen::ExtendedRenewableGenSys) = PowerSystems.get_name(gen.renewable_type)
PowerSystems.get_available(gen::ExtendedRenewableGenSys) = PowerSystems.get_available(gen.renewable_type)
PowerSystems.get_bus(gen::ExtendedRenewableGenSys) = PowerSystems.get_bus(gen.renewable_type)
PowerSystems.get_active_power(gen::ExtendedRenewableGenSys) = gen.active_power
PowerSystems.get_reactive_power(gen::ExtendedRenewableGenSys) = gen.reactive_power
PowerSystems.get_rating(gen::ExtendedRenewableGenSys) = gen.rating
PowerSystems.get_prime_mover_type(gen::ExtendedRenewableGenSys) = gen.prime_mover_type
PowerSystems.get_active_power_limits(gen::ExtendedRenewableGenSys) = gen.active_power_limits
PowerSystems.get_reactive_power_limits(gen::ExtendedRenewableGenSys) = gen.reactive_power_limits
PowerSystems.get_ramp_limits(gen::ExtendedRenewableGenSys) = gen.ramp_limits
PowerSystems.get_operation_cost(gen::ExtendedRenewableGenSys) = gen.operation_cost
PowerSystems.get_power_factor(gen::ExtendedRenewableGenSys) = gen.power_factor
PowerSystems.get_max_active_power(gen::ExtendedRenewableGenSys) = gen.max_active_power
PowerSystems.get_max_reactive_power(gen::ExtendedRenewableGenSys) = gen.max_reactive_power

# Extend InfrastructureSystems.Component interface
IS.get_uuid(gen::ExtendedRenewableGenSys) = IS.get_uuid(gen.renewable_type)
IS.get_ext(gen::ExtendedRenewableGenSys) = IS.get_ext(gen.renewable_type)
#IS.get_time_series_container(gen::ExtendedRenewableGenSys) = IS.get_time_series_container(gen.renewable_type)

# Core getter/setter functions
get_gen_id(gen::ExtendedRenewableGenSys) = gen.gen_id
get_node_connection(gen::ExtendedRenewableGenSys) = gen.node_connection
get_zone_id(gen::ExtendedRenewableGenSys) = gen.zone_id
get_scenario_count(gen::ExtendedRenewableGenSys) = gen.scenario_count

# Economic functions
get_marginal_cost(gen::ExtendedRenewableGenSys) = gen.marginal_cost
set_marginal_cost!(gen::ExtendedRenewableGenSys, cost::Float64) = (gen.marginal_cost = cost)

get_curtailment_cost(gen::ExtendedRenewableGenSys) = gen.curtailment_cost
set_curtailment_cost!(gen::ExtendedRenewableGenSys, cost::Float64) = (gen.curtailment_cost = cost)

# Renewable-specific functions
get_capacity_factor(gen::ExtendedRenewableGenSys) = gen.capacity_factor
set_capacity_factor!(gen::ExtendedRenewableGenSys, factor::Float64) = (gen.capacity_factor = clamp(factor, 0.0, 1.0))

get_availability_factor(gen::ExtendedRenewableGenSys) = gen.availability_factor
set_availability_factor!(gen::ExtendedRenewableGenSys, factor::Float64) = (gen.availability_factor = clamp(factor, 0.0, 1.0))

get_forecast_data(gen::ExtendedRenewableGenSys) = gen.forecast_data
function set_forecast_data!(gen::ExtendedRenewableGenSys, data::Vector{Float64})
    gen.forecast_data = copy(data)
    return nothing
end

get_forecast_uncertainty(gen::ExtendedRenewableGenSys) = gen.forecast_uncertainty
set_forecast_uncertainty!(gen::ExtendedRenewableGenSys, uncertainty::Float64) = (gen.forecast_uncertainty = clamp(uncertainty, 0.0, 1.0))

# LASCOPF operational functions
get_lambda_avg(gen::ExtendedRenewableGenSys) = gen.lambda_avg
set_lambda_avg!(gen::ExtendedRenewableGenSys, lambda::Float64) = (gen.lambda_avg = lambda)

get_power_output(gen::ExtendedRenewableGenSys) = gen.power_output
function set_power_output!(gen::ExtendedRenewableGenSys, power::Float64)
    max_power = gen.max_active_power * gen.capacity_factor * gen.availability_factor
    gen.power_output = clamp(power, 0.0, max_power)
    return nothing
end

get_commitment_status(gen::ExtendedRenewableGenSys) = gen.commitment_status
set_commitment_status!(gen::ExtendedRenewableGenSys, status::Bool) = (gen.commitment_status = status)

# Scenario-based functions
get_power_scenarios(gen::ExtendedRenewableGenSys) = gen.power_scenarios
function set_power_scenario!(gen::ExtendedRenewableGenSys, scenario::Int, power::Float64)
    if 1 <= scenario <= gen.scenario_count
        max_power = gen.max_active_power * gen.capacity_factor * gen.availability_factor
        gen.power_scenarios[scenario] = clamp(power, 0.0, max_power)
    end
    return nothing
end

get_cost_scenarios(gen::ExtendedRenewableGenSys) = gen.cost_scenarios
function set_cost_scenario!(gen::ExtendedRenewableGenSys, scenario::Int, cost::Float64)
    if 1 <= scenario <= gen.scenario_count
        gen.cost_scenarios[scenario] = max(cost, 0.0)
    end
    return nothing
end

get_availability_scenarios(gen::ExtendedRenewableGenSys) = gen.availability_scenarios
function set_availability_scenario!(gen::ExtendedRenewableGenSys, scenario::Int, availability::Float64)
    if 1 <= scenario <= gen.scenario_count
        gen.availability_scenarios[scenario] = clamp(availability, 0.0, 1.0)
    end
    return nothing
end

# Grid integration functions
get_voltage_regulation(gen::ExtendedRenewableGenSys) = gen.voltage_regulation
set_voltage_regulation!(gen::ExtendedRenewableGenSys, capability::Bool) = (gen.voltage_regulation = capability)

get_frequency_response(gen::ExtendedRenewableGenSys) = gen.frequency_response
set_frequency_response!(gen::ExtendedRenewableGenSys, capability::Bool) = (gen.frequency_response = capability)

get_grid_forming_capability(gen::ExtendedRenewableGenSys) = gen.grid_forming_capability
set_grid_forming_capability!(gen::ExtendedRenewableGenSys, capability::Bool) = (gen.grid_forming_capability = capability)

get_inverter_efficiency(gen::ExtendedRenewableGenSys) = gen.inverter_efficiency
set_inverter_efficiency!(gen::ExtendedRenewableGenSys, efficiency::Float64) = (gen.inverter_efficiency = clamp(efficiency, 0.0, 1.0))

# Environmental and policy functions
get_renewable_energy_credits(gen::ExtendedRenewableGenSys) = gen.renewable_energy_credits
set_renewable_energy_credits!(gen::ExtendedRenewableGenSys, credits::Float64) = (gen.renewable_energy_credits = max(credits, 0.0))

get_carbon_offset(gen::ExtendedRenewableGenSys) = gen.carbon_offset
set_carbon_offset!(gen::ExtendedRenewableGenSys, offset::Float64) = (gen.carbon_offset = max(offset, 0.0))

# Performance and reliability functions
get_forced_outage_rate(gen::ExtendedRenewableGenSys) = gen.forced_outage_rate
set_forced_outage_rate!(gen::ExtendedRenewableGenSys, rate::Float64) = (gen.forced_outage_rate = clamp(rate, 0.0, 1.0))

get_reliability_factor(gen::ExtendedRenewableGenSys) = gen.reliability_factor
set_reliability_factor!(gen::ExtendedRenewableGenSys, factor::Float64) = (gen.reliability_factor = clamp(factor, 0.0, 1.0))

# Maintenance functions
get_maintenance_schedule(gen::ExtendedRenewableGenSys) = gen.maintenance_schedule
function add_maintenance_period!(gen::ExtendedRenewableGenSys, period::Int)
    if period > 0 && !(period in gen.maintenance_schedule)
        push!(gen.maintenance_schedule, period)
        sort!(gen.maintenance_schedule)
    end
    return nothing
end

function is_under_maintenance(gen::ExtendedRenewableGenSys, period::Int)
    return period in gen.maintenance_schedule
end

# Performance tracking functions
get_energy_produced(gen::ExtendedRenewableGenSys) = gen.energy_produced
function update_energy_produced!(gen::ExtendedRenewableGenSys, energy::Float64)
    gen.energy_produced += max(energy, 0.0)
    return nothing
end

get_capacity_utilization(gen::ExtendedRenewableGenSys) = gen.capacity_utilization
function calculate_capacity_utilization!(gen::ExtendedRenewableGenSys, hours::Float64)
    if hours > 0 && gen.max_active_power > 0
        gen.capacity_utilization = gen.energy_produced / (gen.max_active_power * hours)
    end
    return gen.capacity_utilization
end

get_curtailment_hours(gen::ExtendedRenewableGenSys) = gen.curtailment_hours
function update_curtailment_hours!(gen::ExtendedRenewableGenSys, hours::Float64)
    gen.curtailment_hours += max(hours, 0.0)
    return nothing
end

# Utility functions
function get_available_power(gen::ExtendedRenewableGenSys, scenario::Int = 1)
    base_power = gen.max_active_power * gen.capacity_factor
    if 1 <= scenario <= gen.scenario_count
        return base_power * gen.availability_scenarios[scenario]
    end
    return base_power * gen.availability_factor
end

function get_effective_cost(gen::ExtendedRenewableGenSys, scenario::Int = 1)
    base_cost = gen.marginal_cost
    if 1 <= scenario <= gen.scenario_count
        return gen.cost_scenarios[scenario]
    end
    return base_cost
end

function is_available(gen::ExtendedRenewableGenSys, scenario::Int = 1)
    return gen.commitment_status && 
           !is_under_maintenance(gen, scenario) && 
           get_available_power(gen, scenario) > 0.0
end

# Reset function
function reset!(gen::ExtendedRenewableGenSys)
    gen.power_output = 0.0
    gen.lambda_avg = 0.0
    gen.energy_produced = 0.0
    gen.capacity_utilization = 0.0
    gen.curtailment_hours = 0.0
    fill!(gen.power_scenarios, 0.0)
    fill!(gen.cost_scenarios, gen.marginal_cost)
    fill!(gen.availability_scenarios, gen.availability_factor)
    fill!(gen.contingency_response, 0.0)
    return nothing
end

# Display function
function Base.show(io::IO, gen::ExtendedRenewableGenSys)
    print(io, "ExtendedRenewableGenSys(")
    print(io, "id=$(gen.gen_id), ")
    print(io, "type=$(gen.prime_mover_type), ")
    print(io, "max_power=$(gen.max_active_power), ")
    print(io, "capacity_factor=$(gen.capacity_factor), ")
    print(io, "node=$(gen.node_connection)")
    print(io, ")")
end

"""
    solve_renewable_generator_subproblem!(gen::ExtendedRenewableGenerator; optimizer_factory, solve_options, time_horizon, include_unit_commitment)

Sys-less overload for the APP distributed algorithm. Updates the solver interval state
from the generator's current operating point, then calls `build_and_solve_gensolver_for_gen!`
with `gen.generator` directly.
"""
function solve_renewable_generator_subproblem!(gen::ExtendedRenewableGenerator;
                                               optimizer_factory=nothing,
                                               solve_options=Dict(),
                                               time_horizon=24,
                                               include_unit_commitment=false)
    # Sync interval state from current generator operating point
    interval = gen.gen_solver.interval_type
    if isa(interval, GenFirstBaseInterval)
        interval.Pg_prev     = gen.P_gen_prev
        interval.Pg_nu       = gen.Pg
        interval.Pg_nu_inner = gen.Pg
        interval.Pg_next_nu  = [gen.P_gen_next]
    end

    renewable_solve_options = merge(solve_options, Dict(
        "include_curtailment_constraints" => true,
        "forecast_power"                  => gen.forecast_power
    ))

    return build_and_solve_gensolver_for_gen!(
        gen.gen_solver, gen.generator;
        optimizer_factory=optimizer_factory,
        solve_options=renewable_solve_options,
        time_horizon=time_horizon
    )
end

"""
    solve_renewable_generator_subproblem!(gen_solver, device; optimizer_factory, solve_options, time_horizon, include_unit_commitment)

Dispatch point for `GeneralizedGenerator` calls arriving from the APP solver. Accepts the
`GenSolver` and raw `PSY.RenewableGen` device exposed by `GeneralizedGenerator` and routes
through `build_and_solve_gensolver_for_gen!`.
"""
function solve_renewable_generator_subproblem!(gen_solver::GenSolver,
                                               device::PSY.RenewableGen;
                                               optimizer_factory=nothing,
                                               solve_options=Dict(),
                                               time_horizon=24,
                                               include_unit_commitment=false)
    renewable_solve_options = merge(solve_options, Dict(
        "include_curtailment_constraints" => true
    ))
    return build_and_solve_gensolver_for_gen!(gen_solver, device;
                                              optimizer_factory=optimizer_factory,
                                              solve_options=renewable_solve_options,
                                              time_horizon=time_horizon)
end

# Export functions
export ExtendedRenewableGenerator
export initialize_renewable_parameters!, extract_renewable_timeseries!
export update_renewable_forecast!, calculate_wind_power, calculate_solar_power
export calculate_renewable_operating_cost
export ExtendedRenewableGenSys
export get_gen_id, get_node_connection, get_zone_id, get_scenario_count
export get_marginal_cost, set_marginal_cost!, get_curtailment_cost, set_curtailment_cost!
export get_capacity_factor, set_capacity_factor!, get_availability_factor, set_availability_factor!
export get_forecast_data, set_forecast_data!, get_forecast_uncertainty, set_forecast_uncertainty!
export get_lambda_avg, set_lambda_avg!, get_power_output, set_power_output!
export get_commitment_status, set_commitment_status!
export get_power_scenarios, set_power_scenario!, get_cost_scenarios, set_cost_scenario!
export get_availability_scenarios, set_availability_scenario!
export get_voltage_regulation, set_voltage_regulation!
export get_frequency_response, set_frequency_response!
export get_grid_forming_capability, set_grid_forming_capability!
export get_inverter_efficiency, set_inverter_efficiency!
export get_renewable_energy_credits, set_renewable_energy_credits!
export get_carbon_offset, set_carbon_offset!
export get_forced_outage_rate, set_forced_outage_rate!
export get_reliability_factor, set_reliability_factor!
export get_maintenance_schedule, add_maintenance_period!, is_under_maintenance
export get_energy_produced, update_energy_produced!
export get_capacity_utilization, calculate_capacity_utilization!
export get_curtailment_hours, update_curtailment_hours!
export get_available_power, get_effective_cost, is_available, reset!
