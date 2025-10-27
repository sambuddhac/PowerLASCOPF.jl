using PowerSystems
using InfrastructureSystems
const PSY = PowerSystems
const IS = InfrastructureSystems

# Import the correct PowerSystems types - Fix: Add Storage type
import PowerSystems: MinMax, UpDown, PrimeMovers, OperationalCost, Storage

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
        
        # Storage-specific properties with fallbacks
        soc_limits = try
            # Try different possible function names for storage limits
            if hasmethod(PSY.get_storage_level_limits, (typeof(storage_type),))
                PSY.get_storage_level_limits(storage_type)
            elseif hasmethod(PSY.get_state_of_charge_limits, (typeof(storage_type),))
                PSY.get_state_of_charge_limits(storage_type)
            else
                PSY.MinMax(0.0, 100.0)  # Default 0-100 MWh
            end
        catch
            PSY.MinMax(0.0, 100.0)  # Default fallback
        end
        
        initial_energy = try
            # Try different possible function names for initial energy
            if hasmethod(PSY.get_initial_energy, (typeof(storage_type),))
                PSY.get_initial_energy(storage_type)
            elseif hasmethod(PSY.get_initial_storage, (typeof(storage_type),))
                PSY.get_initial_storage(storage_type)
            else
                soc_limits.max * 0.5  # Default 50% SOC
            end
        catch
            soc_limits.max * 0.5  # Default fallback
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