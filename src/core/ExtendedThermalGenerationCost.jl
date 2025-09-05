"""
	@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    		thermal_cost_core::PSY.ThermalGenerationCost # Coefficient of the quadratic term
    		regularization_term::Union{T, Float64} # Regularization Term
	end
	This is the struct for implmenting extended thermal generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended thermal generation cost model.
        - thermal_cost_core::PSY.ThermalGenerationCost # Coefficient of the quadratic term
        - regularization_term::Union{T, Float64} # Regularization Term
"""

@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    thermal_cost_core::PSY.ThermalGenerationCost # Core thermal generation cost
    regularization_term::Union{T, Float64} # Regularization Term
end

# @kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
#     thermal_cost_core::PSY.ThermalGenerationCost # Coefficient of the quadratic term
#     regularization_term::Union{T, Float64} # Regularization Term
# end

# This outer constructor is fine for cases where regularization_term is a GenIntervals subtype
# but will cause a TypeError if regularization_term is a Float64, as it will try to infer T as Float64.
# We'll discuss a more robust version for this below.

ExtendedThermalGenerationCost(thermal_cost_core, regularization_term) = ExtendedThermalGenerationCost(; thermal_cost_core, regularization_term)
# FIX IS HERE: Make this constructor parametric.
# It now explicitly states that it's a constructor for ExtendedThermalGenerationCost{T}
# where T is any subtype of GenIntervals.
function ExtendedThermalGenerationCost{T}(::Nothing) where {T<:GenIntervals}
    # When this constructor is called, `T` is already known.
    # We then call the keyword argument constructor for `ExtendedThermalGenerationCost{T}`.
    # The `0.0` is a `Float64`, which is allowed for `regularization_term` because of `Union{T, Float64}`.
    ExtendedThermalGenerationCost{T}(; thermal_cost_core=PSY.ThermalGenerationCost(nothing), regularization_term=0.0)
end

"""Get [`ExtendedThermalGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedThermalGenerationCost) = PSY.get_variable(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `fixed`."""
get_fixed(value::ExtendedThermalGenerationCost) = PSY.get_fixed(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
get_start_up(value::ExtendedThermalGenerationCost) = PSY.get_start_up(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
get_shut_down(value::ExtendedThermalGenerationCost) = PSY.get_shut_down(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `regularization_term`."""
get_regularization(value::ExtendedThermalGenerationCost) = value.regularization_term
"""Get [`ExtendedThermalGenerationCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedThermalGenerationCost) = value.thermal_cost_core

"""Set [`ExtendedThermalGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.variable = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.fixed = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
set_start_up!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.start_up = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
set_shut_down!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.shut_down = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
set_regularization!(value::ExtendedThermalGenerationCost, val) = value.regularization_term = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `cost_core`."""
set_cost_core(value::ExtendedThermalGenerationCost, cost_core) = value.thermal_cost_core = cost_core

"""
    compute_regularization_cost(cost::ExtendedThermalGenerationCost{T}, Pg, args...) where {T<:GenIntervals}

Compute the regularization cost term for thermal generators based on the interval type.
"""
function compute_regularization_cost(cost::ExtendedThermalGenerationCost{T}, Pg, args...) where {T<:GenIntervals}
    if isa(cost.regularization_term, Float64)
        return cost.regularization_term * Pg^2
    else
        return regularization_term(cost.regularization_term, Pg, args...)
    end
end

"""
    build_thermal_cost_expression(cost::ExtendedThermalGenerationCost, Pg, args...)

Build the complete thermal cost expression including variable, fixed, startup, shutdown costs and regularization.
"""
function build_thermal_cost_expression(cost::ExtendedThermalGenerationCost, Pg, commitment_var, args...)
    # Core thermal cost (quadratic + linear + fixed)
    variable_cost = PSY.get_variable(cost.thermal_cost_core)
    if isa(variable_cost, PSY.QuadraticCurve)
        core_cost = variable_cost.quadratic_term * Pg^2 + variable_cost.linear_term * Pg + variable_cost.constant_term
    else
        core_cost = variable_cost * Pg
    end
    
    # Fixed cost (when committed)
    core_cost += PSY.get_fixed(cost.thermal_cost_core) * commitment_var
    
    # Add regularization cost
    regularization_cost = compute_regularization_cost(cost, Pg, args...)
    
    return core_cost + regularization_cost
end

# Common utility functions
update_regularization_parameters!(cost::ExtendedThermalGenerationCost{T}, new_params::Dict) where {T<:GenIntervals} = 
    update_regularization_parameters_generic!(cost, new_params, T)

set_regularization_interval!(cost::ExtendedThermalGenerationCost, interval::T) where {T<:GenIntervals} = 
    (cost.regularization_term = interval)

get_regularization_type(cost::ExtendedThermalGenerationCost{T}) where {T<:GenIntervals} = T

is_regularization_active(cost::ExtendedThermalGenerationCost) = !isa(cost.regularization_term, Float64)
