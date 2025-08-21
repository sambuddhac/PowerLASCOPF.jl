# Extended Storage Generator Type
# This implements energy storage systems with detailed battery modeling capabilities

using JuMP
using PowerSystems
using TimeSeries

"""
Extended Storage Generator with advanced battery modeling
Includes:
- State of charge tracking
- Charging/discharging efficiency
- Cycle degradation
- Temperature effects
- Maximum charge/discharge rates
"""
mutable struct ExtendedStorageGenerator <: Generator
    name::String
    available::Bool
    bus::Bus
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PrimeMovers
    fuel::ThermalFuels
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
    
    # Extended storage-specific parameters
    energy_capacity::Float64  # Total energy capacity (MWh)
    state_of_charge::Float64  # Current SOC (0-1)
    min_soc::Float64         # Minimum allowable SOC
    max_soc::Float64         # Maximum allowable SOC
    charge_efficiency::Float64    # Charging efficiency (0-1)
    discharge_efficiency::Float64 # Discharging efficiency (0-1)
    self_discharge_rate::Float64  # Self-discharge per hour (0-1)
    max_charge_rate::Float64     # Maximum charging rate (MW)
    max_discharge_rate::Float64  # Maximum discharging rate (MW)
    cycle_life::Int              # Expected number of cycles
    cycles_completed::Float64    # Current cycle count
    degradation_factor::Float64  # Capacity degradation per cycle
    temperature_coeff::Float64   # Temperature coefficient (%/°C)
    ambient_temperature::Float64 # Operating temperature (°C)
    reserve_up_capability::Float64    # Upward reserve capability (MW)
    reserve_down_capability::Float64  # Downward reserve capability (MW)
end

# Constructor with default values
function ExtendedStorageGenerator(
    name::String,
    available::Bool,
    bus::Bus,
    active_power::Float64,
    reactive_power::Float64,
    rating::Float64,
    energy_capacity::Float64;
    prime_mover_type::PrimeMovers = PrimeMovers.BA,
    fuel::ThermalFuels = ThermalFuels.OTHER,
    active_power_limits::MinMax = MinMax(-rating, rating),
    reactive_power_limits::Union{Nothing, MinMax} = MinMax(-rating*0.3, rating*0.3),
    ramp_limits::Union{Nothing, UpDown} = UpDown(rating*0.5, rating*0.5),
    operation_cost::OperationalCost = TwoPartCost(0.0, 0.0),
    base_power::Float64 = 100.0,
    services::Vector{Service} = Service[],
    dynamic_injector::Union{Nothing, DynamicInjection} = nothing,
    ext::Dict{String, Any} = Dict{String, Any}(),
    state_of_charge::Float64 = 0.5,
    min_soc::Float64 = 0.1,
    max_soc::Float64 = 0.9,
    charge_efficiency::Float64 = 0.95,
    discharge_efficiency::Float64 = 0.95,
    self_discharge_rate::Float64 = 0.001,
    max_charge_rate::Float64 = rating,
    max_discharge_rate::Float64 = rating,
    cycle_life::Int = 5000,
    cycles_completed::Float64 = 0.0,
    degradation_factor::Float64 = 0.0002,
    temperature_coeff::Float64 = -0.5,
    ambient_temperature::Float64 = 25.0,
    reserve_up_capability::Float64 = 0.0,
    reserve_down_capability::Float64 = 0.0
)
    return ExtendedStorageGenerator(
        name, available, bus, active_power, reactive_power, rating,
        prime_mover_type, fuel, active_power_limits, reactive_power_limits,
        ramp_limits, operation_cost, base_power, services, dynamic_injector,
        ext, InfrastructureSystemsInternal.TimeSeriesContainer(),
        InfrastructureSystemsInternal.InfrastructureSystemsInternal(),
        energy_capacity, state_of_charge, min_soc, max_soc,
        charge_efficiency, discharge_efficiency, self_discharge_rate,
        max_charge_rate, max_discharge_rate, cycle_life, cycles_completed,
        degradation_factor, temperature_coeff, ambient_temperature,
        reserve_up_capability, reserve_down_capability
    )
end

# Storage-specific functions
"""
Calculate effective capacity considering degradation
"""
function get_effective_capacity(storage::ExtendedStorageGenerator)
    degradation = storage.cycles_completed * storage.degradation_factor
    temp_effect = (storage.ambient_temperature - 25.0) * storage.temperature_coeff / 100.0
    return storage.energy_capacity * (1.0 - degradation) * (1.0 + temp_effect)
end

"""
Calculate available charging power
"""
function get_available_charge_power(storage::ExtendedStorageGenerator)
    available_capacity = get_effective_capacity(storage) * (storage.max_soc - storage.state_of_charge)
    max_power = min(storage.max_charge_rate, available_capacity)
    return max(0.0, max_power)
end

"""
Calculate available discharging power
"""
function get_available_discharge_power(storage::ExtendedStorageGenerator)
    available_energy = get_effective_capacity(storage) * (storage.state_of_charge - storage.min_soc)
    max_power = min(storage.max_discharge_rate, available_energy)
    return max(0.0, max_power)
end

"""
Update state of charge based on power dispatch
"""
function update_soc!(storage::ExtendedStorageGenerator, power::Float64, dt::Float64)
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
function get_storage_cost(storage::ExtendedStorageGenerator, power::Float64)
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
function get_reserve_capability(storage::ExtendedStorageGenerator)
    charge_reserve = min(storage.reserve_up_capability, get_available_charge_power(storage))
    discharge_reserve = min(storage.reserve_down_capability, get_available_discharge_power(storage))
    return (up = charge_reserve, down = discharge_reserve)
end

# Optimization model functions for storage
"""
Add storage variables to optimization model
"""
function add_storage_variables!(model::Model, storage::ExtendedStorageGenerator, time_periods::Int)
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
function add_storage_constraints!(model::Model, storage::ExtendedStorageGenerator, 
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
function add_storage_objective!(model::Model, storage::ExtendedStorageGenerator, time_periods::Int)
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
function gpoweranglemessage(storage::ExtendedStorageGenerator, voltage_angle::Float64, 
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
function update_storage_duals!(storage::ExtendedStorageGenerator, power_mismatch::Float64, 
                              rho::Float64, lambda::Vector{Float64}, t::Int)
    # Update lambda based on power balance violation
    lambda[t] += rho * power_mismatch
    return lambda
end

"""
Storage consensus step in APP-ADMM
"""
function storage_consensus_step!(storage::ExtendedStorageGenerator, 
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
function get_storage_status(storage::ExtendedStorageGenerator)
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

function print_storage_summary(storage::ExtendedStorageGenerator)
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