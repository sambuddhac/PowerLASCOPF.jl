# Unified Generator Framework for PowerLASCOPF
# This module creates a unified interface that links the 5 specialized generator types
# with the common APP+ADMM-PMP messaging functionality from ExtendedThermalGenerator.jl

using PowerSystems
using InfrastructureSystems

# Import the specialized generator types
include("extended_hydro.jl")
include("extended_storage.jl") 
include("renewable_generator.jl")
include("storage_generator.jl")
# Import the common messaging framework
include("ExtendedThermalGenerator.jl")
include("GeneralizedGenerator.jl")

# Define abstract type for unified generator interface
abstract type UnifiedGenerator end

# ===== UNIFIED GENERATOR WRAPPER =====

"""
UnifiedGeneratorWrapper

A wrapper that provides a common interface for all 5 generator types to use
the APP+ADMM-PMP messaging functionality from ExtendedThermalGenerator.jl
"""
mutable struct UnifiedGeneratorWrapper{T} <: UnifiedGenerator
    # Core generator (one of the 5 specialized types)
    generator::T
    
    # Common APP+ADMM messaging interface
    messaging_framework::ExtendedThermalGenerator
    
    # Generator type identification
    generator_type::Symbol  # :thermal, :hydro, :storage, :renewable, :storage_gen
    
    # Unified interface properties
    gen_id::Int
    node_connection::Int
    scenario_count::Int
    
    # APP-ADMM specific properties
    lambda_dual::Vector{Float64}     # Dual variables for power balance
    rho_penalty::Float64             # ADMM penalty parameter
    power_consensus::Vector{Float64} # Consensus variables
    angle_consensus::Vector{Float64} # Voltage angle consensus
    
    # Message passing state
    incoming_messages::Dict{String, Vector{Float64}}
    outgoing_messages::Dict{String, Vector{Float64}}
    neighbor_list::Vector{Int}
    
    # Performance tracking
    iteration_count::Int
    convergence_history::Vector{Float64}
    objective_value::Float64
    
    function UnifiedGeneratorWrapper{T}(
        generator::T,
        messaging_framework::ExtendedThermalGenerator,
        generator_type::Symbol,
        gen_id::Int,
        node_connection::Int,
        scenario_count::Int
    ) where T
        return new{T}(
            generator,
            messaging_framework,
            generator_type,
            gen_id,
            node_connection,
            scenario_count,
            zeros(scenario_count),  # lambda_dual
            1.0,                    # rho_penalty
            zeros(scenario_count),  # power_consensus
            zeros(scenario_count),  # angle_consensus
            Dict{String, Vector{Float64}}(),  # incoming_messages
            Dict{String, Vector{Float64}}(),  # outgoing_messages
            Int[],                  # neighbor_list
            0,                      # iteration_count
            Float64[],              # convergence_history
            0.0                     # objective_value
        )
    end
end

# ===== CONSTRUCTOR FUNCTIONS =====

"""
Create unified generator wrapper for Thermal Generator
"""
function create_unified_thermal_generator(
    thermal_gen::ExtendedThermalGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # The thermal generator already has the messaging framework
    wrapper = UnifiedGeneratorWrapper{ExtendedThermalGenerator}(
        thermal_gen,
        thermal_gen,  # Self-reference for messaging
        :thermal,
        gen_id,
        node_connection,
        scenario_count
    )
    
    # Initialize messaging
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Hydro Generator
"""
function create_unified_hydro_generator(
    hydro_gen::ExtendedHydroGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_hydro(hydro_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedHydroGenerator}(
        hydro_gen,
        mock_thermal,
        :hydro,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Storage Generator
"""
function create_unified_storage_generator(
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_storage(storage_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedStorageGenerator}(
        storage_gen,
        mock_thermal,
        :storage,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Renewable Generator
"""
function create_unified_renewable_generator(
    renewable_gen::ExtendedRenewableGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_renewable(renewable_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedRenewableGenerator}(
        renewable_gen,
        mock_thermal,
        :renewable,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Storage Generator (Battery)
"""
function create_unified_storage_gen_generator(
    storage_gen_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_storage_gen(storage_gen_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedStorageGenerator}(
        storage_gen_gen,
        mock_thermal,
        :storage_gen,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

# ===== MESSAGING INTERFACE CREATION =====

"""
Create messaging interface for hydro generator
"""
function create_messaging_interface_for_hydro(
    hydro::ExtendedHydroGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert hydro to thermal-like interface
    # Create a mock thermal generator with equivalent parameters
    
    # Extract relevant parameters from hydro generator
    name = hydro.name
    bus = hydro.bus
    rating = hydro.rating
    min_power = hydro.active_power_limits.min
    max_power = hydro.active_power_limits.max
    
    # Create mock thermal generator cost function
    # For hydro, use water value as fuel cost
    fuel_cost = hydro.water_value / 1000.0  # Convert from $/acre-foot to $/MMBtu equivalent
    
    # Create thermal generation cost with hydro characteristics
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(fuel_cost),
        fixed = 0.0,
        start_up = hydro.start_stop_cost,
        shut_down = hydro.start_stop_cost * 0.5
    )
    
    # Create mock thermal generator for messaging
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = hydro.available,
        status = true,
        bus = bus,
        active_power = hydro.active_power,
        reactive_power = hydro.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.HY,  # Hydro prime mover
        fuel = ThermalFuels.HYDRO,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = hydro.reactive_power_limits,
        ramp_limits = (up = hydro.ramping_rate, down = hydro.ramping_rate),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    # Create mock node connection
    mock_node = Node(bus, 1, scenario_count)
    
    # Create mock solver (simplified)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    # Create ExtendedThermalGenerator for messaging
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0,    # interval
        false, # last_flag
        scenario_count,
        mock_solver,
        0,    # pc_scenario_count
        0,    # base_cont
        0,    # dummy_zero
        1,    # accuracy
        mock_node,
        scenario_count,
        1     # gen_total
    )
    
    return extended_thermal
end

"""
Create messaging interface for storage generator
"""
function create_messaging_interface_for_storage(
    storage::ExtendedStorageGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert storage to thermal-like interface
    
    name = PowerSystems.get_name(storage)
    bus = PowerSystems.get_bus(storage)
    rating = storage.rating
    min_power = storage.active_power_limits.min
    max_power = storage.active_power_limits.max
    
    # For storage, use cycle degradation cost as equivalent fuel cost
    cycle_cost = storage.degradation_factor * storage.energy_capacity * 0.1  # $/MWh
    
    # Create thermal generation cost with storage characteristics
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(cycle_cost),
        fixed = 0.0,
        start_up = 0.0,  # Storage has no startup cost
        shut_down = 0.0
    )
    
    # Create mock thermal generator
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(storage),
        status = true,
        bus = bus,
        active_power = storage.active_power,
        reactive_power = storage.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.BA,  # Battery storage
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = storage.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),  # Fast ramping for storage
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    # Create components for ExtendedThermalGenerator
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create messaging interface for renewable generator
"""
function create_messaging_interface_for_renewable(
    renewable::ExtendedRenewableGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert renewable to thermal-like interface
    
    name = PowerSystems.get_name(renewable)
    bus = PowerSystems.get_bus(renewable)
    rating = renewable.rating
    min_power = renewable.active_power_limits.min
    max_power = renewable.max_active_power  # Use renewable max capacity
    
    # For renewables, use marginal cost + curtailment cost
    fuel_cost = renewable.marginal_cost + renewable.curtailment_cost
    
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(fuel_cost),
        fixed = 0.0,
        start_up = 0.0,  # Renewables have no startup cost
        shut_down = 0.0
    )
    
    # Determine prime mover based on renewable type
    prime_mover = renewable.prime_mover_type
    
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(renewable),
        status = true,
        bus = bus,
        active_power = renewable.active_power,
        reactive_power = renewable.reactive_power,
        rating = rating,
        prime_mover = prime_mover,
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = renewable.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),  # Fast changes for renewables
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create messaging interface for storage generator (battery type)
"""
function create_messaging_interface_for_storage_gen(
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Similar to storage but for the battery generator type
    
    name = PowerSystems.get_name(storage_gen)
    bus = PowerSystems.get_bus(storage_gen)
    rating = storage_gen.rating
    min_power = storage_gen.active_power_limits.min
    max_power = storage_gen.active_power_limits.max
    
    # Use degradation cost for battery
    battery_cost = storage_gen.degradation_factor * 100.0  # $/MWh equivalent
    
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(battery_cost),
        fixed = 0.0,
        start_up = 0.0,
        shut_down = 0.0
    )
    
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(storage_gen),
        status = true,
        bus = bus,
        active_power = storage_gen.active_power,
        reactive_power = storage_gen.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.BA,
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = storage_gen.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create mock generator solver for messaging interface
"""
function create_mock_gen_solver(gen_id::Int, scenario_count::Int)
    # Create a simplified mock solver that satisfies the interface
    # In practice, each generator type would use its specialized solver
    
    return GenSolver(
        gen_id = gen_id,
        scenario_count = scenario_count,
        # Add other required fields with default values
        p_solution = 0.0,
        p_next_solution = 0.0,
        p_prev_solution = 0.0,
        theta_solution = 0.0,
        objective_value = 0.0
    )
end

# ===== UNIFIED INTERFACE FUNCTIONS =====

"""
Initialize messaging for unified generator
"""
function initialize_messaging!(wrapper::UnifiedGeneratorWrapper)
    # Initialize message containers
    wrapper.incoming_messages["power"] = zeros(wrapper.scenario_count)
    wrapper.incoming_messages["voltage_angle"] = zeros(wrapper.scenario_count)
    wrapper.incoming_messages["lambda"] = zeros(wrapper.scenario_count)
    
    wrapper.outgoing_messages["power"] = zeros(wrapper.scenario_count)
    wrapper.outgoing_messages["voltage_angle"] = zeros(wrapper.scenario_count)
    wrapper.outgoing_messages["cost"] = zeros(wrapper.scenario_count)
    
    # Initialize dual variables
    wrapper.lambda_dual = zeros(wrapper.scenario_count)
    wrapper.power_consensus = zeros(wrapper.scenario_count)
    wrapper.angle_consensus = zeros(wrapper.scenario_count)
    
    return nothing
end

"""
Unified power angle message passing function
Uses the common messaging framework from ExtendedThermalGenerator
"""
function unified_power_angle_message!(
    wrapper::UnifiedGeneratorWrapper,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    Pgenavg::Float64,
    Powerprice::Float64,
    Angpriceavg::Float64,
    Angavg::Float64,
    Angprice::Float64,
    scenario_args...  # Additional scenario-specific arguments
)
    # Delegate to the common messaging framework
    result = gpower_angle_message!(
        wrapper.messaging_framework,
        outerAPPIt,
        APPItCount,
        gsRho,
        Pgenavg,
        Powerprice,
        Angpriceavg,
        Angavg,
        Angprice,
        scenario_args...
    )
    
    # Update wrapper state
    wrapper.iteration_count = outerAPPIt
    wrapper.rho_penalty = gsRho
    
    # Extract results and update generator-specific properties
    update_generator_from_messaging_result!(wrapper, result)
    
    return result
end

"""
Update generator-specific properties based on messaging result
"""
function update_generator_from_messaging_result!(
    wrapper::UnifiedGeneratorWrapper{T},
    result
) where T
    # Extract common results
    power_output = wrapper.messaging_framework.Pg
    voltage_angle = wrapper.messaging_framework.theta_g
    
    # Update based on generator type
    if wrapper.generator_type == :thermal
        # Thermal generator - direct update
        wrapper.generator.Pg = power_output
        wrapper.generator.theta_g = voltage_angle
        
    elseif wrapper.generator_type == :hydro
        # Hydro generator - update flow rate and power
        wrapper.generator.active_power = power_output
        flow_rate = calculate_required_flow(wrapper.generator, power_output)
        wrapper.generator.flow_rate = flow_rate
        
        # Update reservoir level if time step is available
        # update_reservoir_level!(wrapper.generator, flow_rate, wrapper.generator.inflow, 1.0)
        
    elseif wrapper.generator_type == :storage
        # Storage generator - update SOC and power
        wrapper.generator.active_power = power_output
        
        # Update SOC based on power dispatch (positive = discharge, negative = charge)
        dt = 1.0  # 1 hour time step
        update_soc!(wrapper.generator, power_output, dt)
        
    elseif wrapper.generator_type == :renewable
        # Renewable generator - update within available capacity
        available_power = get_available_power(wrapper.generator)
        wrapper.generator.power_output = min(power_output, available_power)
        
    elseif wrapper.generator_type == :storage_gen
        # Storage generator (battery) - update SOC and power
        wrapper.generator.active_power = power_output
        wrapper.generator.power_output = power_output
        
        # Update state of charge
        dt = 1.0
        if power_output > 0  # Discharging
            energy_change = -power_output * dt / wrapper.generator.discharging_efficiency
        else  # Charging
            energy_change = -power_output * dt * wrapper.generator.charging_efficiency
        end
        
        new_soc = wrapper.generator.state_of_charge + energy_change / wrapper.generator.energy_capacity
        set_state_of_charge!(wrapper.generator, new_soc)
    end
    
    # Update common wrapper properties
    wrapper.outgoing_messages["power"][1] = power_output
    wrapper.outgoing_messages["voltage_angle"][1] = voltage_angle
    
    return nothing
end

"""
Get generator power output
"""
function get_unified_power_output(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return wrapper.generator.Pg
    elseif wrapper.generator_type == :hydro
        return wrapper.generator.active_power
    elseif wrapper.generator_type == :storage
        return wrapper.generator.active_power
    elseif wrapper.generator_type == :renewable
        return wrapper.generator.power_output
    elseif wrapper.generator_type == :storage_gen
        return wrapper.generator.power_output
    else
        return 0.0
    end
end

"""
Get generator marginal cost
"""
function get_unified_marginal_cost(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return calculate_marginal_cost(wrapper.generator, wrapper.generator.Pg)
    elseif wrapper.generator_type == :hydro
        return calculate_water_value(wrapper.generator)
    elseif wrapper.generator_type == :storage
        return get_storage_cost(wrapper.generator, wrapper.generator.active_power)
    elseif wrapper.generator_type == :renewable
        return get_effective_cost(wrapper.generator)
    elseif wrapper.generator_type == :storage_gen
        return wrapper.generator.marginal_cost_discharge
    else
        return 0.0
    end
end

"""
Check if generator is available and online
"""
function is_unified_generator_available(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return wrapper.generator.generator.available && wrapper.generator.gen_solver.commitment_status
    elseif wrapper.generator_type == :hydro
        return wrapper.generator.available
    elseif wrapper.generator_type == :storage
        return wrapper.generator.available
    elseif wrapper.generator_type == :renewable
        return is_available(wrapper.generator)
    elseif wrapper.generator_type == :storage_gen
        return PowerSystems.get_available(wrapper.generator)
    else
        return false
    end
end

# ===== EXPORT FUNCTIONS =====

export UnifiedGeneratorWrapper, UnifiedGenerator
export create_unified_thermal_generator, create_unified_hydro_generator
export create_unified_storage_generator, create_unified_renewable_generator
export create_unified_storage_gen_generator
export unified_power_angle_message!, initialize_messaging!
export get_unified_power_output, get_unified_marginal_cost, is_unified_generator_available
export update_generator_from_messaging_result!
