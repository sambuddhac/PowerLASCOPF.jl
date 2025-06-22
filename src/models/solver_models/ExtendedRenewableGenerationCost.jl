"""
	@kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel
    		renewable_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended renewable generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended renewable generation cost model.
        - renewable_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    renewable_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""Get [`ExtendedRenewableGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedRenewableGenerationCost) = get_variable(value.renewable_cost_core)
"""Get [`ExtendedRenewableGenerationCost`](@ref) `curtailment_cost`."""
get_curtailment_cost(value::ExtendedRenewableGenerationCost) = get_curtailment_cost(value.renewable_cost_core)

"""Set [`ExtendedRenewableGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.variable = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `curtailment_cost`."""
set_curtailment_cost!(value::ExtendedRenewableGenerationCost, val) = value.renewable_core_cost.curtailment_cost = val
