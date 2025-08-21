using PowerSystems
using InfrastructureSystems
const IS = InfrastructureSystems

# Extended Storage Generator for PowerLASCOPF with Sienna integration
mutable struct ExtendedStorageGenerator{T<:Storage} <: Storage
    # Core storage properties
    storage_type::T
    gen_id::Int
    
    # Power and energy properties
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PrimeMovers
    active_power_limits::MinMax
    reactive_power_limits::Union{Nothing, MinMax}
    ramp_limits::Union{Nothing, RampLimits}
    operation_cost::Union{Nothing, OperationalCost}
    
    # Storage-specific properties
    state_of_charge_limits::MinMax
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
    thermal_limits::MinMax
    cooling_efficiency::Float64
    
    # Inner constructor
    function ExtendedStorageGenerator{T}(
        storage_type::T,
        gen_id::Int,
        node_connection::Int,
        zone_id::Int,
        scenario_count::Int
    ) where T <: Storage
        return new{T}(
            storage_type,
            gen_id,
            PowerSystems.get_active_power(storage_type),
            PowerSystems.get_reactive_power(storage_type),
            PowerSystems.get_rating(storage_type),
            PowerSystems.get_prime_mover_type(storage_type),
            PowerSystems.get_active_power_limits(storage_type),
            PowerSystems.get_reactive_power_limits(storage_type),
            PowerSystems.get_ramp_limits(storage_type),
            PowerSystems.get_operation_cost(storage_type),
            PowerSystems.get_state_of_charge_limits(storage_type),
            PowerSystems.get_initial_energy(storage_type),
            PowerSystems.get_efficiency(storage_type),
            node_connection,
            zone_id,
            scenario_count,
            0.0,  # marginal_cost_charge
            0.0,  # marginal_cost_discharge
            0.0,  # startup_cost
            0.0,  # shutdown_cost
            PowerSystems.get_initial_energy(storage_type),  # state_of_charge
            PowerSystems.get_state_of_charge_limits(storage_type).max,  # energy_capacity
            0.0,  # charge_power
            0.0,  # discharge_power
            PowerSystems.get_efficiency(storage_type).charge,  # charging_efficiency
            PowerSystems.get_efficiency(storage_type).discharge,  # discharging_efficiency
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
            (min = 0.0, max = 50.0),  # thermal_limits
            0.95   # cooling_efficiency
        )
    end
end

# Outer constructor
function ExtendedStorageGenerator(
    storage_type::T,
    gen_id::Int,
    node_connection::Int,
    zone_id::Int,
    scenario_count::Int
) where T <: Storage
    return ExtendedStorageGenerator{T}(storage_type, gen_id, node_connection, zone_id, scenario_count)
end

# Extend PowerSystems.Storage interface
PowerSystems.get_name(gen::ExtendedStorageGenerator) = PowerSystems.get_name(gen.storage_type)
PowerSystems.get_available(gen::ExtendedStorageGenerator) = PowerSystems.get_available(gen.storage_type)
PowerSystems.get_bus(gen::ExtendedStorageGenerator) = PowerSystems.get_bus(gen.storage_type)
PowerSystems.get_active_power(gen::ExtendedStorageGenerator) = gen.active_power
PowerSystems.get_reactive_power(gen::ExtendedStorageGenerator) = gen.reactive_power
PowerSystems.get_rating(gen::ExtendedStorageGenerator) = gen.rating
PowerSystems.get_prime_mover_type(gen::ExtendedStorageGenerator) = gen.prime_mover_type
PowerSystems.get_active_power_limits(gen::ExtendedStorageGenerator) = gen.active_power_limits
PowerSystems.get_reactive_power_limits(gen::ExtendedStorageGenerator) = gen.reactive_power_limits
PowerSystems.get_ramp_limits(gen::ExtendedStorageGenerator) = gen.ramp_limits
PowerSystems.get_operation_cost(gen::ExtendedStorageGenerator) = gen.operation_cost
PowerSystems.get_state_of_charge_limits(gen::ExtendedStorageGenerator) = gen.state_of_charge_limits
PowerSystems.get_initial_energy(gen::ExtendedStorageGenerator) = gen.initial_energy
PowerSystems.get_efficiency(gen::ExtendedStorageGenerator) = gen.efficiency

# Extend InfrastructureSystems.Component interface
IS.get_uuid(gen::ExtendedStorageGenerator) = IS.get_uuid(gen.storage_type)
IS.get_ext(gen::ExtendedStorageGenerator) = IS.get_ext(gen.storage_type)
IS.get_time_series_container(gen::ExtendedStorageGenerator) = IS.get_time_series_container(gen.storage_type)

# Core getter/setter functions
get_gen_id(gen::ExtendedStorageGenerator) = gen.gen_id
get_node_connection(gen::ExtendedStorageGenerator) = gen.node_connection
get_zone_id(gen::ExtendedStorageGenerator) = gen.zone_id
get_scenario_count(gen::ExtendedStorageGenerator) = gen.scenario_count

# Economic functions
get_marginal_cost_charge(gen::ExtendedStorageGenerator) = gen.marginal_cost_charge
set_marginal_cost_charge!(gen::ExtendedStorageGenerator, cost::Float64) = (gen.marginal_cost_charge = cost)

get_marginal_cost_discharge(gen::ExtendedStorageGenerator) = gen.marginal_cost_discharge
set_marginal_cost_discharge!(gen::ExtendedStorageGenerator, cost::Float64) = (gen.marginal_cost_discharge = cost)

# Storage state functions
get_state_of_charge(gen::ExtendedStorageGenerator) = gen.state_of_charge
function set_state_of_charge!(gen::ExtendedStorageGenerator, soc::Float64)
    gen.state_of_charge = clamp(soc, gen.state_of_charge_limits.min, gen.state_of_charge_limits.max)
    return nothing
end

get_energy_capacity(gen::ExtendedStorageGenerator) = gen.energy_capacity
get_available_energy(gen::ExtendedStorageGenerator) = gen.state_of_charge
get_remaining_capacity(gen::ExtendedStorageGenerator) = gen.energy_capacity - gen.state_of_charge

# Power functions
get_charge_power(gen::ExtendedStorageGenerator) = gen.charge_power
function set_charge_power!(gen::ExtendedStorageGenerator, power::Float64)
    max_charge = gen.active_power_limits.max
    gen.charge_power = clamp(power, 0.0, max_charge)
    gen.operating_mode = power > 0.0 ? :charge : gen.operating_mode
    return nothing
end

get_discharge_power(gen::ExtendedStorageGenerator) = gen.discharge_power
function set_discharge_power!(gen::ExtendedStorageGenerator, power::Float64)
    max_discharge = gen.active_power_limits.max
    available_energy = gen.state_of_charge
    max_power_from