# Generator Integration Module for PowerLASCOPF System
# This module integrates the unified generator framework with the PowerLASCOPF system

include("unified_generator_framework.jl")
include("../extensions/extended_system.jl")  # Your PSY.System extension

# ===== POWERLASCOPF SYSTEM INTEGRATION =====

"""
Add unified generator to PowerLASCOPF system
"""
function add_unified_generator!(
    system::PowerLASCOPFSystem,
    generator_wrapper::UnifiedGeneratorWrapper
)
    # Add to the PowerLASCOPF system's generator collection
    if !haskey(system.extended_data, "unified_generators")
        system.extended_data["unified_generators"] = Dict{Int, UnifiedGeneratorWrapper}()
    end
    
    # Store the unified generator
    system.extended_data["unified_generators"][generator_wrapper.gen_id] = generator_wrapper
    
    # Add to PSY system based on generator type
    if generator_wrapper.generator_type == :thermal
        add_component!(system, generator_wrapper.generator.generator)
    elseif generator_wrapper.generator_type == :hydro
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :storage
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :renewable
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :storage_gen
        add_component!(system, generator_wrapper.generator)
    end
    
    println("Added $(generator_wrapper.generator_type) generator (ID: $(generator_wrapper.gen_id)) to PowerLASCOPF system")
    return nothing
end

"""
Create and add thermal generator to system
"""
function add_thermal_generator!(
    system::PowerLASCOPFSystem,
    thermal_gen::ExtendedThermalGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_thermal_generator(thermal_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add hydro generator to system
"""
function add_hydro_generator!(
    system::PowerLASCOPFSystem,
    hydro_gen::ExtendedHydroGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_hydro_generator(hydro_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add storage generator to system
"""
function add_storage_generator!(
    system::PowerLASCOPFSystem,
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_storage_generator(storage_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add renewable generator to system
"""
function add_renewable_generator!(
    system::PowerLASCOPFSystem,
    renewable_gen::ExtendedRenewableGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_renewable_generator(renewable_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add storage generator (battery) to system
"""
function add_storage_gen_generator!(
    system::PowerLASCOPFSystem,
    storage_gen_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_storage_gen_generator(storage_gen_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

# ===== SYSTEM-WIDE OPERATIONS =====

"""
Run APP+ADMM messaging for all generators in the system
"""
function run_unified_messaging!(
    system::PowerLASCOPFSystem,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    power_prices::Dict{Int, Float64},
    angle_prices::Dict{Int, Float64},
    power_averages::Dict{Int, Float64},
    angle_averages::Dict{Int, Float64}
)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Any}()
    end
    
    results = Dict{Int, Any}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        # Get prices and averages for this generator's node
        node_id = generator_wrapper.node_connection
        
        power_price = get(power_prices, node_id, 0.0)
        angle_price = get(angle_prices, node_id, 0.0)
        power_avg = get(power_averages, node_id, 0.0)
        angle_avg = get(angle_averages, node_id, 0.0)
        
        # Run unified messaging
        result = unified_power_angle_message!(
            generator_wrapper,
            outerAPPIt,
            APPItCount,
            gsRho,
            power_avg,
            power_price,
            angle_price,  # Angpriceavg
            angle_avg,    # Angavg
            angle_price   # Angprice
        )
        
        results[gen_id] = result
    end
    
    return results
end

"""
Get all generator power outputs
"""
function get_all_generator_outputs(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Float64}()
    end
    
    outputs = Dict{Int, Float64}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        outputs[gen_id] = get_unified_power_output(generator_wrapper)
    end
    
    return outputs
end

"""
Get all generator marginal costs
"""
function get_all_generator_costs(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Float64}()
    end
    
    costs = Dict{Int, Float64}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        costs[gen_id] = get_unified_marginal_cost(generator_wrapper)
    end
    
    return costs
end

"""
Get system-wide generator summary
"""
function get_generator_summary(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        println("No unified generators found in system")
        return nothing
    end
    
    unified_generators = system.extended_data["unified_generators"]
    println("=== PowerLASCOPF Generator Summary ===")
    println("Total generators: $(length(unified_generators))")
    
    # Count by type
    type_counts = Dict{Symbol, Int}()
    total_power = 0.0
    total_cost = 0.0
    
    for (gen_id, generator_wrapper) in unified_generators
        gen_type = generator_wrapper.generator_type
        type_counts[gen_type] = get(type_counts, gen_type, 0) + 1
        
        power = get_unified_power_output(generator_wrapper)
        cost = get_unified_marginal_cost(generator_wrapper)
        available = is_unified_generator_available(generator_wrapper)
        
        total_power += power
        total_cost += cost
        
        println("Gen $gen_id ($(gen_type)): Power = $(round(power, digits=2)) MW, Cost = \$(round(cost, digits=2))/MWh, Available = $available")
    end
    
    println("\n=== Summary by Type ===")
    for (gen_type, count) in type_counts
        println("$gen_type: $count generators")
    end
    
    println("\nTotal Power Output: $(round(total_power, digits=2)) MW")
    println("Average Marginal Cost: \$(round(total_cost/length(unified_generators), digits=2))/MWh")
    
    return (
        total_generators = length(unified_generators),
        type_counts = type_counts,
        total_power = total_power,
        average_cost = total_cost / length(unified_generators)
    )
end

"""
Validate all generators in system
"""
function validate_unified_generators(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        println("No unified generators to validate")
        return true
    end
    
    unified_generators = system.extended_data["unified_generators"]
    all_valid = true
    
    println("=== Validating Unified Generators ===")
    
    for (gen_id, generator_wrapper) in unified_generators
        valid = true
        issues = String[]
        
        # Check basic properties
        if generator_wrapper.gen_id != gen_id
            push!(issues, "ID mismatch")
            valid = false
        end
        
        # Check messaging framework
        if isnothing(generator_wrapper.messaging_framework)
            push!(issues, "Missing messaging framework")
            valid = false
        end
        
        # Check generator availability
        if !is_unified_generator_available(generator_wrapper)
            push!(issues, "Generator not available")
        end
        
        # Type-specific validation
        if generator_wrapper.generator_type == :hydro
            hydro = generator_wrapper.generator
            if hydro.reservoir_capacity <= 0
                push!(issues, "Invalid reservoir capacity")
                valid = false
            end
        elseif generator_wrapper.generator_type == :storage
            storage = generator_wrapper.generator
            if storage.energy_capacity <= 0
                push!(issues, "Invalid energy capacity")
                valid = false
            end
        end
        
        status = valid ? "✓ VALID" : "✗ INVALID"
        issue_str = isempty(issues) ? "" : " ($(join(issues, ", ")))"
        println("Gen $gen_id ($(generator_wrapper.generator_type)): $status$issue_str")
        
        all_valid = all_valid && valid
    end
    
    if all_valid
        println("\n✓ All generators are valid")
    else
        println("\n✗ Some generators have issues")
    end
    
    return all_valid
end

# ===== EXPORT FUNCTIONS =====

export add_unified_generator!, add_thermal_generator!, add_hydro_generator!
export add_storage_generator!, add_renewable_generator!, add_storage_gen_generator!
export run_unified_messaging!, get_all_generator_outputs, get_all_generator_costs
export get_generator_summary, validate_unified_generators
