using PowerSystems
using InfrastructureSystems
const IS = InfrastructureSystems
const PSY = PowerSystems

# Define abstract types for PowerLASCOPF hierarchy
abstract type PowerLASCOPFComponent end
abstract type Subsystem <: PowerLASCOPFComponent end
abstract type Device <: PowerLASCOPFComponent end
abstract type PowerGenerator <: Device end

# Define the Node struct extending PowerSystems.Bus for Sienna integration
mutable struct Node{T<:PSY.Bus} <: Subsystem
    # Core node properties
    node_type::T
    node_id::Int
    
    # Connection counts
    g_conn_number::Int
    t_conn_number::Int
    l_conn_number::Int
    
    # Power and voltage properties
    P_avg::Float64
    theta_avg::Float64
    conn_load_val::Float64
    u::Float64
    v_avg::Float64
    P_dev_count::Int
    P_init_avg::Float64
    
    # Scenario and contingency properties
    contingency_scenarios::Int
    node_flag::Int
    
    # Reactance properties
    from_react::Float64
    to_react::Float64
    
    # Vector properties for connections and scenarios
    gen_serial_num::Vector{Int}
    react_cont::Vector{Float64}
    conn_node_list::Vector{Int}  # Changed from Vector{Node} to avoid circular references
    conn_react_rec::Vector{Float64}
    tran_from_serial::Vector{Int}
    tran_to_serial::Vector{Int}
    load_serial_num::Vector{Int}
    cont_scen_list::Vector{Int}
    scen_node_list::Vector{Int}
    
    # Inner constructor
    function Node{T}(
        node_type::T,
        node_id::Int,
        number_of_scenarios::Int
    ) where T <: PSY.Bus
        return new{T}(
            node_type,
            node_id,
            0,  # g_conn_number
            0,  # t_conn_number
            0,  # l_conn_number
            0.0,  # P_avg
            0.0,  # theta_avg
            0.0,  # conn_load_val
            0.0,  # u
            0.0,  # v_avg
            0,  # P_dev_count
            0.0,  # P_init_avg
            number_of_scenarios,
            0,  # node_flag
            0.0,  # from_react
            0.0,  # to_react
            Int[],  # gen_serial_num
            Float64[],  # react_cont
            Int[],  # conn_node_list
            Float64[],  # conn_react_rec
            Int[],  # tran_from_serial
            Int[],  # tran_to_serial
            Int[],  # load_serial_num
            Int[],  # cont_scen_list
            Int[]   # scen_node_list
        )
    end
end

# Outer constructor for convenience
function Node(node_type::T, node_id::Int, number_of_scenarios::Int) where T <: PSY.Bus
    return Node{T}(node_type, node_id, number_of_scenarios)
end

# Extend PowerSystems.Bus interface
PowerSystems.get_name(node::Node) = PowerSystems.get_name(node.node_type)
PowerSystems.get_number(node::Node) = node.node_id
PowerSystems.get_bustype(node::Node) = PowerSystems.get_bustype(node.node_type)
PowerSystems.get_angle(node::Node) = node.theta_avg
PowerSystems.get_magnitude(node::Node) = PowerSystems.get_magnitude(node.node_type)
PowerSystems.get_voltage_limits(node::Node) = PowerSystems.get_voltage_limits(node.node_type)
PowerSystems.get_base_voltage(node::Node) = PowerSystems.get_base_voltage(node.node_type)
PowerSystems.get_area(node::Node) = PowerSystems.get_area(node.node_type)
PowerSystems.get_load_zone(node::Node) = PowerSystems.get_load_zone(node.node_type)

# Extend InfrastructureSystems.Component interface
IS.get_uuid(node::Node) = IS.get_uuid(node.node_type)
IS.get_ext(node::Node) = IS.get_ext(node.node_type)
IS.get_time_series_container(node::Node) = IS.get_time_series_container(node.node_type)

# Core getter functions
get_node_id(node::Node) = node.node_id
get_node_type(node::Node) = node.node_type
get_contingency_scenarios(node::Node) = node.contingency_scenarios

# Generator connection functions
function set_g_conn!(node::Node, serial_of_gen::Int64)
    node.g_conn_number += 1
    push!(node.gen_serial_num, serial_of_gen)
    return nothing
end

get_gen_length(node::Node) = node.g_conn_number
get_gen_serial(node::Node, col_count::Int) = node.gen_serial_num[col_count]

# Transmission line connection functions
function set_t_conn!(
    node::Node,
    tran_id::Int,
    dir::Int,
    react::Float64,
    rank_of_other::Int,
    scenario_tracker::Int
)
    node.t_conn_number += 1
    
    if scenario_tracker != 0
        push!(node.cont_scen_list, scenario_tracker)
    end
    
    if dir == 1
        push!(node.tran_from_serial, tran_id)
        node.from_react += 1 / react
        
        if scenario_tracker != 0
            push!(node.react_cont, -1 / react)
            push!(node.scen_node_list, rank_of_other)
        end
        
        pos = findfirst(x -> x == rank_of_other, node.conn_node_list)
        if pos !== nothing
            node.conn_react_rec[pos] -= 1 / react
        else
            push!(node.conn_node_list, rank_of_other)
            push!(node.conn_react_rec, -1 / react)
        end
    else
        push!(node.tran_to_serial, tran_id)
        node.to_react -= 1 / react
        
        if scenario_tracker != 0
            push!(node.react_cont, 1 / react)
            push!(node.scen_node_list, rank_of_other)
        end
        
        pos = findfirst(x -> x == rank_of_other, node.conn_node_list)
        if pos !== nothing
            node.conn_react_rec[pos] += 1 / react
        else
            push!(node.conn_node_list, rank_of_other)
            push!(node.conn_react_rec, 1 / react)
        end
    end
    
    return nothing
end

# Reactance getter functions with scenario support
function get_to_react(node::Node, scenario_tracker::Int)
    pos = findfirst(x -> x == scenario_tracker, node.cont_scen_list)
    if pos !== nothing
        if node.react_cont[pos] > 0
            return node.to_react + node.react_cont[pos]
        else
            return node.to_react
        end
    end
    return node.to_react
end

function get_from_react(node::Node, scenario_tracker::Int)
    pos = findfirst(x -> x == scenario_tracker, node.cont_scen_list)
    if pos !== nothing
        if node.react_cont[pos] <= 0
            return node.from_react + node.react_cont[pos]
        else
            return node.from_react
        end
    end
    return node.from_react
end

# Connection information functions
get_conn_node_length(node::Node) = length(node.conn_node_list)
get_conn_serial(node::Node, col_count::Int) = node.conn_node_list[col_count]
get_conn_react(node::Node, col_count::Int) = node.conn_react_rec[col_count]

function get_conn_serial_scenario(node::Node, scenario_tracker::Int)
    pos = findfirst(x -> x == scenario_tracker, node.cont_scen_list)
    return pos !== nothing ? node.scen_node_list[pos] : 0
end

function get_conn_react_compensate(node::Node, scenario_tracker::Int)
    pos = findfirst(x -> x == scenario_tracker, node.cont_scen_list)
    return pos !== nothing ? node.react_cont[pos] : 0.0
end

# Load connection functions
function set_l_conn!(node::Node, load_id::Int, load_val::Float64)
    node.l_conn_number += 1
    push!(node.load_serial_num, load_id)
    node.conn_load_val = load_val
    return nothing
end

get_load_val(node::Node) = node.conn_load_val
get_load_length(node::Node) = node.l_conn_number
get_load_serial(node::Node, col_count::Int) = node.load_serial_num[col_count]

# Power and angle messaging functions
function np_init_message!(node::Node, p_load::Float64)
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    if total_connections > 0
        node.P_init_avg += p_load / total_connections
    end
    return node.P_init_avg
end

dev_p_init_message(node::Node) = node.P_init_avg

function power_angle_message!(node::Node, power::Float64, ang_price::Float64, angle::Float64)
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    if total_connections > 0
        node.P_avg += power / total_connections
        node.theta_avg += angle / total_connections
        # Uncomment if needed: node.v_avg += ang_price / total_connections
    end
    node.P_dev_count += 1
    return nothing
end

# Message retrieval functions
function p_avg_message(node::Node)
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    return node.P_dev_count == total_connections ? node.P_avg : nothing
end

function u_message!(node::Node)
    if node.node_flag != 0
        return node.u
    end
    
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    if node.P_dev_count == total_connections
        node.u += node.P_avg
        node.node_flag += 1
        return node.u
    end
    
    return nothing
end

function theta_avg_message(node::Node)
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    return node.P_dev_count == total_connections ? node.theta_avg : nothing
end

function v_avg_message(node::Node)
    total_connections = node.g_conn_number + node.t_conn_number + node.l_conn_number
    return node.P_dev_count == total_connections ? node.v_avg : nothing
end

# Reset function
function reset!(node::Node)
    node.P_dev_count = 0
    node.P_avg = 0.0
    node.v_avg = 0.0
    node.theta_avg = 0.0
    node.node_flag = 0
    return nothing
end

# Utility functions for PowerSystems integration
function get_total_connections(node::Node)
    return node.g_conn_number + node.t_conn_number + node.l_conn_number
end

function is_complete(node::Node)
    return node.P_dev_count == get_total_connections(node)
end

# Display function for debugging
function Base.show(io::IO, node::Node)
    print(io, "Node(")
    print(io, "id=$(node.node_id), ")
    print(io, "type=$(typeof(node.node_type)), ")
    print(io, "generators=$(node.g_conn_number), ")
    print(io, "transmissions=$(node.t_conn_number), ")
    print(io, "loads=$(node.l_conn_number)")
    print(io, ")")
end

# Export all public functions
export Node, get_node_id, get_node_type, get_contingency_scenarios
export set_g_conn!, get_gen_length, get_gen_serial
export set_t_conn!, get_to_react, get_from_react
export get_conn_node_length, get_conn_serial, get_conn_react
export get_conn_serial_scenario, get_conn_react_compensate
export set_l_conn!, get_load_val, get_load_length, get_load_serial
export np_init_message!, dev_p_init_message, power_angle_message!
export p_avg_message, u_message!, theta_avg_message, v_avg_message
export reset!, get_total_connections, is_complete