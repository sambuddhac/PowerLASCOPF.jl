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

ExtendedHydroGenerationCost(hydro_cost_core, regularization_term) = ExtendedHydroGenerationCost(; hydro_cost_core, regularization_term)

function ExtendedHydroGenerationCost(::Nothing)
    ExtendedHydroGenerationCost(PSY.HydroGenerationCost(nothing), 0.0)

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
