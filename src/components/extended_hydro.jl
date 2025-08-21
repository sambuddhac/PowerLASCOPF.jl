# Extended Hydro Generator Type
# This implements detailed hydro power modeling with reservoir dynamics

using JuMP
using PowerSystems
using TimeSeries

"""
Extended Hydro Generator with detailed reservoir modeling
Includes:
- Reservoir water level tracking
- Inflow forecasting and uncertainty
- Water value optimization
- Environmental constraints
- Cascade reservoir modeling
- Pumped storage capabilities
"""
mutable struct ExtendedHydroGenerator <: HydroGen
    name::String
    available::Bool
    bus::Bus
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PrimeMovers
    active_power_limits::MinMax
    reactive_power_limits::Union{Nothing, MinMax}
    ramp_limits::Union{Nothing, UpDown}
    operation_cost::OperationalCost
    base_power::Float64
    services::Vector{Service}
    dynamic_injector::Union{Nothing, DynamicInjection}
    ext::Dict{String, Any}
    time_series_container::InfrastructureSystemsInternal.TimeSeriesContainer
    internal::InfrastructureSystemsInternal.InfrastructureSystemsInternal
    
    # Basic hydro parameters
    storage_capacity::StorageCapacity
    inflow::Float64
    initial_storage::Float64
    
    # Extended hydro parameters
    reservoir_capacity::Float64      # Maximum reservoir volume (acre-feet or m³)
    current_level::Float64          # Current water level (feet or meters)
    min_level::Float64             # Minimum operating level
    max_level::Float64             # Maximum operating level
    dead_storage::Float64          # Dead storage volume
    active_storage::Float64        # Current active storage
    head::Float64                  # Hydraulic head (feet or meters)
    efficiency::Float64            # Turbine efficiency
    flow_rate::Float64             # Current flow rate (cfs or m³/s)
    max_flow_rate::Float64         # Maximum turbine flow rate
    min_flow_rate::Float64         # Minimum environmental flow
    tailwater_level::Float64       # Tailwater elevation
    
    # Inflow and forecasting
    historical_inflow::Vector{Float64}  # Historical inflow data
    inflow_forecast::Vector{Float64}    # Forecasted inflow
    inflow_uncertainty::Float64         # Inflow forecast uncertainty (std dev)
    seasonal_pattern::Vector{Float64}   # Seasonal inflow multipliers
    
    # Water value and economics
    water_value::Float64            # Shadow price of water ($/acre-foot)
    spillage_cost::Float64          # Cost of spilling water
    shortage_cost::Float64          # Cost of water shortage
    opportunity_cost::Float64       # Opportunity cost of water use
    
    # Environmental and operational constraints
    environmental_flow::Float64     # Minimum environmental flow requirement
    ramping_rate::Float64          # Maximum ramping rate (MW/min)
    start_stop_cost::Float64       # Cost of starting/stopping units
    maintenance_schedule::Vector{Bool} # Planned maintenance periods
    
    # Pumped storage specific (if applicable)
    is_pumped_storage::Bool        # Whether this is pumped storage
    pump_efficiency::Float64       # Pumping efficiency
    max_pump_power::Float64        # Maximum pumping power
    upper_reservoir::Union{Nothing, ExtendedHydroGenerator}  # Reference to upper reservoir
    lower_reservoir::Union{Nothing, ExtendedHydroGenerator}  # Reference to lower reservoir
    
    # Cascade system
    upstream_plants::Vector{ExtendedHydroGenerator}    # Upstream hydro plants
    downstream_plants::Vector{ExtendedHydroGenerator}  # Downstream hydro plants
    travel_time::Float64           # Water travel time to downstream (hours)
    
    # Stochastic optimization parameters
    scenarios::Vector{Vector{Float64}}  # Inflow scenarios for stochastic optimization
    scenario_probabilities::Vector{Float64}  # Probability of each scenario
    risk_measure::String           # Risk measure (CVaR, worst-case, etc.)
    risk_parameter::Float64        # Risk aversion parameter
end

# Constructor with default values
function ExtendedHydroGenerator(
    name::String,
    available::Bool,
    bus::Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    storage_capacity::StorageCapacity,
    inflow::Float64,
    initial_storage::Float64;
    prime_mover_type::PrimeMovers = PrimeMovers.HY,
    active_power_limits::MinMax = MinMax(0.0, rating),
    reactive_power_limits::Union{Nothing, MinMax} = MinMax(-rating*0.3, rating*0.3),
    ramp_limits::Union{Nothing, UpDown} = UpDown(rating*0.1, rating*0.1),
    operation_cost::OperationalCost = TwoPartCost(0.0, 5.0),
    base_power::Float64 = 100.0,
    services::Vector{Service} = Service[],
    dynamic_injector::Union{Nothing, DynamicInjection} = nothing,
    ext::Dict{String, Any} = Dict{String, Any}(),
    reservoir_capacity::Float64 = 100000.0,
    current_level::Float64 = 1000.0,
    min_level::Float64 = 950.0,
    max_level::Float64 = 1050.0,
    dead_storage::Float64 = 10000.0,
    head::Float64 = 100.0,
    efficiency::Float64 = 0.9,
    max_flow_rate::Float64 = 1000.0,
    min_flow_rate::Float64 = 50.0,
    tailwater_level::Float64 = 900.0,
    inflow_uncertainty::Float64 = 0.2,
    water_value::Float64 = 50.0,
    spillage_cost::Float64 = 10.0,
    shortage_cost::Float64 = 1000.0,
    environmental_flow::Float64 = 100.0,
    ramping_rate::Float64 = rating * 0.05,
    is_pumped_storage::Bool = false,
    pump_efficiency::Float64 = 0.85,
    max_pump_power::Float64 = 0.0,
    travel_time::Float64 = 2.0
)
    
    active_storage = max(0.0, (current_level - min_level) / (max_level - min_level) * 
                             (reservoir_capacity - dead_storage))
    
    return ExtendedHydroGenerator(
        name, available, bus, active_power, reactive_power, rating,
        prime_mover_type, active_power_limits, reactive_power_limits,
        ramp_limits, operation_cost, base_power, services, dynamic_injector,
        ext, InfrastructureSystemsInternal.TimeSeriesContainer(),
        InfrastructureSystemsInternal.InfrastructureSystemsInternal(),
        storage_capacity, inflow, initial_storage,
        reservoir_capacity, current_level, min_level, max_level,
        dead_storage, active_storage, head, efficiency, 0.0,
        max_flow_rate, min_flow_rate, tailwater_level,
        Float64[], Float64[], inflow_uncertainty, Float64[],
        water_value, spillage_cost, shortage_cost, 0.0,
        environmental_flow, ramping_rate, 0.0, Bool[],
        is_pumped_storage, pump_efficiency, max_pump_power, nothing, nothing,
        ExtendedHydroGenerator[], ExtendedHydroGenerator[], travel_time,
        Vector{Float64}[], Float64[], "expectation", 0.1
    )
end

# Core hydro functions
"""
Calculate power output based on flow rate and head
"""
function calculate_power_output(hydro::ExtendedHydroGenerator, flow_rate::Float64)
    # P = ρ * g * Q * H * η / 1000  (MW)
    # Using simplified formula: P = k * Q * H * η
    k = 0.00981  # Conversion factor for metric units
    net_head = hydro.head - hydro.tailwater_level
    power = k * flow_rate * net_head * hydro.efficiency
    return min(power, hydro.rating)
end

"""
Calculate required flow rate for given power output
"""
function calculate_required_flow(hydro::ExtendedHydroGenerator, power::Float64)
    if power <= 0
        return hydro.min_flow_rate
    end
    
    k = 0.00981
    net_head = hydro.head - hydro.tailwater_level
    required_flow = power / (k * net_head * hydro.efficiency)
    return max(hydro.min_flow_rate, min(hydro.max_flow_rate, required_flow))
end

"""
Update reservoir level based on inflow and outflow
"""
function update_reservoir_level!(hydro::ExtendedHydroGenerator, outflow::Float64, 
                                inflow::Float64, dt::Float64)
    # Convert flow rates to volume change
    volume_change = (inflow - outflow) * dt * 3600  # Convert hours to seconds
    
    # Update active storage
    hydro.active_storage += volume_change
    hydro.active_storage = max(0.0, min(hydro.reservoir_capacity - hydro.dead_storage, 
                                       hydro.active_storage))
    
    # Update water level
    storage_ratio = hydro.active_storage / (hydro.reservoir_capacity - hydro.dead_storage)
    hydro.current_level = hydro.min_level + storage_ratio * (hydro.max_level - hydro.min_level)
    
    # Update head (simplified - assumes constant relationship)
    hydro.head = hydro.current_level - hydro.tailwater_level
end

"""
Calculate water value based on current and future conditions
"""
function calculate_water_value(hydro::ExtendedHydroGenerator, time_horizon::Int = 24)
    # Dynamic programming approach for water value calculation
    base_value = hydro.water_value
    
    # Adjust for reservoir level
    level_factor = (hydro.current_level - hydro.min_level) / (hydro.max_level - hydro.min_level)
    scarcity_multiplier = level_factor < 0.3 ? 2.0 : (level_factor > 0.8 ? 0.5 : 1.0)
    
    # Adjust for seasonal patterns and forecasted inflow
    seasonal_factor = length(hydro.seasonal_pattern) > 0 ? 
                     hydro.seasonal_pattern[mod1(hour(now()), length(hydro.seasonal_pattern))] : 1.0
    
    # Future value consideration
    future_inflow = sum(hydro.inflow_forecast[1:min(time_horizon, length(hydro.inflow_forecast))])
    inflow_factor = future_inflow < hydro.inflow * time_horizon * 0.8 ? 1.5 : 0.8
    
    return base_value * scarcity_multiplier * seasonal_factor * inflow_factor
end

"""
Calculate spillage if reservoir is above maximum level
"""
function calculate_spillage(hydro::ExtendedHydroGenerator)
    if hydro.current_level > hydro.max_level
        excess_volume = (hydro.current_level - hydro.max_level) / 
                       (hydro.max_level - hydro.min_level) * 
                       (hydro.reservoir_capacity - hydro.dead_storage)
        return excess_volume / 3600  # Convert to flow rate
    end
    return 0.0
end

# Cascade operations
"""
Add upstream plant to cascade
"""
function add_upstream_plant!(hydro::ExtendedHydroGenerator, upstream::ExtendedHydroGenerator)
    if !(upstream in hydro.upstream_plants)
        push!(hydro.upstream_plants, upstream)
        push!(upstream.downstream_plants, hydro)
    end
end

"""
Calculate inflow from upstream plants
"""
function calculate_cascade_inflow(hydro::ExtendedHydroGenerator, dt::Float64)
    total_inflow = hydro.inflow  # Natural inflow
    
    for upstream in hydro.upstream_plants
        # Delayed inflow based on travel time
        delay_periods = Int(ceil(upstream.travel_time / dt))
        if delay_periods == 0
            total_inflow += upstream.flow_rate
        else
            # In practice, you'd maintain a queue of delayed flows
            total_inflow += upstream.flow_rate  # Simplified
        end
    end
    
    return total_inflow
end

# Optimization model functions
"""
Add hydro variables to optimization model
"""
function add_hydro_variables!(model::Model, hydro::ExtendedHydroGenerator, time_periods::Int)
    # Power generation variables
    @variable(model, p_hydro[1:time_periods] >= 0)
    
    # Flow rate variables
    @variable(model, flow[1:time_periods])
    
    # Storage level variables
    @variable(model, storage[1:time_periods+1])
    
    # Spillage variables
    @variable(model, spillage[1:time_periods] >= 0)
    
    # Binary variables for unit commitment (if needed)
    @variable(model, u_hydro[1:time_periods], Bin)
    
    # Pumped storage variables (if applicable)
    if hydro.is_pumped_storage
        @variable(model, p_pump[1:time_periods] >= 0)
        @variable(model, u_pump[1:time_periods], Bin)
    end
    
    return model
end

"""
Add hydro constraints to optimization model
"""
function add_hydro_constraints!(model::Model, hydro::ExtendedHydroGenerator, 
                               time_periods::Int, dt::Float64 = 1.0)
    p_hydro = model[:p_hydro]
    flow = model[:flow]
    storage = model[:storage]
    spillage = model[:spillage]
    u_hydro = model[:u_hydro]
    
    # Initial storage
    @constraint(model, storage[1] == hydro.active_storage)
    
    # Water balance for each time period
    for t in 1:time_periods
        expected_inflow = t <= length(hydro.inflow_forecast) ? 
                         hydro.inflow_forecast[t] : hydro.inflow
        
        @constraint(model, storage[t+1] == storage[t] + 
                   (expected_inflow - flow[t] - spillage[t]) * dt * 3600)
    end
    
    # Storage limits
    max_storage = hydro.reservoir_capacity - hydro.dea