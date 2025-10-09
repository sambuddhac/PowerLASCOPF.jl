"""
Core type definitions for PowerLASCOPF.jl
"""
"""
    PowerLASCOPFSystemData

Main system data structure for PowerLASCOPF
"""
@kwdef mutable struct PowerLASCOPFSystemData
    name::String
    nodes::Vector{Node}
    branches::Vector{transmissionLine}
    thermal_generators::Vector{ExtendedThermalGenerator}
    renewable_generators::Vector{ExtendedRenewableGenerator}
    hydro_generators::Vector{ExtendedHydroGenerator}
    storage_generators::Vector{ExtendedStorageGenerator}
    loads::Vector{Load}
    reserves::Vector{PSY.Service}
    base_power::Float64 = 100.0
    time_horizon::Vector{DateTime}
    scenarios::Vector{LASCOPFScenario}
end

"""
    PowerLASCOPFLoad

Load component for PowerLASCOPF
"""
@kwdef mutable struct PowerLASCOPFLoad
    load_id::Int
    name::String
    node::Node
    active_power::Float64
    reactive_power::Float64
    max_active_power::Float64
    max_reactive_power::Float64
    base_power::Float64
    available::Bool = true
    
    # LASCOPF-specific fields
    participation_factor::Float64 = 1.0
    demand_response_capability::Bool = false
    interruptible::Bool = false
    priority::Int = 1
end

"""
    Branch

Branch component for PowerLASCOPF
"""
@kwdef mutable struct Branch
    branch_id::Int
    name::String
    from_node::Int
    to_node::Int
    resistance::Float64
    reactance::Float64
    susceptance::Float64
    thermal_rating::Float64
    flow_limits::NamedTuple{(:min, :max), Tuple{Float64, Float64}}
    available::Bool = true
    
    # LASCOPF-specific fields
    monitored::Bool = false
    contingency_rating::Float64 = thermal_rating
    emergency_rating::Float64 = thermal_rating * 1.1
end

"""
    HVDCBranch

HVDC branch component for PowerLASCOPF
"""
@kwdef mutable struct HVDCBranch <: Branch
    branch_id::Int
    name::String
    from_node::Int
    to_node::Int
    available::Bool = true
    active_power_limits_from::NamedTuple{(:min, :max), Tuple{Float64, Float64}}
    active_power_limits_to::NamedTuple{(:min, :max), Tuple{Float64, Float64}}
    loss::NamedTuple{(:l0, :l1), Tuple{Float64, Float64}}
    
    # LASCOPF-specific fields
    contingency_rating::Float64 = max(active_power_limits_from.max, active_power_limits_to.max)
end
"""
    LASCOPFScenario

Scenario definition for stochastic LASCOPF
"""
@kwdef mutable struct LASCOPFScenario
    scenario_id::Int
    name::String
    probability::Float64
    contingencies::Vector{Contingency}
    renewable_forecasts::Dict{String, Vector{Float64}}
    load_forecasts::Dict{String, Vector{Float64}}
    hydro_inflows::Vector{Float64}
end

"""
    Contingency

Contingency definition for LASCOPF
"""
@kwdef mutable struct Contingency
    id::Int
    name::String
    component_type::String  # "Line", "Generator", "Transformer"
    component_id::Int
    outage_probability::Float64 = 1.0
    duration::Float64 = 1.0  # hours
    severity::String = "N-1"  # "N-1", "N-2", etc.
end

"""
    Service

Generic service type for reserves, regulation, etc.
"""
abstract type Service end

"""
Helper function to set generator connection on node
"""
function set_g_conn!(node::Node, gen_id::Int)
    if !(gen_id in node.generation_connections)
        push!(node.generation_connections, gen_id)
    end
end

"""
Helper function to get node ID
"""
function get_node_id(node::Node)
    return node.node_id
end

"""
Helper function for power angle messaging
"""
function power_angle_message!(node::Node, power::Float64, voltage::Float64, angle::Float64)
    node.voltage_magnitude = voltage
    node.voltage_angle = angle
    # Additional node-level processing would go here
end
