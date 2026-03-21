"""
Extended Hydro Generator component for PowerLASCOPF.jl

This module defines the ExtendedHydroGenerator struct that extends PowerSystems hydro generators
for LASCOPF optimization with ADMM/APP state variables, hydro-specific constraints,
and enhanced hydro cost modeling.
"""
# Extended Hydro Generator Type
# This implements detailed hydro power modeling with reservoir dynamics, inflow forecasting,
using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries
using JuMP
using Ipopt

# Import necessary types from PowerSystems and InfrastructureSystems
const PSY = PowerSystems
const IS = InfrastructureSystems

# Import only types that exist in your PowerSystems version
import PowerSystems: MinMax, UpDown, PrimeMovers, Bus, Service, DynamicInjection
import PowerSystems: OperationalCost
# Include necessary modules from the codebase
include("../core/types.jl")
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedHydroGenerationCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedHydroGenerator{T<:PSY.HydroGen, U<:GenIntervals}

An extended hydro generator component that extends PowerSystems hydro generators for LASCOPF optimization.
Supports HydroDispatch, HydroEnergyReservoir, HydroPumpedStorage, and other hydro types with
hydro-specific constraints like water flow limits, reservoir levels, and pumping capabilities.
"""
@kwdef mutable struct ExtendedHydroGenerator{T<:PSY.HydroGen, U<:GenIntervals} <: PowerGenerator
    # Core hydro generator from PowerSystems
    generator::T  # Can be HydroDispatch, HydroEnergyReservoir, HydroPumpedStorage, etc.
    
    # Extended hydro cost function with regularization
    hydro_cost_function::ExtendedHydroGenerationCost{U}
    
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
    
    # Solver interface for hydro generators
    gen_solver::GenSolver{ExtendedHydroGenerationCost{U}, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Hydro-specific operating variables
    reservoir_level::Float64 = 0.0              # Current reservoir level (MWh or acre-feet)
    water_flow_rate::Float64 = 0.0              # Water flow rate (acre-feet/hour)
    spillage::Float64 = 0.0                     # Water spillage (acre-feet/hour)
    pumping_power::Float64 = 0.0                # Pumping power for PSH (MW)
    generation_efficiency::Float64 = 0.9        # Generation efficiency
    pumping_efficiency::Float64 = 0.8           # Pumping efficiency (for PSH)
    
    # Hydro constraints tracking
    water_flow_violation::Float64 = 0.0         # Water flow constraint violations
    reservoir_level_violation::Float64 = 0.0    # Reservoir level violations
    ramp_rate_violation::Float64 = 0.0          # Ramp rate violations
    
    # Environmental and operational variables
    water_value::Float64 = 0.0                  # Water opportunity cost ($/acre-foot)
    environmental_flow::Float64 = 0.0           # Minimum environmental flow requirement
    fish_ladder_flow::Float64 = 0.0             # Fish ladder flow requirement
    irrigation_demand::Float64 = 0.0            # Irrigation water demand
    
    # Hydro timeseries management
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    inflow_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    water_price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    irrigation_schedule::Union{TimeSeries.TimeArray, Nothing} = nothing
    environmental_constraints::Union{TimeSeries.TimeArray, Nothing} = nothing
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Capacity factor
    availability_factor::Float64 = 1.0          # Availability factor
    water_utilization_efficiency::Float64 = 0.0 # Water utilization efficiency
    
    # Hydro-specific cache
    _hydro_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedHydroGenerator(
        generator::T,
        hydro_cost_function::ExtendedHydroGenerationCost{U},
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
    ) where {T<:PSY.HydroGen, U<:GenIntervals}
        
        # Create solver with hydro cost model
        gensolver = GenSolver(
            interval_type = hydro_cost_function.regularization_term,
            cost_curve = hydro_cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.hydro_cost_function = hydro_cost_function
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
        
        # Initialize hydro-specific parameters
        initialize_hydro_parameters!(self)
        
        # Extract timeseries data
        extract_hydro_timeseries!(self)
        
        # Set initial generator data
        set_hydro_gen_data!(self)
        
        return self
    end
end

"""
    initialize_hydro_parameters!(gen::ExtendedHydroGenerator)

Initialize hydro-specific parameters from the PowerSystems hydro generator.
"""
function initialize_hydro_parameters!(gen::ExtendedHydroGenerator{T}) where T
    psy_gen = gen.generator
    
    # Extract basic parameters
    gen.Pg = PSY.get_active_power(psy_gen)
    gen.P_gen_prev = gen.Pg
    gen.P_gen_next = gen.Pg
    
    # Initialize hydro-specific parameters based on type
    if isa(psy_gen, PSY.HydroEnergyReservoir)
        # Reservoir-based hydro
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits  # Extract the upper limit (Float64)
        gen.reservoir_level = max_storage * 0.5  # Start at 50% of max capacity
        
        # Get inflow and outflow characteristics
        inflow = PSY.get_inflow(psy_gen)
        gen.water_flow_rate = inflow
        
    elseif isa(psy_gen, PSY.HydroPumpedStorage)
        # Pumped storage hydro
        # Reservoir-based hydro
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits.up  # Extract the upper limit (Float64)
        gen.reservoir_level = max_storage * 0.5  # Start at 50% of max capacity
        outflow = PSY.get_outflow(psy_gen)
        
        # Get pump and generation characteristics
        pump_load = PSY.get_pump_efficiency(psy_gen) #**THIS NEEDS FURTHER CHECKING**
        gen.pumping_power = pump_load
        gen.pumping_efficiency = 0.8  # Default efficiency
        
    elseif isa(psy_gen, PSY.HydroDispatch)
        # Run-of-river or dispatch hydro
        gen.water_flow_rate = 100.0  # Default flow rate
        gen.reservoir_level = 0.0    # No reservoir
    end
    
    # Initialize efficiency and water value
    gen.generation_efficiency = 0.9
    gen.water_value = 10.0  # $/acre-foot
    
    # Initialize performance metrics
    rating = PSY.get_rating(psy_gen)
    if rating > 0 && gen.Pg >= 0
        gen.capacity_factor = gen.Pg / rating
    end
end

"""
    extract_hydro_timeseries!(gen::ExtendedHydroGenerator)

Extract hydro-specific timeseries data from PowerSystems generator.
"""
function extract_hydro_timeseries!(gen::ExtendedHydroGenerator)
    psy_gen = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries - use correct PowerSystems function
    try
        if IS.has_time_series(psy_gen)
            # Get all time series keys
            ts_keys = PSY.get_time_series_keys(psy_gen)

            if !isempty(ts_keys)
                for ts_name in ts_keys
                    try
                        ts_data = PSY.get_time_series(psy_gen, ts_name)
                        key_name = string(ts_name.name)
                
                        # Map timeseries based on name
                        if occursin("Inflow", string(ts_name)) || occursin("Flow", string(ts_name))
                            gen.inflow_forecast = ts_data
                        elseif occursin("WaterPrice", string(ts_name)) || occursin("Water", string(ts_name))
                            gen.water_price_forecast = ts_data
                        elseif occursin("Irrigation", string(ts_name))
                            gen.irrigation_schedule = ts_data
                        elseif occursin("Environmental", string(ts_name)) || occursin("MinFlow", string(ts_name))
                            gen.environmental_constraints = ts_data
                        end
                    
                    catch e
                        @debug "Could not extract timeseries $ts_name for hydro generator $(PSY.get_name(psy_gen)): $e"
                    end
                end
            end
        else
            @info "No timeseries data available for hydro generator $(PSY.get_name(psy_gen))"
        end
        
    catch e
        @warn "Failed to get timeseries names for hydro generator $(PSY.get_name(psy_gen)): $e"
    end
end

"""
    set_hydro_gen_data!(gen::ExtendedHydroGenerator)

Set hydro generator data and validate hydro-specific constraints.
"""
function set_hydro_gen_data!(gen::ExtendedHydroGenerator{T}) where T
    psy_gen = gen.generator
    
    # Validate power constraints
    active_power_limits = PSY.get_active_power_limits(psy_gen)
    gen.Pg = clamp(gen.Pg, active_power_limits.min, active_power_limits.max)
    
    # Validate hydro-specific constraints based on type
    if isa(psy_gen, PSY.HydroEnergyReservoir)
        # Check reservoir level constraints
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits
        min_storage = 0.0  # Assuming minimum storage is 0 for simplicity

        if gen.reservoir_level > max_storage
            gen.reservoir_level_violation = gen.reservoir_level - max_storage
            gen.reservoir_level = max_storage
        elseif gen.reservoir_level < min_storage
            gen.reservoir_level_violation = min_storage - gen.reservoir_level
            gen.reservoir_level = min_storage
        end
        
        # Check water flow constraints
        inflow_limits = PSY.get_inflow(psy_gen)
        if gen.water_flow_rate > inflow_limits
            gen.water_flow_violation = gen.water_flow_rate - inflow_limits
            gen.water_flow_rate = inflow_limits
        end
        
    elseif isa(psy_gen, PSY.HydroPumpedStorage)
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits.up
        min_storage = storage_limits.down
        gen.reservoir_level = clamp(gen.reservoir_level, min_storage, max_storage)

        # Check water flow constraints
        outflow_limits = PSY.get_outflow(psy_gen)
        if gen.water_flow_rate > outflow_limits
            gen.water_flow_violation = gen.water_flow_rate - outflow_limits
            gen.water_flow_rate = outflow_limits
        end
        
        # Ensure only generation OR pumping, not both
        pump_load = PSY.get_pump_efficiency(psy_gen) #**THIS NEEDS FURTHER CHECKING**
        if gen.Pg > 0 && gen.pumping_power > 0
            # Prioritize generation
            gen.pumping_power = 0.0
        end
    end
    
    # Update water utilization efficiency
    update_hydro_performance!(gen)
end

"""
    update_hydro_performance!(gen::ExtendedHydroGenerator)

Update hydro performance metrics based on current operating point.
"""
function update_hydro_performance!(gen::ExtendedHydroGenerator{T}) where T
    if gen.Pg > 0
        # Calculate water utilization efficiency
        if gen.water_flow_rate > 0
            gen.water_utilization_efficiency = gen.Pg / gen.water_flow_rate
        end
        
        # Update reservoir level based on generation (simplified)
        if isa(gen.generator, PSY.HydroEnergyReservoir)
            # Decrease reservoir level based on generation
            water_used = gen.Pg / gen.generation_efficiency
            gen.reservoir_level = max(0.0, gen.reservoir_level - water_used)
            
        elseif isa(gen.generator, PSY.HydroPumpedStorage)
            # For PSH in generation mode, decrease reservoir level
            water_used = gen.Pg / gen.generation_efficiency
            
            # Get minimum storage capacity to respect lower bound
            storage_limits = PSY.get_storage_capacity(gen.generator)
            min_storage = storage_limits.down  # Extract lower limit
            
            gen.reservoir_level = max(min_storage, gen.reservoir_level - water_used)
        end
        
    elseif isa(gen.generator, PSY.HydroPumpedStorage) && gen.pumping_power > 0
        # Pumping mode - increase reservoir level
        water_pumped = gen.pumping_power * gen.pumping_efficiency
        
        # Get storage capacity limits and extract the upper bound
        storage_limits = PSY.get_storage_capacity(gen.generator)
        max_storage = storage_limits.up  # Extract upper limit (Float64)
        min_storage = storage_limits.down  # Extract lower limit (Float64)
        
        # Increase reservoir level but don't exceed maximum capacity
        gen.reservoir_level = min(max_storage, gen.reservoir_level + water_pumped)
        gen.capacity_factor = 0.0  # Not generating
        
    else
        gen.water_utilization_efficiency = 0.0
        gen.capacity_factor = 0.0
    end

    # Additional safety check: ensure reservoir level stays within bounds for all hydro types
    #=if isa(gen.generator, PSY.HydroEnergyReservoir) || isa(gen.generator, PSY.HydroPumpedStorage)
        storage_limits = PSY.get_storage_capacity(gen.generator)
        max_storage = storage_limits.up
        min_storage = storage_limits.down
        
        # Clamp reservoir level to valid range
        gen.reservoir_level = clamp(gen.reservoir_level, min_storage, max_storage)=#
        
        # Track violations if they occur
        #=if gen.reservoir_level == max_storage && (gen.reservoir_level + water_pumped > max_storage rescue false)
            gen.reservoir_level_violation = (gen.reservoir_level + water_pumped) - max_storage
        elseif gen.reservoir_level == min_storage && (gen.reservoir_level - water_used < min_storage rescue false)
            gen.reservoir_level_violation = min_storage - (gen.reservoir_level - water_used)
        else
            gen.reservoir_level_violation = 0.0
        end
    end=#
end

"""
    calculate_hydro_operating_cost(gen::ExtendedHydroGenerator, time_step::Float64 = 1.0)::Float64

Calculate total hydro operating cost including water opportunity cost.
"""
function calculate_hydro_operating_cost(gen::ExtendedHydroGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    # Variable operating cost (typically low for hydro)
    if is_regularization_active(gen.hydro_cost_function)
        total_cost += build_hydro_cost_expression(
            gen.hydro_cost_function, 
            gen.Pg, 
            gen.P_gen_next, 
            gen.theta_g
        )
    else
        # Simple cost model
        op_cost = PSY.get_operation_cost(gen.generator)
        var_cost = PSY.get_variable(op_cost)
        total_cost += var_cost * gen.Pg * time_step
    end
    
    # Water opportunity cost
    if gen.Pg > 0
        water_used = gen.Pg / gen.generation_efficiency
        total_cost += gen.water_value * water_used * time_step
    end
    
    # Pumping cost for PSH
    if isa(gen.generator, PSY.HydroPumpedStorage) && gen.pumping_power > 0
        # Cost of electricity for pumping (simplified)
        pumping_cost = 50.0  # $/MWh
        total_cost += pumping_cost * gen.pumping_power * time_step
    end
    
    return total_cost
end

# ...existing code for solver functions...


# Define simple alternative types for missing ones
struct SimpleStorageCapacity
    min::Float64
    max::Float64
end

struct SimpleTwoPartCost <: PSY.OperationalCost
    variable::Float64
    fixed::Float64
end

# Use Dict as a simple alternative to TimeSeriesContainer
const SimpleTimeSeriesContainer = Dict{String, Any}

# Simple internal structure
struct SimpleInternalStructure
    uuid::Base.UUID
    ext::Dict{String, Any}
    
    SimpleInternalStructure() = new(Base.uuid4(), Dict{String, Any}())
end

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
mutable struct ExtendedHydroReservoir <: PSY.HydroGen
    name::String
    available::Bool
    bus::PSY.Bus
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PSY.PrimeMovers
    active_power_limits::PSY.MinMax
    reactive_power_limits::Union{Nothing, PSY.MinMax}
    ramp_limits::Union{Nothing, PSY.UpDown}
    operation_cost::PSY.OperationalCost
    base_power::Float64
    services::Vector{PSY.Service}
    dynamic_injector::Union{Nothing, PSY.DynamicInjection}
    ext::Dict{String, Any}
    time_series_container::SimpleTimeSeriesContainer  # Use simple alternative
    internal::SimpleInternalStructure                 # Use simple alternative
    
    # Basic hydro parameters
    storage_capacity::SimpleStorageCapacity  # Use simple alternative
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
    upper_reservoir::Union{Nothing, ExtendedHydroReservoir}  # Reference to upper reservoir
    lower_reservoir::Union{Nothing, ExtendedHydroReservoir}  # Reference to lower reservoir
    
    # Cascade system
    upstream_plants::Vector{ExtendedHydroReservoir}    # Upstream hydro plants
    downstream_plants::Vector{ExtendedHydroReservoir}  # Downstream hydro plants
    travel_time::Float64           # Water travel time to downstream (hours)
    
    # Stochastic optimization parameters
    scenarios::Vector{Vector{Float64}}  # Inflow scenarios for stochastic optimization
    scenario_probabilities::Vector{Float64}  # Probability of each scenario
    risk_measure::String           # Risk measure (CVaR, worst-case, etc.)
    risk_parameter::Float64        # Risk aversion parameter
end

# Constructor with default values
function ExtendedHydroReservoir(
    name::String,
    available::Bool,
    bus::PSY.Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    storage_capacity::SimpleStorageCapacity,
    inflow::Float64,
    initial_storage::Float64;
    prime_mover_type::PSY.PrimeMovers = PSY.PrimeMovers.HY,
    active_power_limits::PSY.MinMax = PSY.MinMax(0.0, rating),
    reactive_power_limits::Union{Nothing, PSY.MinMax} = PSY.MinMax(-rating*0.3, rating*0.3),
    ramp_limits::Union{Nothing, PSY.UpDown} = PSY.UpDown(rating*0.1, rating*0.1),
    operation_cost::PSY.OperationalCost = SimpleTwoPartCost(5.0, 0.0),  # Use simple alternative
    base_power::Float64 = 100.0,
    services::Vector{PSY.Service} = PSY.Service[],
    dynamic_injector::Union{Nothing, PSY.DynamicInjection} = nothing,
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
    
    return ExtendedHydroReservoir(
        name, available, bus, active_power, reactive_power, rating,
        prime_mover_type, active_power_limits, reactive_power_limits,
        ramp_limits, operation_cost, base_power, services, dynamic_injector,
        ext, SimpleTimeSeriesContainer(),  # Use simple alternative
        SimpleInternalStructure(),         # Use simple alternative
        storage_capacity, inflow, initial_storage,
        reservoir_capacity, current_level, min_level, max_level,
        dead_storage, active_storage, head, efficiency, 0.0,
        max_flow_rate, min_flow_rate, tailwater_level,
        Float64[], Float64[], inflow_uncertainty, Float64[],
        water_value, spillage_cost, shortage_cost, 0.0,
        environmental_flow, ramping_rate, 0.0, Bool[],
        is_pumped_storage, pump_efficiency, max_pump_power, nothing, nothing,
        ExtendedHydroReservoir[], ExtendedHydroReservoir[], travel_time,
        Vector{Float64}[], Float64[], "expectation", 0.1
    )
end

# Convenience constructor that creates SimpleStorageCapacity
function ExtendedHydroReservoir(
    name::String,
    available::Bool,
    bus::PSY.Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    min_storage::Float64,
    max_storage::Float64,
    inflow::Float64,
    initial_storage::Float64;
    kwargs...
)
    storage_capacity = SimpleStorageCapacity(min_storage, max_storage)
    return ExtendedHydroReservoir(
        name, available, bus, active_power, reactive_power, rating,
        storage_capacity, inflow, initial_storage; kwargs...
    )
end

# Helper functions for the simple types
get_min_storage(sc::SimpleStorageCapacity) = sc.min
get_max_storage(sc::SimpleStorageCapacity) = sc.max
get_variable_cost(tc::SimpleTwoPartCost) = tc.variable
get_fixed_cost(tc::SimpleTwoPartCost) = tc.fixed

# Export the types and functions
export ExtendedHydroReservoir, SimpleStorageCapacity, SimpleTwoPartCost
export get_min_storage, get_max_storage, get_variable_cost, get_fixed_cost

# Core hydro functions
"""
Calculate power output based on flow rate and head
"""
function calculate_power_output(hydro::ExtendedHydroReservoir, flow_rate::Float64)
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
function calculate_required_flow(hydro::ExtendedHydroReservoir, power::Float64)
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
function update_reservoir_level!(hydro::ExtendedHydroReservoir, outflow::Float64, 
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
function calculate_water_value(hydro::ExtendedHydroReservoir, time_horizon::Int = 24)
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
function calculate_spillage(hydro::ExtendedHydroReservoir)
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
function add_upstream_plant!(hydro::ExtendedHydroReservoir, upstream::ExtendedHydroReservoir)
    if !(upstream in hydro.upstream_plants)
        push!(hydro.upstream_plants, upstream)
        push!(upstream.downstream_plants, hydro)
    end
end

"""
Calculate inflow from upstream plants
"""
function calculate_cascade_inflow(hydro::ExtendedHydroReservoir, dt::Float64)
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
function add_hydro_variables!(model::JuMP.Model, hydro::ExtendedHydroReservoir, time_periods::Int)
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
function add_hydro_constraints!(model::JuMP.Model, hydro::ExtendedHydroReservoir, 
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
    
    # Storage limits - FIX: Correct syntax for constraint arrays
    max_storage = hydro.reservoir_capacity - hydro.dead_storage
    @constraint(model, [t=1:time_periods], storage[t] <= max_storage)
    @constraint(model, [t=1:time_periods], storage[t] >= 0)
    
    # Power generation limits
    @constraint(model, [t=1:time_periods], p_hydro[t] <= hydro.rating * u_hydro[t])
    @constraint(model, [t=1:time_periods], p_hydro[t] >= 0)
    
    # Flow rate limits
    @constraint(model, [t=1:time_periods], flow[t] <= hydro.max_flow_rate * u_hydro[t])
    @constraint(model, [t=1:time_periods], flow[t] >= hydro.min_flow_rate * u_hydro[t])
    
    # Environmental flow constraint
    @constraint(model, [t=1:time_periods], flow[t] >= hydro.environmental_flow)
    
    # Power-flow relationship (simplified)
    k = 0.00981  # Conversion factor
    net_head = hydro.head - hydro.tailwater_level
    for t in 1:time_periods
        @constraint(model, p_hydro[t] <= k * flow[t] * net_head * hydro.efficiency)
    end
    
    # Ramping constraints
    if time_periods > 1
        @constraint(model, [t=2:time_periods], 
                   p_hydro[t] - p_hydro[t-1] <= hydro.ramping_rate * dt)
        @constraint(model, [t=2:time_periods], 
                   p_hydro[t-1] - p_hydro[t] <= hydro.ramping_rate * dt)
    end
    
    # Pumped storage constraints (if applicable)
    if hydro.is_pumped_storage
        p_pump = model[:p_pump]
        u_pump = model[:u_pump]
        
        @constraint(model, [t=1:time_periods], p_pump[t] <= hydro.max_pump_power * u_pump[t])
        @constraint(model, [t=1:time_periods], u_hydro[t] + u_pump[t] <= 1)  # Cannot generate and pump simultaneously
        
        # Modified water balance for pumped storage
        for t in 1:time_periods
            expected_inflow = t <= length(hydro.inflow_forecast) ? 
                             hydro.inflow_forecast[t] : hydro.inflow
            
            pump_inflow = p_pump[t] / (k * net_head * hydro.pump_efficiency)
            
            @constraint(model, storage[t+1] == storage[t] + 
                       (expected_inflow - flow[t] - spillage[t] + pump_inflow) * dt * 3600)
        end
    end
    
    return model
end

"""
Add hydro objective terms to optimization model
"""
function add_hydro_objective!(model::JuMP.Model, hydro::ExtendedHydroReservoir, time_periods::Int)
    p_hydro = model[:p_hydro]
    spillage = model[:spillage]
    u_hydro = model[:u_hydro]
    
    # Generation cost (negative because it's revenue)
    generation_cost = sum(-hydro.variable_cost * p_hydro[t] for t in 1:time_periods)
    
    # Spillage cost
    spillage_cost = sum(hydro.spillage_cost * spillage[t] for t in 1:time_periods)
    
    # Start-up costs (simplified)
    startup_cost = 0.0
    if time_periods > 1
        startup_cost = sum(hydro.start_stop_cost * max(0, u_hydro[t] - u_hydro[t-1]) 
                          for t in 2:time_periods)
    end
    
    # Water value at end of horizon
    final_storage = model[:storage][time_periods+1]
    water_value_term = -hydro.water_value * final_storage / 1000  # Convert to $/MWh equivalent
    
    total_cost = generation_cost + spillage_cost + startup_cost + water_value_term
    
    # Add to existing objective or set as objective
    if JuMP.objective_function(model) == 0
        @objective(model, Min, total_cost)
    else
        # Add to existing objective
        current_obj = JuMP.objective_function(model)
        @objective(model, Min, current_obj + total_cost)
    end
    
    return model
end

"""
Solve hydro subproblem
"""
function solve_hydro_subproblem(hydro::ExtendedHydroReservoir, time_periods::Int; 
                               solver = nothing, dt::Float64 = 1.0)
    model = JuMP.Model()
    
    # Set solver if provided
    if !isnothing(solver)
        JuMP.set_optimizer(model, solver)
    else
        # Default solver
        try
            JuMP.set_optimizer(model, Ipopt.Optimizer)
            JuMP.set_attribute(model, "print_level", 0)
        catch
            @warn "Ipopt not available, using default solver"
        end
    end
    
    # Add variables and constraints
    add_hydro_variables!(model, hydro, time_periods)
    add_hydro_constraints!(model, hydro, time_periods, dt)
    add_hydro_objective!(model, hydro, time_periods)
    
    # Solve
    JuMP.optimize!(model)
    
    # Extract results
    if JuMP.termination_status(model) == JuMP.OPTIMAL
        results = Dict(
            "status" => :optimal,
            "objective" => JuMP.objective_value(model),
            "power" => JuMP.value.(model[:p_hydro]),
            "flow" => JuMP.value.(model[:flow]),
            "storage" => JuMP.value.(model[:storage]),
            "spillage" => JuMP.value.(model[:spillage])
        )
        
        if hydro.is_pumped_storage
            results["pump_power"] = JuMP.value.(model[:p_pump])
        end
        
        return results
    else
        @warn "Hydro optimization failed with status: $(JuMP.termination_status(model))"
        return Dict("status" => :failed)
    end
end

# Export additional functions
export calculate_power_output, calculate_required_flow, update_reservoir_level!
export calculate_water_value, calculate_spillage, add_upstream_plant!
export add_hydro_variables!, add_hydro_constraints!, add_hydro_objective!
export solve_hydro_subproblem
export ExtendedHydroGenerator
export initialize_hydro_parameters!, extract_hydro_timeseries!, set_hydro_gen_data!
export update_hydro_performance!, calculate_hydro_operating_cost