"""
Load component for PowerLASCOPF.jl

This module defines the Load struct and associated functions for power system loads
in the PowerLASCOPF optimization framework.
"""
"""
    Load{T<:PSY.ElectricLoad}

A load component that extends PowerSystems.ElectricLoad for LASCOPF optimization.
Contains ADMM/APP algorithm state variables and message passing functionality.
"""
@kwdef mutable struct Load{T<:PSY.ElectricLoad}
    # Core load properties
    load_type::T
    load_id::Int
    
    # Power properties
    Pl::Union{Int64, Float64}  # Active power demand
    Thetal::Float64 = 0.0  # Load voltage angle
    v::Float64 = 0.0  # Lagrange multiplier for voltage angle constraint
    
    # Node connection
    conn_node_ptr::Union{Any, Nothing, Node} = nothing  # Will reference Node object
    
    # ADMM/APP state variables
    P_avg::Float64 = 0.0  # Average power from node
    
    function Load(load_type::T, load_id::Int, Pl::Union{Int64, Float64}) where T<:PSY.ElectricLoad
        return new{T}(load_type, load_id, Pl, 0.0, 0.0, nothing, 0.0)
    end
end

# Constructor for legacy compatibility
function Load(idOfLoad::Int, Load_P::Float64)
    # Create a basic PSY.PowerLoad for compatibility
    load_sys = PSY.PowerLoad(
        name="Load_$idOfLoad",
        available=true,
        bus=PSY.ACBus(nothing),  # Will be set later
        active_power=Load_P,
        reactive_power=0.0,
        base_power=100.0,
        max_active_power=Load_P * 1.2,
        max_reactive_power=Load_P * 0.3
    )
    
    return Load(load_sys, idOfLoad, Load_P)
end

# Accessor functions
get_load_id(load::Load) = load.load_id
get_load_node_id(load::Load) = isnothing(load.conn_node_ptr) ? 0 : get_node_id(load.conn_node_ptr)
get_active_power(load::Load) = load.Pl

# ADMM/APP message passing functions
function set_load_data!(load::Load)
    load.v = 0.0  # Initialize Lagrange multiplier
end

function pinit_message(load::Load)
    pinit = 0.0
    if !isnothing(load.conn_node_ptr)
        pinit += ninit_message(load.conn_node_ptr, load.Pl)
    end
    return pinit
end

function lpower_angle_message!(load::Load, lRho::Float64, vprevavg::Float64, Aprevavg::Float64, vprev::Float64)
    load.Thetal = vprevavg + Aprevavg - vprev
    if !isnothing(load.conn_node_ptr)
        power_angle_message!(load.conn_node_ptr, load.Pl, load.v, load.Thetal)
    end
end

function calc_ptilde(load::Load)
    P_avg = isnothing(load.conn_node_ptr) ? 0.0 : pav_message(load.conn_node_ptr)
    return load.Pl - P_avg
end

function calc_pav_init(load::Load)
    return load.Pl - (isnothing(load.conn_node_ptr) ? 0.0 : dev_pinit_message(load.conn_node_ptr))
end

# Connect load to node
function connect_to_node!(load::Load, node)
    load.conn_node_ptr = node
    # Update node connection count and load information
    # set_load_connection!(node, load.load_id, load.Pl)  # Will be implemented when Node is defined
end

function get_u(load::Load)
    return isnothing(load.conn_node_ptr) ? 0.0 : u_message(load.conn_node_ptr)
end

function calc_theta_tilde(load::Load)
    theta_avg = isnothing(load.conn_node_ptr) ? 0.0 : theta_av_message(load.conn_node_ptr)
    return load.Thetal - theta_avg
end

function calc_v_tilde(load::Load)
    v_avg = isnothing(load.conn_node_ptr) ? 0.0 : v_av_message(load.conn_node_ptr)
    return load.v - v_avg
end

function update_v!(load::Load)
    load.v += calc_theta_tilde(load)
    return load.v
end

# Export load functions
export Load, get_load_id, get_load_node_id, get_active_power
export set_load_data!, pinit_message, lpower_angle_message!
export calc_ptilde, calc_pav_init, connect_to_node!
export get_u, calc_theta_tilde, calc_v_tilde, update_v!
