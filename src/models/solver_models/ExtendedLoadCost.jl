# Needed macros and types
using Parameters  # for @kwdef
# using PowerSystems  # Uncomment in actual code base, for type access

# AbstractModel and LoadIntervals should be defined somewhere in your codebase.
# abstract type AbstractModel end
# abstract type LoadIntervals end
"""
    The core cost information for flexible/controllable loads.
    Can be either a LoadCost or a MarketBidCost (for DR bidding).

    Regularization term, to allow adding convexifying penalties,
    scenario weights, or auxiliary variables.
    """

@kwdef mutable struct ExtendedLoadCost{T<:LoadIntervals}<:AbstractModel
    
    load_cost_core::Union{PSY.LoadCost, PSY.MarketBidCost}
    regularization_term::Union{T, Float64}
end

# Default outer constructors, following your template
ExtendedLoadCost(load_cost_core, regularization_term) = ExtendedLoadCost(; load_cost_core, regularization_term)

function ExtendedLoadCost{T}(::Nothing) where {T<:LoadIntervals}
    # Both LoadCost and MarketBidCost have demo/empty constructors with nothing
    ExtendedLoadCost{T}(;
        load_cost_core=LoadCost(nothing),
        regularization_term=0.0
    )
end

# -- Generic field access
get_cost_core(value::ExtendedLoadCost) = value.load_cost_core
get_regularization(value::ExtendedLoadCost) = value.regularization_term

set_cost_core!(value::ExtendedLoadCost, val) = (value.load_cost_core = val)
set_regularization!(value::ExtendedLoadCost, val) = (value.regularization_term = val)

# -- Delegate load_cost_core internals, for easy compatibility
# LoadCost fields
get_variable(value::ExtendedLoadCost) = isa(value.load_cost_core, LoadCost) ?
    get_variable(value.load_cost_core) : nothing

get_fixed(value::ExtendedLoadCost) = isa(value.load_cost_core, LoadCost) ?
    get_fixed(value.load_cost_core) : nothing

set_variable!(value::ExtendedLoadCost, val) =
    isa(value.load_cost_core, LoadCost) ?
        set_variable!(value.load_cost_core, val) : nothing

set_fixed!(value::ExtendedLoadCost, val) =
    isa(value.load_cost_core, LoadCost) ?
        set_fixed!(value.load_cost_core, val) : nothing



# MarketBidCost fields
get_no_load_cost(value::ExtendedLoadCost) = isa(value.load_cost_core, MarketBidCost) ?
    get_no_load_cost(value.load_cost_core) : nothing

get_start_up(value::ExtendedLoadCost) = isa(value.load_cost_core, MarketBidCost) ?
    get_start_up(value.load_cost_core) : nothing

get_shut_down(value::ExtendedLoadCost) = isa(value.load_cost_core, MarketBidCost) ?
    get_shut_down(value.load_cost_core) : nothing

