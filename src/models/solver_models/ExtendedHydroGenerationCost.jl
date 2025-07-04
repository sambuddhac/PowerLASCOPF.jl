"""
	@kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel
    		hydro_cost_core::HydroGenerationCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended hydro generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended hydro generation cost model.
        - hydro_cost_core::HydroGenerationCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel
    hydro_cost_core::HydroGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""Get [`ExtendedHydroGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedHydroGenerationCost) = PSY.get_variable(value.hydro_cost_core)
"""Get [`ExtendedHydroGenerationCost`](@ref) `fixed`."""
get_fixed(value::ExtendedHydroGenerationCost) = PSY.get_fixed(value.hydro_cost_core)

"""Set [`ExtendedHydroGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedHydroGenerationCost, val) = value.hydro_cost_core.variable = val
"""Set [`ExtendedHydroGenerationCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedHydroGenerationCost, val) = value.hydro_cost_core.fixed = val
