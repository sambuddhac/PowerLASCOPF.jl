"""
Extended Storage Generator component for PowerLASCOPF.jl

This module defines the ExtendedStorageGenerator struct that extends PowerSystems storage devices
for LASCOPF optimization with ADMM/APP state variables, storage-specific constraints,
and enhanced storage cost modeling including cycling costs and degradation.
"""
# Extended Storage Generator Type
# This implements detailed battery and storage modeling

using JuMP
using PowerSystems
# Import specific types that exist
import PowerSystems: MinMax, UpDown, PrimeMovers, Bus, Service, DynamicInjection
import PowerSystems: OperationalCost, Storage
using TimeSeries
using Dates

# Import necessary types from PowerSystems and InfrastructureSystems
const PSY = PowerSystems
const IS = InfrastructureSystems

# Include necessary modules from the codebase
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedStorageCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedStorageGenerator{T<:PSY.Storage, U<:GenIntervals}

An extended storage device component that extends PowerSystems storage devices for LASCOPF optimization.
Supports BatteryEMS, GenericBattery, and other storage technologies with storage-specific constraints
like state of charge, cycling limits, and degradation modeling.
"""
@kwdef mutable struct ExtendedStorageGenerator{T<:PSY.Storage, U<:GenIntervals} <: PowerGenerator
    # Core storage device from PowerSystems
    generator::T  # BatteryEMS, GenericBattery, etc. (treating as generator for dispatch)
    
    # Extended storage cost function with regularization
    storage_cost_function::ExtendedStorageCost{U}
    
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
    
    # Solver interface for storage devices
    gen_solver::GenSolver{ExtendedStorageCost, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output (positive = discharge, negative = charge)
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Storage-specific operating variables
    state_of_charge::Float64 = 0.5              # Current SOC (0-1)
    energy_level::Float64 = 0.0                 # Current energy level (MWh)
    charging_power::Float64 = 0.0               # Charging power (MW, positive)
    discharging_power::Float64 = 0.0            # Discharging power (MW, positive)
    charging_efficiency::Float64 = 0.95         # Charging efficiency
    discharging_efficiency::Float64 = 0.95      # Discharging efficiency
    round_trip_efficiency::Float64 = 0.90       # Overall round-trip efficiency
    
    # Storage constraints and limits
    soc_min::Float64 = 0.1                      # Minimum SOC (typically 10%)
    soc_max::Float64 = 0.9                      # Maximum SOC (typically 90%)
    charge_rate_limit::Float64 = 0.0            # Maximum charge rate (MW)
    discharge_rate_limit::Float64 = 0.0         # Maximum discharge rate (MW)
    
    # Storage degradation and lifecycle
    cycle_count::Float64 = 0.0                  # Total number of equivalent full cycles
    depth_of_discharge::Float64 = 0.0           # Current depth of discharge
    temperature::Float64 = 25.0                 # Operating temperature (°C)
    calendar_aging::Float64 = 0.0               # Calendar aging factor
    cycle_aging::Float64 = 0.0                  # Cycle aging factor
    capacity_retention::Float64 = 1.0           # Remaining capacity (fraction of original)
    
    # Economic variables
    cycling_cost::Float64 = 0.0                 # Cost per cycle ($/MWh)
    degradation_cost::Float64 = 0.0             # Degradation cost ($/MWh)
    ancillary_service_revenue::Float64 = 0.0    # Revenue from ancillary services
    arbitrage_value::Float64 = 0.0              # Energy arbitrage value
    
    # Grid services capabilities
    frequency_regulation::Bool = true           # Can provide frequency regulation
    spinning_reserve::Bool = true               # Can provide spinning reserve
    non_spinning_reserve::Bool = true           # Can provide non-spinning reserve
    voltage_support::Bool = false               # Can provide voltage support
    black_start_capability::Bool = false        # Black start capability
    
    # Storage timeseries management
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    degradation_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    service_signals::Union{TimeSeries.TimeArray, Nothing} = nothing
    thermal_constraints::Union{TimeSeries.TimeArray, Nothing} = nothing
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Capacity factor (discharge only)
    availability_factor::Float64 = 1.0          # Availability factor
    energy_throughput::Float64 = 0.0            # Cumulative energy throughput (MWh)
    revenue_total::Float64 = 0.0                # Total revenue earned
    
    # Storage-specific cache
    _storage_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedStorageGenerator(
        generator::T,
        storage_cost_function::ExtendedStorageCost{U},
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
    ) where {T<:PSY.Storage, U<:GenIntervals}
        
        # Create solver with storage cost model
        gensolver = GenSolver(
            interval_type = storage_cost_function.regularization_term,
            cost_curve = storage_cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.storage_cost_function = storage_cost_function
        # ...existing code for other assignments...
        
        # Initialize storage-specific parameters
        initialize_storage_parameters!(self)
        
        # Extract timeseries data
        #extract_storage_timeseries!(self)
        
        # Set initial storage data
        #set_storage_gen_data!(self)
        
        return self
    end
end

"""
    initialize_storage_parameters!(gen::ExtendedStorageGenerator)

Initialize storage-specific parameters from the PowerSystems storage device.
"""
function initialize_storage_parameters!(gen::ExtendedStorageGenerator{T}) where T
    psy_storage = gen.generator
    
    # Extract basic power parameters
    if hasmethod(PSY.get_output_active_power_limits, (T,))
        power_limits = PSY.get_output_active_power_limits(psy_storage)
        gen.discharge_rate_limit = power_limits.max
    end
    
    if hasmethod(PSY.get_input_active_power_limits, (T,))
        charge_limits = PSY.get_input_active_power_limits(psy_storage)
        gen.charge_rate_limit = charge_limits.max
    end
    
    # Extract energy capacity
    if hasmethod(PSY.get_storage_level_limits, (T,))
        soc_limits = PSY.get_storage_level_limits(psy_storage)
        gen.soc_min = soc_limits.min
        gen.soc_max = soc_limits.max
    end
    
    if hasmethod(PSY.get_storage_capacity, (T,))
        capacity = PSY.get_storage_capacity(psy_storage)
        gen.energy_level = capacity * gen.state_of_charge
    end
    
    # Extract efficiency parameters
    if hasmethod(PSY.get_efficiency, (T,))
        efficiency = PSY.get_efficiency(psy_storage)
        if isa(efficiency, NamedTuple)
            gen.charging_efficiency = get(efficiency, :in, 0.95)
            gen.discharging_efficiency = get(efficiency, :out, 0.95)
        else
            gen.round_trip_efficiency = efficiency
            gen.charging_efficiency = sqrt(efficiency)
            gen.discharging_efficiency = sqrt(efficiency)
        end
    end
    
    # Initialize power dispatch
    gen.Pg = 0.0  # Start with no charging or discharging
    gen.P_gen_prev = 0.0
    gen.P_gen_next = 0.0
    
    # Initialize degradation parameters
    gen.cycling_cost = 5.0    # $/MWh typical cycling cost
    gen.degradation_cost = 2.0  # $/MWh degradation cost
    gen.capacity_retention = 1.0
    
    # Initialize performance metrics
    gen.availability_factor = PSY.get_available(psy_storage) ? 1.0 : 0.0
end

"""
    extract_storage_timeseries!(gen::ExtendedStorageGenerator)

Extract storage-specific timeseries data from PowerSystems storage device.
"""
function extract_storage_timeseries!(gen::ExtendedStorageGenerator)
    psy_storage = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries
    time_series_names = PSY.get_time_series_names(psy_storage)
    
    for ts_name in time_series_names
        try
            ts_data = PSY.get_time_series(psy_storage, ts_name)
            
            # Map timeseries based on name
            if occursin("Price", string(ts_name)) || occursin("LMP", string(ts_name))
                gen.price_forecast = ts_data
            elseif occursin("Degradation", string(ts_name)) || occursin("Aging", string(ts_name))
                gen.degradation_forecast = ts_data
            elseif occursin("Service", string(ts_name)) || occursin("Regulation", string(ts_name))
                gen.service_signals = ts_data
            elseif occursin("Thermal", string(ts_name)) || occursin("Temperature", string(ts_name))
                gen.thermal_constraints = ts_data
            end
            
        catch e
            @debug "Could not extract timeseries $ts_name for storage device $(PSY.get_name(psy_storage)): $e"
        end
    end
end

"""
    update_storage_state!(gen::ExtendedStorageGenerator, power::Float64, time_step::Float64 = 1.0)

Update storage state of charge and energy level based on power dispatch.
"""
function update_storage_state!(gen::ExtendedStorageGenerator, power::Float64, time_step::Float64 = 1.0)
    gen.Pg = power
    
    # Determine charging vs discharging
    if power > 0  # Discharging
        gen.discharging_power = power
        gen.charging_power = 0.0
        
        # Decrease energy level accounting for efficiency
        energy_delivered = power * time_step
        energy_from_storage = energy_delivered / gen.discharging_efficiency
        gen.energy_level = max(0.0, gen.energy_level - energy_from_storage)
        
    elseif power < 0  # Charging
        gen.charging_power = -power
        gen.discharging_power = 0.0
        
        # Increase energy level accounting for efficiency
        energy_consumed = -power * time_step
        energy_to_storage = energy_consumed * gen.charging_efficiency
        capacity = PSY.get_storage_capacity(gen.generator)
        gen.energy_level = min(capacity, gen.energy_level + energy_to_storage)
        
    else  # Idle
        gen.charging_power = 0.0
        gen.discharging_power = 0.0
    end
    
    # Update state of charge
    capacity = PSY.get_storage_capacity(gen.generator)
    if capacity > 0
        gen.state_of_charge = gen.energy_level / capacity
    end
    
    # Update cycle counting and degradation
    update_storage_degradation!(gen, time_step)
    
    # Update performance metrics
    update_storage_performance!(gen, time_step)
end

"""
    update_storage_degradation!(gen::ExtendedStorageGenerator, time_step::Float64)

Update storage degradation based on cycling and calendar aging.
"""
function update_storage_degradation!(gen::ExtendedStorageGenerator, time_step::Float64)
    # Calendar aging (simplified linear model)
    calendar_aging_rate = 0.02 / 8760  # 2% per year
    gen.calendar_aging += calendar_aging_rate * time_step
    
    # Cycle aging based on depth of discharge
    if gen.charging_power > 0 || gen.discharging_power > 0
        # Calculate depth of discharge for this interval
        capacity = PSY.get_storage_capacity(gen.generator)
        energy_cycled = max(gen.charging_power, gen.discharging_power) * time_step
        dod_increment = energy_cycled / capacity
        
        gen.depth_of_discharge += dod_increment
        
        # Count equivalent full cycles (simplified)
        if gen.depth_of_discharge >= 1.0
            gen.cycle_count += gen.depth_of_discharge
            gen.depth_of_discharge = 0.0  # Reset
        end
        
        # Cycle aging (Arrhenius equation simplified)
        cycle_aging_rate = 0.05 / 5000  # 5% after 5000 cycles
        gen.cycle_aging += cycle_aging_rate * dod_increment
    end
    
    # Update capacity retention
    total_aging = gen.calendar_aging + gen.cycle_aging
    gen.capacity_retention = max(0.7, 1.0 - total_aging)  # Minimum 70% retention
end

"""
    update_storage_performance!(gen::ExtendedStorageGenerator, time_step::Float64)

Update storage performance metrics.
"""
function update_storage_performance!(gen::ExtendedStorageGenerator, time_step::Float64)
    # Update energy throughput
    energy_throughput_increment = max(gen.charging_power, gen.discharging_power) * time_step
    gen.energy_throughput += energy_throughput_increment
    
    # Update capacity factor (discharge only)
    if gen.discharge_rate_limit > 0
        gen.capacity_factor = gen.discharging_power / gen.discharge_rate_limit
    end
    
    # Update arbitrage value (simplified)
    if !isnothing(gen.price_forecast) && !isnothing(gen.current_time)
        try
            current_price = PSY.get_value_at_time(gen.price_forecast, gen.current_time)
            
            if gen.discharging_power > 0
                gen.arbitrage_value += current_price * gen.discharging_power * time_step
            elseif gen.charging_power > 0
                gen.arbitrage_value -= current_price * gen.charging_power * time_step
            end
        catch e
            @debug "Could not calculate arbitrage value: $e"
        end
    end
end

"""
    check_storage_constraints(gen::ExtendedStorageGenerator)::Vector{String}

Check storage-specific constraints and return violations.
"""
function check_storage_constraints(gen::ExtendedStorageGenerator)::Vector{String}
    violations = String[]
    
    # SOC constraints
    if gen.state_of_charge < gen.soc_min
        push!(violations, "SOC below minimum: $(gen.state_of_charge) < $(gen.soc_min)")
    elseif gen.state_of_charge > gen.soc_max
        push!(violations, "SOC above maximum: $(gen.state_of_charge) > $(gen.soc_max)")
    end
    
    # Power rate constraints
    if gen.charging_power > gen.charge_rate_limit
        push!(violations, "Charging power exceeds limit: $(gen.charging_power) > $(gen.charge_rate_limit)")
    end
    
    if gen.discharging_power > gen.discharge_rate_limit
        push!(violations, "Discharging power exceeds limit: $(gen.discharging_power) > $(gen.discharge_rate_limit)")
    end
    
    # Cannot charge and discharge simultaneously
    if gen.charging_power > 0 && gen.discharging_power > 0
        push!(violations, "Simultaneous charging and discharging not allowed")
    end
    
    return violations
end

"""
    calculate_storage_operating_cost(gen::ExtendedStorageGenerator, time_step::Float64 = 1.0)::Float64

Calculate total storage operating cost including cycling and degradation costs.
"""
function calculate_storage_operating_cost(gen::ExtendedStorageGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    # Base operating cost (typically very low for storage)
    if is_regularization_active(gen.storage_cost_function)
        total_cost += build_storage_cost_expression(
            gen.storage_cost_function, 
            gen.Pg, 
            gen.state_of_charge,
            time_step,
            gen.P_gen_next, 
            gen.theta_g
        )
    end
    
    # Cycling cost (wear and tear)
    energy_cycled = max(gen.charging_power, gen.discharging_power) * time_step
    total_cost += gen.cycling_cost * energy_cycled
    
    # Degradation cost
    total_cost += gen.degradation_cost * energy_cycled * (1.0 - gen.capacity_retention)
    
    # Subtract ancillary service revenue
    total_cost -= gen.ancillary_service_revenue * time_step
    
    return total_cost
end

# ...existing code for solver functions...



# Define simple alternative types for missing ones
struct SimpleStorageCapacity
    min::Float64
    max::Float64
end

struct SimpleStorageEnergyCapacity
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
Extended Storage System with detailed battery modeling
Includes:
- State of charge tracking
- Charging/discharging efficiency
- Degradation modeling
- Thermal management
- Cycling cost optimization
- Grid services participation
"""
mutable struct ExtendedStorageSystem <: PSY.Storage
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
    time_series_container::SimpleTimeSeriesContainer
    internal::SimpleInternalStructure
    
    # Basic storage parameters
    storage_capacity::SimpleStorageEnergyCapacity  # Energy capacity (MWh)
    charge_capacity::SimpleStorageCapacity         # Charging capacity (MW)
    discharge_capacity::SimpleStorageCapacity      # Discharging capacity (MW)
    initial_energy::Float64                        # Initial stored energy (MWh)
    
    # Storage-specific parameters
    state_of_charge::Float64          # Current SoC (0-1)
    state_of_charge_limits::Tuple{Float64, Float64}  # (min_soc, max_soc)
    round_trip_efficiency::Float64    # Overall round-trip efficiency
    charge_efficiency::Float64        # Charging efficiency
    discharge_efficiency::Float64     # Discharging efficiency
    self_discharge_rate::Float64      # Self-discharge rate per hour
    
    # Battery characteristics
    battery_type::String              # "Li-ion", "Lead-acid", "Flow", etc.
    chemistry::String                 # "LFP", "NMC", "NCA", etc.
    nominal_voltage::Float64          # Battery nominal voltage (V)
    cell_count::Int                   # Number of cells
    module_count::Int                 # Number of modules
    
    # Degradation modeling
    cycle_count::Int                  # Total charge/discharge cycles
    calendar_age::Float64             # Calendar age (years)
    capacity_fade::Float64            # Capacity degradation factor (0-1)
    resistance_growth::Float64        # Internal resistance growth factor
    degradation_model::String         # "linear", "sqrt", "exponential"
    
    # Thermal management
    temperature::Float64              # Current temperature (°C)
    temperature_limits::Tuple{Float64, Float64}  # (min_temp, max_temp)
    thermal_capacity::Float64         # Thermal capacity (J/K)
    heat_generation_rate::Float64     # Heat generation coefficient
    cooling_power::Float64            # Cooling system power consumption
    
    # Economic parameters
    cycling_cost::Float64             # Cost per cycle ($/cycle)
    degradation_cost::Float64         # Cost of capacity degradation ($/MWh lost)
    maintenance_cost::Float64         # O&M cost ($/MWh)
    replacement_cost::Float64         # Replacement cost ($/MWh capacity)
    residual_value::Float64           # End-of-life residual value
    
    # Grid services capabilities
    frequency_regulation::Bool        # Can provide frequency regulation
    spinning_reserve::Bool            # Can provide spinning reserves
    ramping_capability::Bool          # Can provide ramping services
    voltage_support::Bool             # Can provide voltage support
    black_start_capability::Bool      # Black start capability
    
    # Optimization parameters
    charge_power::Float64             # Current charging power (MW)
    discharge_power::Float64          # Current discharging power (MW)
    binary_charge::Bool               # Charging status (binary)
    binary_discharge::Bool            # Discharging status (binary)
    energy_schedule::Vector{Float64}  # Energy schedule for optimization
    
    # Forecasting and uncertainty
    price_forecast::Vector{Float64}   # Electricity price forecast
    load_forecast::Vector{Float64}    # Load forecast for sizing
    renewable_forecast::Vector{Float64}  # Renewable generation forecast
    uncertainty_factor::Float64       # Forecast uncertainty factor
    
    # Advanced features
    is_aggregated::Bool               # Whether this represents aggregated storage
    individual_units::Vector{ExtendedStorageSystem}  # Individual units if aggregated
    control_strategy::String          # "price_arbitrage", "peak_shaving", "backup"
    participation_factor::Float64     # Participation in grid services (0-1)
end

# Constructor with default values
function ExtendedStorageSystem(
    name::String,
    available::Bool,
    bus::PSY.Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    storage_capacity::SimpleStorageEnergyCapacity,
    initial_energy::Float64;
    prime_mover_type::PSY.PrimeMovers = PSY.PrimeMovers.BA,  # Battery
    active_power_limits::PSY.MinMax = PSY.MinMax(-rating, rating),
    reactive_power_limits::Union{Nothing, PSY.MinMax} = PSY.MinMax(-rating*0.3, rating*0.3),
    ramp_limits::Union{Nothing, PSY.UpDown} = PSY.UpDown(rating, rating),
    operation_cost::PSY.OperationalCost = SimpleTwoPartCost(10.0, 0.0),
    base_power::Float64 = 100.0,
    services::Vector{PSY.Service} = PSY.Service[],
    dynamic_injector::Union{Nothing, PSY.DynamicInjection} = nothing,
    ext::Dict{String, Any} = Dict{String, Any}(),
    charge_capacity::SimpleStorageCapacity = SimpleStorageCapacity(0.0, rating),
    discharge_capacity::SimpleStorageCapacity = SimpleStorageCapacity(0.0, rating),
    round_trip_efficiency::Float64 = 0.85,
    charge_efficiency::Float64 = 0.95,
    discharge_efficiency::Float64 = 0.95,
    self_discharge_rate::Float64 = 0.001,
    battery_type::String = "Li-ion",
    chemistry::String = "LFP",
    state_of_charge_limits::Tuple{Float64, Float64} = (0.1, 0.9),
    cycling_cost::Float64 = 0.01,
    control_strategy::String = "price_arbitrage"
)
    
    # Calculate initial state of charge
    max_energy = storage_capacity.max
    initial_soc = max_energy > 0 ? initial_energy / max_energy : 0.0
    
    return ExtendedStorageSystem(
        name, available, bus, active_power, reactive_power, rating,
        prime_mover_type, active_power_limits, reactive_power_limits,
        ramp_limits, operation_cost, base_power, services, dynamic_injector,
        ext, SimpleTimeSeriesContainer(), SimpleInternalStructure(),
        storage_capacity, charge_capacity, discharge_capacity, initial_energy,
        initial_soc, state_of_charge_limits, round_trip_efficiency,
        charge_efficiency, discharge_efficiency, self_discharge_rate,
        battery_type, chemistry, 3.7 * 1000, 1000, 10,  # voltage, cells, modules
        0, 0.0, 1.0, 1.0, "linear",  # degradation parameters
        25.0, (-10.0, 60.0), 1000.0, 0.05, 0.0,  # thermal parameters
        cycling_cost, 50.0, 5.0, 200.0, 20.0,  # economic parameters
        true, true, true, false, false,  # grid services
        0.0, 0.0, false, false, Float64[],  # optimization variables
        Float64[], Float64[], Float64[], 0.1,  # forecasting
        false, ExtendedStorageSystem[], control_strategy, 1.0  # advanced features
    )
end

# Convenience constructor
function ExtendedStorageSystem(
    name::String,
    available::Bool,
    bus::PSY.Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    energy_capacity::Float64,  # MWh
    initial_energy::Float64;
    kwargs...
)
    storage_cap = SimpleStorageEnergyCapacity(0.0, energy_capacity)
    return ExtendedStorageSystem(
        name, available, bus, active_power, reactive_power, rating,
        storage_cap, initial_energy; kwargs...
    )
end

# Helper functions
get_energy_capacity(storage::ExtendedStorageSystem) = storage.storage_capacity.max
get_current_energy(storage::ExtendedStorageSystem) = storage.state_of_charge * get_energy_capacity(storage)
get_available_charge_capacity(storage::ExtendedStorageSystem) = (storage.state_of_charge_limits[2] - storage.state_of_charge) * get_energy_capacity(storage)
get_available_discharge_capacity(storage::ExtendedStorageSystem) = (storage.state_of_charge - storage.state_of_charge_limits[1]) * get_energy_capacity(storage)

function update_state_of_charge!(storage::ExtendedStorageSystem, energy_change::Float64, dt::Float64 = 1.0)
    # Include self-discharge
    self_discharge = storage.self_discharge_rate * dt * get_energy_capacity(storage)
    
    # Update energy
    new_energy = get_current_energy(storage) + energy_change - self_discharge
    
    # Update SoC with limits
    max_energy = get_energy_capacity(storage)
    storage.state_of_charge = max(storage.state_of_charge_limits[1], 
                                 min(storage.state_of_charge_limits[2], 
                                     new_energy / max_energy))
    
    return storage.state_of_charge
end


# Storage-specific functions
"""
Calculate effective capacity considering degradation
"""
function get_effective_capacity(storage::ExtendedStorageSystem)
    degradation = storage.cycles_completed * storage.degradation_factor
    temp_effect = (storage.ambient_temperature - 25.0) * storage.temperature_coeff / 100.0
    return storage.energy_capacity * (1.0 - degradation) * (1.0 + temp_effect)
end

"""
Calculate available charging power
"""
function get_available_charge_power(storage::ExtendedStorageSystem)
    available_capacity = get_effective_capacity(storage) * (storage.max_soc - storage.state_of_charge)
    max_power = min(storage.max_charge_rate, available_capacity)
    return max(0.0, max_power)
end

"""
Calculate available discharging power
"""
function get_available_discharge_power(storage::ExtendedStorageSystem)
    available_energy = get_effective_capacity(storage) * (storage.state_of_charge - storage.min_soc)
    max_power = min(storage.max_discharge_rate, available_energy)
    return max(0.0, max_power)
end

"""
Update state of charge based on power dispatch
"""
function update_soc!(storage::ExtendedStorageSystem, power::Float64, dt::Float64)
    if power > 0  # Discharging
        energy_out = power * dt
        soc_change = -energy_out / (get_effective_capacity(storage) * storage.discharge_efficiency)
    else  # Charging
        energy_in = -power * dt
        soc_change = energy_in * storage.charge_efficiency / get_effective_capacity(storage)
    end
    
    # Apply self-discharge
    self_discharge = storage.self_discharge_rate * dt
    storage.state_of_charge = max(storage.min_soc, 
                                 min(storage.max_soc, 
                                     storage.state_of_charge + soc_change - self_discharge))
    
    # Update cycle count (simplified - each full charge/discharge counts as 0.5 cycle)
    if abs(soc_change) > 0.01
        storage.cycles_completed += abs(soc_change) * 0.5
    end
end

"""
Storage operational cost considering degradation
"""
function get_storage_cost(storage::ExtendedStorageSystem, power::Float64)
    base_cost = get_variable_cost(get_operation_cost(storage))
    
    # Add degradation cost for cycling
    if abs(power) > 0.01
        degradation_cost = abs(power) * storage.degradation_factor * 
                          storage.energy_capacity * 0.1  # $/MWh degradation cost
        return base_cost + degradation_cost
    end
    
    return base_cost
end

"""
Reserve capability based on current SOC and limits
"""
function get_reserve_capability(storage::ExtendedStorageSystem)
    charge_reserve = min(storage.reserve_up_capability, get_available_charge_power(storage))
    discharge_reserve = min(storage.reserve_down_capability, get_available_discharge_power(storage))
    return (up = charge_reserve, down = discharge_reserve)
end

# Optimization model functions for storage
"""
Add storage variables to optimization model
"""
function add_storage_variables!(model::JuMP.Model, storage::ExtendedStorageSystem, time_periods::Int)
    # Power variables (positive = discharge, negative = charge)
    @variable(model, p_storage[1:time_periods])
    
    # State of charge variables
    @variable(model, soc[1:time_periods+1])
    
    # Binary variables for charge/discharge
    @variable(model, u_charge[1:time_periods], Bin)
    @variable(model, u_discharge[1:time_periods], Bin)
    
    # Reserve variables
    @variable(model, r_up[1:time_periods] >= 0)
    @variable(model, r_down[1:time_periods] >= 0)
    
    return model
end

"""
Add storage constraints to optimization model
"""
function add_storage_constraints!(model::JuMP.Model, storage::ExtendedStorageSystem, 
                                time_periods::Int, dt::Float64 = 1.0)
    p_storage = model[:p_storage]
    soc = model[:soc]
    u_charge = model[:u_charge]
    u_discharge = model[:u_discharge]
    r_up = model[:r_up]
    r_down = model[:r_down]
    
    effective_capacity = get_effective_capacity(storage)
    
    # Initial SOC
    @constraint(model, soc[1] == storage.state_of_charge)
    
    # SOC dynamics
    for t in 1:time_periods
        @constraint(model, soc[t+1] == soc[t] - 
                   (p_storage[t] * dt / effective_capacity) * 
                   (p_storage[t] >= 0 ? 1/storage.discharge_efficiency : storage.charge_efficiency) -
                   storage.self_discharge_rate * dt)
    end
    
    # SOC limits
    @constraint(model, [t=1:time_periods+1], storage.min_soc <= soc[t] <= storage.max_soc)
    
    # Power limits with binary variables
    M = max(storage.max_charge_rate, storage.max_discharge_rate)
    @constraint(model, [t=1:time_periods], p_storage[t] <= storage.max_discharge_rate * u_discharge[t])
    @constraint(model, [t=1:time_periods], p_storage[t] >= -storage.max_charge_rate * u_charge[t])
    @constraint(model, [t=1:time_periods], u_charge[t] + u_discharge[t] <= 1)
    
    # Reserve constraints
    @constraint(model, [t=1:time_periods], r_up[t] <= storage.reserve_up_capability)
    @constraint(model, [t=1:time_periods], r_down[t] <= storage.reserve_down_capability)
    @constraint(model, [t=1:time_periods], r_up[t] <= get_available_charge_power(storage))
    @constraint(model, [t=1:time_periods], r_down[t] <= get_available_discharge_power(storage))
    
    return model
end

"""
Add storage objective terms
"""
function add_storage_objective!(model::JuMP.Model, storage::ExtendedStorageSystem, time_periods::Int)
    p_storage = model[:p_storage]
    
    # Variable cost including degradation
    storage_cost = sum(get_storage_cost(storage, p_storage[t]) * abs(p_storage[t]) 
                      for t in 1:time_periods)
    
    # Add to existing objective or create new one
    if objective_function(model) != AffExpr(0.0)
        @objective(model, Min, objective_function(model) + storage_cost)
    else
        @objective(model, Min, storage_cost)
    end
    
    return model
end

# APP-ADMM specific functions for storage
"""
    storage_admm_dispatch_update!(storage::ExtendedStorageSystem, voltage_angle::Float64,
                                  lambda::Float64, rho::Float64)

Storage ADMM dispatch update for the per-device consensus step. Computes the optimal
dispatch power for `storage` given the dual variable `lambda` and penalty `rho` at the
supplied `voltage_angle`.

Note: this function is distinct from `gpower_angle_message!` (the full APP subproblem
defined on `GeneralizedGenerator`), which orchestrates the complete multi-parameter
ADMM state update and routes through `build_and_solve_gensolver_for_gen!`.
"""
function storage_admm_dispatch_update!(storage::ExtendedStorageSystem, voltage_angle::Float64,
                           lambda::Float64, rho::Float64)
    # For storage, the power angle relationship is simpler than for thermal generators
    # Storage can provide instantaneous response based on SOC and limits

    available_up = get_available_discharge_power(storage)
    available_down = get_available_charge_power(storage)

    # Calculate optimal power based on price signal and constraints
    base_power = (lambda - get_variable_cost(get_operation_cost(storage))) / rho

    # Clip to available capacity
    optimal_power = max(-available_down, min(available_up, base_power))

    # Storage doesn't have significant angle dependency, so return current angle
    return (power = optimal_power, angle = voltage_angle)
end

"""
Update storage dual variables in APP-ADMM
"""
function update_storage_duals!(storage::ExtendedStorageSystem, power_mismatch::Float64, 
                              rho::Float64, lambda::Vector{Float64}, t::Int)
    # Update lambda based on power balance violation
    lambda[t] += rho * power_mismatch
    return lambda
end

"""
Storage consensus step in APP-ADMM
"""
function storage_consensus_step!(storage::ExtendedStorageSystem, 
                                neighbor_powers::Vector{Float64}, 
                                rho::Float64, time_periods::Int)
    # For storage, consensus involves coordinating with grid constraints
    # and maintaining energy balance across time periods
    
    consensus_power = zeros(time_periods)
    
    for t in 1:time_periods
        # Average with neighbors weighted by storage capability
        weight = get_effective_capacity(storage) / 100.0  # Normalize by 100 MWh
        consensus_power[t] = (neighbor_powers[t] + weight * storage.active_power) / (1 + weight)
        
        # Ensure feasibility
        max_discharge = get_available_discharge_power(storage)
        max_charge = get_available_charge_power(storage)
        consensus_power[t] = max(-max_charge, min(max_discharge, consensus_power[t]))
    end
    
    return consensus_power
end

# Utility functions
function get_storage_status(storage::ExtendedStorageSystem)
    return Dict(
        "name" => storage.name,
        "soc" => storage.state_of_charge,
        "effective_capacity" => get_effective_capacity(storage),
        "available_charge" => get_available_charge_power(storage),
        "available_discharge" => get_available_discharge_power(storage),
        "cycles_completed" => storage.cycles_completed,
        "temperature" => storage.ambient_temperature
    )
end

function print_storage_summary(storage::ExtendedStorageSystem)
    status = get_storage_status(storage)
    println("=== Extended Storage Generator: $(status["name"]) ===")
    println("State of Charge: $(round(status["soc"]*100, digits=1))%")
    println("Effective Capacity: $(round(status["effective_capacity"], digits=2)) MWh")
    println("Available Charge: $(round(status["available_charge"], digits=2)) MW")
    println("Available Discharge: $(round(status["available_discharge"], digits=2)) MW")
    println("Cycles Completed: $(round(status["cycles_completed"], digits=1))")
    println("Operating Temperature: $(status["temperature"])°C")
    println("=" ^ 50)
end

# Extended Storage Generator for PowerLASCOPF with Sienna integration
mutable struct ExtendedStorage{T<:PSY.Storage} <: PSY.Storage
    # Core storage properties
    storage_type::T
    gen_id::Int
    
    # Power and energy properties
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PSY.PrimeMovers  # Fix: Add PSY prefix
    active_power_limits::PSY.MinMax
    reactive_power_limits::Union{Nothing, PSY.MinMax}
    ramp_limits::Union{Nothing, PSY.UpDown}
    operation_cost::Union{Nothing, PSY.OperationalCost}
    
    # Storage-specific properties
    state_of_charge_limits::PSY.MinMax
    initial_energy::Float64
    efficiency::NamedTuple{(:charge, :discharge), Tuple{Float64, Float64}}
    
    # PowerLASCOPF specific properties
    node_connection::Int
    zone_id::Int
    scenario_count::Int
    
    # Economic and operational variables
    marginal_cost_charge::Float64
    marginal_cost_discharge::Float64
    startup_cost::Float64
    shutdown_cost::Float64
    
    # Storage operational variables
    state_of_charge::Float64
    energy_capacity::Float64
    charge_power::Float64
    discharge_power::Float64
    charging_efficiency::Float64
    discharging_efficiency::Float64
    self_discharge_rate::Float64
    
    # Cycling and degradation
    cycle_count::Int
    degradation_factor::Float64
    calendar_aging_factor::Float64
    cycle_life::Int
    depth_of_discharge_limit::Float64
    
    # LASCOPF specific variables
    lambda_avg::Float64
    power_output::Float64  # Net power (discharge - charge)
    commitment_status::Bool
    reserve_provision::Float64
    
    # Scenario-based variables
    power_scenarios::Vector{Float64}
    cost_scenarios::Vector{Float64}
    soc_scenarios::Vector{Float64}
    energy_scenarios::Vector{Float64}
    
    # Operational modes and capabilities
    operating_mode::Symbol  # :charge, :discharge, :idle, :regulation
    frequency_regulation::Bool
    spinning_reserve::Bool
    load_following::Bool
    peak_shaving::Bool
    
    # Grid services
    voltage_support::Bool
    black_start_capability::Bool
    grid_forming_capability::Bool
    reactive_power_support::Bool
    
    # Economic optimization
    energy_arbitrage::Bool
    ancillary_service_participation::Bool
    demand_response_participation::Bool
    
    # Performance tracking
    total_energy_charged::Float64
    total_energy_discharged::Float64
    round_trip_efficiency::Float64
    utilization_rate::Float64
    
    # Maintenance and reliability
    forced_outage_rate::Float64
    maintenance_schedule::Vector{Int}
    reliability_factor::Float64
    
    # Thermal management
    temperature::Float64
    thermal_limits::PSY.MinMax
    cooling_efficiency::Float64
    
    # Inner constructor
    function ExtendedStorage{T}(
        storage_type::T,
        gen_id::Int,
        node_connection::Int,
        zone_id::Int,
        scenario_count::Int
    ) where T <: PSY.Storage  # Fix: Add PSY prefix
        
        # Get basic properties with fallbacks for missing functions
        active_power = try
            PSY.get_active_power(storage_type)
        catch
            0.0  # Default fallback
        end
        
        reactive_power = try
            PSY.get_reactive_power(storage_type)
        catch
            0.0  # Default fallback
        end
        
        rating = try
            PSY.get_rating(storage_type)
        catch
            100.0  # Default fallback
        end
        
        prime_mover = try
            PSY.get_prime_mover_type(storage_type)
        catch
            PSY.PrimeMovers.BA  # Battery default
        end
        
        active_limits = try
            PSY.get_active_power_limits(storage_type)
        catch
            PSY.MinMax(-rating, rating)  # Default symmetric limits
        end
        
        reactive_limits = try
            PSY.get_reactive_power_limits(storage_type)
        catch
            PSY.MinMax(-rating*0.3, rating*0.3)  # Default reactive limits
        end
        
        ramp_limits = try
            PSY.get_ramp_limits(storage_type)
        catch
            PSY.UpDown(rating, rating)  # Default ramp limits
        end
        
        op_cost = try
            PSY.get_operation_cost(storage_type)
        catch
            nothing  # No operation cost
        end
        
        # Storage-specific properties with fallbacks (PSY v4.6 getter names)
        soc_limits = try
            PSY.get_storage_level_limits(storage_type)
        catch
            (min = 0.0, max = 1.0)  # Default full range as fractions
        end

        initial_energy = try
            PSY.get_initial_storage_capacity_level(storage_type)
        catch
            0.5  # Default 50% SOC
        end
        
        efficiency = try
            # Try different possible function names for efficiency
            if hasmethod(PSY.get_efficiency, (typeof(storage_type),))
                PSY.get_efficiency(storage_type)
            else
                (charge = 0.9, discharge = 0.9)  # Default 90% efficiency
            end
        catch
            (charge = 0.9, discharge = 0.9)  # Default fallback
        end
        
        return new{T}(
            storage_type,
            gen_id,
            active_power,
            reactive_power,
            rating,
            prime_mover,
            active_limits,
            reactive_limits,
            ramp_limits,
            op_cost,
            soc_limits,
            initial_energy,
            efficiency,
            node_connection,
            zone_id,
            scenario_count,
            0.0,  # marginal_cost_charge
            0.0,  # marginal_cost_discharge
            0.0,  # startup_cost
            0.0,  # shutdown_cost
            initial_energy,  # state_of_charge
            soc_limits.max,  # energy_capacity
            0.0,  # charge_power
            0.0,  # discharge_power
            efficiency.charge,  # charging_efficiency
            efficiency.discharge,  # discharging_efficiency
            0.001,  # self_discharge_rate (0.1% per hour)
            0,    # cycle_count
            1.0,  # degradation_factor
            1.0,  # calendar_aging_factor
            5000, # cycle_life
            0.8,  # depth_of_discharge_limit
            0.0,  # lambda_avg
            0.0,  # power_output
            true, # commitment_status
            0.0,  # reserve_provision
            zeros(scenario_count),  # power_scenarios
            zeros(scenario_count),  # cost_scenarios
            fill(0.5, scenario_count),  # soc_scenarios (50% initial SOC)
            zeros(scenario_count),  # energy_scenarios
            :idle,  # operating_mode
            false,  # frequency_regulation
            false,  # spinning_reserve
            false,  # load_following
            false,  # peak_shaving
            false,  # voltage_support
            false,  # black_start_capability
            false,  # grid_forming_capability
            false,  # reactive_power_support
            true,   # energy_arbitrage
            false,  # ancillary_service_participation
            false,  # demand_response_participation
            0.0,  # total_energy_charged
            0.0,  # total_energy_discharged
            0.85, # round_trip_efficiency
            0.0,  # utilization_rate
            0.01, # forced_outage_rate (1%)
            Int[], # maintenance_schedule
            0.99,  # reliability_factor
            25.0,  # temperature (°C)
            PSY.MinMax(0.0, 50.0),  # thermal_limits
            0.95   # cooling_efficiency
        )
    end
end

# Outer constructor
function ExtendedStorage(
    storage_type::T,
    gen_id::Int,
    node_connection::Int,
    zone_id::Int,
    scenario_count::Int
) where T <: PSY.Storage  # Fix: Add PSY prefix
    return ExtendedStorage{T}(storage_type, gen_id, node_connection, zone_id, scenario_count)
end

# Extend PowerSystems.Storage interface - Fix: Use safe function calls
PSY.get_name(gen::ExtendedStorage) = PSY.get_name(gen.storage_type)
PSY.get_available(gen::ExtendedStorage) = PSY.get_available(gen.storage_type)
PSY.get_bus(gen::ExtendedStorage) = PSY.get_bus(gen.storage_type)
PSY.get_active_power(gen::ExtendedStorage) = gen.active_power
PSY.get_reactive_power(gen::ExtendedStorage) = gen.reactive_power
PSY.get_rating(gen::ExtendedStorage) = gen.rating
PSY.get_prime_mover_type(gen::ExtendedStorage) = gen.prime_mover_type
PSY.get_active_power_limits(gen::ExtendedStorage) = gen.active_power_limits
PSY.get_reactive_power_limits(gen::ExtendedStorage) = gen.reactive_power_limits
PSY.get_ramp_limits(gen::ExtendedStorage) = gen.ramp_limits
PSY.get_operation_cost(gen::ExtendedStorage) = gen.operation_cost

# Storage-specific getters with safe fallbacks
function get_storage_level_limits(gen::ExtendedStorage)
    return gen.state_of_charge_limits
end

function get_initial_energy(gen::ExtendedStorage)
    return gen.initial_energy
end

function get_efficiency(gen::ExtendedStorage)
    return gen.efficiency
end

# Alternative function names for compatibility
PSY.get_storage_level_limits(gen::ExtendedStorage) = get_storage_level_limits(gen)

# Extend InfrastructureSystems.Component interface - Fix: Remove non-existent functions
IS.get_uuid(gen::ExtendedStorage) = IS.get_uuid(gen.storage_type)
IS.get_ext(gen::ExtendedStorage) = IS.get_ext(gen.storage_type)
# REMOVED: IS.get_time_series_container - doesn't exist in your IS version

# Core getter/setter functions
get_gen_id(gen::ExtendedStorage) = gen.gen_id
get_node_connection(gen::ExtendedStorage) = gen.node_connection
get_zone_id(gen::ExtendedStorage) = gen.zone_id
get_scenario_count(gen::ExtendedStorage) = gen.scenario_count

# Economic functions
get_marginal_cost_charge(gen::ExtendedStorage) = gen.marginal_cost_charge
set_marginal_cost_charge!(gen::ExtendedStorage, cost::Float64) = (gen.marginal_cost_charge = cost)

get_marginal_cost_discharge(gen::ExtendedStorage) = gen.marginal_cost_discharge
set_marginal_cost_discharge!(gen::ExtendedStorage, cost::Float64) = (gen.marginal_cost_discharge = cost)

# Storage state functions
get_state_of_charge(gen::ExtendedStorage) = gen.state_of_charge
function set_state_of_charge!(gen::ExtendedStorage, soc::Float64)
    gen.state_of_charge = clamp(soc, gen.state_of_charge_limits.min, gen.state_of_charge_limits.max)
    return nothing
end

get_energy_capacity(gen::ExtendedStorage) = gen.energy_capacity
get_available_energy(gen::ExtendedStorage) = gen.state_of_charge
get_remaining_capacity(gen::ExtendedStorage) = gen.energy_capacity - gen.state_of_charge

# Power functions
get_charge_power(gen::ExtendedStorage) = gen.charge_power
function set_charge_power!(gen::ExtendedStorage, power::Float64)
    max_charge = gen.active_power_limits.max
    gen.charge_power = clamp(power, 0.0, max_charge)
    gen.operating_mode = power > 0.0 ? :charge : gen.operating_mode
    return nothing
end

get_discharge_power(gen::ExtendedStorage) = gen.discharge_power
function set_discharge_power!(gen::ExtendedStorage, power::Float64)
    max_discharge = gen.active_power_limits.max
    available_energy = gen.state_of_charge
    max_power_from_energy = available_energy * gen.discharging_efficiency  # Fix: Simplified calculation
    gen.discharge_power = clamp(power, 0.0, min(max_discharge, max_power_from_energy))
    gen.operating_mode = power > 0.0 ? :discharge : gen.operating_mode
    return nothing
end

# Operating mode functions
get_operating_mode(gen::ExtendedStorage) = gen.operating_mode
function set_operating_mode!(gen::ExtendedStorage, mode::Symbol)
    valid_modes = [:charge, :discharge, :idle, :regulation]
    if mode in valid_modes
        gen.operating_mode = mode
    else
        @warn "Invalid operating mode: $mode. Valid modes are: $valid_modes"
    end
    return nothing
end

# Grid services functions
get_frequency_regulation(gen::ExtendedStorage) = gen.frequency_regulation
set_frequency_regulation!(gen::ExtendedStorage, status::Bool) = (gen.frequency_regulation = status)

get_spinning_reserve(gen::ExtendedStorage) = gen.spinning_reserve
set_spinning_reserve!(gen::ExtendedStorage, status::Bool) = (gen.spinning_reserve = status)

get_energy_arbitrage(gen::ExtendedStorage) = gen.energy_arbitrage
set_energy_arbitrage!(gen::ExtendedStorage, status::Bool) = (gen.energy_arbitrage = status)

# Performance tracking functions
get_round_trip_efficiency(gen::ExtendedStorage) = gen.round_trip_efficiency
function calculate_round_trip_efficiency!(gen::ExtendedStorage)
    if gen.total_energy_charged > 0
        gen.round_trip_efficiency = gen.total_energy_discharged / gen.total_energy_charged
    end
    return gen.round_trip_efficiency
end

get_utilization_rate(gen::ExtendedStorage) = gen.utilization_rate
function calculate_utilization_rate!(gen::ExtendedStorage, time_period::Float64 = 8760.0)
    total_possible_energy = gen.energy_capacity * time_period
    if total_possible_energy > 0
        gen.utilization_rate = (gen.total_energy_charged + gen.total_energy_discharged) / total_possible_energy
    end
    return gen.utilization_rate
end

# Degradation functions
get_cycle_count(gen::ExtendedStorage) = gen.cycle_count
function increment_cycle_count!(gen::ExtendedStorage)
    gen.cycle_count += 1
    # Simple degradation model
    if gen.cycle_count <= gen.cycle_life
        gen.degradation_factor = 1.0 - (gen.cycle_count / gen.cycle_life) * 0.2  # 20% degradation over life
    end
    return gen.cycle_count
end

get_degradation_factor(gen::ExtendedStorage) = gen.degradation_factor

# Thermal management functions
get_temperature(gen::ExtendedStorage) = gen.temperature
function set_temperature!(gen::ExtendedStorage, temp::Float64)
    gen.temperature = clamp(temp, gen.thermal_limits.min, gen.thermal_limits.max)
    return nothing
end

"""
    solve_storage_generator_subproblem!(gen::ExtendedStorageGenerator; optimizer_factory, solve_options, time_horizon, include_unit_commitment)

Sys-less overload for the APP distributed algorithm. Updates the solver interval state
from the generator's current operating point, then calls `build_and_solve_gensolver_for_gen!`
with `gen.generator` directly.
"""
function solve_storage_generator_subproblem!(gen::ExtendedStorageGenerator;
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

    storage_solve_options = merge(solve_options, Dict(
        "include_charge_discharge_constraints" => true,
        "include_soc_constraints"              => true
    ))

    results = build_and_solve_gensolver_for_gen!(
        gen.gen_solver, gen.generator;
        optimizer_factory=optimizer_factory,
        solve_options=storage_solve_options,
        time_horizon=time_horizon
    )

    update_storage_performance!(gen, 1.0)

    return results
end

"""
    solve_storage_generator_subproblem!(gen_solver, device; optimizer_factory, solve_options, time_horizon, include_unit_commitment)

Dispatch point for `GeneralizedGenerator` calls arriving from the APP solver. Accepts the
`GenSolver` and raw `PSY.Storage` device exposed by `GeneralizedGenerator` and routes
through `build_and_solve_gensolver_for_gen!`.
"""
function solve_storage_generator_subproblem!(gen_solver::GenSolver,
                                              device::PSY.Storage;
                                              optimizer_factory=nothing,
                                              solve_options=Dict(),
                                              time_horizon=24,
                                              include_unit_commitment=false)
    storage_solve_options = merge(solve_options, Dict(
        "include_charge_discharge_constraints" => true,
        "include_soc_constraints"              => true
    ))
    return build_and_solve_gensolver_for_gen!(gen_solver, device;
                                              optimizer_factory=optimizer_factory,
                                              solve_options=storage_solve_options,
                                              time_horizon=time_horizon)
end

# Export all functions
export ExtendedStorage
export get_gen_id, get_node_connection, get_zone_id, get_scenario_count
export get_marginal_cost_charge, set_marginal_cost_charge!
export get_marginal_cost_discharge, set_marginal_cost_discharge!
export get_state_of_charge, set_state_of_charge!
export get_energy_capacity, get_available_energy, get_remaining_capacity
export get_charge_power, set_charge_power!, get_discharge_power, set_discharge_power!
export get_operating_mode, set_operating_mode!
export get_frequency_regulation, set_frequency_regulation!
export get_spinning_reserve, set_spinning_reserve!
export get_energy_arbitrage, set_energy_arbitrage!
export get_round_trip_efficiency, calculate_round_trip_efficiency!
export get_utilization_rate, calculate_utilization_rate!
export get_cycle_count, increment_cycle_count!, get_degradation_factor
export get_temperature, set_temperature!
export get_storage_level_limits, get_initial_energy, get_efficiency
export ExtendedStorageGenerator
export initialize_storage_parameters!, extract_storage_timeseries!
export update_storage_state!, update_storage_degradation!, update_storage_performance!
export check_storage_constraints, calculate_storage_operating_cost
export ExtendedStorageSystem, SimpleStorageCapacity, SimpleStorageEnergyCapacity
export get_energy_capacity, get_current_energy, get_available_charge_capacity, get_available_discharge_capacity
export update_state_of_charge!
