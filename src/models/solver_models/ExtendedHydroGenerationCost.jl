"""
	@kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel
    		hydro_cost_core::PSY.HydroGenerationCost # Coefficient of the quadratic term
    		regularization_term::Union{T, Float64} # Regularization Term
	end
	This is the struct for implmenting extended hydro generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended hydro generation cost model.
        - hydro_cost_core::PSY.HydroGenerationCost # Coefficient of the quadratic term
        - regularization_term::Union{T, Float64} # Regularization Term
"""

@kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel
    hydro_cost_core::PSY.HydroGenerationCost # Coefficient of the quadratic term
    regularization_term::Union{T, Float64} # Regularization Term
end

# @kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel
#     hydro_cost_core::PSY.HydroGenerationCost # Coefficient of the quadratic term
#     regularization_term::Union{T, Float64} # Regularization Term
# end

# This outer constructor is fine for cases where regularization_term is a GenIntervals subtype
# but will cause a TypeError if regularization_term is a Float64, as it will try to infer T as Float64.
# We'll discuss a more robust version for this below.

ExtendedHydroGenerationCost(hydro_cost_core, regularization_term) = ExtendedHydroGenerationCost(; hydro_cost_core, regularization_term)

# FIX IS HERE: Make this constructor parametric.
# It now explicitly states that it's a constructor for ExtendedHydroGenerationCost{T}
# where T is any subtype of GenIntervals.

function ExtendedHydroGenerationCost(::Nothing)
    # When this constructor is called, `T` is already known.
    # We then call the keyword argument constructor for `ExtendedHydroGenerationCost{T}`.
    # The `0.0` is a `Float64`, which is allowed for `regularization_term` because of `Union{T, Float64}`.
    ExtendedHydroGenerationCost{T}(; hydro_cost_core=PSY.HydroGenerationCost(nothing), regularization_term=0.0)
end

"""Get [`ExtendedHydroGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedHydroGenerationCost) = PSY.get_variable(value.hydro_cost_core)
"""Get [`ExtendedHydroGenerationCost`](@ref) `fixed`."""
get_fixed(value::ExtendedHydroGenerationCost) = PSY.get_fixed(value.hydro_cost_core)
"""Get [`ExtendedHydroGenerationCost`](@ref) `regularization_term`."""
get_regularization_term(value::ExtendedHydroGenerationCost) = value.regularization_term
"""Get [`ExtendedHydroGenerationCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedHydroGenerationCost) = value.hydro_cost_core

"""Set [`ExtendedHydroGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedHydroGenerationCost, val) = value.hydro_cost_core.variable = val
"""Set [`ExtendedHydroGenerationCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedHydroGenerationCost, val) = value.hydro_cost_core.fixed = val
"""Set [`ExtendedHydroGenerationCost`](@ref) `regularization_term`."""
set_regularization_term!(value::ExtendedHydroGenerationCost, val) = value.regularization_term = val
"""Set [`ExtendedHydroGenerationCost`](@ref) `cost_core`."""
set_cost_core(value::ExtendedHydroGenerationCost, cost_core) = value.hydro_cost_core = cost_core
