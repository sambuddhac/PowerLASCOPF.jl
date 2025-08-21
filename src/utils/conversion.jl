"""
Conversion utilities for PowerLASCOPF.jl

This module provides conversion functions between different data formats
and coordinate systems used in PowerLASCOPF.
"""

using PowerSystems
using ..Core: DEFAULT_BASE_POWER, DEFAULT_DIV_CONV_MWPU
const PSY = PowerSystems

"""
    mw_to_pu(power_mw::Float64, base_power::Float64 = DEFAULT_BASE_POWER)

Convert power from MW to per-unit (pu) using the specified base power.
"""
function mw_to_pu(power_mw::Float64, base_power::Float64 = DEFAULT_BASE_POWER)
    return power_mw / base_power
end

"""
    pu_to_mw(power_pu::Float64, base_power::Float64 = DEFAULT_BASE_POWER)

Convert power from per-unit (pu) to MW using the specified base power.
"""
function pu_to_mw(power_pu::Float64, base_power::Float64 = DEFAULT_BASE_POWER)
    return power_pu * base_power
end

"""
    degrees_to_radians(angle_degrees::Float64)

Convert angle from degrees to radians.
"""
function degrees_to_radians(angle_degrees::Float64)
    return angle_degrees * π / 180.0
end

"""
    radians_to_degrees(angle_radians::Float64)

Convert angle from radians to degrees.
"""
function radians_to_degrees(angle_radians::Float64)
    return angle_radians * 180.0 / π
end

"""
    reactance_to_susceptance(reactance::Float64)

Convert reactance to susceptance (B = 1/X).
"""
function reactance_to_susceptance(reactance::Float64)
    if abs(reactance) < 1e-12
        error("Reactance too small, susceptance would be infinite")
    end
    return 1.0 / reactance
end

"""
    susceptance_to_reactance(susceptance::Float64)

Convert susceptance to reactance (X = 1/B).
"""
function susceptance_to_reactance(susceptance::Float64)
    if abs(susceptance) < 1e-12
        error("Susceptance too small, reactance would be infinite")
    end
    return 1.0 / susceptance
end

"""
    normalize_power_values!(power_values::Vector{Float64}, divisor::Float64 = DEFAULT_DIV_CONV_MWPU)

Normalize power values by dividing by the specified divisor.
Modifies the input vector in-place.
"""
function normalize_power_values!(power_values::Vector{Float64}, divisor::Float64 = DEFAULT_DIV_CONV_MWPU)
    power_values ./= divisor
    return power_values
end

"""
    denormalize_power_values!(power_values::Vector{Float64}, multiplier::Float64 = DEFAULT_DIV_CONV_MWPU)

Denormalize power values by multiplying by the specified multiplier.
Modifies the input vector in-place.
"""
function denormalize_power_values!(power_values::Vector{Float64}, multiplier::Float64 = DEFAULT_DIV_CONV_MWPU)
    power_values .*= multiplier
    return power_values
end

"""
    convert_psy_bus_to_node_data(psy_bus::PSY.Bus)

Convert a PowerSystems.Bus to node data for PowerLASCOPF.
Returns a dictionary with node parameters.
"""
function convert_psy_bus_to_node_data(psy_bus::PSY.Bus)
    node_data = Dict(
        "id" => PSY.get_number(psy_bus),
        "name" => PSY.get_name(psy_bus),
        "base_voltage" => PSY.get_base_voltage(psy_bus),
        "voltage_limits" => (PSY.get_voltage_limits(psy_bus).min, PSY.get_voltage_limits(psy_bus).max),
        "bustype" => PSY.get_bustype(psy_bus),
        "angle" => PSY.get_angle(psy_bus),
        "magnitude" => PSY.get_magnitude(psy_bus)
    )
    return node_data
end

"""
    convert_psy_line_to_transmission_data(psy_line::PSY.Line)

Convert a PowerSystems.Line to transmission line data for PowerLASCOPF.
Returns a dictionary with transmission line parameters.
"""
function convert_psy_line_to_transmission_data(psy_line::PSY.Line)
    line_data = Dict(
        "name" => PSY.get_name(psy_line),
        "from_bus" => PSY.get_number(PSY.get_from(PSY.get_arc(psy_line))),
        "to_bus" => PSY.get_number(PSY.get_to(PSY.get_arc(psy_line))),
        "r" => PSY.get_r(psy_line),
        "x" => PSY.get_x(psy_line),
        "b" => PSY.get_b(psy_line),
        "rating" => PSY.get_rating(psy_line),
        "available" => PSY.get_available(psy_line)
    )
    return line_data
end

"""
    convert_psy_generator_to_gen_data(psy_gen::PSY.Generator)

Convert a PowerSystems.Generator to generator data for PowerLASCOPF.
Returns a dictionary with generator parameters.
"""
function convert_psy_generator_to_gen_data(psy_gen::PSY.Generator)
    gen_data = Dict(
        "name" => PSY.get_name(psy_gen),
        "bus" => PSY.get_number(PSY.get_bus(psy_gen)),
        "available" => PSY.get_available(psy_gen),
        "active_power" => PSY.get_active_power(psy_gen),
        "reactive_power" => PSY.get_reactive_power(psy_gen),
        "rating" => PSY.get_rating(psy_gen),
        "active_power_limits" => (PSY.get_active_power_limits(psy_gen).min, PSY.get_active_power_limits(psy_gen).max),
        "reactive_power_limits" => (PSY.get_reactive_power_limits(psy_gen).min, PSY.get_reactive_power_limits(psy_gen).max),
        "base_power" => PSY.get_base_power(psy_gen)
    )
    return gen_data
end

# Export conversion functions
export mw_to_pu, pu_to_mw, degrees_to_radians, radians_to_degrees
export reactance_to_susceptance, susceptance_to_reactance
export normalize_power_values!, denormalize_power_values!
export convert_psy_bus_to_node_data, convert_psy_line_to_transmission_data
export convert_psy_generator_to_gen_data