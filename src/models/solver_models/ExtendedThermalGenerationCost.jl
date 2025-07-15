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
    thermal_cost_core::PSY.ThermalGenerationCost # Coefficient of the quadratic term
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
get_regularization(value::ExtendedThermalGenerationCost) = PSY.value.regularization_term
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
