# Extended Storage Generator Type
# This implements detailed battery and storage modeling

using JuMP
using PowerSystems
using TimeSeries
using Dates
using InfrastructureSystems

# Import necessary types from PowerSystems and InfrastructureSystems
const PSY = PowerSystems
const IS = InfrastructureSystems

# Import specific types that exist
import PowerSystems: MinMax, UpDown, PrimeMovers, Bus, Service, DynamicInjection
import PowerSystems: OperationalCost

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

# Export the types and functions
export ExtendedStorageSystem, SimpleStorageCapacity, SimpleStorageEnergyCapacity
export get_energy_capacity, get_current_energy, get_available_charge_capacity, get_available_discharge_capacity
export update_state_of_charge!

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
Storage power angle message passing for APP-ADMM
"""
function gpoweranglemessage(storage::ExtendedStorageSystem, voltage_angle::Float64, 
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