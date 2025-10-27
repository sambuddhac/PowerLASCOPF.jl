"""
GeneratorScenario for PowerLASCOPF.jl

This module defines the GeneratorScenario struct that handles stochastic scenarios
for generators, including renewable forecasts, hydro availability, and thermal
operation scenarios using PowerSystems time series functionality.
"""

using PowerSystems
using TimeSeries
using Dates
using InfrastructureSystems

const PSY = PowerSystems
const IS = InfrastructureSystems
const TS = TimeSeries

"""
    GeneratorScenario

Represents a stochastic scenario for generator operation, including:
- Renewable power forecasts (wind, solar, etc.)
- Hydro water availability and inflow forecasts
- Thermal generator availability and maintenance schedules
- Load forecasts affecting generator dispatch

Supports both deterministic and stochastic scenarios with probability weights.
"""
mutable struct GeneratorScenario
    # Scenario identification
    scenario_id::Int
    scenario_name::String
    probability::Float64  # Probability weight for stochastic scenarios
    
    # Time series data (from PowerSystems)
    active_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}
    reactive_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}
    renewable_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}  # For wind/solar forecasts
    availability_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}     # Generator availability
    
    # Hydro-specific time series
    inflow_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}          # Water inflow
    storage_level_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}   # Reservoir level
    spillage_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing}        # Water spillage
    
    # Current values (updated during simulation)
    current_active_power::Float64
    current_reactive_power::Float64
    current_renewable_power::Float64
    current_availability::Bool
    current_inflow::Float64          # For hydro generators
    current_storage_level::Float64   # For hydro with reservoirs
    current_spillage::Float64        # For hydro spillage
    
    # Forecast horizon and resolution
    forecast_horizon::Dates.Period
    forecast_resolution::Dates.Period
    forecast_initial_time::Union{DateTime, Nothing}
    
    # Scenario metadata
    weather_condition::String       # "normal", "high_wind", "low_wind", "cloudy", etc.
    season::String                  # "winter", "spring", "summer", "fall"
    load_level::String              # "peak", "off_peak", "shoulder"
    
    # Constructor
    function GeneratorScenario(;
        scenario_id::Int = 1,
        scenario_name::String = "scenario_$scenario_id",
        probability::Float64 = 1.0,
        active_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        reactive_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        renewable_power_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        availability_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        inflow_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        storage_level_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        spillage_series::Union{PSY.SingleTimeSeries, PSY.Deterministic, Nothing} = nothing,
        current_active_power::Float64 = 0.0,
        current_reactive_power::Float64 = 0.0,
        current_renewable_power::Float64 = 0.0,
        current_availability::Bool = true,
        current_inflow::Float64 = 0.0,
        current_storage_level::Float64 = 0.0,
        current_spillage::Float64 = 0.0,
        forecast_horizon::Dates.Period = Dates.Hour(24),
        forecast_resolution::Dates.Period = Dates.Hour(1),
        forecast_initial_time::Union{DateTime, Nothing} = nothing,
        weather_condition::String = "normal",
        season::String = "summer",
        load_level::String = "peak"
    )
        return new(
            scenario_id, scenario_name, probability,
            active_power_series, reactive_power_series, renewable_power_series, availability_series,
            inflow_series, storage_level_series, spillage_series,
            current_active_power, current_reactive_power, current_renewable_power,
            current_availability, current_inflow, current_storage_level, current_spillage,
            forecast_horizon, forecast_resolution, forecast_initial_time,
            weather_condition, season, load_level
        )
    end
end

"""
    create_renewable_scenario(generator::PSY.RenewableGen, forecast_data::Vector{Float64}, 
                             timestamps::Vector{DateTime}; scenario_id::Int = 1, 
                             probability::Float64 = 1.0)

Create a GeneratorScenario for renewable generators with forecast data.
"""
function create_renewable_scenario(
    generator::PSY.RenewableGen, 
    forecast_data::Vector{Float64}, 
    timestamps::Vector{DateTime};
    scenario_id::Int = 1,
    probability::Float64 = 1.0,
    scenario_name::String = "renewable_scenario_$scenario_id",
    weather_condition::String = "normal"
)
    # Create TimeSeries from forecast data
    ts_data = TS.TimeArray(timestamps, forecast_data)
    
    # Create PowerSystems SingleTimeSeries
    renewable_series = PSY.SingleTimeSeries(
        name = "renewable_power_forecast",
        data = ts_data,
        scaling_factor_multiplier = PSY.get_scaling_factor_multiplier,
        units = PSY.UnitSystem.NATURAL_UNITS
    )
    
    # Calculate initial values
    initial_power = isempty(forecast_data) ? PSY.get_rating(generator) : first(forecast_data)
    
    return GeneratorScenario(
        scenario_id = scenario_id,
        scenario_name = scenario_name,
        probability = probability,
        renewable_power_series = renewable_series,
        current_renewable_power = initial_power,
        current_active_power = min(initial_power, PSY.get_rating(generator)),
        forecast_initial_time = isempty(timestamps) ? nothing : first(timestamps),
        forecast_horizon = isempty(timestamps) ? Dates.Hour(24) : timestamps[end] - timestamps[1],
        forecast_resolution = length(timestamps) > 1 ? timestamps[2] - timestamps[1] : Dates.Hour(1),
        weather_condition = weather_condition
    )
end

"""
    create_hydro_scenario(generator::Union{PSY.HydroGen, PSY.HydroDispatch, PSY.HydroEnergyReservoir},
                         inflow_data::Vector{Float64}, timestamps::Vector{DateTime}; 
                         storage_data::Union{Vector{Float64}, Nothing} = nothing,
                         scenario_id::Int = 1, probability::Float64 = 1.0)

Create a GeneratorScenario for hydro generators with inflow and storage forecasts.
"""
function create_hydro_scenario(
    generator::Union{PSY.HydroGen, PSY.HydroDispatch, PSY.HydroEnergyReservoir},
    inflow_data::Vector{Float64},
    timestamps::Vector{DateTime};
    storage_data::Union{Vector{Float64}, Nothing} = nothing,
    scenario_id::Int = 1,
    probability::Float64 = 1.0,
    scenario_name::String = "hydro_scenario_$scenario_id",
    season::String = "summer"
)
    # Create inflow time series
    inflow_ts_data = TS.TimeArray(timestamps, inflow_data)
    inflow_series = PSY.SingleTimeSeries(
        name = "hydro_inflow_forecast",
        data = inflow_ts_data,
        scaling_factor_multiplier = PSY.get_scaling_factor_multiplier,
        units = PSY.UnitSystem.NATURAL_UNITS
    )
    
    # Create storage level time series if provided
    storage_series = nothing
    if !isnothing(storage_data) && length(storage_data) == length(timestamps)
        storage_ts_data = TS.TimeArray(timestamps, storage_data)
        storage_series = PSY.SingleTimeSeries(
            name = "hydro_storage_forecast",
            data = storage_ts_data,
            scaling_factor_multiplier = PSY.get_scaling_factor_multiplier,
            units = PSY.UnitSystem.NATURAL_UNITS
        )
    end
    
    # Calculate initial values
    initial_inflow = isempty(inflow_data) ? 0.0 : first(inflow_data)
    initial_storage = isnothing(storage_data) || isempty(storage_data) ? 0.0 : first(storage_data)
    
    # Estimate power based on inflow and generator capacity
    max_power = PSY.get_active_power_limits(generator).max
    estimated_power = min(initial_inflow * 0.1, max_power)  # Simple conversion factor
    
    return GeneratorScenario(
        scenario_id = scenario_id,
        scenario_name = scenario_name,
        probability = probability,
        inflow_series = inflow_series,
        storage_level_series = storage_series,
        current_inflow = initial_inflow,
        current_storage_level = initial_storage,
        current_active_power = estimated_power,
        forecast_initial_time = isempty(timestamps) ? nothing : first(timestamps),
        forecast_horizon = isempty(timestamps) ? Dates.Hour(24) : timestamps[end] - timestamps[1],
        forecast_resolution = length(timestamps) > 1 ? timestamps[2] - timestamps[1] : Dates.Hour(1),
        season = season
    )
end

"""
    create_thermal_scenario(generator::PSY.ThermalGen, availability_data::Vector{Bool},
                           timestamps::Vector{DateTime}; scenario_id::Int = 1, 
                           probability::Float64 = 1.0)

Create a GeneratorScenario for thermal generators with availability schedules.
"""
function create_thermal_scenario(
    generator::PSY.ThermalGen,
    availability_data::Vector{Bool},
    timestamps::Vector{DateTime};
    scenario_id::Int = 1,
    probability::Float64 = 1.0,
    scenario_name::String = "thermal_scenario_$scenario_id",
    load_level::String = "peak"
)
    # Convert Bool to Float64 for TimeSeries
    availability_float = Float64.(availability_data)
    
    # Create availability time series
    availability_ts_data = TS.TimeArray(timestamps, availability_float)
    availability_series = PSY.SingleTimeSeries(
        name = "thermal_availability_schedule",
        data = availability_ts_data,
        scaling_factor_multiplier = PSY.get_scaling_factor_multiplier,
        units = PSY.UnitSystem.NATURAL_UNITS
    )
    
    # Calculate initial values
    initial_availability = isempty(availability_data) ? true : first(availability_data)
    max_power = PSY.get_active_power_limits(generator).max
    current_power = initial_availability ? PSY.get_active_power(generator) : 0.0
    
    return GeneratorScenario(
        scenario_id = scenario_id,
        scenario_name = scenario_name,
        probability = probability,
        availability_series = availability_series,
        current_availability = initial_availability,
        current_active_power = current_power,
        forecast_initial_time = isempty(timestamps) ? nothing : first(timestamps),
        forecast_horizon = isempty(timestamps) ? Dates.Hour(24) : timestamps[end] - timestamps[1],
        forecast_resolution = length(timestamps) > 1 ? timestamps[2] - timestamps[1] : Dates.Hour(1),
        load_level = load_level
    )
end

"""
    create_scenarios_from_psy_timeseries(generator::PSY.Generator; max_scenarios::Int = 5)

Extract scenarios from PowerSystems time series data attached to a generator.
"""
function create_scenarios_from_psy_timeseries(generator::PSY.Generator; max_scenarios::Int = 5)
    scenarios = GeneratorScenario[]
    
    try
	# Get all time series keys from the generator
	ts_keys = PSY.get_time_series_keys(generator)
	
	if isempty(ts_keys)
		# Create default scenario if no time series available
		default_scenario = GeneratorScenario(
		scenario_id = 1,
		scenario_name = "default_$(PSY.get_name(generator))",
		probability = 1.0,
		current_active_power = PSY.get_active_power(generator),
		current_availability = PSY.get_available(generator)
		)
		
		if isa(generator, PSY.RenewableGen)
		default_scenario.current_renewable_power = PSY.get_rating(generator)
		end
		
		push!(scenarios, default_scenario)
		return scenarios
	end
	
	# Process each time series
	scenario_count = 0
	for ts_key in ts_keys
		if scenario_count >= max_scenarios
		break
		end
		
		try
		ts_data = PSY.get_time_series(generator, ts_key)
		scenario_count += 1
		
		scenario = GeneratorScenario(
			scenario_id = scenario_count,
			scenario_name = "$(PSY.get_name(generator))_$(ts_key)",
			probability = 1.0 / min(length(ts_keys), max_scenarios)
		)
		
		# Assign time series based on key and generator type
		if isa(generator, PSY.RenewableGen)
			if occursin("renewable", lowercase(string(ts_key))) || 
			occursin("wind", lowercase(string(ts_key))) || 
			occursin("solar", lowercase(string(ts_key)))
			scenario.renewable_power_series = ts_data
			# Get first value
			first_val = PSY.get_data(ts_data)[1]
			scenario.current_renewable_power = first_val
			scenario.current_active_power = min(first_val, PSY.get_rating(generator))
			end
		elseif isa(generator, Union{PSY.HydroGen, PSY.HydroDispatch, PSY.HydroEnergyReservoir})
			if occursin("inflow", lowercase(string(ts_key)))
			scenario.inflow_series = ts_data
			scenario.current_inflow = PSY.get_data(ts_data)[1]
			elseif occursin("storage", lowercase(string(ts_key))) || 
			occursin("reservoir", lowercase(string(ts_key)))
			scenario.storage_level_series = ts_data
			scenario.current_storage_level = PSY.get_data(ts_data)[1]
			end
		elseif isa(generator, PSY.ThermalGen)
			if occursin("availability", lowercase(string(ts_key)))
			scenario.availability_series = ts_data
			scenario.current_availability = PSY.get_data(ts_data)[1] > 0.5
			end
		end
		
		# Set default active power if not set
		if scenario.current_active_power == 0.0
			scenario.current_active_power = PSY.get_active_power(generator)
		end
		
		# Extract time information
		ts_times = PSY.get_timestamps(ts_data)
		if !isempty(ts_times)
			scenario.forecast_initial_time = first(ts_times)
			scenario.forecast_horizon = last(ts_times) - first(ts_times)
			if length(ts_times) > 1
			scenario.forecast_resolution = ts_times[2] - ts_times[1]
			end
		end
		
		push!(scenarios, scenario)
		
		catch e
		@warn "Failed to process time series $ts_key for generator $(PSY.get_name(generator)): $e"
		end
	end
    catch e
	@warn "Failed to get time series keys for generator $(PSY.get_name(generator)): $e"
    end
    
    # Ensure we have at least one scenario
    if isempty(scenarios)
        push!(scenarios, GeneratorScenario(
            scenario_id = 1,
            scenario_name = "fallback_$(PSY.get_name(generator))",
            probability = 1.0,
            current_active_power = PSY.get_active_power(generator),
            current_availability = PSY.get_available(generator)
        ))
    end
    
    return scenarios
end

"""
    update_scenario_at_time!(scenario::GeneratorScenario, time::DateTime)

Update scenario values at a specific time using time series data.
"""
function update_scenario_at_time!(scenario::GeneratorScenario, time::DateTime)
    # Update renewable power
    if !isnothing(scenario.renewable_power_series)
        try
            scenario.current_renewable_power = PSY.get_value_at_time(scenario.renewable_power_series, time)
        catch e
            @debug "Could not get renewable power at time $time: $e"
        end
    end
    
    # Update availability
    if !isnothing(scenario.availability_series)
        try
            availability_val = PSY.get_value_at_time(scenario.availability_series, time)
            scenario.current_availability = availability_val > 0.5
        catch e
            @debug "Could not get availability at time $time: $e"
        end
    end
    
    # Update inflow
    if !isnothing(scenario.inflow_series)
        try
            scenario.current_inflow = PSY.get_value_at_time(scenario.inflow_series, time)
        catch e
            @debug "Could not get inflow at time $time: $e"
        end
    end
    
    # Update storage level
    if !isnothing(scenario.storage_level_series)
        try
            scenario.current_storage_level = PSY.get_value_at_time(scenario.storage_level_series, time)
        catch e
            @debug "Could not get storage level at time $time: $e"
        end
    end
    
    # Update active power if available
    if !isnothing(scenario.active_power_series)
        try
            scenario.current_active_power = PSY.get_value_at_time(scenario.active_power_series, time)
        catch e
            @debug "Could not get active power at time $time: $e"
        end
    end
end

"""
    get_scenario_value_at_time(scenario::GeneratorScenario, variable::Symbol, time::DateTime)

Get a specific variable value from the scenario at a given time.
"""
function get_scenario_value_at_time(scenario::GeneratorScenario, variable::Symbol, time::DateTime)
    if variable == :renewable_power && !isnothing(scenario.renewable_power_series)
        return PSY.get_value_at_time(scenario.renewable_power_series, time)
    elseif variable == :inflow && !isnothing(scenario.inflow_series)
        return PSY.get_value_at_time(scenario.inflow_series, time)
    elseif variable == :storage_level && !isnothing(scenario.storage_level_series)
        return PSY.get_value_at_time(scenario.storage_level_series, time)
    elseif variable == :availability && !isnothing(scenario.availability_series)
        return PSY.get_value_at_time(scenario.availability_series, time) > 0.5
    elseif variable == :active_power && !isnothing(scenario.active_power_series)
        return PSY.get_value_at_time(scenario.active_power_series, time)
    else
        error("Unknown variable $variable or time series not available")
    end
end

# Export functions and types
export GeneratorScenario
export create_renewable_scenario, create_hydro_scenario, create_thermal_scenario
export create_scenarios_from_psy_timeseries
export update_scenario_at_time!, get_scenario_value_at_time