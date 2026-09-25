"""
Load component for PowerLASCOPF.jl

This module defines the Load struct and associated functions for power system loads
in the PowerLASCOPF optimization framework.
    Load{T<:PSY.ElectricLoad}

A load component that extends PowerSystems.ElectricLoad for LASCOPF optimization.
Contains ADMM/APP algorithm state variables and message passing functionality.
"""
@kwdef mutable struct Load{T<:PSY.ElectricLoad} <: Devices
    # Core load properties
    load_type::T
    load_id::Int

    # Power properties
    Pl::Union{Int64, Float64}  # Active power demand for the active interval
    Thetal::Float64 = 0.0  # Load voltage angle
    v::Float64 = 0.0  # Lagrange multiplier for voltage angle constraint

    # Node connection
    conn_node_ptr::Union{Any, Nothing, Node} = nothing  # Will reference Node object

    # ADMM/APP state variables
    P_avg::Float64 = 0.0  # Average power from node

    # Time-varying demand
    Pl_nominal::Float64 = 0.0  # Nameplate demand from the Loads CSV, before scaling
    Pl_profile::Vector{Float64} = Float64[]  # PL array: Pl_nominal .* per-unit time series
    interval::Int = 0  # Index into Pl_profile currently loaded into Pl (0 = none)

    function Load(load_type::T, load_id::Int, Pl::Union{Int64, Float64},
                  Pl_profile::AbstractVector{<:Real} = Float64[]) where T<:PSY.ElectricLoad
        profile = Vector{Float64}(Pl_profile)
        # With a profile attached the load starts at hour 1; without one it keeps
        # the scalar nominal, so existing three-argument callers are unaffected.
        Pl_active = isempty(profile) ? Float64(Pl) : profile[1]
        return new{T}(load_type, load_id, Pl_active, 0.0, 0.0, nothing, 0.0,
                      Float64(Pl), profile, isempty(profile) ? 0 : 1)
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
        pinit += np_init_message!(load.conn_node_ptr, Float64(load.Pl))
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
    isnothing(load.conn_node_ptr) && return 0.0
    P_avg = p_avg_message(load.conn_node_ptr)
    # p_avg_message returns nothing until every device on the node has reported.
    return isnothing(P_avg) ? 0.0 : load.Pl - P_avg
end

function calc_pav_init(load::Load)
    return load.Pl - (isnothing(load.conn_node_ptr) ? 0.0 : dev_p_init_message(load.conn_node_ptr))
end

# Connect load to node
function connect_to_node!(load::Load, node)
    load.conn_node_ptr = node
    # Mirrors the C++ constructor, which registered the load on its node so the
    # node's averaging divisor counts this device.
    set_l_conn!(node, load.load_id, Float64(load.Pl))
    return load
end

function get_u(load::Load)
    isnothing(load.conn_node_ptr) && return 0.0
    u = u_message!(load.conn_node_ptr)
    return isnothing(u) ? 0.0 : u
end

function calc_theta_tilde(load::Load)
    isnothing(load.conn_node_ptr) && return 0.0
    theta_avg = theta_avg_message(load.conn_node_ptr)
    return isnothing(theta_avg) ? 0.0 : load.Thetal - theta_avg
end

function calc_v_tilde(load::Load)
    isnothing(load.conn_node_ptr) && return 0.0
    v_avg = v_avg_message(load.conn_node_ptr)
    return isnothing(v_avg) ? 0.0 : load.v - v_avg
end

function update_v!(load::Load)
    load.v += calc_theta_tilde(load)
    return load.v
end

# ===== TIME-VARYING DEMAND (PL ARRAY) =====

"""
    attach_profile!(load::Load, profile::AbstractVector{<:Real})

Attach a PL array — nominal demand already multiplied by its per-unit time
series — and move the load to the first interval.
"""
function attach_profile!(load::Load, profile::AbstractVector{<:Real})
    load.Pl_profile = Vector{Float64}(profile)
    if !isempty(load.Pl_profile)
        set_interval!(load, 1)
    end
    return load
end

has_profile(load::Load) = !isempty(load.Pl_profile)
get_pl_profile(load::Load) = load.Pl_profile
get_horizon(load::Load) = length(load.Pl_profile)

"""
    get_pl_at(load::Load, t::Int)

Demand at interval `t`, falling back to the scalar nominal when no PL array is
attached.
"""
function get_pl_at(load::Load, t::Int)
    has_profile(load) || return Float64(load.Pl)
    1 <= t <= length(load.Pl_profile) ||
        throw(BoundsError("interval $t outside PL array of length $(length(load.Pl_profile)) for load $(load.load_id)"))
    return load.Pl_profile[t]
end

"""
    set_interval!(load::Load, t::Int)

Load interval `t` of the PL array into `Pl`, keeping the demand registered on
the connected node in step.
"""
function set_interval!(load::Load, t::Int)
    load.Pl = get_pl_at(load, t)
    load.interval = t
    if !isnothing(load.conn_node_ptr)
        set_load_val!(load.conn_node_ptr, Float64(load.Pl))
    end
    return load.Pl
end

# Export load functions
export Load, get_load_id, get_load_node_id, get_active_power
export set_load_data!, pinit_message, lpower_angle_message!
export calc_ptilde, calc_pav_init, connect_to_node!
export get_u, calc_theta_tilde, calc_v_tilde, update_v!
export attach_profile!, has_profile, get_pl_profile, get_horizon
export get_pl_at, set_interval!
