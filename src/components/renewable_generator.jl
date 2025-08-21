using PowerSystems
using InfrastructureSystems
const IS = InfrastructureSystems

# Extended Renewable Generator for PowerLASCOPF with Sienna integration
mutable struct ExtendedRenewableGenerator{T<:RenewableGen} <: RenewableGen
    # Core renewable generator properties
    renewable_type::T
    gen_id::Int
    
    # Power and economic properties
    active_power::Float64
    reactive_power::Float64
    rating::Float64
    prime_mover_type::PrimeMovers
    active_power_limits::MinMax
    reactive_power_limits::Union{Nothing, MinMax}
    ramp_limits::Union{Nothing, RampLimits}
    operation_cost::Union{Nothing, OperationalCost}
    
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
    function ExtendedRenewableGenerator{T}(
        renewable_type::T,
        gen_id::Int,
        node_connection::Int,
        zone_id::Int,
        scenario_count::Int
    ) where T <: RenewableGen
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
function ExtendedRenewableGenerator(
    renewable_type::T,
    gen_id::Int,
    node_connection::Int,
    zone_id::Int,
    scenario_count::Int
) where T <: RenewableGen
    return ExtendedRenewableGenerator{T}(renewable_type, gen_id, node_connection, zone_id, scenario_count)
end

# Extend PowerSystems.RenewableGen interface
PowerSystems.get_name(gen::ExtendedRenewableGenerator) = PowerSystems.get_name(gen.renewable_type)
PowerSystems.get_available(gen::ExtendedRenewableGenerator) = PowerSystems.get_available(gen.renewable_type)
PowerSystems.get_bus(gen::ExtendedRenewableGenerator) = PowerSystems.get_bus(gen.renewable_type)
PowerSystems.get_active_power(gen::ExtendedRenewableGenerator) = gen.active_power
PowerSystems.get_reactive_power(gen::ExtendedRenewableGenerator) = gen.reactive_power
PowerSystems.get_rating(gen::ExtendedRenewableGenerator) = gen.rating
PowerSystems.get_prime_mover_type(gen::ExtendedRenewableGenerator) = gen.prime_mover_type
PowerSystems.get_active_power_limits(gen::ExtendedRenewableGenerator) = gen.active_power_limits
PowerSystems.get_reactive_power_limits(gen::ExtendedRenewableGenerator) = gen.reactive_power_limits
PowerSystems.get_ramp_limits(gen::ExtendedRenewableGenerator) = gen.ramp_limits
PowerSystems.get_operation_cost(gen::ExtendedRenewableGenerator) = gen.operation_cost
PowerSystems.get_power_factor(gen::ExtendedRenewableGenerator) = gen.power_factor
PowerSystems.get_max_active_power(gen::ExtendedRenewableGenerator) = gen.max_active_power
PowerSystems.get_max_reactive_power(gen::ExtendedRenewableGenerator) = gen.max_reactive_power

# Extend InfrastructureSystems.Component interface
IS.get_uuid(gen::ExtendedRenewableGenerator) = IS.get_uuid(gen.renewable_type)
IS.get_ext(gen::ExtendedRenewableGenerator) = IS.get_ext(gen.renewable_type)
IS.get_time_series_container(gen::ExtendedRenewableGenerator) = IS.get_time_series_container(gen.renewable_type)

# Core getter/setter functions
get_gen_id(gen::ExtendedRenewableGenerator) = gen.gen_id
get_node_connection(gen::ExtendedRenewableGenerator) = gen.node_connection
get_zone_id(gen::ExtendedRenewableGenerator) = gen.zone_id
get_scenario_count(gen::ExtendedRenewableGenerator) = gen.scenario_count

# Economic functions
get_marginal_cost(gen::ExtendedRenewableGenerator) = gen.marginal_cost
set_marginal_cost!(gen::ExtendedRenewableGenerator, cost::Float64) = (gen.marginal_cost = cost)

get_curtailment_cost(gen::ExtendedRenewableGenerator) = gen.curtailment_cost
set_curtailment_cost!(gen::ExtendedRenewableGenerator, cost::Float64) = (gen.curtailment_cost = cost)

# Renewable-specific functions
get_capacity_factor(gen::ExtendedRenewableGenerator) = gen.capacity_factor
set_capacity_factor!(gen::ExtendedRenewableGenerator, factor::Float64) = (gen.capacity_factor = clamp(factor, 0.0, 1.0))

get_availability_factor(gen::ExtendedRenewableGenerator) = gen.availability_factor
set_availability_factor!(gen::ExtendedRenewableGenerator, factor::Float64) = (gen.availability_factor = clamp(factor, 0.0, 1.0))

get_forecast_data(gen::ExtendedRenewableGenerator) = gen.forecast_data
function set_forecast_data!(gen::ExtendedRenewableGenerator, data::Vector{Float64})
    gen.forecast_data = copy(data)
    return nothing
end

get_forecast_uncertainty(gen::ExtendedRenewableGenerator) = gen.forecast_uncertainty
set_forecast_uncertainty!(gen::ExtendedRenewableGenerator, uncertainty::Float64) = (gen.forecast_uncertainty = clamp(uncertainty, 0.0, 1.0))

# LASCOPF operational functions
get_lambda_avg(gen::ExtendedRenewableGenerator) = gen.lambda_avg
set_lambda_avg!(gen::ExtendedRenewableGenerator, lambda::Float64) = (gen.lambda_avg = lambda)

get_power_output(gen::ExtendedRenewableGenerator) = gen.power_output
function set_power_output!(gen::ExtendedRenewableGenerator, power::Float64)
    max_power = gen.max_active_power * gen.capacity_factor * gen.availability_factor
    gen.power_output = clamp(power, 0.0, max_power)
    return nothing
end

get_commitment_status(gen::ExtendedRenewableGenerator) = gen.commitment_status
set_commitment_status!(gen::ExtendedRenewableGenerator, status::Bool) = (gen.commitment_status = status)

# Scenario-based functions
get_power_scenarios(gen::ExtendedRenewableGenerator) = gen.power_scenarios
function set_power_scenario!(gen::ExtendedRenewableGenerator, scenario::Int, power::Float64)
    if 1 <= scenario <= gen.scenario_count
        max_power = gen.max_active_power * gen.capacity_factor * gen.availability_factor
        gen.power_scenarios[scenario] = clamp(power, 0.0, max_power)
    end
    return nothing
end

get_cost_scenarios(gen::ExtendedRenewableGenerator) = gen.cost_scenarios
function set_cost_scenario!(gen::ExtendedRenewableGenerator, scenario::Int, cost::Float64)
    if 1 <= scenario <= gen.scenario_count
        gen.cost_scenarios[scenario] = max(cost, 0.0)
    end
    return nothing
end

get_availability_scenarios(gen::ExtendedRenewableGenerator) = gen.availability_scenarios
function set_availability_scenario!(gen::ExtendedRenewableGenerator, scenario::Int, availability::Float64)
    if 1 <= scenario <= gen.scenario_count
        gen.availability_scenarios[scenario] = clamp(availability, 0.0, 1.0)
    end
    return nothing
end

# Grid integration functions
get_voltage_regulation(gen::ExtendedRenewableGenerator) = gen.voltage_regulation
set_voltage_regulation!(gen::ExtendedRenewableGenerator, capability::Bool) = (gen.voltage_regulation = capability)

get_frequency_response(gen::ExtendedRenewableGenerator) = gen.frequency_response
set_frequency_response!(gen::ExtendedRenewableGenerator, capability::Bool) = (gen.frequency_response = capability)

get_grid_forming_capability(gen::ExtendedRenewableGenerator) = gen.grid_forming_capability
set_grid_forming_capability!(gen::ExtendedRenewableGenerator, capability::Bool) = (gen.grid_forming_capability = capability)

get_inverter_efficiency(gen::ExtendedRenewableGenerator) = gen.inverter_efficiency
set_inverter_efficiency!(gen::ExtendedRenewableGenerator, efficiency::Float64) = (gen.inverter_efficiency = clamp(efficiency, 0.0, 1.0))

# Environmental and policy functions
get_renewable_energy_credits(gen::ExtendedRenewableGenerator) = gen.renewable_energy_credits
set_renewable_energy_credits!(gen::ExtendedRenewableGenerator, credits::Float64) = (gen.renewable_energy_credits = max(credits, 0.0))

get_carbon_offset(gen::ExtendedRenewableGenerator) = gen.carbon_offset
set_carbon_offset!(gen::ExtendedRenewableGenerator, offset::Float64) = (gen.carbon_offset = max(offset, 0.0))

# Performance and reliability functions
get_forced_outage_rate(gen::ExtendedRenewableGenerator) = gen.forced_outage_rate
set_forced_outage_rate!(gen::ExtendedRenewableGenerator, rate::Float64) = (gen.forced_outage_rate = clamp(rate, 0.0, 1.0))

get_reliability_factor(gen::ExtendedRenewableGenerator) = gen.reliability_factor
set_reliability_factor!(gen::ExtendedRenewableGenerator, factor::Float64) = (gen.reliability_factor = clamp(factor, 0.0, 1.0))

# Maintenance functions
get_maintenance_schedule(gen::ExtendedRenewableGenerator) = gen.maintenance_schedule
function add_maintenance_period!(gen::ExtendedRenewableGenerator, period::Int)
    if period > 0 && !(period in gen.maintenance_schedule)
        push!(gen.maintenance_schedule, period)
        sort!(gen.maintenance_schedule)
    end
    return nothing
end

function is_under_maintenance(gen::ExtendedRenewableGenerator, period::Int)
    return period in gen.maintenance_schedule
end

# Performance tracking functions
get_energy_produced(gen::ExtendedRenewableGenerator) = gen.energy_produced
function update_energy_produced!(gen::ExtendedRenewableGenerator, energy::Float64)
    gen.energy_produced += max(energy, 0.0)
    return nothing
end

get_capacity_utilization(gen::ExtendedRenewableGenerator) = gen.capacity_utilization
function calculate_capacity_utilization!(gen::ExtendedRenewableGenerator, hours::Float64)
    if hours > 0 && gen.max_active_power > 0
        gen.capacity_utilization = gen.energy_produced / (gen.max_active_power * hours)
    end
    return gen.capacity_utilization
end

get_curtailment_hours(gen::ExtendedRenewableGenerator) = gen.curtailment_hours
function update_curtailment_hours!(gen::ExtendedRenewableGenerator, hours::Float64)
    gen.curtailment_hours += max(hours, 0.0)
    return nothing
end

# Utility functions
function get_available_power(gen::ExtendedRenewableGenerator, scenario::Int = 1)
    base_power = gen.max_active_power * gen.capacity_factor
    if 1 <= scenario <= gen.scenario_count
        return base_power * gen.availability_scenarios[scenario]
    end
    return base_power * gen.availability_factor
end

function get_effective_cost(gen::ExtendedRenewableGenerator, scenario::Int = 1)
    base_cost = gen.marginal_cost
    if 1 <= scenario <= gen.scenario_count
        return gen.cost_scenarios[scenario]
    end
    return base_cost
end

function is_available(gen::ExtendedRenewableGenerator, scenario::Int = 1)
    return gen.commitment_status && 
           !is_under_maintenance(gen, scenario) && 
           get_available_power(gen, scenario) > 0.0
end

# Reset function
function reset!(gen::ExtendedRenewableGenerator)
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
function Base.show(io::IO, gen::ExtendedRenewableGenerator)
    print(io, "ExtendedRenewableGenerator(")
    print(io, "id=$(gen.gen_id), ")
    print(io, "type=$(gen.prime_mover_type), ")
    print(io, "max_power=$(gen.max_active_power), ")
    print(io, "capacity_factor=$(gen.capacity_factor), ")
    print(io, "node=$(gen.node_connection)")
    print(io, ")")
end

# Export functions
export ExtendedRenewableGenerator
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